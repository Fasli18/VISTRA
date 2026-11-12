# VISTRA V2 — UI Consistency Audit & Final Polish

Tanggal: 11 November 2026, Asia/Jakarta.
Proyek: `/Applications/XAMPP/xamppfiles/htdocs/VISTRA`.

## Perubahan

- `css/vistra-midnight.css` disusun ulang menjadi tokens, komponen reusable, state interaksi, serta aturan responsif. CSS cascade layers memprioritaskan tema atas stylesheet lama yang disisipkan renderer tanpa menaikkan spesifisitas berulang.
- Material kaca dan aurora Home dipertahankan untuk kartu, chart, sidebar, navbar, halaman analitik, profil, Help, formulir, modal, dan panel admin frontend utama.
- Diperbaiki: FAQ bertulisan gelap, tombol Help putih/ungu, dropdown sektor berwarna lama, kalkulasi formulir, popup hasil, bingkai input ganda, field omzet terang, avatar, serta pemberitahuan admin.
- Warna button gradient disesuaikan agar teks putih memiliki rasio kontras 5,17:1 / 5,77:1 / 5,33:1 pada ketiga stop. Ini pemeriksaan stop gradient, bukan sertifikasi aksesibilitas seluruh aplikasi.
- `js/vistra-theme.js` hanya memperluas pemetaan warna grafik lama, termasuk hover dan fill transparan. Label, data numerik, callback, endpoint dan aturan perhitungan tidak diubah.

## Cakupan browser

Chrome headless lokal, viewport desktop 1440×1000 dan mobile 390×1000. Tersedia 62 tangkapan halaman/state dalam matriks utama, ditambah state loading formulir, template undangan, dan screenshot tooltip referensi. Semua screenshot sebelum/sesudah tersimpan di `/tmp/vistra-consistency/before/` dan `/tmp/vistra-consistency/after/`.

| Halaman/komponen | State yang diperiksa pada kedua ukuran |
|---|---|
| Landing | Hero, preview enam faktor, fitur, CTA, footer |
| Login | Owner dan Employee, input, toggle password |
| Registrasi | Owner tahap 1/tahap 2, dropdown provinsi/sektor, Employee/kode undangan |
| Home | Kondisi tanpa data akun, tiga kartu KPI dan grafik |
| Factor Profile | Kartu faktor, radar dan tooltip titik tengah bawaan |
| Distribution | Statistik/chart dalam kondisi data tidak tersedia |
| Benchmarking | Kartu, panel dan ringkasan tanpa data akun |
| UMKM & Recommendations | Tabel kosong, pagination, dropdown filter |
| Ringkasan UMKM | State data tidak dapat dimuat; template undangan kosong diaudit terpisah |
| Form Data | Loading/error, formulir Owner/Employee, pilihan radio/likert, pratinjau belum lengkap |
| Profil Saya | Template tanpa nilai profil, tombol navigasi |
| Help | Pencarian, FAQ keyboard, kartu kategori, SVG box plot, CTA |
| Overlay | Dropdown akun/sektor, modal logout, toast, popup hasil dengan placeholder |
| Admin frontend utama | Overview dan tujuh subhalaman, placeholder/loading/error serta struktur tabel |

Template Owner/Employee/admin dirender dalam konteks role UI saja, tanpa membuat akun atau menambah record bisnis. Template undangan memakai markup persis dari renderer yang ada; tidak ditambahkan email, kode, riwayat, atau hasil buatan. Popup kosong hanya mengaudit material/layout, bukan hasil evaluasi tersimpan yang sebenarnya.

## Hasil validasi

- Matriks akhir: tidak ditemukan overflow horizontal, permukaan putih besar yang tidak sesuai, teks ungu lama atau teks gelap yang terdeteksi scanner. Scanner warna adalah heuristik dan dilengkapi inspeksi screenshot, bukan audit WCAG lengkap.
- Tidak ada JavaScript runtime error (`pageerror`) dalam pemeriksaan.
- Tiga KPI pada kedua viewport: `background-color: rgba(10,25,46,0.46)` dan `backdrop-filter: blur(18px) saturate(1.45)`.
- Lulus: pilihan role, toggle password, dropdown provinsi, navigasi UMKM Saya dengan Enter, pencarian/FAQ Help, pilihan radio/likert, pratinjau, tutup popup melalui Escape, serta fokus awal popup.
- Hit testing tombol UMKM Saya lulus; tidak ada lapisan dekoratif yang menangkap klik.
- Data dataset sebelum/sesudah update grafik identik. Tooltip referensi memakai ice white, dan animasi grafik dinonaktifkan saat reduced motion aktif.
- Sintaks seluruh JavaScript dan parsing stylesheet lulus; tidak ada properti ganda dalam satu rule pada stylesheet tema.
- Request API diblokir di browser audit; tidak ada POST atau operasi database yang dilakukan. Satu GET publik `umkm_options` juga berhasil (1 entri), tanpa menampilkan nama atau informasi akun di laporan.
- Semua HTML, ID, data attributes, handler, script aplikasi selain skrip tema, serta definisi pertanyaan tetap identik dengan baseline.

## Bukti sebelum/sesudah

- Help: [sebelum](/tmp/vistra-consistency/before/help-1440.png) · [sesudah](/tmp/vistra-consistency/after/help-1440.png).
- Filter sektor: [sebelum](/tmp/vistra-consistency/before/filter-dropdown-1440.png) · [sesudah](/tmp/vistra-consistency/after/filter-dropdown-1440.png).
- Form Owner: [sebelum](/tmp/vistra-consistency/before/form-owner-1440.png) · [sesudah](/tmp/vistra-consistency/after/form-owner-1440.png).
- Registrasi tahap 2 mobile: [sebelum](/tmp/vistra-consistency/before/register-owner-step2-390.png) · [sesudah](/tmp/vistra-consistency/after/register-owner-step2-390.png).
- Admin utama: [sebelum](/tmp/vistra-consistency/before/admin-1440.png) · [sesudah](/tmp/vistra-consistency/after/admin-1440.png).

## Batas dan pemeriksaan manual

1. Pengguna mengonfirmasi bahwa sesi akun uji belum tersedia. Karena itu state setelah data akun berhasil dimuat, hasil evaluasi tersimpan, riwayat/kode undangan, dan tabel berisi data autentikasi belum diverifikasi end-to-end. Tidak dibuat data dummy sebagai pengganti. Tes placeholder dan template tidak dianggap bukti keberhasilan pemuatan data nyata.
2. Halaman admin mandiri `backend/admin.php` diperiksa namun tidak diubah: halaman tersebut memiliki HTML/CSS terpisah dan tidak memuat stylesheet tema. Menyatukannya memerlukan perubahan pada file PHP, yang dilarang oleh cakupan tugas. Panel admin di frontend utama `index.html` termasuk dalam perbaikan ini.
3. Pengujian browser dilakukan pada Chrome desktop dan emulasi mobile, bukan perangkat Safari/iOS fisik. Fallback tanpa backdrop-filter tersedia, namun belum diuji pada engine tanpa dukungan tersebut.
4. Tidak diubah: PHP, database, API, autentikasi, undangan, scoring, n8n, konfigurasi privat, atau proyek lain. Tidak ada commit/deploy.
