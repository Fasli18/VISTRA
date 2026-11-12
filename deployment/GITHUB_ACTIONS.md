# Auto deploy VISTRA

Workflow: `.github/workflows/deploy.yml`. Hanya repository `Fasli18/VISTRA`,
branch `main`; berjalan pada push dan manual melalui **Actions → VISTRA Auto
Deploy → Run workflow → main** setelah workflow tersedia di GitHub.

## Secrets khusus repository VISTRA

Buat di **Fasli18/VISTRA → Settings → Secrets and variables → Actions →
Repository secrets**. Isi melalui UI privat; jangan tulis password pada file,
issue, commit, atau log.

| Secret | Isi |
| --- | --- |
| `VISTRA_FTP_HOST` | FTP hostname dari panel akun VISTRA, tanpa `ftp://`, port, atau path. Gunakan hostname yang cocok dengan sertifikat TLS. Ini bukan domain website. |
| `VISTRA_FTP_USERNAME` | Username FTP akun VISTRA `if0_43420750`. |
| `VISTRA_FTP_PASSWORD` | Password FTP akun VISTRA dari panel privat. |

Tujuan website: `vistra-bi.freehosting.dev`; target tetap `/htdocs`, bukan
`/htdocs/VISTRA` atau folder akun lain. Identitas akun di uploader merupakan
guard publik untuk menolak secret username akun lain; autentikasi selalu
mengambil nilai dari Secrets. Jangan menggunakan kredensial atau secret proyek lain.

## Batas pengamanan

- Checkout dipatok ke SHA action, token hanya `contents: read`, kredensial Git
  tidak dipersistenkan. Job ditolak pada repository/branch lain. Concurrency
  menserialkan deployment; run aktif tidak dibatalkan oleh push berikutnya.
- Build memakai source checkout dan `tools/build_release.py`, menuju folder
  baru di `runner.temp`. Tidak mengambil paket Desktop atau config lokal.
- Allowlist harus tepat 22 file dan sama dengan daftar independen di
  `tools/deploy_runtime.py`. File harus tracked, tidak kosong, tanpa symlink;
  config privat tracked, perubahan proteksi wajib, atau indikasi secret tertentu
  membuat job gagal. Pemindaian pola bukan jaminan mendeteksi semua secret.
- Sebelum koneksi FTP: inventaris paket, direktori, hash SHA-256 source/paket/
  manifest, serta lint PHP dan JS harus lulus. PHP hanya dilint dengan `-n -l`,
  tidak dieksekusi; tidak membuka DB, menjalankan aplikasi atau memanggil n8n.
- FTP memakai explicit TLS port 21, validasi sertifikat dan enkripsi data;
  gagal TLS menghentikan job, tanpa fallback plaintext. Host/username/password
  hanya diberikan ke langkah upload; exception FTP mentah tidak dicetak.
- Hanya `STOR /htdocs/<path allowlist>` dan pembuatan empat direktori runtime
  bila belum ada. Tidak ada DELETE, RMD, rename, mirror, unduhan config,
  sinkronisasi state, atau pembersihan remote. `/htdocs` harus sudah tersedia.
- Ketiga `.htaccess` dikirim lebih dahulu, `index.html` terakhir. Ukuran tiap
  file remote diperiksa sesudah upload. Manifest berada di luar paket dan tidak
  diunggah; SQL, dokumentasi, tes, `.env`, config lokal/contoh tidak masuk paket.

`backend/php/config.php` produksi tetap dikelola privat langsung pada hosting.
Pipeline tidak membuat, membaca, mengganti, atau menghapusnya dan tidak membutuhkan
secret DB/JWT. File tersebut harus sudah tersedia agar aplikasi dapat berfungsi.
Proteksi root dan `backend/php/.htaccess` ikut dikirim untuk menolak akses HTTP.

FTP per file tidak atomik: kegagalan jaringan dapat meninggalkan sebagian file
runtime versi baru. Job akan gagal, bukan melaporkan sukses; jalankan ulang commit
yang sama setelah penyebabnya diperbaiki. File lama di luar allowlist sengaja tidak
dihapus. Tidak ada pemeriksaan HTTP otomatis terhadap situs/API.

## Hasil review lokal — 12 November 2026

Lulus `actionlint` v1.7.12, validasi build tepat 22 file beserta hash, lint 5
file PHP dan 9 file JS. Simulasi FTPS membuktikan tepat 22 tujuan `STOR`,
proteksi lebih dahulu dan `index.html` terakhir; tidak ada operasi config/hapus.
Kasus negatif menolak payload tambahan (config sintetis, `.env`, SQL, docs,
tes), hash berubah, symlink, direktori tambahan, repository/branch/akun salah,
secret kosong, host tidak valid, allowlist/proteksi berubah dan pola secret
sintetis. Builder menolak output existing dan output di dalam checkout.

Belum ada eksekusi GitHub Actions, koneksi hosting, verifikasi TLS server aktual
atau verifikasi aturan Apache di hosting. Tidak membaca config privat, mengubah
database, memanggil n8n, menyentuh KARSA, melakukan commit atau push.

## Validasi lokal tanpa deployment

```sh
python3 tools/deploy_runtime.py validate-source
python3 tools/build_release.py --output /tmp/vistra-runtime-review-UNIQUE
python3 tools/deploy_runtime.py validate-release --release /tmp/vistra-runtime-review-UNIQUE
actionlint .github/workflows/deploy.yml
```

Gunakan nama output baru untuk setiap build. Jangan menjalankan subcommand
`upload` untuk review lokal. Uploader juga menolak eksekusi di luar GitHub Actions
repository VISTRA branch main.

Pembuatan file workflow secara lokal tidak mengaktifkan deployment. Setelah
kelak workflow dipush ke `main`, trigger push langsung aktif dan akan mencoba
deploy bila secret sudah diisi. Pekerjaan persiapan ini tidak mencakup commit,
push, pengisian secret atau deployment.

Referensi: [sintaks GitHub Actions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
dan [dukungan FTP/TLS InfinityFree](https://forum.infinityfree.com/t/unable-to-ftp-for-new-account-and-domain/120145/2).
