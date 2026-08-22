const { Pool } = require('pg');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
    console.error('CRITICAL: DATABASE_URL is not defined in environment variables!');
}

const isLocalhost = connectionString && (connectionString.includes('localhost') || connectionString.includes('127.0.0.1'));

const pool = new Pool({
    connectionString: connectionString,
    ssl: isLocalhost ? false : { rejectUnauthorized: false },
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
});

pool.on('error', (err) => {
    console.error('Beklenmeyen veritabanı havuz hatası (idle client):', err.message);
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    pool,
    getClient: () => pool.connect(),
};
