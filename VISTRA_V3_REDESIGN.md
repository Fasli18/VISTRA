# VISTRA V3 — Midnight Intelligence Workspace

Pengerjaan lokal, 11 November 2026. Perubahan mencakup struktur frontend utama, bukan hanya palet warna. Tidak ada commit, deploy, perubahan backend, atau penulisan database.

## Implementasi dan file

| File | Perubahan |
| --- | --- |
| `index.html` | Struktur Home dipindahkan ke bento; directory dipisahkan dari ranking/rekomendasi; auth menjadi satu shell terpusat; landing menjadi hero terpusat dan product stage; label rail tetap memiliki nama aksesibel; workspace bar dengan judul halaman; judul tab/favicon V3. Semua ID/handler/data attribute lama dipertahankan. |
| `css/vistra-workspace.css` (baru) | Token geometri, rail ringkas/expanded dan off-canvas mobile, workspace bar, komposisi tiap halaman, questionnaire navigation, drawer preview, responsive breakpoint, keyboard states, dan motion. |
| `css/vistra-midnight.css` | Material bersama diperluas ke notifikasi dan rekomendasi dinamis, perbaikan warna teks, rank, dan CTA. Geometri lama yang sudah digantikan dirapikan. |
| `js/vistra-workspace.js` (baru) | Perilaku presentasi: judul workspace, akses rail mobile, stepper sesuai renderer registrasi asli, navigasi antarfaktor dan kelengkapan jawaban, label faktor yang terverifikasi, fokus modal, serta ringkasan history dari cache yang sudah dimuat. Tidak memanggil API, mengubah sesi, atau menghitung skor. |
| `js/main.js` | Class semantik untuk region Ringkasan UMKM; label ringkasan memakai kamus faktor terverifikasi; renderer label Benchmarking mempertahankan span rail; deskripsi warna radar disesuaikan; inisialisasi grafik `trendMini` tanpa canvas dan angka contoh lama dihapus. Query, skor, dan kontrak data tetap. |
| `VISTRA_V3_REDESIGN.md` (baru) | Cakupan, validasi, dan keterbatasan pengujian. |

Material kaca tetap memakai token V2; komposisi dimiliki satu layout system V3. Sebanyak 125 deklarasi geometri lama di HTML/material stylesheet dihapus. Aturan legacy yang masih diperlukan renderer dipertahankan. Layer reduced motion memiliki prioritas tersendiri agar animasi lama maupun baru dapat dinonaktifkan secara konsisten.

Tidak ada framework atau dependency runtime baru. `auth.js`, `form.js`, `invitations.js`, `api.js`, `api-umkm.js`, dan `vistra-theme.js` identik dengan snapshot sebelum pekerjaan ini. Pertanyaan, opsi, nilai radio, rumus, dan identifier penyimpanan tidak diubah.

## Cakupan halaman

| Halaman/state | Komposisi V3 dan batas uji |
| --- | --- |
| Landing | Hero aurora terpusat, product preview berbasis komponen asli tanpa metrik dummy, bento value proposition, langkah evaluasi vertikal, CTA. Diperiksa di tiga viewport. |
| Login | Satu kartu glass terpusat, shell brand baru. Pilihan Owner/Employee tetap memakai handler asli. Tidak melakukan login. |
| Registrasi | Centered wizard mengikuti dua tahap Owner yang asli; Employee memakai navigasi bagian akun/undangan dalam satu form. Pergantian peran dan focus jump diuji, tanpa membuat akun. |
| Home | Bento skor dominan, identitas usaha, empat informasi ringkas, chart enam faktor, insight, dan panel history/link ke ringkasan. History dibatasi ke UMKM akun aktif dan memakai cache Ringkasan UMKM yang sudah dimuat; sebelum tersedia tampil keterangan, tanpa menciptakan timeline. |
| Factor Profile | Radar terpusat dan enam detail card di bawahnya; progress/category tetap terikat kode faktor asli. Enam nilai diverifikasi terhadap snapshot database read-only. |
| Distribution | Statistik di sisi histogram, interpretasi dan outlier pada deck bawah. Mobile menjadi dua kolom KPI dan panel berurutan. |
| Benchmarking | Header dan KPI asimetris, comparison besar, insight samping, radar dan tindak lanjut, lalu ranking/ringkasan. Grid bertumpuk dan radar terlalu sempit yang ditemukan saat uji sudah diperbaiki. |
| UMKM & Recommendations | Directory sebagai region utama, ranking/rekomendasi sebagai side deck. Tabel tetap scroll horizontal di dalam panel. Kartu rekomendasi terang diperbaiki dan details diuji dengan skor faktor asli. |
| Ringkasan UMKM | Region profil, KPI, faktor, anggota, periode, dan undangan. Renderer diuji dengan snapshot usaha/faktor/periode asli yang disanitasi; data anggota tidak disalin ke fixture. Layout formulir undangan diuji terpisah dari markup renderer asli. Belum diuji dengan sesi dan daftar anggota/undangan nyata. |
| Form Data | Navigasi faktor sticky, progress berdasarkan pertanyaan terjawab, pertanyaan asli, sidebar live calculation asli, preview drawer. Kedua peran diuji. State loading/submitted tetap menyembunyikan panel input lanjutan sesuai handler asli. |
| Profil Saya | Horizontal identity strip, business details dan action panels. Renderer diuji dengan subset akun asli tanpa email/password; field yang tidak disertakan menampilkan fallback. |
| Help | Category rail, kolom FAQ, panel referensi; pencarian dan details diuji. |
| Notifikasi | Summary deck dan timeline terpisah, tanpa banner ungu atau kartu putih. |
| Modal/dropdown/toast/loading/empty | Material, spacing dan states bersama; preview menjadi drawer; modal memiliki fokus masuk, Tab trap, Escape dan pemulihan fokus. Dropdown akun, navigasi dan empty states diperiksa. |
| Admin SPA | Rail dan delapan tujuan admin serta shell overview diperiksa. Tampilan data admin yang terisi memerlukan sesi platform_admin. |

Admin terpisah di `backend/admin.php` tidak diedit karena batasan melarang perubahan PHP. Tampilan tersebut tidak termasuk klaim penyelesaian V3.

## Validasi

Chrome headless lokal pada 1440, 820, dan 390 px. Matriks dasar mencakup 14 halaman/state per viewport (42 screenshot): landing, login, register, register2, home, factor, distribution, comparison, umkmrec, umkmsummary, formdata, profile, help, notifications. Screenshot tambahan mencakup Employee register, renderer ringkasan/profil, kedua role form, preview, invitation markup, recommendation, dan admin shell.

- Tidak ada horizontal overflow dokumen pada matriks dan komponen tambahan. Tabel lebar memiliki scroll internal.
- Tidak ada `pageerror` JavaScript dalam pengujian. Grafik tidak lagi membuat error context untuk canvas `trendMini` yang tidak ada.
- Parser CSS dan pemeriksaan sintaks JavaScript/empat inline script lulus.
- 120 ID awal tetap tersedia, tidak ada ID statis duplikat; seluruh handler lama dan 39 data attribute tetap tersedia. Ada tiga ID statis baru dan satu tombol navigasi history tambahan.
- Background tiga factor card: `rgba(10, 25, 46, 0.46)`; filter `blur(18px) saturate(1.45)`. Invitation panel juga diuji dengan material yang sama.
- Rail compact/expanded, overlay mobile, inert saat tertutup, navigasi mouse, tombol UMKM Saya, dropdown akun, modal Escape, focus jump, FAQ dan progress jawaban lulus.
- Native radio Likert yang sebelumnya disembunyikan menjadi target keyboard yang tetap tersembunyi secara visual dan memiliki indikator fokus pada dot.
- Reduced motion: page animation `none`, aurora `none`, transition `0s`. Normal mode: page reveal dan aurora aktif.
- Kondisi distribusi 0, 1, dan beberapa data diuji pada helper di memori; kondisi satu UMKM nyata juga dirender di browser. Tidak ada fixture yang disimpan ke database atau menjadi data default aplikasi.
- Semua request API dalam browser pengujian diblokir. Tidak ada request tulis yang teramati. Error koneksi/toast yang tampak pada sebagian screenshot merupakan akibat pemblokiran ini.

Enam faktor menggunakan definisi `factor_definitions` yang diverifikasi melalui transaksi read-only lokal, tanpa membaca konfigurasi privat:

| Kode | Label utama | Skor asli pada skala 5, ditampilkan dua desimal |
| --- | --- | --- |
| INS | Sumber Daya | 4.44 |
| LDI | Kepemimpinan | 3.67 |
| WEQ | Proses | 3.40 |
| OV | Budaya | 3.63 |
| OPS | Inovasi | 4.00 |
| ECT | Eksternal | 4.00 |

Nilai radar, kartu dan progress diverifikasi sama dengan nilai normalisasi asli × 5. Perubahan label tidak menukar urutan kode atau nilai.

## Bukti lokal dan pemeriksaan lanjutan

Screenshot dan keluaran pengujian tersimpan sementara di `/tmp/vistra-v3/`:

- [Home sebelum](/tmp/vistra-v3/before-1440-home.png) · [Home sesudah](/tmp/vistra-v3/after-1440-home.png)
- [Landing sebelum](/tmp/vistra-v3/before-1440-landing.png) · [Landing sesudah](/tmp/vistra-v3/after-1440-landing.png)
- [Factor sebelum](/tmp/vistra-v3/before-1440-factor.png) · [Factor sesudah](/tmp/vistra-v3/after-1440-factor.png)
- [Distribution mobile](/tmp/vistra-v3/after-390-distribution.png)
- [Matriks hasil](/tmp/vistra-v3/after-results.json) · [Interaksi](/tmp/vistra-v3/interactions-results.json) · [State tambahan](/tmp/vistra-v3/extras-results.json) · [Motion](/tmp/vistra-v3/motion-results.json) · [Rekomendasi](/tmp/vistra-v3/recommendation-results.json)

Batasan: belum tersedia sesi akun uji. Rendering terisi di atas adalah pemeriksaan komponen dengan subset data asli, bukan pengujian API terautentikasi end-to-end. Login/logout server, registrasi berhasil, pembuatan/pencabutan undangan, pembuatan/penguncian periode, penyimpanan evaluasi, laporan PDF dan admin berisi data perlu diverifikasi memakai sesi Owner/Employee/Admin. Tidak ada tindakan tersebut dijalankan dalam pengujian ini. Dataset lokal hanya menyediakan satu UMKM; distribusi banyak UMKM nyata belum dapat diuji. Kontras diperiksa secara visual dan melalui warna computed style; ini bukan sertifikasi aksesibilitas seluruh state.

Untuk review manual: hard refresh `http://localhost/VISTRA/`, periksa rail/halaman pada tiga lebar tersebut, lalu gunakan akun uji untuk meninjau renderer setelah respons API asli diterima. Lakukan review tanpa menekan tombol simpan, buat akun, buat/cabut undangan, atau ubah periode bila ingin tetap read-only.
