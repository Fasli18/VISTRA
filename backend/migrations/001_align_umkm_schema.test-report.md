# VISTRA migration 001 — hasil pengujian

Tanggal: 10 November 2026 (Asia/Jakarta).
Server: MariaDB 10.4.28 lokal melalui socket XAMPP.
Sumber: `vistra_db` (hanya pembacaan); target: `vistra_migration_test`.

## Persiapan

- Database percobaan dibuat baru, tanpa menimpa database yang sudah ada.
- Struktur enam tabel sumber disalin tanpa data pengguna, trigger, atau perintah penghapusan tabel.
- Hanya data referensi disalin: 6 faktor dan 35 pertanyaan.
- Salinan uji sementara hanya mengganti pemeriksaan target dari `vistra_db` ke `vistra_migration_test`. Semua pemeriksaan kompatibilitas dipertahankan.
- File migrasi produksi dan database.sql tidak diubah selama pengujian.

## Hasil

| Pemeriksaan | Hasil |
|---|---|
| Migrasi pertama | Lulus, exit 0, tanpa error |
| Migrasi kedua | Lulus, exit 0, metadata identik |
| Tabel / kolom / indeks / foreign key / CHECK | 12 / 108 / 45 / 16 / 5 |
| Data referensi | Identik dengan sumber |
| Query backend | 67 statement berhasil di-PREPARE tanpa dieksekusi |
| Urutan INSERT Owner dan hubungan UMKM | Lulus |
| Undangan personal dan hubungan Employee | Lulus |
| Constraint undangan sekali pakai | Lulus |
| Submission unik per pengguna/periode | Lulus |
| Relasi periode, submission, jawaban, hasil dan enam faktor | Lulus |
| Hasil unik per UMKM/periode | Lulus |
| Penolakan hasil dengan periode dari UMKM lain | Lulus |
| platform_admin tanpa hubungan UMKM | Lulus |
| Pengaman target produksi | Menolak database percobaan sebelum DDL |
| Struktur dan data referensi sumber | Identik dengan baseline |

Jumlah kolom per tabel: users 12; submissions 18; answers 8; validation_log 8; factor_definitions 6; question_definitions 9; umkms 9; invitation_codes 11; invitation_uses 4; evaluation_periods 9; evaluation_results 10; result_factor_scores 4.

Uji relasi memakai data sintetis `example.invalid` dalam transaksi di database percobaan. Seluruh baris sintetis di-rollback; tabel operasional kembali kosong. Ini menguji skema dan urutan query, bukan login HTTP, hashing kata sandi, enkripsi undangan, atau n8n. Query dinamis diuji melalui bentuk SQL lengkap yang setara. Indeks AUTO_INCREMENT database percobaan dapat telah maju karena INSERT uji yang di-rollback.

## Bukti sumber tidak berubah

SHA-256 struktur sumber sebelum/sesudah: `ff6c97d0dec8479e4b936c8664e4214e9c1373a99edfb754e100e2782a01cefb`.

SHA-256 data referensi sumber sebelum/sesudah: `d1ce55888593647fbd594c5878561d75b586897d3af36885f0c3a507a319910e`.

Jumlah baris sumber akhir: users 0; submissions 0; answers 0; validation_log 0; factor_definitions 6; question_definitions 35.

## Artefak dan kesiapan

SQL uji, baseline, log migrasi, metadata, dan SQL pengujian PREPARE tersimpan sementara di `/var/folders/6_/w3_rwhvx0zlfh_5cznx1z0140000gn/T/vistra_migration_test_j45gz8fa`. Database `vistra_migration_test` dipertahankan untuk pemeriksaan.

Tidak ditemukan error migrasi yang membutuhkan perubahan SQL. Migrasi siap untuk eksekusi manual pada `vistra_db` dengan kondisi yang diuji, setelah persetujuan terpisah. Belum ada migrasi dijalankan pada `vistra_db`. Pengujian ini berlaku untuk MariaDB 10.4.28; eksekusi pada MySQL 8 atau server lain belum diuji. Tidak ada konfigurasi privat dibaca atau diubah, perubahan frontend/autentikasi/skor/n8n, commit, atau deploy.
