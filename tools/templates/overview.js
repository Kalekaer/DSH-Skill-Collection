
const P = {{JSON}};
const E = {{EV}};
const PLANS = {{PLANS}};
const SYN = {{SYN}};   // 同义词组：搜索时按「组内任一命中」算命中
const WS = {{WS}};
const DIMS = ['领域','形态','用途','成熟度','上手难度','风险等级'];
const STA = {active:'已收录',using:'正在用',watching:'继续观察',researching:'正在研究',dropped:'不再看'};   // B14：saved 已废弃，不留死映射
const f = {q:'', sort:'stars', status:'', risk:'', tier:'', five:'', active:'', l1:'', l2:'', tag:'', badge:''};
let cmpSel = [];   // 对比选择（最多 2 个，页内纯前端）
let groupByUse = false;   // 按用途分组（把结果按二级分类聚合，便于按流程挑组合）

function esc(s){return (s||'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
function repoUrl(p){ return 'https://github.com/' + p.id; }
function when(s){ return s ? String(s).slice(0,10) : '—'; }
function daysAgo(s){ if(!s) return null; const d=new Date(String(s)); if(isNaN(d)) return null; return Math.floor((Date.now()-d)/86400000); }
function stars5(n){ if(n===null||n===undefined) return '<span class="stars5" style="color:var(--dim)">待评估</span>'; return '<span class="stars5">'+'★'.repeat(n)+'☆'.repeat(5-n)+'</span>'; }
function oneText(p){ return p.one || (p.desc ? p.desc : null); }function evCount(p){ const e=E[p.id]; return e? e.length : 0; }
function hay(p){
  return [p.id,p.desc||'',p.note||'',p.one||'',p.prob||'',p.ex||'',
    (p.fn||[]).join(' '),(p.ft||[]).join(' '),(p.un||[]).map(x=>x&&x.note?x.note:'').join(' '),
    p.t.join(' '),p.l1||'',p.l2||''].join(' ').toLowerCase();
}
// —— 搜索词处理：分词 + 错字容错（v3.1 第五节）——
let CURTOK = [];
let VOCAB = null;
function buildVocab(){
  if(VOCAB) return VOCAB;
  const set=new Set();
  P.forEach(p=>{
    (p.ft||[]).forEach(x=>{ if(x) set.add(String(x).toLowerCase()); });
    [p.l1,p.l2].forEach(x=>{ if(x) set.add(String(x).toLowerCase()); });
    String(p.id||'').toLowerCase().split(/[\/\-_.]+/).forEach(x=>{ if(x.length>2) set.add(x); });
  });
  VOCAB=Array.from(set);
  return VOCAB;
}
function lev(a,b){
  const m=a.length,n=b.length; if(!m) return n; if(!n) return m;
  let prev=[]; for(let j=0;j<=n;j++) prev[j]=j;
  for(let i=1;i<=m;i++){
    const cur=[i];
    for(let j=1;j<=n;j++){
      const cost=(a[i-1]===b[j-1])?0:1;
      cur[j]=Math.min(cur[j-1]+1, prev[j]+1, prev[j-1]+cost);
    }
    prev=cur;
  }
  return prev[n];
}
function fuzzyFix(tok){
  if(!tok || tok.length<3) return null;
  const v=buildVocab().concat((SYN||[]).reduce(function(a,g){ return a.concat((g.terms||[]).map(function(x){ return String(x).toLowerCase(); })); },[]));   // 1a：把同义词表的词并进容错词表（原来库里没有 photoshop 这类词，photshop 修不到）
  for(let i=0;i<v.length;i++){
    const w=v[i];
    if(Math.abs(w.length-tok.length)<=1 && lev(tok,w)<=1) return w;
  }
  return null;
}
// 同义词扩展（B2）：命中组内任一词 → 返回整组，搜索按「组内任一命中」判定
function expandToken(t){
  const tl=String(t).toLowerCase();
  for(const g of (SYN||[])){
    const terms=(g.terms||[]).map(x=>String(x).toLowerCase());
    if(terms.indexOf(tl)>=0) return terms;
  }
  return [tl];
}function parseQuery(q){
  if(!q) return [];
  let toks=q.split(/[\s,，、;；|]+/).filter(x=>x);
  if(!toks.length) toks=[q];
  // §2 修复（v5.1.0 测试发现）：中文整句没有空格 → 整句被当成**一个词**去匹配，必然 0 命中
  // （实测「我想做PPT / 我要画图 / 我要写代码 / 我要找AI助手 / 我要管理文件」= 0/5）。
  // 策略：剥掉意图前缀，对剩下的短词做同义词扩展；整句也保留（避免误伤正常搜索）。
  const INTENT = /^(我想|我要|帮我|给我|想要|需要一个|需要|寻找|找找|有没有|求|想|要|找|做个|做)/;
  return toks.map(function(t){
    const tl0 = String(t).toLowerCase();
    if (expandToken(tl0).length > 1) return expandToken(tl0);   // ① 精确命中同义词组 → 不要再容错改写（ppt 被 fuzzyFix 改写就是这个 bug）
    const f = fuzzyFix(t) || t;   // ② 没命中才容错
    let s = f; for (let k = 0; k < 2; k++) { s = s.replace(INTENT, ''); }   // 剥两层：「我要找AI助手」→ 我要 → 找 → ai助手
    let parts = [];
    if (s && s !== f) { parts = parts.concat(expandToken(s)); }
    const full = expandToken(f);
    for (const x of full) { if (parts.indexOf(x) < 0) parts.push(x); }
    return parts;
  });
}

function pass(p){
  if(f.l1 && p.l1!==f.l1) return false;
  if(f.l2 && p.l2!==f.l2) return false;
  if(f.badge && badgeOf(p).indexOf(f.badge)<0) return false;   // P2-2：按分层徽章过滤 ✓
  if(f.q){
    // 分词 + 容错后，要求**所有词都命中**（多词查询更精确）；单词查询等价于原来的子串匹配
    if(CURTOK.length){
      const h=hay(p);
      if(!CURTOK.every(set=>set.some(t=>h.indexOf(t)>=0))) return false;   // 词集：组内任一命中即可（B2）
    }
  }
  if(f.tag && (p.ft||[]).indexOf(f.tag)<0) return false;
  if(f.status && p.status!==f.status) return false;
  if(f.risk && p.risk!==f.risk) return false;
  if(f.tier){ if(p.tier!==f.tier) return false; }
  if(f.five){ if(+f.five===0){ if(p.exp!==null) return false; } else { if(p.exp===null || p.exp < +f.five) return false; } }
  if(f.active){ const d=daysAgo(p.pushed); if(d===null || d> +f.active) return false; }
  return true;
}
// 搜索优先级（v3.1 验收）：项目全名 > 简称 > 前缀 > GitHub ID > 功能标签 > 一句话 > 分类
function matchScore(p,q){
  if(!q) return 0;
  const qq=q.toLowerCase();
  const id=(p.id||'').toLowerCase();
  const name=id.split('/')[1]||'';
  if(id===qq) return 100;
  if(name===qq) return 95;
  if(name.indexOf(qq)===0) return 85;
  if(id.indexOf(qq)>=0) return 80;
  if((p.ft||[]).some(x=>String(x).toLowerCase().indexOf(qq)>=0)) return 65;
  if((p.one||'').toLowerCase().indexOf(qq)>=0) return 50;
  if((p.l1||'').toLowerCase()===qq||(p.l2||'').toLowerCase()===qq) return 45;
  return 25;
}
function sorted(arr){
  const r=arr.slice();
  const bySort=(a,b)=>{
    if(f.sort==='stars'){ const x=a.exp===null?-1:a.exp, y=b.exp===null?-1:b.exp; return y-x || (b.expSc||0)-(a.expSc||0) || b.stars-a.stars; }
    if(f.sort==='gh') return b.stars-a.stars;
    if(f.sort==='recent') return String(b.pushed||'').localeCompare(String(a.pushed||''));
    return a.id.localeCompare(b.id);
  };
  r.sort((a,b)=>{
    if(f.q){ const d=matchScore(b,f.q)-matchScore(a,f.q); if(d!==0) return d; }
    return bySort(a,b);
  });
  return r;
}
function hasNote(p){ return !!(p.note || (p.un && p.un.filter(x=>x&&x.note).length)); }
function cardHtml(p, idx){
  const flags=[];
  if(p.tier==='S'||p.tier==='A') flags.push('<span class="pill tier-'+p.tier+'">'+p.tier+' 档</span>');
  else if(p.tier==='dropped') flags.push('<span class="pill s-dropped">D 档</span>');
  else flags.push('<span class="pill tier-unrated">D 档</span>');
  if(p.risk) flags.push('<span class="pill r-'+(p.risk==='低'?'low':p.risk==='高'?'high':'mid')+'">风险 '+p.risk+'</span>');
  if(p.status!=='active') flags.push('<span class="pill s-'+p.status+'">'+(STA[p.status]||p.status)+'</span>');
  if(p.origin==='user') flags.push('<span class="pill" style="border-color:var(--violet-line);color:var(--violet)">用户推荐</span>');
  // P1-2：官方/大厂徽章**排第一**（白名单命中才有；只降验证成本、不加分 ✓）
  flags.unshift(badgeHtml(p));   // P2-2：徽章排在最前（官方/新星/冷门/常青/待观察）✓
  const fts=(p.ft||[]).slice(0,2).map(x=>'<span class="pill pill-fn">'+esc(x)+'</span>').join('');
  const one = oneText(p);
  // 待补全条目**不隐藏、但降低视觉权重**（GPT 建议）：明确标出来，而不是让用户以为"就这么点东西"
  const thin = (p.hs!=='complete');
  // 卡片上没有任何"收藏"元素：收藏功能已整体撤销（用户 2026-10-13 决定：用起来太麻烦繁琐）
  // 📝 备注标记（2026-10-15 用户要求，方案 A）：该条有台账备注或用户备注时，在标题旁给一个记号 ——
  // 不用点进详情就知道"这条有备注"。备注**只在详情面板里显示**（页面是只读单文件，不能在页面里编辑）。
  const noteMark = hasNote(p) ? '<span title="这条有备注（台账备注 / 用户备注）—— 点开卡片看详情" style="margin-left:6px;font-size:var(--fs-xs);color:var(--gold);cursor:help">📝</span>' : '';
  // 批次 6 · #/all：**行式密集排版**（设计 §10.5「列表用行式密集排版，非卡片墙」）——
  // 三段：编号（等宽）｜正文（标题 / 一句话 / 标签 / 标记）｜元数据列（星数·语言·许可·最近提交，等宽右对齐）
  // ⚠️ 根元素类名必须保持 class="card"（check-page 用 /class="card/ 计数，改名等于自己拆网 ✗）
  const rk = (typeof idx === 'number') ? String(idx+1).padStart(2,'0') : '';
  return '<div class="card'+(thin?' thin':'')+'" onclick="detail(\''+p.id+'\')">'
    +'<span class="rk mono" aria-hidden="true">'+rk+'</span>'
    +'<div class="main">'
    +'<h3><a href="'+repoUrl(p)+'" target="_blank" rel="noopener" onclick="event.stopPropagation()">'+esc(p.id)+'</a>'+noteMark
      +'<span class="cmp'+(cmpSel.indexOf(p.id)>=0?' on':'')+'" onclick="toggleCmp(event,\''+p.id+'\')">'+(cmpSel.indexOf(p.id)>=0?'✓ 已选对比':'对比')+'</span></h3>'
    +'<div class="stars">'+stars5(p.exp)+' <span class="pill">'+esc(p.l2)+'</span></div>'
    +'<p class="one'+(one?'':' none')+'">'+esc(one||'（暂无中文介绍，仅有英文描述或台账备注）')+'</p>'
    +(thin?'<div class="soon">详细介绍待补全：这个库在长，它还没轮到</div>':'')
    +'<div class="row tags">'+fts+flags.join('')+'</div>'
    +'</div>'
    +'<div class="meta"><span>★ '+p.stars.toLocaleString()+'</span>'
    +'<span>'+esc(p.lang||'')+' ｜ '+esc(p.lic||'许可未知')+'</span>'
    +'<span title="最近提交">'+when(p.pushed)+'</span></div>'
    +'</div>';
}
// ---------- 项目对比（页内，纯前端；数据已内嵌，不调 API） ----------
function toggleCmp(ev, id){
  if(ev && ev.stopPropagation) ev.stopPropagation();
  const i=cmpSel.indexOf(id);
  if(i>=0) cmpSel.splice(i,1);
  else { if(cmpSel.length>=2) cmpSel.shift(); cmpSel.push(id); }
  render(); renderCmpBar();
}
function clearCmp(){ cmpSel=[]; render(); renderCmpBar(); }
function renderCmpBar(){
  const bar=document.getElementById('cmpBar');
  if(!cmpSel.length){ bar.className=''; bar.innerHTML=''; return; }
  bar.className='on';
  bar.innerHTML='<span>已选 <b>'+cmpSel.length+'/2</b>：'+cmpSel.map(esc).join('　vs　')+'</span>'
    +(cmpSel.length===2?'<span class="chip on" onclick="showCompare()">查看对比</span>':'<span style="color:var(--dim)">再选一个</span>')
    +'<span class="chip" onclick="clearCmp()">清空</span>';
}
function cmpCell(p, kind){
  if(!p) return '';
  if(kind==='one')   return oneText(p)||'';
  if(kind==='what')  return (p.fn&&p.fn[0])||'';
  if(kind==='core')  return (p.fn&&p.fn[1])||'';
  if(kind==='use')   return (p.fn&&p.fn[2])||'';
  if(kind==='case')  return (p.fn&&p.fn[3])||'';
  if(kind==='no')    return (p.fn&&p.fn[4])||'';
  if(kind==='ease')  return (p.t&&p.t[4])||'';
  if(kind==='env')   return p.lang||'';
  if(kind==='exp')   return (p.exp===null||p.exp===undefined)?'':('★'.repeat(p.exp)+'☆'.repeat(5-p.exp)+'（'+p.expSc+'/100）');
  if(kind==='stars') return p.stars.toLocaleString();
  if(kind==='pushed')return when(p.pushed);
  if(kind==='lic')   return p.lic||'';
  if(kind==='risk')  return p.risk||(p.t&&p.t[5])||'';
  if(kind==='tier')  return (p.tier==='S'||p.tier==='A')?(p.tier+' 档'):(p.tier==='dropped'?'D 档':'D 档');
  return '';
}
function cmpRow(A,B,label,kind){
  const a=cmpCell(A,kind), b=cmpCell(B,kind);
  const t=v=>v?esc(v):'<span style="color:var(--dim)">（待补全）</span>';
  return '<tr><td>'+label+'</td><td>'+t(a)+'</td><td>'+t(b)+'</td></tr>';
}
function cmpSuggest(A,B){
  const s=[];
  if(A.exp!==null&&B.exp!==null&&A.exp!==undefined&&B.exp!==undefined&&A.exp!==B.exp)
    s.push('体验评分更高：<b>'+(A.exp>B.exp?esc(A.id):esc(B.id))+'</b>（'+A.exp+'★ vs '+B.exp+'★）');
  const ra=A.risk||(A.t&&A.t[5]), rb=B.risk||(B.t&&B.t[5]);
  const rank={'低':1,'中':2,'高':3};
  if(ra&&rb&&ra!==rb&&rank[ra]&&rank[rb]) s.push('风险更低：<b>'+(rank[ra]<rank[rb]?esc(A.id):esc(B.id))+'</b>（'+ra+' vs '+rb+'）');
  const da=A.t&&A.t[4], db=B.t&&B.t[4];
  const rank2={'开箱即用':1,'轻配置':2,'要编程':3,'要部署':4};
  if(da&&db&&da!==db&&rank2[da]&&rank2[db]) s.push('更易上手：<b>'+(rank2[da]<rank2[db]?esc(A.id):esc(B.id))+'</b>（'+da+' vs '+db+'）');
  if(!s.length) s.push('两者在评分 / 风险 / 上手难度上没拉开差距，建议按使用场景选（见上面「常见用途」行）');
  return s;
}
function showCompare(){
  if(cmpSel.length<2) return;
  const A=P.find(x=>x.id===cmpSel[0]), B=P.find(x=>x.id===cmpSel[1]);
  if(!A||!B) return;
  const h='<span class="close" onclick="closePanel()">×</span>'
    +'<h2>对比：'+esc(A.id)+' vs '+esc(B.id)+'</h2>'
    +'<div style="color:var(--dim);font-size:var(--fs-sm)">数据来自本地知识库（页面已内嵌）｜ 未调用任何 API ｜ 缺失标「（待补全）」</div>'
    +'<table class="cmpt"><tr><th>维度</th><th>'+esc(A.id)+'</th><th>'+esc(B.id)+'</th></tr>'
    +cmpRow(A,B,'一句话定位','one')
    +cmpRow(A,B,'是什么','what')
    +cmpRow(A,B,'核心功能','core')
    +cmpRow(A,B,'常见用途（适合谁）','use')
    +cmpRow(A,B,'使用案例','case')
    +cmpRow(A,B,'不适合','no')
    +cmpRow(A,B,'学习成本（上手难度）','ease')
    +cmpRow(A,B,'运行环境（语言）','env')
    +cmpRow(A,B,'体验评分（不看 star）','exp')
    +cmpRow(A,B,'星数','stars')
    +cmpRow(A,B,'最近提交','pushed')
    +cmpRow(A,B,'License','lic')
    +cmpRow(A,B,'风险','risk')
    +cmpRow(A,B,'档位','tier')
    +'</table>'
    +'<div class="sec-h">怎么选（自动判断，仅供参考）</div>'
    +'<ul style="margin:4px 0 0;padding-left:20px;font-size:var(--fs-sm);line-height:1.8">'+cmpSuggest(A,B).map(x=>'<li>'+x+'</li>').join('')+'</ul>'
    +'<div class="cmpnote">判断只基于本地数据（体验评分 / 风险 / 上手难度），不构成使用担保；用前请看各自仓库的 License 与最近维护状态。</div>'
    +'<div class="kv"><a href="'+repoUrl(A)+'" target="_blank" rel="noopener">打开 '+esc(A.id)+' ↗</a>　'
    +'<a href="'+repoUrl(B)+'" target="_blank" rel="noopener">打开 '+esc(B.id)+' ↗</a></div>';
  document.getElementById('panel').innerHTML=h;
  document.getElementById('panel').classList.add('open');
}
// ---------- 方案（v3.1 第八节）：需求 → 工具组合 + 为什么 ----------
function planFor(q){
  if(!q) return null;
  const qq=q.toLowerCase();
  return PLANS.find(function(pl){
    return (pl.triggers||[]).some(function(t){
      const tl=String(t).toLowerCase();
      return qq.indexOf(tl)>=0 || tl.indexOf(qq)>=0;
    });
  }) || null;
}
function planRoleTools(role, max){
  const out=[];
  P.forEach(function(p){
    if(p.status==='dropped') return;
    let sc=0;
    let ftHit=0;   // A 方案第三刀：分类命中必须搭配功能标签命中
    if(role.l2 && role.l2.length && p.l2 && role.l2.indexOf(p.l2)>=0) sc+=3;
    // 去掉后阈值 >=3 等价于「必须二级分类命中，或 >=2 个功能标签命中」。
    if(role.ft && role.ft.length){
      (p.ft||[]).forEach(function(f){
        const fl=String(f).toLowerCase();
        role.ft.forEach(function(x){
          const xl=String(x).toLowerCase();
          if(fl.indexOf(xl)>=0 || (fl.length>=3 && xl.indexOf(fl)>=0)) sc+=2;   // A 方案：短标签不再反向命中一切
          ftHit++;
        });
      });
    }
    // A 方案（用户 2026-10-14 决定：宁缺毋滥）——原来 sc>0 就进候选，导致「仅一级分类命中」(1 分)
// 的工具被塞进不相关场景（如 WeChatBridge 出现在「做 PPT」「查资料」「产品设计」三个场景）。
// 现在要求 ≥3 分：二级分类命中(3) / 两个功能标签(2+2) / 一个标签+一级分类(2+1)。
// 分数不够就**不显示**——让页面那句「🔍 这一步现在没有合适的选择」说真话。
      if(sc>=3 && ftHit>=1) out.push({p:p, sc:sc});
  });
  out.sort(function(a,b){
    if(b.sc!==a.sc) return b.sc-a.sc;
    const x=(a.p.exp===null||a.p.exp===undefined)?-1:a.p.exp, y=(b.p.exp===null||b.p.exp===undefined)?-1:b.p.exp;
    return y-x || b.p.stars-a.p.stars;
  });
  return out.slice(0, max||2);
}
function planWhyPick(p){
  // **把数据库字段翻成人话**（GPT 评审：不要出现「体验4★｜风险中｜7天提交｜GPL」这种后台串）
  const good=[], bad=[];
  const pt=p.part||{};
  const d=daysAgo(p.pushed);
  if(pt['易用性']>=24) good.push('装上就能用'); else if(pt['易用性']!==undefined && pt['易用性']<15) bad.push('上手要花点功夫');
  if(pt['文档完整度']>=16) good.push('文档比较全'); else if(pt['文档完整度']!==undefined && pt['文档完整度']<10) bad.push('文档较少，可能要自己摸索');
  if(d!==null){ if(d<=30) good.push('最近仍在维护'); else if(d>365) bad.push('很久没更新了'); }
  if(pt['功能成熟度']>=15) good.push('功能比较成熟'); else if(pt['功能成熟度']!==undefined && pt['功能成熟度']<10) bad.push('还比较早期');
  if(pt['风险']>=12) good.push('风险低'); else if(pt['风险']!==undefined && pt['风险']<8) bad.push('有风险，先看清楚再用');
  if(p.lic){ if(/MIT|Apache/i.test(p.lic)) good.push(p.lic+'（可商用）'); else good.push(p.lic); }
  else bad.push('没有 License，商用要谨慎');
  if(p.stars>=10000) good.push('社区成熟（'+(p.stars/10000).toFixed(1)+' 万 star）');
  else if(p.stars<50) bad.push('用的人还少');
  let out='';
  if(good.length) out+='<span style="color:var(--ok)">✅ '+good.map(esc).join(' ｜ ')+'</span>';
  if(bad.length) out+=(out?'<br>':'')+'<span style="color:var(--warn)">⚠️ '+bad.map(esc).join(' ｜ ')+'</span>';
  return out || '<span style="color:var(--dim)">资料不足，暂无法判断</span>';
}
function planRoleAll(role){
  // 该角色一共能匹配到多少个（用于「查看全部 N 个同类工具 →」）
  return planRoleTools(role, 999).length;
}
function showL2(l2){
  f.l2=l2; f.l1=''; f.q='';
  const qEl=document.getElementById('q'); if(qEl) qEl.value='';
  // 从「方案」面板点进来 → 需要切到全库区（原来靠滚到页面底部，路由化后靠切区）
  const pn=document.getElementById('panel'); if(pn) pn.classList.remove('open');
  ensureAllView();
  buildCat(); render();
  const v=document.getElementById('view-all');
  try{ if(v && v.scrollIntoView) v.scrollIntoView({block:'start'}); }catch(e){}
}
function buildPlans(){
  const box=document.getElementById('planGrid');
  if(!box) return;
  if(!PLANS.length){ box.innerHTML='<p class="none">没有方案模板（data/plans.json）</p>'; return; }
  // 批次 6 · #/plans = **工作台/工单**（设计 §10.5：角色-工具用表格线呈现，黄块标"已配齐/缺件"）✓
  const stat=function(pl){
    let ok=0, miss=0;
    (pl.roles||[]).forEach(function(r){ (planRoleAll(r)>0) ? ok++ : miss++; });
    return { n:(pl.roles||[]).length, ok:ok, miss:miss };
  };
  box.innerHTML='<div class="wotable">'
    + '<div class="worow wohead"><span class="mono">#</span><span>方案</span><span class="mono">步骤</span>'
      + '<span class="mono">已配齐</span><span class="mono">缺件</span><span>触发词</span></div>'
    + PLANS.map(function(pl,i){
        const s=stat(pl);
        const trig=(pl.triggers||pl.trigger||[]).slice(0,4).map(function(x){ return '<span class="tagx">'+esc(x)+'</span>'; }).join('');
        return '<button type="button" class="worow" onclick="showPlan(\''+pl.id+'\')">'
          + '<span class="mono wo-no">'+String(i+1).padStart(2,'0')+'</span>'
          + '<span class="wo-name">'+esc(pl.name)+'</span>'
          + '<span class="mono">'+s.n+'</span>'
          + '<span class="mono wo-ok">'+s.ok+'</span>'
          + '<span class="mono wo-miss'+(s.miss?' on':'')+'">'+s.miss+'</span>'
          + '<span class="wo-trig">'+(trig||'<span class="none">—</span>')+'</span>'
          + '</button>';
      }).join('')
    + '</div>';
}
function showPlan(id){
  const pl=PLANS.filter(function(x){ return x.id===id; })[0];
  if(!pl) return;
  // 工单口径：每个角色"库里有没有候选工具" → 已配齐 / 缺件（黄块标已配齐 ✓）
    // ⚠️ planRoleAll 返回的是**数字**（不是数组）——写 .length 会恒为 falsy，把有工具的角色也标成「缺件」✗
  const woStat=(pl.roles||[]).map(function(r){ return (planRoleAll(r)>0)?1:0; });
  const woOk=woStat.filter(function(x){return x;}).length, woMiss=woStat.length-woOk;
  let h='<span class="close" onclick="closePanel()">×</span>'
    +'<h2>'+esc(pl.name)+'</h2>'
    +'<div class="wosum"><span class="wo-st ok">已配齐 '+woOk+' / '+woStat.length+' 步</span>'
      +(woMiss?'<span class="wo-st miss">缺件 '+woMiss+' 步</span>':'')
      +'<span class="mono">工具来自你的本地库，按用途自动匹配 ｜ 未调用 API ｜ 步骤顺序由你决定</span></div>';
  // 摘要先行（商城版：一次给全，但先给能一眼看完的）
  const roleN=(pl.roles||[]).length;
  const easeMap={'开箱即用':5,'轻配置':4,'要编程':2,'要部署':1};
  const eases=[];
  (pl.roles||[]).forEach(function(r){
    planRoleTools(r,1).forEach(function(t){
      const e=easeMap[(t.p.t&&t.p.t[4])||''];
      if(e) eases.push(e);
    });
  });
  let diff='';
  if(eases.length){
    const avg=eases.reduce(function(a,b){return a+b;},0)/eases.length;
    const lvl=Math.max(1,Math.min(5,Math.round(6-avg)));
    diff=' ｜ 难度 '+'★'.repeat(lvl)+'☆'.repeat(5-lvl);
  }
  h+='<div class="hbody" style="margin-top:10px">'+esc(pl.intro)+'</div>';
  h+='<div style="color:var(--dim);font-size:var(--fs-sm);margin-top:8px">这套要 <b>'+roleN+'</b> 步'
    +(pl.roles||[]).map(function(r,i){return '　'+(i+1)+'. '+esc(r.role);}).join('')+diff+'</div>';
  (pl.roles||[]).forEach(function(r,i){
    const tools=planRoleTools(r,2);
    const allN=planRoleAll(r);
    h+='<div class="wo-role"><span class="mono wo-no">'+String(i+1).padStart(2,'0')+'</span><b>'+esc(r.role)+'</b>'+((woStat[i])?'<span class="wo-st ok">已配齐</span>':'<span class="wo-st miss">缺件</span>')+'</div>';
    h+='<div style="color:var(--dim);font-size:var(--fs-sm);margin-bottom:6px">为什么需要这一步：'+esc(r.why)+'</div>';
    if(!tools.length){
      // 不要像失败（GPT 评审）：给两条可走的路
      h+='<div class="todo-box">🔍 「'+esc(r.role)+'」这一步，你的工具库现在没有合适的选择。<br>'
        +'可以：① 我去 GitHub 搜 2–3 个候选给你过目（要花一点 API 额度）　② 先放着，等以后自动收录 —— 这一步不挡着你先做前面的</div>';
      return;
    }
    h+='<table class="cmpt"><tr><th>工具</th><th>适合谁 / 为什么选它 / 要注意</th></tr>';
    tools.forEach(function(t,ti){
      const p=t.p;
      const medal=ti===0?'🥇':'🥈';
      const label=ti===0?'首选':'备选（觉得太重可以用这个）';
      h+='<tr><td style="white-space:normal;min-width:150px">'
        +medal+' <a href="'+repoUrl(p)+'" target="_blank" rel="noopener" onclick="event.stopPropagation()">'+esc(p.id)+'</a>'
        +'<br><span style="color:var(--dim);font-size:var(--fs-xs)">'+stars5(p.exp)+' ｜ '+label+'</span>'
        +'<br><span class="cmp" style="margin-left:0" onclick="detail(\''+p.id+'\')">看详情</span></td>'
        +'<td style="white-space:normal"><div>'+esc(oneText(p)||'（待补全）')+'</div>'
        +'<div style="font-size:var(--fs-xs);margin-top:5px;line-height:1.7">'+planWhyPick(p)+'</div></td></tr>';
    });
    h+='</table>';
    if(allN>tools.length && r.l2 && r.l2[0]){
      h+='<div style="margin-top:4px"><span class="chip" onclick="showL2(\''+String(r.l2[0])+'\')">查看全部 '+allN+' 个同类工具 →</span></div>';
    }
  });
  h+='<div class="cmpnote">这是「按用途归类」的建议，不构成使用担保；每个工具用前请看它的 License 与最近维护状态。想看两个的差别：在卡片上点「对比」。</div>';
  document.getElementById('panel').innerHTML=h;
  document.getElementById('panel').classList.add('open');
  setHash('#/plans/'+encodeURIComponent(id));   // 深链：单个方案的链接可分享
}

// —— 搜索缺口：搜不到就记下来（页面是本地静态文件，写不了工作区，所以「记下 + 复制」交给用户转给我）——
let gapList = [];
function loadGaps(){
  try{ const s=localStorage.getItem('dsh-lib-gaps'); if(s) gapList=JSON.parse(s)||[]; }catch(e){ gapList=[]; }
  renderGapChip();
}
function saveGaps(){ try{ localStorage.setItem('dsh-lib-gaps', JSON.stringify(gapList)); }catch(e){} }
function addGap(term){
  const t=(term||'').trim(); if(!t) return;
  if(gapList.indexOf(t)<0) gapList.push(t);
  saveGaps(); renderGapChip();
  try{ navigator.clipboard.writeText(t); }catch(e){}
  const el=document.getElementById('gapHint');
  if(el) el.innerHTML='已记下「'+esc(t)+'」（同时复制到剪贴板）。攒几个后点右上角「⚠ 搜索缺口」一次性复制给我，我补进同义词表。';
}
function copyGaps(){
  if(!gapList.length) return;
  const txt=gapList.join('\n');
  try{ navigator.clipboard.writeText(txt); }catch(e){}
  const el=document.getElementById('gapHint');
  if(el) el.innerHTML='已复制 '+gapList.length+' 个缺口词：'+esc(txt.replace(/\n/g,' / '))+'　→ 发给我即可补词表。';
  else alert('已复制 '+gapList.length+' 个缺口词：\n'+txt+'\n\n发给我即可补进同义词表。');
}
function clearGaps(){ gapList=[]; saveGaps(); renderGapChip(); }
function renderGapChip(){
  const c=document.getElementById('gapChip');
  if(!c) return;
  if(!gapList.length){ c.style.display='none'; return; }
  c.style.display='inline-block';
  c.textContent='⚠ 搜索缺口 '+gapList.length+'（点我复制）';
}
function render(){
  f.q=document.getElementById('q').value.trim().toLowerCase();
  CURTOK=parseQuery(f.q);
  f.status=document.getElementById('fs').value;
  f.risk=document.getElementById('fr').value;
  f.tier=document.getElementById('ft').value;
  f.five=document.getElementById('f5').value;
  f.active=document.getElementById('fa').value;
  f.sort=document.getElementById('sort').value;
  f.badge=document.getElementById('fb').value;
  const r=sorted(P.filter(pass));
  const hint=document.getElementById('countHint');
  const scope = f.l1 ? ('　分类：'+f.l1+(f.l2?(' → '+f.l2):'')) : '';
  const sortedNote = f.q ? '　（已按匹配度排序：项目名 > 简称 > 标签 > 描述）' : '';
  hint.textContent='命中 '+r.length+' / '+P.length+' 个工具'+scope+sortedNote;
  const list=document.getElementById('list');
  if(!r.length){
    const qt=document.getElementById('q').value.trim();
    list.innerHTML=planHintHtml() + '<div class="empty">没有匹配的工具。<br>'
      +(qt?('<span class="chip" onclick="addGap(document.getElementById(\'q\').value.trim())">记下这个词</span> '):'')
      +'<span class="chip" onclick="clearAll()">清空筛选</span>'
      +'<div id="gapHint" style="margin-top:12px;color:var(--dim);font-size:var(--fs-sm);line-height:1.8">搜不到？点「记下这个词」存起来，'
      +'攒几个后点顶部「⚠ 搜索缺口」一次性复制给我 —— 我把它补进同义词表，<b>词表就这样随库增长</b>，而不是一成不变。</div></div>';
    return;
  }
  if(groupByUse){
    // 按用途分组：把命中的工具按其二级分类聚在一起，便于按流程挑组合（组合是否合适由用户判断）
    const byL2={};
    r.forEach(p=>{ const k=p.l2||'其他工具'; if(!byL2[k]) byL2[k]=[]; byL2[k].push(p); });
    const keys=Object.keys(byL2).sort((a,b)=>byL2[b].length-byL2[a].length);
    list.innerHTML=planHintHtml()+ '<div class="grpNote">按用途分组：同组工具通常可以配合使用（是否真的合适由你判断，这里只做归类，不替你决定流程）</div>'
      + keys.map(k=>'<div class="grpHead">'+esc(k)+'<em>'+byL2[k].length+' 个</em></div>'+byL2[k].map(cardHtml).join('')).join('');
    return;
  }
  list.innerHTML = planHintHtml() + r.map(function(p,i){return cardHtml(p,i)}).join('');
}
// 搜到的词像一个「场景」时，主动提示可以看成套方案
function planHintHtml(){
  if(!f.q) return '';
  const pl=planFor(f.q);
  if(!pl) return '';
  return '<div class="grpNote">💡 这像是一个场景，不只是单个工具 —— '
    +'<span class="chip on" onclick="showPlan(\''+pl.id+'\')">看「'+esc(pl.name)+'」该怎么配</span></div>';
}
function toggleGroup(){
  groupByUse=!groupByUse;
  const b=document.getElementById('grpBtn');
  b.className='chip'+(groupByUse?' on':'');
  b.textContent=groupByUse?'分组中（点此取消）':'按用途分组';
  render();
}
function quickStatus(s){
  f.status=s; const sEl=document.getElementById('fs'); if(sEl) sEl.value=s;
  buildCat(); render();
  ensureAllView();     // 从别处改状态 → 切到全库，否则用户看不到结果
  const v=document.getElementById('view-all');
  try{ if(v && v.scrollIntoView) v.scrollIntoView({block:'start'}); }catch(e){}
}
function setL1(g){ f.l1=(f.l1===g?'':g); f.l2=''; buildCat(); render(); syncURL(); }
function setL2(g){ f.l2=(f.l2===g?'':g); buildCat(); render(); syncURL(); }
function setTag(t){ f.tag=(f.tag===t?'':t); buildCat(); render(); syncURL(); }
// 批次 6：从 #/home 的图表**一步跳进「全库 + 该筛选」**。
// 为什么不能写成 go('all') + setL1(v)：route() 处理 '#/all' 时会 applyQuery('') 把筛选清掉 ✗
// → 正确做法是**先设 f，再把筛选写进 hash**，由 route() 按 hash 复原（applyQuery 会回填控件 ✓）
function jumpL1(v){ f.l1=v; f.l2=''; f.q=''; f.tag=''; const q=document.getElementById('q'); if(q) q.value=''; const qs=filterQuery(); setHash('#/all'+(qs?('?'+qs):'')); }
function jumpL2(v){ f.l2=v; f.l1=''; f.q=''; f.tag=''; const q=document.getElementById('q'); if(q) q.value=''; const qs=filterQuery(); setHash('#/all'+(qs?('?'+qs):'')); }
function clearAll(){
  f.q='';f.status='';f.risk='';f.tier='';f.five='';f.active='';f.l1='';f.l2='';f.tag='';f.badge='';
  document.getElementById('q').value='';['fs','fr','ft','f5','fa','fb'].forEach(id=>{ const el=document.getElementById(id); if(el) el.value=''; });
  buildCat(); render(); syncURL();
}
function miniHtml(p){
  return '<div class="mini" onclick="detail(\''+p.id+'\')">'
    +'<div class="n">'+esc(p.id)+(hasNote(p)?' <span title="这条有备注" style="color:var(--gold);cursor:help">📝</span>':'')+'</div>'
    +'<div style="margin:2px 0">'+stars5(p.exp)+'</div>'
    +'<div class="d">'+esc(oneText(p)||'（暂无中文介绍）')+'</div>'
    +'<div class="m"><span>★ '+p.stars.toLocaleString()+'</span><span>'+when(p.pushed)+'</span></div></div>';
}
function latestPickDay(){
  let d='';
  P.forEach(function(p){ if(p.first && String(p.first)>d) d=String(p.first); });
  return d;
}
// 批次 6 · #/picks = **专题报道**（设计 §10.5）：首条做大做封面稿、其余**按档位分栏**、官方动态做侧栏小字条 ✓
// 批次 6 / P2-2：**分层徽章**（唯一真源 —— 渲染与筛选共用；规则同步写在 #/legend §04）
// 语义：🏢 官方=白名单命中 ｜ 🌱 新星=首见≤14天且有质量信号 ｜ 🧊 冷门=低星但优质（用户 2026-10-16 指定冰块）
//       🧱 常青=库龄>30天且近7天仍有提交 ｜ 🧪 待观察=档位待评估且风险待评估（证据不足）
function badgeOf(p){
  const out=[];
  const day=function(s){ return s ? new Date(String(s)+'T00:00:00').getTime() : null; };
  const now=Date.now();
  const ageD=(day(p.first)!==null) ? Math.floor((now-day(p.first))/86400000) : null;
  const pushD=(p.pushed && day(p.pushed)!==null) ? (now-day(p.pushed))/86400000 : null;
  const good=(p.tier==='S' || p.tier==='A' || (p.exp!==null && p.exp!==undefined && p.exp>=4));
  if(p.oc==='official') out.push('org');
  if(ageD!==null && ageD<=7 && (p.tier==='S' || p.tier==='A')) out.push('new');   // 收紧（2026-10-17）：原来 14 天+质量信号 ⇒ 覆盖 74%，徽章失去区分度 ✗
  if(p.stars<1000 && good) out.push('gem');
  if(ageD!==null && ageD>30 && pushD!==null && pushD<=7) out.push('ever');
  if(!p.tier && !p.risk) out.push('watch');
  return out;
}
function badgeHtml(p){
  const B={org:'🏢',new:'🌱',gem:'🧊',ever:'🧱',watch:'🧪'};
  const T={org:'官方/大厂（白名单）',new:'新星：首见≤14天且有质量信号',gem:'冷门优质：星数<1000 但质量好',ever:'常青：库龄>30天且近7天仍活跃',watch:'待观察：档位与风险都待评估'};
  return badgeOf(p).map(function(k){
    const lab=(k==='org' && p.ol) ? esc(p.ol) : ({org:'官方',new:'新星',gem:'冷门',ever:'常青',watch:'待观察'})[k];
    return '<span class="pill b-'+k+'" title="'+T[k]+'">'+B[k]+' '+lab+'</span>';
  }).join('');
}function tierRank(p){ return p.tier==='S'?0 : p.tier==='A'?1 : p.tier==='B'?2 : 3; }
function leadHtml(p, day, fallback){
  if(!p) return '';
  const one=oneText(p);
  const risk = p.risk ? '<span class="pill r-'+(p.risk==='低'?'low':p.risk==='高'?'high':'mid')+'">风险 '+p.risk+'</span>'
                      : '<span class="pill tier-unrated">风险待评估</span>';
  return '<article class="lead" onclick="detail(\''+p.id+'\')">'
    + '<div class="lead-k mono">'+(fallback?'库里最值得看的':'当天头条')+' · '+esc(String(day||''))+'</div>'
    + '<h3><a href="'+repoUrl(p)+'" target="_blank" rel="noopener" onclick="event.stopPropagation()">'+esc(p.id)+'</a></h3>'
    + '<p class="lead-lede">'+esc(one||'（暂无中文介绍，仅有英文描述或台账备注）')+'</p>'
    + (p.aud?'<p class="lead-aud"><b>适合谁</b>：'+esc(p.aud)+'</p>':'')
    + '<div class="lead-meta">'+badgeHtml(p)+'<span class="pill">'+esc(p.l2||'')+'</span>'+stars5(p.exp)
      + (p.tier==='S'?'<span class="pill tier-s">S 档</span>':p.tier==='A'?'<span class="pill tier-a">A 档</span>':'')
      + risk + '<span class="mono">★ '+p.stars.toLocaleString()+' ｜ '+esc(p.lang||'')+' ｜ '+esc(p.lic||'许可未知')+' ｜ '+when(p.pushed)+'</span></div>'
    + '<div class="lead-cta">点开看详情与「选它因为」→</div>'
    + '</article>';
}
function buildToday(date){
  const today=new Date().toISOString().slice(0,10);
  const day=date||latestPickDay()||today;
  let r=P.filter(function(p){ return String(p.first)===String(day); });
  let notice='', fallback=false;
  if(!r.length){
    r=sorted(P).slice(0,10); fallback=true;
    notice='<div class="picknote">'+(date?('<b>'+esc(date)+'</b> 这天没有新增记录'):'库里还没有任何「新增」记录')
      +'：下面是库里最值得看的 10 个。</div>';
  } else if(!date && day!==today){
    notice='<div class="picknote">最新一天有新增的是 <b>'+esc(day)+'</b>（今天还没有新增）。</div>';
  }
  // 排序：**档位优先**（S→A→B→待评估），再体验分、再 star（"专题报道"的第一条必须是最值得看的 ✓）
  r=r.slice().sort(function(a,b){ return tierRank(a)-tierRank(b) || (b.exp||0)-(a.exp||0) || (b.stars||0)-(a.stars||0); });
  const leadEl=document.getElementById('todayLead');
  if(leadEl) leadEl.innerHTML = leadHtml(r[0], day, fallback);
  const colsEl=document.getElementById('todayTiers');
  if(colsEl){
    const groups={S:[],A:[],B:[],other:[]};
    r.slice(1).forEach(function(p){ const k=(p.tier==='S'||p.tier==='A'||p.tier==='B')?p.tier:'other'; groups[k].push(p); });
    const label={S:'S 档 · 最值得看',A:'A 档 · 值得收藏',B:'B 档 · 合格',other:'待评估 / 其他'};
    colsEl.innerHTML=['S','A','B','other'].map(function(k){
      const g=groups[k];
      return '<div class="tcol"><h4>'+label[k]+' <b class="mono">'+g.length+'</b></h4>'
        + (g.length ? g.map(miniHtml).join('') : '<p class="none">这天没有这一档</p>') + '</div>';
    }).join('');
  }
  // 官方动态：owner_class 校订（P1-2）**还没做** → 库里若确实没有官方条目，就**明说还没校订**，不画假侧栏 ✓
  const offEl=document.getElementById('todayOff');
  if(offEl){
    // ⚠️ 投影里 owner_class 的值是 'official'（不是 'official-bigtech'）——写错会**在页面上谎称"没有官方条目"** ✗（2026-10-16 我自己踩过：库里实际有 8 条 official）
    const off=P.filter(function(p){ return p.oc==='official'; });
    offEl.innerHTML = off.length
      ? '<ul class="offlist">'+off.slice(0,14).map(function(p){
          return '<li><a href="'+repoUrl(p)+'" target="_blank" rel="noopener">'+esc(p.id)+'</a>'
            + (p.ol?'<span class="mono">'+esc(p.ol)+'</span>':'')+'</li>'; }).join('')+'</ul>'
      : '<p class="none">还没有校订过的官方 / 大厂条目 —— 白名单（<code>data/owner-whitelist.json</code>）里命中 0 条（不画假的 ✓）。</p>';
  }
  const noteEl=document.getElementById('todayRow');
  if(noteEl) noteEl.innerHTML = notice;
}// ---------- 我的工作区（用户实例，非官方模板）----------
function buildWorkspaces(){
  const box=document.getElementById('wsGrid');
  if(!box) return;
  if(!WS.length){
    box.innerHTML='<span style="color:var(--dim);font-size:var(--fs-sm)">还没有工作区。工作区 = 「我正在做的一件事 + 它用到的那套工具」。'
      +'让助手建一个（例如「给我建个工作区：B站视频制作」），或跑 tools\\workspace.ps1。也可以先点上面的「按需求组方案」找个模板试试。</span>';
    return;
  }
  box.innerHTML=WS.map(function(w){
    const n=(w.tools||[]).length;
    const done=Array.isArray(w.done)?w.done.length:0;   // 加固：手写 JSONL 把 done 写成对象/字符串时不再崩
    return '<span class="chip" onclick="showWorkspace(\''+esc(String(w.id).replace(/'/g,''))+'\')">'
      +'📌 '+esc(w.name)+' <b style="color:var(--dim);font-weight:400">'+(w.status||'')+(n?(' · '+done+'/'+n):'')+'</b></span>';
  }).join('');
}
function showWorkspace(id){
  const w=WS.filter(function(x){ return String(x.id)===String(id); })[0];
  if(!w) return;
  const done=Array.isArray(w.done)?w.done:[];   // 加固（同上）
  let h='<span class="close" onclick="closePanel()">×</span>'
    +'<h2>📌 '+esc(w.name)+'</h2>'
    +'<div style="color:var(--dim);font-size:var(--fs-sm)">状态：'+esc(w.status||'进行中')+'　｜　建于 '+esc(w.created||'')+'</div>';
  if(w.goal) h+='<div class="hbody" style="margin-top:10px">目标：'+esc(w.goal)+'</div>';
  if(w.note) h+='<div style="color:var(--dim);font-size:var(--fs-sm);margin-top:6px">我的备注：'+esc(w.note)+'</div>';
  const wanted=(w.tools||[]);
  const tools=wanted.map(function(t){ return P.filter(function(p){ return p.id===t; })[0]; }).filter(Boolean);
  const missing=wanted.filter(function(t){ return !P.some(function(p){ return p.id===t; }); });   // B15：不静默丢弃
  h+='<div class="sec-h">这个工作区用到的工具（'+tools.length+' 个）</div>'
    +(missing.length? ('<div class="soon">⚠ 有 '+missing.length+' 个工具在库里找不到（可能已删或名字写错）：'+esc(missing.join('、'))+'</div>') : '');
  if(!tools.length) h+='<div class="todo-box">还没往里加工具。可以在「🧩 按需求组方案」里找一套，然后让助手加进来。</div>';
  else {
    h+='<table class="cmpt"><tr><th>工具</th><th>用它做什么</th></tr>';
    tools.forEach(function(p){
      const isDone=done.indexOf(p.id)>=0;
      h+='<tr><td style="white-space:normal">'+(isDone?'✅ ':'⬜ ')+'<a href="'+repoUrl(p)+'" target="_blank" rel="noopener">'+esc(p.id)+'</a>'
        +'<br><span style="color:var(--dim);font-size:var(--fs-xs)">'+stars5(p.exp)+' ｜ '+esc(p.l2)+'</span></td>'
        +'<td style="white-space:normal">'+esc(oneText(p)||'（待补全）')+'</td></tr>';
    });
    h+='</table>';
  }
  h+='<div class="cmpnote">工作区是你自己的记录，不是官方模板；勾选进度请让助手更新（页面写不了文件）。</div>';
  document.getElementById('panel').innerHTML=h;
  document.getElementById('panel').classList.add('open');
  setHash('#/ws/'+encodeURIComponent(w.id));   // 深链：单个工作区的链接可分享
}
function buildCat(){
  const grid=document.getElementById('catGrid'); let h='';
  // 一级 / 二级 两级分类（二级只在此一级下展示）
  const byL1={};
  P.forEach(p=>{ const k1=p.l1||'未分类', k2=p.l2||'未分类'; if(!byL1[k1]) byL1[k1]={n:0,l2:{}}; byL1[k1].n++; byL1[k1].l2[k2]=(byL1[k1].l2[k2]||0)+1; });   // B9：空分类不再变成字面量 null
  const l1s=Object.keys(byL1).sort((a,b)=>byL1[b].n-byL1[a].n);
  h+='<div class="catbox"><h3>全部</h3><div class="items"><span class="chip '+(f.l1===''?'on':'')+'" onclick="clearAll()">全部工具 <b style="color:var(--dim);font-weight:400">'+P.length+'</b></span></div></div>';
  l1s.forEach(l1=>{
    h+='<div class="catbox"><h3>'+esc(l1)+' <b style="color:var(--dim);font-weight:400">'+byL1[l1].n+'</b></h3><div class="items">';
    h+='<span class="chip '+(f.l1===l1&&!f.l2?'on':'')+'" onclick="setL1(\''+esc(l1)+'\')">全部</span>';
    Object.keys(byL1[l1].l2).sort((a,b)=>byL1[l1].l2[b]-byL1[l1].l2[a]).forEach(l2=>{
      const on = (f.l2===l2) ? 'on' : '';
      h+='<span class="chip '+on+'" onclick="setL2(\''+esc(l2)+'\')">'+esc(l2)+' <b style="color:var(--dim);font-weight:400">'+byL1[l1].l2[l2]+'</b></span>';
    });
    h+='</div></div>';
  });
  // 功能标签云
  const tagCount={};
  P.forEach(p=>(p.ft||[]).forEach(x=>tagCount[x]=(tagCount[x]||0)+1));
  const topTags=Object.keys(tagCount).sort((a,b)=>tagCount[b]-tagCount[a]).slice(0,16);
  if(topTags.length){
    h+='<div class="catbox"><h3>功能标签</h3><div class="items">';
    topTags.forEach(t=>{ h+='<span class="chip '+(f.tag===t?'on':'')+'" onclick="setTag(\''+esc(t)+'\')">'+esc(t)+' <b style="color:var(--dim);font-weight:400">'+tagCount[t]+'</b></span>'; });
    h+='</div></div>';
  }
  grid.innerHTML=h;
}
function detail(id){
  const p=P.find(x=>x.id===id); if(!p) return;
  const evs=(E[id]||[]);
  let human='';
  if(p.one) human+='<div class="sec-h">一句话理解（它是什么）</div><div class="hbody">'+esc(p.one)+'</div>';
  if(p.prob) human+='<div class="sec-h">它解决什么问题</div><div class="hbody">'+esc(p.prob)+'</div>';
  if(p.ex) human+='<div class="sec-h">举个例子</div><div class="hbody">'+esc(p.ex)+'</div>';
  if(p.aud) human+='<div class="sec-h">适合谁</div><div class="hbody">'+esc(p.aud)+'</div>';
  if(p.note) human+='<div class="sec-h">为什么值得留意</div><div class="hbody">'+esc(p.note)+'</div>';
  if(p.hs==='partial') human+='<div class="todo-box">该工具的更多说明<b>待补全</b>：它在 2026-10-13 之前收录，当时没有落盘英文描述。<br>上面两段来自当日台账，是<b>唯一可用素材</b>，未做任何推断。</div>';
  if(p.hs==='missing') human+='<div class="todo-box">该工具<b>暂无介绍素材</b>，仅有仓库名与自动推断的分类。</div>';
  const fnLabels=['是什么','核心功能','常见用途','使用案例','不适合什么场景'];
  let fnHtml=''; (p.fn||[]).forEach((v,i)=>{ if(v) fnHtml+='<div class="fnrow"><b>'+fnLabels[i]+'</b><span>'+esc(v)+'</span></div>'; });
  const fnBlock = fnHtml ? ('<div class="sec-h">📘 功能说明</div>'+fnHtml) : '';
  // 功能备注：多维星级（v3.1 验收要求；**与 star 数无关**）
  let expBlock='';
  if(p.exp!==null && p.part){
    const to5=(v,m)=>((typeof v==='number'&&isFinite(v))?Math.max(1,Math.min(5,Math.round(v/m*5))):null);
    const num=(v,u)=>((typeof v==='number'&&isFinite(v))?(v+u):'暂无数据');   // B4：缺键不再显示 undefined
    const easeMap={'开箱即用':5,'轻配置':4,'要编程':2,'要部署':1};
    const easeTag=(p.t&&p.t[4])||'';
    const dims=[
      ['上手难度', easeMap[easeTag]||null, easeTag?('按分类标签「'+easeTag+'」折算'):'分类标签未定'],
      ['本地运行难度', to5(p.part['易用性'],30), num(p.part['易用性'],'/30')],
      ['文档质量', to5(p.part['文档完整度'],20), num(p.part['文档完整度'],'/20')],
      ['功能成熟度', to5(p.part['功能成熟度'],20), num(p.part['功能成熟度'],'/20')],
      ['活跃程度', to5(p.part['维护活跃'],15), num(p.part['维护活跃'],'/15')],
      ['推荐程度', p.exp, p.expSc+'/100 综合']
    ];
    expBlock='<div class="sec-h">📊 功能备注（多维评分）</div>';
    dims.forEach(d=>{
      if(d[1]===null||d[1]===undefined) return;
      expBlock+='<div class="fnrow"><b>'+d[0]+'</b><span>'+stars5(d[1])+' <span style="color:var(--dim);font-size:var(--fs-xs)">'+d[2]+'</span></span></div>';
    });
    expBlock+='<div class="todo-box" style="background:var(--surface-3);border-color:var(--line);color:var(--dim)">评分构成：易用性 30 ｜ 文档完整 20 ｜ 功能成熟 20 ｜ 维护活跃 15 ｜ 风险 15（满分 100）。<b>不看 star 数</b>——500 star 但装上就能用的工具可以五星，5 万 star 但要配半天环境的只能三星。</div>';
  } else {
    expBlock='<div class="sec-h">📊 功能备注（多维评分）</div><div class="todo-box">信息不足，<b>暂不评分</b>。资料完整后会补上。</div>';
  }
  const tags=(p.ft||[]).map(x=>'<span class="pill pill-fn">'+esc(x)+'</span>').join('');
  const rows=DIMS.map((d,i)=>'<div><b>'+d+'</b>'+esc(p.t[i])+'</div>').join('');
  const evHtml=evs.length? evs.map(e=>'<div class="ev"><time>'+e.d+'</time><span><b>'+esc(e.t)+'</b> '+esc(e.x)+'</span></div>').join('') : '<div class="ev">暂无事件记录</div>';
  document.getElementById('panel').innerHTML='<span class="close" onclick="closePanel()">×</span>'
    +'<h2>'+esc(p.id)+'</h2>'
    +'<div style="margin:6px 0 2px">'+stars5(p.exp)+'　<span class="pill pill-fn">'+esc(p.l1)+' / '+esc(p.l2)+'</span>'
      +((p.tier==='S'||p.tier==='A')?('　<span class="pill tier-'+p.tier+'">'+p.tier+' 档推荐</span>'):(p.tier==='dropped'?'　<span class="pill s-dropped">D 档</span>':'　<span class="pill tier-unrated">D 档</span>'))
      +'</div>'
    +human
    +fnBlock
    +expBlock
    +(tags?('<div class="sec-h">🏷 功能与搜索词</div><div style="display:flex;gap:5px;flex-wrap:wrap">'+tags+'</div>'):'')
    +'<div class="sec-h">📈 成长记录</div>'+evHtml
    +'<div class="sec-h">🔧 详细信息</div><div class="kv">'
    +'<div><b>英文描述</b>'+esc(p.desc||'（未落盘）')+'</div>'
    +'<div><b>星数</b>'+p.stars.toLocaleString()+'　<b>语言</b>'+esc(p.lang||'—')+'</div>'
    +'<div><b>许可</b>'+esc(p.lic||'未知（历史数据缺失）')+'</div>'
    +'<div><b>最近提交</b>'+when(p.pushed)+'　<b>首次收录</b>'+p.first+'</div>'
    +'<div><b>来源</b>'+esc(p.oder||'自动发现')+'　<b>推荐</b>'+(p.rec?(p.tier+' 档 ｜ '+p.rc+' 次'):((p.rc>0)?('历史推荐 '+p.rc+' 次'):'未推荐'))+'</div>'
    +((p.dr)?('<div><b>D 档原因</b><span style="color:var(--danger)">'+esc(p.dr)+'</span></div>'):'')
    +'<div><b>台账备注</b>'+esc(p.note||'—')+'</div>'
    +((p.un&&p.un.filter(x=>x).length)?('<div><b>用户备注</b>'+p.un.filter(x=>x).map(x=>'【'+(x.date||'')+'】'+esc(x.note||'')).join('；')+'</div>'):'')
    +'<div><b>事件数</b>'+evCount(p)+' 条</div>'
    +rows+'</div>'
    +'<div class="kv"><a href="'+repoUrl(p)+'" target="_blank" rel="noopener">在 GitHub 打开 ↗</a></div>';
  document.getElementById('panel').classList.add('open');
  setHash(detailLink(p.id));   // 深链：地址栏变成 #/p/owner/repo（复制即分享；后退 = 回上一个集合）
}
// ================= hash 路由（P2-9）=================
// 为什么是 hash：`#/xxx` 在 file:// 下前进/后退/刷新/收藏都可靠，且**不依赖 pushState 的版本差异**。
// ⚠️ 旧注释「history.pushState 在 file:// 会抛 SecurityError」已被**真机实测推翻**：
//    2026-10-16 Edge 155 headless：只改 hash 的 pushState({},'','#/x') **不抛**（换路径未实测）。
//    hash 路由的收益与本条无关，所以维持只用 hash，但注释不能再写错的前提 ✓
// 设计约束：**不删功能，只搬家** —— detail/showCompare/toggleGroup/addGap/showPlan/
// buildWorkspaces/showWorkspace 全部保留原名原行为（check-page.js 的安全网）✓
const VIEWS=['home','picks','all','plans','site'];
const VIEW_LABEL={home:'① 总览',picks:'② 发现',all:'③ 全库',plans:'④ 方案与工作区',site:'⑤ 档案站'};
let curView='';          // 当前一级区（图例抽屉打开时**不改变**它）
let legendReturn='';     // 打开图例前的 hash，关闭时回退
let lastAllQuery='';     // 离开全库时记住筛选，从详情返回时还原

function getHash(){
  // 非浏览器环境（check-page.js 的极简 DOM 桩）没有 location → 返回空，页面照常初始化 ✓
  try{ return (typeof location!=='undefined' && location.hash) ? String(location.hash) : ''; }catch(e){ return ''; }
}
function setHash(h){
  const nx=(String(h||'').charAt(0)==='#')?String(h):('#'+String(h||''));
  if(getHash()===nx) return false;
  try{ if(typeof location!=='undefined'){ location.hash=nx; return true; } }catch(e){}
  return false;
}
function parseHash(){
  let raw=getHash().replace(/^#\/?/,'');
  let qs='';
  const qi=raw.indexOf('?');
  if(qi>=0){ qs=raw.slice(qi+1); raw=raw.slice(0,qi); }
  const seg=raw.split('/').filter(function(x){ return x!==''; });
  const out={name:'home', seg:seg, query:qs};
  if(!seg.length) return out;
  if(seg[0]==='p' && seg.length>=2){ out.name='p'; out.id=seg.slice(1).join('/'); return out; }
  if(VIEWS.indexOf(seg[0])>=0){ out.name=seg[0]; return out; }
  if(seg[0]==='legend'){ out.name='legend'; return out; }
  if(seg[0]==='ws' && seg.length>=2){ out.name='ws'; out.id=seg[1]; return out; }
  return out;   // 认不出的路由 → 回总览（不白屏、不抛错）
}
function dec(s){ try{ return decodeURIComponent(String(s||'')); }catch(e){ return String(s||''); } }
function qsMap(qs){
  const g={};
  String(qs||'').split('&').forEach(function(kv){
    if(!kv) return;
    const i=kv.indexOf('=');
    const k=i<0?kv:kv.slice(0,i);
    g[k]=i<0?'':dec(kv.slice(i+1));
  });
  return g;
}
// 筛选状态 → 查询串（写进 hash 才能分享、才能用后退撤销）
function filterQuery(){
  const p=[];
  const add=function(k,v){ if(v!=='' && v!==null && v!==undefined) p.push(k+'='+encodeURIComponent(v)); };
  if(f.l1) add('cat', f.l1+(f.l2?('/'+f.l2):''));
  else if(f.l2) add('sub', f.l2);
  add('tier',f.tier); add('status',f.status); add('risk',f.risk); add('tag',f.tag);
  add('five',f.five); add('active',f.active); add('q',f.q); add('badge',f.badge);
  if(f.sort && f.sort!=='stars') add('sort',f.sort);
  return p.join('&');
}
// 查询串 → 筛选状态。**必须回填控件**：render() 是从控件读 f 的，不回填就被清掉 ✗
function applyQuery(qs){
  const g=qsMap(qs);
  f.l1=''; f.l2=''; f.tag=''; f.tier=''; f.status=''; f.risk=''; f.five=''; f.active=''; f.q=''; f.sort='stars'; f.badge='';
  if(g.cat){ const a=String(g.cat).split('/'); f.l1=a[0]||''; f.l2=a[1]||''; }
  if(g.sub) f.l2=g.sub;
  f.tier=g.tier||''; f.status=g.status||''; f.risk=g.risk||''; f.tag=g.tag||'';
  f.five=g.five||''; f.active=g.active||''; f.q=g.q||''; f.sort=g.sort||'stars'; f.badge=g.badge||'';
  const setV=function(id,v){ const el=document.getElementById(id); if(el) el.value=v; };
  setV('q',f.q); setV('fs',f.status); setV('fr',f.risk); setV('ft',f.tier);
  setV('f5',f.five); setV('fa',f.active); setV('sort',f.sort); setV('fb',f.badge);
}
// 用户显式改筛选后调用：把当前筛选写进地址栏（不做历史去重就会刷屏，setHash 内部已比对）
function syncURL(){
  if(curView!=='all') return;
  const q=filterQuery();
  lastAllQuery=q;
  setHash('#/all'+(q?('?'+q):''));
}
function ensureAllView(){
  if(curView==='all') return;
  const q=filterQuery();
  setHash('#/all'+(q?('?'+q):''));
}
function searchFor(term){
  const el=document.getElementById('q');
  if(el) el.value=term;
  f.q=String(term||'').toLowerCase();
  ensureAllView();     // 在总览区点搜索示例 → 切到全库，否则用户看不到结果
  render();
}
function showView(name){
  curView=name;
  VIEWS.forEach(function(v){
    const el=document.getElementById('view-'+v);
    if(el){ if(v===name) el.classList.add('on'); else el.classList.remove('on'); }
    const nb=document.getElementById('nav-'+v);
    if(nb){ if(v===name) nb.classList.add('on'); else nb.classList.remove('on'); }
  });
  // 排序/状态/风险/档位/评分/活跃度只对「全库」有意义 → 其它区收起（搜索框常驻，设计 §5）
  const tb=document.getElementById('toolbar');
  if(tb){ if(name==='all') tb.classList.remove('off'); else tb.classList.add('off'); }
}
function crumb(parts, note){
  const el=document.getElementById('crumb');
  if(!el) return;
  if((!parts||!parts.length) && !note){ el.classList.remove('on'); el.innerHTML=''; return; }
  el.classList.add('on');
  let h=(parts||[]).map(function(p){
    if(p.href) return '<a onclick="setHash(\''+p.href+'\')">'+esc(p.t)+'</a>';
    return '<b>'+esc(p.t)+'</b>';
  }).join(' <span style="color:var(--dim)">›</span> ');
  if(note) h+='<span style="margin-left:10px">'+esc(note)+'</span> <span class="chip" onclick="clearAll()">清空筛选</span>';
  el.innerHTML=h;
}
function go(name){
  const h='#/'+name;
  if(getHash()===h){ route(); return; }
  if(!setHash(h)) route();     // 极端环境（拿不到 location）也要能用
}
// 关掉图例后该回到哪：[ 优先用打开前的真实 URL（含筛选）→ 否则按当前区兜底 ]
// 兜底是必需的：直接打开 `#/legend`（分享链接 / 刷新）时没有"打开前"的 URL，
// 而 route() 处理 legend 时**不改变** curView，所以 curView 仍是要回去的那一区 ✓
function legendBackHash(){
  if(curView==='all') return '#/all'+(lastAllQuery?('?'+lastAllQuery):'');
  return curView?('#/'+curView):'#/home';
}
function openLegend(){
  const h=getHash();
  if(!legendReturn) legendReturn=(h && h!=='#/legend')?h:legendBackHash();
  const el=document.getElementById('legend'); if(el) el.classList.add('open');
  const nb=document.getElementById('nav-legend'); if(nb) nb.classList.add('on');
  setHash('#/legend');
}
// E-2（2026-10-17）：**不新增历史记录**地改 hash —— 关抽屉专用。
// 为什么：抽屉是叠加层（设计 §1「不改变所在区」），原来关闭走 pushState ⇒ 历史里多一条，
// 按一次「后退」抽屉又弹回来 ✗。file:// 下 hash-only 的 replaceState 实测可用；不可用则回落到 setHash ✓
function replaceHash(h){
  const nx=(String(h||'').charAt(0)==='#')?String(h):('#'+String(h||''));
  if(getHash()===nx) return false;
  try{ if(typeof history!=='undefined' && history.replaceState){ history.replaceState(null,'',nx); return true; } }catch(e){}
  return setHash(nx);
}function closeLegend(){
  const el=document.getElementById('legend'); if(el) el.classList.remove('open');
  const nb=document.getElementById('nav-legend'); if(nb) nb.classList.remove('on');
  if(getHash()==='#/legend'){
    const back=legendReturn||'#/home';
    legendReturn='';
    replaceHash(back);   // E-2：关抽屉不新增历史记录 ✓             // 回到打开图例前的那一区（叠加层，不改变区）
  }
}
// 深链：由 detail/showPlan/showWorkspace **自身**写 hash。
// 为什么不另起 openDetail/openPlan 包装：check-page.js 的安全网是按 `detail('…')` /
// `showPlan('…')` 字面抓的（⑦⑨ 两项），改名等于自己拆网（设计 §7：优先保留原名原行为）。
function detailLink(id){ return '#/p/'+String(id).split('/').map(encodeURIComponent).join('/'); }
function closePanel(){
  const p=document.getElementById('panel'); if(p) p.classList.remove('open');
  const h=getHash();
  if(h.indexOf('#/p/')===0) setHash('#/all'+(lastAllQuery?('?'+lastAllQuery):''));
  else if(h.indexOf('#/plans/')===0 || h.indexOf('#/ws/')===0) setHash('#/plans');
}
function route(){
  const r=parseHash();
  if(r.name==='legend'){
    // 真实浏览器实测（2026-10-17，Edge headless）：直接打开 `#/legend` 时 curView 还是空，
    // 四个 `.view` 全部 display:none → **抽屉背后白屏**。所以先垫一个区，再开抽屉 ✓
    // 已经有区时不动它 —— 设计 §2 要求「打开图例不改变当前区」✓
    if(!curView) showView('home');
    openLegend();
    return;
  }
  const le=document.getElementById('legend'); if(le) le.classList.remove('open');
  const nlg=document.getElementById('nav-legend'); if(nlg) nlg.classList.remove('on');
  let v='home';
  if(r.name==='p'||r.name==='all') v='all';
  else if(r.name==='picks') v='picks';
  else if(r.name==='plans'||r.name==='ws') v='plans';
  else if(r.name==='site') v='site';
  showView(v);
  if(r.name==='all'){
    applyQuery(r.query);
    lastAllQuery=r.query||'';
    const cp=[{t:'全库',href:'#/all'}];
    if(f.l1) cp.push(f.l2?{t:f.l1,href:'#/all?cat='+encodeURIComponent(f.l1)}:{t:f.l1});
    if(f.l2) cp.push({t:f.l2});
    const sel=[f.tier&&('档位 '+f.tier), f.status&&('状态 '+f.status), f.risk&&('风险 '+f.risk),
      f.tag&&('标签 '+f.tag), f.five&&('评分筛选'), f.active&&('活跃 '+f.active+' 天'), f.q&&('搜索「'+f.q+'」')].filter(Boolean);
    crumb(cp, sel.length?('已选：'+sel.join(' × ')):'');
    buildCat(); render();
  } else if(r.name==='picks'){
    crumb([]);
    buildToday(dec(r.seg[1]||''));
  } else if(r.name==='p'){
    // 详情深链：**保留**内存里的筛选（返回时用 lastAllQuery 还原）
    buildCat(); render();
    crumb([{t:'全库',href:'#/all'+(lastAllQuery?('?'+lastAllQuery):'')},{t:r.id}]);
    detail(dec(r.id));
  } else if(r.name==='plans'){
    crumb([]);
    if(r.seg[1]) showPlan(dec(r.seg[1]));
  } else if(r.name==='ws'){
    crumb([{t:'方案与工作区',href:'#/plans'},{t:'我的工作区'}]);
    showWorkspace(dec(r.id));
  } else {
    crumb([]);
  }
  try{ document.title='我的开源工具库 · '+VIEW_LABEL[v]+(r.name==='p'?(' · '+r.id):''); }catch(e){}
}
try{ if(typeof window!=='undefined' && window.addEventListener) window.addEventListener('hashchange', route); }catch(e){}
document.addEventListener('keydown',e=>{
  if(e.key==='/' && document.activeElement!==document.getElementById('q')){ e.preventDefault(); document.getElementById('q').focus(); }
  if(e.key==='Escape'){
    // 先关叠加层（图例），再关详情面板 —— 与「Esc 回到上一个集合」一致
    const lg=document.getElementById('legend');
    if(lg && lg.classList.contains('open')){ closeLegend(); return; }
    closePanel(); clearCmp();
  }
});
buildToday(); buildPlans(); buildWorkspaces(); buildCat(); loadGaps(); render(); renderCmpBar();
// 批次 6（2026-10-16 用户实测报障）：封面 `#hero` 已从"可关闭的引导横幅"升级为**首页主体**
//（刊头 ARCHIVE INDEX + 入口 chips），**不再允许收起** ✗。历史遗留的 `dsh-lib-hero=off` 必须**清掉** ——
// 否则点过"收起"的用户会**永久看不到封面**（localStorage 在 file:// 下按源持久保存，这就是"总览上方少一块"的真因）。
try{ if(localStorage.getItem('dsh-lib-hero')==='off'){ localStorage.removeItem('dsh-lib-hero'); } }catch(e){}
// 路由必须在首次 render 之后：route() 会按 hash 覆盖筛选状态并重渲染（刷新保持当前视图 ✓）
try{ route(); }catch(err){ if(typeof console!=='undefined' && console.error) console.error('路由初始化失败（页面其余功能不受影响）', err); }
