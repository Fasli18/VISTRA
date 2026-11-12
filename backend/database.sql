-- ============================================================
--  KoyoUMKM Database Schema
--  Engine : MySQL 8.0.16+ / MariaDB 10.4+
--  Charset: utf8mb4_unicode_ci
--
--  IMPORT VIA PhpMyAdmin:
--    Database > Import > pilih file ini > Execute
--
--  CATATAN: Semua data lama TIDAK dihapus.
--  Instalasi baru: impor file ini pada database yang dipilih.
--  Upgrade enam tabel lama: gunakan migrations/001_align_umkm_schema.sql.
--  Penambahan skema UMKM dijaga oleh pemeriksaan information_schema.
-- ============================================================

SET NAMES utf8mb4;
-- Foreign keys remain enabled during schema creation and validation.
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';
SET time_zone = '+07:00';

-- ============================================================
--  1. TABEL USERS  (akun login owner & pegawai)
-- ============================================================
CREATE TABLE IF NOT EXISTS `users` (
  `id`           INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `umkm_name`    VARCHAR(150)    NOT NULL                    COMMENT 'Nama resmi bisnis / UMKM',
  `email`        VARCHAR(180)    NOT NULL                    COMMENT 'Email bisnis (unik)',
  `password_hash`VARCHAR(255)    NOT NULL                    COMMENT 'bcrypt hash',
  `role`         ENUM('owner','employee') NOT NULL           COMMENT 'Peran responden',
  `lokasi`       VARCHAR(100)    DEFAULT NULL                COMMENT 'Provinsi / kota',
  `sektor`       VARCHAR(80)     DEFAULT NULL                COMMENT 'Bidang industri',
  `omzet`        BIGINT UNSIGNED DEFAULT NULL                COMMENT 'Omzet per bulan (IDR)',
  `is_active`    TINYINT(1)      NOT NULL DEFAULT 1,
  `created_at`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_email` (`email`),
  KEY `idx_role` (`role`),
  KEY `idx_sektor` (`sektor`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Akun pengguna NexaUMKM (owner & pegawai)';


-- ============================================================
--  2. TABEL SUBMISSIONS  (satu baris = satu pengiriman formulir)
-- ============================================================
CREATE TABLE IF NOT EXISTS `submissions` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`         INT UNSIGNED NOT NULL                 COMMENT 'FK → users.id',
  `role`            ENUM('owner','employee') NOT NULL     COMMENT 'Peran saat submit',
  `status`          ENUM('draft','submitted','validated','rejected')
                                NOT NULL DEFAULT 'submitted',
  `validation_pass` TINYINT(1)  NOT NULL DEFAULT 0        COMMENT '1 = lolos validasi backend',
  `submitted_at`    DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `validated_at`    DATETIME    DEFAULT NULL,
  `notes`           TEXT        DEFAULT NULL              COMMENT 'Catatan validator / admin',

  -- ── Skor per Faktor (dinormalisasi 0.0000–1.0000) ──────
  `score_ins`   DECIMAL(5,4) DEFAULT NULL COMMENT 'Sumber Daya   — INS (owner)',
  `score_ov`    DECIMAL(5,4) DEFAULT NULL COMMENT 'Budaya        — OV  (employee)',
  `score_ldi`   DECIMAL(5,4) DEFAULT NULL COMMENT 'Kepemimpinan  — LDI (employee)',
  `score_weq`   DECIMAL(5,4) DEFAULT NULL COMMENT 'Proses        — WEQ (employee)',
  `score_ops`   DECIMAL(5,4) DEFAULT NULL COMMENT 'Inovasi       — OPS (owner)',
  `score_ect`   DECIMAL(5,4) DEFAULT NULL COMMENT 'Eksternal     — ECT (owner)',
  `score_composite` DECIMAL(5,4) DEFAULT NULL            COMMENT 'Skor komposit tertimbang 0–1',
  `score_on_5`  DECIMAL(4,2) DEFAULT NULL                COMMENT 'Skor komposit skala 0–5',
  `health_category` VARCHAR(30) DEFAULT NULL             COMMENT 'SANGAT BAIK / BAIK / CUKUP / PERLU PERHATIAN',

  PRIMARY KEY (`id`),
  KEY `idx_user`   (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_submitted` (`submitted_at`),
  CONSTRAINT `fk_sub_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Header setiap pengiriman formulir SiSEHAT';


-- ============================================================
--  3. TABEL ANSWERS  (jawaban individual per pertanyaan)
--     Satu baris = satu jawaban untuk satu pertanyaan
-- ============================================================
CREATE TABLE IF NOT EXISTS `answers` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `submission_id` INT UNSIGNED NOT NULL                   COMMENT 'FK → submissions.id',
  `user_id`       INT UNSIGNED NOT NULL                   COMMENT 'FK → users.id (responden yang menjawab; owner atau pegawai)',
  `factor_key`    ENUM('INS','OV','LDI','WEQ','OPS','ECT') NOT NULL COMMENT 'Faktor kesehatan',
  `question_id`   VARCHAR(20)  NOT NULL                   COMMENT 'ID soal: ins_oh1 … weq_oh17',
  `question_code` VARCHAR(10)  NOT NULL                   COMMENT 'Kode codebook: OH-1 … OH-35',
  `answer_value`  TINYINT      NOT NULL                   COMMENT 'Nilai jawaban (1–5 atau 1–3)',
  `scale_max`     TINYINT      NOT NULL                   COMMENT 'Batas atas skala (3 atau 5)',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_sub_user_question` (`submission_id`, `user_id`, `question_id`),
  KEY `idx_ans_user` (`user_id`),
  KEY `idx_factor`   (`factor_key`),
  KEY `idx_qid`      (`question_id`),
  CONSTRAINT `fk_ans_sub` FOREIGN KEY (`submission_id`) REFERENCES `submissions`(`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_ans_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_answer_range` CHECK (`answer_value` >= 1 AND `answer_value` <= `scale_max`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Jawaban per pertanyaan tiap responden (satu submission owner bisa memuat jawaban banyak pegawai)';

-- ------------------------------------------------------------
--  3b. MIGRASI answers untuk database LAMA (aman dijalankan ulang)
--      Menambah answers.user_id agar jawaban tiap pegawai tidak
--      saling menimpa. Baris lama diisi dengan pemilik submission
--      (jawaban pegawai lama sudah tertimpa dan tidak bisa dipulihkan).
-- ------------------------------------------------------------
SET @has_col := (SELECT COUNT(*) FROM information_schema.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'answers' AND COLUMN_NAME = 'user_id');
SET @sql := IF(@has_col = 0,
  'ALTER TABLE `answers` ADD COLUMN `user_id` INT UNSIGNED NULL AFTER `submission_id`',
  'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

UPDATE `answers` a JOIN `submissions` s ON s.id = a.submission_id
   SET a.user_id = s.user_id
 WHERE a.user_id IS NULL;

SET @sql := IF(@has_col = 0,
  'ALTER TABLE `answers` MODIFY `user_id` INT UNSIGNED NOT NULL',
  'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

-- Unique key baru dibuat DULU (FK submission_id butuh indeks pendukung), baru yang lama dihapus.
SET @has_new := (SELECT COUNT(*) FROM information_schema.STATISTICS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'answers' AND INDEX_NAME = 'uq_sub_user_question');
SET @sql := IF(@has_new = 0,
  'ALTER TABLE `answers` ADD UNIQUE KEY `uq_sub_user_question` (`submission_id`,`user_id`,`question_id`)',
  'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

SET @has_old := (SELECT COUNT(*) FROM information_schema.STATISTICS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'answers' AND INDEX_NAME = 'uq_sub_question');
SET @sql := IF(@has_old > 0, 'ALTER TABLE `answers` DROP INDEX `uq_sub_question`', 'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

SET @has_fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'answers' AND CONSTRAINT_NAME = 'fk_ans_user');
SET @sql := IF(@has_fk = 0,
  'ALTER TABLE `answers` ADD KEY `idx_ans_user` (`user_id`), ADD CONSTRAINT `fk_ans_user` FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE',
  'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;


-- ============================================================
--  4. TABEL VALIDATION_LOG  (log hasil validasi backend)
-- ============================================================
CREATE TABLE IF NOT EXISTS `validation_log` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `submission_id` INT UNSIGNED NOT NULL,
  `level`         ENUM('error','warning','info') NOT NULL,
  `factor_key`    VARCHAR(10)  DEFAULT NULL,
  `field_name`    VARCHAR(30)  DEFAULT NULL,
  `error_code`    VARCHAR(40)  NOT NULL,
  `message`       TEXT         NOT NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_vlog_sub`   (`submission_id`),
  KEY `idx_vlog_level` (`level`),
  CONSTRAINT `fk_vlog_sub` FOREIGN KEY (`submission_id`) REFERENCES `submissions`(`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Log error & warning dari proses validasi';


-- ============================================================
--  5. TABEL FACTOR_DEFINITIONS  (referensi statis 6 faktor)
--     Data ini digunakan oleh dashboard untuk labeling.
-- ============================================================
CREATE TABLE IF NOT EXISTS `factor_definitions` (
  `key`         VARCHAR(5)   NOT NULL,
  `label`       VARCHAR(80)  NOT NULL,
  `role`        ENUM('owner','employee') NOT NULL,
  `weight`      DECIMAL(4,2) NOT NULL COMMENT 'Bobot dalam skor komposit (total = 1.00)',
  `scale_max`   TINYINT      NOT NULL,
  `description` VARCHAR(200) DEFAULT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Definisi 6 faktor SiSEHAT (data referensi)';

-- Insert referensi faktor — gunakan INSERT IGNORE agar tidak
-- menimpa jika sudah ada
INSERT IGNORE INTO `factor_definitions`
  (`key`, `label`, `role`, `weight`, `scale_max`, `description`) VALUES
('INS', 'Sumber Daya — Institutional Resources', 'owner',    0.20, 3, 'Ketersediaan sumber daya kelembagaan dan dukungan eksternal'),
('OV',  'Budaya — Organizational Values',        'employee', 0.18, 5, 'Nilai-nilai organisasi, budaya, dan integritas lingkungan kerja'),
('LDI', 'Kepemimpinan — Leader Involvement',     'employee', 0.17, 5, 'Keterlibatan aktif manajemen dalam operasional dan pengembangan SDM'),
('WEQ', 'Proses — Work Environment Quality',     'employee', 0.15, 5, 'Kualitas lingkungan dan proses kerja yang mendukung produktivitas'),
('OPS', 'Inovasi — Operational Stability',       'owner',    0.15, 5, 'Stabilitas operasional dan kemampuan bisnis mengelola proses harian'),
('ECT', 'Eksternal — Economic Connectivity',     'owner',    0.15, 5, 'Kinerja ekonomi dan konektivitas bisnis dengan pasar eksternal');


-- ============================================================
--  6. TABEL QUESTION_DEFINITIONS  (referensi statis 35 soal)
-- ============================================================
CREATE TABLE IF NOT EXISTS `question_definitions` (
  `id`          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `question_id` VARCHAR(20)  NOT NULL,
  `code`        VARCHAR(10)  NOT NULL,
  `factor_key`  VARCHAR(5)   NOT NULL,
  `text_id`     TEXT         NOT NULL COMMENT 'Teks Bahasa Indonesia',
  `text_en`     TEXT         NOT NULL COMMENT 'Teks Bahasa Inggris',
  `scale_max`   TINYINT      NOT NULL,
  `is_required` TINYINT(1)   NOT NULL DEFAULT 1,
  `sort_order`  SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_qid`  (`question_id`),
  UNIQUE KEY `uq_code` (`code`),
  KEY `idx_factor` (`factor_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Definisi 35 pertanyaan SiSEHAT (data referensi)';

INSERT IGNORE INTO `question_definitions`
  (`question_id`,`code`,`factor_key`,`text_id`,`text_en`,`scale_max`,`sort_order`) VALUES
-- INS (Owner, skala 1–3)
('ins_oh1','OH-1','INS','Apakah bisnis Anda memiliki Nomor Induk Berusaha (NIB)?','Does your business have a Business Identification Number (NIB)?',3,1),
('ins_oh2','OH-2','INS','Apakah Anda pernah menerima bantuan pendanaan dari pemerintah?','Have you received any government funding assistance?',3,2),
('ins_oh3','OH-3','INS','Apakah Anda pernah mengikuti kegiatan yang diselenggarakan pemerintah?','Have you participated in government-organized activities?',3,3),
('ins_oh4','OH-4','INS','Apakah Anda berkolaborasi dengan pedagang atau bisnis lain?','Do you collaborate with other merchants or businesses?',3,4),
('ins_oh5','OH-5','INS','Apakah Anda menggunakan pemasaran digital?','Do you use digital marketing?',3,5),
('ins_oh6','OH-6','INS','Apa sumber modal keuangan utama bisnis Anda?','What is the primary source of financial capital?',3,6),
-- OV (Employee, skala 1–5)
('ov_oh18','OH-18','OV','Saya merasa bebas membicarakan kesulitan kerja dengan pemimpin atau rekan','I feel free to talk about work-related difficulties with my leader or colleagues',5,7),
('ov_oh19','OH-19','OV','Suasana di tempat kerja saya positif dan mendukung','The atmosphere in my workplace is positive and supportive',5,8),
('ov_oh20','OH-20','OV','Semangat kerja karyawan di tempat kerja saya umumnya tinggi','The morale of employees in my workplace is generally high',5,9),
('ov_oh21','OH-21','OV','Karyawan di tempat kerja saya saling membantu saat dibutuhkan','Employees in my workplace help each other when needed',5,10),
('ov_oh22','OH-22','OV','Tingkat kepercayaan antar karyawan di tempat kerja saya sangat kuat','The level of trust among employees in my workplace is very strong',5,11),
('ov_oh23','OH-23','OV','Kerja tim di tempat kerja saya sangat efektif','Teamwork in my workplace is effective',5,12),
('ov_oh24','OH-24','OV','Karyawan di tempat kerja saya saling menghormati','Employees in my workplace treat each other with respect',5,13),
('ov_oh25','OH-25','OV','Karyawan di tempat kerja saya memandang pekerjaan sebagai bentuk dedikasi','Employees view their work as a form of dedication',5,14),
-- LDI (Employee, skala 1–5)
('ldi_oh7','OH-7','LDI','Pemimpin Anda terhubung dengan karyawan secara personal','Your leader connects to employees on a personal level',5,15),
('ldi_oh8','OH-8','LDI','Pemimpin Anda bertindak sebagai panutan bagi karyawan','Your leader acts as a role model for employees',5,16),
('ldi_oh9','OH-9','LDI','Pemimpin Anda terbuka untuk menerapkan ide atau saran dari karyawan','Your leader is open to implementing ideas or suggestions from employees',5,17),
('ldi_oh10','OH-10','LDI','Pemimpin Anda terlibat langsung dalam pekerjaan sehari-hari','Your leader is directly involved in day-to-day work',5,18),
('ldi_oh11','OH-11','LDI','Pemimpin Anda aktif berpartisipasi dalam melatih karyawan baru','Your leader actively participates in training new employees',5,19),
('ldi_oh12','OH-12','LDI','Pemimpin Anda memperlakukan karyawan secara adil','Your leader treats employees fairly when giving punishments and rewards',5,20),
-- WEQ (Employee, skala 1–5)
('weq_oh13','OH-13','WEQ','Tempat kerja bebas dari kecelakaan kerja','Workplace is free from job-related accidents',5,21),
('weq_oh14','OH-14','WEQ','Saya puas dengan jam kerja yang ditetapkan di perusahaan ini','I am satisfied with the working hours set in this company',5,22),
('weq_oh15','OH-15','WEQ','Beban kerja saya dapat dikelola dengan baik','My workload is manageable',5,23),
('weq_oh16','OH-16','WEQ','Kondisi kerja fisik (kebisingan, pencahayaan, suhu) nyaman','The physical working conditions are comfortable',5,24),
('weq_oh17','OH-17','WEQ','Sebagian besar karyawan bertanggung jawab dan jarang absen tanpa alasan sah','Most employees are responsible and rarely miss work without valid reasons',5,25),
-- OPS (Owner, skala 1–5)
('ops_oh26','OH-26','OPS','Modal kerja mencukupi untuk operasional bisnis sehari-hari','Working capital is adequate for daily business operations',5,26),
('ops_oh27','OH-27','OPS','Perusahaan mampu membayar gaji karyawan tepat waktu','The company is able to pay employee salaries on time',5,27),
('ops_oh28','OH-28','OPS','Peralatan/mesin dalam kondisi baik dan berfungsi optimal','The equipment/machinery is in good condition and functions optimally',5,28),
('ops_oh29','OH-29','OPS','Rantai pasokan bisnis berjalan lancar tanpa gangguan signifikan','The business supply chain runs smoothly without significant disruptions',5,29),
('ops_oh30','OH-30','OPS','Permintaan produk/jasa dapat diprediksi dengan baik','The demand for products/services is predictable',5,30),
('ops_oh31','OH-31','OPS','Kualitas hubungan jangka panjang bisnis dengan pelanggan sangat baik','The quality of long-term relationships with customers',5,31),
-- ECT (Owner, skala 1–5)
('ect_oh32','OH-32','ECT','Kemampuan bisnis kami menjangkau pasar atau pelanggan baru sangat baik',"Our business's ability to reach new markets or customers is excellent",5,32),
('ect_oh33','OH-33','ECT','Pertumbuhan penjualan bisnis kami selama setahun terakhir sangat memuaskan',"Our business's sales growth over the past year has been very satisfactory",5,33),
('ect_oh34','OH-34','ECT','Liabilitas bisnis kami (pinjaman, utang) sangat dapat dikelola',"Our business's liabilities are very manageable",5,34),
('ect_oh35','OH-35','ECT','Situasi arus kas bisnis kami sangat sehat dan stabil',"Our business's cash flow situation is very healthy and stable",5,35);


-- VIEW sengaja tidak dibuat karena shared hosting membatasi privilege CREATE VIEW.

-- BEGIN VISTRA UMKM SCHEMA 001
-- MySQL 8.0.16+ / MariaDB 10.4+; no stored-routine privileges needed.
-- No account creation, data backfill, score recalculation, or row deletion.
-- NULL links preserve legacy records; map legacy accounts/periods separately.
-- Run with the SQL client configured to STOP on errors (never --force).
-- DDL commits implicitly; back up first. This is not a transactional rollback.
-- Preflight rejects incompatible existing additions before attempting DDL.
SET @vistra_schema_ok = (DATABASE() IS NOT NULL) AND
  @@FOREIGN_KEY_CHECKS = 1
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='answers' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='validation_log' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='factor_definitions' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='question_definitions' AND ENGINE='InnoDB')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND EXTRA LIKE '%auto_increment%')
  AND EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND EXTRA LIKE '%auto_increment%')
  AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='role' AND IS_NULLABLE='NO' AND COLUMN_TYPE IN ('enum(''owner'',''employee'')','enum(''owner'',''employee'',''platform_admin'')'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id') OR EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND IS_NULLABLE='YES'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id') OR EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id' AND DATA_TYPE='int' AND LOCATE('unsigned',COLUMN_TYPE)>0 AND IS_NULLABLE='YES'))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role') OR (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role' AND NON_UNIQUE=1)='umkm_id,role,is_active')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user') OR (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user' AND NON_UNIQUE=0)='period_id,user_id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm') OR (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm')='umkm_id:umkms:id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period') OR (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period')='period_id:evaluation_periods:id')
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='owner_user_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='name' AND COLUMN_TYPE='varchar(150)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='lokasi' AND COLUMN_TYPE='varchar(100)' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='sektor' AND COLUMN_TYPE='varchar(80)' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='omzet' AND DATA_TYPE='bigint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='is_active' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 0 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND COLUMN_NAME='updated_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='uq_umkms_owner' AND NON_UNIQUE=0)='owner_user_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='uq_umkms_name' AND NON_UNIQUE=0)='name'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND INDEX_NAME='idx_umkms_active_name' AND NON_UNIQUE=1)='is_active,name'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='umkms' AND CONSTRAINT_NAME='fk_umkms_owner')='owner_user_id:users:id'
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='owner_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='invited_email' AND COLUMN_TYPE='varchar(180)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='code_hash' AND COLUMN_TYPE='char(64)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='code_encrypted' AND DATA_TYPE='text' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='max_uses' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='used_count' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='expires_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='is_active' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 0 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='uq_invitation_hash' AND NON_UNIQUE=0)='code_hash'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='idx_invitation_pending' AND NON_UNIQUE=1)='umkm_id,invited_email,is_active,used_count,expires_at'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND INDEX_NAME='idx_invitation_owner' AND NON_UNIQUE=1)='owner_id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='fk_invitation_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='fk_invitation_owner')='owner_id:users:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_codes' AND CONSTRAINT_NAME='chk_invitation_single_use' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='invitation_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='user_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND COLUMN_NAME='used_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='uq_invitation_use' AND NON_UNIQUE=0)='invitation_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND INDEX_NAME='uq_invitation_user' AND NON_UNIQUE=0)='user_id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND CONSTRAINT_NAME='fk_invitation_use_code')='invitation_id:invitation_codes:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='invitation_uses' AND CONSTRAINT_NAME='fk_invitation_use_user')='user_id:users:id'
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='period_name' AND COLUMN_TYPE='varchar(150)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='status' AND LOWER(COLUMN_TYPE)='enum(''open'',''published'',''closed'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='min_employee_responses' AND DATA_TYPE='tinyint' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='started_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='completed_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='created_by' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND COLUMN_NAME='created_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='uq_period_name' AND NON_UNIQUE=0)='umkm_id,period_name'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='uq_period_umkm' AND NON_UNIQUE=0)='id,umkm_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='idx_period_status' AND NON_UNIQUE=1)='umkm_id,status,id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND INDEX_NAME='idx_period_creator' AND NON_UNIQUE=1)='created_by'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='fk_period_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='fk_period_creator')='created_by:users:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_periods' AND CONSTRAINT_NAME='chk_period_min_employees' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO' AND EXTRA LIKE '%auto_increment%')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='umkm_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='period_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='score_composite' AND COLUMN_TYPE='decimal(5,4)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='score_on_5' AND COLUMN_TYPE='decimal(4,2)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='health_category' AND COLUMN_TYPE='varchar(30)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='respondent_count' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='status' AND LOWER(COLUMN_TYPE)='enum(''draft'',''published'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='calculated_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND COLUMN_NAME='published_at' AND COLUMN_TYPE='datetime' AND IS_NULLABLE='YES')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='uq_result_umkm_period' AND NON_UNIQUE=0)='umkm_id,period_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='idx_result_period_umkm' AND NON_UNIQUE=1)='period_id,umkm_id'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND INDEX_NAME='idx_result_published' AND NON_UNIQUE=1)='status,published_at'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='fk_result_umkm')='umkm_id:umkms:id'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='fk_result_period_umkm')='period_id:evaluation_periods:id,umkm_id:evaluation_periods:umkm_id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='evaluation_results' AND CONSTRAINT_NAME='chk_result_scores' AND CONSTRAINT_TYPE='CHECK')
  ))
  AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores') OR (
    EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND ENGINE='InnoDB' AND TABLE_COLLATION='utf8mb4_unicode_ci')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='result_id' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='factor_key' AND LOWER(COLUMN_TYPE)='enum(''ins'',''ov'',''ldi'',''weq'',''ops'',''ect'')' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='factor_score' AND COLUMN_TYPE='decimal(5,4)' AND IS_NULLABLE='NO')
    AND EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND COLUMN_NAME='respondent_count' AND DATA_TYPE='int' AND (LOCATE('unsigned',COLUMN_TYPE)>0) = 1 AND IS_NULLABLE='NO')
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND INDEX_NAME='PRIMARY' AND NON_UNIQUE=0)='result_id,factor_key'
    AND (SELECT GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND INDEX_NAME='idx_result_factor' AND NON_UNIQUE=1)='factor_key'
    AND (SELECT GROUP_CONCAT(CONCAT(COLUMN_NAME,':',REFERENCED_TABLE_NAME,':',REFERENCED_COLUMN_NAME) ORDER BY ORDINAL_POSITION) FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND CONSTRAINT_NAME='fk_factor_result')='result_id:evaluation_results:id'
    AND EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='result_factor_scores' AND CONSTRAINT_NAME='chk_result_factor_score' AND CONSTRAINT_TYPE='CHECK')
  ));
-- The deliberately missing metadata table makes PREPARE fail on bad schemas.
-- Every subsequent DDL is also gated, even if a client continues after errors.
SET @vistra_ddl = IF(@vistra_schema_ok, 'DO 0',
  'SELECT * FROM information_schema.VISTRA_ABORT_INCOMPATIBLE_SCHEMA');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='umkm_id')),
  'ALTER TABLE `users` ADD COLUMN `umkm_id` INT UNSIGNED NULL DEFAULT NULL AFTER `id`', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND COLUMN_NAME='period_id')),
  'ALTER TABLE `submissions` ADD COLUMN `period_id` INT UNSIGNED NULL DEFAULT NULL AFTER `id`', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (EXISTS (SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND COLUMN_NAME='role' AND COLUMN_TYPE='enum(''owner'',''employee'')')),
  'ALTER TABLE `users` MODIFY COLUMN `role` ENUM(''owner'',''employee'',''platform_admin'') NOT NULL COMMENT ''Peran akun; admin tidak dibuat otomatis''', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `umkms` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `owner_user_id` INT UNSIGNED NOT NULL,
  `name` VARCHAR(150) NOT NULL,
  `lokasi` VARCHAR(100) DEFAULT NULL,
  `sektor` VARCHAR(80) DEFAULT NULL,
  `omzet` BIGINT UNSIGNED DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_umkms_owner` (`owner_user_id`),
  UNIQUE KEY `uq_umkms_name` (`name`),
  KEY `idx_umkms_active_name` (`is_active`,`name`),
  CONSTRAINT `fk_umkms_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `invitation_codes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `owner_id` INT UNSIGNED NOT NULL,
  `invited_email` VARCHAR(180) NOT NULL,
  `code_hash` CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `code_encrypted` TEXT DEFAULT NULL,
  `max_uses` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `used_count` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `expires_at` DATETIME NOT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invitation_hash` (`code_hash`),
  KEY `idx_invitation_pending` (`umkm_id`,`invited_email`,`is_active`,`used_count`,`expires_at`),
  KEY `idx_invitation_owner` (`owner_id`),
  CONSTRAINT `fk_invitation_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_invitation_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_invitation_single_use` CHECK (`max_uses` = 1 AND `used_count` <= `max_uses`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `invitation_uses` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `invitation_id` INT UNSIGNED NOT NULL,
  `user_id` INT UNSIGNED NOT NULL,
  `used_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_invitation_use` (`invitation_id`),
  UNIQUE KEY `uq_invitation_user` (`user_id`),
  CONSTRAINT `fk_invitation_use_code` FOREIGN KEY (`invitation_id`) REFERENCES `invitation_codes` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_invitation_use_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `evaluation_periods` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `period_name` VARCHAR(150) NOT NULL,
  `status` ENUM(''open'',''published'',''closed'') NOT NULL DEFAULT ''open'',
  `min_employee_responses` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `started_at` DATETIME DEFAULT NULL,
  `completed_at` DATETIME DEFAULT NULL,
  `created_by` INT UNSIGNED NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_period_name` (`umkm_id`,`period_name`),
  UNIQUE KEY `uq_period_umkm` (`id`,`umkm_id`),
  KEY `idx_period_status` (`umkm_id`,`status`,`id`),
  KEY `idx_period_creator` (`created_by`),
  CONSTRAINT `fk_period_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_period_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_period_min_employees` CHECK (`min_employee_responses` BETWEEN 1 AND 50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `evaluation_results` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `umkm_id` INT UNSIGNED NOT NULL,
  `period_id` INT UNSIGNED NOT NULL,
  `score_composite` DECIMAL(5,4) NOT NULL,
  `score_on_5` DECIMAL(4,2) NOT NULL,
  `health_category` VARCHAR(30) NOT NULL,
  `respondent_count` INT UNSIGNED NOT NULL,
  `status` ENUM(''draft'',''published'') NOT NULL DEFAULT ''published'',
  `calculated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `published_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_result_umkm_period` (`umkm_id`,`period_id`),
  KEY `idx_result_period_umkm` (`period_id`,`umkm_id`),
  KEY `idx_result_published` (`status`,`published_at`),
  CONSTRAINT `fk_result_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_result_period_umkm` FOREIGN KEY (`period_id`,`umkm_id`) REFERENCES `evaluation_periods` (`id`,`umkm_id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_result_scores` CHECK (`score_composite` BETWEEN 0 AND 1 AND `score_on_5` BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (1),
  'CREATE TABLE IF NOT EXISTS `result_factor_scores` (
  `result_id` INT UNSIGNED NOT NULL,
  `factor_key` ENUM(''INS'',''OV'',''LDI'',''WEQ'',''OPS'',''ECT'') NOT NULL,
  `factor_score` DECIMAL(5,4) NOT NULL,
  `respondent_count` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`result_id`,`factor_key`),
  KEY `idx_result_factor` (`factor_key`),
  CONSTRAINT `fk_factor_result` FOREIGN KEY (`result_id`) REFERENCES `evaluation_results` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_result_factor_score` CHECK (`factor_score` BETWEEN 0 AND 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='users' AND INDEX_NAME='idx_users_umkm_role')),
  'ALTER TABLE `users` ADD KEY `idx_users_umkm_role` (`umkm_id`,`role`,`is_active`)', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND INDEX_NAME='uq_submission_period_user')),
  'ALTER TABLE `submissions` ADD UNIQUE KEY `uq_submission_period_user` (`period_id`,`user_id`)', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='users' AND CONSTRAINT_NAME='fk_users_umkm' AND CONSTRAINT_TYPE='FOREIGN KEY')),
  'ALTER TABLE `users` ADD CONSTRAINT `fk_users_umkm` FOREIGN KEY (`umkm_id`) REFERENCES `umkms` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SET @vistra_ddl = IF(@vistra_schema_ok AND (NOT EXISTS (SELECT 1 FROM information_schema.TABLE_CONSTRAINTS WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='submissions' AND CONSTRAINT_NAME='fk_sub_period' AND CONSTRAINT_TYPE='FOREIGN KEY')),
  'ALTER TABLE `submissions` ADD CONSTRAINT `fk_sub_period` FOREIGN KEY (`period_id`) REFERENCES `evaluation_periods` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT', 'DO 0');
PREPARE vistra_stmt FROM @vistra_ddl;
EXECUTE vistra_stmt;
DEALLOCATE PREPARE vistra_stmt;

SELECT IF(@vistra_schema_ok, 'VISTRA schema 001 completed; legacy NULL links are unchanged.', 'VISTRA schema 001 ABORTED: incompatible schema.') AS migration_status;
-- END VISTRA UMKM SCHEMA 001

