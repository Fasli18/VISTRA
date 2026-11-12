<?php
// Instalasi baru: salin ke config.php dan isi nilai privat; jangan commit config.php.
// Instalasi yang sudah ada: sesuaikan konfigurasi produksi tanpa menimpa nilai lokal.
// Semua REPLACE_WITH_* adalah placeholder, bukan kredensial yang dapat dipakai.

define('DB_HOST', 'REPLACE_WITH_DB_HOST');
define('DB_PORT', 3306);
define('DB_NAME', 'REPLACE_WITH_DB_NAME');
define('DB_USER', 'REPLACE_WITH_DB_USER');
define('DB_PASS', 'REPLACE_WITH_DB_PASSWORD');
define('DB_CHARSET', 'utf8mb4');

define('APP_ENV', 'production');
define('APP_DEBUG', false);
// Kosong: hanya origin aplikasi sendiri. Opsional: satu origin HTTPS milik Anda,
// misalnya https://your-domain.invalid (tanpa path/trailing slash). Jangan gunakan *.
define('CORS_ORIGIN', '');

define('JWT_SECRET', 'REPLACE_WITH_STRONG_RANDOM_JWT_SECRET');
define('JWT_EXPIRE', 86400);

define('PAGE_LIMIT_DEFAULT', 20);
define('PAGE_LIMIT_MAX', 100);

// Isi URL privat yang sama dengan konfigurasi workflow n8n Anda.
// Gunakan string kosong bila n8n dinonaktifkan; fallback PHP tetap tersedia.
// Contoh ini tidak mengaktifkan autentikasi webhook baru.
define('N8N_WEBHOOK_URL', '');
