# build-overview.ps1 — 生成 overview.html（「我的开源工具库」）
#
# 设计（按 2026-10-13 产品决策）：
#   1. **单文件、全部内嵌**：双击即可用，不需要服务器、不需要 Python、不需要任何参数。
#      因此详情数据不再外部 fetch（file:// 下会被浏览器拦）。
#   2. **首页不是日报**：三个入口 —— 今日新增 / 分类浏览 / 搜索工具。
#   3. **小白理解层**：一句话 / 它解决什么 / 比如 / 功能 / 适合谁 / 不适合谁。
#   4. **使用体验五星**：独立于 S/A/B 推荐档，不看 star 数。
#   5. **两级分类**：一级（AI/设计/效率/开发/学习/数据/安全/运维/其他）+ 二级。
#
# 依赖：data/projects.jsonl（由 sync-projects.ps1 生成）
# 用法：& ".\tools\build-overview.ps1"

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$projPath = P 'data\projects.jsonl'
if (-not (Test-Path $projPath)) {
  Write-Host "找不到 data\projects.jsonl，请先运行：& `".\tools\sync-projects.ps1`"" -ForegroundColor Red
  exit 1
}

# ---------- 读数据：**全部内嵌**（含详情），不再外部加载 ----------
$rows = @()
# N-01（v5.1.0 测试发现 / P1）：projects.jsonl 里出现一行字面量 null 时，
# P 数组会含 null 项 → 页面排序读 null.localeCompare 直接崩（整个脚本停摆）。
# null 是**合法 JSON**，所以 audit 第 19 节'每行可解析'拦不住 —— 必须在生成端过滤。
$rows = @($rows | Where-Object { $_ })
foreach ($l in Get-Content $projPath -Encoding UTF8) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try {
    $p = $l | ConvertFrom-Json
    # N-01（v5.1.0 测试发现 / P1）：一行字面量 null 会让 $p = $null，而 PowerShell 里
    # $null.human / $null.id **不报错**（返回 $null）→ 照样生成一条 id=null 的全空记录（实测 144 条），
    # 页面对 id 排序时 localeCompare 读到 null 直接抛 TypeError，整个 <script> 停摆。
    # null 是合法 JSON，audit「每行可解析」拦不住 → 必须在源头跳过。
    if (-not $p -or -not $p.id) { continue }
    $h = $p.human
    # 无人话层时用**空数组**，不要用 @($null,$null,...) 占位——序列化会变成 [null,null,...]，
    # 既白占体积，也是「数组里混 null」这类前端坑的源头（2026-10-13 事故同类）。
    $fn = @()
    if ($h -and $h.feature_note) {
      $fn = @(
        "$($h.feature_note.'是什么')",
        (@($h.feature_note.'核心功能') -join '；'),
        (@($h.feature_note.'常见用途') -join '；'),
        (@($h.feature_note.'使用案例') -join '；'),
        (@($h.feature_note.'不适合') -join '；')
      )
    }
    # **不要写 @($p.user_notes)**：若该字段为 null，@($null) 会得到「含一个 null 的数组」，
    # 序列化成 [null] 后前端 .map(x=>x.date) 直接抛 TypeError，表现为「卡片点了没反应」。
    # 必须显式过滤掉 null 元素。function_tags 同理。
    $unArr = @()
    if ($p.user_notes) { $unArr = @($p.user_notes | Where-Object { $_ -ne $null }) }
    $ftArr = @()
    if ($p.function_tags) { $ftArr = @($p.function_tags | Where-Object { $_ -ne $null }) }

    $rows += [pscustomobject][ordered]@{
      id     = $p.id
      # url 不内嵌：前端用 'https://github.com/' + id 拼回。3650 项时约省 42 B/条。
      # desc 不内嵌：有人话层时用中文一句话，没有时才回退（见页面 oneText）。
      desc   = if ($h -and $h.one_liner) { $null } else { $p.description }
      lic    = $p.license
      lang   = $p.language
      stars  = [int]$p.stars.current
      d7     = [int]$p.stars.delta_7d
      dtot   = [int]$p.stars.delta_total
      pushed = $p.pushed_at
      first  = $p.first_seen
      last   = $p.last_seen
      rec    = [bool]$p.recommended
      rc     = [int]$p.recommend_count
      tier   = $p.tier
      risk   = $p.risk
      status = $p.status
      origin = $p.origin
      oder   = $p.origin_note
      l1     = $p.category.l1
      l2     = $p.category.l2
      exp    = $p.experience.stars          # 体验五星（可能为 null）
      expSc  = $p.experience.score
      part   = $p.experience.parts
      t      = @($p.tags.'领域', $p.tags.'形态', $p.tags.'用途', $p.tags.'成熟度', $p.tags.'上手难度', $p.tags.'风险等级')
      hs     = if ($h) { $h.status } else { 'missing' }
      one    = if ($h) { $h.one_liner } else { $null }
      # v3.1 验收要求「它解决什么问题」与「比如」必须可见，故重新内嵌（约 +60 B/条）
      prob   = if ($h) { $h.problem } else { $null }
      ex     = if ($h) { $h.example } else { $null }
      # 体积控制：prob / ex / uk / extra 只服务详情面板，单文件内嵌时**不内嵌**，
      # 改由 one + note 承担解释职责（见页面 renderDetail）。3650 项时约省 86 B/条。
      fn     = $fn
      ft     = $ftArr
      evc    = [int]$p.events_count
      note   = $p.note
      un     = $unArr
    }
  } catch { Write-Warning "跳过损坏行" }
}

# ---------- 事件：按项目归组（内嵌，详情里的"成长记录"用）----------
$evMap = @{}
$evPath = P 'data\events.jsonl'
if (Test-Path $evPath) {
  foreach ($l in Get-Content $evPath -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try {
      $e = $l | ConvertFrom-Json
      if (-not $evMap.ContainsKey($e.id)) { $evMap[$e.id] = @() }
      $evMap[$e.id] += [pscustomobject]@{ d = $e.date; t = $e.type; x = $e.detail }
    } catch {}
  }
}

# N-01（v5.1.0 测试发现 / P1）：projects.jsonl 若含一行字面量 null，P 数组会带 null 项 →
# 页面排序读 null.localeCompare 直接崩（整个 <script> 停摆）。null 是合法 JSON，
# 所以 audit「每行可解析」拦不住 —— 必须在生成端过滤。（第一次插在 $rows=@() 后面 = 无效，已修）
$rows = @($rows | Where-Object { $_ })
$json = $rows | ConvertTo-Json -Depth 6 -Compress

# 空库兜底（Bug 测试报告 B1 / P0）：0 条时管道不产出任何内容 → 页面变成 const P = ;
# 那是语法错误，会让整个 <script> 失效（白屏）。原来只兜了「1 条」（下一行），漏了「0 条」——
# $plansJson / $wsJson 一直有兜底，只有 P 没有。
if ($rows.Count -eq 0) { $json = '[]' }
if ($rows.Count -eq 1) { $json = "[$json]" }
$evJson = @{}
foreach ($k in $evMap.Keys) { $evJson[$k] = @($evMap[$k] | Sort-Object d -Descending) }
$evJsonStr = if ($evMap.Count) { $evJson | ConvertTo-Json -Depth 5 -Compress } else { '{}' }

# ---------- 方案模板（v3.1 第八节）：选场景 → 页面直接给工具组合 ----------
# 角色与「为什么需要这一步」是人工写的一次性内容（data/plans.json）；
# 具体填哪个工具由页面**按 l2/ft 从本地库自动匹配**——数据驱动，不编造。
$plansJson = '[]'
$plansPath = P 'data\plans.json'
if (Test-Path $plansPath) {
  try {
    $pj = Get-Content $plansPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plansJson = ConvertTo-Json -InputObject @($pj.plans) -Depth 8 -Compress
  } catch { Write-Warning "plans.json 解析失败，方案区将为空：$($_.Exception.Message)" }
}
if (-not $plansJson -or $plansJson -eq 'null') { $plansJson = '[]' }
# ---------- 同义词表（data/human/search-synonyms.jsonl）**必须内嵌进页面** ----------
# Bug 测试报告 B2（P1）：这份表原来只有 suggest-terms/gaps 当"已收录词"用，
# **搜索和分类都没读它** —— 于是搜索框里写的示例词（画图/做PPT/替代PS…）全部 0 命中。
$synJson = '[]'
$synPath = P 'data\human\search-synonyms.jsonl'
if (Test-Path $synPath) {
  try {
    $sl = @()
    foreach ($l in (Get-Content $synPath -Encoding UTF8)) { if ($l.Trim()) { $sl += ($l | ConvertFrom-Json) } }
    if ($sl.Count) { $synJson = ConvertTo-Json -InputObject @($sl) -Depth 4 -Compress }
  } catch { Write-Warning "search-synonyms.jsonl 解析失败：$($_.Exception.Message)" }
}
if (-not $synJson) { $synJson = '[]' }

# ---------- 我的工作区（data/workspaces.jsonl）：**用户实例**，与 plans.json（官方模板）分开 ----------
# 分工：plans.json = 「AI 视频该怎么做」的官方模板；workspaces.jsonl = 「我的 B 站视频工作区，进行中」。
# 两者结构相似但语义不同：模板不可变、工作区由用户增删改。
$wsJson = '[]'
$wsPath = P 'data\workspaces.jsonl'
if (Test-Path $wsPath) {
  try {
    $wsl = @()
    foreach ($l in (Get-Content $wsPath -Encoding UTF8)) {
      if ([string]::IsNullOrWhiteSpace($l)) { continue }
      try { $wsl += ($l | ConvertFrom-Json) } catch {}
    }
    if ($wsl.Count) { $wsJson = ConvertTo-Json -InputObject @($wsl) -Depth 8 -Compress }
  } catch { Write-Warning "workspaces.jsonl 解析失败：$($_.Exception.Message)" }
}
if (-not $wsJson) { $wsJson = '[]' }

# ---------- 统计 ----------
$genTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$today   = (Get-Date).ToString('yyyy-MM-dd')
$totalN  = $rows.Count
$recN    = ($rows | Where-Object { $_.rec }).Count
$savedN  = ($rows | Where-Object { $_.status -eq 'saved' }).Count
$descN   = ($rows | Where-Object { $_.desc -or $_.one }).Count
$ratedN  = ($rows | Where-Object { $null -ne $_.exp }).Count
$todayNew= ($rows | Where-Object { $_.first -eq $today }).Count
# 一级分类（按数量排序，只保留非空）
$l1Groups = $rows | Group-Object { $_.l1 } | Sort-Object Count -Descending
# 近 7 天有提交的
$recentN = ($rows | Where-Object { $_.pushed -and (([datetime]::Now) - [datetime]$_.pushed).Days -le 7 }).Count

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>我的开源工具库</title>
<style>
:root{--bg:#0e1014;--panel:#151922;--card:#1a1f29;--line:#262c37;--fg:#e7e9ee;--dim:#98a2b3;--acc:#4f8cff;--gold:#e8b93a}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.6 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif}
a{color:var(--acc);text-decoration:none}
header{padding:16px 22px 12px;border-bottom:1px solid var(--line);position:sticky;top:0;background:rgba(14,16,20,.97);backdrop-filter:blur(8px);z-index:9}
h1{margin:0 0 4px;font-size:19px;display:flex;align-items:center;gap:10px;flex-wrap:wrap}
h1 small{font-weight:400;color:var(--dim);font-size:12px}
#q{width:100%;background:var(--panel);color:var(--fg);border:1px solid var(--line);border-radius:10px;padding:12px 15px;font-size:14.5px;margin-top:9px}
#q:focus{outline:none;border-color:var(--acc)}
.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin-top:9px;align-items:center}
select{background:var(--panel);color:var(--fg);border:1px solid var(--line);border-radius:8px;padding:6px 9px;font-size:12.5px}
.chip{cursor:pointer;border:1px solid var(--line);border-radius:999px;padding:4px 12px;font-size:12.5px;color:var(--dim);background:var(--panel);display:inline-block}
.chip:hover{border-color:var(--acc);color:var(--fg)}
.chip.on{background:#243149;border-color:var(--acc);color:#cfe0ff}
.wrap{padding:16px 22px 30px;max-width:1560px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(126px,1fr));gap:10px;margin-bottom:16px}
.stat{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:11px 13px;cursor:pointer}
.stat:hover{border-color:#3c4a63}
.stat b{display:block;font-size:21px;line-height:1.25}
.stat span{color:var(--dim);font-size:12px}
section{margin-bottom:20px}
h2{font-size:14.5px;margin:0 0 10px;display:flex;align-items:center;gap:8px}
h2 em{font-style:normal;color:var(--dim);font-weight:400;font-size:12px}
.row-scroll{display:flex;gap:9px;overflow-x:auto;padding-bottom:5px}
.mini{flex:0 0 218px;background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px;cursor:pointer}
.mini:hover{border-color:#3c4a63}
.mini .n{font-size:13px;font-weight:600;margin-bottom:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.mini .d{color:var(--dim);font-size:11.5px;height:32px;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical}
.mini .m{color:var(--dim);font-size:11px;margin-top:6px;display:flex;justify-content:space-between}
.catgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:9px}
.catbox{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:11px 13px}
.catbox h3{margin:0 0 8px;font-size:13px;color:var(--fg);font-weight:600}
.catbox .items{display:flex;flex-wrap:wrap;gap:5px}
#list{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(350px,1fr))}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:13px;cursor:pointer}
.card:hover{border-color:#3c4a63}
.card h3{margin:0 0 7px;font-size:14.5px;display:flex;gap:7px;align-items:center;flex-wrap:wrap}
.card h3 a{color:var(--fg)}
.card h3 a:hover{color:var(--acc)}
.stars5{color:var(--gold);font-size:13px;letter-spacing:1px}
.stars5 small{color:var(--dim);font-size:11px;letter-spacing:0}
.one{color:var(--fg);font-size:13px;margin:0 0 8px;min-height:36px;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;opacity:.92}
.one.none{color:var(--dim);font-style:italic}
/* 待补全的条目：**不隐藏、但降低视觉权重**（GPT 建议）——让库看起来还在长，而不是"就这么点东西" */
.card.thin{opacity:.82;border-style:dashed}
.card.thin:hover{opacity:1}
.soon{font-size:11.5px;color:#ffd88a;border-left:2px solid #8a6d3a;padding-left:7px;margin:0 0 8px}
.pill{border-radius:999px;padding:1px 8px;font-size:11px;border:1px solid var(--line);color:var(--dim);white-space:nowrap}
.pill-fn{border-color:#3a5f8a;color:#9cc4ff}
.pill-todo{border-color:#8a6d3a;color:#ffd88a}
.tier-S,.r-low{border-color:#2e7d5b;color:#7ee2b8}
.tier-A{border-color:#3a5f8a;color:#9cc4ff}
.tier-unrated{border-color:#6a4f8a;color:#c9a9f5}
.r-mid{border-color:#8a6d3a;color:#ffd88a}
.r-high{border-color:#8a3a3a;color:#ff9d9d}
.s-saved{border-color:#4f8cff;color:#9cc4ff}
.s-using{border-color:#2f8f5b;color:#8ee7b0}
.s-watching{border-color:#8a6d3a;color:#ffd88a}
.s-researching{border-color:#6a4f8a;color:#c9a9f5}
.s-dropped{border-color:#8a3a3a;color:#ff9d9d}
.meta{color:var(--dim);font-size:11.5px;margin-top:7px;display:flex;justify-content:space-between;gap:8px}
.empty{grid-column:1/-1;text-align:center;color:var(--dim);padding:50px}
#panel{position:fixed;inset:0 0 0 auto;width:min(660px,95vw);background:var(--panel);border-left:1px solid var(--line);padding:22px;overflow:auto;transform:translateX(105%);transition:transform .18s;z-index:20;box-shadow:-20px 0 40px rgba(0,0,0,.45)}
#panel.open{transform:none}
#panel h2{margin:0 0 6px;font-size:19px;display:block}
#panel .close{position:absolute;top:14px;right:16px;cursor:pointer;color:var(--dim);font-size:22px;line-height:1}
.sec-h{font-size:12px;color:var(--dim);font-weight:600;margin:16px 0 7px;padding-bottom:5px;border-bottom:1px solid var(--line)}
.hbody{font-size:13.5px;line-height:1.75;background:#1c222c;border-left:3px solid var(--acc);border-radius:0 8px 8px 0;padding:10px 13px;margin-bottom:4px}
.fnrow{display:flex;gap:10px;font-size:13px;margin:6px 0;line-height:1.7}
.fnrow b{color:var(--dim);font-weight:500;min-width:92px;flex:0 0 auto}
.todo-box{background:#2a2418;border:1px solid #5c4a24;border-radius:8px;padding:10px 13px;font-size:12.5px;line-height:1.8;color:#ffd88a;margin-top:10px}
.kv{margin:12px 0;padding-top:10px;border-top:1px solid var(--line)}
.kv div{margin:5px 0;font-size:13px}
.kv b{color:var(--dim);font-weight:500;display:inline-block;min-width:84px}
.ev{font-size:12.5px;margin:4px 0;display:flex;gap:8px}
.ev time{color:var(--dim);white-space:nowrap}
.foot{padding:0 22px 26px;color:var(--dim);font-size:12px;line-height:1.9;max-width:1560px}
code{background:#222733;padding:1px 5px;border-radius:4px;font-size:12px}
/* —— 项目对比（页内，纯前端；数据已内嵌，不调 API）—— */
.cmp{cursor:pointer;border:1px solid var(--line);border-radius:6px;padding:1px 8px;font-size:11px;color:var(--dim);background:transparent;white-space:nowrap;margin-left:auto}
.cmp:hover{border-color:var(--acc);color:var(--fg)}
.cmp.on{background:#243149;border-color:var(--acc);color:#cfe0ff}
#cmpBar{position:fixed;bottom:18px;right:18px;background:var(--panel);border:1px solid var(--acc);border-radius:10px;padding:10px 14px;display:none;gap:10px;align-items:center;z-index:15;box-shadow:0 8px 24px rgba(0,0,0,.45);font-size:12.5px}
#cmpBar.on{display:flex}
table.cmpt{border-collapse:collapse;width:100%;font-size:12.5px;margin-top:8px}
table.cmpt th,table.cmpt td{border:1px solid var(--line);padding:6px 8px;vertical-align:top;text-align:left;line-height:1.6}
table.cmpt th{background:#1c222c;color:var(--dim);font-weight:500;white-space:nowrap}
table.cmpt td:first-child{color:var(--dim);white-space:nowrap;background:#181d26}
.cmpnote{color:var(--dim);font-size:12px;margin-top:8px;line-height:1.7}
.grpNote{grid-column:1/-1;color:var(--dim);font-size:12.5px;line-height:1.7;margin-bottom:2px}
.grpHead{grid-column:1/-1;font-size:13px;font-weight:600;color:var(--fg);border-bottom:1px solid var(--line);padding:6px 0 5px;margin-top:6px}
.grpHead em{font-style:normal;color:var(--dim);font-weight:400;font-size:11.5px;margin-left:7px}
@media(max-width:700px){.wrap{padding:12px}}
</style>
</head>
<body>
<header>
  <h1>🧰 我的开源工具库 <small>共 $totalN 个工具 ｜ 已评分 $ratedN ｜ 近 7 天有更新 $recentN ｜ 生成于 $genTime</small></h1>
  <input id="q" placeholder="想干什么？直接说需求，例如：画图 / 做PPT / 替代PS / 聊天机器人 / 本地运行AI（按 / 聚焦）" oninput="render()">
  <div class="toolbar">
    <select id="sort" onchange="render()">
      <option value="stars">按体验评分</option>
      <option value="gh">按星数</option>
      <option value="recent">按最近提交</option>
      <option value="name">按名称</option>
    </select>
    <select id="fs" onchange="render()">
      <option value="">全部状态</option>
      
      <option value="active">已收录</option>
      <option value="using">正在使用</option>
      <option value="watching">观察中</option>
      <option value="researching">研究中</option>
      <option value="dropped">已放弃</option>
    </select>
    <select id="fr" onchange="render()">
      <option value="">全部风险</option><option>低</option><option>中</option><option>高</option>
    </select>
    <select id="ft" onchange="render()">
      <option value="">全部档位</option><option>S</option><option>A</option><option value="unrated">未评档</option>
    </select>
    <select id="f5" onchange="render()">
      <option value="">全部评分</option>
      <option value="5">五星</option><option value="4">四星以上</option><option value="3">三星以上</option>
      <option value="0">仅未评分</option>
    </select>
    <select id="fa" onchange="render()">
      <option value="">全部活跃度</option>
      <option value="30">30 天内有提交</option>
      <option value="90">90 天内有提交</option>
      <option value="365">一年内有提交</option>
    </select>
    <span class="chip" id="gapChip" style="display:none" onclick="copyGaps()"></span>
    <span class="chip" id="grpBtn" onclick="toggleGroup()">按用途分组</span>
    <span class="chip" id="clear" onclick="clearAll()">清空筛选</span>
  </div>
</header>
<div class="wrap">
  <section id="hero">
    <h2>👋 欢迎来到你的开源工具库 <em>143 个项目 · 11 个工作方案 · 全部本地、双击即用</em></h2>
    <div class="catbox">
      <div class="items">
        <span class="chip" onclick="document.getElementById('q').value='做视频';render();document.getElementById('q').scrollIntoView({block:'center'})">🔍 试试搜「做视频」</span>
        <span class="chip" onclick="document.getElementById('q').value='AI绘画';render()">🔍 搜「AI绘画」</span>
        <span class="chip" onclick="document.getElementById('q').value='找文件';render()">🔍 搜「找文件」</span>
        <span class="chip" onclick="document.getElementById('planGrid').scrollIntoView({behavior:'smooth'})">🧩 按需求组方案</span>
        <span class="chip" onclick="document.getElementById('wsSection').scrollIntoView({behavior:'smooth'})">📌 我的工作区</span>
        <span class="chip" onclick="document.getElementById('catGrid').scrollIntoView({behavior:'smooth'})">🗂 浏览分类</span>
      </div>
    </div>
    <div style="color:var(--dim);font-size:12.5px;margin-top:8px">
      不知道怎么用？<b>在搜索框里直接说你想干什么</b>（例如「我想做一个播客频道」），这里会从你自己的库里配一套工具给你。
      想看整套搭配：点上面的「按需求组方案」。<span class="chip" style="margin-left:6px" onclick="this.closest('section').style.display='none';try{localStorage.setItem('dsh-lib-hero','off')}catch(e){}">知道了，收起</span>
    </div>
  </section>

  <section>
    <h2>🆕 今日新增 <em>每天进货的入口</em></h2>
    <div class="row-scroll" id="todayRow"></div>
  </section>

  <section>
    <h2>🧩 按需求组方案 <em>点一个场景，看这套该怎么配（工具按用途自动匹配，不调 API）</em></h2>
    <div class="catbox"><div class="items" id="planGrid"></div></div>
  </section>

  <section id="wsSection">
    <h2>📌 我的工作区 <em>你正在做的事，和它用到的那套工具</em></h2>
    <div class="catbox"><div class="items" id="wsGrid"></div></div>
  </section>

  <section>
    <h2>🗂 分类浏览 <em>点大类或小类即筛选</em></h2>
    <div class="catgrid" id="catGrid"></div>
  </section>

  <section>
    <h2>📋 全部工具 <em id="countHint"></em></h2>
    <div id="list"></div>
  </section>
</div>
<div id="panel"></div>
<div id="cmpBar"></div>
<div class="foot">
  数据来自 <code>data/projects.jsonl</code> + <code>data/events.jsonl</code>（由原始来源派生，可全量重建）。<b>本页是只读视图，数据已全部内嵌，双击即可用。</b><br>
  改状态：编辑 <code>data/seen.jsonl</code> 的 <code>status</code>（白名单 active/using/watching/researching/dropped；saved 为遗留值）并在 <code>data/status-log.jsonl</code> 追加一行，然后跑 <code>sync-projects.ps1</code> 与 <code>build-overview.ps1</code>。<br>
  改分类：只改 <code>data/taxonomy.json</code>（<b>分类不允许运行时自由创建</b>，新方向先写入 <code>taxonomy-suggestions.json</code> 等人工批准）。
</div>
<script>
const P = $json;
const E = $evJsonStr;
const PLANS = $plansJson;
const SYN = $synJson;   // 同义词组：搜索时按「组内任一命中」算命中
const WS = $wsJson;
const DIMS = ['领域','形态','用途','成熟度','上手难度','风险等级'];
const STA = {active:'已收录',using:'正在使用',watching:'观察中',researching:'研究中',dropped:'已放弃'};   // B14：saved 已废弃，不留死映射
const f = {q:'', sort:'stars', status:'', risk:'', tier:'', five:'', active:'', l1:'', l2:'', tag:''};
let cmpSel = [];   // 对比选择（最多 2 个，页内纯前端）
let groupByUse = false;   // 按用途分组（把结果按二级分类聚合，便于按流程挑组合）

function esc(s){return (s||'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
function repoUrl(p){ return 'https://github.com/' + p.id; }
function when(s){ return s ? String(s).slice(0,10) : '—'; }
function daysAgo(s){ if(!s) return null; const d=new Date(String(s)); if(isNaN(d)) return null; return Math.floor((Date.now()-d)/86400000); }
function stars5(n){ if(n===null||n===undefined) return '<span class="stars5" style="color:var(--dim)">未评分</span>'; return '<span class="stars5">'+'★'.repeat(n)+'☆'.repeat(5-n)+'</span>'; }
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
  const INTENT = /^(我想|我要|帮我|给我|想要|需要一个|需要|寻找|找找|有没有|求|想|要|找)/;
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
  if(f.tier){ if(f.tier==='unrated'){ if(p.tier && p.tier!=='unrated') return false; } else if(p.tier!==f.tier) return false; }
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
function cardHtml(p){
  const flags=[];
  if(p.tier==='S'||p.tier==='A') flags.push('<span class="pill tier-'+p.tier+'">'+p.tier+' 档</span>');
  else if(p.tier==='dropped') flags.push('<span class="pill s-dropped">已淘汰</span>');
  else flags.push('<span class="pill tier-unrated" title="未经日报评档">未评档</span>');
  if(p.risk) flags.push('<span class="pill r-'+(p.risk==='低'?'low':p.risk==='高'?'high':'mid')+'">风险 '+p.risk+'</span>');
  if(p.status!=='active') flags.push('<span class="pill s-'+p.status+'">'+(STA[p.status]||p.status)+'</span>');
  if(p.origin==='user') flags.push('<span class="pill" style="border-color:#6a4f8a;color:#c9a9f5">用户推荐</span>');
  const fts=(p.ft||[]).slice(0,2).map(x=>'<span class="pill pill-fn">'+esc(x)+'</span>').join('');
  const one = oneText(p);
  // 待补全条目**不隐藏、但降低视觉权重**（GPT 建议）：明确标出来，而不是让用户以为"就这么点东西"
  const thin = (p.hs!=='complete');
  // 卡片上没有任何"收藏"元素：收藏功能已整体撤销（用户 2026-10-13 决定：用起来太麻烦繁琐）
  return '<div class="card'+(thin?' thin':'')+'" onclick="detail(\''+p.id+'\')">'
    +'<h3><a href="'+repoUrl(p)+'" target="_blank" rel="noopener" onclick="event.stopPropagation()">'+esc(p.id)+'</a>'
      +'<span class="cmp'+(cmpSel.indexOf(p.id)>=0?' on':'')+'" onclick="toggleCmp(event,\''+p.id+'\')">'+(cmpSel.indexOf(p.id)>=0?'✓ 已选对比':'对比')+'</span></h3>'
    +'<div style="margin-bottom:6px">'+stars5(p.exp)+' <span class="pill">'+esc(p.l2)+'</span></div>'
    +'<p class="one'+(one?'':' none')+'">'+esc(one||'（暂无中文介绍，仅有英文描述或台账备注）')+'</p>'
    +(thin?'<div class="soon">📌 详细介绍待补全 —— 这个库在长，它还没轮到</div>':'')
    +'<div class="row" style="display:flex;gap:5px;flex-wrap:wrap">'+fts+'</div>'
    +'<div class="row" style="display:flex;gap:5px;flex-wrap:wrap;margin-top:6px">'+flags.join('')+'</div>'
    +'<div class="meta"><span>★ '+p.stars.toLocaleString()+' ｜ '+esc(p.lang||'')+' ｜ '+esc(p.lic||'许可未知')+'</span>'
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
  if(kind==='tier')  return (p.tier==='S'||p.tier==='A')?(p.tier+' 档'):(p.tier==='dropped'?'已淘汰':'未评档');
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
  const h='<span class="close" onclick="document.getElementById(\'panel\').classList.remove(\'open\')">×</span>'
    +'<h2>对比：'+esc(A.id)+' vs '+esc(B.id)+'</h2>'
    +'<div style="color:var(--dim);font-size:12.5px">数据来自本地知识库（页面已内嵌）｜ 未调用任何 API ｜ 缺失标「（待补全）」</div>'
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
    +'<ul style="margin:4px 0 0;padding-left:20px;font-size:13px;line-height:1.8">'+cmpSuggest(A,B).map(x=>'<li>'+x+'</li>').join('')+'</ul>'
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
  if(good.length) out+='<span style="color:#7ee2b8">✅ '+good.map(esc).join(' ｜ ')+'</span>';
  if(bad.length) out+=(out?'<br>':'')+'<span style="color:#ffd88a">⚠️ '+bad.map(esc).join(' ｜ ')+'</span>';
  return out || '<span style="color:var(--dim)">资料不足，暂无法判断</span>';
}
function planRoleAll(role){
  // 该角色一共能匹配到多少个（用于「查看全部 N 个同类工具 →」）
  return planRoleTools(role, 999).length;
}
function showL2(l2){
  f.l2=l2; f.l1=''; f.q='';
  document.getElementById('q').value='';
  document.getElementById('panel').classList.remove('open');
  buildCat(); render();
  window.scrollTo({top:document.body.scrollHeight,behavior:'smooth'});
}
function buildPlans(){
  const box=document.getElementById('planGrid');
  if(!box) return;
  if(!PLANS.length){ box.innerHTML='<span style="color:var(--dim);font-size:12.5px">没有方案模板（data/plans.json）</span>'; return; }
  box.innerHTML=PLANS.map(function(pl){ return '<span class="chip" onclick="showPlan(\''+pl.id+'\')">'+esc(pl.name)+'</span>'; }).join('');
}
function showPlan(id){
  const pl=PLANS.filter(function(x){ return x.id===id; })[0];
  if(!pl) return;
  let h='<span class="close" onclick="document.getElementById(\'panel\').classList.remove(\'open\')">×</span>'
    +'<h2>🧩 '+esc(pl.name)+'</h2>'
    +'<div style="color:var(--dim);font-size:12.5px">工具来自你的本地库，按用途自动匹配 ｜ 未调用 API ｜ <b>步骤顺序由你决定</b></div>';
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
  h+='<div style="color:var(--dim);font-size:12.5px;margin-top:8px">这套要 <b>'+roleN+'</b> 步'
    +(pl.roles||[]).map(function(r,i){return '　'+(i+1)+'. '+esc(r.role);}).join('')+diff+'</div>';
  (pl.roles||[]).forEach(function(r,i){
    const tools=planRoleTools(r,2);
    const allN=planRoleAll(r);
    h+='<div class="sec-h">'+(i+1)+'. '+esc(r.role)+'</div>';
    h+='<div style="color:var(--dim);font-size:12.5px;margin-bottom:6px">为什么需要这一步：'+esc(r.why)+'</div>';
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
        +'<br><span style="color:var(--dim);font-size:11.5px">'+stars5(p.exp)+' ｜ '+label+'</span>'
        +'<br><span class="cmp" style="margin-left:0" onclick="detail(\''+p.id+'\')">看详情</span></td>'
        +'<td style="white-space:normal"><div>'+esc(oneText(p)||'（待补全）')+'</div>'
        +'<div style="font-size:11.5px;margin-top:5px;line-height:1.7">'+planWhyPick(p)+'</div></td></tr>';
    });
    h+='</table>';
    if(allN>tools.length && r.l2 && r.l2[0]){
      h+='<div style="margin-top:4px"><span class="chip" onclick="showL2(\''+String(r.l2[0])+'\')">查看全部 '+allN+' 个同类工具 →</span></div>';
    }
  });
  h+='<div class="cmpnote">这是「按用途归类」的建议，不构成使用担保；每个工具用前请看它的 License 与最近维护状态。想看两个的差别：在卡片上点「对比」。</div>';
  document.getElementById('panel').innerHTML=h;
  document.getElementById('panel').classList.add('open');
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
      +'<div id="gapHint" style="margin-top:12px;color:var(--dim);font-size:12.5px;line-height:1.8">搜不到？点「记下这个词」存起来，'
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
  list.innerHTML = planHintHtml() + r.map(cardHtml).join('');
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
function quickStatus(s){ f.status=s; document.getElementById('fs').value=s; render(); window.scrollTo({top:document.body.scrollHeight,behavior:'smooth'}); }
function setL1(g){ f.l1=(f.l1===g?'':g); f.l2=''; buildCat(); render(); }
function setL2(g){ f.l2=(f.l2===g?'':g); buildCat(); render(); }
function setTag(t){ f.tag=(f.tag===t?'':t); buildCat(); render(); }
function clearAll(){
  f.q='';f.status='';f.risk='';f.tier='';f.five='';f.active='';f.l1='';f.l2='';f.tag='';
  document.getElementById('q').value='';['fs','fr','ft','f5','fa'].forEach(id=>document.getElementById(id).value='');
  buildCat(); render();
}
function miniHtml(p){
  return '<div class="mini" onclick="detail(\''+p.id+'\')">'
    +'<div class="n">'+esc(p.id)+'</div>'
    +'<div style="margin:2px 0">'+stars5(p.exp)+'</div>'
    +'<div class="d">'+esc(oneText(p)||'（暂无中文介绍）')+'</div>'
    +'<div class="m"><span>★ '+p.stars.toLocaleString()+'</span><span>'+when(p.pushed)+'</span></div></div>';
}
function buildToday(){
  const today=new Date().toISOString().slice(0,10);
  let r=P.filter(p=>p.first===today);
  if(!r.length){ r=sorted(P).slice(0,10); }
  document.getElementById('todayRow').innerHTML = r.length
    ? r.map(miniHtml).join('')
    : '<div style="color:var(--dim);font-size:12.5px">今天没有新增工具</div>';
}
// ---------- 我的工作区（用户实例，非官方模板）----------
function buildWorkspaces(){
  const box=document.getElementById('wsGrid');
  if(!box) return;
  if(!WS.length){
    box.innerHTML='<span style="color:var(--dim);font-size:12.5px">还没有工作区。工作区 = 「我正在做的一件事 + 它用到的那套工具」。'
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
  let h='<span class="close" onclick="document.getElementById(\'panel\').classList.remove(\'open\')">×</span>'
    +'<h2>📌 '+esc(w.name)+'</h2>'
    +'<div style="color:var(--dim);font-size:12.5px">状态：'+esc(w.status||'进行中')+'　｜　建于 '+esc(w.created||'')+'</div>';
  if(w.goal) h+='<div class="hbody" style="margin-top:10px">目标：'+esc(w.goal)+'</div>';
  if(w.note) h+='<div style="color:var(--dim);font-size:12.5px;margin-top:6px">我的备注：'+esc(w.note)+'</div>';
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
        +'<br><span style="color:var(--dim);font-size:11.5px">'+stars5(p.exp)+' ｜ '+esc(p.l2)+'</span></td>'
        +'<td style="white-space:normal">'+esc(oneText(p)||'（待补全）')+'</td></tr>';
    });
    h+='</table>';
  }
  h+='<div class="cmpnote">工作区是你自己的记录，不是官方模板；勾选进度请让助手更新（页面写不了文件）。</div>';
  document.getElementById('panel').innerHTML=h;
  document.getElementById('panel').classList.add('open');
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
  if(p.one) human+='<div class="sec-h">💡 一句话理解（它是什么）</div><div class="hbody">'+esc(p.one)+'</div>';
  if(p.prob) human+='<div class="sec-h">🎯 它解决什么问题</div><div class="hbody">'+esc(p.prob)+'</div>';
  if(p.ex) human+='<div class="sec-h">🧪 举个例子</div><div class="hbody">'+esc(p.ex)+'</div>';
  if(p.note) human+='<div class="sec-h">📝 为什么值得留意</div><div class="hbody">'+esc(p.note)+'</div>';
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
      expBlock+='<div class="fnrow"><b>'+d[0]+'</b><span>'+stars5(d[1])+' <span style="color:var(--dim);font-size:11.5px">'+d[2]+'</span></span></div>';
    });
    expBlock+='<div class="todo-box" style="background:#1c222c;border-color:var(--line);color:var(--dim)">评分构成：易用性 30 ｜ 文档完整 20 ｜ 功能成熟 20 ｜ 维护活跃 15 ｜ 风险 15（满分 100）。<b>不看 star 数</b>——500 star 但装上就能用的工具可以五星，5 万 star 但要配半天环境的只能三星。</div>';
  } else {
    expBlock='<div class="sec-h">📊 功能备注（多维评分）</div><div class="todo-box">信息不足，<b>暂不评分</b>。资料完整后会补上。</div>';
  }
  const tags=(p.ft||[]).map(x=>'<span class="pill pill-fn">'+esc(x)+'</span>').join('');
  const rows=DIMS.map((d,i)=>'<div><b>'+d+'</b>'+esc(p.t[i])+'</div>').join('');
  const evHtml=evs.length? evs.map(e=>'<div class="ev"><time>'+e.d+'</time><span><b>'+esc(e.t)+'</b> '+esc(e.x)+'</span></div>').join('') : '<div class="ev">暂无事件记录</div>';
  document.getElementById('panel').innerHTML='<span class="close" onclick="document.getElementById(\'panel\').classList.remove(\'open\')">×</span>'
    +'<h2>'+esc(p.id)+'</h2>'
    +'<div style="margin:6px 0 2px">'+stars5(p.exp)+'　<span class="pill pill-fn">'+esc(p.l1)+' / '+esc(p.l2)+'</span>'
      +((p.tier==='S'||p.tier==='A')?('　<span class="pill tier-'+p.tier+'">'+p.tier+' 档推荐</span>'):(p.tier==='dropped'?'　<span class="pill s-dropped">已淘汰</span>':'　<span class="pill tier-unrated">未评档</span>'))
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
    +'<div><b>台账备注</b>'+esc(p.note||'—')+'</div>'
    +((p.un&&p.un.filter(x=>x).length)?('<div><b>用户备注</b>'+p.un.filter(x=>x).map(x=>'【'+(x.date||'')+'】'+esc(x.note||'')).join('；')+'</div>'):'')
    +'<div><b>事件数</b>'+evCount(p)+' 条</div>'
    +rows+'</div>'
    +'<div class="kv"><a href="'+repoUrl(p)+'" target="_blank" rel="noopener">在 GitHub 打开 ↗</a></div>';
  document.getElementById('panel').classList.add('open');
}
document.addEventListener('keydown',e=>{
  if(e.key==='/' && document.activeElement!==document.getElementById('q')){ e.preventDefault(); document.getElementById('q').focus(); }
  if(e.key==='Escape'){ document.getElementById('panel').classList.remove('open'); clearCmp(); }
});
buildToday(); buildPlans(); buildWorkspaces(); buildCat(); loadGaps(); render(); renderCmpBar();
try{ if(localStorage.getItem('dsh-lib-hero')==='off'){ const hs=document.getElementById('hero'); if(hs) hs.style.display='none'; } }catch(e){}
</script>
</body>
</html>
"@

$out = P 'overview.html'
[System.IO.File]::WriteAllText($out, $html, (New-Object System.Text.UTF8Encoding($false)))
$sz = [math]::Round((Get-Item $out).Length/1KB,1)
$per = (Get-Item $out).Length / [Math]::Max($rows.Count,1)
Write-Host "已生成：$out" -ForegroundColor Green
Write-Host "  工具 $($rows.Count) ｜ 已评分 $ratedN ｜ 今日新增 $todayNew ｜ 近 7 天有更新 $recentN"
Write-Host "  **单文件全部内嵌**：$sz KB（每项 $([math]::Round($per,0)) B）"
Write-Host "  按此密度 3650 项约 $([math]::Round($per*3650/1KB,0)) KB —— 双击即可用，无需服务器"
