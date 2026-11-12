/* KoyoUMKM Personal Invitations: one email, one code, one use. */
(() => {
  'use strict';
  const esc = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function readUser() {
    try {
      if (typeof AuthAPI !== 'undefined' && typeof AuthAPI.getUser === 'function') {
        const u = AuthAPI.getUser(); if (u) return u;
      }
    } catch (_) {}
    try { return JSON.parse(localStorage.getItem('nexa_user') || 'null'); } catch (_) { return null; }
  }
  function call(action, method='GET', body=null) {
    if (typeof apiCall === 'function') return apiCall(action, method, body);
    if (typeof window.apiCall === 'function') return window.apiCall(action, method, body);
    throw new Error('Fungsi API tidak tersedia. Muat ulang halaman.');
  }
  function statusLabel(status) {
    return ({pending:'Menunggu',used:'Sudah digunakan',expired:'Kedaluwarsa',revoked:'Dicabut'})[status] || status;
  }
  function panelHTML() {
    return `
      <section id="koyo-invitation-panel" style="margin-top:22px;padding:24px;border:1px solid #e9e5f3;border-radius:20px;background:#fff;box-shadow:0 6px 25px #35305204;color:#282c49">
        <div style="display:flex;gap:12px;align-items:center;margin-bottom:8px">
          <div style="width:42px;height:42px;display:grid;place-items:center;border-radius:13px;background:#f1edfc;color:#806bc5;font-size:20px">✉</div>
          <div><h2 style="margin:0 0 4px;font-size:17px">Manajemen Undangan Pegawai</h2><p style="margin:0;color:#9292a8;font-size:12px">Buat undangan personal untuk satu pegawai.</p></div>
        </div>
        <p style="font-size:12px;line-height:1.7;color:#77788f;margin:14px 0">Setiap kode terikat pada satu alamat email dan hanya dapat digunakan satu kali. Pastikan email penerima benar.</p>
        <div style="display:grid;grid-template-columns:minmax(220px,2fr) minmax(130px,1fr);gap:12px">
          <label style="font-size:12px;color:#686981">Email pegawai
            <input id="koyoInviteEmail" type="email" maxlength="190" placeholder="pegawai@email.com" autocomplete="email" style="display:block;box-sizing:border-box;width:100%;margin-top:7px;padding:12px;border:1px solid #e5e2ef;border-radius:10px;background:#fff;color:#34334d">
          </label>
          <label style="font-size:12px;color:#686981">Masa berlaku
            <select id="koyoInviteDays" style="display:block;box-sizing:border-box;width:100%;margin-top:7px;padding:12px;border:1px solid #e5e2ef;border-radius:10px;background:#fff;color:#34334d"><option value="7">7 hari</option><option value="3">3 hari</option><option value="14">14 hari</option><option value="30">30 hari</option></select>
          </label>
        </div>
        <button id="koyoCreateInvite" type="button" style="margin-top:14px;padding:12px 18px;border:0;border-radius:10px;background:#6d59c8;color:#fff;font-weight:700;cursor:pointer">Buat Undangan</button>
        <div id="koyoInviteResult" aria-live="polite" style="margin-top:14px"></div>
        <div style="margin-top:24px;border-top:1px solid #eeeaf6;padding-top:18px">
          <div style="display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap"><h3 id="koyoInviteHistoryTitle" style="margin:0;font-size:15px">Riwayat Undangan</h3><button id="koyoRefreshInvites" type="button" style="padding:8px 12px;border:1px solid #e5e2ef;border-radius:9px;background:#fff;color:#5e50a0;cursor:pointer">Muat ulang</button></div>
          <div id="koyoInviteHistory" style="margin-top:12px;color:#85859a;font-size:12px">Memuat riwayat undangan...</div>
        </div>
      </section>`;
  }
  async function loadHistory(panel) {
    const host = panel.querySelector('#koyoInviteHistory');
    host.textContent = 'Memuat riwayat undangan...';
    try {
      const r = await call('my_invitations');
      if (!r?.ok) throw new Error(r?.message || 'Riwayat undangan gagal dimuat.');
      const rows = r.data || [];
      if (!rows.length) { host.textContent = 'Belum ada undangan yang dibuat.'; return; }
      host.innerHTML = `<p class="v-invite-scroll-hint" id="koyoInviteHistoryHint"><span aria-hidden="true">↔</span> Geser tabel ke samping bila diperlukan untuk melihat semua kolom dan aksi.</p><div class="v-invite-table-scroll" role="region" aria-labelledby="koyoInviteHistoryTitle" aria-describedby="koyoInviteHistoryHint" tabindex="0"><table class="v-invite-table" style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr style="text-align:left;color:#85859a"><th style="padding:10px 8px">Email pegawai</th><th style="padding:10px 8px">Status</th><th style="padding:10px 8px">Berlaku sampai</th><th style="padding:10px 8px">Aksi</th></tr></thead><tbody>${rows.map(row => {
        const canRevoke = row.invitation_status === 'pending';
        const expiry = row.expires_at ? new Date(String(row.expires_at).replace(' ','T')).toLocaleString('id-ID') : '-';
        return `<tr style="border-top:1px solid #f0edf6"><td style="padding:11px 8px;color:#393650">${esc(row.invited_email)}</td><td style="padding:11px 8px">${esc(statusLabel(row.invitation_status))}</td><td style="padding:11px 8px">${esc(expiry)}</td><td style="padding:11px 8px;white-space:nowrap"><div class="v-invite-actions"><button type="button" data-reveal="${Number(row.id)}" style="padding:6px 9px;border:1px solid #d8d1ef;border-radius:8px;background:#f8f6ff;color:#5e50a0;cursor:pointer;margin-right:5px">Lihat Kode</button>${canRevoke ? `<button type="button" data-revoke="${Number(row.id)}" style="padding:6px 9px;border:1px solid #f0cbd2;border-radius:8px;background:#fff7f8;color:#b34d62;cursor:pointer">Cabut</button>` : ''}</div></td></tr>`;
      }).join('')}</tbody></table></div>`;

      host.querySelectorAll('[data-reveal]').forEach(btn => btn.addEventListener('click', async () => {
        btn.disabled = true; const oldText = btn.textContent; btn.textContent = 'Mengambil...';
        try {
          const result = await call('reveal_invitation_code','POST',{invitation_id:Number(btn.dataset.reveal)});
          if (!result?.ok || !result?.data?.invitation_code) throw new Error(result?.message || 'Kode tidak bisa ditampilkan.');
          const code = String(result.data.invitation_code);
          const row = btn.closest('tr');
          let codeBox = row.nextElementSibling;
          if (!codeBox || !codeBox.dataset.invitationCodeRow) {
            codeBox = document.createElement('tr'); codeBox.dataset.invitationCodeRow = '1';
            codeBox.innerHTML = `<td colspan="4" style="padding:12px 8px;background:#f8f6ff;border-top:1px solid #e5def7"><div class="v-invite-code-content"><strong style="font-size:17px;letter-spacing:2px;color:#4f428e">${esc(code)}</strong><button type="button" data-copy-revealed style="margin-left:10px;padding:6px 9px;border:1px solid #d8d1ef;border-radius:8px;background:#fff;color:#5e50a0;cursor:pointer">Salin Kode</button></div></td>`;
            row.after(codeBox);
          } else {
            codeBox.querySelector('strong').textContent = code;
          }
          codeBox.querySelector('[data-copy-revealed]').onclick = async () => {
            try { await navigator.clipboard.writeText(code); codeBox.querySelector('[data-copy-revealed]').textContent='Tersalin'; }
            catch (_) { prompt('Salin kode undangan:', code); }
          };
          btn.textContent = 'Kode Ditampilkan';
        } catch (e) { alert(e.message || 'Gagal mengambil kode.'); btn.textContent = oldText; }
        finally { btn.disabled = false; }
      }));
      host.querySelectorAll('[data-revoke]').forEach(btn => btn.addEventListener('click', async () => {
        if (!confirm('Cabut undangan untuk email ini? Kode tidak akan bisa digunakan.')) return;
        btn.disabled = true;
        try {
          const result = await call('revoke_invitation','POST',{invitation_id:Number(btn.dataset.revoke)});
          if (!result?.ok) throw new Error(result?.message || 'Undangan gagal dicabut.');
          await loadHistory(panel);
        } catch (e) { alert(e.message || 'Gagal mencabut undangan.'); btn.disabled = false; }
      }));
    } catch (e) { host.textContent = e.message || 'Riwayat undangan gagal dimuat.'; }
  }
  function mount() {
    const user = readUser();
    const role = String(user?.role || '').toLowerCase();
    const host = document.getElementById('umkm-summary-content');
    if (!host || role !== 'owner' || host.querySelector('#koyo-invitation-panel')) return;
    host.insertAdjacentHTML('beforeend', panelHTML());
    const panel = host.querySelector('#koyo-invitation-panel');
    panel.querySelector('#koyoCreateInvite').addEventListener('click', async () => {
      const emailInput = panel.querySelector('#koyoInviteEmail');
      const email = emailInput.value.trim().toLowerCase();
      const resultHost = panel.querySelector('#koyoInviteResult');
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { resultHost.innerHTML = '<p style="color:#b34d62">Masukkan email pegawai yang valid.</p>'; emailInput.focus(); return; }
      const button = panel.querySelector('#koyoCreateInvite'); button.disabled = true; button.textContent = 'Membuat undangan...'; resultHost.innerHTML = '';
      try {
        const r = await call('create_invitation','POST',{invited_email:email,valid_days:Number(panel.querySelector('#koyoInviteDays').value)});
        if (!r?.ok || !r?.data?.invitation_code) throw new Error(r?.message || 'Undangan gagal dibuat.');
        const code = String(r.data.invitation_code);
        resultHost.innerHTML = `<div style="padding:16px;border:1px solid #dcd5f4;border-radius:12px;background:#f8f6ff"><div style="font-size:11px;color:#8276a5;margin-bottom:8px">KODE UNTUK ${esc(email).toUpperCase()}</div><div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap"><strong style="font-size:24px;letter-spacing:2px;color:#4f428e">${esc(code)}</strong><button id="koyoCopyInvite" type="button" style="padding:9px 12px;border:1px solid #d8d1ef;border-radius:9px;background:#fff;color:#5e50a0;font-weight:700;cursor:pointer">Salin Kode</button></div><p style="margin:10px 0 0;color:#77748d;font-size:11px">Berlaku ${Number(r.data.expires_in_days)} hari. Hanya dapat digunakan satu kali oleh email penerima.</p><p style="margin:6px 0 0;color:#a15d65;font-size:11px">Kode dapat dibuka kembali melalui Riwayat Undangan. Kode yang sudah digunakan, dicabut, atau kedaluwarsa tetap tidak dapat dipakai untuk registrasi.</p></div>`;
        panel.querySelector('#koyoCopyInvite').addEventListener('click', async () => { try { await navigator.clipboard.writeText(code); panel.querySelector('#koyoCopyInvite').textContent='Tersalin'; } catch (_) { prompt('Salin kode undangan:',code); } });
        emailInput.value = '';
        await loadHistory(panel);
      } catch (e) { resultHost.innerHTML = `<p style="margin:0;color:#b34d62;font-size:12px">${esc(e.message || e)}</p>`; }
      finally { button.disabled = false; button.textContent = 'Buat Undangan'; }
    });
    panel.querySelector('#koyoRefreshInvites').addEventListener('click', () => loadHistory(panel));
    loadHistory(panel);
  }
  function install() {
    if (typeof window.renderUmkmSummary === 'function' && !window.renderUmkmSummary.__koyoInvitationWrapped) {
      const original = window.renderUmkmSummary;
      const wrapped = function (...args) { const out = original.apply(this,args); setTimeout(mount,0); return out; };
      wrapped.__koyoInvitationWrapped = true;
      window.renderUmkmSummary = wrapped;
    }
    mount();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', install); else install();
  const observer = new MutationObserver(() => { if (document.getElementById('umkm-summary-content')) mount(); });
  observer.observe(document.documentElement,{childList:true,subtree:true});
  document.addEventListener('click', e => { if (e.target.closest('[data-page="umkmsummary"], [data-nav="umkmsummary"]')) setTimeout(install,100); });
})();