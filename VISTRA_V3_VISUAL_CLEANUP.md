# VISTRA V3 — Final Visual Cleanup

11 November 2026. Hanya presentasi frontend; tidak ada perubahan backend, database, autentikasi, skor, maupun n8n. Tidak melakukan commit/deploy dan tidak membaca konfigurasi privat.

## Temuan dan perbaikan

Badge anggota pada renderer Ringkasan UMKM memakai background pastel inline `#e7f7f1`. Aturan warna teks legacy menimpanya menjadi `#b0c5de`, sehingga teks pucat bertemu latar terang. Tombol PDF memakai putih transparan inline dan belum memakai komponen tombol V3.

- Badge anggota, kelengkapan evaluasi dan status periode kini memakai `.v-status` dengan varian success/warning/error/info/neutral. Teks dan kondisi status asli dipertahankan.
- Token status menyediakan latar gelap transparan, warna teks, dan border tersendiri. Sukses tetap hijau/mint, peringatan amber, error merah/rose, informasi cyan, nonaktif netral.
- Varian badge faktor, skor tabel, benchmarking, notifikasi, admin SPA, popup hasil, serta toast memakai sistem warna status yang sama. Tombol tindakan berbahaya tetap memiliki aksen error.
- Tombol PDF memakai komponen `v-report-button`: navy glass, highlight cyan, teks ice white, blur, hover dan focus yang jelas. Handler tetap `generateUmkmPdfReport()`.
- Aturan legacy yang mereset semua tombol di dalam elemen berlatar putih dihapus; tombol menggunakan class/varian yang sesuai.
- Aksen ungu pada detail faktor popup dan ikon pengantar form Employee diganti cobalt/cyan. Nilai, label data, dan fungsi tidak diubah.
- Tabel anggota mobile membungkus email agar kolom peran dan badge terlihat bersamaan. Tidak ada data yang dihapus; email hanya ditutup pada screenshot.
- Aksen ungu pada template laporan cetak diganti cobalt. Dokumen cetak tetap memakai kertas terang agar terbaca saat dicetak. Fungsi laporan identik dengan versi sebelum perbaikan bila bagian CSS dikecualikan.

## File

| File | Perubahan |
| --- | --- |
| `css/vistra-midnight.css` | Token dan komponen status/tombol, konsolidasi varian status, aksen form/popup, tabel anggota mobile. Aturan komponen yang ada diperbarui; tidak membuat stylesheet override tambahan. |
| `js/main.js` | Mengganti warna pastel inline dengan class status semantik dan class tombol PDF; warna CSS laporan cetak. Tidak mengubah query, teks data, formula, atau handler. |
| `index.html` | Cache version stylesheet dan script renderer diperbarui agar browser memuat perbaikan. |
| `VISTRA_V3_VISUAL_CLEANUP.md` | Laporan ini. |

`auth.js`, `form.js`, `invitations.js`, `api.js`, `api-umkm.js`, `feedback-popup.js`, `vistra-workspace.js`, dan `vistra-workspace.css` tetap identik dengan snapshot awal cleanup.

## Validasi

- Audit sumber dan browser: landing, login, registrasi dua tahap, Home, Factor Profile, Distribution, Benchmarking, directory/rekomendasi, Ringkasan UMKM, Form Data, Profil Saya, Help dan notifikasi. Matriks 14 tampilan/state × 3 viewport: 1440, 820, 390 px.
- Tidak ada runtime `pageerror` atau overflow dokumen. Pemindai computed style tidak menemukan permukaan terang atau gradient/solid ungu pada area yang diuji. Garis ikon hamburger, teks terang, dan kertas laporan tidak dikategorikan sebagai permukaan UI yang salah.
- Ringkasan Owner dan Employee diperiksa pada 1440/390 px dengan snapshot read-only usaha, periode, enam faktor, serta dua anggota yang memang sudah tervalidasi di database lokal. Tidak ada fixture yang disimpan ke database. Request API browser diblokir; respons read adapter diganti sementara hanya untuk pengujian renderer, lalu dikembalikan.
- Badge tervalidasi: sebelumnya `rgb(231,247,241)` + teks `rgb(176,197,222)`; sesudah `rgba(7,52,44,.86)` + teks `rgb(114,228,189)` dengan `blur(18px) saturate(145%)`.
- Tombol PDF: `rgba(10,40,65,.82)`, gradient highlight, teks `rgb(232,243,255)`. Tidak tertutup overlay, dapat difokuskan dengan keyboard, dan handler asli tetap sama.
- Klik tombol PDF diuji dengan penampung jendela sementara: menghasilkan HTML laporan berisi brand, skor dan status anggota asli serta aksen cobalt. Tidak mencetak atau membuat file PDF sungguhan.
- Enam belas varian badge/status diuji. Rasio kontras minimum sekitar **5,21:1**, termasuk komposit transparansi di atas putih sebagai batas konservatif.
- Popup hasil kedua peran diuji dengan nilai faktor asli; tidak ditemukan permukaan putih atau ungu. Ini uji renderer popup, bukan pengiriman evaluasi.
- Regresi tiga viewport: perpindahan peran registrasi, rail/overlay, navigasi, dropdown, modal Escape, form Owner 16 pertanyaan/Employee 19 pertanyaan, progress, preview, FAQ dan shell admin SPA lulus. Tidak ada request tulis teramati.
- Parser CSS, sintaks JS dan inline script lulus. Seluruh ID awal, handler dan data attribute tetap tersedia.

Batas uji: belum tersedia sesi login akun uji, sehingga hasil di atas bukan pengujian end-to-end autentikasi/API. Pembuatan akun, undangan, perubahan periode dan penyimpanan evaluasi tidak dijalankan. Dialog cetak/PDF OS dan admin PHP terpisah tidak diuji atau diubah. Varian status yang belum tersedia dalam data nyata diperiksa sebagai komponen di memori.

## Screenshot dan bukti lokal

- [Owner desktop sesudah](/tmp/vistra-v3-cleanup/after-1440-summary-owner.png)
- [Employee mobile sesudah](/tmp/vistra-v3-cleanup/after-390-summary-employee.png)
- [Owner mobile sesudah](/tmp/vistra-v3-cleanup/after-390-summary-owner.png)
- [Employee desktop sesudah](/tmp/vistra-v3-cleanup/after-1440-summary-employee.png)
- [Ringkasan sebelum](/tmp/vistra-v3-cleanup/before-1440-summary-owner.png)
- [Popup Employee mobile](/tmp/vistra-v3-cleanup/after-390-popup-employee.png)
- [Hasil Ringkasan](/tmp/vistra-v3-cleanup/after-summary-results.json) · [Komponen/kontras](/tmp/vistra-v3-cleanup/components-results.json) · [Matriks halaman](/tmp/vistra-v3-cleanup/after-results.json) · [Regresi](/tmp/vistra-v3-cleanup/regression-results.json)

Screenshot menutup alamat email tanpa mengubah isi aplikasi. Artefak pengujian tersimpan sementara di `/tmp/vistra-v3-cleanup/`. Untuk review manual, hard refresh `http://localhost/VISTRA/`, lalu buka Ringkasan UMKM pada akun yang memiliki data.
