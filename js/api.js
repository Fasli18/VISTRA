/**
 * KoyoUMKM - Frontend API Client
 * Seluruh komunikasi frontend ke backend PHP.
 */
// Resolve from this script so both /VISTRA/ and domain-root installs work.
const API_BASE = new URL('../backend/api.php', document.currentScript.src).href;

const TokenStore = {
  get() { return localStorage.getItem('nexa_token'); },
  set(token) { localStorage.setItem('nexa_token', token); },
  clear() { localStorage.removeItem('nexa_token'); },
  getUser() {
    try { return JSON.parse(localStorage.getItem('nexa_user') || 'null'); }
    catch { return null; }
  },
  setUser(user) { localStorage.setItem('nexa_user', JSON.stringify(user)); },
  clearUser() { localStorage.removeItem('nexa_user'); },
  clearAll() { this.clear(); this.clearUser(); }
};

async function apiCall(action, method = 'GET', body = null) {
  const headers = { Accept: 'application/json' };
  const token = TokenStore.get();
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== null && method !== 'GET') headers['Content-Type'] = 'application/json';

  const url = `${API_BASE}?action=${action}`;
  const options = { method, headers, cache: 'no-store' };
  if (body !== null && method !== 'GET') options.body = JSON.stringify(body);

  try {
    const response = await fetch(url, options);
    let result;
    try {
      result = await response.json();
    } catch {
      return {
        ok: false,
        success: false,
        status: response.status,
        message: `Server mengembalikan respons yang bukan JSON. HTTP ${response.status}`,
        data: null
      };
    }

    const actionName = String(action).split('&')[0];
    const publicActions = ['login', 'register', 'umkm_options'];
    if (response.status === 401 && !publicActions.includes(actionName)) {
      TokenStore.clearAll();
      window.dispatchEvent(new Event('koyo:auth-expired'));
    }

    return { ...result, ok: response.ok && result.success === true, status: response.status };
  } catch (error) {
    console.error('[KoyoUMKM API Error]', error);
    return {
      ok: false,
      success: false,
      status: 0,
      message: 'Tidak dapat terhubung ke server. Periksa koneksi dan alamat backend.',
      data: null
    };
  }
}

const AuthAPI = {
  async register(payload) {
    const response = await apiCall('register', 'POST', payload);
    if (response.ok && response.data?.token) {
      TokenStore.set(response.data.token);
      TokenStore.setUser(response.data);
    }
    return response;
  },
  async login(payload) {
    const response = await apiCall('login', 'POST', payload);
    if (response.ok && response.data?.token) {
      TokenStore.set(response.data.token);
      TokenStore.setUser(response.data);
    }
    return response;
  },
  async umkmOptions() { return apiCall('umkm_options'); },
  logout() { TokenStore.clearAll(); },
  getUser() { return TokenStore.getUser(); },
  isLoggedIn() { return Boolean(TokenStore.get() && TokenStore.getUser()); }
};

const FormAPI = {
  async submit(answers) { return apiCall('submit', 'POST', answers); },
  async getStatus() { return apiCall('submission_status'); }
};

const DashboardAPI = {
  async getStats() { return apiCall('dashboard'); },
  async getUmkmList(opts = {}) {
    const limit = Number(opts.limit) || 15;
    const offset = Number(opts.offset) || 0;
    const search = opts.q || '';
    return apiCall('umkm_list&limit=' + encodeURIComponent(limit) +
      '&offset=' + encodeURIComponent(offset) + '&search=' + encodeURIComponent(search));
  },
  async getFactorAverages() { return apiCall('factor_averages'); },
  async getMe() { return apiCall('me'); },
  async getMyUmkm() { return apiCall('my_umkm'); },
  async setEmployeeStatus(userId, isActive) {
    return apiCall('set_employee_status', 'POST', {
      user_id: userId,
      is_active: isActive ? 1 : 0
    });
  },
  async getInvitations() { return apiCall('my_invitations'); },
  async createInvitation(email, validDays = 7) {
    return apiCall('create_invitation', 'POST', { invited_email: email, valid_days: validDays });
  },
  async revokeInvitation(invitationId) {
    return apiCall('revoke_invitation', 'POST', { invitation_id: invitationId });
  },
  async revealInvitation(invitationId) {
    return apiCall('reveal_invitation_code', 'POST', { invitation_id: invitationId });
  }
};
