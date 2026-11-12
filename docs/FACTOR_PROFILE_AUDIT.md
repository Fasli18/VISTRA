# Factor Profile VISTRA — audit dan perbaikan

Tanggal: 11 November 2026 (Asia/Jakarta).

## Temuan dan keputusan sumber data

Tabel lokal `vistra_db.factor_definitions` dibaca dalam transaksi READ ONLY, tanpa membuka `backend/php/config.php`. Terdapat satu hasil gabungan tersimpan (result ID 1), dengan enam rincian pada `result_factor_scores`.

`OPS` didefinisikan sebagai **Inovasi — Operational Stability**. Validator PHP juga memakai label pendek **Inovasi**, sedangkan pemetaan teks pada endpoint leaderboard memakai **Stabilitas Operasional**. Factor Profile sekarang mengikuti label tabel referensi dan validator. API/validator tidak diubah. Lima kode lain juga diverifikasi terhadap tabel referensi dan backend.

| Kode | Label sumber database | Nilai tersimpan (0–1) | Grafik/kartu (0–5) |
|---|---|---:|---:|
| INS | Sumber Daya — Institutional Resources | 0.8889 | 4.44 / 5 |
| LDI | Kepemimpinan — Leader Involvement | 0.7333 | 3.67 / 5 |
| WEQ | Proses — Work Environment Quality | 0.6800 | 3.40 / 5 |
| OV | Budaya — Organizational Values | 0.7250 | 3.63 / 5 |
| OPS | Inovasi — Operational Stability | 0.8000 | 4.00 / 5 |
| ECT | Eksternal — Economic Connectivity | 0.8000 | 4.00 / 5 |

Konversi normalisasi × 5 adalah perilaku frontend yang sudah ada dan tetap dipertahankan. `scale_max=3` pada INS adalah skala jawaban asli, bukan skala tampilan radar. Tidak ada pertukaran faktor, perubahan bobot, kategori, rumus, jawaban, maupun skor.

## Penyebab visual dan perubahan

Banner ungu berasal dari rule khusus Factor Profile di `index.html`, termasuk selector gabungan yang memakai `!important`. Komponen banner tema bersama sebelumnya hanya mencakup Distribution/Benchmarking, sehingga Factor Profile terlewat.

- `index.html`: 95 selector presentasi lama khusus Factor Profile dihapus dari blok style. ID style dipertahankan sebagai penanda, dan layout dipusatkan pada stylesheet tema. Banner Factor Profile dikeluarkan dari rule ungu gabungan. Legenda memakai class presentasi; placeholder skor/kategori/deviasi statis yang tidak berasal dari data diganti state belum ada data. Canvas memperoleh label dan fokus aksesibel.
- `css/vistra-midnight.css`: Factor Profile memakai material banner bersama navy–cobalt–cyan, blur 18px/saturasi 145%, aurora yang terlihat di belakang panel, highlight translucent, serta shadow berlapis. Layout radar, enam kartu, progress, legenda dan ringkasan ditata di komponen kanonik dan aturan responsif.
- `js/main.js`: satu tabel metadata presentasi enam faktor, diverifikasi dari database, mengendalikan label radar/kartu dan warna aksen berdasarkan kode. Kartu diidentifikasi dengan hook `data-factor-progress`, bukan regex teks nama. Tooltip disamakan ke dua desimal tanpa membulatkan/mengubah dataset. Progress bar dan radar diberi deskripsi aksesibel.

## Pengujian

Browser Chrome lokal pada 1440×1000 dan 390×1000:

- Enam pasangan kode–label–nilai lulus pada kedua ukuran. Dataset numerik radar dan teks skor/kategori kartu sebelum/sesudah identik.
- Nilai tooltip dua desimal sesuai kartu; nama lengkap pada title kartu sama dengan definisi database.
- State tanpa data menampilkan dash dan “Belum ada data”, tanpa nilai statis yang menyesatkan.
- Banner: sebelum `backdrop-filter: none`; sesudah `blur(18px) saturate(1.45)` dengan background semi-transparan.
- Tidak ada horizontal overflow atau JavaScript runtime error.
- Canvas dapat difokuskan dengan keyboard, deskripsi aksesibel memuat keenam kode/nilai, dan progress memiliki rentang 0–5 serta nilai aktual.
- CTA lolos hit-testing dan fokus keyboard. Tidak ada pseudo-element yang menangkap klik.
- Sampling foreground terhadap piksel latar pada enam jenis teks menghasilkan rasio minimum 7,00:1 di desktop dan 7,26:1 di mobile. Ini pemeriksaan representatif, bukan sertifikasi WCAG seluruh aplikasi.
- Sintaks seluruh JavaScript dan parsing stylesheet lulus. ID serta event handler HTML yang sudah ada tetap sama.
- Transformasi data API-ke-skor pada `loadUmkmData()` tetap identik; skrip tema grafik tidak berubah.
- Query definisi faktor dan nilai hasil sebelum/sesudah menghasilkan SHA-256 yang identik. Seluruh akses SQL hanya SELECT dalam transaksi READ ONLY.

## Screenshot

| Ukuran | Sebelum | Sesudah |
|---|---|---|
| Desktop 1440 px | [Sebelum](/tmp/vistra-factor-review/before-1440.png) | [Sesudah](/tmp/vistra-factor-review/after-1440.png) |
| Mobile 390 px | [Sebelum](/tmp/vistra-factor-review/before-390.png) | [Sesudah](/tmp/vistra-factor-review/after-390.png) |

Artefak metadata, pemetaan, kontras dan pengujian berada di `/tmp/vistra-factor-review/`. Snapshot tidak memuat password, token, atau email akun.

## Batas verifikasi

Pengujian nilai menggunakan snapshot data database nyata dalam model presentasi browser terisolasi; bukan data dummy atau API response buatan. Request API browser diblokir agar pengujian tidak menulis data atau membutuhkan token. Pengambilan hasil melalui sesi Owner/Employee yang benar-benar login belum diuji end-to-end. Akses link WhatsApp tidak dijalankan; tujuan dan handler tetap sama.

Perbedaan label OPS di pemetaan leaderboard backend dicatat sebagai ketidakkonsistenan sumber di luar cakupan Factor Profile; tidak ditambal lewat perubahan API. Tampilan halaman lain yang masih menggunakan nama Operasional/Stabilitas Operasional tidak diganti massal dalam tugas ini.

Tidak diubah: PHP, database, endpoint API, autentikasi, n8n, proyek KARSA/KoyoUmkm. Tidak ada commit/deploy.
