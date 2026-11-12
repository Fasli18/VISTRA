# VISTRA V3 — Functional QA sebelum GitHub dan hosting

Tanggal: 11 November 2026.

**Keputusan: belum layak dinyatakan seluruhnya PASS atau siap hosting.** Alur utama berhasil dijalankan dengan backend dan database sungguhan yang terisolasi, tetapi ada bug penguncian periode, validasi jawaban, kontrak API, dan konsistensi data UI. Tidak ada perbaikan kode aplikasi yang dilakukan.

## Lingkungan, isolasi, dan arti hasil

- Proyek sumber: VISTRA. URL utama `http://localhost/VISTRA/` hanya diperiksa dengan GET tanpa sesi: landing HTTP 200; `me`, `dashboard`, `my_invitations`, `period_history` HTTP 401 dan JSON valid. Tidak melakukan login/registrasi/submission pada database utama.
- Pengujian mutasi memakai database baru **`vistra_qa_232f24841b`**, bukan `vistra_db` dan bukan database percobaan lama. Database diisi dari `backend/database.sql`, tanpa menyalin baris pengguna/data nyata.
- Akun koneksi QA baru dibatasi ke database QA saja. Akun aplikasi sintetis memakai domain `example.test`. Kondisi akhir: 13 akun sintetis, 7 UMKM sintetis, 210 jawaban sintetis. Beberapa fixture sintetis direset saat pembetulan harness; tidak ada operasi tersebut pada database utama.
- Aplikasi dijalankan dari salinan sementara file sumber yang identik di `http://127.0.0.1:9876/VISTRA/`, dengan PHP 8.2.4 dan MariaDB 10.4.28. Konfigurasi QA dibuat baru; konfigurasi privat proyek asli tidak dibaca/disalin. N8N_WEBHOOK_URL QA kosong dan `curl_exec` dinonaktifkan pada server QA. Tidak memanggil webhook eksternal.
- Browser: Chrome headless melalui Playwright, desktop 1440 px, tablet 820 px, mobile viewport 390 px. Seluruh alur login/registrasi/submission yang dinyatakan end-to-end menggunakan HTTP API dan MariaDB QA nyata, tanpa mock respons bisnis.
- **PASS** hanya untuk cakupan dan metode pada baris terkait. Fault injection, helper, dan print spy ditandai terpisah; hasilnya bukan bukti integrasi layanan eksternal atau hosting produksi.
- **FAIL** berarti terdapat reproduksi yang bertentangan dengan perilaku yang diharapkan. **BELUM DIUJI** tidak dihitung PASS.
- Pemeriksaan checksum seluruh **12 tabel `vistra_db` identik sebelum/sesudah pengujian**. Hash file aplikasi sumber tetap sama; hanya laporan ini ditambahkan. Tidak melakukan commit/push/deploy.

## Matriks fitur

| Fitur | Hasil | Metode dan bukti utama |
| --- | --- | --- |
| Instalasi skema baru | PASS | Import SQL sumber pada DB QA: 12 tabel, 6 faktor, 35 pertanyaan, awalnya 0 akun. |
| Sintaks PHP/JavaScript | PASS | 14 file aplikasi JS/PHP yang diperiksa lolos parser/lint; konfigurasi privat asli dikecualikan. |
| Landing, CTA, navigasi sebelum login | PASS | Browser nyata; CTA membuka wizard. Landing host utama juga HTTP 200. |
| Registrasi Owner | PASS | Wizard dua tahap, dropdown provinsi/sektor, persetujuan, API dan relasi user–UMKM tersimpan nyata. |
| Registrasi Employee | PASS | Browser 390 px menggunakan undangan yang dibuat Owner; akun terhubung ke UMKM yang sama. |
| Validasi dasar registrasi | PASS | Email salah, password pendek dan role `platform_admin` pada registrasi ditolak 422; duplikat email/nama 409. |
| Login Owner/Employee | PASS | Browser + API nyata; password salah 401. Role sebenarnya tetap mengikuti database meskipun pilihan role login berbeda. |
| Logout dan login ulang | PASS | Kedua peran; token lokal dibersihkan dan form login kembali tampil. |
| Sesi ditolak/akses tanpa izin | PASS | API tanpa token/token rusak 401; Employee ditolak 403 pada aksi Owner; tenant lain mendapat 404/409 pada objek yang bukan miliknya. |
| UI saat API mengembalikan 401 | PASS | Fault injection khusus pengujian: token lokal dihapus dan kembali ke login. |
| JWT benar-benar kedaluwarsa menurut waktu server | BELUM DIUJI | Tidak menunggu masa berlaku token atau mengubah waktu server. Penanganan 401 di client dan token rusak diuji terpisah. |
| Profil UMKM/Profil Saya — baca | PASS | Data hasil registrasi QA dimuat melalui API, bukan placeholder renderer. |
| Undangan personal, Lihat Kode, Cabut, Muat ulang | PASS | Pembuatan/reveal/pencabutan melalui browser dan API QA nyata. Penolakan penggunaan ulang diverifikasi. |
| Undangan salah email/dipakai/dicabut/kedaluwarsa | PASS | API menolak; fixture waktu kedaluwarsa diubah hanya dalam DB QA. |
| Penonaktifan akun — penolakan akses | PASS | Fixture `is_active=0` hanya pada akun sintetis: login dan token ditolak 403. Ini bukan bukti tombol pengubahan status bekerja. |
| API pengubahan status pegawai | FAIL | `DashboardAPI.setEmployeeStatus` memanggil route yang tidak tersedia; HTTP 404, QA-03. |
| Membuat periode, nama duplikat, history | PASS | Browser dan API; nama duplikat 409; periode sebelumnya tetap tercatat. |
| Penguncian periode yang bertahan setelah refresh/status | FAIL | GET `submission_status` membuka kembali periode closed; QA-01. |
| Minimum Employee pada backend | PASS | Minimum 2: setelah Owner + 1 Employee masih incomplete; setelah Employee kedua hasil published. |
| Minimum Employee dan asal periode pada Ringkasan | FAIL | UI menyatakan lengkap untuk 1 dari minimum 2 Employee, dan menaruh skor periode lama di bawah periode baru; QA-04. |
| Kuesioner Owner | PASS | 16 pertanyaan dijawab/disimpan melalui browser nyata. |
| Kuesioner Employee | PASS | 19 pertanyaan dijawab/disimpan melalui browser nyata; reload mempertahankan status selesai. |
| Jawaban wajib dan nilai di luar rentang bulat | PASS | Guard browser tidak mengirim form kosong; API menolak jawaban hilang dan INS=4 dengan 422. |
| Jawaban wajib berupa bilangan bulat | FAIL | `ins_oh1=1.5` diterima HTTP 200 lalu disimpan sebagai 1; QA-02. |
| Maksimum satu submission per akun/periode | PASS | Pengiriman ulang 409; form selesai tidak kembali menjadi input setelah reload. |
| Normalisasi, rata-rata Employee, bobot, penyimpanan | PASS | Diuji API + DB dengan nilai tidak seragam dan pembanding perhitungan independen; rincian di bawah. |
| Dashboard Home dan Factor Profile | PASS | Kedua peran, data nyata QA; skor gabungan 5,00 dan enam nilai radar 5 pada fixture browser; tidak ada pageerror. |
| Distribution: 0 dan 1 data | PASS | Empty state sebelum evaluasi serta teks belum cukup data untuk satu hasil diuji melalui UI nyata. |
| Distribution: beberapa data | PASS | Helper statistik memakai 3 hasil leaderboard QA asli; total frekuensi 3 dan insight sesuai. Ini uji helper, bukan UI multi-UMKM Owner yang memang bersumber dari UMKM sendiri. |
| Benchmarking dan rekomendasi dengan pembanding | PASS | Tiga hasil QA pada nama periode yang sama: 5,00; 4,20; 1,13. Kartu rekomendasi terisi dan details dapat dibuka. |
| Directory, pencarian/sort/filter desktop | PASS | Tabel API nyata; query tidak ditemukan, filter Fashion dan urutan diuji. |
| Filter sektor mobile setelah perubahan scroll | FAIL | Klik pertama dapat langsung menutup dropdown; klik kedua berhasil; QA-05. |
| Pagination | PASS | 7 UMKM QA: berpindah dari halaman 1/2 ke halaman 2/2; API limit/offset juga diuji. |
| Modal, dropdown akun, FAQ, toast | PASS | Preview, Escape, logout modal, menu profil dan pencarian FAQ diuji. Race filter sektor dicatat terpisah. |
| Form Data dan status anggota setelah reload | PASS | Submission tersimpan, anggota validated dan duplicate lock tampil; bug penentuan kelengkapan minimum dicatat terpisah. |
| PDF: isi laporan, pemanggilan print dan berkas PDF | PASS | Popup asli berisi skor 5,00; print dipantau; Chromium menghasilkan PDF valid 42.517 byte. Data berasal dari API QA. |
| Dialog cetak OS / memilih lokasi Save as PDF manual | BELUM DIUJI | Spy print mencegah dialog OS; berkas PDF dibuat melalui engine headless. |
| Error API/non-JSON/jaringan terputus | PASS | Respons 503/502 dan abort jaringan diinjeksi secara terisolasi; client mengembalikan kegagalan yang sesuai dan menampilkan error. Bukan simulasi outage hosting sungguhan. |
| Admin SPA: login/directory/data beberapa UMKM | PASS | 820 px, role admin sintetis, 8 tujuan navigasi dan data API nyata. |
| Admin SPA: analitik faktor dan tanggal periode | FAIL | Salah pemetaan nama field menghasilkan enam 0,00 dan tanggal kosong; QA-06. |
| Admin terpisah `backend/admin.php` | PASS | Login, pemuatan UMKM QA dan logout diuji; bukan pengujian seluruh modul admin standalone. |
| Fallback tanpa n8n | PASS | Submit nyata memakai skor PHP dan `n8n_status=fallback`; tidak ada panggilan eksternal. |
| Integrasi workflow n8n eksternal | BELUM DIUJI | Sengaja tidak dipanggil sesuai batasan. |
| Alur terautentikasi pada `localhost/VISTRA`/DB utama | BELUM DIUJI | Tidak memakai akun/data nyata. Alur tersebut diuji pada salinan identik + DB QA. |
| Upgrade migrasi dari database lama | BELUM DIUJI | Run ini menguji instalasi skema lengkap yang baru, bukan migrasi upgrade. |
| Hosting, HTTPS, CORS produksi, proteksi HTTP file privat/diagnostik | BELUM DIUJI | Tidak deploy; nilai konfigurasi privat asli tidak diperiksa. |
| Perangkat Android/iOS fisik dan browser selain Chrome | BELUM DIUJI | Hanya emulasi viewport/headless. |

## Pembanding skor dan integritas data

Fixture API menggunakan 1 Owner dan 2 Employee. Setelah normalisasi dan rata-rata Employee, nilai yang diharapkan adalah:

| Faktor | Nilai normalisasi | Bobot |
| --- | --- | --- |
| INS | 0,6667 | 0,20 |
| OPS | 0,6000 | 0,15 |
| ECT | 0,6000 | 0,15 |
| OV | 0,6000 | 0,18 |
| LDI | 0,7000 | 0,17 |
| WEQ | 0,7000 | 0,15 |

Jumlah berbobot dibulatkan menjadi 0,6453; skor skala 5 menjadi **3,23**, sama dengan hasil API/database. Sebanyak **54 jawaban** tersimpan pada periode tersebut: 16 + 19 + 19, tanpa saling menimpa. Fixture browser lain memakai jawaban maksimum dan menghasilkan **5,00** setelah kedua peran mengirim. Ini membuktikan konsistensi contoh perhitungan dengan rumus saat ini, bukan validasi ilmiah atas pemilihan bobot.

## Bug, bukti, penyebab, rekomendasi

### QA-01 — P1: Periode closed dibuka kembali oleh pembacaan status

**Reproduksi:** Owner membuat periode dengan nama default bulan berjalan, lalu menguncinya. Submit dengan period_id eksplisit ditolak 409. Setelah memanggil GET `submission_status`, status database berubah **closed → open** pada periode yang sama (ID sintetis 4).

**Penyebab:** [createOrGetPeriod](../backend/api.php#L117) mencari periode open/published, lalu membuka kembali periode bernama default jika ditemukan closed. [GET submission_status](../backend/api.php#L671) memanggil fungsi tersebut. Submit tanpa period_id juga menggunakan helper ini.

**Dampak:** Membuka Form Data/mengecek status dapat membatalkan keputusan penguncian Owner. GET bukan operasi baca murni.

**Rekomendasi:** Pisahkan pembacaan status dari pembuatan/pembukaan periode. Periode closed tetap immutable sampai aksi Owner yang eksplisit. Pastikan submit tanpa ID tidak melewati penguncian. Tambahkan regresi GET berulang sesudah close dan skenario Employee belum pernah submit.

### QA-02 — P2: Jawaban pecahan diterima dan dipotong

**Reproduksi:** POST submit dengan semua jawaban lengkap tetapi `ins_oh1: 1.5` mendapat HTTP 200. Jawaban yang tersimpan adalah **1**.

**Penyebab:** [validator.php:111](../backend/php/validator.php#L111) memeriksa rentang setelah cast `(int)$raw`; [baris 115](../backend/php/validator.php#L115) juga memasukkan hasil cast tersebut. Angka pecahan lolos sebagai integer yang berbeda.

**Rekomendasi:** Validasi representasi bilangan bulat sebelum cast dan rentang. Pertahankan skala INS 1–3 serta faktor lain 1–5; jangan mengubah formula skor. Uji pecahan, notasi eksponen dan batas rentang sebagai kontrak input.

### QA-03 — P2: Kontrak pengubahan status Employee tidak tersedia

**Bukti:** [DashboardAPI.setEmployeeStatus](../js/api.js#L106) memanggil `set_employee_status`. Request Owner dengan ID Employee miliknya mengembalikan **404**, bukan hasil perubahan status. Tidak ada handler route tersebut dalam `backend/api.php`.

**Dampak:** API client menawarkan fungsi yang tidak dapat dijalankan. Pengujian fixture akun nonaktif hanya membuktikan penolakan akses, bukan kemampuan mengubah status melalui aplikasi.

**Rekomendasi:** Tentukan cakupan fitur. Jika disediakan, implementasikan endpoint dengan pemeriksaan Owner/tenant dan batasan akun sasaran; jika belum didukung, jangan menawarkan kontrak/aksi seolah tersedia. Pada tahap QA ini tidak diimplementasikan.

### QA-04 — P2: Ringkasan mengabaikan minimum periode dan mencampur asal skor

**Reproduksi nyata:** Periode aktif sintetis 8, `QA Threshold UI`, mensyaratkan 2 Employee. Owner dan 1 Employee sudah mengirim; API submit menyatakan **incomplete**. UI justru menampilkan **HASIL GABUNGAN** dan **Syarat minimum evaluasi gabungan terpenuhi**. Skor 3,23 yang ditampilkan berasal dari periode sintetis 4, sedangkan header menyebut periode 8.

**Penyebab minimum:** [js/main.js:1215](../js/main.js#L1215) mengambil `completion.required_employee_responses ?? 1`; respons `my_umkm` tidak menyediakan object completion tersebut, sementara minimum sebenarnya ada di `current_period.min_employee_responses`.

**Penyebab skor:** [backend/api.php:778](../backend/api.php#L778) mengambil latest_result lintas periode; renderer memilih `latest_result || owner_submission` tanpa memastikan cocok dengan periode yang dijadikan header. Nilai historis tidak salah, tetapi konteks penyajiannya salah.

**Rekomendasi:** Gunakan minimum periode aktual. Pisahkan hasil periode aktif dari hasil evaluasi terakhir; jika menampilkan skor historis, beri nama/tanggal periode asal secara eksplisit. Jangan menandai periode aktif lengkap sebelum syarat backend terpenuhi.

### QA-05 — P2: Race dropdown filter sektor pada mobile

**Reproduksi:** Viewport 390 px, cari string yang tidak ditemukan, kembalikan pencarian menjadi QA, lalu buka filter sektor setelah kontrol bergeser/scroll. Klik pertama berakhir dengan `show=false`, `display=none`, `visibility=hidden`. Klik kedua membuka menu dan Fashion dapat dipilih.

**Penyebab:** [js/main.js:2274](../js/main.js#L2274) memasang penutupan dropdown pada semua event scroll dalam fase capture. Scroll otomatis/fokus/layout yang berdekatan dengan pembukaan dapat segera menutup menu. Geometri menu sesudah klik kedua berada dalam viewport, sehingga ini bukan kegagalan API atau filter data.

**Rekomendasi:** Atur ulang posisi atau batasi listener scroll ke keadaan yang relevan; jangan langsung menutup menu akibat scroll yang berasal dari proses membuka/fokusnya sendiri. Uji urutan pencarian → scroll → filter dan keyboard. Temuan bersifat race/intermiten, bukan klaim bahwa seluruh filter mobile selalu gagal.

### QA-06 — P2: Admin SPA salah membaca field hasil API

**Bukti analitik:** API `factor_averages` memberikan enam pasangan `factor_key`/`avg_score` yang tidak nol; konversi sampel saat diuji adalah INS 3,75; OV 3,25; LDI/WEQ 3,38; OPS/ECT 3,25. UI menampilkan enam baris **Faktor 0.00 / 5**.

**Penyebab:** [loadAdminAnalytics](../js/main.js#L2538) membaca field label dan angka yang tidak ada (`factor_name`, `name`, `factor`, `average`, `average_score`, `score`) serta fallback 0. Tidak membaca `factor_key`/`avg_score` dan konversi skala 0–1 ke 0–5.

**Bukti tanggal:** API periode memiliki tujuh `started_at` terisi pada saat probe, tetapi tabel menampilkan `-`. [loadAdminPeriods](../js/main.js#L2536) memakai `start_date`/`end_date`, bukan `started_at`/`completed_at`.

**Rekomendasi:** Buat pemetaan kontrak eksplisit dan verifikasi nilai, bukan sekadar keberadaan tabel. Bedakan nilai nol yang sah dengan field yang tidak tersedia.

### QA-07 — P3, temuan statis: Label OPS pada popup berbeda dari kamus faktor

[feedback-popup.js:12](../js/feedback-popup.js#L12) masih memberi label OPS “Operasional”, sementara schema validator/kamus Factor Profile memberi label utama “Inovasi”. Ini inkonsistensi teks presentasi; pengujian tidak menemukan pertukaran nilai faktor. Rekomendasi: satu kamus label presentasi yang bersumber dari definisi faktor, tanpa mengganti kode, pertanyaan atau skor.

## Bukti pengujian dan batas instrumen

Artefak lokal sementara berada di `/tmp/vistra-qa-326ff6c3/`, di luar repository:

- [API: 22 kasus, 19 PASS dan 3 FAIL](/tmp/vistra-qa-326ff6c3/api-results.json) — tiga kegagalan API merupakan QA-01/02/03.
- [Screenshot Ringkasan yang salah status/periode](/tmp/vistra-qa-326ff6c3/bug-threshold-previous-result.png).
- [Screenshot analitik admin nol](/tmp/vistra-qa-326ff6c3/bug-admin-analytics.png).
- [Filter mobile klik pertama](/tmp/vistra-qa-326ff6c3/mobile-filter-first-click.png), [probe computed state](/tmp/vistra-qa-326ff6c3/mobile-filter-probe.json).
- [Factor Owner desktop](/tmp/vistra-qa-326ff6c3/Owner-desktop-factor.png), [Factor Employee mobile](/tmp/vistra-qa-326ff6c3/Employee-mobile-factor.png), [admin tablet](/tmp/vistra-qa-326ff6c3/admin-tablet.png).
- [PDF sintetis](/tmp/vistra-qa-326ff6c3/report-synthetic.pdf), [probe print/PDF](/tmp/vistra-qa-326ff6c3/pdf-probe.json).
- `threshold-api.json`, `final-probes.json`, `db-evidence.json`, `peers-results.json`, `distribution-network.json`, `syntax-results.json`, `integrity-results.json`, dan log browser memuat rincian tambahan yang sudah dipisahkan dari kredensial.

Log browser mentah dipertahankan. Selector notifikasi pada percobaan awal keliru menunjuk sidebar; selector diarahkan ke tombol navbar dan kasus diulang. Browser pertama juga terhenti; pengujian dilanjutkan pada proses browser terpisah. Percobaan awal print spy dipasang pada page saja sehingga tidak mengikuti popup; pengujian diulang dengan context-level spy dan berhasil, lalu PDF benar-benar dihasilkan oleh Chromium. Kesalahan instrumen tersebut tidak dihitung sebagai bug produk. Log mentah yang masih menyebut kegagalan instrumen bukan keputusan akhir; matriks dan reproduksi di atas adalah hasil yang sudah ditinjau.

Tidak ada token, password, JWT secret, atau URL webhook privat dalam laporan. Artefak screenshot/PDF hanya memuat akun/data sintetis. File konfigurasi/kredensial QA sementara tidak ditautkan dan tidak termasuk kandidat Git.

## Rekomendasi sebelum publikasi

1. Perbaiki QA-01 sebelum hosting; lanjutkan dengan validasi integer dan kesesuaian status/periode pada Ringkasan.
2. Selaraskan kontrak frontend/backend untuk status pegawai dan admin analytics, lalu jalankan ulang kasus gagal dengan data QA terpisah.
3. Perbaiki race filter dan konsistensi label; jangan mengubah formula skor saat memperbaiki pemetaan.
4. Konfirmasi kebijakan benchmarking: backend memilih nama periode hasil published terakhir secara global. Tiga fixture pembanding sengaja memakai nama periode yang sama; hasil dari nama periode lain tidak ikut diranking pada snapshot tersebut. Ini perlu keputusan produk, bukan diasumsikan sebagai perbandingan semua hasil historis.
5. Selesaikan pengamanan hosting yang masih terpisah dari ignore Git: blokir endpoint diagnostik dan file privat/SQL/metadata Git secara HTTP, siapkan autentikasi webhook bersama konfigurasi n8n, dan verifikasi HTTPS/CORS/debug pada lingkungan staging. Endpoint diagnostik tidak dijalankan dalam QA ini.
6. Uji manual dialog cetak, perangkat fisik dan konfigurasi hosting setelah perbaikan. Jangan menyatakan siap produksi hanya dari PASS pada mock/helper atau keberhasilan render halaman.

Server PHP QA dihentikan setelah pemeriksaan. Database QA dipertahankan untuk reproduksi; tidak ada DROP database utama maupun database percobaan yang sudah ada sebelumnya.
