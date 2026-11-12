/** VISTRA V3: presentation enhancements only. No session, API or score mutation. */
(() => {
  'use strict';
  const $ = selector => document.querySelector(selector);
  const rail = $('#sidebar');
  const main = $('#main');
  const auth = $('#auth-form-container');
  const form = $('#formMainContent');
  const reduced = matchMedia('(prefers-reduced-motion: reduce)');
  const titles = {home:'Overview',factor:'Factor Profile',distribution:'Distribution',comparison:'Benchmarking',umkmrec:'UMKM & Recommendations',umkmsummary:'Ringkasan UMKM',formdata:'Evaluasi Usaha',profile:'Profil Saya',help:'Help & Resources',notifications:'Notifikasi',admin:'Platform Overview'};
  const text = (tag, value, className) => {
    const el = document.createElement(tag);
    el.textContent = value;
    if (className) el.className = className;
    return el;
  };
  function syncRail() {
    const expanded = !rail.classList.contains('collapsed');
    $('.hamburger')?.setAttribute('aria-expanded', String(expanded));
    $('#sidebarOverlay')?.classList.toggle('show', expanded && innerWidth <= 900);
    // The closed mobile panel must not retain invisible keyboard targets.
    rail.inert = !expanded && innerWidth <= 900;
  }
  closeSidebar();
  syncRail();
  new MutationObserver(syncRail).observe(rail, {attributes:true, attributeFilter:['class']});
  let compactViewport = innerWidth <= 900;
  addEventListener('resize', () => {
    const next = innerWidth <= 900;
    if (next !== compactViewport) { closeSidebar(); compactViewport = next; }
    syncRail();
  }, {passive:true});
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !rail.classList.contains('collapsed') && innerWidth <= 900) {
      closeSidebar(); $('.hamburger')?.focus();
    }
  });
  document.addEventListener('click', event => {
    if (innerWidth <= 900 && event.target.closest('#sidebar .nav-item[data-page]')) closeSidebar();
  });
  function syncTitle() {
    const page = main.querySelector('.page.active');
    if (!page) return;
    const key = page.id.replace(/^page-/, '');
    const title = titles[key] || page.querySelector('h1')?.textContent || 'Workspace';
    const heading = $('#v3-workspace-title');
    if (heading.textContent !== title) heading.textContent = title;
  }
  new MutationObserver(() => { syncTitle(); syncHistory(); }).observe(main, {subtree:true,attributes:true,attributeFilter:['class'],childList:true});
  syncTitle();
  // The stepper reflects existing native registration steps. It never advances
  // a form or bypasses validation, and uses the unchanged auth renderer.
  function enhanceAuth() {
    const wrap = auth.querySelector('.auth-form-wrap');
    if (!wrap || !wrap.querySelector('#regEmail,#reg2Name')) return;
    wrap.querySelectorAll('[placeholder]').forEach(input => {
      if (input.placeholder.includes('Kedai Kopi Koyo')) input.placeholder='Contoh: Kedai Kopi Anda';
    });
    const business = Boolean(wrap.querySelector('#reg2Name'));
    const employee = wrap.dataset.role === 'employee';
    const signature = `${employee}:${business}`;
    const existing = wrap.querySelector('.v3-wizard');
    if (existing?.dataset.signature === signature) return;
    existing?.remove();
    const steps = employee ? ['Peran & akun', 'Undangan personal'] : ['Peran & akun', 'Identitas usaha'];
    const stepper = document.createElement('div');
    stepper.className = 'v3-wizard'; stepper.dataset.signature=signature; stepper.style.gridTemplateColumns = 'repeat(2,minmax(0,1fr))';
    stepper.setAttribute('aria-label', employee ? 'Pendaftaran Employee dalam satu formulir' : 'Tahap pendaftaran Owner');
    steps.forEach((label, index) => {
      const step = text('div', '', 'v3-wizard-step');
      step.append(text('b', String(index + 1).padStart(2,'0')), text('span', label));
      if (index === (business ? 1 : 0)) step.setAttribute('aria-current', 'step');
      stepper.append(step);
    });
    if (employee) {
      // Both Employee sections exist in the same form; use anchor buttons
      // rather than implying a separate submission step.
      [...stepper.children].forEach((step,index) => {
        const button = text('button', steps[index]); button.type = 'button';
        button.className = 'v3-wizard-jump';
        button.addEventListener('click', () => wrap.querySelector(index ? '#regInvitationCode' : '#regEmail')?.focus());
        step.replaceChildren(text('b',String(index+1).padStart(2,'0')),button);
        step.removeAttribute('aria-current');
      });
    }
    wrap.prepend(stepper);
  }
  new MutationObserver(enhanceAuth).observe(auth, {childList:true,subtree:true});
  enhanceAuth();
  // Navigate existing sections; count completed questions, never compute scores.
  let sectionsObserver;
  function enhanceQuestionnaire() {
    const sections = [...form.querySelectorAll('.form-section')];
    if (!sections.length || form.querySelector('.v3-question-tools')) return;
    // Align headings with the verified display dictionary, never question text,
    // answer values, factor keys or scoring definitions in form.js.
    sections.forEach(section => {
      const heading = section.querySelector('.section-title');
      const code = heading?.textContent.match(/\(([A-Z]+)\)/)?.[1];
      const factor = FACTOR_PROFILE_FACTORS.find(item => item.code === code);
      if (factor && heading) heading.textContent = `${factor.label} (${code}) — ${factor.definition.split(' — ')[1]}`;
    });
    FACTOR_PROFILE_FACTORS.forEach(factor => {
      const label = document.getElementById(`calc-${factor.code}`)?.previousElementSibling;
      if (label) label.textContent = `${factor.label} (${factor.code})`;
    });
    const subtitle = $('#formSubtitle');
    if (subtitle) subtitle.textContent = subtitle.textContent.replace('Operasional', FACTOR_PROFILE_FACTORS.find(factor => factor.code === 'OPS').label);
    sectionsObserver?.disconnect();
    const tools = document.createElement('div'); tools.className = 'v3-question-tools';
    const line = text('div','', 'v3-question-progress');
    const progress = text('span',''); progress.id='v3-question-count';
    const progressBar = document.createElement('div');progressBar.className='v3-question-track';
    progressBar.setAttribute('role','progressbar');progressBar.setAttribute('aria-label','Kelengkapan jawaban');progressBar.setAttribute('aria-valuemin','0');progressBar.setAttribute('aria-valuemax','100');
    const fill = document.createElement('i');progressBar.append(fill);
    line.append(text('span','QUESTIONNAIRE WORKSPACE','v3-kicker'),progress);
    const nav = document.createElement('nav');nav.className='v3-factor-nav';nav.setAttribute('aria-label','Navigasi faktor evaluasi');
    const buttons = sections.map((section,index) => {
      const title = section.querySelector('.section-title')?.textContent || `Faktor ${index+1}`;
      const button = text('button', title.split(' — ')[0]);button.type='button';
      button.addEventListener('click', () => {
        section.scrollIntoView({behavior:reduced.matches?'instant':'smooth',block:'start'});
        const heading = section.querySelector('.section-title');
        heading?.setAttribute('tabindex','-1');heading?.focus({preventScroll:true});
      });
      nav.append(button); return button;
    });
    tools.append(line,progressBar,nav);form.prepend(tools);
    const update = () => {
      const total = new Set([...form.querySelectorAll('input[type=radio]')].map(input=>input.name)).size;
      const count = new Set([...form.querySelectorAll('input[type=radio]:checked')].map(input=>input.name)).size;
      progress.textContent = `${count} / ${total} dijawab`;
      const percent = total ? Math.round(count/total*100) : 0;
      fill.style.width=`${percent}%`;
      progressBar.setAttribute('aria-valuenow',String(percent));
      progressBar.setAttribute('aria-valuetext',`${count} dari ${total} pertanyaan dijawab`);
    };
    form.addEventListener('change',update,{signal:resetQuestionListeners()});update();
    if ('IntersectionObserver' in window) {
      sectionsObserver = new IntersectionObserver(entries => {
        const entry=entries.filter(item=>item.isIntersecting).sort((a,b)=>b.intersectionRatio-a.intersectionRatio)[0];
        if (!entry) return;
        buttons.forEach((button,index)=>button.setAttribute('aria-current',String(sections[index]===entry.target)));
      },{rootMargin:'-180px 0px -45% 0px',threshold:[0,.15,.4]});
      sections.forEach(section=>sectionsObserver.observe(section));
    }
  }
  let questionListeners;
  function resetQuestionListeners(){questionListeners?.abort();questionListeners=new AbortController();return questionListeners.signal;}
  new MutationObserver(enhanceQuestionnaire).observe(form,{childList:true});
  enhanceQuestionnaire();
  // Preview/report history already loaded by the existing owner workspace.
  // No additional requests, no invented timeline entries.
  let lastHistory;
  function syncHistory(){
    const box=$('#v3-home-history');
    const report=typeof umkmSummaryReportData==='undefined'?null:umkmSummaryReportData;
    const currentUmkm=AppState.currentUser?.umkm_id;
    if(!report || !currentUmkm || String(report.umkm?.id)!==String(currentUmkm)){
      if(lastHistory){box.replaceChildren(text('p','Detail riwayat tersedia di Ringkasan UMKM.'));lastHistory=null;}
      return;
    }
    if(lastHistory===report)return;
    lastHistory=umkmSummaryReportData;
    const history=umkmSummaryReportData.history;
    if(!Array.isArray(history)||!history.length)return;
    box.replaceChildren(...history.slice(0,3).map(period=>{
      const row=text('div','', 'v3-history-row');row.append(text('span',period.name||'Periode evaluasi'),text('strong',period.score==null?'Belum tersedia':Number(period.score).toFixed(2)+' / 5'));return row;
    }));
  }
  new MutationObserver(syncHistory).observe($('#umkm-summary-content'),{childList:true});
  // Existing modal state is authoritative. Add focus entry, trap and restoration.
  let modalTrigger;
  document.querySelectorAll('.modal-backdrop').forEach(backdrop=>{
    let open=false;
    const focusables=()=>[...backdrop.querySelectorAll('button,input,select,textarea,a[href],[tabindex="0"]')].filter(el=>!el.disabled&&el.getClientRects().length);
    new MutationObserver(()=>{
      const next=backdrop.classList.contains('show');if(next===open)return;open=next;
      if(open){modalTrigger=document.activeElement;const modal=backdrop.querySelector('.modal');modal?.setAttribute('role','dialog');modal?.setAttribute('aria-modal','true');const heading=modal?.querySelector('h2,h3,.modal-title');if(heading)modal.setAttribute('aria-label',heading.textContent.trim());focusables()[0]?.focus();}
      else if(modalTrigger?.isConnected)modalTrigger.focus();
    }).observe(backdrop,{attributes:true,attributeFilter:['class']});
    backdrop.addEventListener('keydown',event=>{
      if(event.key==='Escape'){hideModal(backdrop.id);return;}
      if(event.key!=='Tab')return;const items=focusables();const first=items[0],last=items.at(-1);if(!first)return;
      if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}
      else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}
    });
  });
})();
