# VISTRA V3 — Pre-publication Security Hardening

Tanggal selesai: 12 November 2026. Ruang lingkup: source lokal dan paket deployment; tidak melakukan commit, push atau deployment.

## Kesimpulan

Pengamanan lokal diterapkan dan lulus pengujian Apache, API, browser serta validator. **Konfigurasi akun hosting, domain, HTTPS dan penegakan aturan pada InfinityFree belum diverifikasi.** Ini bukan pernyataan bahwa seluruh risiko keamanan aplikasi sudah tertutup.

Database utama vistra_db tidak digunakan untuk pengujian tulis. Konfigurasi privat asli tidak dibaca/ditampilkan/diedit. Empat diagnostik lokal tetap ada dan tidak diedit atau dieksekusi. Tidak memanggil n8n eksternal dan tidak menyentuh proyek/database lain.

## Masalah dan perbaikan

| Temuan | Perbaikan | Hasil |
| --- | --- | --- |
| Belum ada proteksi HTTP root untuk SQL, laporan, config, log dan backup | .htaccess root menolak direktori privat, dotfiles, dump/arsip, laporan dan ekstensi sensitif; listing direktori dinonaktifkan. | PASS di Apache lokal dan salinan QA. |
| Diagnostik hanya dilindungi ignore Git | Pemblokiran nama empat endpoint pada root/backend dan pengecualian dari allowlist paket rilis. | PASS; stub diagnostik QA tidak pernah dieksekusi. |
| Include PHP/config dapat diminta langsung melalui HTTP | backend/php/.htaccess menolak semua akses HTTP; PHP tetap dapat require file tersebut. | PASS; API/login tetap berfungsi. |
| Debug dapat membocorkan exception/PDO pada produksi | Bootstrap error sebelum config, display_errors off, respons generik + error_ref; debug hanya boleh pada environment local/development/test yang eksplisit. APP_DEBUG=true tidak membuka detail pada APP_ENV=production. | PASS pada kegagalan DB, config hilang/rusak, warning dan exception. |
| Log exception sebelumnya menyalin pesan mentah | Log error aplikasi kini hanya mencatat referensi dan jenis exception, tanpa SQL/payload/koneksi/token. | PASS dengan canary sintetis. |
| CORS mengandalkan satu nilai konfigurasi tanpa validasi origin | Same-origin tetap tersedia; origin tambahan harus cocok persis dengan konfigurasi. Wildcard, null, userinfo, path dan origin penyerupaan ditolak. API tanpa Origin tetap memerlukan autentikasi seperti sebelumnya. | PASS; preflight dan login browser sah lulus. |
| Nomor kontak langsung pada tautan WhatsApp tidak terverifikasi kepemilikannya | Mengganti tujuan CTA lama dengan Pusat Bantuan internal, tanpa mempublikasikan nomor tersebut. | Dihapus dari kandidat Git; tidak mengganti layout/desain. |
| Contoh config berisi URL placeholder yang bisa disangka webhook aktif | CORS dan n8n default kosong: same-origin dan fallback PHP. DB/JWT tetap placeholder, APP_ENV production dan APP_DEBUG false. | Aman dipublikasikan; bukan konfigurasi siap dipakai. |
| Upload folder proyek mentah berisiko membawa file privat | Manifest 22 file runtime + pembuat paket allowlist. Config, diagnostik, SQL, laporan, tools, Git dan backup tidak disalin. | PASS; hash paket cocok dengan sumber. |
| Ignore belum mencakup semua kelas artefak lokal | Mempertahankan aturan lama; menambah dump, arsip, kunci privat, data ekspor, log dan keluaran rilis. SQL sumber/migrasi bernomor tetap kandidat Git. | PASS pada 12 kasus ignore dan tiga pengecualian sumber. |
| Header dasar belum seragam | nosniff, Referrer-Policy, SAMEORIGIN dan CSP terbatas untuk object/base/frame; API memakai no-store. | PASS; grafik, inline UI dan popup PDF tetap bekerja. |

CORS bukan pengganti otorisasi. Backend tetap memeriksa token, role dan kepemilikan UMKM. Tidak mengubah algoritma autentikasi, formula skor, skema, desain V3, kontrak jawaban atau workflow n8n.

## Audit kandidat Git

Audit memakai git status --short --ignored, git ls-files dan git ls-files --others --exclude-standard. Hasil akhir: **37 file kandidat, 0 file tracked, belum ada commit**. Daftar kandidat akhir dan hasil pemindaian berada pada artefak lokal yang disebut di bagian bukti.

- config.php, .env/.env.* privat dan empat diagnostik tidak menjadi kandidat Git. Tidak menjalankan git add atau force-add.
- Pemindaian kandidat memeriksa pola secret/token/private key, penugasan kredensial, URL keluar, kontak, SQL, migrasi, laporan dan artefak pengujian. Tidak ditemukan kredensial aktif, token literal, JWT tersimpan, private key, URL webhook privat atau dump data pengguna pada kandidat yang diperiksa.
- INSERT pada SQL kandidat hanya mengisi factor_definitions dan question_definitions. database.sql dan migrasi adalah sumber skema, bukan backup data pribadi.
- Tiga temuan email pada frontend adalah placeholder input generik, bukan data akun. Laporan QA memuat akun sintetis dan jalur artefak lokal, bukan data pengguna utama.
- Tujuan frontend eksternal yang tersisa adalah CDN/font dan namespace SVG publik. URL localhost/127.0.0.1 pada dokumentasi adalah referensi QA. Tidak ditemukan URL request yang mengarah ke KARSA, KoyoUMKM atau server teman pada kandidat Git.
- Dua diagnostik lokal yang diabaikan masih memiliki referensi webhook/tunnel. Nilai tidak ditampilkan; file tetap lokal, ditolak melalui HTTP dan tidak masuk paket rilis. Ini bukan alasan untuk menyalin folder backend mentah.
- Nilai config.php asli sengaja tidak diperiksa. Kepemilikan/ketepatan domain CORS, kekuatan JWT secret, kredensial hosting dan URL webhook produksi masih perlu pemeriksaan privat oleh pemilik. Tidak dapat disimpulkan aman hanya karena file diabaikan Git.

Bukti git check-ignore -v:

| File/pola | Aturan efektif |
| --- | --- |
| backend/php/config.php | .gitignore:2 |
| .env | .gitignore:3 |
| .env.production | .gitignore:4 |
| backend/check_n8n_temp.php | .gitignore:21 |
| backend/test_n8n.php | .gitignore:22 |
| backend/test.php | .gitignore:23 |
| backend/tesadmin.php | .gitignore:24 |

Ignore tidak melindungi file yang kelak dipaksa masuk Git dan tidak menghapus riwayat lama. Saat audit ini riwayat commit memang belum ada. Pemindaian berbasis pola disertai peninjauan sumber bukan jaminan dapat mengenali semua kemungkinan secret di masa depan.

## File yang diubah/dibuat

| File | Tujuan |
| --- | --- |
| .gitignore | Menambah kelas artefak privat tanpa menghapus aturan sebelumnya. |
| .htaccess | Proteksi HTTP root, larangan listing dan header dasar. |
| backend/.htaccess | Menolak diagnostik/include/migrasi sambil mempertahankan penerusan Authorization. |
| backend/php/.htaccess | Menolak akses HTTP langsung ke include/config. |
| backend/php/security.php | Bootstrap error, logging tersanitasi dan pemeriksaan CORS. |
| backend/api.php | Memuat bootstrap, memakai CORS terkontrol dan error response generik. |
| backend/php/db.php | Respons kegagalan koneksi melalui handler aman. |
| backend/php/config.example.php | Default produksi dan placeholder tanpa webhook aktif. |
| index.html | Menghapus tujuan kontak langsung yang tidak terverifikasi; CTA menuju Help. |
| deployment/public-files.txt | Allowlist eksplisit 22 file runtime. |
| tools/build_release.py | Membangun folder runtime baru tanpa mengakses Git, database atau hosting. |
| docs/VISTRA_PREDEPLOY_SECURITY.md | Laporan dan panduan deployment ini. |

Backup sumber sebelum perubahan berada di `/tmp/vistra-security-9a4b85c6/backup/`, di luar folder publikasi dan tanpa konfigurasi privat.

## Pembagian file untuk Git dan hosting

| Kategori | Boleh di Git? | Upload ke web root? |
| --- | --- | --- |
| index.html, css, js, API/admin dan include runtime | Ya | Ya, sesuai manifest. |
| .htaccess root/backend/backend/php | Ya | Wajib ikut paket. |
| backend/php/config.example.php | Ya, placeholder saja | Tidak diperlukan; paket mengecualikannya. |
| backend/php/config.php dan .env privat | Tidak | Config dibuat privat secara terpisah; .env tidak diperlukan aplikasi ini. |
| backend/database.sql dan migrasi | Ya, skema/referensi tanpa data pribadi | Tidak; gunakan alat database secara terpisah bila memang diotorisasi. |
| docs, laporan audit, script/tools dan manifest sumber | Ya setelah ditinjau | Tidak. |
| Empat diagnostik, dump, log, backup, Git metadata, akun/kredensial QA | Tidak | Tidak. |

## Panduan deployment aman untuk pemilik

Langkah berikut merupakan dokumentasi; tidak ada langkah upload/konfigurasi hosting yang dijalankan pada pekerjaan ini.

1. Buat paket dari sumber yang sudah ditinjau:

   ```sh
   python3 tools/build_release.py --output /tmp/vistra-release-YYYYMMDD
   ```

   Tujuan harus folder baru di luar proyek. Tool menolak folder yang sudah ada, menyalin hanya manifest runtime dan menaruh inventaris hash di samping folder rilis. Jangan upload inventaris tersebut, folder proyek mentah atau arsip QA. Paket lokal yang sudah dibangun untuk pemeriksaan: `/tmp/vistra-security-9a4b85c6/release-final/`.

2. Pastikan hosting menyediakan PHP 8.1+ sesuai penggunaan never pada source, PDO MySQL, mbstring dan OpenSSL. Gunakan host/nama/user database dari akun hosting milik Anda sendiri; jangan menganggap host database hosting adalah localhost. Pilih HTTPS untuk domain produksi dan validasi sertifikat. Tidak ada redirect HTTPS/HSTS global yang dipaksakan karena localhost harus tetap bekerja dan domain final belum ditentukan.

3. Upload hanya isi paket runtime ke htdocs/domain yang benar, termasuk tiga .htaccess. Untuk pemasangan root, index.html berada langsung di htdocs; untuk subfolder, seluruh paket berada di subfolder yang sama. Resolver API sudah diuji pada kedua bentuk URL. Jangan mencampur file dari proyek lain.

4. Buat backend/php/config.php secara terpisah dari config.example.php pada mesin/akun privat. Isi DB_* dari akun Anda, APP_ENV='production', APP_DEBUG=false, JWT_SECRET acak kuat dan unik minimal 32 byte, JWT_EXPIRE yang sesuai kebijakan Anda, dan CORS_ORIGIN='' untuk frontend/API satu origin. Jika memang perlu origin tambahan, gunakan satu origin HTTPS milik Anda tanpa path/trailing slash; jangan pakai *. Jangan menyimpan config produksi di repository atau screenshot/laporan.

5. Biarkan N8N_WEBHOOK_URL='' sampai konfigurasi privat dan workflow milik Anda siap. Jangan menyalin URL dari diagnostik lokal atau sumber proyek lain. Saat kelak diaktifkan, isi secara privat dan koordinasikan autentikasi webhook di n8n; pekerjaan ini tidak menambah autentikasi atau memanggil webhook.

6. Gunakan permission file paling ketat yang tetap dapat dibaca proses PHP, misalnya 600 bila PHP berjalan sebagai pemilik atau 640 dengan grup yang sesuai. Jangan menggunakan 777. Pada hosting umum yang mendukungnya, tempatkan config/log di luar document root; pada InfinityFree kemampuan akses di luar htdocs terbatas, sehingga panduan ini mempertahankan config di include privat yang ditolak HTTP. Pembatasan ini dijelaskan oleh [Admin InfinityFree](https://forum.infinityfree.com/t/error-500/88143/12).

7. Sumber skema hanya dipakai melalui panel database/alat SQL saat instalasi atau migrasi memang telah diotorisasi. Jangan upload SQL/migrasi ke web root, jangan menjalankannya otomatis dari browser dan jangan menggunakan database lokal vistra_db sebagai target percobaan hosting. Tidak ada perubahan struktur yang diperlukan oleh hardening ini.

8. Sebelum mengisi data nyata, verifikasi HTTP menggunakan file canary sintetis pada lingkungan staging: root/assets/API sah dapat diakses; direktori include/config, SQL, docs, backup/dotfile dan diagnostik tidak mengembalikan isi file. Hapus canary setelah pengujian. Jangan membuat diagnostic endpoint berisi kredensial atau memanggil webhook untuk tes proteksi. Respons 403/404 atau halaman penolakan hosting harus benar-benar tidak memuat canary, bukan halaman PHP sumber dengan status 200.

9. Uji login/logout Owner/Employee, otorisasi admin, undangan, penyimpanan, periode terkunci dan PDF pada database staging tersendiri. Konfirmasi API mengembalikan JSON, Authorization diteruskan, CORS untuk origin sah berjalan dan error tidak mengungkap SQL/path/kredensial. Set display_errors/display_startup_errors Off melalui pengaturan PHP hosting bila tersedia; lint source sebelum upload. Error startup/konfigurasi web server sebelum bootstrap PHP tidak dapat seluruhnya ditangani aplikasi.

10. Jika aturan ditolak host atau tidak berlaku, **tahan publikasi/data nyata** dan perbaiki pada staging. Jangan menghapus blok perlindungan untuk sekadar menghilangkan error 500. Penegakan .htaccess bergantung pada AllowOverride dan modul server menurut [dokumentasi Apache](https://httpd.apache.org/docs/2.4/howto/htaccess.html). Aturan menghindari php_value/php_flag, Options All dan perubahan konfigurasi server yang memerlukan akses administrator. Pemakaian Options All pernah menimbulkan kegagalan pada InfinityFree; [penjelasan administrator hosting](https://forum.infinityfree.com/t/something-went-wrong/121464) menjadi alasan memakai aturan minimal Options -Indexes. Dukungan akun hosting Anda tetap harus diuji langsung.

11. Sebelum commit kelak, periksa ulang git status --short --ignored dan kandidat file. Repository privat tidak membuat secret aman untuk di-commit. Jika secret pernah terunggah/terbagi, rotasi secara privat; menghapus baris dari commit terbaru saja tidak mencabut secret atau menghapus seluruh riwayat.

## Pengujian keamanan dan regresi

Lingkungan: Apache 2.4.56 + PHP 8.2.4 lokal khusus pada port 9884 dan 9885; bukan PHP built-in server yang mengabaikan .htaccess. Database baru khusus QA vistra_sec_fedd90a7ed dibuat dari skema/referensi, tanpa menyalin data pengguna utama. Konfigurasi QA dibuat sendiri, memakai APP_ENV=production dan APP_DEBUG=true untuk membuktikan pembatasan detail produksi. n8n kosong dan curl_exec dinonaktifkan di server QA.

| Pengujian | Hasil | Bukti/cakupan |
| --- | --- | --- |
| Proteksi HTTP | PASS | 25 path privat/sensitif ditolak 403; tambahan POST/HEAD/OPTIONS diagnostik ditolak. Stub tidak menulis tanda eksekusi dan canary tidak bocor. |
| Listing direktori | PASS | css/, js/ dan backend/ ditolak 403 dengan mod_autoindex tersedia. |
| Jalur publik dan header | PASS | Landing, CSS, JS, admin tetap 200; API route tak dikenal 404 dan me anonim 401, tanpa DB utama. |
| CORS | PASS | Empat origin berbahaya ditolak, preflight same-origin 204; origin tambahan cocok persis, penyerupaan/wildcard ditolak. |
| Kegagalan koneksi DB produksi | PASS | Respons 503 JSON generik; tidak mengandung SQLSTATE, DSN, password, path atau canary meski APP_DEBUG=true. |
| Config hilang/rusak dan exception | PASS | Respons 500 generik; output parsial dibersihkan; canary tidak muncul pada respons/log aplikasi. |
| API nyata | PASS | 22 kasus: registrasi/login, undangan, Owner/Employee, batas role/tenant, status pegawai, periode, integer, penyimpanan 54 jawaban dan skor pembanding 3,23. |
| Browser subfolder | PASS | 8 onboarding + 6 Owner desktop + 5 Employee mobile + 3 admin tablet. Viewport 1440/390/820; navigasi, grafik, filter/keyboard, modal, logout/error/session dan PDF. |
| Browser root URL | PASS | 6 kasus Owner yang sama pada root, termasuk login, semua halaman analitik, API, filter dan PDF. |
| Admin standalone | PASS | Login, data QA dan logout pada backend/admin.php; bukan audit penetrasi seluruh modul. |
| Validator/sintaks | PASS | 66 pemeriksaan validator; 15 file PHP/JS lolos sintaks. Schema dan validator tidak berubah. |
| Paket rilis dan ignore | PASS | 22 file runtime identik dengan sumber; file privat/SQL/diagnostik tidak ikut. Folder output existing/di dalam proyek ditolak. |
| Database utama | PASS | Seluruh 12 checksum tabel identik sebelum/sesudah; 6 faktor dan 35 pertanyaan tetap tersedia. |
| InfinityFree/HTTPS aktual | BELUM DIUJI | Tidak ada upload, login hosting, perubahan DNS atau deploy. |
| Dialog print OS/perangkat fisik/n8n aktual | BELUM DIUJI | Print dipantau dan PDF dibuat oleh Chromium; tidak memanggil n8n atau perangkat fisik. |

Hasil akhir mencakup **8 kelompok security test, 22 kasus API, 28 kasus browser, 66 pemeriksaan validator dan 15 file lolos sintaks**, ditambah admin standalone dan pemeriksaan paket/ignore. Jumlah kasus adalah pemeriksaan gabungan, bukan klaim cakupan seluruh kemungkinan serangan. Uji error memakai fault injection terisolasi dan canary, bukan rahasia nyata. Pada percobaan awal, modul autoindex belum dimuat pada Apache QA sehingga akses direktori menghasilkan 404; modul dimuat dan tes diulang untuk membuktikan Options -Indexes benar-benar menghasilkan 403. Percobaan awal admin standalone menunggu networkidle dan timeout; tes diulang dengan DOMContentLoaded serta batas navigasi lebih panjang dan lulus login/data/logout. Ini penyesuaian instrumen, bukan perbaikan aplikasi baru.

Pada Apache utama localhost, pemeriksaan baca saja menghasilkan landing 200 dan SQL/laporan internal/build tool/config.example 403. Diagnostik asli tidak diminta melalui HTTP agar tidak berisiko memanggil n8n; penegakan terhadap keempat nama tersebut diuji memakai stub pada salinan Apache QA yang identik. Server Apache QA dihentikan setelah pengujian; layanan XAMPP utama tetap berjalan.

## Risiko tersisa dan penghalang publikasi

- **BLOCKED untuk verifikasi hosting:** domain/HTTPS, aturan .htaccess, penanganan error startup dan konfigurasi PHP pada akun InfinityFree belum dapat dinyatakan PASS tanpa staging pada hosting tersebut. Tidak ada deployment yang diotorisasi dalam pekerjaan ini.
- **Perlu pemeriksaan privat pemilik:** config asli tidak diinspeksi; nilai DB/JWT/CORS/n8n produksi belum diverifikasi. Jangan menganggap contoh placeholder sudah siap dijalankan. Pengecekan kekuatan/rotasi secret membutuhkan pengelolaan nilai privat oleh pemilik, bukan menampilkannya di laporan.
- **Rate limiting belum tersedia:** login/registrasi/undangan masih memerlukan perlindungan brute force/abuse yang sesuai hosting. Tidak menambahkan tabel, lockout atau limit global berbasis IP yang berisiko memblokir pengguna sah tanpa keputusan kebijakan.
- **Token tetap memakai penyimpanan browser yang ada:** XSS dapat mengancam token. CSP yang ditambahkan hanya membatasi object/base/frame, bukan kebijakan script ketat atau bukti semua XSS telah ditutup. Migrasi ke nonce/eksternalisasi inline atau cookie HttpOnly memerlukan pekerjaan autentikasi/frontend tersendiri.
- **CDN/font eksternal tetap digunakan:** ini dependensi eksternal yang sudah ada; tidak menambah library. Ketersediaan, supply chain dan kebijakan privasi perlu dipertimbangkan pemilik; tidak mengklaim audit dependensi menyeluruh.
- **Webhook:** URL diabaikan Git bukan autentikasi. Dua diagnostik lokal masih memuat referensi privat; jangan upload. Autentikasi n8n perlu konfigurasi kedua sisi dan belum diaktifkan/diuji.
- Jika seluruh proyek disalin lewat FTP, Git ignore tidak berlaku. Gunakan paket allowlist; aturan HTTP hanya lapisan pertahanan tambahan. Nginx/PHP built-in tanpa aturan setara tidak boleh dianggap terlindungi oleh .htaccess.

## Artefak lokal

Semua artefak di luar folder publikasi: `/tmp/vistra-security-9a4b85c6/`. Artefak sementara dapat hilang saat /tmp dibersihkan. Jangan menyalin state/config/akun QA ke Git atau hosting.

- [Security test](</tmp/vistra-security-9a4b85c6/security-results.json>), [API regression](</tmp/vistra-security-9a4b85c6/api-results.json>), [paket/ignore](</tmp/vistra-security-9a4b85c6/release-results.json>).
- [Onboarding](</tmp/vistra-security-9a4b85c6/browser-results.json>), [Owner](</tmp/vistra-security-9a4b85c6/browser-owner-results.json>), [Employee](</tmp/vistra-security-9a4b85c6/browser-employee-results.json>), [admin](</tmp/vistra-security-9a4b85c6/browser-admin-results.json>), [root URL](</tmp/vistra-security-9a4b85c6/browser-root-results.json>).
- [Validator](</tmp/vistra-security-9a4b85c6/validator-results.json>), [sintaks](</tmp/vistra-security-9a4b85c6/syntax-results.json>), [admin standalone](</tmp/vistra-security-9a4b85c6/standalone-admin.json>).
- Screenshot: regression-owner-factor.png, regression-employee-factor.png, fixed-admin-analytics-820.png; PDF completed-report.pdf. Seluruhnya hanya memakai data sintetis QA.
- Audit kandidat akhir, integritas database/sumber dan status server disimpan sebagai candidate-audit-final.json, integrity-results.json dan server-stopped.json setelah pemeriksaan akhir.
