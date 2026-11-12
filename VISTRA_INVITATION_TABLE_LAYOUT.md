# Perbaikan Riwayat Undangan VISTRA V3

Panel kanan bento sebelumnya tidak memiliki batas `min-width:0`. Tabel dengan minimum 520 px dan email tanpa pemenggalan dapat memperbesar ukuran intrinsik panel; wrapper `overflow-x:auto` saja belum menjamin kolom Aksi tetap terjangkau.

Perubahan terbatas pada komponen undangan:

- `css/vistra-workspace.css`: membatasi lebar panel/host; tabel memiliki layout kolom tetap dan minimum 700 px agar empat kolom tetap terbaca; email panjang membungkus; overflow hanya di region tabel; petunjuk geser dan scrollbar bertema V3; tombol aksi dapat turun baris tanpa terpotong.
- `js/invitations.js`: class markup tabel, region scroll yang dapat difokuskan dan memiliki label aksesibel, petunjuk geser, wrapper tombol, serta wrapper sticky untuk kode/salin. ID dan data attribute aksi lama dipertahankan.
- `index.html`: cache version stylesheet/renderer diperbarui.
- `VISTRA_INVITATION_TABLE_LAYOUT.md`: laporan ini.

Tidak ada perubahan warna/layout global, endpoint, autentikasi, data, atau database. Callback aksi dan proses mount tetap identik dengan snapshot sebelumnya jika tambahan markup baris kode dikecualikan.

## Hasil browser

| Viewport | Lebar panel | Lebar region tabel | Lebar tabel | Hasil |
| --- | --- | --- | --- | --- |
| 1440 px | 527,5 px | 472 px | 700 px | Scroll internal; semua aksi terjangkau di kanan. |
| 820 px | 780 px | 724 px | 724 px | Keempat kolom muat dalam panel. |
| 390 px | 362 px | 322 px | 700 px | Scroll internal; semua aksi terjangkau di kanan. |

Pengujian memakai fixture email panjang, empat status undangan, Lihat Kode dan Cabut bersamaan pada undangan pending. Fixture hanya berada di browser pengujian; tidak menjadi data aplikasi atau ditulis ke database. Ringkasan di belakang panel memakai snapshot read-only dari pengujian sebelumnya. Alamat email anggota ditutup pada screenshot.

Pemeriksaan dilakukan pada batas panel/region dan bounding rectangle masing-masing tombol, bukan hanya `document.scrollWidth`. Seluruh tombol berada utuh dalam viewport region setelah scroll ke kanan. ArrowRight dapat menggeser region melalui keyboard saat diperlukan; Tab mencapai tombol aksi. Kode yang dibuka tetap terlihat walaupun posisi scroll berada di kanan; tombol Salin tetap tersedia. Email panjang tetap dapat dibaca dengan menggeser kembali ke kiri.

Handler Lihat Kode, konfirmasi Cabut dan Muat ulang lulus menggunakan adapter panggilan di memori. Payload ID/metode/aksi diperiksa. Tidak ada request tulis jaringan asli, horizontal overflow dokumen, atau runtime `pageerror`. Sintaks JavaScript dan parser CSS lulus. Pengujian ini tidak menggunakan sesi login dan tidak mengeksekusi aksi terhadap undangan nyata.

## Screenshot sesudah

| Viewport | Sisi email | Sisi aksi/kode |
| --- | --- | --- |
| Desktop 1440 | [Email panjang](/tmp/vistra-invitation-layout/after-1440-email.png) | [Aksi dan kode](/tmp/vistra-invitation-layout/after-1440-panel.png) |
| Tablet 820 | [Semua kolom](/tmp/vistra-invitation-layout/after-820-email.png) | [Aksi dan kode](/tmp/vistra-invitation-layout/after-820-panel.png) |
| Mobile 390 | [Email panjang](/tmp/vistra-invitation-layout/after-390-email.png) | [Aksi dan kode](/tmp/vistra-invitation-layout/after-390-panel.png) |

[Hasil pengujian geometri dan interaksi](/tmp/vistra-invitation-layout/results.json). Artefak tersimpan sementara di `/tmp/vistra-invitation-layout/`. Tidak ada commit atau deploy.
