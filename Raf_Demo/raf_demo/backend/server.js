require('dotenv').config();

const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { EventEmitter } = require('events');
const db = require('./db');

const whatsappEvents = new EventEmitter();
const whatsappService = require('./whatsapp_service.js')(whatsappEvents);

const app = express();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'raf_demo_secure_jwt_secret_key_2026_x89a1b2c3d4e5f6';

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

// Ana Sayfa & Sağlık Kontrolü Endpoint'i
app.get('/', (req, res) => {
    res.json({
        success: true,
        message: 'Raf Demo Backend API başarıyla çalışıyor!',
        timestamp: new Date().toISOString()
    });
});

app.get('/api/health', (req, res) => {
    res.json({ status: 'ok', uptime: process.uptime() });
});

const httpServer = http.createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST', 'PUT', 'DELETE'],
    },
});

// --- 1. Veritabanı Tablolarını Kurma Fonksiyonu ---
async function setupDatabase() {
    try {
        console.log("PostgreSQL tabloları ve indeksleri kontrol ediliyor / oluşturuluyor...");

        // 1. Ana Tablolar
        await db.query(`
            CREATE TABLE IF NOT EXISTS master_products (
                id SERIAL PRIMARY KEY,
                product_name TEXT NOT NULL,
                category TEXT NOT NULL,
                brand TEXT NOT NULL,
                weight_volume TEXT,
                image_url TEXT,
                unit_price NUMERIC(10, 2) DEFAULT 0,
                sap_code TEXT
            );
            ALTER TABLE master_products ADD COLUMN IF NOT EXISTS unit_price NUMERIC(10, 2) DEFAULT 0;
            ALTER TABLE master_products ADD COLUMN IF NOT EXISTS sap_code TEXT;

            CREATE INDEX IF NOT EXISTS idx_master_products_category ON master_products(category);
            CREATE INDEX IF NOT EXISTS idx_master_products_brand ON master_products(brand);
            CREATE INDEX IF NOT EXISTS idx_master_products_sap_code ON master_products(sap_code);

            CREATE TABLE IF NOT EXISTS merchants (
                id SERIAL PRIMARY KEY,
                shop_name TEXT NOT NULL UNIQUE,
                owner_name TEXT NOT NULL,
                phone TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                city TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_merchants_city ON merchants(city);

            CREATE TABLE IF NOT EXISTS customers (
                id SERIAL PRIMARY KEY,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                phone TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                city TEXT
            );

            CREATE TABLE IF NOT EXISTS shop_products (
                id SERIAL PRIMARY KEY,
                shop_id INTEGER NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
                master_product_id INTEGER NOT NULL REFERENCES master_products(id) ON DELETE CASCADE,
                price NUMERIC(10, 2) NOT NULL,
                stock INTEGER NOT NULL,
                is_active INTEGER DEFAULT 1,
                UNIQUE(shop_id, master_product_id)
            );

            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                customer_id INTEGER NOT NULL REFERENCES customers(id),
                merchant_id INTEGER NOT NULL REFERENCES merchants(id),
                total_price NUMERIC(10, 2) NOT NULL,
                status TEXT NOT NULL DEFAULT 'Bekleniyor',
                payment_method TEXT NOT NULL,
                shipping_address TEXT,
                order_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
            CREATE INDEX IF NOT EXISTS idx_orders_merchant_id ON orders(merchant_id);

            CREATE TABLE IF NOT EXISTS order_items (
                id SERIAL PRIMARY KEY,
                order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
                shop_product_id INTEGER NOT NULL REFERENCES shop_products(id),
                quantity INTEGER NOT NULL CHECK(quantity > 0),
                price_at_purchase NUMERIC(10, 2) NOT NULL
            );

            CREATE TABLE IF NOT EXISTS carts (
                id SERIAL PRIMARY KEY,
                customer_id INTEGER UNIQUE REFERENCES customers(id) ON DELETE CASCADE,
                session_id TEXT UNIQUE,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS cart_items (
                id SERIAL PRIMARY KEY,
                cart_id INTEGER NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
                shop_product_id INTEGER NOT NULL REFERENCES shop_products(id) ON DELETE CASCADE,
                quantity INTEGER NOT NULL DEFAULT 1,
                UNIQUE(cart_id, shop_product_id)
            );

            CREATE TABLE IF NOT EXISTS shop_packages (
                id SERIAL PRIMARY KEY,
                shop_id INTEGER NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
                name TEXT NOT NULL,
                package_size TEXT NOT NULL,
                total_price NUMERIC(10, 2) NOT NULL,
                stock INTEGER NOT NULL DEFAULT 10,
                is_active INTEGER DEFAULT 1,
                created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_shop_packages_shop_id ON shop_packages(shop_id);

            CREATE TABLE IF NOT EXISTS shop_package_items (
                id SERIAL PRIMARY KEY,
                package_id INTEGER NOT NULL REFERENCES shop_packages(id) ON DELETE CASCADE,
                master_product_id INTEGER NOT NULL REFERENCES master_products(id) ON DELETE CASCADE,
                price NUMERIC(10, 2) NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 1
            );
            CREATE INDEX IF NOT EXISTS idx_shop_package_items_pkg ON shop_package_items(package_id);
        `);

        console.log("PostgreSQL tabloları başarıyla hazırlandı.");
        await seedMasterProducts();
        // await seedMerchant(); // Tamamen boş sıfırlama için otomatik seed devre dışı bırakıldı
    } catch (err) {
        console.error("Veritabanı kurulum hatası:", err.message);
    }
}

// --- 2. Seed Data Fonksiyonları ---
async function seedMerchant() {
    try {
        const result = await db.query("SELECT COUNT(*) as count FROM merchants");
        const count = parseInt(result.rows[0].count, 10);
        if (count === 0) {
            const passwordHash = bcrypt.hashSync('bngs123', 10);
            const insertResult = await db.query(
                'INSERT INTO merchants (shop_name, owner_name, phone, password_hash, city) VALUES ($1, $2, $3, $4, $5) RETURNING id',
                ['BengiBengi', 'Bengi', '05551112233', passwordHash, 'Istanbul']
            );
            console.log('Seed merchant kaydedildi (ID):', insertResult.rows[0].id);
        } else {
            console.log('Merchant tablosu zaten dolu, seed atlandı.');
        }
    } catch (err) {
        console.error('Merchant seed kontrolü/eklenmesi sırasında hata:', err.message);
    }
}

async function seedMasterProducts() {
    try {
        const result = await db.query("SELECT COUNT(*) as count FROM master_products");
        const count = parseInt(result.rows[0].count, 10);
        
        // 450 ürün içeren tam PDF kataloğunu yükle
        if (count < 400) {
            console.log(`master_products tablosunda ${count} ürün var. PDF'teki 450 ürün yükleniyor...`);
            let productsToSeed = [];
            try {
                productsToSeed = require('./products_seed.json');
            } catch (readErr) {
                console.error("products_seed.json okunamadı:", readErr.message);
            }

            if (productsToSeed.length > 0) {
                const client = await db.getClient();
                try {
                    await client.query('BEGIN');
                    await client.query('TRUNCATE TABLE master_products CASCADE');
                    
                    for (const p of productsToSeed) {
                        await client.query(
                            `INSERT INTO master_products (product_name, category, brand, weight_volume, unit_price, sap_code, image_url) 
                             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
                            [p.product_name, p.category, p.brand, p.weight_volume, p.unit_price, p.sap_code, p.image_url]
                        );
                    }
                    await client.query('COMMIT');
                    console.log(`${productsToSeed.length} adet PDF ürünü birim fiyatlarıyla Neon PostgreSQL'e yüklendi.`);
                } catch (insertErr) {
                    await client.query('ROLLBACK');
                    console.error("Master ürünler yüklenirken hata:", insertErr.message);
                } finally {
                    client.release();
                }
            }
        } else {
            console.log(`master_products tablosunda ${count} ürün mevcut. Seed atlandı.`);
        }
    } catch (err) {
        console.error("Master ürünler sayılırken hata:", err.message);
    }

    // Sunucu başladığında WhatsApp servisini başlat
    try {
        whatsappService.initialize(whatsappEvents);
    } catch (wErr) {
        console.error("WhatsApp servisi başlatılırken hata:", wErr.message);
    }
}

// --- 3. API Endpoint'leri ---

// GET /api/master-products -> Tüm master ürünleri veya kategoriye göre döner
app.get('/api/master-products', async (req, res) => {
    try {
        const { category, search } = req.query;
        let sql = `
            SELECT
                id,
                product_name,
                category,
                brand,
                weight_volume,
                image_url,
                unit_price::float AS unit_price,
                sap_code
            FROM master_products
        `;
        const params = [];
        const conditions = [];

        if (category && category !== 'Tümü') {
            params.push(category);
            conditions.push(`category = $${params.length}`);
        }

        if (search) {
            params.push(`%${search}%`);
            conditions.push(`(product_name ILIKE $${params.length} OR brand ILIKE $${params.length} OR sap_code ILIKE $${params.length})`);
        }

        if (conditions.length > 0) {
            sql += " WHERE " + conditions.join(" AND ");
        }

        sql += " ORDER BY id ASC";

        const result = await db.query(sql, params);
        res.json({
            message: 'Success',
            count: result.rows.length,
            data: result.rows
        });
    } catch (err) {
        console.error('Master products getirilirken hata:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET /api/shops -> Tüm dükkanları döner
app.get('/api/shops', async (req, res) => {
    try {
        const { city } = req.query;
        let sql = 'SELECT id, shop_name, city, phone FROM merchants';
        const params = [];

        if (city && city !== 'Tüm Şehirler') {
            sql += ' WHERE city = $1';
            params.push(city);
        }

        sql += ' ORDER BY shop_name ASC';

        const result = await db.query(sql, params);
        res.json(result.rows.map((row) => ({
            id: row.id,
            shop_name: row.shop_name,
            city: row.city,
            phone: row.phone,
            image_url: null,
        })));
    } catch (err) {
        console.error('Dükkanlar getirilirken hata:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET /api/products -> Belirli dükkanın ürünlerini döner
app.get('/api/products', async (req, res) => {
    const shopId = req.query.shopId || req.query.shop_id;

    if (!shopId) {
        return res.status(400).json({ error: 'shopId parametresi zorunludur.' });
    }

    try {
        const sql = `
            SELECT
                sp.id as id,
                sp.shop_id as shop_id,
                sp.master_product_id as master_product_id,
                mp.product_name as name,
                sp.price,
                sp.stock,
                mp.image_url,
                mp.category,
                mp.brand,
                mp.weight_volume,
                mp.unit_price::float as unit_price,
                mp.sap_code
            FROM shop_products sp
            JOIN master_products mp ON sp.master_product_id = mp.id
            WHERE sp.shop_id = $1
            ORDER BY mp.product_name ASC
        `;

        const result = await db.query(sql, [shopId]);
        res.json(result.rows.map((row) => ({
            id: row.id,
            shop_id: row.shop_id,
            master_product_id: row.master_product_id,
            name: row.name,
            price: row.price !== null ? parseFloat(row.price) : null,
            stock: row.stock !== null ? parseInt(row.stock, 10) : null,
            image_url: row.image_url,
            category: row.category,
            brand: row.brand,
            weight_volume: row.weight_volume,
            unit_price: row.unit_price,
            sap_code: row.sap_code,
        })));
    } catch (err) {
        console.error('Ürünler getirilirken hata:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// POST /api/products/batch -> İşletmeci paket halinde birden çok ürünü toplu ekler / günceller
app.post('/api/products/batch', authenticateMerchant, async (req, res) => {
    const { products } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    if (!Array.isArray(products) || products.length === 0) {
        return res.status(400).json({ success: false, message: 'En az bir ürün içeren bir ürün listesi gönderilmelidir.' });
    }

    const client = await db.getClient();
    try {
        await client.query('BEGIN');
        const insertedIds = [];

        for (const item of products) {
            const masterProductId = item.master_product_id || item.masterProductId;
            const price = parseFloat(item.price);
            const stock = parseInt(item.stock !== undefined ? item.stock : 10, 10);

            if (!masterProductId || isNaN(price) || isNaN(stock) || price < 0 || stock < 0) {
                throw new Error('Geçersiz ürün verisi: master_product_id, price ve stock geçerli olmalıdır.');
            }

            const sql = `
                INSERT INTO shop_products (shop_id, master_product_id, price, stock)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT(shop_id, master_product_id) DO UPDATE SET
                    price = EXCLUDED.price,
                    stock = EXCLUDED.stock
                RETURNING id;
            `;
            const result = await client.query(sql, [merchantId, masterProductId, price, stock]);
            insertedIds.push(result.rows[0].id);
        }

        await client.query('COMMIT');

        // Socket olaylarını yayınla
        io.to(`shop-${merchantId}`).emit('products-updated', { shopId: merchantId, count: insertedIds.length });
        io.to(`merchant-${merchantId}`).emit('products-updated', { shopId: merchantId, count: insertedIds.length });

        res.status(201).json({
            success: true,
            message: `${insertedIds.length} adet ürün başarıyla dükkana eklendi/güncellendi.`,
            count: insertedIds.length
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error("Toplu ürün eklenirken hata:", err.message);
        res.status(500).json({ success: false, message: err.message || 'Ürünler eklenemedi.' });
    } finally {
        client.release();
    }
});

// --- PAKET YÖNETİMİ ENDPOINT'LERİ ---

// GET /api/packages -> Belirli dükkanın tüm paketlerini ve içerdikleri ürünleri döner
app.get('/api/packages', async (req, res) => {
    const shopId = req.query.shopId || req.query.shop_id;
    if (!shopId) {
        return res.status(400).json({ error: 'shopId parametresi zorunludur.' });
    }

    try {
        const sql = `
            SELECT
                p.id,
                p.shop_id,
                m.shop_name,
                m.phone as shop_phone,
                p.name,
                p.package_size,
                p.total_price::float as total_price,
                p.stock,
                p.is_active,
                p.created_at,
                COALESCE(
                    json_agg(
                        json_build_object(
                            'id', spi.id,
                            'master_product_id', mp.id,
                            'name', mp.product_name,
                            'brand', mp.brand,
                            'category', mp.category,
                            'weight_volume', mp.weight_volume,
                            'image_url', mp.image_url,
                            'unit_price', mp.unit_price::float,
                            'price', spi.price::float,
                            'quantity', spi.quantity
                        ) ORDER BY spi.id ASC
                    ) FILTER (WHERE spi.id IS NOT NULL),
                    '[]'::json
                ) as items
            FROM shop_packages p
            JOIN merchants m ON p.shop_id = m.id
            LEFT JOIN shop_package_items spi ON p.id = spi.package_id
            LEFT JOIN master_products mp ON spi.master_product_id = mp.id
            WHERE p.shop_id = $1 AND p.is_active = 1
            GROUP BY p.id, m.shop_name, m.phone
            ORDER BY p.created_at DESC;
        `;

        const result = await db.query(sql, [shopId]);
        res.json({
            success: true,
            count: result.rows.length,
            data: result.rows
        });
    } catch (err) {
        console.error("Paketler getirilirken hata:", err.message);
        res.status(500).json({ success: false, error: err.message });
    }
});

// POST /api/packages -> İşletmeci yeni isimlendirilmiş paket oluşturur
app.post('/api/packages', authenticateMerchant, async (req, res) => {
    const { name, package_size, total_price, stock, items } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    if (!name || !package_size || total_price === undefined || !Array.isArray(items) || items.length === 0) {
        return res.status(400).json({ success: false, message: 'Eksik veya geçersiz paket bilgisi.' });
    }

    const client = await db.getClient();
    try {
        await client.query('BEGIN');

        // 1. shop_packages tablosuna paketi ekle
        const pkgSql = `
            INSERT INTO shop_packages (shop_id, name, package_size, total_price, stock)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id;
        `;
        const pkgResult = await client.query(pkgSql, [
            merchantId,
            name.trim(),
            package_size,
            parseFloat(total_price),
            parseInt(stock || 10, 10)
        ]);
        const packageId = pkgResult.rows[0].id;

        // 2. shop_package_items tablosuna ürünleri ekle
        for (const item of items) {
            const masterProductId = item.master_product_id || item.masterProductId;
            const price = parseFloat(item.price);
            const quantity = parseInt(item.quantity || 1, 10);

            const itemSql = `
                INSERT INTO shop_package_items (package_id, master_product_id, price, quantity)
                VALUES ($1, $2, $3, $4);
            `;
            await client.query(itemSql, [packageId, masterProductId, price, quantity]);

            // Ayrıca dükkanın genel ürün envanterini de senkronize et
            const syncShopProdSql = `
                INSERT INTO shop_products (shop_id, master_product_id, price, stock)
                VALUES ($1, $2, $3, $4)
                ON CONFLICT (shop_id, master_product_id) DO UPDATE SET
                    price = EXCLUDED.price,
                    stock = EXCLUDED.stock;
            `;
            await client.query(syncShopProdSql, [merchantId, masterProductId, price, parseInt(stock || 10, 10)]);
        }

        await client.query('COMMIT');

        // Socket bildirimi
        io.to(`shop-${merchantId}`).emit('packages-updated', { shopId: merchantId, packageId });
        io.to(`merchant-${merchantId}`).emit('packages-updated', { shopId: merchantId, packageId });

        res.status(201).json({
            success: true,
            message: `"${name}" paketi başarıyla oluşturuldu.`,
            packageId: packageId
        });
    } catch (err) {
        await client.query('ROLLBACK');
        console.error("Paket oluşturulurken hata:", err.message);
        res.status(500).json({ success: false, message: err.message });
    } finally {
        client.release();
    }
});

// PUT /api/packages/:id -> İşletmeci paket adını, fiyatını veya stoğunu günceller
app.put('/api/packages/:id', authenticateMerchant, async (req, res) => {
    const packageId = req.params.id;
    const { name, total_price, stock } = req.body;
    const merchantId = req.merchant?.merchantId;

    try {
        const fields = [];
        const values = [];

        if (name !== undefined) {
            values.push(name.trim());
            fields.push(`name = $${values.length}`);
        }
        if (total_price !== undefined) {
            values.push(parseFloat(total_price));
            fields.push(`total_price = $${values.length}`);
        }
        if (stock !== undefined) {
            values.push(parseInt(stock, 10));
            fields.push(`stock = $${values.length}`);
        }

        if (fields.length === 0) {
            return res.status(400).json({ success: false, message: 'Güncellenecek alan belirtilmedi.' });
        }

        values.push(packageId);
        values.push(merchantId);

        const sql = `
            UPDATE shop_packages
            SET ${fields.join(', ')}
            WHERE id = $${values.length - 1} AND shop_id = $${values.length}
            RETURNING id;
        `;

        const result = await db.query(sql, values);
        if (result.rowCount === 0) {
            return res.status(404).json({ success: false, message: 'Paket bulunamadı veya yetkisiz.' });
        }

        io.to(`merchant-${merchantId}`).emit('packages-updated', { shopId: merchantId, packageId });

        res.json({ success: true, message: 'Paket başarıyla güncellendi.' });
    } catch (err) {
        console.error("Paket güncellenirken hata:", err.message);
        res.status(500).json({ success: false, message: err.message });
    }
});

// DELETE /api/packages/:id -> İşletmeci paketi siler
app.delete('/api/packages/:id', authenticateMerchant, async (req, res) => {
    const packageId = req.params.id;
    const merchantId = req.merchant?.merchantId;

    try {
        const sql = "DELETE FROM shop_packages WHERE id = $1 AND shop_id = $2 RETURNING id;";
        const result = await db.query(sql, [packageId, merchantId]);

        if (result.rowCount === 0) {
            return res.status(404).json({ success: false, message: 'Paket bulunamadı veya yetkisiz.' });
        }

        io.to(`merchant-${merchantId}`).emit('packages-updated', { shopId: merchantId, packageId });

        res.json({ success: true, message: 'Paket başarıyla silindi.' });
    } catch (err) {
        console.error("Paket silinirken hata:", err.message);
        res.status(500).json({ success: false, message: err.message });
    }
});

// POST /api/products -> İşletmeci tek ürün ekler / günceller (UPSERT)
app.post('/api/products', authenticateMerchant, async (req, res) => {
    const { master_product_id, price, stock } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (merchantId === undefined || master_product_id === undefined || price === undefined || stock === undefined) {
        return res.status(400).json({ success: false, message: 'Eksik parametreler: master_product_id, price, stock ve merchant bilgisi zorunludur.' });
    }

    const numPrice = parseFloat(price);
    const numStock = parseInt(stock, 10);

    if (isNaN(numPrice) || isNaN(numStock) || numPrice < 0 || numStock < 0) {
        return res.status(400).json({ success: false, message: 'Fiyat ve stok geçerli sayısal değerler olmalıdır.' });
    }

    try {
        const sql = `
            INSERT INTO shop_products (shop_id, master_product_id, price, stock)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT(shop_id, master_product_id) DO UPDATE SET
                price = EXCLUDED.price,
                stock = EXCLUDED.stock
            RETURNING id, (xmax = 0) AS is_new_insert;
        `;

        const result = await db.query(sql, [merchantId, master_product_id, numPrice, numStock]);
        const row = result.rows[0];
        const shopProductId = row.id;
        const isNewInsert = row.is_new_insert;

        // Socket olaylarını yayınla
        io.to(`shop-${merchantId}`).emit('product-updated', { shopId: merchantId, shopProductId, masterProductId: master_product_id, price: numPrice, stock: numStock });
        io.to(`merchant-${merchantId}`).emit('product-updated', { shopId: merchantId, shopProductId, masterProductId: master_product_id, price: numPrice, stock: numStock });

        if (isNewInsert) {
            res.status(201).json({ success: true, message: 'Ürün dükkana başarıyla eklendi.', id: shopProductId });
        } else {
            res.status(200).json({ success: true, message: 'Ürün başarıyla güncellendi.', id: shopProductId });
        }
    } catch (err) {
        console.error("Dükkan ürünü eklerken/güncellerken hata:", err.message);
        res.status(500).json({ success: false, message: err.message });
    }
});

// PUT /api/products/:shopProductId -> İşletmeci fiyat/stok günceller
app.put('/api/products/:shopProductId', authenticateMerchant, async (req, res) => {
    const { shopProductId } = req.params;
    const { price, stock } = req.body;
    const merchantId = req.merchant?.merchantId;

    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    try {
        const checkResult = await db.query('SELECT shop_id FROM shop_products WHERE id = $1', [shopProductId]);
        const product = checkResult.rows[0];

        if (!product || product.shop_id !== merchantId) {
            return res.status(403).json({ success: false, message: 'Bu ürünü güncelleme yetkiniz yok veya ürün bulunamadı.' });
        }

        const numPrice = price !== undefined ? parseFloat(price) : null;
        const numStock = stock !== undefined ? parseInt(stock, 10) : null;

        await db.query(
            'UPDATE shop_products SET price = COALESCE($1, price), stock = COALESCE($2, stock) WHERE id = $3',
            [numPrice, numStock, shopProductId]
        );

        io.to(`shop-${merchantId}`).emit('stock-updated', { shopProductId: parseInt(shopProductId, 10), newStock: numStock, newPrice: numPrice });
        io.to(`merchant-${merchantId}`).emit('stock-updated', { shopProductId: parseInt(shopProductId, 10), newStock: numStock, newPrice: numPrice });

        res.json({ success: true, message: 'Ürün başarıyla güncellendi.' });
    } catch (err) {
        console.error('Ürün güncellenirken hata:', err.message);
        res.status(500).json({ success: false, message: 'Ürün güncellenemedi.' });
    }
});

// DELETE /api/products/:shopProductId -> İşletmeci dükkan ürününü siler
app.delete('/api/products/:shopProductId', authenticateMerchant, async (req, res) => {
    const { shopProductId } = req.params;
    const merchantId = req.merchant?.merchantId;

    try {
        const checkResult = await db.query('SELECT shop_id FROM shop_products WHERE id = $1', [shopProductId]);
        const product = checkResult.rows[0];

        if (!product || product.shop_id !== merchantId) {
            return res.status(403).json({ success: false, message: 'Bu ürünü silme yetkiniz yok veya ürün bulunamadı.' });
        }

        await db.query('DELETE FROM shop_products WHERE id = $1', [shopProductId]);

        io.to(`shop-${merchantId}`).emit('product-deleted', { shopProductId: parseInt(shopProductId, 10) });
        io.to(`merchant-${merchantId}`).emit('product-deleted', { shopProductId: parseInt(shopProductId, 10) });

        res.json({ success: true, message: 'Ürün başarıyla silindi.' });
    } catch (err) {
        console.error('Ürün silinirken hata:', err.message);
        res.status(500).json({ success: false, message: 'Ürün silinemedi.' });
    }
});

// GET /api/shops/:shopId/products -> Dükkanın ürünlerini getir
app.get('/api/shops/:shopId/products', async (req, res) => {
    const { shopId } = req.params;
    const parsedShopId = parseInt(shopId, 10);

    if (isNaN(parsedShopId) || parsedShopId <= 0) {
        return res.status(400).json({ error: 'Geçersiz dükkan ID (shopId) parametresi.' });
    }

    try {
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
                sp.shop_id = $1
            ORDER BY mp.product_name ASC
        `;

        const result = await db.query(sql, [parsedShopId]);
        res.json({
            message: 'Success',
            shop_id: parsedShopId,
            count: result.rows.length,
            data: result.rows.map(r => ({
                ...r,
                price: parseFloat(r.price),
                stock: parseInt(r.stock, 10)
            }))
        });
    } catch (err) {
        console.error("Dükkan ürünleri getirilirken hata:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// POST /api/customer/register -> Müşteri Kaydı
app.post('/api/customer/register', async (req, res) => {
    const { username, email, phone, password, city } = req.body;

    if (!username || !email || !phone || !password || !city) {
        return res.status(400).json({ success: false, message: 'Tüm alanların doldurulması zorunludur.' });
    }

    try {
        const lcUsername = username.toLowerCase();
        const lcEmail = email.toLowerCase();

        // 1. Müşteri çakışma kontrolü
        const existingCustRes = await db.query(
            "SELECT username, email, phone FROM customers WHERE LOWER(username) = $1 OR LOWER(email) = $2 OR phone = $3",
            [lcUsername, lcEmail, phone]
        );

        if (existingCustRes.rows.length > 0) {
            const existingCustomer = existingCustRes.rows[0];
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

        // 2. Satıcı çakışma kontrolü
        const existingMerchRes = await db.query(
            "SELECT phone, shop_name FROM merchants WHERE phone = $1 OR LOWER(shop_name) = $2",
            [phone, lcUsername]
        );

        if (existingMerchRes.rows.length > 0) {
            const existingMerchant = existingMerchRes.rows[0];
            if (existingMerchant.shop_name.toLowerCase() === lcUsername) {
                return res.status(409).json({ success: false, message: 'Bu kullanıcı adı bir dükkan adı olarak kullanılıyor ve alınamaz.' });
            }
            if (existingMerchant.phone === phone) {
                return res.status(409).json({ success: false, message: 'Bu telefon numarası bir dükkan hesabına kayıtlıdır.' });
            }
        }

        // 3. Kayıt İşlemi
        const passwordHash = await bcrypt.hash(password, 10);
        const insertRes = await db.query(
            'INSERT INTO customers (username, email, phone, password_hash, city) VALUES ($1, $2, $3, $4, $5) RETURNING id',
            [username, email, phone, passwordHash, city]
        );

        res.status(201).json({
            success: true,
            message: 'Kayıt başarılı! Şimdi giriş yapabilirsiniz.',
            userId: insertRes.rows[0].id
        });
    } catch (error) {
        console.error('Müşteri kaydı sırasında hata:', error.message);
        if (error.message.includes('unique constraint') || error.message.includes('duplicate key')) {
            return res.status(409).json({ success: false, message: 'Kullanıcı adı, e-posta veya telefon numarası zaten kayıtlı.' });
        }
        res.status(500).json({ success: false, message: 'Sunucu hatası nedeniyle kayıt yapılamadı.' });
    }
});

// POST /api/customer/login -> Müşteri Girişi
app.post('/api/customer/login', async (req, res) => {
    const { loginIdentifier, password } = req.body;

    if (!loginIdentifier || !password) {
        return res.status(400).json({ success: false, message: 'Kullanıcı adı/e-posta ve şifre gereklidir.' });
    }

    try {
        const result = await db.query(
            'SELECT * FROM customers WHERE LOWER(username) = LOWER($1) OR LOWER(email) = LOWER($1) LIMIT 1',
            [loginIdentifier]
        );
        const user = result.rows[0];

        if (!user) {
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri. Lütfen bilgilerinizi kontrol edin.' });
        }

        const passwordMatches = await bcrypt.compare(password, user.password_hash);
        if (!passwordMatches) {
            return res.status(401).json({ success: false, message: 'Geçersiz giriş bilgileri. Lütfen bilgilerinizi kontrol edin.' });
        }

        const token = jwt.sign({ customerId: user.id, username: user.username }, JWT_SECRET, { expiresIn: '7d' });

        res.json({
            success: true,
            token,
            user: {
                id: user.id,
                username: user.username,
                name: user.username,
                email: user.email,
                city: user.city
            }
        });
    } catch (err) {
        console.error('Müşteri login hatası:', err.message);
        res.status(500).json({ success: false, message: 'Sunucu hatası.' });
    }
});

// POST /api/merchant/login -> Satıcı Girişi
app.post('/api/merchant/login', async (req, res) => {
    const { identifier, password } = req.body;
    if (!identifier || !password) {
        return res.status(400).json({ success: false, message: 'identifier ve password gereklidir.' });
    }

    try {
        const result = await db.query(
            'SELECT * FROM merchants WHERE phone = $1 OR LOWER(shop_name) = LOWER($1) LIMIT 1',
            [identifier]
        );
        const merchant = result.rows[0];

        if (!merchant) {
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
    } catch (err) {
        console.error('Merchant login hatası:', err.message);
        res.status(500).json({ success: false, message: 'Sunucu hatası.' });
    }
});

// POST /api/merchant/register -> Satıcı Kaydı
app.post('/api/merchant/register', async (req, res) => {
    const { shop_name, owner_name, phone, password, city } = req.body;
    if (!shop_name || !owner_name || !phone || !password) {
        return res.status(400).json({ success: false, message: 'shop_name, owner_name, phone ve password gereklidir.' });
    }

    try {
        const passwordHash = isBcryptHash(password) ? password : await bcrypt.hash(password, 10);
        const result = await db.query(
            'INSERT INTO merchants (shop_name, owner_name, phone, password_hash, city) VALUES ($1, $2, $3, $4, $5) RETURNING id',
            [shop_name, owner_name, phone, passwordHash, city || null]
        );
        res.status(201).json({ success: true, message: 'Merchant başarıyla kaydedildi.', shopId: result.rows[0].id });
    } catch (err) {
        console.error('Merchant kaydı hatası:', err.message);
        if (err.message.includes('unique constraint') || err.message.includes('duplicate key')) {
            return res.status(409).json({ success: false, message: 'Bu dükkan adı veya telefon numarası zaten kayıtlı.' });
        }
        res.status(500).json({ success: false, message: 'Sunucu hatası.' });
    }
});

// POST /api/orders -> Sipariş Oluşturma (PostgreSQL Transaction)
app.post('/api/orders', authenticateCustomer, async (req, res) => {
    const customerId = req.customer?.customerId;
    const { carts, paymentMethod, shippingAddress, userName } = req.body;

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

    const client = await db.getClient();
    const stockUpdateEvents = [];
    const whatsappNotifications = [];

    try {
        await client.query('BEGIN');

        // Müşteri bilgilerini al
        const customerRes = await client.query("SELECT username, phone FROM customers WHERE id = $1", [customerId]);
        const customer = customerRes.rows[0];

        for (const [merchantId, cart] of shopCarts) {
            const items = Array.isArray(cart?.items) ? cart.items : [];
            if (items.length === 0) continue;

            const totalPrice = items.reduce((sum, item) => sum + (parseFloat(item.price) * parseInt(item.quantity, 10)), 0);

            // 1. Sipariş kaydı aç
            const orderRes = await client.query(
                `INSERT INTO orders (customer_id, merchant_id, total_price, payment_method, shipping_address) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
                [customerId, merchantId, totalPrice, paymentMethod, shippingAddress || null]
            );
            const orderId = orderRes.rows[0].id;

            // 2. Her bir ürünü ekle ve stok düş
            for (const item of items) {
                const shopProductId = item.id;
                const quantity = parseInt(item.quantity, 10);
                const price = parseFloat(item.price);
                const name = item.name;

                if (!shopProductId || !quantity || isNaN(price)) {
                    throw new Error('Sipariş kaleminde eksik bilgi: id, quantity, price zorunludur.');
                }

                // Atomik stok düşme kontrolü
                const stockUpdateRes = await client.query(
                    `UPDATE shop_products SET stock = stock - $1 WHERE id = $2 AND stock >= $1 RETURNING stock`,
                    [quantity, shopProductId]
                );

                if (stockUpdateRes.rowCount === 0) {
                    throw new Error(`Yetersiz stok: ${name}`);
                }

                const newStock = stockUpdateRes.rows[0].stock;

                // Sipariş kalemini ekle
                await client.query(
                    `INSERT INTO order_items (order_id, shop_product_id, quantity, price_at_purchase) VALUES ($1, $2, $3, $4)`,
                    [orderId, shopProductId, quantity, price]
                );

                stockUpdateEvents.push({
                    merchantId: merchantId,
                    shopProductId: shopProductId,
                    newStock: newStock,
                });
            }

            // 3. WhatsApp bildirimi için satıcı bilgisi al
            const merchantRes = await client.query("SELECT phone, shop_name FROM merchants WHERE id = $1", [merchantId]);
            const merchant = merchantRes.rows[0];

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

                whatsappNotifications.push({ phone: merchant.phone, message: message, orderId: orderId, status: 'Bekleniyor' });
            }
        }

        await client.query('COMMIT');

        // Transaction başarılı olduktan sonra socket olaylarını ve bildirimleri gönder
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
        await client.query('ROLLBACK');
        console.error('Sipariş oluşturma transaction hatası:', error.message);
        res.status(500).json({ success: false, message: error.message || 'Sipariş oluşturulamadı.' });
    } finally {
        client.release();
    }
});

// Merkezi sipariş durumu güncelleme ve bildirim fonksiyonu
async function updateOrderStatusAndNotify(orderId, newStatus, merchantId) {
    try {
        const orderRes = await db.query(`SELECT customer_id, merchant_id FROM orders WHERE id = $1`, [orderId]);
        const order = orderRes.rows[0];

        if (!order) return { success: false, message: 'Sipariş bulunamadı.' };
        if (order.merchant_id !== merchantId) return { success: false, message: 'Bu siparişi güncelleme yetkiniz yok.' };

        await db.query('UPDATE orders SET status = $1 WHERE id = $2', [newStatus, orderId]);

        const custRes = await db.query('SELECT phone FROM customers WHERE id = $1', [order.customer_id]);
        const customer = custRes.rows[0];

        const payload = { orderId: parseInt(orderId, 10), newStatus: newStatus, merchantId: merchantId };
        io.to(`customer-${order.customer_id}`).emit('order-status-updated', payload);
        io.to(`merchant-${merchantId}`).emit('order-status-updated', payload);

        if (customer && customer.phone) {
            const message = `Siparişiniz güncellendi! 📦\n\nSipariş ID: #${orderId}\n*Yeni Durum: ${newStatus}*`;
            whatsappService.sendMessage(customer.phone, message);
        }

        return { success: true, message: 'Sipariş durumu başarıyla güncellendi.' };
    } catch (error) {
        console.error(`Sipariş durumu güncelleme hatası (orderId: ${orderId}):`, error.message);
        return { success: false, message: error.message };
    }
}

// PUT /api/orders/:orderId/status -> İşletmeci sipariş durumunu günceller
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

    const result = await updateOrderStatusAndNotify(parseInt(orderId, 10), status, merchantId);

    if (result.success) {
        res.json(result);
    } else {
        const statusCode = result.message.includes('yetkiniz yok') ? 403 : result.message.includes('bulunamadı') ? 404 : 500;
        res.status(statusCode).json(result);
    }
});

// GET /api/customer/orders -> Müşteri siparişlerini döner
app.get('/api/customer/orders', authenticateCustomer, async (req, res) => {
    const customerId = req.customer?.customerId;
    if (!customerId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    try {
        const sql = `
            SELECT
                o.id,
                o.status,
                o.total_price::float AS total_price,
                o.payment_method,
                o.order_date,
                m.shop_name AS "shopName",
                COALESCE(
                    (
                        SELECT json_agg(
                            json_build_object(
                                'id', sp.id,
                                'name', mp.product_name,
                                'brand', mp.brand,
                                'quantity', oi.quantity,
                                'price', oi.price_at_purchase::float,
                                'imageUrl', mp.image_url
                            )
                        )
                        FROM order_items oi
                        JOIN shop_products sp ON oi.shop_product_id = sp.id
                        JOIN master_products mp ON sp.master_product_id = mp.id
                        WHERE oi.order_id = o.id
                    ),
                    '[]'::json
                ) AS items
            FROM orders o
            JOIN merchants m ON o.merchant_id = m.id
            WHERE o.customer_id = $1
            ORDER BY o.order_date DESC
        `;

        const result = await db.query(sql, [customerId]);
        res.json(result.rows);
    } catch (err) {
        console.error('Müşteri siparişleri getirilirken hata:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// GET /api/merchant/orders -> Satıcı siparişlerini döner
app.get('/api/merchant/orders', authenticateMerchant, async (req, res) => {
    const merchantId = req.merchant?.merchantId;
    if (!merchantId) {
        return res.status(401).json({ success: false, message: 'Yetkisiz işlem.' });
    }

    try {
        const sql = `
            SELECT
                o.id,
                o.status,
                o.total_price::float AS total_price,
                o.payment_method,
                o.order_date,
                c.username AS "customerName",
                COALESCE(
                    (
                        SELECT json_agg(
                            json_build_object(
                                'id', sp.id,
                                'name', mp.product_name,
                                'brand', mp.brand,
                                'quantity', oi.quantity,
                                'price', oi.price_at_purchase::float,
                                'imageUrl', mp.image_url
                            )
                        )
                        FROM order_items oi
                        JOIN shop_products sp ON oi.shop_product_id = sp.id
                        JOIN master_products mp ON sp.master_product_id = mp.id
                        WHERE oi.order_id = o.id
                    ),
                    '[]'::json
                ) AS items
            FROM orders o
            JOIN customers c ON o.customer_id = c.id
            WHERE o.merchant_id = $1
            ORDER BY o.order_date DESC
        `;

        const result = await db.query(sql, [merchantId]);
        res.json(result.rows);
    } catch (err) {
        console.error('Merchant orders getirirken hata:', err.message);
        res.status(500).json({ error: err.message });
    }
});

// WhatsApp'tan gelen durum güncelleme isteklerini dinle
whatsappEvents.on('status-update-request', async ({ from, orderId, newStatus }) => {
    console.log(`[WhatsApp] Gelen durum güncelleme isteği: From: ${from}, OrderID: ${orderId}, NewStatus: ${newStatus}`);

    try {
        const phone = from.substring(2).replace('@c.us', '');
        const merchantRes = await db.query('SELECT id FROM merchants WHERE phone LIKE $1', [`%${phone}`]);
        const merchant = merchantRes.rows[0];

        if (!merchant) {
            throw new Error(`Bu numaraya kayıtlı bir işletme bulunamadı: ${phone}.`);
        }

        const result = await updateOrderStatusAndNotify(orderId, newStatus, merchant.id);

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

// Socket.io Bağlantı ve Oda Yönetimi
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

// Sunucuyu ve Veritabanını Başlat
httpServer.listen(PORT, '0.0.0.0', async () => {
    console.log(`Sunucu http://0.0.0.0:${PORT} adresinde çalışıyor.`);
    console.log(`Sunucu http://localhost:${PORT} adresinde çalışıyor.`);
    await setupDatabase();
});
