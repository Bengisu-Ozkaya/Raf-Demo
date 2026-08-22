// d:\Flutter\Raf_Demo\raf_demo\backend\whatsapp_service.js

let eventEmitter;

/**
 * WhatsApp Servisi (Hafif ve Bulut Uyumlu)
 * Mobil uygulama kullanıcıyı doğrudan WhatsApp deep link (wa.me) ile yönlendirdiği için
 * sunucu tarafında ağır ve harici Chromium gerektiren kütüphaneler yerine
 * sunucu loglaması ve olay yönetimi kullanılır.
 */
const initialize = (emitter) => {
    eventEmitter = emitter;
    console.log("WhatsApp Servisi hazır (Direct DeepLink Modu). 🚀");
};

const sendOrderNotification = (shopPhoneNumber, messageText, orderId, currentStatus) => {
    console.log(`[WhatsApp Bildirimi] -> Alıcı: ${shopPhoneNumber} | Sipariş: #${orderId} | Durum: ${currentStatus}`);
};

const sendMessage = (chatId, messageText, options = {}) => {
    console.log(`[WhatsApp Mesajı] -> Alıcı: ${chatId}`);
};

module.exports = (emitter) => {
    eventEmitter = emitter;
    return {
        initialize: () => initialize(emitter),
        sendOrderNotification,
        sendMessage,
    };
};
