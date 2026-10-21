/* site-motion.js — 只做三件事：入视口、一次焦点、必要的状态反馈。
   默认内容可见；JS 失败不隐藏内容；减少动态效果直接退出。 */
(function () {
  'use strict';
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduced) return;
  var page = document.body.getAttribute('data-motion-page') || '';
  var fine = window.matchMedia && window.matchMedia('(pointer: fine)').matches;
  var ready = false;
  function markReady() { if (ready) return; ready = true; document.body.classList.add('motion-ready'); }
  function texture(kind) {
    if (!page) return;
    var d = document.createElement('div');
    d.className = 'motion-texture ' + kind;
    d.setAttribute('aria-hidden', 'true');
    document.body.appendChild(d);
  }
  if (page === 'daily') texture('ribbed');
  if (page === 'library') texture('rebar');
  if (page === 'weekly') texture('tunnel');

  /* ---------- 首页：一次性扫描 + 色差 + 光斑 ---------- */
  if (page === 'home' && fine) {
    var hero = document.querySelector('.hero');
    if (hero) {
      var spot = document.createElement('div'); spot.className = 'motion-spotlight'; spot.setAttribute('aria-hidden', 'true'); hero.appendChild(spot);
      var scan = document.createElement('div'); scan.className = 'motion-scanline-home'; scan.setAttribute('aria-hidden', 'true'); hero.appendChild(scan);
      var w1 = hero.querySelector('.w1');
      if (w1) w1.classList.add('motion-glitch');
      var q = false;
      hero.addEventListener('pointermove', function (e) {
        if (q) return; q = true;
        requestAnimationFrame(function () {
          var r = hero.getBoundingClientRect();
          var x = ((e.clientX - r.left) / Math.max(1, r.width)) * 100;
          var y = ((e.clientY - r.top) / Math.max(1, r.height)) * 100;
          spot.style.setProperty('--mx', x.toFixed(2) + '%');
          spot.style.setProperty('--my', y.toFixed(2) + '%');
          q = false;
        });
      }, { passive: true });
    }
  }

  /* ---------- 站点壳：切页时的一次扫描幕 ---------- */
  if (page === 'shell') {
    var curtain = document.createElement('div');
    curtain.className = 'motion-route-curtain';
    curtain.setAttribute('aria-hidden', 'true');
    document.body.appendChild(curtain);
    var routeTimer = 0;
    function routePulse() {
      if (routeTimer) clearTimeout(routeTimer);
      document.body.classList.add('motion-route');
      curtain.classList.remove('on');
      void curtain.offsetWidth;
      curtain.classList.add('on');
      routeTimer = setTimeout(function () {
        document.body.classList.remove('motion-route');
        curtain.classList.remove('on');
      }, 430);
    }
    window.addEventListener('hashchange', routePulse);
  }

  /* ---------- 顶部读取进度（日报 / 周报） ---------- */
  if (page === 'daily' || page === 'weekly') {
    var bar = document.createElement('div');
    bar.className = 'motion-progress';
    bar.setAttribute('aria-hidden', 'true');
    document.body.appendChild(bar);
    var ticking = false;
    function updateBar() {
      var h = document.documentElement.scrollHeight - innerHeight;
      var p = h > 0 ? Math.min(1, Math.max(0, scrollY / h)) : 0;
      bar.style.width = (p * 100).toFixed(2) + '%';
      ticking = false;
    }
    addEventListener('scroll', function () {
      if (ticking) return; ticking = true; requestAnimationFrame(updateBar);
    }, { passive: true });
    updateBar();
  }

  /* ---------- 入视口：只启动一次 ---------- */
  var selectors = {
    daily: '.bay,.b-cell,.cd-row,.mem-row',
    weekly: '.sec',
    library: '.wcard-in'
  };
  var io = null;
  if ('IntersectionObserver' in window) {
    io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        en.target.classList.add('is-in');
        io.unobserve(en.target);
      });
    }, { rootMargin: '0px 0px -7% 0px', threshold: 0.06 });
  }
  function collect() {
    if (!io) return;
    var sel = selectors[page];
    if (!sel) return;
    var nodes = document.querySelectorAll(sel);
    var i = 0;
    for (; i < nodes.length; i++) {
      var n = nodes[i];
      if (n.hasAttribute('data-motion-reveal')) continue;
      n.setAttribute('data-motion-reveal', '');
      n.style.setProperty('--mo-delay', Math.min(i * 42, 252) + 'ms');
      io.observe(n);
    }
  }
  if (io && selectors[page]) {
    markReady();
    collect();
    document.addEventListener('focusin', function (e) {
      var n = e.target && e.target.closest ? e.target.closest('[data-motion-reveal]') : null;
      if (n) n.classList.add('is-in');
    });
    if (page === 'library') {
      var t = 0;
      new MutationObserver(function () {
        if (t) clearTimeout(t);
        t = setTimeout(collect, 80);
      }).observe(document.body, { childList: true, subtree: true });
    }
  }

  /* ---------- 周报图版：轻微视差，只动 2–8px ---------- */
  if (page === 'weekly' && fine) {
    var plates = Array.prototype.slice.call(document.querySelectorAll('.plate'));
    if (plates.length) {
      var pTick = false;
      var parallax = function () {
        pTick = false;
        var vh = innerHeight || 800;
        for (var k = 0; k < plates.length; k++) {
          var r = plates[k].getBoundingClientRect();
          if (r.bottom < -80 || r.top > vh + 80) continue;
          var d = ((r.top + r.height / 2) - vh / 2) / Math.max(1, vh);
          plates[k].style.transform = 'translate3d(0,' + (d * 8).toFixed(2) + 'px,0)';
        }
      };
      addEventListener('scroll', function () {
        if (pTick) return; pTick = true; requestAnimationFrame(parallax);
      }, { passive: true });
      parallax();
    }
  }

  /* ---------- 周报图表的入视口扫描，只跑一次 ---------- */
  if (io && page === 'weekly') {
    var charts = document.querySelectorAll('.chart-wrap');
    var cio = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        en.target.classList.add('motion-scan');
        cio.unobserve(en.target);
      });
    }, { threshold: 0.12 });
    for (var c = 0; c < charts.length; c++) cio.observe(charts[c]);
  }
})();
