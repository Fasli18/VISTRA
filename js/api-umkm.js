// ============================================================
// KOYOUMKM — Tambahan API: daftar UMKM untuk register pegawai
// File: js/api-umkm.js
// Muat SETELAH js/api.js dan SEBELUM js/auth.js.
// Tidak mengubah fungsi lama; hanya menambah AuthAPI.umkmOptions().
// ============================================================
(function () {
  if (typeof AuthAPI === 'undefined') return;

  // Gunakan endpoint yang sama dengan login/register; pertahankan override lama.
  const API_URL = window.KOYO_API_URL || API_BASE;

  AuthAPI.umkmOptions = async function (query = '') {
    const url =
      API_URL + '?action=umkm_options' +
      (query ? '&q=' + encodeURIComponent(query) : '');

    const res = await fetch(url, { headers: { Accept: 'application/json' } });

    let json = null;
    try { json = await res.json(); } catch (error) { /* respons bukan JSON */ }

    // Bentuk hasil sama dengan AuthAPI.login/register: { ok, data, message }
    return {
      ok: Boolean(res.ok && json && json.success),
      data: json ? json.data : null,
      message: (json && json.message) || ''
    };
  };
})();
