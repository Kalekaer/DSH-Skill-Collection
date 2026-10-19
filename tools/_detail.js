/* ============================================================================
   项目详情浮窗（三页共用）—— window.PD.open(project)
   project 字段（缺哪个就自动藏哪个区块）：
     id url tier score risk action stars d7 forks lic lang l1 l2
     one problem example aud what feats[] uses[] cases[] unfit[]
     note exp{stars,score,parts{易用性,文档完整度,功能成熟度,维护活跃,风险}}
     first last pushed created evc rec status drop
   ============================================================================ */
(function () {
  var HOST = null;
  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  }
  function has(x) { return x != null && String(x).trim() !== ''; }
  function list(a) { return Array.isArray(a) ? a.filter(has) : []; }
  function sec(title, body) { return body ? '<section class="pd-sec"><h4>' + title + '</h4>' + body + '</section>' : ''; }
  function pgh(t) { return '<p>' + esc(t) + '</p>'; }
  function ul(a) { return '<ul>' + list(a).map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('') + '</ul>'; }

  function ensure() {
    if (HOST && document.body.contains(HOST)) { return HOST; }
    HOST = document.createElement('div');
    HOST.className = 'pd-wrap';
    HOST.innerHTML = '<div class="pd-mask"></div><div class="pd-panel" role="dialog" aria-modal="true"></div>';
    document.body.appendChild(HOST);
    HOST.querySelector('.pd-mask').addEventListener('click', close);
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { close(); } });
    return HOST;
  }
  function close() {
    if (!HOST) { return; }
    HOST.classList.remove('on');
    document.documentElement.style.overflow = '';
  }

  function render(p) {
    var parts = (p.exp && p.exp.parts) || {};
    var rows = Object.keys(parts).map(function (k) {
      var v = Math.max(0, Math.min(20, Number(parts[k]) || 0));
      return '<div class="pd-bar"><span>' + esc(k) + '</span><i><b style="width:' + (v / 20 * 100) + '%"></b></i><span>' + v + '</span></div>';
    }).join('');
    var tier = has(p.tier) ? String(p.tier) : 'D';
    var TLAB = { S: 'S 档', A: 'A 档', B: 'B 档', C: 'C 档', D: 'D 档', dropped: 'D 档' };
    var tl = TLAB[tier] || (tier + ' 档');
    var badges = '<span class="pd-b tier ' + String(tier).toLowerCase() + '">' + esc(tl) + '</span>';
    if (has(p.score)) { badges += '<span class="pd-b">' + esc(p.score) + ' 分</span>'; }
    if (has(p.risk)) { badges += '<span class="pd-b risk">风险 ' + esc(p.risk) + '</span>'; }
    if (has(p.l1)) { badges += '<span class="pd-b ghost">' + esc(p.l1) + (has(p.l2) ? ' · ' + esc(p.l2) : '') + '</span>'; }
    if (p.rec) { badges += '<span class="pd-b ghost">推荐过</span>'; }
    if (p.org) { badges += '<span class="pd-b ghost">🏢 官方</span>'; }
    if (has(p.action)) { badges += '<span class="pd-b ghost">' + esc(p.action) + '</span>'; }

    /* 关键事实放最上面：星标 / 许可 / 语言 / 最近推送 —— 不用滚到底也知道分量 */
    var facts = [];
    if (has(p.stars)) { facts.push('★ ' + p.stars + (has(p.d7) && p.d7 !== 0 ? '（7 日 ' + (p.d7 > 0 ? '+' : '') + p.d7 + '）' : '')); }
    if (has(p.lic)) { facts.push(/^NOASSERTION$|^NOASSERTION$/i.test(p.lic) ? '许可未标注' : p.lic); }
    if (has(p.lang)) { facts.push(p.lang); }
    if (has(p.pushed)) { facts.push('最近推送 ' + p.pushed); }
    var factsHtml = facts.length ? '<div class="pd-facts">' + facts.map(function (x) { return '<span>' + esc(x) + '</span>'; }).join('') + '</div>' : '';

    var tagBits = '';
    var tgs = list(p.tags), kws = list(p.kw), syns = list(p.syn);
    if (tgs.length) { tagBits += '<div class="pd-tags"><b>标签</b>' + tgs.map(function (x, i) { return '<span class="pd-tag" style="--d:' + (i * 18) + 'ms">' + esc(x) + '</span>'; }).join('') + '</div>'; }
    if (kws.length) { tagBits += '<div class="pd-tags"><b>搜索词</b>' + kws.map(function (x, i) { return '<span class="pd-tag kw" style="--d:' + (i * 18 + 40) + 'ms">' + esc(x) + '</span>'; }).join('') + '</div>'; }
    if (syns.length) { tagBits += '<div class="pd-tags"><b>同义词</b>' + syns.map(function (x, i) { return '<span class="pd-tag kw" style="--d:' + (i * 18 + 80) + 'ms">' + esc(x) + '</span>'; }).join('') + '</div>'; }

    var meta = '';
    function m(label, val) { if (has(val)) { meta += '<div>' + label + '<b>' + esc(val) + '</b></div>'; } }
    if (has(p.stars)) { m('STARS', '★ ' + p.stars + (has(p.d7) && p.d7 !== 0 ? '（7 日 ' + (p.d7 > 0 ? '+' : '') + p.d7 + '）' : '')); }
    if (has(p.forks)) { m('FORKS', p.forks); }
    if (has(p.lic)) { m('许可', p.lic); }
    if (has(p.lang)) { m('语言', p.lang); }
    if (has(p.created)) { m('建于', p.created); }
    if (has(p.pushed)) { m('最近推送', p.pushed); }
    if (has(p.first)) { m('首次收录', p.first); }
    if (has(p.last)) { m('最近更新', p.last); }
    if (has(p.evc)) { m('成长记录', p.evc + ' 条'); }
    if (has(p.status)) { m('状态', p.status); }
    if (has(p.drop)) { m('退稿原因', p.drop); }

    var fit = (has(p.aud) || list(p.unfit).length)
      ? '<div class="pd-fit">' +
        '<div><b>适合谁</b><p>' + (has(p.aud) ? esc(p.aud) : '—') + '</p></div>' +
        '<div><b>不适合</b><p>' + (list(p.unfit).length ? list(p.unfit).map(esc).join('；') : '—') + '</p></div>' +
        '</div>' : '';

    var scoreBlock = (has(p.exp && p.exp.stars) || rows)
      ? '<div class="pd-score"><div class="num">' + (has(p.exp && p.exp.stars) ? esc(p.exp.stars) + '★' : '—') +
        '<small>体验评分' + (has(p.exp && p.exp.score) ? ' · ' + esc(p.exp.score) + '/100' : '') + '</small></div><div class="pd-bars">' + rows + '</div></div>'
      : '';

    var html =
      '<button class="pd-x" aria-label="关闭">×</button>' +
      '<div class="pd-badges">' + badges + '</div>' +
      '<h3 class="pd-id">' + esc(p.id || '—') + '</h3>' +
      factsHtml +
      tagBits +
      (has(p.one) ? '<p class="pd-one">' + esc(p.one) + '</p>' : '') +
      sec('它是什么', has(p.what) ? pgh(p.what) : '') +
      sec('解决什么问题', has(p.problem) ? pgh(p.problem) : '') +
      sec('怎么用 · 例子', has(p.example) ? pgh(p.example) : '') +
      sec('核心功能', list(p.feats).length ? ul(p.feats) : '') +
      sec('常见用途 / 使用案例', (list(p.uses).length || list(p.cases).length)
        ? (list(p.uses).length ? ul(p.uses) : '') + (list(p.cases).length ? ul(p.cases) : '') : '') +
      (fit ? '<section class="pd-sec"><h4>适合谁 / 门槛</h4>' + fit + '</section>' : '') +
      (scoreBlock ? '<section class="pd-sec"><h4>我的评价</h4>' + scoreBlock + '</section>' : '') +
      (meta ? '<section class="pd-sec"><h4>数据</h4><div class="pd-meta">' + meta + '</div></section>' : '') +
      (has(p.note) ? '<section class="pd-sec"><h4>备注</h4><p class="pd-note">' + esc(p.note) + '</p></section>' : '') +
      '<a class="pd-go" href="' + esc(p.url || ('https://github.com/' + (p.id || ''))) + '" target="_blank" rel="noopener">在 GitHub 打开 ↗</a>' +
      '<div class="pd-hint">ESC 关闭 · 点背景关闭</div>';

    var host = ensure();
    var panel = host.querySelector('.pd-panel');
    panel.innerHTML = html;
    panel.scrollTop = 0;
    panel.querySelector('.pd-x').addEventListener('click', close);
    host.classList.add('on');
    document.documentElement.style.overflow = 'hidden';
  }

  window.PD = {
    open: render,
    close: close,
    bind: function (el, get) {
      if (!el) { return; }
      el.addEventListener('click', function (e) { var p = get(e); if (p) { e.preventDefault(); render(p); } });
    }
  };

  function findCard(id) {
    var srcs = [];
    try { if (typeof DATA !== 'undefined' && DATA) { srcs = srcs.concat(DATA.picks || [], DATA.projects || [], DATA.related || [], DATA.official || []); } } catch (e) {}
    try { if (typeof D !== 'undefined' && D) { srcs = srcs.concat(D.picks || [], D.projects || [], D.related || [], D.official || []); } } catch (e) {}
    try { if (typeof PROJ !== 'undefined' && PROJ) { srcs = srcs.concat(PROJ); } } catch (e) {}
    try { if (window.__CARDS) { srcs = srcs.concat(window.__CARDS); } } catch (e) {}
    for (var i = 0; i < srcs.length; i++) { if (srcs[i] && srcs[i].id === id) { return srcs[i]; } }
    return null;
  }

  /* 日报「本日报相关」里的项目按钮（老朋友 / 退稿等，库里有卡片就直接复用） */
  document.addEventListener('click', function (e) {
    var el = e.target && e.target.closest ? e.target.closest('.relchip[data-pid]') : null;
    if (!el) { return; }
    var p = findCard(el.getAttribute('data-pid'));
    if (p) { e.preventDefault(); render(p); }
  });

  /* 深链：?detail=<owner/repo> 直接打开（方便截图和分享） */
  window.addEventListener('DOMContentLoaded', function () {
    var id = new URLSearchParams(location.search).get('detail');
    if (!id) { return; }
    var srcs = [];
    try { if (typeof DATA !== 'undefined' && DATA) { srcs = srcs.concat(DATA.picks || [], DATA.projects || [], DATA.related || []); } } catch (e) {}
    try { if (typeof PROJ !== 'undefined' && PROJ) { srcs = srcs.concat(PROJ); } } catch (e) {}
    try { if (window.__CARDS) { srcs = srcs.concat(window.__CARDS); } } catch (e) {}
    var found = null;
    srcs.forEach(function (x) { if (x && x.id === id) { found = x; } });
    if (found) { render(found); }
  });
  /* 站点外壳的快捷键（1–4 / G / ESC）转发：焦点在页面里也能用 */
  document.addEventListener('keydown', function (e) {
    var t = e.target;
    if (t && /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName)) { return; }
    if (/^[1-4gG]$/.test(e.key) || e.key === 'Escape') {
      try { parent.postMessage({ __archiveKey: e.key }, '*'); } catch (err) {}
    }
  });
  /* file:// 下父文档拿不到本页 contentWindow：页内 #/ 路由链接改成 postMessage 转发给外壳 */
  if (window.parent !== window) {
    document.addEventListener('click', function (e) {
      var a = e.target && e.target.closest ? e.target.closest('a[href^="#/"]') : null;
      if (!a) { return; }
      e.preventDefault();
      try { parent.postMessage({ __archiveRoute: a.getAttribute('href') }, '*'); } catch (err) {}
    }, true);
  }

  /* 完整日报浮层（C/D 共用；内容由构建期注入） */
  (function () {
    var btn = document.getElementById('frbtn'), wrap = document.getElementById('frwrap');
    if (!btn || !wrap) { return; }
    function openFr() { wrap.classList.add('on'); wrap.setAttribute('aria-hidden', 'false'); document.documentElement.style.overflow = 'hidden'; }
    function closeFr() { wrap.classList.remove('on'); wrap.setAttribute('aria-hidden', 'true'); document.documentElement.style.overflow = ''; }
    btn.addEventListener('click', openFr);
    wrap.addEventListener('click', function (e) { if (e.target.closest && e.target.closest('[data-fr-close]')) { closeFr(); } });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape') { closeFr(); } });
  })();
})();
