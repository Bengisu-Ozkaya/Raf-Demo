// d:\Flutter\Raf_Demo\raf_demo\backend\whatsapp_service.js

const { Client, LocalAuth } = require('whatsapp-web.js'); // Buttons kaldırıldı
const qrcode = require('qrcode-terminal');

// Değişkenler
let client;
const messageQueue = []; // Gönderilecek mesajlar için kuyruk yapısı
let isSending = false;   // Anlık olarak mesaj gönderilip gönderilmediğini kontrol eden bayrak
let eventEmitter; // server.js'ten gelen olay dinleyicisi

/**
 * Belirtilen milisaniye kadar beklemeyi sağlayan yardımcı fonksiyon.
 * @param {number} ms - Beklenecek süre (milisaniye).
 */
const delay = (ms) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * WhatsApp istemcisini (bot) başlatan ana fonksiyon.
 * Oturumu 'session' klasörüne kaydederek tekrar QR kod okutma ihtiyacını ortadan kaldırır.
 */
const initialize = (emitter) => {
    console.log("WhatsApp Bot başlatılıyor...");

    client = new Client({
        authStrategy: new LocalAuth(), // Oturumu kalıcı hale getirir.
        puppeteer: {
            headless: true,
            // Sunucu/Termux ortamlarında sorunsuz çalışması için gerekli ayarlar
            args: ['--no-sandbox', '--disable-setuid-sandbox'],
            // YENİ: Bağlantı zaman aşımı süresini 120 saniyeye (2 dakika) çıkarıyoruz.
            timeout: 120000
        }
    });

    // 1. QR Kod Oluşturma: Sadece ilk kurulumda çalışır.
    client.on('qr', (qr) => {
        console.log('WhatsApp Web QR Kodu (Lütfen telefonunuzdan taratın):');
        qrcode.generate(qr, { small: true });
    });

    // 2. Başarılı Bağlantı: Bot hazır olduğunda tetiklenir.
    client.on('ready', () => {
        console.log('WhatsApp Dağıtıcı Bot Aktif ve Bağlandı! 🚀');
        // Bot hazır olduğunda bekleyen mesajları göndermeye başla.
        processQueue();
    });

    // 3. Hata Yönetimi
    client.on('auth_failure', msg => {
        console.error('WhatsApp kimlik doğrulama hatası! Oturum dosyalarını silip tekrar deneyin.', msg);
    });

    client.on('disconnected', (reason) => {
        console.log('WhatsApp bağlantısı kesildi!', reason);
        // Burada isteğe bağlı olarak client.initialize() çağrılarak yeniden bağlanma denenebilir.
    });

    // 4. YENİ: Gelen Mesajları Dinleme
    // İşletmecinin butonlara verdiği yanıtları yakalamak için.
    client.on('message', async (message) => {
        // Sadece buton yanıtı olan ve bizim belirlediğimiz ID yapısına uyan mesajları işle.
        if (message.type === 'buttons_response' && message.selectedButtonId.startsWith('updateStatus_')) {
            console.log(`[WhatsApp] Buton yanıtı alındı: ${message.selectedButtonId} / Gönderen: ${message.from}`);
            
            const [action, orderIdStr, newStatus] = message.selectedButtonId.split('_');
            
            if (action === 'updateStatus' && orderIdStr && newStatus) {
                const orderId = parseInt(orderIdStr, 10);
                const from = message.from; // Gönderenin ID'si (örn: 905xxxxxxxxx@c.us)
                
                // server.js'i haberdar et.
                if (eventEmitter) {
                    eventEmitter.emit('status-update-request', { from, orderId, newStatus });
                }
            }
        }
    });

    client.initialize();
};

/**
 * Mesaj kuyruğunu işleyen fonksiyon.
 * Spam filtresine takılmamak için her mesaj arasına rastgele bir gecikme ekler.
 */
const processQueue = async () => {
    // Eğer zaten bir gönderme işlemi varsa veya kuyruk boşsa, fonksiyondan çık.
    if (isSending || messageQueue.length === 0) {
        return;
    }
    isSending = true;

    // Kuyruktan ilk mesajı al.
    const { chatId, messageText, options } = messageQueue.shift(); // YENİ: messageText ve options olarak al

    try {
        // WhatsApp'ın spam olarak algılamaması için 1-3 saniye arası rastgele bir gecikme ekle.
        const randomDelay = Math.floor(Math.random() * 2000) + 1000;
        console.log(`(${chatId}) numarasına mesaj göndermek için ${randomDelay}ms bekleniyor...`);
        await delay(randomDelay);

        // Mesajı ve seçenekleri (butonlar vb.) gönder.
        await client.sendMessage(chatId, messageText, options); // YENİ: messageText ve options ile gönder
        console.log(`Sipariş bildirimi başarıyla gönderildi: ${chatId}`);
    } catch (error) {
        console.error(`Mesaj gönderilemedi: ${chatId}`, error.message);
    } finally {
        // Gönderim tamamlansın veya hata versin, bir sonraki mesaja geçmeye hazır ol.
        isSending = false;
        // Kuyrukta hala mesaj varsa, bir sonrakini işlemeye başla.
        processQueue();
    }
};

/**
 * Siparişin mevcut durumuna göre gösterilecek butonları oluşturan yardımcı fonksiyon.
 * @param {string} status - Siparişin mevcut durumu ('Bekleniyor', 'Hazırlanıyor' vb.).
 * @param {number} orderId - Sipariş ID'si.
 * @returns {Array} - Buton nesnelerini içeren bir dizi.
 */
const getButtonsForStatus = (status, orderId) => {
    const buttons = [];
    switch (status) {
        case 'Bekleniyor':
            buttons.push({ id: `updateStatus_${orderId}_Hazırlanıyor`, body: 'Hazırlanıyor' });
            buttons.push({ id: `updateStatus_${orderId}_İptal Edildi`, body: 'İptal Et' });
            break;
        case 'Hazırlanıyor':
            buttons.push({ id: `updateStatus_${orderId}_Yola Çıktı`, body: 'Yola Çıktı' });
            buttons.push({ id: `updateStatus_${orderId}_İptal Edildi`, body: 'İptal Et' });
            break;
        case 'Yola Çıktı':
             buttons.push({ id: `updateStatus_${orderId}_Teslim Edildi`, body: 'Teslim Edildi' });
            break;
        // 'Teslim Edildi' veya 'İptal Edildi' durumları için yeni bir aksiyon butonu gösterme.
        default:
            break;
    }
    return buttons;
}

/**
 * Dışarıdan çağrılacak olan, sipariş bildirimini kuyruğa ekleyen fonksiyon.
 * @param {string} shopPhoneNumber - Dükkanın telefon numarası (örn: 5321234567).
 * @param {string} message - Gönderilecek formatlanmış mesaj.
 * @param {number} orderId - Siparişin ID'si (butonlar için gerekli).
 * @param {string} currentStatus - Siparişin mevcut durumu (butonları belirlemek için).
 */
const sendOrderNotification = (shopPhoneNumber, messageText, orderId, currentStatus) => {
    // Botun hazır olup olmadığını kontrol et.
    if (!client || !client.info) {
        console.error('WhatsApp istemcisi henüz hazır değil. Mesaj kuyruğa eklendi ama gönderim için botun bağlanması bekleniyor.');
    }
    
    const formattedNumber = `90${shopPhoneNumber.replace(/\s/g, '').slice(-10)}@c.us`;
    const actionButtons = getButtonsForStatus(currentStatus, orderId);

    const options = {};
    if (actionButtons.length > 0) {
        options.buttons = actionButtons;
        options.title = `Sipariş #${orderId}`;
        options.footer = 'Durumu güncellemek için butona tıklayın.';
    }

    // Mesajı ve seçenekleri kuyruğa ekle
    messageQueue.push({ chatId: formattedNumber, messageText: messageText, options: options });
    console.log(`Yeni sipariş bildirimi kuyruğa eklendi: ${formattedNumber}`);

    if (!isSending) {
        processQueue();
    }
};

const sendMessage = (chatId, messageText, options = {}) => { // options parametresi eklendi
    messageQueue.push({ chatId, messageText, options }); // messageText ve options olarak sakla
    if (!isSending) processQueue();
};

module.exports = (emitter) => {
    eventEmitter = emitter;
    return { initialize: () => initialize(emitter), sendOrderNotification, sendMessage };
};
