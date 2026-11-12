# VISTRA V3 — Bug Fix Sprint & Regression Report

Tanggal: 11 November 2026. Acuan: [laporan QA awal](VISTRA_V3_QA_REPORT.md).

## Hasil sprint

**7 FIXED, 0 PARTIAL, 0 BLOCKED** untuk tujuh bug yang diminta. Status ini berlaku pada kasus regresi yang dijelaskan di bawah, bukan sertifikasi seluruh aplikasi/hosting siap produksi.

| Bug | Prioritas | Status | Bukti regresi |
| --- | --- | --- | --- |
| QA-01: periode terkunci terbuka lagi | P1 | FIXED | 6 GET status berulang tetap closed; 12 submit implisit/eksplisit ditolak 409; tidak muncul periode baru. GET tanpa periode juga tidak membuat periode. |
| QA-02: jawaban pecahan dipotong | P2 | FIXED | Pecahan pada keenam faktor ditolak 422 tanpa penambahan jawaban. 66 pemeriksaan validator mencakup tipe, rentang dan input integer yang sah. |
| QA-03: status pegawai 404 | P2 | FIXED | Helper frontend dan endpoint nyata berhasil menonaktifkan/mengaktifkan pegawai sendiri; akses tanpa login/Employee/Admin/Owner lain ditolak. |
| QA-04: ringkasan mencampur periode | P2 | FIXED | Minimum 2 Employee dengan baru 1 respons tetap incomplete; tidak menampilkan skor lama. Employee kedua melengkapi periode yang benar menjadi 3,23. Riwayat dan jawaban lama tetap ada. |
| QA-05: filter mobile race | P2 | FIXED | Klik pertama setelah pencarian/scroll berhasil 10 kali pada masing-masing viewport desktop/mobile; tambahan 5 siklus touch, navigasi keyboard dan Escape lulus. |
| QA-06: mapping admin | P2 | FIXED | Enam nilai/label dibandingkan dengan factor_key/avg_score dari API nyata; tanggal memakai started_at/completed_at. Akses admin tidak diperluas. |
| QA-07: label OPS | P3 | FIXED | Referensi utama terverifikasi sebagai Inovasi — Operational Stability. Popup menampilkan Inovasi dengan enam skor tersimpan yang tetap benar. |

## Pengamanan dan lingkungan pengujian

- Laporan QA dibaca sebelum perubahan. P1 diperbaiki dan diuji lebih dahulu, kemudian P2 dan P3.
- Backup file sumber sebelum perubahan berada di `/tmp/vistra-fix-a4a29c3a/backup/`, di luar folder publikasi. Backup tidak mencakup konfigurasi privat.
- Seluruh operasi tulis pengujian memakai database baru **vistra_fix_783e1d858f**, skema dari backend/database.sql dan akun/data sintetis. Tidak menyalin data pengguna nyata.
- Aplikasi diuji melalui salinan di `/tmp/vistra-fix-a4a29c3a/site/VISTRA/`, server lokal khusus port 9876. File aplikasi yang disalin cocok dengan sumber akhir berdasarkan hash.
- Akun SQL aplikasi QA dibatasi ke database QA tersebut. Konfigurasi QA dibuat tersendiri; konfigurasi privat proyek tidak dibaca, ditampilkan, atau diubah.
- URL webhook QA kosong dan curl_exec dinonaktifkan. Submit nyata menggunakan fallback PHP. Tidak memanggil n8n eksternal atau mengubah workflow/payload n8n.
- Browser: Chrome headless melalui Playwright, viewport 1440, 820 dan 390 px, serta konteks mobile dengan touch. Pengujian memakai login dan API nyata pada DB QA, bukan mock autentikasi.
- Server PHP QA telah dihentikan. Database QA dan artefak lokal dipertahankan untuk reproduksi; tidak menghapus database percobaan sebelumnya.
- Tidak mengubah database utama, folder/database proyek lain, konfigurasi privat, stylesheet/desain global, atau migrasi. Tidak menjalankan git add, commit, push atau deploy.

## Penyebab dan implementasi

### QA-01 — Pembacaan status harus bebas mutasi

Helper lama createOrGetPeriod dapat membuat periode atau membuka kembali periode default yang sudah ditutup. GET submission_status dan submit tanpa ID memakai helper tersebut. Agregasi juga menulis status open tanpa memperhatikan penguncian.

Perbaikan pada [backend/api.php](../backend/api.php):

- Mengganti helper dengan pembacaan periode terbaru tanpa INSERT/UPDATE; periode terakhir yang closed tetap closed.
- Memindahkan pembuatan periode awal ke transaksi POST registrasi Owner. Employee dan GET tidak membuat periode.
- Menolak submit jika periode tidak tersedia/terkunci, termasuk ketika period_id tidak dikirim.
- Memeriksa ulang status dengan SELECT FOR UPDATE di transaksi penyimpanan, sehingga penerimaan submission diserialisasi terhadap penguncian periode.
- Agregasi tidak lagi mengubah status periode menjadi open.
- Respons status menambahkan can_submit; field lama tetap tersedia.

[Form Data](../js/form.js) menampilkan state belum ada periode/periode dikunci dan menyembunyikan kontrol simpan pada kedua kondisi tersebut. Data yang sudah dikirim tetap menampilkan bukti pengiriman.

Regresi: periode default ditutup, lalu Owner/Employee membaca status berulang dan mencoba submit implisit/eksplisit; closed tetap bertahan. Kasus UMKM tanpa periode tidak menghasilkan periode lewat GET. Browser menguji pembuatan/penguncian resmi, reload dan form yang tetap terkunci. Tambahan 18 GET pada status, profil, dashboard, periode, hasil dan statistik tidak mengubah checksum seluruh 12 tabel QA.

### QA-02 — Validasi integer sebelum konversi

[Validator](../backend/php/validator.php) sebelumnya melakukan cast integer sebelum mengecek rentang. Sekarang hanya menerima integer JSON atau string digit integer dalam rentang: INS 1–3, lima faktor lain 1–5. Pecahan, string desimal/eksponen, float PHP, boolean, array, object, null dan nilai di luar skala tidak dipotong menjadi jawaban lain.

Regresi: 14 variasi input tidak valid melalui API tanpa penambahan jawaban; pecahan pada setiap faktor ditolak 422. Pengujian langsung validator menjalankan 66 pemeriksaan untuk enam faktor, termasuk float 3.0, batas integer dan integer string yang sah. Submit integer string melalui API menyimpan 16 jawaban Owner dengan benar. JSON.stringify akan menyerialisasi angka JavaScript 3.0 sebagai integer 3; pengujian tipe float tersendiri dilakukan langsung pada validator PHP.

### QA-03 — Kontrak status pegawai dan otorisasi

Helper DashboardAPI.setEmployeeStatus sudah memanggil set_employee_status, tetapi backend belum menyediakan route tersebut. [backend/api.php](../backend/api.php) kini menangani POST dengan validasi ID/status, role Owner, kepemilikan UMKM, dan target role Employee pada UMKM yang sama.

Regresi: Owner berhasil menonaktifkan/mengaktifkan Employee melalui API dan helper frontend asli. Akun nonaktif ditolak saat memakai token maupun login. Anonim mendapat 401; Employee dan Platform Admin mendapat 403; Owner lain atau target Owner mendapat 404; status tidak valid mendapat 422. Jawaban dan hasil historis tidak dihapus atau dihitung ulang saat status akun berubah. Tidak menambahkan kontrol UI atau kewenangan baru bagi pengguna biasa.

### QA-04 — Pemisahan periode dan kelengkapan

Backend sebelumnya mengembalikan hasil terakhir lintas periode; renderer memakainya untuk header periode aktif dan memakai minimum default 1. Fallback submission Owner lintas periode juga dapat mencampur konteks.

[backend/api.php](../backend/api.php) kini menyediakan current_result, current_factor_scores dan completion yang terikat pada periode terbaru UMKM. owner_submission hanya berasal dari periode tersebut. latest_result/factor_scores tetap tersedia untuk tampilan hasil terakhir dan riwayat.

Kelengkapan memakai minimum periode aktual, Owner tervalidasi serta jumlah Employee aktif yang tervalidasi dan memiliki tiga faktor wajib perannya. Pemilihan responden agregasi mengikuti akun aktif dan faktor wajib yang tersedia. Rumus normalisasi, rata-rata, bobot dan pembulatan tidak berubah. Perubahan status akun tidak menulis ulang hasil historis secara otomatis.

[Renderer Ringkasan dan laporan PDF](../js/main.js) hanya memakai skor/faktor yang period_id-nya sesuai header. Hasil lama ditampilkan di riwayat dengan nama periodenya. Jika respons belum memenuhi minimum, UI tidak mengklaim HASIL GABUNGAN; hasil tersimpan periode yang sama dibedakan dari status kelengkapan saat ini.

Regresi: periode lama berisi 54 jawaban dan hasil 3,23; periode baru minimum 2 diuji pada 0 respons, Owner saja, lalu Owner + 1 Employee. Saat masih incomplete, current_result kosong, skor gabungan kosong, faktor Employee belum ditampilkan, dan UI/PDF menyebut 1/2 minimum. Akun nonaktif dan submission tanpa faktor wajib tidak dihitung lengkap. Setelah Employee kedua mengirim, enam faktor dan skor 3,23 berasal dari periode baru; 54 jawaban lama dan hasil lama tetap utuh, 54 jawaban baru terpisah.

### QA-05 — Dropdown tidak ditutup oleh scroll pembukaan

Listener scroll capture lama menutup dropdown, termasuk scroll otomatis saat fokus/layout bergeser. [js/main.js](../js/main.js) sekarang memosisikan ulang menu terbuka lewat requestAnimationFrame, mengabaikan scroll internal menu, dan tetap membatasi geometri menu dalam viewport. Resize mengikuti mekanisme yang sama. Click di luar, pemilihan opsi dan Escape tetap menutup menu.

Ditambahkan fokus opsi serta ArrowUp/ArrowDown/Home/End/Enter/Space dan pemulihan fokus ke trigger saat Escape. Tidak mengubah warna, struktur data filter atau desain global.

Regresi: 20 siklus klik pertama total pada desktop/mobile setelah perubahan pencarian dan scroll, 5 siklus touch tambahan, pemilihan Fashion, scroll internal, keyboard dan pemulihan fokus lulus.

### QA-06 — Pemetaan field admin sesuai API

[js/main.js](../js/main.js) kini memetakan factor_key ke kamus faktor yang sudah diverifikasi dan mengonversi avg_score normalisasi menjadi skala 5 hanya untuk tampilan. Nilai yang tidak tersedia tidak diganti nol. Tanggal memakai started_at/completed_at dan menampilkan — bila kosong/tidak valid. Field statistik menggunakan kontrak dashboard aktual.

Regresi: keenam label dan nilai UI dibandingkan satu per satu dengan respons API; semua started_at yang terisi tampil sebagai tanggal, completed_at kosong tetap —. Delapan tujuan navigasi admin diuji pada 820 px. Owner tetap ditolak oleh endpoint directory admin dan navigasi admin disembunyikan. Halaman admin standalone juga lulus login, pemuatan data QA dan logout.

### QA-07 — OPS memakai model terverifikasi

Label pada form, deskripsi faktor Owner, fallback popup, popup aktif dan admin standalone diselaraskan: label ringkas Inovasi, nama panjang Inovasi — Operational Stability. Referensi factor_definitions database utama dibaca secara read-only untuk memastikan nama OPS tersebut. Kode OPS, pertanyaan, jawaban dan nilai tidak ditukar.

Regresi: popup dirender menggunakan enam nilai hasil QA tersimpan, label Inovasi terlihat dan keenam nilai 5,00 tetap sama. Schema faktor validator, pertanyaan, skala dan bobot cocok dengan backup sebelum perubahan; bagian matematika agregasi juga identik.

## File yang diubah

| File | Perubahan |
| --- | --- |
| backend/api.php | GET periode read-only, periode awal registrasi, pengaman submit, endpoint status Employee, hasil/kelengkapan per periode. |
| backend/php/validator.php | Pemeriksaan tipe integer dan skala sebelum cast. |
| js/main.js | Ringkasan/PDF sesuai periode, dropdown tahan scroll dan keyboard, mapping analitik/tanggal admin. |
| js/form.js | State periode tidak tersedia/terkunci dan label OPS. |
| js/feedback-popup.js | Label OPS pada popup aktif. |
| backend/admin.php | Dua kamus label OPS; tidak mengubah autentikasi admin. |
| index.html | Versi cache tiga script yang berubah. |
| docs/VISTRA_V3_QA_FIX_REPORT.md | Laporan sprint ini. |

## Hasil regression test

Hasil akhir: **30 kasus API PASS**, **37 kasus browser PASS**, **66 pemeriksaan validator PASS**, **13 file lolos sintaks**. Angka kasus browser mencakup beberapa pemeriksaan gabungan; bukan jumlah fitur independen. Uji P1 berulang, pembentukan pembanding QA dan admin standalone memiliki artefak terpisah.

| Fitur | Hasil | Cakupan aktual |
| --- | --- | --- |
| Landing dan registrasi Owner/Employee | PASS | Wizard Owner desktop, undangan personal dan registrasi Employee mobile, validasi registrasi API. |
| Login, logout, sesi dan akun nonaktif | PASS | Login nyata, password salah, role otoritatif, logout/relogin; 401 kedaluwarsa diinjeksi untuk menguji pembersihan sesi. |
| Undangan | PASS | Buat, lihat kode, cabut, muat ulang; email salah, kedaluwarsa dan penggunaan ulang ditolak. |
| Hak akses dan pemisahan UMKM | PASS | Operasi Owner oleh Employee ditolak; undangan/periode/status pegawai lintas UMKM ditolak; profil tetap milik tenant sendiri. |
| Periode dan Form Data | PASS | Pembuatan/penguncian resmi, GET read-only, minimum 2 Employee, duplicate submit, form sesudah reload, tanpa periode/terkunci. |
| Evaluasi enam faktor dan penyimpanan | PASS | 16 jawaban Owner + 19 + 19 Employee, pembanding rumus independen 3,23; fixture browser maksimum menghasilkan 5,00. |
| Home/Factor/Distribution/Benchmark/Recommendations/Ringkasan | PASS | Data API QA nyata, radar enam nilai; skenario kosong dan satu hasil, pembanding 3 hasil, rekomendasi dan history. |
| Distribution beberapa data | PASS terbatas | Helper menerima 3 hasil leaderboard QA asli; UI Owner sendiri tetap n=1 sesuai sumber datanya. Tidak menyuntikkan dataset dashboard palsu. |
| Filter/pencarian/sort/pagination | PASS | Desktop, mobile, touch, keyboard, data kosong pencarian dan directory 10 UMKM QA. |
| Modal/dropdown/FAQ/toast/profil/notifikasi | PASS | Navigasi kedua peran, preview validasi, Escape, menu akun dan pencarian FAQ. Tidak menyimpan perubahan profil nyata. |
| PDF | PASS terbatas | Popup asli periode lengkap/incomplete, isi dan window.print dipantau; Chromium menghasilkan dua PDF valid. Dialog cetak OS tidak diuji. |
| Admin | PASS | Mapping angka/tanggal, delapan halaman SPA, login/data/logout standalone, pembatasan akses Owner. |
| Error API | PASS | 503, non-JSON 502, jaringan abort, sesi 401 dan akses tidak sah. Fault injection terisolasi, bukan outage hosting sungguhan. |
| Runtime/overflow | PASS | Tidak ada pageerror pada kasus browser akhir; halaman Owner/Employee dan admin diperiksa terhadap horizontal overflow viewport. |
| n8n eksternal | BELUM DIUJI | Sengaja tidak dipanggil. Fallback PHP diuji pada submit nyata. |
| Hosting/perangkat fisik/dialog print OS | BELUM DIUJI | Tidak deploy; bukan pengujian Android/iOS fisik, Safari atau Firefox. |
| Autentikasi terhadap DB utama | BELUM DIUJI | Sengaja memakai akun sintetis pada DB QA; tidak mengirim submission ke vistra_db. |

Pembanding skor tanpa perubahan rumus:

| Kode | Normalisasi hasil QA | Bobot |
| --- | --- | --- |
| INS | 0,6667 | 0,20 |
| OPS | 0,6000 | 0,15 |
| ECT | 0,6000 | 0,15 |
| OV | 0,6000 | 0,18 |
| LDI | 0,7000 | 0,17 |
| WEQ | 0,7000 | 0,15 |

Komposit 0,6453 menghasilkan **3,23/5**. Skor, pertanyaan dan skala tidak diubah demi memperbaiki tampilan/status.

## Integritas database utama

CHECKSUM TABLE EXTENDED dibandingkan sebelum dan sesudah sprint untuk **seluruh 12 tabel vistra_db**: **12/12 identik**. Enam factor_definitions dan 35 question_definitions tetap tersedia. Tidak menjalankan migrasi, INSERT, UPDATE, DELETE atau DDL pada database utama. Data sintetis hanya berada di database QA terpisah.

Pemeriksaan hash sumber menemukan tujuh file aplikasi yang berubah sesuai daftar di atas; file lain tetap sama dibanding baseline sprint. Laporan ini merupakan file tambahan. Tidak membuka konfigurasi privat untuk membuat baseline maupun backup.

## Artefak lokal dan screenshot

Artefak berada di `/tmp/vistra-fix-a4a29c3a/`, di luar publikasi dan dapat hilang saat direktori sementara dibersihkan. Tidak menautkan konfigurasi/kredensial QA.

- [22 kasus API dasar](</tmp/vistra-fix-a4a29c3a/api-results.json>), [kasus batas API](</tmp/vistra-fix-a4a29c3a/regression-api-results.json>), [regresi GET/enam faktor/riwayat](</tmp/vistra-fix-a4a29c3a/final-api-results.json>). File pertama memuat 22 kasus; dua berikutnya 5 dan 3 kasus.
- [P1 final](</tmp/vistra-fix-a4a29c3a/p1-final-results.json>), [validator](</tmp/vistra-fix-a4a29c3a/validator-results.json>), [integritas DB/sumber](</tmp/vistra-fix-a4a29c3a/integrity-results.json>), [model](</tmp/vistra-fix-a4a29c3a/model-results.json>), [sintaks](</tmp/vistra-fix-a4a29c3a/syntax-results.json>).
- [Ringkasan incomplete desktop](</tmp/vistra-fix-a4a29c3a/fixed-threshold-1440.png>), [mobile](</tmp/vistra-fix-a4a29c3a/fixed-threshold-390.png>), [Ringkasan complete](</tmp/vistra-fix-a4a29c3a/fixed-summary-complete-1440.png>).
- [Analitik admin](</tmp/vistra-fix-a4a29c3a/fixed-admin-analytics-820.png>), [tanggal periode admin](</tmp/vistra-fix-a4a29c3a/fixed-admin-periods-820.png>), [filter mobile](</tmp/vistra-fix-a4a29c3a/fixed-filter-390.png>).
- [Form tanpa periode](</tmp/vistra-fix-a4a29c3a/form-no-period-390.png>), [form terkunci](</tmp/vistra-fix-a4a29c3a/form-locked-390.png>), [popup OPS](</tmp/vistra-fix-a4a29c3a/fixed-OPS-popup-1440.png>).
- [PDF periode aktif incomplete](</tmp/vistra-fix-a4a29c3a/active-period-report.pdf>), [PDF complete](</tmp/vistra-fix-a4a29c3a/completed-report.pdf>).
- Hasil browser: browser-results.json (onboarding), browser-owner-results.json, browser-employee-results.json, browser-admin-results.json, browser-threshold-results.json, browser-extra-results.json, browser-final-results.json. Admin standalone: standalone-admin.json.

Satu percobaan instrumen pagination mencari halaman 2 saat filter Fashion masih aktif, sehingga halaman tersebut memang tidak tersedia. Instrumen diulang setelah memilih Semua sektor; pagination dan kasus lanjutan lulus. Ini bukan perubahan kode untuk mengatasi bug produk baru. Screenshot sebelum perbaikan tersedia pada laporan QA awal.

## Risiko/batas yang masih tersisa

1. Tidak ada migrasi atau keputusan desain destruktif yang diperlukan. UMKM lama tanpa periode kini perlu membuat periode melalui aksi Owner resmi; GET tidak lagi membuatnya diam-diam.
2. Hasil historis tetap disimpan saat akun dinonaktifkan. Status kelengkapan saat ini dapat berbeda dari snapshot hasil tersimpan; label UI membedakannya. Tidak melakukan rekalkulasi historis otomatis.
3. Pengaman transaksi penguncian ditambahkan, tetapi stress test konkurensi multi-worker PHP/FPM pada hosting belum dilakukan. Server QA memakai proses PHP lokal.
4. Kebijakan benchmarking berbasis nama periode global tetap sebagaimana implementasi sebelumnya. Pembanding regresi sengaja memakai nama periode sama; tidak mengubah kebijakan ini.
5. Integrasi n8n aktual, proteksi HTTP file privat/diagnostik, HTTPS/CORS hosting, perangkat fisik dan dialog cetak OS tetap memerlukan pemeriksaan terpisah. Hasil sprint ini tidak mengklaim hal-hal tersebut PASS.
