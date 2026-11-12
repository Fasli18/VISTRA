// ============================================================
// KOYOUMKM — POPUP HASIL SETELAH SUBMIT FORM (desain ulang)
// Lokasi: koyoumkm/js/feedback-popup.js
// Dimuat SETELAH form.js. File ini menggantikan showFeedbackPopup()
// milik form.js tanpa mengubah form.js itu sendiri.
// Tidak bergantung pada CSS variable dashboard (popup ada di luar #dashboard-app).
// ============================================================
(function () {
  'use strict';

  // Nama faktor — ubah di sini kalau ingin mengganti label
  var LABELS = { INS: 'Sumber Daya', OPS: 'Inovasi', ECT: 'Eksternal', OV: 'Budaya', LDI: 'Kepemimpinan', WEQ: 'Proses' };
  var COLORS = { INS: '#e5484d', OPS: '#e08a2c', ECT: '#0e9bb5', OV: '#7c5ce6', LDI: '#149b83', WEQ: '#285de5' };

  function esc(v) {
    return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function num(v) { var n = parseFloat(v); return isFinite(n) ? n : null; }
  function fmt(n) { return n === null ? '--' : n.toFixed(2); }

  function tone(category) {
    var c = String(category || '').toUpperCase();
    if (c === 'SANGAT BAIK' || c === 'BAIK') return { cls: 'good', color: '#149b83' };
    if (c === 'CUKUP')                         return { cls: 'mid',  color: '#e08a2c' };
    return { cls: 'bad', color: '#e5484d' };
  }

  function closePopup() {
    var el = document.getElementById('feedbackPopup');
    if (el) el.remove();
    document.body.style.overflow = '';
    document.removeEventListener('keydown', onKey);
  }
  function onKey(e) { if (e.key === 'Escape') closePopup(); }

  window.showFeedbackPopup = function (data, elapsed) {
    data = data || {};
    closePopup();

    var role      = (typeof getCurrentRole === 'function') ? getCurrentRole() : 'owner';
    var isEmp     = role === 'employee';
    var composite = data.composite || {};
    var scores    = data.scores || {};
    var duration  = (typeof formatDuration === 'function') ? formatDuration(elapsed) : '--';
    var t         = tone(composite.category);
    var total     = num(composite.scoreOn5);

    // ── Faktor ──────────────────────────────────────────────
    var items = Object.keys(scores).map(function (k) {
      var s   = scores[k] || {};
      var val = num(s.scoreOn5);
      var pct = val !== null ? val / 5 * 100 : (num(s.normScore) !== null ? num(s.normScore) * 100 : 0);
      return { key: k, label: LABELS[k] || k, val: val, pct: Math.max(0, Math.min(100, pct)), color: COLORS[k] || '#6354d9' };
    });

    var factorsHtml = items.map(function (f, i) {
      return '<div class="kf-factor" style="--c:' + f.color + ';--d:' + (0.25 + i * 0.07).toFixed(2) + 's">' +
        '<div class="kf-factor-top"><span class="kf-factor-name"><i></i>' + esc(f.label) + '</span>' +
        '<b>' + fmt(f.val) + '<small> / 5</small></b></div>' +
        '<div class="kf-bar"><span data-w="' + f.pct.toFixed(1) + '"></span></div></div>';
    }).join('');

    // ── Terkuat / terendah ──────────────────────────────────
    var withVal = items.filter(function (f) { return f.val !== null; });
    var insightHtml = '';
    if (withVal.length >= 2) {
      var hi = withVal.reduce(function (a, b) { return b.val > a.val ? b : a; });
      var lo = withVal.reduce(function (a, b) { return b.val < a.val ? b : a; });
      if (hi.val !== lo.val) {
        insightHtml =
          '<div class="kf-insights">' +
            '<span class="kf-chip kf-chip-up">▲ Terkuat: <b>' + esc(hi.label) + '</b> ' + fmt(hi.val) + '</span>' +
            '<span class="kf-chip kf-chip-down">▼ Terendah: <b>' + esc(lo.label) + '</b> ' + fmt(lo.val) + '</span>' +
          '</div>';
      }
    }

    // ── Gauge ───────────────────────────────────────────────
    var R = 52, C = 2 * Math.PI * R;
    var gaugeOffset = C * (1 - (total !== null ? Math.max(0, Math.min(1, total / 5)) : 0));

    var warn = (data.warnings && data.warnings.length && data.warnings[0] && data.warnings[0].message)
      ? '<div class="kf-warn"><span>⚠</span><div><b>Catatan</b>' + esc(data.warnings[0].message) + '</div></div>' : '';

    var popup = document.createElement('div');
    popup.id = 'feedbackPopup';
    popup.className = 'kf-overlay';
    popup.setAttribute('role', 'dialog');
    popup.setAttribute('aria-modal', 'true');
    popup.setAttribute('aria-labelledby', 'kfTitle');
    popup.innerHTML =
      '<div class="kf-card">' +
        '<button type="button" class="kf-x" aria-label="Tutup" data-kf-close>&times;</button>' +
        '<div class="kf-hero">' +
          '<div class="kf-check"><svg viewBox="0 0 52 52" width="34" height="34" fill="none" stroke="currentColor" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 27l8 8 16-17"/></svg></div>' +
          '<h2 id="kfTitle">Evaluasi Berhasil Disimpan</h2>' +
          '<p>Skor kesehatan usaha Anda sudah diperbarui dan tersedia di dashboard.</p>' +
        '</div>' +
        '<div class="kf-body">' +
          '<div class="kf-summary">' +
            '<div class="kf-gauge" style="--tone:' + t.color + '">' +
              '<svg viewBox="0 0 120 120" width="132" height="132">' +
                '<circle cx="60" cy="60" r="' + R + '" class="kf-ring-bg"/>' +
                '<circle cx="60" cy="60" r="' + R + '" class="kf-ring" stroke-dasharray="' + C.toFixed(1) + '" stroke-dashoffset="' + C.toFixed(1) + '" data-offset="' + gaugeOffset.toFixed(1) + '"/>' +
              '</svg>' +
              '<div class="kf-gauge-text"><strong>' + fmt(total) + '</strong><span>dari 5.00</span></div>' +
            '</div>' +
            '<div class="kf-meta">' +
              '<span class="kf-pill kf-pill-' + t.cls + '">' + esc(composite.category || '--') + '</span>' +
              '<div class="kf-label">' + (isEmp ? 'Skor komposit UMKM' : 'Skor sementara (3 dari 6 faktor)') + '</div>' +
              '<div class="kf-row"><span>Waktu pengerjaan</span><b>' + esc(duration) + '</b></div>' +
              '<div class="kf-row"><span>ID submission</span><b>#' + esc(data.submission_id || '--') + '</b></div>' +
            '</div>' +
          '</div>' +
          (isEmp ? '' : '<div class="kf-note">Skor ini baru mencakup faktor yang Anda isi sebagai owner. Budaya, Kepemimpinan, dan Proses akan melengkapinya setelah karyawan mengisi.</div>') +
          insightHtml +
          (factorsHtml ? '<div class="kf-section">Rincian per faktor</div><div class="kf-factors">' + factorsHtml + '</div>' : '') +
          warn +
        '</div>' +
        '<div class="kf-actions">' +
          '<button type="button" class="kf-btn kf-btn-primary" data-kf-dashboard>Lihat Dashboard</button>' +
          '<button type="button" class="kf-btn kf-btn-ghost" data-kf-close>Tutup</button>' +
        '</div>' +
      '</div>';

    document.body.appendChild(popup);
    document.body.style.overflow = 'hidden';

    popup.addEventListener('click', function (e) {
      if (e.target === popup || e.target.closest('[data-kf-close]')) { closePopup(); return; }
      if (e.target.closest('[data-kf-dashboard]')) { closePopup(); if (typeof navigate === 'function') navigate('home'); }
    });
    document.addEventListener('keydown', onKey);

    // Jalankan animasi bar & ring setelah elemen tampil
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        var ring = popup.querySelector('.kf-ring');
        if (ring) ring.style.strokeDashoffset = ring.getAttribute('data-offset');
        popup.querySelectorAll('.kf-bar span').forEach(function (b) { b.style.width = b.getAttribute('data-w') + '%'; });
      });
    });
    var primary = popup.querySelector('[data-kf-dashboard]');
    if (primary) primary.focus();
  };
})();