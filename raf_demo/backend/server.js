
const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { EventEmitter } = require('events');
const whatsappEvents = new EventEmitter();
const whatsappService = require('./whatsapp_service.js')(whatsappEvents); // WhatsApp servisini olay yöneticisi ile başlat

const app = express();
const PORT = 3001;
const JWT_SECRET = 'change_this_secret_to_a_stronger_one';

function isBcryptHash(value) {
    return typeof value === 'string' && /^\$2[aby]\$\d{2}\$/.test(value);
}

function authenticateCustomer(req, res, next) {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
        return res.status(401).json({ success: false, message: 'Kimlik doğrulama gereklidir.' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.customer = decoded; // customerId ve username içerir
        next();
    } catch (err) {
        return res.status(401).json({ success: false, message: 'Geçersiz veya süresi dolmuş token.' });
    }
}

function authenticateMerchant(req, res, next) {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (!token) {
        return res.status(401).json({ success: false, message: 'Kimlik doğrulama gereklidir.' });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.merchant = decoded;
        next();
    } catch (err) {
        return res.status(401).json({ success: false, message: 'Geçersiz veya süresi dolmuş token.' });
    }
}

app.use(cors());
app.use(express.json());

const httpServer = http.createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST'],
    },
});

// --- 1. Veritabanı Bağlantısı ---
const db = new sqlite3.Database('./database.db', (err) => {
    if (err) {
        console.error("Veritabanı bağlantı hatası:", err.message);
    } else {
        console.log("SQLite veritabanına başarıyla bağlanıldı.");
        setupDatabase();
    }
});

// --- 2. Veritabanı Tablolarını Kurma Fonksiyonu ---
function setupDatabase() {
    db.serialize(() => {
        console.log("Veritabanı tabloları ve indeksleri oluşturuluyor...");

        // Foreign key desteğini aktif et
        db.run("PRAGMA foreign_keys = ON;");

        // --- Ana Tablolar ---
        db.run(`
            CREATE TABLE IF NOT EXISTS master_products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_name TEXT NOT NULL,
                category TEXT NOT NULL,
                brand TEXT NOT NULL,
                weight_volume TEXT,
                image_url TEXT
            )
        `);
        db.run(`CREATE INDEX IF NOT EXISTS idx_master_products_category ON master_products(category)`);
        db.run(`CREATE INDEX IF NOT EXISTS idx_master_products_brand ON master_products(brand)`);

        db.run(`
            CREATE TABLE IF NOT EXISTS shop_products (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                shop_id INTEGER NOT NULL,
                master_product_id INTEGER NOT NULL,
                price NUMERIC(10, 2) NOT NULL,
                stock INTEGER NOT NULL,
                is_active INTEGER DEFAULT 1, -- Ürünü satıştan kaldırma/gizleme için flag
                FOREIGN KEY (shop_id) REFERENCES merchants (id) ON DELETE CASCADE,
                FOREIGN KEY (master_product_id) REFERENCES master_products (id) ON DELETE CASCADE,
                UNIQUE(shop_id, master_product_id)
            )
        `);

        db.run(`
            CREATE TABLE IF NOT EXISTS merchants (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                shop_name TEXT NOT NULL UNIQUE,
                owner_name TEXT NOT NULL,
                phone TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                city TEXT
            )
        `);
        db.run(`CREATE INDEX IF NOT EXISTS idx_merchants_city ON merchants(city)`);

        db.run(`
            CREATE TABLE IF NOT EXISTS customers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                phone TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                city TEXT
            )
        `);

        // --- Sipariş Tabloları (Yeniden Tasarlandı) ---
        db.run(`
            CREATE TABLE IF NOT EXISTS orders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_id INTEGER NOT NULL,
                merchant_id INTEGER NOT NULL,
                total_price NUMERIC(10, 2) NOT NULL,
                status TEXT NOT NULL DEFAULT 'Bekleniyor', -- (Bekleniyor, Hazırlanıyor, Yola Çıktı, Teslim Edildi, İptal Edildi)
                payment_method TEXT NOT NULL,
                shipping_address TEXT,
                order_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (customer_id) REFERENCES customers (id),
                FOREIGN KEY (merchant_id) REFERENCES merchants (id)
            )
        `);
        db.run(`CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id)`);
        db.run(`CREATE INDEX IF NOT EXISTS idx_orders_merchant_id ON orders(merchant_id)`);

        db.run(`
            CREATE TABLE IF NOT EXISTS order_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                order_id INTEGER NOT NULL,
                shop_product_id INTEGER NOT NULL, -- Hangi dükkan ürününün satıldığı
                quantity INTEGER NOT NULL CHECK(quantity > 0),
                price_at_purchase NUMERIC(10, 2) NOT NULL, -- Fiyatı sipariş anında sabitlemek için
                FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
                FOREIGN KEY (shop_product_id) REFERENCES shop_products (id)
            )
        `);

        // --- Kalıcı Sepet Tabloları (YENİ) ---
        db.run(`
            CREATE TABLE IF NOT EXISTS carts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                customer_id INTEGER UNIQUE, -- Bir müşterinin bir sepeti olur. NULL ise misafir sepeti.
                session_id TEXT UNIQUE,     -- Misafir sepetlerini takip için. NULL ise müşteri sepeti.
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
            )
        `);

        db.run(`
            CREATE TABLE IF NOT EXISTS cart_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                cart_id INTEGER NOT NULL,
                shop_product_id INTEGER NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1,
                FOREIGN KEY (cart_id) REFERENCES carts (id) ON DELETE CASCADE,
                FOREIGN KEY (shop_product_id) REFERENCES shop_products (id) ON DELETE CASCADE,
                UNIQUE(cart_id, shop_product_id)
            )
        `);
        console.log("Tablolar başarıyla oluşturuldu veya zaten mevcuttu.");
        seedMasterProducts();
        seedMerchant();
    });
}

// --- 3. Seed Data (Hazır Veri Doldurma) Fonksiyonu ---
function seedMerchant() {
    db.get("SELECT COUNT(*) as count FROM merchants", (err, row) => {
        if (err) {
            console.error('Merchant seed sayısı alınırken hata:', err.message);
            return;
        }
        if (row.count === 0) {
            const passwordHash = bcrypt.hashSync('bngs123', 10);
            const sql = 'INSERT INTO merchants (shop_name, owner_name, phone, password_hash, city) VALUES (?, ?, ?, ?, ?)';
            db.run(sql, ['BengiBengi', 'Bengi', '05551112233', passwordHash, 'Istanbul'], function (err) {
                if (err) {
                    console.error('Merchant seed eklenirken hata:', err.message);
                } else {
                    console.log('Seed merchant kaydedildi:', this.lastID);
                }
            });
        } else {
            console.log('Merchant tablosu zaten dolu, seed atlandı.');
        }
    });
}

function seedMasterProducts() {
    const categories = {
        "Temel Gıda": [{ name: 'Pilavlık Bulgur', brand: 'Duru', wv: '1 kg', img: 'https://images.migrosone.com/sanalmarket/product/01010100/01010100-a51563.jpg' }, { name: 'Kırmızı Mercimek', brand: 'Yayla', wv: '1 kg', img: 'https://images.migrosone.com/sanalmarket/product/01020200/01020200-c5da58.jpg' }, { name: 'Baldo Pirinç', brand: 'Torku', wv: '2.5 kg', img: 'https://images.migrosone.com/sanalmarket/product/01012111/torku-baldo-pirinc-2500-g-1e948c.jpg'}],
        "Sıvı Yağ": [{ name: 'Ayçiçek Yağı', brand: 'Yudum', wv: '2 L', img: 'https://images.migrosone.com/sanalmarket/product/04111003/04111003-a16997.jpg' }, { name: 'Sızma Zeytinyağı', brand: 'Komili', wv: '1 L', img: 'https://images.migrosone.com/sanalmarket/product/04121701/04121701-a18515.jpg' }],
        "İçecek": [{ name: 'Gazlı İçecek', brand: 'Coca-Cola', wv: '1 L', img: 'https://images.migrosone.com/sanalmarket/product/08010000/08010000-c6e80b.jpg' }, { name: 'Meyveli Gazoz', brand: 'Uludağ', wv: '1.5 L', img: 'https://images.migrosone.com/sanalmarket/product/08011504/08011504-20d014.jpg' }, { name: 'Sade Maden Suyu', brand: 'Beypazarı', wv: '6x200 ml', img: 'https://images.migrosone.com/sanalmarket/product/08050721/beypazari-sade-maden-suyu-6x200-ml-720b0d.jpg' }],
        "Unlu Mamüller": [{ name: 'Buğday Unu', brand: 'Söke', wv: '2 kg', img: 'https://images.migrosone.com/sanalmarket/product/05010701/05010701-e2f694.jpg' }, { name: 'Tost Ekmeği', brand: 'Uno', wv: '500 g', img: 'https://images.migrosone.com/sanalmarket/product/05030200/05030200-a548c2.jpg' }],
        "Şarküteri & Kahvaltılık": [{ name: 'Süzme Peynir', brand: 'Sütaş', wv: '500 g', img: 'https://images.migrosone.com/sanalmarket/product/10015705/10015705-1a357f.jpg' }, { name: 'Siyah Zeytin', brand: 'Marmarabirlik', wv: '400 g', img: 'https://images.migrosone.com/sanalmarket/product/14010156/14010156-f63991.jpg' }],
        "Et Ürünleri": [{ name: 'Dana Kangal Sucuk', brand: 'Torku', wv: '225 g', img: 'https://images.migrosone.com/sanalmarket/product/13010526/torku-dana-kangal-sucuk-225-g-956555.jpg' }, { name: 'Piliç Salam', brand: 'Pınar', wv: '75 g', img: 'https://images.migrosone.com/sanalmarket/product/13012000/13012000-84c483.jpg' }],
        "Bebek": [{ name: 'Bebek Bezi 4 Beden', brand: 'Prima', wv: '34 Adet', img: 'https://images.migrosone.com/sanalmarket/product/30010515/30010515-58253a.jpg' }, { name: 'Devam Sütü', brand: 'Aptamil', wv: '800 g', img: 'https://images.migrosone.com/sanalmarket/product/30020101/30020101-b3b28b.jpg' }],
        "Temizlik": [{ name: 'Bulaşık Deterjanı', brand: 'Fairy', wv: '1500 ml', img: 'https://images.migrosone.com/sanalmarket/product/31010115/31010115-46757b.jpg' }, { name: 'Çamaşır Suyu', brand: 'Domestos', wv: '3.5 L', img: 'https://images.migrosone.com/sanalmarket/product/31040106/31040106-93da53.jpg' }],
        "Kişisel Bakım": [{ name: 'Şampuan', brand: 'Elidor', wv: '650 ml', img: 'https://images.migrosone.com/sanalmarket/product/33030303/33030303-349f7e.jpg' }, { name: 'Katı Sabun', brand: 'Hacı Şakir', wv: '4x200 g', img: 'https://images.migrosone.com/sanalmarket/product/33010100/33010100-c08a3d.jpg' }],
        "Gıda Dışı": [{ name: 'Buzdolabı Poşeti', brand: 'Koroplast', wv: 'Orta Boy', img: 'https://images.migrosone.com/sanalmarket/product/31130102/31130102-125026.jpg' }, { name: 'Kibrit', brand: 'Kavak', wv: '10 Adet', img: 'https://images.migrosone.com/sanalmarket/product/31150100/31150100-8b1e4c.jpg' }],
        "Evcil Hayvan": [{ name: 'Yetişkin Kedi Maması', brand: 'Whiskas', wv: '1 kg', img: 'https://images.migrosone.com/sanalmarket/product/40010104/40010104-e593c9.jpg' }, { name: 'Köpek Ödül Bisküvisi', brand: 'Pedigree', wv: '150 g', img: 'https://images.migrosone.com/sanalmarket/product/40020202/40020202-b0625d.jpg' }]
    };
    
    db.get("SELECT COUNT(*) as count FROM master_products", (err, row) => {
        if (err) { console.error("Master ürünler sayılırken hata:", err.message); return; }
        if (row.count === 0) {
            console.log("`master_products` tablosu boş. Hazır veriler ekleniyor...");
            // node-sqlite3 ile toplu ekleme (bulk insert) işlemleri için transaction kullanmak
            // ve tüm işlemleri serialize bloğu içine almak en doğru yöntemdir.
            // Bu, "cannot commit - no transaction is active" hatasını önler.
            db.serialize(() => {
                db.run("BEGIN TRANSACTION");
                const stmt = db.prepare("INSERT INTO master_products (product_name, category, brand, weight_volume, image_url) VALUES (?, ?, ?, ?, ?)");
                for (const category in categories) {
                    categories[category].forEach(product => {
                        stmt.run(product.name, category, product.brand, product.wv, product.img);
                    });
                }
                stmt.finalize((err) => {
                    if (err) {
                        console.error("Seed data eklenirken hata, rollback yapılıyor:", err.message);
                        db.run("ROLLBACK");
                    } else {
                        db.run("COMMIT", (commitErr) => {
                            if (commitErr) return console.error("Transaction commit edilemedi:", commitErr.message);
                            console.log("Hazır veriler başarıyla veritabanına eklendi.");
                        });
                    }
                });
            });
        } else {
            console.log("`master_products` tablosu zaten dolu. Seed işlemi atlandı.");
        }
    });

    // Sunucu başladığında WhatsApp servisini başlat
    whatsappService.initialize(whatsappEvents);
}

// --- 4. API Endpoint'leri ---

// GET /api/master-products -> Tüm master ürünleri döner.
// GET /api/master-products?category=Temizlik -> Sadece 'Temizlik' kategorisindeki ürünleri döner.
app.get('/api/master-products', (req, res) => {
    const { category } = req.query;

    let sql = "SELECT * FROM master_products";
    const params = [];

    // Eğer bir kategori filtresi varsa, SQL sorgusuna WHERE koşulu ekle.
    if (category) {
        sql += " WHERE category = ?";
        params.push(category);
    }

    db.all(sql, params, (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json({
            message: 'Success',
            count: rows.length,
            data: rows
        });
    });
});


// GET /api/shops -> Tüm dükkanları döner.
app.get('/api/shops', (req, res) => {
    const { city } = req.query;
    let sql = 'SELECT id, shop_name, city FROM merchants';
    const params = [];

    if (city && city !== 'Tüm Şehirler') {
        sql += ' WHERE city = ?';
        params.push(city);
    }

    sql += ' ORDER BY shop_name';

    db.all(sql, params, (err, rows) => {
        if (err) {
            console.error('Dükkanlar getirilirken hata:', err.message);
            return res.status(500).json({ error: err.message });
        }

        res.json(rows.map((row) => ({
            id: row.id,
            shop_name: row.shop_name,
            city: row.city,
            image_url: null,
        })));
    });
});

// GET /api/products -> Belirli dükkanın ürünlerini döner.
app.get('/api/products', (req, res) => {
    const shopId = req.query.shopId || req.query.shop_id;

    if (!shopId) {
        return res.status(400).json({ error: 'shopId parametresi zorunludur.' });
    }

    const sql = `
        SELECT
            sp.id as id,
            sp.shop_id as shop_id,
            mp.product_name as name,
            sp.price,
            sp.stock,
            mp.image_url,
            mp.category
        FROM shop_products sp
        JOIN master_products mp ON sp.master_product_id = mp.id
        WHERE sp.shop_id = ?
        ORDER BY mp.product_name
    `;

    db.all(sql, [shopId], (err, rows) => {
        if (err) {
            console.error('Ürünler getirilirken hata:', err.message);
            return res.status(500).json({ error: err.message });
        }

        res.json(rows.map((row) => ({
            id: row.id,
            shop_id: row.shop_id,
            name: row.name,
            price: row.price,
            stock: row.stock,
            image_url: row.image_url,
            category: row.category,
        })));
    });
});

// POST /api/products -> İşletmeci, mevcut bir master ürünü kendi dükkanına ekler veya günceller (UPSERT).
// Body: { "master_product_id": 123, "price": 99.99, "stock": 50 }
app.post('/api/products', authenticateMerchant, (req, res) => {
    const { master_product_id, price, stock } = req.body;
    const merchantId = req.merchant?.merchantId;

    // Gerekli alanların kontrolü
    if (merchantId === undefined || master_product_id === undefined || price === undefined || stock === undefined) {
        return res.status(400).json({ success: false, message: 'Eksik parametreler: master_product_id, price, stock ve merchant bilgisi zorunludur.' });
    }
    // Fiyat ve stok için basit tip kontrolü
    if (typeof price !== 'number' || typeof stock !== 'number' || price < 0 || stock < 0) {
        return res.status(400).json({ success: false, message: 'Fiyat ve stok geçerli sayısal değerler olmalıdır.' });
    }

    // SQLite'ın UPSERT özelliği: Eğer (shop_id, master_product_id) kombinasyonu zaten varsa günceller, yoksa ekler.
    const sql = `
        INSERT INTO shop_products (shop_id, master_product_id, price, stock)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(shop_id, master_product_id) DO UPDATE SET
            price = excluded.price,
            stock = excluded.stock -- Yeni stok değeri doğrudan set edilir
    `;

    db.run(sql, [merchantId, master_product_id, price, stock], function(err) {
        if (err) {
            console.error("Dükkan ürünü eklerken/güncellerken hata:", err.message);
            return res.status(500).json({ success: false, message: err.message });
        }

        const isNewInsert = this.lastID > 0;
        let shopProductId = isNewInsert ? this.lastID : null; // Eğer yeni ekleme ise ID'yi al

        // Eğer güncelleme ise veya ID'yi doğrulamak gerekiyorsa, sorgula
        db.get("SELECT id FROM shop_products WHERE shop_id = ? AND master_product_id = ?",
            [merchantId, master_product_id], (err, row) => {
                if (err) {
                    console.error("Socket emit için shop_product_id bulunamadı:", err.message);
                } else if (row) {
                    shopProductId = row.id;
                }

                if (shopProductId) { // shopProductId mevcutsa socket olayını yayınla
                    io.to(`shop-${merchantId}`).emit('product-updated', { shopId: merchantId, shopProductId, masterProductId: master_product_id, price, stock });
                    io.to(`merchant-${merchantId}`).emit('product-updated', { shopId: merchantId, shopProductId, masterProductId: master_product_id, price, stock });
                }

                if (isNewInsert) {
                    res.status(201).json({ success: true, message: 'Ürün dükkana başarıyla eklendi.', id: this.lastID });
                } else if (this.changes > 0) {
                    res.status(200).json({ success: true, message: 'Ürün başarıyla güncellendi.' });
                } else {
                    res.status(200).json({ success: true, message: 'Ürün bilgileri aynı olduğu için bir değişiklik yapılmadı.' });
                }
            });
    });
});

// PUT /api/products/:shopProductId -> İşletmeci dükkan ürünü fiyat/stoğunu günceller.
// NOT: Bu endpoint artık shop_products tablosundaki 'id'yi (shop_product_id) kullanır.
app.put('/api/products/:shopProductId', authenticateMerchant, (req, res) => {
    const { shopProductId } = req.params; // Parametre adı productId'den shopProductId'ye değişti
    const { price, stock } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    // Güncellenecek ürünün gerçekten bu satıcıya ait olup olmadığını kontrol et
    db.get('SELECT shop_id FROM shop_products WHERE id = ?', [shopProductId], (err, row) => {
        if (err) {
            console.error('Ürün kontrol edilirken hata:', err.message);
            return res.status(500).json({ success: false, message: 'İşlem başarısız.' });
        }

        if (!row || row.shop_id !== merchantId) {
            return res.status(403).json({ success: false, message: 'Bu ürünü güncelleme yetkiniz yok veya ürün bulunamadı.' });
        }

        db.run('UPDATE shop_products SET price = ?, stock = ? WHERE id = ?', [price, stock, shopProductId], function (err2) {
            if (err2) {
                console.error('Ürün güncellenirken hata:', err2.message);
                return res.status(500).json({ success: false, message: 'Ürün güncellenemedi.' });
            }

            // Socket.io ile stok güncellemesini bildir
            io.to(`shop-${merchantId}`).emit('stock-updated', { shopProductId: parseInt(shopProductId), newStock: stock, newPrice: price });
            io.to(`merchant-${merchantId}`).emit('stock-updated', { shopProductId: parseInt(shopProductId), newStock: stock, newPrice: price });

            res.json({ success: true, message: 'Ürün başarıyla güncellendi.' });
        });
    });
});

// DELETE /api/products/:shopProductId -> İşletmeci dükkan ürünü siler.
// NOT: Bu endpoint artık shop_products tablosundaki 'id'yi (shop_product_id) kullanır.
app.delete('/api/products/:shopProductId', authenticateMerchant, (req, res) => {
    const { shopProductId } = req.params; // Parametre adı productId'den shopProductId'ye değişti
    const merchantId = req.merchant?.merchantId;

    // Silinecek ürünün gerçekten bu satıcıya ait olup olmadığını kontrol et
    db.get('SELECT shop_id FROM shop_products WHERE id = ?', [shopProductId], (err, row) => {
        if (err) {
            console.error('Ürün kontrol edilirken hata:', err.message);
            return res.status(500).json({ success: false, message: 'İşlem başarısız.' });
        }

        if (!row || row.shop_id !== merchantId) {
            return res.status(403).json({ success: false, message: 'Bu ürünü silme yetkiniz yok veya ürün bulunamadı.' });
        }

        db.run('DELETE FROM shop_products WHERE id = ?', [shopProductId], function (err2) {
            if (err2) {
                console.error('Ürün silinirken hata:', err2.message);
                return res.status(500).json({ success: false, message: 'Ürün silinemedi.' });
            }

            // Socket.io ile ürün silindiğini bildir
            io.to(`shop-${merchantId}`).emit('product-deleted', { shopProductId: parseInt(shopProductId) });
            io.to(`merchant-${merchantId}`).emit('product-deleted', { shopProductId: parseInt(shopProductId) });

            res.json({ success: true, message: 'Ürün başarıyla silindi.' });
        });
    });
});

// POST /api/shop-products endpoint'i artık gereksizdir, çünkü /api/products endpoint'i UPSERT işlemini yapmaktadır.
// Bu endpoint'i kaldırabiliriz veya farklı bir amaç için kullanabiliriz.
/*
app.post('/api/shop-products', (req, res) => { ... });
*/

// GET /api/shops/:shopId/products (Dükkanın Aktif Ürünlerini Getir)
// Örn: GET /api/shops/1/products
app.get('/api/shops/:shopId/products', (req, res) => {
    const { shopId } = req.params;

    // shopId'nin sayısal olup olmadığını kontrol et
    if (isNaN(shopId) || parseInt(shopId) <= 0) {
        return res.status(400).json({ error: 'Geçersiz dükkan ID (shopId) parametresi.' });
    }

    // shop_products ve master_products tablolarını JOIN ile birleştiriyoruz.
    // Bu sayede hem dükkanın belirlediği fiyat/stok bilgisine, hem de ürünün ana bilgilerine
    // tek bir sorguda ulaşıyoruz.
    const sql = `
        SELECT
            sp.id as shop_product_id,
            sp.master_product_id,
            mp.product_name,
            mp.category,
            mp.brand,
            mp.weight_volume,
            mp.image_url,
            sp.price,
            sp.stock
        FROM
            shop_products sp
        JOIN
            master_products mp ON sp.master_product_id = mp.id
        WHERE
            sp.shop_id = ?
    `;

    db.all(sql, [shopId], (err, rows) => {
        if (err) {
            console.error("Dükkan ürünleri getirilirken hata:", err.message);
            res.status(500).json({ error: err.message });
            return;
        }
        res.json({
            message: 'Success',
            shop_id: parseInt(shopId),
            count: rows.length,
            data: rows
        });
    });
});

// YENİ: Müşteri Kayıt Endpoint'i
// - Boş alan kontrolü yapar.
// - Username, email ve telefonun hem müşterilerde hem de satıcılarda benzersiz olmasını sağlar.
app.post('/api/customer/register', async (req, res) => {
    const { username, email, phone, password, city } = req.body;

    // 1. Girdi Doğrulama (Validation)
    if (!username || !email || !phone || !password || !city) {
        return res.status(400).json({ success: false, message: 'Tüm alanların doldurulması zorunludur.' });
    }

    try {
        const lcUsername = username.toLowerCase();
        const lcEmail = email.toLowerCase();

        // 2. Benzersizlik Kontrolü (Uniqueness Check)
        // Girilen bilgilerin başka bir müşteri tarafından kullanılıp kullanılmadığını kontrol et
        const existingCustomer = await new Promise((resolve, reject) => {
            db.get("SELECT username, email, phone FROM customers WHERE LOWER(username) = ? OR LOWER(email) = ? OR phone = ?", [lcUsername, lcEmail, phone], (err, row) => {
                if (err) return reject(new Error('Veritabanı hatası: Müşteri kontrolü başarısız.'));
                resolve(row);
            });
        });

        if (existingCustomer) {
            if (existingCustomer.username.toLowerCase() === lcUsername) {
                return res.status(409).json({ success: false, message: 'Bu kullanıcı adı zaten alınmış. Lütfen başka bir kullanıcı adı seçin.' });
            }
            if (existingCustomer.email.toLowerCase() === lcEmail) {
                return res.status(409).json({ success: false, message: 'Bu e-posta adresi zaten kayıtlı.' });
            }
            if (existingCustomer.phone === phone) {
                return res.status(409).json({ success: false, message: 'Bu telefon numarası zaten kayıtlı.' });
            }
        }

        // Girilen bilgilerin bir satıcı tarafından kullanılıp kullanılmadığını kontrol et
        const existingMerchant = await new Promise((resolve, reject) => {
            db.get("SELECT phone, shop_name FROM merchants WHERE phone = ? OR LOWER(shop_name) = ?", [phone, lcUsername], (err, row) => {
                if (err) return reject(new Error('Veritabanı hatası: Satıcı kontrolü başarısız.'));
                resolve(row);
            });
        });

        if (existingMerchant) {
            if (existingMerchant.shop_name.toLowerCase() === lcUsername) {
                return res.status(409).json({ success: false, message: 'Bu kullanıcı adı bir dükkan adı olarak kullanılıyor ve alınamaz.' });
            }
            if (existingMerchant.phone === phone) {
                return res.status(409).json({ success: false, message: 'Bu telefon numarası bir dükkan hesabına kayıtlıdır.' });
            }
        }

        // 3. Kayıt İşlemi
        const passwordHash = await bcrypt.hash(password, 10);
        const sql = 'INSERT INTO customers (username, email, phone, password_hash, city) VALUES (?, ?, ?, ?, ?)';
        db.run(sql, [username, email, phone, passwordHash, city], function (err) {
            if (err) {
                console.error('Müşteri kaydı hatası:', err.message);
                // SQLite'ın kendi UNIQUE kontrolü de bir güvencedir.
                if (err.message.includes('UNIQUE constraint failed')) {
                    return res.status(409).json({ success: false, message: 'Kullanıcı adı, e-posta veya telefon numarası zaten kayıtlı.' });
                }
                return res.status(500).json({ success: false, message: 'Sunucu hatası nedeniyle kayıt yapılamadı.' });
            }
            res.status(201).json({ success: true, message: 'Kayıt başarılı! Şimdi giriş yapabilirsiniz.', userId: this.lastID });
        });

    } catch (error) {
        console.error('Müşteri kaydı sırasında genel hata:', error.message);
        res.status(500).json({ success: false, message: error.message });
    }
});

// YENİ: Müşteri Giriş Endpoint'i
// - Kullanıcı adı veya e-posta ile giriş yapılmasına izin verir.
app.post('/api/customer/login', async (req, res) => {
    const { loginIdentifier, password } = req.body;

    if (!loginIdentifier || !password) {
        return res.status(400).json({ success: false, message: 'Kullanıcı adı/e-posta ve şifre gereklidir.' });
    }

    const sql = 'SELECT * FROM customers WHERE username = ? OR email = ? LIMIT 1';
    db.get(sql, [loginIdentifier, loginIdentifier], async (err, user) => {
        if (err) {
            console.error('Müşteri login hatası:', err.message);
            return res.status(500).json({ success: false, message: 'Sunucu hatası.' });
        }
        if (!user) {
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri. Lütfen bilgilerinizi kontrol edin.' });
        }

        const passwordMatches = await bcrypt.compare(password, user.password_hash);
        if (!passwordMatches) {
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri. Lütfen bilgilerinizi kontrol edin.' });
        }

        const token = jwt.sign({ customerId: user.id, username: user.username }, JWT_SECRET, { expiresIn: '7d' });

        // Flutter tarafının beklediği user objesi
        const userPayload = {
            id: user.id,
            username: user.username,
            name: user.username, // 'name' alanı için 'username' kullanılıyor
            email: user.email,
            city: user.city
        };

        res.json({
            success: true,
            token,
            user: userPayload
        });
    });
});

// MEVCUT: Satıcı Giriş Endpoint'i
app.post('/api/merchant/login', (req, res) => {
    console.log('POST /api/merchant/login payload:', req.body);
    const { identifier, password } = req.body;
    if (!identifier || !password) {
        console.log('Merchant login missing identifier or password');
        return res.status(400).json({ success: false, message: 'identifier ve password gereklidir.' });
    }

    const sql = 'SELECT * FROM merchants WHERE phone = ? OR shop_name = ? LIMIT 1';
    db.get(sql, [identifier, identifier], async (err, merchant) => {
        if (err) {
            console.error('Merchant login hatası:', err.message);
            return res.status(500).json({ success: false, message: 'Sunucu hatası.' });
        }
        if (!merchant) {
            console.log('Merchant login failed: no merchant found for identifier', identifier);
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri.' });
        }

        const submittedPassword = typeof password === 'string' ? password.trim() : '';
        let passwordMatches = false;

        if (isBcryptHash(submittedPassword)) {
            passwordMatches = submittedPassword === merchant.password_hash;
        } else {
            passwordMatches = await bcrypt.compare(submittedPassword, merchant.password_hash);
        }

        if (!passwordMatches) {
            console.log('Merchant login failed: invalid password for merchant', merchant.id);
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri.' });
        }

        const token = jwt.sign({ merchantId: merchant.id, shopName: merchant.shop_name }, JWT_SECRET, { expiresIn: '7d' });
        res.json({
            success: true,
            token,
            shopId: merchant.id,
            shopName: merchant.shop_name,
            city: merchant.city || '',
        });
    });
});

// POST /api/orders -> Sipariş oluşturur.
app.post('/api/orders', authenticateCustomer, async (req, res) => {
    // customerId'yi token'dan alıyoruz, body'den değil.
    const customerId = req.customer?.customerId;
    const { carts, paymentMethod, shippingAddress, userName } = req.body; // userName'i de alalım

    if (!carts || !paymentMethod) {
        return res.status(400).json({ success: false, message: 'Sipariş bilgileri eksik (carts, paymentMethod).' });
    }
    if (!customerId) {
        return res.status(401).json({ success: false, message: 'Geçerli bir müşteri tokeni gereklidir.' });
    }

    const shopCarts = Object.entries(carts || {});
    if (shopCarts.length === 0) {
        return res.status(400).json({ success: false, message: 'Sepet boş.' });
    }

    // Tüm siparişleri bir veritabanı transaction'ı içinde işleyelim.
    db.serialize(async () => {
        const stockUpdateEvents = [];
        const whatsappNotifications = [];

        try {
            await new Promise((resolve, reject) => {
                db.run('BEGIN TRANSACTION', err => err ? reject(err) : resolve());
            });

            // Müşteri bilgilerini (özellikle telefon) bildirim için alalım.
            const customer = await new Promise((resolve, reject) => {
                if (!customerId) return resolve(null);
                db.get("SELECT username, phone FROM customers WHERE id = ?", [customerId], (err, row) => {
                    if (err) return reject(new Error('Müşteri bilgisi alınamadı.'));
                    resolve(row);
                });
            });

            for (const [merchantId, cart] of shopCarts) {
                const items = Array.isArray(cart?.items) ? cart.items : [];
                if (items.length === 0) continue;

                // 1. Toplam fiyatı hesapla ve sipariş kaydını oluştur
                const totalPrice = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
                const orderId = await new Promise((resolve, reject) => {
                    const sql = `INSERT INTO orders (customer_id, merchant_id, total_price, payment_method, shipping_address) VALUES (?, ?, ?, ?, ?)`;
                    db.run(sql, [customerId, merchantId, totalPrice, paymentMethod, shippingAddress || null], function (err) {
                        if (err) return reject(new Error(`Sipariş oluşturulurken hata: ${err.message}`));
                        resolve(this.lastID);
                    });
                });

                // 2. Her bir ürünü 'order_items' tablosuna ekle ve stoğu güncelle
                for (const item of items) {
                    const { id: shopProductId, quantity, price, name } = item;
                    if (!shopProductId || !quantity || price === undefined) {
                       return reject(new Error('Sipariş kaleminde eksik bilgi: id, quantity, price zorunludur.'));
                    }

                    // 2a. Stok kontrolü ve güncelleme
                    const stockUpdateResult = await new Promise((resolve, reject) => {
                        const stockUpdateSql = `UPDATE shop_products SET stock = stock - ? WHERE id = ? AND stock >= ?`;
                        db.run(stockUpdateSql, [quantity, shopProductId, quantity], function(err) {
                            if (err) return reject(new Error(`Stok güncellenemedi: ${err.message}`));
                            if (this.changes === 0) return reject(new Error(`Yetersiz stok: ${name}`));
                            
                            db.get('SELECT stock FROM shop_products WHERE id = ?', [shopProductId], (err, row) => {
                                if (err || !row) return reject(new Error('Yeni stok seviyesi alınamadı.'));
                                resolve({ newStock: row.stock });
                            });
                        });
                    });

                    // 2b. Sipariş kalemini ekle
                    await new Promise((resolve, reject) => {
                        const sql = `INSERT INTO order_items (order_id, shop_product_id, quantity, price_at_purchase) VALUES (?, ?, ?, ?)`;
                        db.run(sql, [orderId, shopProductId, quantity, price], (err) => {
                            if (err) return reject(new Error(`Sipariş kalemi eklenirken hata: ${err.message}`));
                            resolve();
                        });
                    });

                    // 2c. Socket olayı için veriyi sakla
                    stockUpdateEvents.push({
                        merchantId: merchantId,
                        shopProductId: shopProductId,
                        newStock: stockUpdateResult.newStock,
                    });
                }

                // 3. WhatsApp bildirimi için veriyi sakla
                const merchant = await new Promise((resolve, reject) => {
                    db.get("SELECT phone, shop_name FROM merchants WHERE id = ?", [merchantId], (err, row) => {
                        if (err) return reject(new Error('Satıcı bilgisi alınamadı.'));
                        resolve(row);
                    });
                });

                if (merchant && merchant.phone) {
                    const customerNameForMsg = userName || customer?.username || 'Bir müşteri';
                    const customerPhone = customer?.phone || 'Belirtilmedi';
                    const customerAddress = shippingAddress || 'Adres belirtilmedi';

                    let message = `🔔 *YENİ SİPARİŞ GELDİ!* 🔔\n`;
                    message += `----------------------------------\n`;
                    message += `👤 *Müşteri:* ${customerNameForMsg}\n`;
                    message += `📞 *Telefon:* ${customerPhone}\n`;
                    message += `📍 *Adres:* ${customerAddress}\n`;
                    message += `----------------------------------\n`;
                    message += `🛒 *Sipariş Detayı:*\n`;
                    items.forEach(item => {
                        const itemTotal = item.price * item.quantity;
                        message += `* ${item.quantity}x ${item.name} (${itemTotal.toFixed(2)} TL)\n`;
                    });
                    message += `----------------------------------\n`;
                    message += `💰 *Toplam Tutar:* ${totalPrice.toFixed(2)} TL\n`;
                    message += `💳 *Ödeme Yöntemi:* ${paymentMethod}\n`;
                    message += `----------------------------------\n`;
                    message += `Lütfen siparişi hazırlamaya başlayın!`;
                    // Butonların gönderilebilmesi için orderId ve status bilgisi ile birlikte kuyruğa ekliyoruz.
                    whatsappNotifications.push({ phone: merchant.phone, message: message, orderId: orderId, status: 'Bekleniyor' });
                }
            }

            await new Promise((resolve, reject) => {
                db.run('COMMIT', err => err ? reject(err) : resolve());
            });

            // Transaction başarılı, şimdi olayları yayınla ve bildirimleri gönder
            stockUpdateEvents.forEach(event => {
                io.to(`shop-${event.merchantId}`).emit('stock-updated', {
                    shopProductId: event.shopProductId,
                    newStock: event.newStock,
                });
            });
            whatsappNotifications.forEach(notification => {
                whatsappService.sendOrderNotification(notification.phone, notification.message, notification.orderId, notification.status);
            });

            res.status(201).json({ success: true, message: 'Siparişler başarıyla oluşturuldu.' });

        } catch (error) {
            await new Promise(resolve => db.run('ROLLBACK', () => resolve()));
            console.error('Sipariş oluşturma transaction hatası:', error.message);
            res.status(500).json({ success: false, message: error.message || 'Sipariş oluşturulamadı.' });
        }
    });
});

/**
 * Sipariş durumunu güncelleyen, socket ve WhatsApp bildirimlerini gönderen merkezi fonksiyon.
 * @param {number} orderId - Güncellenecek siparişin ID'si.
 * @param {string} newStatus - Siparişin yeni durumu.
 * @param {number} merchantId - İşlemi yapan işletmenin ID'si.
 * @returns {Promise<{success: boolean, message: string}>} - İşlem sonucu.
 */
async function updateOrderStatusAndNotify(orderId, newStatus, merchantId) {
    try {
        // 1. Siparişin varlığını ve bu satıcıya ait olduğunu doğrula.
        const order = await new Promise((resolve, reject) => {
            const sql = `SELECT customer_id, merchant_id FROM orders WHERE id = ?`;
            db.get(sql, [orderId], (err, row) => {
                if (err) return reject(new Error('Sipariş kontrol edilirken veritabanı hatası.'));
                if (!row) return reject(new Error('Sipariş bulunamadı.'));
                if (row.merchant_id !== merchantId) return reject(new Error('Bu siparişi güncelleme yetkiniz yok.'));
                resolve(row);
            });
        });

        // 2. Durumu güncelle
        await new Promise((resolve, reject) => {
            db.run('UPDATE orders SET status = ? WHERE id = ?', [newStatus, orderId], function(err) {
                if (err) return reject(new Error('Sipariş durumu güncellenirken hata.'));
                if (this.changes === 0) return reject(new Error('Durum zaten aynı olduğu için güncelleme yapılmadı.'));
                resolve();
            });
        });

        // 3. Müşteri telefonunu al (WhatsApp bildirimi için)
        const customer = await new Promise((resolve, reject) => {
            db.get('SELECT phone FROM customers WHERE id = ?', [order.customer_id], (err, row) => {
                if (err) return reject(new Error('Müşteri bilgisi alınamadı.'));
                resolve(row);
            });
        });

        // 4. Socket.io ile hem müşteriye hem de işletmeciye bildirim gönder
        const payload = { orderId: parseInt(orderId), newStatus: newStatus, merchantId: merchantId };
        io.to(`customer-${order.customer_id}`).emit('order-status-updated', payload);
        io.to(`merchant-${merchantId}`).emit('order-status-updated', payload);

        // 5. Müşteriye WhatsApp ile bildirim gönder
        if (customer && customer.phone) {
            let message = `Siparişiniz güncellendi! 📦\n\nSipariş ID: #${orderId}\n*Yeni Durum: ${newStatus}*`;
            // ... (mesaj içeriği özelleştirilebilir)
            whatsappService.sendMessage(customer.phone, message);
        }

        return { success: true, message: 'Sipariş durumu başarıyla güncellendi.' };

    } catch (error) {
        console.error(`Sipariş durumu güncelleme hatası (orderId: ${orderId}):`, error.message);
        return { success: false, message: error.message };
    }
}

// PUT /api/orders/:orderId/status -> İşletmeci sipariş durumunu günceller.
app.put('/api/orders/:orderId/status', authenticateMerchant, async (req, res) => {
    const { orderId } = req.params;
    const { status } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (!status) {
        return res.status(400).json({ success: false, message: 'Yeni durum (status) bilgisi gereklidir.' });
    }

    const allowedStatus = ['Hazırlanıyor', 'Yola Çıktı', 'Teslim Edildi', 'İptal Edildi'];
    if (!allowedStatus.includes(status)) {
        return res.status(400).json({ success: false, message: 'Geçersiz durum bilgisi.' });
    }

    const result = await updateOrderStatusAndNotify(parseInt(orderId), status, merchantId);

    if (result.success) {
        res.json(result);
    } else {
        const statusCode = result.message.includes('yetkiniz yok') ? 403 : result.message.includes('bulunamadı') ? 404 : 500;
        res.status(statusCode).json(result);
    }
});

// GET /api/customer/orders -> Müşteri siparişlerini döner.
app.get('/api/customer/orders', authenticateCustomer, (req, res) => {
    const customerId = req.customer?.customerId;
    if (!customerId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    const sql = `
        SELECT
            o.id,
            o.status,
            o.total_price,
            o.payment_method,
            o.order_date,
            m.shop_name as shopName,
            (
                SELECT
                    '[' || GROUP_CONCAT(
                        json_object(
                            'id', sp.id,
                            'name', mp.product_name,
                            'brand', mp.brand,
                            'quantity', oi.quantity,
                            'price', oi.price_at_purchase,
                            'imageUrl', mp.image_url
                        )
                    ) || ']'
                FROM order_items oi
                JOIN shop_products sp ON oi.shop_product_id = sp.id
                JOIN master_products mp ON sp.master_product_id = mp.id
                WHERE oi.order_id = o.id
            ) as items
        FROM orders o
        JOIN merchants m ON o.merchant_id = m.id
        WHERE o.customer_id = ?
        ORDER BY o.order_date DESC
    `;

    db.all(sql, [customerId], (err, rows) => {
        if (err) {
            console.error('Müşteri siparişleri getirilirken hata:', err.message);
            return res.status(500).json({ error: err.message });
        }

        const orders = rows.map(row => ({
            ...row,
            items: JSON.parse(row.items || '[]'),
        }));

        res.json(orders);
    });
});

// POST /api/merchant/register
app.post('/api/merchant/register', async (req, res) => {
    const { shop_name, owner_name, phone, password, city } = req.body;
    if (!shop_name || !owner_name || !phone || !password) {
        return res.status(400).json({ success: false, message: 'shop_name, owner_name, phone ve password gereklidir.' });
    }

    const passwordHash = isBcryptHash(password) ? password : await bcrypt.hash(password, 10);
    const sql = 'INSERT INTO merchants (shop_name, owner_name, phone, password_hash, city) VALUES (?, ?, ?, ?, ?)';
    db.run(sql, [shop_name, owner_name, phone, passwordHash, city || null], function (err) {
        if (err) {
            console.error('Merchant kaydı hatası:', err.message);
            if (err.message.includes('UNIQUE constraint failed')) {
                return res.status(409).json({ success: false, message: 'Bu telefon numarası zaten kayıtlı.' });
            }
            return res.status(500).json({ success: false, message: 'Sunucu hatası.' });
        }
        res.status(201).json({ success: true, message: 'Merchant başarıyla kaydedildi.', shopId: this.lastID });
    });
});

// GET /api/merchant/orders
app.get('/api/merchant/orders', authenticateMerchant, (req, res) => {
    const merchantId = req.merchant?.merchantId;
    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    // Bu sorgu, her sipariş için müşteri adını ve sipariş kalemlerini JSON dizisi olarak birleştirir.
    const sql = `
        SELECT
            o.id,
            o.status,
            o.total_price,
            o.payment_method,
            o.order_date,
            c.username as customerName,
            (
                SELECT
                    '[' || GROUP_CONCAT(
                        json_object(
                            'id', sp.id,
                            'name', mp.product_name,
                            'brand', mp.brand,
                            'quantity', oi.quantity,
                            'price', oi.price_at_purchase,
                            'imageUrl', mp.image_url
                        )
                    ) || ']'
                FROM order_items oi
                JOIN shop_products sp ON oi.shop_product_id = sp.id
                JOIN master_products mp ON sp.master_product_id = mp.id
                WHERE oi.order_id = o.id
            ) as items
        FROM orders o
        JOIN customers c ON o.customer_id = c.id
        WHERE o.merchant_id = ?
        ORDER BY o.order_date DESC
    `;

    db.all(sql, [merchantId], (err, rows) => {
        if (err) {
            console.error('Merchant orders getirirken hata:', err.message);
            return res.status(500).json({ error: err.message });
        }

        // GROUP_CONCAT sonucu bir string'dir, JSON'a parse etmemiz gerekir.
        const orders = rows.map(row => ({
            ...row,
            items: JSON.parse(row.items || '[]'),
        }));

        res.json(orders);
    });
});

// YENİ: WhatsApp'tan gelen durum güncelleme isteklerini dinle
whatsappEvents.on('status-update-request', async ({ from, orderId, newStatus }) => {
    console.log(`[WhatsApp] Gelen durum güncelleme isteği: From: ${from}, OrderID: ${orderId}, NewStatus: ${newStatus}`);
    
    try {
        // Telefon numarasını veritabanı formatına çevir (örn: 05xxxxxxxxx)
        const phone = from.substring(2).replace('@c.us', '');

        // Telefon numarasından işletmeyi bul
        const merchant = await new Promise((resolve, reject) => {
            db.get('SELECT id FROM merchants WHERE phone LIKE ?', [`%${phone}`], (err, row) => {
                if (err) return reject(new Error('İşletme aranırken veritabanı hatası.'));
                resolve(row);
            });
        });

        if (!merchant) {
            throw new Error(`Bu numaraya kayıtlı bir işletme bulunamadı: ${phone}.`);
        }

        // Merkezi güncelleme fonksiyonunu çağır
        const result = await updateOrderStatusAndNotify(orderId, newStatus, merchant.id);

        // İşletmeciye WhatsApp üzerinden geri bildirim gönder
        if (result.success) {
            whatsappService.sendMessage(from, `Sipariş #${orderId} durumu başarıyla "${newStatus}" olarak güncellendi. ✅`);
        } else {
            whatsappService.sendMessage(from, `Hata: Sipariş #${orderId} güncellenemedi. Sebep: ${result.message} ❌`);
        }
    } catch (error) {
        console.error('[WhatsApp] Durum güncelleme işlenirken hata:', error.message);
        whatsappService.sendMessage(from, `İsteğiniz işlenirken bir sunucu hatası oluştu. 😞`);
    }
});

io.on('connection', (socket) => {
    console.log('Yeni socket bağlantısı:', socket.id);

    socket.on('join-shop-room', (shopId) => {
        if (shopId != null) {
            const roomName = `shop-${shopId}`;
            socket.join(roomName);
            console.log(`Socket ${socket.id} shop rooma katıldı: ${roomName}`);
        }
    });

    socket.on('join-customer-room', (customerId) => {
        if (customerId != null) {
            const roomName = `customer-${customerId}`;
            socket.join(roomName);
            console.log(`Socket ${socket.id} customer rooma katıldı: ${roomName}`);
        }
    });

    socket.on('join-merchant-room', (shopId) => {
        if (shopId != null) {
            const roomName = `merchant-${shopId}`;
            socket.join(roomName);
            console.log(`Socket ${socket.id} merchant rooma katıldı: ${roomName}`);
        }
    });

    socket.on('disconnect', () => {
        console.log('Socket bağlantısı kapandı:', socket.id);
    });
});

// --- Sunucuyu Başlat ---
httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`Sunucu http://0.0.0.0:3001 adresinde çalışıyor.`);
    console.log(`Sunucu http://localhost:3001 adresinde çalışıyor.`);
});
