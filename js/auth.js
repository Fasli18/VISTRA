// ============================================================
// KOYOUMKM — AUTHENTICATION
// File: js/auth.js
// Membutuhkan: js/api.js dan js/main.js
// ============================================================

let selectedRole = 'owner';
let currentAuthView = 'landing';
let _regTemp = {};
let authBusy = false;
let _umkmOptions = null;   // cache daftar UMKM (hanya untuk register pegawai)

const VIEW_KEY = 'koyo.currentView';

// ============================================================
// HELPERS
// ============================================================

function authEscape(value) {
  return String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  })[character]);
}

function authValue(id) {
  return document.getElementById(id)?.value ?? '';
}

function authEmailValid(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function authNotify(message, type = 'error') {
  if (typeof showToast === 'function') {
    showToast(message, type);
  } else {
    alert(message);
  }
}

// Jika backend menolak token saat Dashboard sedang terbuka,
// hapus sesi lokal dan arahkan pengguna kembali ke Login.
window.addEventListener('koyo:auth-expired', () => {
  if (typeof AuthAPI !== 'undefined') {
    AuthAPI.logout();
  }

  if (typeof AppState !== 'undefined') {
    AppState.currentUser = null;
  }

  if (currentAuthView === 'dashboard') {
    // Pastikan navigasi tidak tertahan oleh status loading formulir.
    authBusy = false;
    showView('login');
    authNotify('Sesi login sudah berakhir. Silakan masuk kembali.');
  }
});

function setLoading(buttonId, loading, text = '') {
  const button = document.getElementById(buttonId);
  if (!button) return;

  button.disabled = loading;
  button.textContent = loading ? 'Memproses...' : text;
}

function togglePwd(id, button) {
  const input = document.getElementById(id);
  if (!input) return;

  const visible = input.type === 'password';
  input.type = visible ? 'text' : 'password';

  if (button) {
    button.textContent = visible ? 'Sembunyikan' : 'Lihat';

    button.setAttribute(
      'aria-label',
      visible ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'
    );
  }
}

function authUserData(data = {}, fallback = {}) {
  data = data || {};

  const name =
    (data.umkm_name && data.umkm_name !== 'undefined'
      ? data.umkm_name
      : '') ||
    (data.name && data.name !== 'undefined' ? data.name : '') ||
    fallback.umkm_name ||
    data.email?.split('@')[0] ||
    fallback.email?.split('@')[0] ||
    'Pengguna';

  return {
    name,
    umkm_name: name,
    email: data.email || fallback.email || '',
    role: data.role || fallback.role || 'owner',
    user_id: data.user_id ?? fallback.user_id,
    lokasi: data.lokasi || fallback.lokasi || '',
    sektor: data.sektor || fallback.sektor || '',
    omzet: data.omzet ?? fallback.omzet ?? null
  };
}

function authHasSession() {
  if (typeof AuthAPI === 'undefined') return false;

  try {
    return Boolean(AuthAPI.getUser() && AuthAPI.isLoggedIn());
  } catch (error) {
    return false;
  }
}

function rememberView(view) {
  try {
    // Tahap kedua kembali ke tahap pertama setelah refresh.
    // Data formulir dan kata sandi tidak disimpan ke storage.
    const saved = view === 'register2' ? 'register' : view;

    if (['landing', 'login', 'register', 'dashboard'].includes(saved)) {
      sessionStorage.setItem(VIEW_KEY, saved);
    }
  } catch (error) {
    // Aplikasi tetap berjalan jika storage tidak tersedia.
  }
}

function savedView() {
  try {
    return sessionStorage.getItem(VIEW_KEY) || 'landing';
  } catch (error) {
    return 'landing';
  }
}

function syncLandingSession() {
  document.getElementById('landing-page')
    ?.classList.toggle('is-authed', authHasSession());
}

// ============================================================
// NAVIGASI
// ============================================================

function showView(view) {
  if (authBusy) {
    authNotify('Tunggu sebentar, permintaan sedang diproses.');
    return;
  }

  const allowedViews = [
    'landing',
    'login',
    'register',
    'register2',
    'dashboard',
    'logout'
  ];

  if (!allowedViews.includes(view)) return;

  if (view === 'logout') {
    if (typeof AuthAPI !== 'undefined') {
      AuthAPI.logout();
    }

    if (typeof AppState !== 'undefined') {
      AppState.currentUser = null;
      AppState.chartsInit = {};
      AppState.umkmData = [];
      AppState.filteredData = [];
      AppState.dataLoaded = false;
    }

    selectedRole = 'owner';
    _regTemp = {};

    // Setelah logout, tampilkan Login dan simpan pilihan halaman ini.
    showView('login');
    return;
  }

  if (
    view === 'register2' &&
    (!_regTemp.email || !_regTemp.pwd)
  ) {
    view = 'register';
  }

  if (view === 'dashboard' && !authHasSession()) {
    view = 'login';
  }

  currentAuthView = view;
  rememberView(view);

  ['landing-page', 'auth-page', 'dashboard-app'].forEach(id => {
    document.getElementById(id)?.classList.remove('active');
  });

  if (view === 'landing') {
    _regTemp = {};

    document.getElementById('auth-form-container')?.replaceChildren();
    document.getElementById('landing-page')?.classList.add('active');

    syncLandingSession();
  }

  if (['login', 'register', 'register2'].includes(view)) {
    if (view === 'login') {
      _regTemp = {};
    }

    document.getElementById('auth-page')?.classList.add('active');
    renderAuthView(view);
  }

  if (view === 'dashboard') {
    document.getElementById('auth-form-container')?.replaceChildren();
    document.getElementById('dashboard-app')?.classList.add('active');

    initDashboard();
    navigate('home');
  }

  window.scrollTo(0, 0);
}

function backToLanding() {
  showView('landing');
}

// ============================================================
// TOMBOL KEMBALI
// ============================================================

function authBackHTML() {
  const existingBack = document.querySelector(
    '#auth-page .ka-auth-top .ka-back'
  );

  if (existingBack) return '';

  return `
    <button
      type="button"
      onclick="backToLanding()"
      style="
        display:inline-flex;
        align-items:center;
        gap:8px;
        padding:9px 12px;
        margin-bottom:22px;
        border:1px solid #dfe6f1;
        border-radius:10px;
        background:#fff;
        color:#52647f;
        font-family:inherit;
        font-size:12px;
        font-weight:600;
        cursor:pointer;
      ">
      <span aria-hidden="true">←</span>
      Kembali ke Beranda
    </button>
  `;
}

// ============================================================
// RENDER HALAMAN AUTENTIKASI
// ============================================================

function renderAuthView(view) {
  const container = document.getElementById('auth-form-container');
  if (!container) return;

  if (view === 'login') {
    container.innerHTML = renderLoginForm();
  }

  if (view === 'register') {
    container.innerHTML = renderRegisterForm();

    document.getElementById('regPwd').value = _regTemp.pwd || '';

    document.getElementById('regPwdConfirm').value =
      _regTemp.pwdConfirm ?? _regTemp.pwd ?? '';

    document.getElementById('regAgree').checked =
      Boolean(_regTemp.agree);

  }

  if (view === 'register2') {
    container.innerHTML = renderRegisterForm2();

    document.getElementById('reg2Lokasi').value =
      _regTemp.lokasi || '';

    document.getElementById('reg2Sektor').value =
      _regTemp.sektor || '';

    document.getElementById('reg2Omzet').value =
      _regTemp.omzet ?? '';

    // Dropdown kustom untuk Provinsi dan Sektor Usaha
    selDDEnhance('reg2Lokasi', {
      searchable: true,
      searchPlaceholder: 'Cari provinsi'
    });
    selDDEnhance('reg2Sektor');
  }
}

// ============================================================
// PILIHAN PERAN
// ============================================================

function roleCardsHTML() {
  const owner = selectedRole === 'owner';
  const employee = selectedRole === 'employee';

  return `
    <div class="role-selector" aria-label="Pilih peran akun">
      <button
        type="button"
        class="role-card ${owner ? 'selected' : ''}"
        aria-pressed="${owner}"
        onclick="selectRole('owner')">

        <span class="role-card-icon">
          <svg
            width="20" height="20" viewBox="0 0 24 24"
            fill="none"
            stroke="${owner ? '#ffffff' : '#6b7280'}"
            stroke-width="1.8"
            aria-hidden="true">
            <rect x="3" y="7" width="18" height="14" rx="2"/>
            <path d="M8 7V4h8v3M3 12h18"/>
          </svg>
        </span>

        <span class="role-card-title" style="display:block">
          Pemilik Usaha
        </span>
        <span class="role-card-desc" style="display:block">
          Pengelola UMKM
        </span>
      </button>

      <button
        type="button"
        class="role-card ${employee ? 'selected' : ''}"
        aria-pressed="${employee}"
        onclick="selectRole('employee')">

        <span class="role-card-icon">
          <svg
            width="20" height="20" viewBox="0 0 24 24"
            fill="none"
            stroke="${employee ? '#ffffff' : '#6b7280'}"
            stroke-width="1.8"
            aria-hidden="true">
            <circle cx="12" cy="8" r="4"/>
            <path d="M4 21a8 8 0 0 1 16 0"/>
          </svg>
        </span>

        <span class="role-card-title" style="display:block">
          Pegawai
        </span>
        <span class="role-card-desc" style="display:block">
          Anggota tim UMKM
        </span>
      </button>
    </div>
  `;
}

function selectRole(role) {
  if (authBusy) return;
  if (!['owner', 'employee'].includes(role)) return;

  selectedRole = role;

  if (currentAuthView === 'register') {
    // Ganti peran: nama dari peran sebelumnya tidak berlaku lagi.
    if (_regTemp.role && _regTemp.role !== role) {
      _regTemp.name = '';
    }
    _regTemp.role = role;

    const wrap = document.querySelector('#auth-form-container .auth-form-wrap');
    if (wrap) wrap.dataset.role = role;

    const submitButton = document.getElementById('btnReg1');
    if (submitButton) submitButton.textContent = regSubmitLabel();

    const group = document.getElementById('regNameGroup');
    if (group) {
      group.outerHTML = umkmNameFieldHTML();
    }
  }

  const selector = document.querySelector(
    '#auth-form-container .role-selector'
  );

  if (selector) {
    selector.outerHTML = roleCardsHTML();
  }
}

// ============================================================
// LOGIN
// ============================================================

function renderLoginForm() {
  return `
    <div class="auth-form-wrap">
      ${authBackHTML()}

      <h1 class="auth-title">Selamat datang kembali.</h1>
      <p class="auth-subtitle">
        Masuk ke VISTRA untuk melihat hasil evaluasi
        dan memahami kondisi usaha Anda.
      </p>

      <form onsubmit="event.preventDefault(); handleLogin();">
        ${roleCardsHTML()}

        <div class="form-group">
          <label class="field-label" for="loginEmail">
            Email Akun
          </label>
          <div class="field-wrap">
            <input
              type="email"
              id="loginEmail"
              name="email"
              placeholder="nama@usaha.com"
              autocomplete="username"
              required>
          </div>
        </div>

        <div class="form-group">
          <label class="field-label" for="loginPassword">
            Kata Sandi
          </label>
          <div class="field-wrap">
            <input
              type="password"
              id="loginPassword"
              name="password"
              placeholder="Masukkan kata sandi"
              autocomplete="current-password"
              required>

            <button
              type="button"
              class="field-eye"
              aria-label="Tampilkan kata sandi"
              onclick="togglePwd('loginPassword', this)"
              style="
                background:none;
                border:0;
                padding:4px;
                font-size:10px;
                white-space:nowrap;
              ">
              Lihat
            </button>
          </div>
        </div>

        <button type="submit" class="btn-auth" id="btnLogin">
          Masuk ke Dashboard →
        </button>
      </form>

      <p class="auth-link-text">
        Belum punya akun?
        <a href="#"
           onclick="event.preventDefault(); showView('register');">
          Daftar sekarang
        </a>
      </p>
    </div>
  `;
}

async function handleLogin() {
  if (authBusy) return;

  const email = authValue('loginEmail').trim();
  const password = authValue('loginPassword');

  if (!authEmailValid(email)) {
    authNotify('Masukkan alamat email yang valid.');
    return;
  }

  if (!password) {
    authNotify('Kata sandi wajib diisi.');
    return;
  }

  authBusy = true;
  setLoading('btnLogin', true);

  let result;

  try {
    result = await AuthAPI.login({
      email,
      password,
      role: selectedRole
    });
  } catch (error) {
    authNotify(
      'Tidak dapat terhubung ke server. Pastikan Apache dan MySQL aktif.'
    );
    return;
  } finally {
    authBusy = false;
    setLoading('btnLogin', false, 'Masuk ke Dashboard →');
  }

  if (!result?.ok) {
    authNotify(
      result?.message || 'Email, kata sandi, atau peran tidak sesuai.'
    );
    return;
  }

  AppState.currentUser = authUserData(result.data, {
    email,
    role: selectedRole
  });

  authNotify('Berhasil masuk ke VISTRA.', 'success');
  showView('dashboard');
}

// ============================================================
// PILIHAN UMKM (PEGAWAI) — dropdown kustom dengan pencarian
// ============================================================

// Owner mengetik nama usahanya. Pegawai wajib memilih dari UMKM
// yang sudah punya Owner, sehingga salah ketik tidak mungkin terjadi.
// Nilai pilihan disimpan di <input type="hidden" id="regName">,
// jadi kode lain tetap membaca authValue('regName') seperti biasa.

const UMKM_DD = { filtered: [], active: -1, outsideBound: false };

const UMKM_CHEVRON =
  '<svg class="ka-dd-chev" width="16" height="16" viewBox="0 0 24 24" fill="none" ' +
  'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ' +
  'aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>';

const UMKM_CHECK =
  '<svg class="ka-dd-check" width="16" height="16" viewBox="0 0 24 24" fill="none" ' +
  'stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" ' +
  'aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';

function umkmInitial(name) {
  return (String(name || '').trim().charAt(0) || '?').toUpperCase();
}

function umkmDDStyles() {
  if (document.getElementById('ka-dd-style')) return;

  const style = document.createElement('style');
  style.id = 'ka-dd-style';
  style.textContent = `
    #auth-page #regNameGroup { position: relative; z-index: 20; }

    /* Pegawai mendaftar dalam satu langkah, jadi penanda "Langkah 1 dari 2" disembunyikan. */
    #auth-page .auth-form-wrap[data-role="employee"] .ka-step,
    #auth-page .auth-form-wrap[data-role="employee"] > p:not([class]) { display: none; }
    #auth-page .ka-dd { position: relative; }

    #auth-page .ka-dd-btn {
      width: 100%; height: 49px; display: flex; align-items: center; gap: 11px;
      padding: 0 13px; border: 1px solid #e7e8f1; border-radius: 11px;
      background: #f7f7fc; color: #263d5c; font: inherit; font-size: 13px;
      text-align: left; cursor: pointer;
      transition: border-color .18s, background .18s, box-shadow .18s;
    }
    #auth-page .ka-dd-btn:hover:not([disabled]) { border-color: #cfc6f1; }
    #auth-page .ka-dd-btn:focus-visible,
    #auth-page .ka-dd.open .ka-dd-btn {
      outline: none; border-color: #a08de2; background: #fff;
      box-shadow: 0 0 0 4px #6354d912;
    }
    #auth-page .ka-dd-btn[disabled] { cursor: default; }

    #auth-page .ka-dd-av {
      flex: none; width: 28px; height: 28px; border-radius: 9px;
      display: grid; place-items: center; background: #ece8fb; color: #6354d9;
      font-size: 12px; font-weight: 800;
    }
    #auth-page .ka-dd-label {
      flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    }
    #auth-page .ka-dd-ph { color: #97a3b6; }
    #auth-page .ka-dd-btn[disabled] .ka-dd-ph { animation: ka-dd-pulse 1.2s ease-in-out infinite; }
    #auth-page .ka-dd-chev { flex: none; color: #8e9db3; transition: transform .2s, color .2s; }
    #auth-page .ka-dd.open .ka-dd-chev { transform: rotate(180deg); color: #6354d9; }

    #auth-page .ka-dd-panel {
      position: absolute; left: 0; right: 0; top: calc(100% + 8px); z-index: 50;
      padding: 8px; background: #fff; border: 1px solid #e6e9f2; border-radius: 14px;
      box-shadow: 0 18px 40px #2823422e;
      opacity: 0; visibility: hidden; pointer-events: none;
      transform: translateY(-6px) scale(.98); transform-origin: top center;
      transition: opacity .16s, transform .16s, visibility .16s;
    }
    #auth-page .ka-dd.open .ka-dd-panel {
      opacity: 1; visibility: visible; pointer-events: auto; transform: none;
    }

    #auth-page .ka-dd-search {
      display: flex; align-items: center; gap: 8px; height: 40px; padding: 0 11px;
      border: 1px solid #e7e8f1; border-radius: 10px; background: #f7f7fc; color: #8e9db3;
    }
    #auth-page .ka-dd-search:focus-within { border-color: #a08de2; background: #fff; color: #6354d9; }
    #auth-page .ka-dd-search input {
      flex: 1; min-width: 0; border: 0 !important; outline: 0 !important;
      box-shadow: none !important; background: transparent !important;
      font: inherit; font-size: 13px; color: #263d5c;
    }
    #auth-page .ka-dd-search.hide { display: none; }

    #auth-page .ka-dd-list {
      max-height: 232px; overflow-y: auto; margin: 6px 0 0; padding: 0; list-style: none;
    }
    #auth-page .ka-dd-list:first-child { margin-top: 0; }
    #auth-page .ka-dd-opt {
      display: flex; align-items: center; gap: 10px; padding: 8px 10px;
      border-radius: 10px; font-size: 13px; color: #253049; cursor: pointer;
    }
    #auth-page .ka-dd-opt:hover,
    #auth-page .ka-dd-opt.act { background: #f0ecfc; }
    #auth-page .ka-dd-opt.sel { color: #4d40b8; font-weight: 700; }
    #auth-page .ka-dd-opt.sel .ka-dd-av { background: #7462cb; color: #fff; }
    #auth-page .ka-dd-name {
      flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
    }
    #auth-page .ka-dd-check { flex: none; color: #6354d9; }
    #auth-page .ka-dd-empty { padding: 18px 10px; text-align: center; font-size: 12px; color: #8a93a8; }

    @keyframes ka-dd-pulse { 50% { opacity: .45; } }
    @media (prefers-reduced-motion: reduce) {
      #auth-page .ka-dd-btn, #auth-page .ka-dd-panel, #auth-page .ka-dd-chev { transition: none; }
      #auth-page .ka-dd-btn[disabled] .ka-dd-ph { animation: none; }
    }
  `;
  document.head.appendChild(style);
}

function umkmNameFieldHTML() {
  if (selectedRole === 'employee') {
    return `
      <div class="form-group" id="regNameGroup">
        <label class="field-label" for="regInvitationCode">Kode Undangan dari Owner</label>
        <div class="field-wrap">
          <input
            type="text"
            id="regInvitationCode"
            placeholder="Masukkan kode undangan"
            autocomplete="off"
            autocapitalize="characters"
            maxlength="32"
            value="${authEscape(_regTemp.invitation_code || '')}"
            required>
        </div>
        <div class="field-hint">
          Minta kode undangan kepada Owner UMKM Anda. Kode ini menghubungkan akun Anda ke UMKM yang benar.
        </div>
      </div>
    `;
  }

  return `
    <div class="form-group" id="regNameGroup">
      <label class="field-label" for="regName">Nama UMKM</label>
      <div class="field-wrap">
        <input
          type="text"
          id="regName"
          placeholder="Contoh: Kedai Kopi Koyo"
          autocomplete="organization"
          maxlength="180"
          value="${authEscape(_regTemp.name || '')}"
          required>
      </div>
    </div>
  `;
}

function umkmDDSetSelected(name) {
  const input = document.getElementById('regName');
  const button = document.getElementById('regDDBtn');
  if (!input || !button) return;

  input.value = name || '';
  _regTemp.name = name || '';

  button.innerHTML = name
    ? `<span class="ka-dd-av">${authEscape(umkmInitial(name))}</span>
       <span class="ka-dd-label">${authEscape(name)}</span>${UMKM_CHEVRON}`
    : `<span class="ka-dd-label ka-dd-ph">Pilih UMKM</span>${UMKM_CHEVRON}`;
}

function umkmDDRenderList() {
  const list = document.getElementById('regDDList');
  if (!list) return;

  if (!UMKM_DD.filtered.length) {
    list.innerHTML = '<li class="ka-dd-empty" role="presentation">UMKM tidak ditemukan</li>';
    return;
  }

  const selected = authValue('regName').trim().toLowerCase();

  list.innerHTML = UMKM_DD.filtered.map((name, index) => {
    const on = name.trim().toLowerCase() === selected;

    return `
      <li class="ka-dd-opt${on ? ' sel' : ''}${index === UMKM_DD.active ? ' act' : ''}"
          role="option" id="regDDOpt${index}" data-i="${index}"
          aria-selected="${on}">
        <span class="ka-dd-av">${authEscape(umkmInitial(name))}</span>
        <span class="ka-dd-name">${authEscape(name)}</span>
        ${on ? UMKM_CHECK : ''}
      </li>
    `;
  }).join('');
}

function umkmDDMoveActive(step) {
  const total = UMKM_DD.filtered.length;
  if (!total) return;

  UMKM_DD.active = (UMKM_DD.active + step + total) % total;

  document.querySelectorAll('#regDDList .ka-dd-opt').forEach(item => {
    item.classList.toggle('act', Number(item.dataset.i) === UMKM_DD.active);
  });

  const active = document.getElementById('regDDOpt' + UMKM_DD.active);
  active?.scrollIntoView({ block: 'nearest' });

  document.getElementById('regDDSearch')
    ?.setAttribute('aria-activedescendant', 'regDDOpt' + UMKM_DD.active);
}

function umkmDDOpen() {
  const dd = document.getElementById('regDD');
  const button = document.getElementById('regDDBtn');
  const search = document.getElementById('regDDSearch');
  if (!dd || !button || button.disabled || !_umkmOptions) return;

  UMKM_DD.filtered = _umkmOptions.slice();

  const selected = authValue('regName').trim().toLowerCase();
  const at = UMKM_DD.filtered.findIndex(n => n.trim().toLowerCase() === selected);
  UMKM_DD.active = at >= 0 ? at : 0;

  if (search) search.value = '';
  umkmDDRenderList();

  dd.classList.add('open');
  button.setAttribute('aria-expanded', 'true');

  document.getElementById('regDDOpt' + UMKM_DD.active)?.scrollIntoView({ block: 'nearest' });

  const searchable = !document.getElementById('regDDSearchWrap')?.classList.contains('hide');
  if (searchable && search) setTimeout(() => search.focus(), 0);
}

function umkmDDClose(returnFocus) {
  const dd = document.getElementById('regDD');
  const button = document.getElementById('regDDBtn');
  if (!dd || !dd.classList.contains('open')) return;

  dd.classList.remove('open');
  button?.setAttribute('aria-expanded', 'false');

  if (returnFocus) button?.focus();
}

function umkmDDChoose(name) {
  umkmDDSetSelected(name);
  umkmDDClose(true);
}

function umkmDDBind() {
  const dd = document.getElementById('regDD');
  if (!dd || dd.dataset.bound) return;
  dd.dataset.bound = '1';

  dd.querySelector('#regDDBtn').addEventListener('click', () => {
    dd.classList.contains('open') ? umkmDDClose(false) : umkmDDOpen();
  });

  const list = dd.querySelector('#regDDList');

  // mousedown dicegah agar kolom pencarian tidak kehilangan fokus sebelum klik terbaca
  list.addEventListener('mousedown', event => event.preventDefault());
  list.addEventListener('click', event => {
    const item = event.target.closest('.ka-dd-opt');
    if (item) umkmDDChoose(UMKM_DD.filtered[Number(item.dataset.i)]);
  });

  dd.querySelector('#regDDSearch').addEventListener('input', event => {
    const term = event.target.value.trim().toLowerCase();

    UMKM_DD.filtered = _umkmOptions.filter(n => n.toLowerCase().includes(term));
    UMKM_DD.active = UMKM_DD.filtered.length ? 0 : -1;
    umkmDDRenderList();
  });

  dd.addEventListener('keydown', event => {
    const open = dd.classList.contains('open');

    if (event.key === 'Escape' && open) {
      event.preventDefault();
      umkmDDClose(true);
    } else if (event.key === 'Tab' && open) {
      umkmDDClose(false);
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      open ? umkmDDMoveActive(event.key === 'ArrowDown' ? 1 : -1) : umkmDDOpen();
    } else if (event.key === 'Enter' && open) {
      // Cegah submit form; Enter memilih item yang disorot.
      event.preventDefault();
      if (UMKM_DD.active >= 0) umkmDDChoose(UMKM_DD.filtered[UMKM_DD.active]);
    }
  });

  if (!UMKM_DD.outsideBound) {
    UMKM_DD.outsideBound = true;

    document.addEventListener('click', event => {
      const current = document.getElementById('regDD');
      if (current && !current.contains(event.target)) umkmDDClose(false);
    });
  }
}

async function populateUmkmSelect() {
  umkmDDStyles();

  const button = document.getElementById('regDDBtn');
  if (!button) return;

  try {
    if (!_umkmOptions) {
      if (typeof AuthAPI === 'undefined' || typeof AuthAPI.umkmOptions !== 'function') {
        throw new Error('AuthAPI.umkmOptions belum ada di js/api.js');
      }

      const result = await AuthAPI.umkmOptions();
      if (!result?.ok) throw new Error(result?.message || 'Gagal memuat daftar UMKM.');

      _umkmOptions = (result.data || [])
        .map(row => row.umkm_name)
        .filter(Boolean);
    }
  } catch (error) {
    const failed = document.getElementById('regDDBtn');
    if (failed) {
      failed.innerHTML =
        `<span class="ka-dd-label ka-dd-ph">Daftar UMKM gagal dimuat</span>${UMKM_CHEVRON}`;
    }
    authNotify('Daftar UMKM tidak dapat dimuat. Coba muat ulang halaman.');
    return;
  }

  // Pengguna mungkin sudah berpindah peran selagi menunggu respons.
  const current = document.getElementById('regDDBtn');
  if (!current) return;

  if (_umkmOptions.length === 0) {
    current.innerHTML =
      `<span class="ka-dd-label ka-dd-ph">Belum ada UMKM terdaftar</span>${UMKM_CHEVRON}`;
    return;
  }

  // Kolom pencarian hanya berguna kalau daftarnya cukup panjang.
  document.getElementById('regDDSearchWrap')
    ?.classList.toggle('hide', _umkmOptions.length <= 5);

  const wanted = String(_regTemp.name || '').trim().toLowerCase();
  const match = _umkmOptions.find(n => n.trim().toLowerCase() === wanted);

  current.disabled = false;
  umkmDDSetSelected(match || '');
  umkmDDBind();
}

// ============================================================
// DROPDOWN KUSTOM — PROVINSI & SEKTOR USAHA (Register Langkah 2)
// ============================================================
// <select> asli tetap ada (disembunyikan) dan nilainya selalu
// disinkronkan, jadi handleRegisterStep2(), backToRegisterStep1()
// dan renderAuthView() tetap membaca/mengisi nilainya seperti biasa.
// Memakai kelas .ka-dd-* yang sama dengan dropdown UMKM pegawai.

let _selDDOutsideBound = false;

function selDDEnhance(selectId, options = {}) {
  const select = document.getElementById(selectId);
  if (!select || select.dataset.ddReady) return;
  select.dataset.ddReady = '1';

  umkmDDStyles();

  const searchable = Boolean(options.searchable);
  const items = Array.from(select.options)
    .filter(option => option.value !== '')
    .map(option => ({ value: option.value, label: option.textContent.trim() }));
  const placeholder = select.options[0]?.textContent.trim() || 'Pilih';

  let filtered = items.slice();
  let active = -1;

  // "required" dilepas agar browser tidak memblokir submit pada kolom
  // tersembunyi; validasi tetap dilakukan oleh handleRegisterStep2().
  select.required = false;
  select.tabIndex = -1;

  const host = select.closest('.field-wrap') || select;
  host.style.display = 'none';

  const buttonId = selectId + 'DDBtn';
  const dd = document.createElement('div');
  dd.className = 'ka-dd ka-sel';

  dd.innerHTML = `
    <button type="button" class="ka-dd-btn" id="${buttonId}"
            aria-haspopup="listbox" aria-expanded="false"></button>
    <div class="ka-dd-panel">
      ${searchable ? `
        <div class="ka-dd-search">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
               stroke="currentColor" stroke-width="2" stroke-linecap="round"
               aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg>
          <input type="text" autocomplete="off"
                 placeholder="${authEscape(options.searchPlaceholder || 'Cari')}"
                 aria-label="${authEscape(options.searchPlaceholder || 'Cari')}">
        </div>` : ''}
      <ul class="ka-dd-list" role="listbox"></ul>
    </div>
  `;

  host.after(dd);

  // Label "for" diarahkan ke tombol baru agar klik label tetap berfungsi.
  const label = document.querySelector(`label[for="${selectId}"]`);
  if (label) label.htmlFor = buttonId;

  const button = dd.querySelector('.ka-dd-btn');
  const list = dd.querySelector('.ka-dd-list');
  const search = dd.querySelector('.ka-dd-search input');

  function paintButton() {
    const current = items.find(item => item.value === select.value);

    button.innerHTML = current
      ? `<span class="ka-dd-label">${authEscape(current.label)}</span>${UMKM_CHEVRON}`
      : `<span class="ka-dd-label ka-dd-ph">${authEscape(placeholder)}</span>${UMKM_CHEVRON}`;
  }

  function paintList() {
    if (!filtered.length) {
      list.innerHTML = '<li class="ka-dd-empty" role="presentation">Tidak ditemukan</li>';
      return;
    }

    list.innerHTML = filtered.map((item, index) => {
      const on = item.value === select.value;

      return `
        <li class="ka-dd-opt${on ? ' sel' : ''}${index === active ? ' act' : ''}"
            role="option" data-i="${index}" aria-selected="${on}">
          <span class="ka-dd-name">${authEscape(item.label)}</span>
          ${on ? UMKM_CHECK : ''}
        </li>
      `;
    }).join('');
  }

  function moveActive(step) {
    if (!filtered.length) return;

    active = (active + step + filtered.length) % filtered.length;

    list.querySelectorAll('.ka-dd-opt').forEach(el => {
      el.classList.toggle('act', Number(el.dataset.i) === active);
    });

    list.querySelector('.ka-dd-opt.act')?.scrollIntoView({ block: 'nearest' });
  }

  function open() {
    filtered = items.slice();

    const at = filtered.findIndex(item => item.value === select.value);
    active = at >= 0 ? at : 0;

    if (search) search.value = '';
    paintList();

    dd.classList.add('open');
    button.setAttribute('aria-expanded', 'true');

    list.querySelector('.ka-dd-opt.act')?.scrollIntoView({ block: 'nearest' });
    if (search) setTimeout(() => search.focus(), 0);
  }

  function close(returnFocus) {
    if (!dd.classList.contains('open')) return;

    dd.classList.remove('open');
    button.setAttribute('aria-expanded', 'false');

    if (returnFocus) button.focus();
  }

  function choose(item) {
    select.value = item.value;
    select.dispatchEvent(new Event('change', { bubbles: true }));

    paintButton();
    close(true);
  }

  dd._close = () => close(false);

  button.addEventListener('click', () => {
    dd.classList.contains('open') ? close(false) : open();
  });

  // Cegah kolom pencarian kehilangan fokus sebelum klik terbaca.
  list.addEventListener('mousedown', event => event.preventDefault());
  list.addEventListener('click', event => {
    const el = event.target.closest('.ka-dd-opt');
    if (el) choose(filtered[Number(el.dataset.i)]);
  });

  search?.addEventListener('input', event => {
    const term = event.target.value.trim().toLowerCase();

    filtered = items.filter(item => item.label.toLowerCase().includes(term));
    active = filtered.length ? 0 : -1;
    paintList();
  });

  dd.addEventListener('keydown', event => {
    const isOpen = dd.classList.contains('open');

    if (event.key === 'Escape' && isOpen) {
      event.preventDefault();
      close(true);
    } else if (event.key === 'Tab' && isOpen) {
      close(false);
    } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      isOpen ? moveActive(event.key === 'ArrowDown' ? 1 : -1) : open();
    } else if (event.key === 'Enter' && isOpen) {
      event.preventDefault();
      if (active >= 0) choose(filtered[active]);
    }
  });

  if (!_selDDOutsideBound) {
    _selDDOutsideBound = true;

    document.addEventListener('click', event => {
      document.querySelectorAll('.ka-sel.open').forEach(el => {
        if (!el.contains(event.target)) el._close?.();
      });
    });
  }

  paintButton();
}

// ============================================================
// REGISTER — TAHAP 1
// ============================================================

function regSubmitLabel() {
  return selectedRole === 'employee'
    ? 'Buat Akun VISTRA →'
    : 'Lanjut ke Profil Usaha →';
}

function renderRegisterForm() {
  umkmDDStyles();

  return `
    <div class="auth-form-wrap" data-role="${selectedRole}">
      ${authBackHTML()}

      <p style="
        margin:0 0 12px;
        color:var(--ka-blue, #6354d9);
        font-size:10px;
        font-weight:800;
        letter-spacing:1px;
      ">
        LANGKAH 1 DARI 2 · AKUN
      </p>

      <h1 class="auth-title">Mulai bersama VISTRA.</h1>
      <p class="auth-subtitle">
        Buat akun sesuai peran Anda untuk memulai evaluasi usaha.
      </p>

      <form onsubmit="event.preventDefault(); handleRegisterStep1();">
        ${roleCardsHTML()}

        ${umkmNameFieldHTML()}

        <div class="form-group">
          <label class="field-label" for="regEmail">Email Akun</label>
          <div class="field-wrap">
            <input
              type="email"
              id="regEmail"
              placeholder="nama@usaha.com"
              autocomplete="email"
              maxlength="180"
              value="${authEscape(_regTemp.email)}"
              required>
          </div>
        </div>

        <div class="form-group-half">
          <div>
            <label class="field-label" for="regPwd">Kata Sandi</label>
            <div class="field-wrap">
              <input
                type="password"
                id="regPwd"
                placeholder="Minimal 8 karakter"
                autocomplete="new-password"
                minlength="8"
                required>
            </div>
          </div>

          <div>
            <label class="field-label" for="regPwdConfirm">
              Ulangi Kata Sandi
            </label>
            <div class="field-wrap">
              <input
                type="password"
                id="regPwdConfirm"
                placeholder="Ketik sekali lagi"
                autocomplete="new-password"
                minlength="8"
                required>
            </div>
          </div>
        </div>

        <div class="checkbox-wrap">
          <input type="checkbox" id="regAgree" required>
          <label class="checkbox-label" for="regAgree">
            Saya memastikan informasi yang saya isi benar
            dan ingin membuat akun VISTRA.
          </label>
        </div>

        <button type="submit" class="btn-auth" id="btnReg1">
          ${regSubmitLabel()}
        </button>
      </form>

      <p class="auth-link-text">
        Sudah memiliki akun?
        <a href="#"
           onclick="event.preventDefault(); showView('login');">
          Masuk di sini
        </a>
      </p>
    </div>
  `;
}

function handleRegisterStep1() {
  if (authBusy) return;

  const email = authValue('regEmail').trim();
  const password = authValue('regPwd');
  const confirmation = authValue('regPwdConfirm');
  const agree = document.getElementById('regAgree')?.checked;

  if (!authEmailValid(email)) {
    authNotify('Masukkan alamat email yang valid.');
    return;
  }
  if (password.length < 8) {
    authNotify('Kata sandi minimal 8 karakter.');
    return;
  }
  if (password !== confirmation) {
    authNotify('Konfirmasi kata sandi belum sama.');
    return;
  }
  if (!agree) {
    authNotify('Centang konfirmasi untuk melanjutkan.');
    return;
  }

  if (selectedRole === 'employee') {
    const invitationCode = authValue('regInvitationCode').trim().toUpperCase();
    if (!invitationCode) {
      authNotify('Kode undangan dari Owner wajib diisi.');
      return;
    }
    submitRegistration({
      invitation_code: invitationCode,
      email,
      password,
      role: 'employee'
    }, 'btnReg1', regSubmitLabel());
    return;
  }

  const name = authValue('regName').trim();
  if (!name) {
    authNotify('Nama UMKM wajib diisi.');
    return;
  }

  _regTemp = {
    ..._regTemp,
    name,
    email,
    pwd: password,
    pwdConfirm: confirmation,
    role: 'owner',
    agree
  };
  showView('register2');
}

// ============================================================
// REGISTER — TAHAP 2
// ============================================================

function renderRegisterForm2() {
  const provinces = [
    'Aceh',
    'Sumatera Utara',
    'Sumatera Barat',
    'Riau',
    'Kepulauan Riau',
    'Jambi',
    'Sumatera Selatan',
    'Kepulauan Bangka Belitung',
    'Bengkulu',
    'Lampung',
    'DKI Jakarta',
    'Banten',
    'Jawa Barat',
    'Jawa Tengah',
    'DI Yogyakarta',
    'Jawa Timur',
    'Bali',
    'Nusa Tenggara Barat',
    'Nusa Tenggara Timur',
    'Kalimantan Barat',
    'Kalimantan Tengah',
    'Kalimantan Selatan',
    'Kalimantan Timur',
    'Kalimantan Utara',
    'Sulawesi Utara',
    'Gorontalo',
    'Sulawesi Tengah',
    'Sulawesi Barat',
    'Sulawesi Selatan',
    'Sulawesi Tenggara',
    'Maluku',
    'Maluku Utara',
    'Papua',
    'Papua Barat',
    'Papua Selatan',
    'Papua Tengah',
    'Papua Pegunungan',
    'Papua Barat Daya'
  ];

  return `
    <div class="auth-form-wrap">
      ${authBackHTML()}

      <p style="
        margin:0 0 12px;
        color:var(--ka-blue, #6354d9);
        font-size:10px;
        font-weight:800;
        letter-spacing:1px;
      ">
        LANGKAH 2 DARI 2 · PROFIL USAHA
      </p>

      <h1 class="auth-title">Kenalkan usaha Anda.</h1>
      <p class="auth-subtitle">
        Lengkapi profil usaha untuk menyelesaikan pendaftaran.
      </p>

      <form onsubmit="event.preventDefault(); handleRegisterStep2();">
        <div class="form-group">
          <label class="field-label" for="reg2Name">Nama UMKM</label>
          <div class="field-wrap">
            <input
              type="text"
              id="reg2Name"
              placeholder="Nama usaha Anda"
              autocomplete="organization"
              maxlength="150"
              value="${authEscape(_regTemp.name)}"
              ${(_regTemp.role || selectedRole) === 'employee' ? 'readonly' : ''}
              required>
          </div>
          ${(_regTemp.role || selectedRole) === 'employee' ? `
            <div class="field-hint">
              Nama UMKM mengikuti pilihan Anda di langkah sebelumnya.
            </div>` : ''}
        </div>

        <div class="form-group-half">
          <div>
            <label class="field-label" for="reg2Lokasi">Provinsi</label>
            <div class="field-wrap">
              <select id="reg2Lokasi" required>
                <option value="">Pilih provinsi</option>
                ${provinces.map(province => `
                  <option value="${authEscape(province)}">
                    ${authEscape(province)}
                  </option>
                `).join('')}
              </select>
            </div>
          </div>

          <div>
            <label class="field-label" for="reg2Sektor">
              Sektor Usaha
            </label>
            <div class="field-wrap">
              <select id="reg2Sektor" required>
                <option value="">Pilih sektor</option>
                <option value="Makanan &amp; Minuman">
                  Makanan &amp; Minuman
                </option>
                <option value="Fashion">Fashion</option>
                <option value="Grosir &amp; Retail">
                  Grosir &amp; Retail
                </option>
              </select>
            </div>
          </div>
        </div>

        <div class="form-group">
          <label class="field-label" for="reg2Omzet">
            Omzet per Bulan
          </label>
          <div class="field-number-wrap">
            <span class="field-prefix">Rp</span>
            <input
              type="number"
              id="reg2Omzet"
              placeholder="Contoh: 5000000"
              min="0"
              max="9007199254740991"
              step="1"
              inputmode="numeric">
          </div>
          <div class="field-hint">
            Opsional. Isi estimasi rata-rata omzet bulanan,
            tanpa titik atau koma.
          </div>
        </div>

        <button type="submit" class="btn-auth" id="btnReg2">
          Buat Akun VISTRA →
        </button>
      </form>

      <p class="auth-link-text">
        <a href="#"
           onclick="event.preventDefault(); backToRegisterStep1();">
          ← Kembali ke Data Akun
        </a>
      </p>
    </div>
  `;
}

function backToRegisterStep1() {
  if (authBusy) return;

  _regTemp.name = authValue('reg2Name').trim();
  _regTemp.lokasi = authValue('reg2Lokasi');
  _regTemp.sektor = authValue('reg2Sektor');
  _regTemp.omzet = authValue('reg2Omzet');

  showView('register');
}

async function handleRegisterStep2() {
  if (authBusy) return;

  if (!_regTemp.email || !_regTemp.pwd) {
    authNotify('Lengkapi data akun terlebih dahulu.');
    showView('register');
    return;
  }

  const name = authValue('reg2Name').trim();
  const lokasi = authValue('reg2Lokasi');
  const sektor = authValue('reg2Sektor');
  const omzetText = authValue('reg2Omzet').trim();
  const omzet = omzetText === '' ? null : Number(omzetText);

  if (!name) {
    authNotify('Nama UMKM wajib diisi.');
    return;
  }

  if (!lokasi) {
    authNotify('Pilih provinsi usaha Anda.');
    return;
  }

  if (!sektor) {
    authNotify('Pilih sektor usaha Anda.');
    return;
  }

  if (
    omzet !== null &&
    (!Number.isSafeInteger(omzet) || omzet < 0)
  ) {
    authNotify('Omzet harus berupa angka bulat nol atau lebih.');
    return;
  }

  const payload = {
    umkm_name: name,
    email: _regTemp.email,
    password: _regTemp.pwd,
    role: _regTemp.role || selectedRole,
    lokasi,
    sektor,
    omzet
  };

  await submitRegistration(payload, 'btnReg2', 'Buat Akun VISTRA →');
}

// Dipakai bersama oleh Owner (setelah langkah 2) dan Pegawai (langsung dari langkah 1).
async function submitRegistration(payload, buttonId, buttonText) {
  authBusy = true;
  setLoading(buttonId, true);

  let result;

  try {
    result = await AuthAPI.register(payload);
  } catch (error) {
    authNotify(
      'Tidak dapat terhubung ke server. Pastikan Apache dan MySQL aktif.'
    );
    return;
  } finally {
    authBusy = false;
    setLoading(buttonId, false, buttonText);
  }

  if (!result?.ok) {
    authNotify(result?.message || 'Pendaftaran belum berhasil.');
    return;
  }

  AppState.currentUser = authUserData(result.data, {
    umkm_name: payload.umkm_name,
    email: payload.email,
    role: payload.role,
    lokasi: payload.lokasi,
    sektor: payload.sektor,
    omzet: payload.omzet
  });

  _regTemp = {};

  if (result.data?.token) {
    authNotify('Akun VISTRA berhasil dibuat.', 'success');
    showView('dashboard');
  } else {
    authNotify('Akun berhasil dibuat. Silakan masuk.', 'success');
    showView('login');
  }
}

// ============================================================
// STARTUP — VALIDASI SESI SEBELUM MEMBUKA DASHBOARD
// ============================================================

document.addEventListener('DOMContentLoaded', async () => {
  if (typeof AuthAPI === 'undefined') {
    showView('landing');

    authNotify(
      'Komponen login belum termuat. Periksa file js/api.js.'
    );

    return;
  }

  let hasSession = authHasSession();

  // Token yang masih tersimpan di browser belum tentu masih valid.
  // Periksa ke backend melalui endpoint GET api.php?action=me.
  if (
    hasSession &&
    typeof DashboardAPI !== 'undefined' &&
    typeof DashboardAPI.getMe === 'function'
  ) {
    try {
      const sessionCheck = await DashboardAPI.getMe();

      // Backend requireAuth() mengembalikan HTTP 401 jika token
      // kosong, rusak, atau sudah kedaluwarsa.
      if (sessionCheck?.status === 401) {
        AuthAPI.logout();
        hasSession = false;
      }
    } catch (error) {
      // Jika server sedang tidak dapat dijangkau, jangan hapus token
      // yang mungkin masih valid. Dashboard tetap dapat dimuat.
    }
  }

  if (typeof AppState !== 'undefined') {
    AppState.currentUser = hasSession
      ? authUserData(AuthAPI.getUser())
      : null;
  }

  let view = savedView();

  if (view === 'register2') {
    view = 'register';
  }

  if (!['landing', 'login', 'register', 'dashboard'].includes(view)) {
    view = 'landing';
  }

  // Dashboard hanya boleh dibuka jika token dan profil lokal tersedia
  // serta token telah lolos pemeriksaan backend.
  if (view === 'dashboard' && !hasSession) {
    view = 'login';
  }

  showView(view);
});