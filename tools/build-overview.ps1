# build-overview.ps1 — 生成旧版工具库 legacy/overview-v5.html（「我的开源工具库」v5）
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
      dr     = $p.drop_reason   # 淘汰原因（2026-10-16 新增投影；建议调整项 13）
      origin = $p.origin
      oder   = $p.origin_note
  oc     = $p.owner_class   # $/all 与 $/picks 的官方标记（P1-2 校订后才有 official-bigtech）
  ol     = $p.owner_label
      l1     = $p.category.l1
      l2     = $p.category.l2
      exp    = $p.experience.stars          # 体验五星（可能为 null）
      expSc  = $p.experience.score
      part   = $p.experience.parts
      t      = @($p.tags.'领域', $p.tags.'形态', $p.tags.'用途', $p.tags.'成熟度', $p.tags.'上手难度', $p.tags.'风险等级')
      hs     = if ($h) { $h.status } else { 'missing' }
      one    = if ($h) { $h.one_liner } else { $null }
      aud    = if ($h) { $h.audience } else { $null }   # P1-13：适合谁（推荐过的条目才有；页面在 #/picks 头条与详情显示）
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
    } catch { $null = $_ }
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
$planCount = 0   # hero 文案里的「N 个工作方案」用它（2026-10-14 修复：原来硬编码 143 个项目 / 11 个方案，
                 # demo 页面于是自称「143 个项目」而页面实际只有 15 条 —— 数字必须由数据算出来）
$plansPath = P 'data\plans.json'
if (Test-Path $plansPath) {
  try {
    $pj = Get-Content $plansPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $plansJson = ConvertTo-Json -InputObject @($pj.plans) -Depth 8 -Compress
    $planCount = @($pj.plans).Count
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
      try { $wsl += ($l | ConvertFrom-Json) } catch { $null = $_ }
    }
    if ($wsl.Count) { $wsJson = ConvertTo-Json -InputObject @($wsl) -Depth 8 -Compress }
  } catch { Write-Warning "workspaces.jsonl 解析失败：$($_.Exception.Message)" }
}
if (-not $wsJson) { $wsJson = '[]' }

# ---------- 统计 ----------
$genTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$today   = (Get-Date).ToString('yyyy-MM-dd')
$totalN  = $rows.Count
$ratedN  = ($rows | Where-Object { $null -ne $_.exp }).Count
$todayNew= ($rows | Where-Object { $_.first -eq $today }).Count
# 一级分类（按数量排序，只保留非空）
# 近 7 天有提交的
$recentN = ($rows | Where-Object { $_.pushed -and (([datetime]::Now) - [datetime]$_.pushed).Days -le 7 }).Count

# --- P1-14 build stamp（2026-10-17）：算在字面量**之前**（字面量里只能写变量 ✓）---
$buildAt = (Get-Date).ToString('yyyy-MM-dd HH:mm')
$sigFile2 = Join-Path $root 'data\.projects-signature'
$sigShort = if (Test-Path $sigFile2) { (Get-Content $sigFile2 -Raw).Trim().Substring(0,12) } else { 'nosig' }
$projCount = @(Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() }).Count
$buildStamp = "build $buildAt ｜ 数据指纹 $sigShort ｜ $projCount 条"

# --- P2-12 字体内嵌（2026-10-16）：Anton **拉丁 WOFF2 子集** base64 内嵌 ---
# 为什么：设计 §10.2 要 Anton 做拉丁刊头；内嵌后**依然 0 外部请求**（单文件离线 ✓）。
# 许可：SIL OFL 1.1 —— 允许嵌入/随软件分发，**条件 2 要求随附版权声明与许可文本** →
#       根目录 `THIRD-PARTY.md` 存 OFL 全文；audit 有一条检查盯这个配对 ✓
# 缺失时不报错、自动降级（@font-face 不输出，刊头回落到等宽栈）—— 不让缺一个字体把页面搞挂 ✓
$antonPath = Join-Path $root 'assets\anton-latin.woff2'
$antonB64 = ''
$antonNote = '（未内嵌：找不到 assets\anton-latin.woff2）'
if (Test-Path $antonPath) {
  $antonBytes = [System.IO.File]::ReadAllBytes($antonPath)
  $antonB64 = [Convert]::ToBase64String($antonBytes)
  $antonNote = "（已内嵌 $([math]::Round($antonBytes.Length/1KB,1)) KB WOFF2 子集 ｜ OFL 1.1 ｜ 版权见 THIRD-PARTY.md）"
}
$antonFontFace = if ($antonB64) {
  "@font-face{font-family:'Anton';font-style:normal;font-weight:400;font-display:swap;src:url(data:font/woff2;base64,$antonB64) format('woff2')}"
} else { '/* Anton 未内嵌（assets\anton-latin.woff2 缺失）→ 刊头回落等宽栈 */' }

# --- P2-3 后半（2026-10-16）：模板拆分 —— CSS/JS 从生成器里拆出去 ---
# 为什么：这段字面量已涨到 ~1200 行，改一行 CSS 得在整坨 here-string 里翻 ✗；拆成**真文件**后
# 可用编辑器/语法高亮，而且**插值风险只剩骨架**（CSS/JS 现在是纯文本，反引号/`$` 不再被 PS 吃掉 ✓）。
# 产物仍是**单文件** legacy\overview-v5.html ✓（模板只是构建期输入，不改变交付形态）。
$tplDir = Join-Path $root 'tools\templates'
$cssTplPath = Join-Path $tplDir 'overview.css'
$jsTplPath  = Join-Path $tplDir 'overview.js'
foreach ($tplPath in @($cssTplPath, $jsTplPath)) {
  if (-not (Test-Path $tplPath)) { Write-Host "缺少模板文件：$tplPath（模板是生成器的输入，必须随 tools\ 一起走）" -ForegroundColor Red; exit 1 }
}
$cssBlock = (Get-Content $cssTplPath -Raw -Encoding UTF8).Replace('{{FONT_FACE}}', $antonFontFace)
$jsBlock  = Get-Content $jsTplPath -Raw -Encoding UTF8
foreach ($pair in @(@('{{EV}}', $evJsonStr), @('{{PLANS}}', $plansJson), @('{{SYN}}', $synJson), @('{{WS}}', $wsJson), @('{{JSON}}', $json))) {
  if ($jsBlock.IndexOf($pair[0]) -lt 0) { Write-Host "JS 模板缺少占位符 $($pair[0])" -ForegroundColor Red; exit 1 }
  $jsBlock = $jsBlock.Replace($pair[0], $pair[1])   # 字面替换（.Replace 不是正则 ✓ JSON 里的 $ 和 \ 安全）
}
# ================= 批次 6 · #/home（杂志封面 + 目录）=================
# 设计依据：`页面分级设计` §10.5（home = 杂志封面 + 目录）、§12-①②③（库总览 / 探索地图 / 最近变化）
# **所有数字在构建期算完**（设计 §0-5：页面打开即出图，不依赖运行时聚合；229 条 <10ms ✓）
# 视觉纪律：荧光黄**≤8% 且只做底/块/线**、警示红只做警示、颜色不做唯一信息手段（每个图都有文字摘要 + aria）✓
$nTotal  = $rows.Count
$nRec    = @($rows | Where-Object { $_.rec -eq $true }).Count
$nActive = @($rows | Where-Object { $_.status -eq 'active' }).Count
$nWatch  = @($rows | Where-Object { $_.status -eq 'watching' }).Count
$nUsing  = @($rows | Where-Object { $_.status -eq 'using' }).Count
$nRes    = @($rows | Where-Object { $_.status -eq 'researching' }).Count
$nDrop   = @($rows | Where-Object { $_.status -eq 'dropped' }).Count
$nS      = @($rows | Where-Object { $_.tier -eq 'S' }).Count
$nA      = @($rows | Where-Object { $_.tier -eq 'A' }).Count
$nB      = @($rows | Where-Object { $_.tier -eq 'B' }).Count
$nDropT  = @($rows | Where-Object { $_.tier -eq 'dropped' }).Count
$nUnrated= @($rows | Where-Object { $_.tier -ne 'S' -and $_.tier -ne 'A' -and $_.tier -ne 'B' -and $_.tier -ne 'dropped' }).Count
$nLow    = @($rows | Where-Object { $_.risk -eq '低' }).Count
$nMid    = @($rows | Where-Object { $_.risk -eq '中' }).Count
$nHigh   = @($rows | Where-Object { $_.risk -eq '高' }).Count
$nNoRisk = @($rows | Where-Object { -not $_.risk }).Count
$nUser   = @($rows | Where-Object { $_.origin -eq 'user' }).Count
$d7 = (Get-Date).AddDays(-6).ToString('yyyy-MM-dd')
$nNew7 = @($rows | Where-Object { $_.first -and ([string]$_.first) -ge $d7 }).Count
$pctOf = { param($n, $tot) if ($tot -gt 0) { (100.0 * $n / $tot).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) } else { '0.0' } }

# 堆叠条 + 明细行（状态/档位/风险共用；黄只给"警示/强调"两处，其余走灰阶 ✓）
function Home-Bar($items, $tot) {
  $bar = ''; $rowsHtml = ''
  foreach ($it in $items) {
    $ps = & $pctOf $it.n $tot
    if ($it.n -gt 0) { $bar += '<span class="seg ' + $it.cls + '" style="width:' + $ps + '%"></span>' }
    $rowsHtml += '<li><span class="rl">' + $it.label + '</span><span class="rn mono">' + $it.n + '</span><span class="rp mono">' + $ps + '%</span></li>'
  }
  return @{ bar = $bar; rows = $rowsHtml }
}
$stItems = @(
  [pscustomobject]@{ label = '观察中';   n = $nWatch;  cls = 'sg-gray' },
  [pscustomobject]@{ label = '已收录';   n = $nActive; cls = 'sg-white' },
  [pscustomobject]@{ label = '正在使用'; n = $nUsing;  cls = 'sg-white' },
  [pscustomobject]@{ label = '研究中';   n = $nRes;    cls = 'sg-gray' },
  [pscustomobject]@{ label = '已放弃';   n = $nDrop;   cls = 'sg-red' }
)
$tierItems = @(
  [pscustomobject]@{ label = 'S 档';    n = $nS;       cls = 'sg-yellow' },
  [pscustomobject]@{ label = 'A 档';    n = $nA;       cls = 'sg-white' },
  [pscustomobject]@{ label = 'B 档';    n = $nB;       cls = 'sg-gray' },
  [pscustomobject]@{ label = '已淘汰';  n = $nDropT;   cls = 'sg-red' }
)
$riskItems = @(
  [pscustomobject]@{ label = '低';   n = $nLow;    cls = 'sg-white' },
  [pscustomobject]@{ label = '中';   n = $nMid;    cls = 'sg-gray' },
  [pscustomobject]@{ label = '高';   n = $nHigh;   cls = 'sg-red' },
  [pscustomobject]@{ label = '未评'; n = $nNoRisk; cls = 'sg-gray' }
)
$stBar = Home-Bar $stItems $nTotal
$tierBar = Home-Bar $tierItems $nTotal
$riskBar = Home-Bar $riskItems $nTotal

$libDays = ((Get-Date) - [datetime](($rows | Measure-Object first -Minimum).Minimum)).Days
$nTierUnratedWord = @($rows | Where-Object { $_.tier -eq 'unrated' }).Count
$nTierEmpty = @($rows | Where-Object { -not $_.tier }).Count
$new7Note = if ($nNew7 -ge $nTotal) { "库只有 $libDays 天历史 · 全部都在窗口内" } else { '首次收录进台账' }# KPI 4 卡（只有"推荐过"用黄块 —— 黄是稀缺资源 ✓）
$kpiHtml = (@(
  @{ n = $nTotal;     label = '库内项目';     note = '全部本地 · 可全量重建';     cls = '' },
  @{ n = $nRec;       label = '推荐过';       note = "S 档 $nS · A 档 $nA";        cls = 'is-yellow' },
  @{ n = $nNew7;      label = '近 7 天新增';  note = $new7Note;                   cls = '' },
  @{ n = ($nWatch + $nActive + $nUsing); label = '在跟 + 在用'; note = "观察中 $nWatch · 已收录 $nActive" ; cls = '' }
) | ForEach-Object {
  '<div class="kpi ' + $_.cls + '"><b class="mono">' + $_.n + '</b><span>' + $_.label + '</span><em>' + $_.note + '</em></div>'
}) -join ''

# 类别分布（一级横条，可点 → 跳到全库并按该大类筛选）
$l1Groups = @($rows | Group-Object { $_.l1 } | Sort-Object Count -Descending)
$l1Max = if ($l1Groups.Count) { $l1Groups[0].Count } else { 1 }
$catRows = ''
foreach ($g in $l1Groups) {
  if (-not $g.Name) { continue }
  $ps = & $pctOf $g.Count $nTotal
  $w = if ($l1Max -gt 0) { [math]::Round(100.0 * $g.Count / $l1Max, 1).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) } else { '0' }
  $catRows += "<button type=""button"" class=""catrow"" onclick=""jumpL1('$($g.Name)')""><span class=""cl"">$($g.Name)</span><span class=""cbar""><i style=""width:$w%""></i></span><span class=""cn mono"">$($g.Count)</span><span class=""cp mono"">$ps%</span></button>"
}
$l2Count = @($rows | Group-Object { $_.l2 }).Count

# 探索缺口（② 探索地图）：用 taxonomy 的全量类目去比"数据里有没有"，缺口才算得准 ✓
$taxPath = Join-Path $root 'data\taxonomy.json'
$gapEmpty = @(); $gapNoRec = @()
if (Test-Path $taxPath) {
  $tx = Get-Content $taxPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $presentL2 = @{}; foreach ($g in ($rows | Group-Object { $_.l2 })) { if ($g.Name) { $presentL2[$g.Name] = $g.Count } }
  $recL2 = @{}; foreach ($g in ($rows | Where-Object { $_.rec -eq $true } | Group-Object { $_.l2 })) { if ($g.Name) { $recL2[$g.Name] = $g.Count } }
  foreach ($p1 in $tx.'一级分类'.PSObject.Properties) {
    if (-not $p1.Value.children) { continue }
    foreach ($p2 in $p1.Value.children.PSObject.Properties) {
      $l2n = $p2.Name
      $cnt = if ($presentL2.ContainsKey($l2n)) { [int]$presentL2[$l2n] } else { 0 }
      if ($cnt -eq 0) { $gapEmpty += "$($p1.Name) / $l2n" }
      elseif (-not $recL2.ContainsKey($l2n)) { $gapNoRec += "$($p1.Name) / $l2n（$cnt 条）" }
    }
  }
}
$gapStale = @($rows | Group-Object { $_.l2 } | Where-Object { ($_.Group | Measure-Object first -Maximum).Maximum -lt (Get-Date).AddDays(-30).ToString('yyyy-MM-dd') })
$gapHtml = ''
$gapHtml += '<div class="gap"><h4>① 还没有任何项目的类目 <b class="mono">' + $gapEmpty.Count + '</b></h4>'
$gapHtml += if ($gapEmpty.Count) { ($gapEmpty | ForEach-Object { '<span class="tagx">' + $_ + '</span>' }) -join ' ' } else { '<p class="none">无：每个类目都至少有 1 条 ✓</p>' }
$gapHtml += '</div><div class="gap"><h4>② 有项目但一条都没推荐过 <b class="mono">' + $gapNoRec.Count + '</b></h4>'
$gapHtml += if ($gapNoRec.Count) { ($gapNoRec | Select-Object -First 18 | ForEach-Object { '<span class="tagx">' + $_ + '</span>' }) -join ' ' } else { '<p class="none">无 ✓</p>' }
$gapHtml += '</div><div class="gap"><h4>③ 超过 30 天没有新增 <b class="mono">' + @($gapStale).Count + '</b></h4>'
$gapHtml += if (@($gapStale).Count) { (@($gapStale) | ForEach-Object { '<span class="tagx">' + $_.Name + '</span>' }) -join ' ' } else { '<p class="none">无 —— 库本身才 ' + ((Get-Date) - [datetime]($rows | Measure-Object first -Minimum).Minimum).Days + ' 天历史，全部类目都还"新" ✓（等库老了这条才有意义）</p>' }
$gapHtml += '</div>'

# 最近变化（③）：近 7 天每日事件数 + 事件类型（等宽方括号徽章，design §10.5 终端日志性格）
$dayList = @(); for ($i = 6; $i -ge 0; $i--) { $dayList += (Get-Date).AddDays(-$i).ToString('yyyy-MM-dd') }
$evPerDay = @{}; foreach ($d in $dayList) { $evPerDay[$d] = 0 }
$evType7 = @{}
foreach ($k in $evMap.Keys) {
  foreach ($e in $evMap[$k]) {
    $d = [string]$e.d
    if ($evPerDay.ContainsKey($d)) { $evPerDay[$d]++; $t = [string]$e.t; $evType7[$t] = 1 + ([int]$evType7[$t]) }
  }
}
$evMax = 0; foreach ($v in $evPerDay.Values) { if ($v -gt $evMax) { $evMax = $v } }
$spark = ''
foreach ($d in $dayList) {
  $c = [int]$evPerDay[$d]
  $h = if ($evMax -gt 0) { [math]::Round(100.0 * $c / $evMax, 0) } else { 0 }
  $spark += "<div class=""spark-col"" title=""$d：$c 条事件""><i style=""height:$h%""></i><b class=""mono"">$c</b><span class=""mono"">$($d.Substring(5))</span></div>"
}
$typeLabel = @{ discovered = 'NEW'; stars_up = 'STAR'; recommended = 'PICK'; release_detected = 'REL'; status_changed = 'STAT'; metadata_updated = 'META'; push_activity = 'PUSH'; stars_drop = 'DROP'; category_changed = 'CAT'; license_changed = 'LIC' }
$typeZh = @{ discovered = '首次收录'; stars_up = '星数上涨'; recommended = '进推荐'; release_detected = '有新版本'; status_changed = '状态变更'; metadata_updated = '元数据更新'; push_activity = '提交活动'; stars_drop = '星数下降'; category_changed = '分类变更'; license_changed = '许可变更' }
$typeBadges = ''
foreach ($k in ($evType7.Keys | Sort-Object { -[int]$evType7[$_] })) {
  $lb = if ($typeLabel.ContainsKey($k)) { $typeLabel[$k] } else { $k.ToUpper() }
  $zh = if ($typeZh.ContainsKey($k)) { $typeZh[$k] } else { '' }
  $typeBadges += '<span class="tagx mono">[' + $lb + ']</span><span class="zh">' + $zh + ' <b class="mono">' + $evType7[$k] + '</b></span> '
}
$evTotal7 = 0; foreach ($v in $evPerDay.Values) { $evTotal7 += $v }
$homeSummary = "库内 $nTotal 个项目：推荐过 $nRec 个，观察中 $nWatch、已收录 $nActive、已放弃 $nDrop；风险已评 $($nLow + $nMid + $nHigh) 个（低 $nLow / 中 $nMid / 高 $nHigh），其余 $nNoRisk 个未评：未评不等于安全。近 7 天共 $evTotal7 条变化。"
# 图例里的白名单数字**实时算**，不写死（2026-10-18）
$offCount = @($rows | Where-Object { $_.oc -eq 'official' }).Count
$wlCount = 0
try {
  $wlRaw = Get-Content (P 'data\owner-whitelist.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $wlCount = @($wlRaw.orgs.PSObject.Properties).Count
} catch { $null = $_ }

$html = @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>我的开源工具库</title>
<style>$cssBlock</style>
<style>
/* ⑤ 档案站：新视觉六页（外壳 + 首页 + 日报 C/D + 全库 + 计划与工作区） */
#view-site{padding:0}
#view-site .site-head{padding:20px 0 6px}
#view-site .site-head h2{margin:0 0 6px;font-size:22px}
#view-site .site-head p{margin:0 0 6px;color:var(--dim);font-size:13px;line-height:1.75}
#view-site .site-links{font-size:12px}
#view-site .site-links a{margin:0 3px;border-bottom:1px solid currentColor}
#view-site iframe{display:block;width:100%;height:calc(100vh - 215px);min-height:620px;
  border:2px solid #0a0a0a;background:#080807;margin:10px 0 24px}
</style>
</head>
<body>
<header>
  <h1>🧰 我的开源工具库 <small>共 $totalN 个工具 ｜ 已评分 $ratedN ｜ 近 7 天有更新 $recentN ｜ 生成于 $genTime</small></h1>
  <input id="q" placeholder="想干什么？直接说需求，例如：画图 / 做PPT / 替代PS / 聊天机器人 / 本地运行AI（按 / 聚焦）" oninput="render();ensureAllView()">
  <nav id="nav">
    <!-- 一级导航用**真链接**（`<a href="#/…">`），不用 `<span onclick>`：
         ① 可 Tab 聚焦、回车即开（设计 §5「全键盘可达」）；
         ② 可右键「复制链接 / 在新标签打开」——这才叫可分享；
         ③ 真机探针（tools\history-probe-cdp.js）按 `href` 找目标 → 改前是 span，它按定义找不到 ✗
         点击后由 hashchange → route() 统一渲染，不需要额外的 onclick ✓ -->
    <a class="navlink" id="nav-home" href="#/home">① 总览</a>
    <a class="navlink" id="nav-picks" href="#/picks">② 发现</a>
    <a class="navlink" id="nav-all" href="#/all">③ 全库</a>
    <a class="navlink" id="nav-plans" href="#/plans">④ 方案与工作区</a>
    <a class="navlink" id="nav-site" href="#/site">⑤ 档案站</a>
    <a class="navlink" id="nav-legend" href="#/legend" title="档位 / 状态 / 风险 / 徽章是什么意思">📖 图例与标准</a>
  </nav>
  <div class="toolbar" id="toolbar">
    <select id="sort" onchange="render();syncURL()">
      <option value="stars">按体验评分</option>
      <option value="gh">按星数</option>
      <option value="recent">按最近提交</option>
      <option value="name">按名称</option>
    </select>
    <select id="fs" onchange="render();syncURL()">
      <option value="">全部状态</option>
      
      <option value="active">已收录</option>
      <option value="using">正在使用</option>
      <option value="watching">观察中</option>
      <option value="researching">研究中</option>
      <option value="dropped">已放弃</option>
    </select>
    <select id="fb" onchange="render();syncURL()">
  <option value="">全部徽章</option>
  <option value="org">🏢 官方</option><option value="new">🌱 新星</option><option value="gem">🧊 冷门</option>
  <option value="ever">🧱 常青</option><option value="watch">🧪 待观察</option>
  </select>  <select id="fr" onchange="render();syncURL()">
      <option value="">全部风险</option><option>低</option><option>中</option><option>高</option>
    </select>
    <select id="ft" onchange="render();syncURL()">
      <option value="">全部档位</option><option>S</option><option>A</option><option value="unrated">未评档</option>
    </select>
    <select id="f5" onchange="render();syncURL()">
      <option value="">全部评分</option>
      <option value="5">五星</option><option value="4">四星以上</option><option value="3">三星以上</option>
      <option value="0">仅未评分</option>
    </select>
    <select id="fa" onchange="render();syncURL()">
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
  <div id="crumb"></div>

  <!-- ① 总览：#/home -->
  <section id="view-home" class="view">
  <!-- § 封面（杂志刊头）：拉丁超大标题用内嵌 Anton，中文走系统栈，黄只做一条切割带 ✓ -->
  <section id="hero" class="masthead">
    <h2 class="mh-title"><span class="mh-lat">ARCHIVE</span><br><span class="mh-lat mh-hl">INDEX</span></h2>
    <div class="mh-bar"><span class="mono">EST. 2026 · LOCAL ARCHIVE · 单文件离线 · 零依赖</span></div>
    <p class="mh-cn">开源工具档案 · <em>$totalN 个项目</em> · $planCount 个工作方案</p>
    <p class="mh-lede">本地只读档案：$nTotal 条项目，其中 $nUser 条是你自己推荐的。所有数字在构建期算好，双击即用、不联网。</p>
    <div class="items mh-actions">
      <span class="chip" onclick="searchFor('做视频')">试试搜「做视频」</span>
      <span class="chip" onclick="searchFor('AI绘画')">搜「AI绘画」</span>
      <span class="chip" onclick="searchFor('找文件')">搜「找文件」</span>
      <span class="chip" onclick="go('plans')">按需求组方案</span>
      <span class="chip" onclick="go('all')">浏览全部 $nTotal 条</span>
      <span class="chip" onclick="go('picks')">今日新增</span>
    </div>
    <p class="mh-hint">不知道怎么用？<b>在搜索框里直接说你想干什么</b>（例如「我想做一个播客频道」），这里会从你自己的库里配一套工具给你。</p>
  </section>

  <!-- § 01 库总览（KPI） -->
  <!-- § 00 中央几何导航（第一轮新增）：三个主入口 + 次级小入口。
       用**真链接**（可 Tab 聚焦、可右键复制、可后退），路由不变：#/picks #/all #/plans ✓ -->
  <nav id="hub" aria-label="主要入口">
    <a class="hub-node hub-picks" href="#/picks">
      <b class="hub-no">01</b>
      <span class="hub-t">每日精选</span>
      <span class="hub-d">日报与精选是同一件事：按天看新增，或按档位看精品。含来源说明与「适合谁」。</span>
      <span class="hub-n mono">$($nS + $nA) 条已推荐 ｜ $recentN 条近 7 天有更新</span>
    </a>
    <a class="hub-node hub-all" href="#/all">
      <b class="hub-no">02</b>
      <span class="hub-t">完整项目库</span>
      <span class="hub-d">全部 $nTotal 条档案：分类、标签、徽章、风险、成长记录都能筛，筛选条件写进链接可分享。</span>
      <span class="hub-n mono">$nTotal 条 ｜ 其中你自己推荐 $nUser 条</span>
    </a>
    <a class="hub-node hub-plans" href="#/plans">
      <b class="hub-no">03</b>
      <span class="hub-t">计划与工作区</span>
      <span class="hub-d">按需求配好的工具组合与工作区：谁干什么、还缺什么，一屏看完。</span>
      <span class="hub-n mono">$planCount 个方案</span>
    </a>
    <div class="hub-meta">
      <a class="hub-mini" href="#/legend" title="档位 / 状态 / 风险 / 徽章是什么意思">📖 图例与标准</a>
      <a class="hub-mini" href="#/all?badge=gem">🧊 冷门优质</a>
      <a class="hub-mini" href="#/all?badge=org">🏢 官方出品</a>
      <a class="hub-mini" href="#/all?tier=S">S 档</a>
      <span class="hub-mini" onclick="searchFor('本地运行AI')" style="cursor:pointer">试试搜「本地运行AI」</span>
    </div>
  </nav>
  <section class="panel">
    <h3 class="sec-h2"><span class="mono snum">§ 01</span> 库总览 <em>4 个数字说清这个库</em></h3>
    <div class="kpis">$kpiHtml</div>
    <p class="chart-note">$homeSummary</p>
  </section>

  <!-- § 02 结构分布（状态 / 档位 / 风险） -->
  <section class="panel">
    <h3 class="sec-h2"><span class="mono snum">§ 02</span> 结构分布 <em>状态 · 档位 · 风险</em></h3>
    <div class="dist-grid">
      <div class="dist">
        <h4>状态</h4>
        <div class="stack" role="img" aria-label="状态分布：观察中 $nWatch 条、已收录 $nActive 条、已放弃 $nDrop 条">$($stBar.bar)</div>
        <ul class="legend">$($stBar.rows)</ul>
        <p class="chart-note">「正在使用 / 研究中」现在是 0：这两态还没启用（待 P1-3），不是"没有问题"。</p>
      </div>
      <div class="dist">
        <h4>档位</h4>
        <div class="stack" role="img" aria-label="档位分布：S 档 $nS 条、A 档 $nA 条、B 档 $nB 条、未评 $nUnrated 条、已淘汰 $nDropT 条">$($tierBar.bar)</div>
        <ul class="legend">$($tierBar.rows)</ul>
        <p class="chart-note">日报每天最多 8 条，所以 S + A 只有 $($nS + $nA) 条：档位是<b>稀缺</b>的，未评只代表还没看（未评档 $nUnrated = 显式 unrated $nTierUnratedWord + tier 为空 $nTierEmpty，数据里两种写法同义）。</p>
      </div>
      <div class="dist">
        <h4>风险</h4>
        <div class="stack" role="img" aria-label="风险分布：低 $nLow 条、中 $nMid 条、高 $nHigh 条、未评 $nNoRisk 条">$($riskBar.bar)</div>
        <ul class="legend">$($riskBar.rows)</ul>
        <p class="chart-note">未评 $nNoRisk 条（$([math]::Round(100.0 * $nNoRisk / [Math]::Max($nTotal,1), 0))%）：<b>未评 ≠ 安全</b>，只表示还没评估过。</p>
      </div>
    </div>
  </section>

  <!-- § 03 类别分布 -->
  <section class="panel">
    <h3 class="sec-h2"><span class="mono snum">§ 03</span> 类别分布 <em>一级 $($l1Groups.Count) 类 · 二级 $l2Count 类在用</em></h3>
    <div class="catrows">$catRows</div>
    <p class="chart-note">点任一行 → 去全库按该大类筛选（筛选条件会写进链接，可分享、可后退）。</p>
  </section>

  <!-- § 04 探索缺口 -->
  <section class="panel">
    <h3 class="sec-h2"><span class="mono snum">§ 04</span> 探索缺口 <em>哪些地方还没被看过</em></h3>
    <div class="gaps">$gapHtml</div>
  </section>

  <!-- § 05 最近变化 -->
  <section class="panel">
    <h3 class="sec-h2"><span class="mono snum">§ 05</span> 最近变化 <em>近 7 天 $evTotal7 条事件</em></h3>
    <div class="spark" role="img" aria-label="近 7 天每日事件数（列下方数字即当日条数，合计 $evTotal7 条）">$spark</div>
    <div class="typelegend">$typeBadges</div>
    <p class="chart-note">事件来自 data/events.jsonl（可全量重建）。每行都能在「发现」区按日展开。</p>
  </section>
  </section>

  <!-- ② 发现：#/picks（可深链到某天 #/picks/YYYY-MM-DD） -->
  <section id="view-picks" class="view">
  <section class="panel">
    <h2><span class="mono ix">FEATURE</span> 今日新增 <em>每天进货的入口（链接可直接分享到某一天：#/picks/2026-10-16）</em></h2>
    <div id="todayLead"></div>
    <div id="todayRow"></div>
  </section>
  <section class="panel">
    <h2><span class="mono ix">BY TIER</span> 按档位分栏 <em>同一天里，S 档先看</em></h2>
    <div class="tcols" id="todayTiers"></div>
  </section>
  <section class="panel">
    <h2><span class="mono ix">OFFICIAL</span> 官方动态 <em>属于已验证组织账号的条目</em></h2>
    <div id="todayOff"></div>
  </section>
  </section>
<!-- ③ 全库：#/all（分类浏览 + 全部工具） -->
  <section id="view-all" class="view">
  <section>
    <h2><span class="mono ix">INDEX</span> 分类索引 <em>点大类或小类即筛选（筛选条件会写进链接，可分享）</em></h2>
    <div class="catgrid" id="catGrid"></div>
  </section>

  <section>
    <h2><span class="mono ix">LIST</span> 全部条目 <em id="countHint"></em></h2>
    <div id="list"></div>
  </section>
  </section>

  <!-- ④ 方案与工作区：#/plans -->
  <section id="view-plans" class="view">
  <section>
    <h2><span class="mono ix">PLANS</span> 按需求组方案 <em>点一行看这套怎么配（工具按用途自动匹配，不调 API）</em></h2>
    <div id="planGrid"></div>
  </section>

  <section id="wsSection">
    <h2>📌 我的工作区 <em>你正在做的事，和它用到的那套工具</em></h2>
    <div class="catbox"><div class="items" id="wsGrid"></div></div>
  </section>
  </section>

  <!-- ⑤ 档案站：#/site（2026-10-17 接入；iframe 嵌入新视觉站点） -->
  <section id="view-site" class="view">
    <div class="site-head">
      <h2><span class="mono ix">SITE</span> 档案站 <em>新视觉五页 · 外壳 / 首页 / 每日精选 / 全库 / 计划与工作区</em></h2>
      <p>下面嵌入的是新站点入口（底部导航坞、键盘 1–4、G 图例）。<b>用本地 http 服务打开时完整可用</b>；
         直接双击时首屏可看，站内互跳可能被浏览器拦（file:// 不允许跨文档），可用下面的单页链接。</p>
      <p class="site-links">单独打开：
        <a href="data/_tmp/site-shell.generated.html" target="_blank">站点入口</a>
        <a href="data/_tmp/home-brutal-token.generated.html" target="_blank">首页</a>
        <a href="data/_tmp/daily-layout-c-finsara.generated.html" target="_blank">每日精选</a>
        <a href="data/_tmp/library-notebook.generated.html" target="_blank">全库</a>
        <a href="data/_tmp/plans-shelf.generated.html" target="_blank">计划与工作区</a>
      </p>
    </div>
    <iframe src="data/_tmp/site-shell.generated.html#/home" title="档案站（新视觉）" loading="lazy"></iframe>
  </section>
</div>
<div id="panel"></div>
<div id="legend">
  <span class="close" onclick="closeLegend()">×</span>
  <h2>SPEC · 图例与标准</h2>
  <p class="spec-note">本档案自己的技术规范：标记含义、数字口径、链接用法。随时可查（Esc 或点 × 关闭；关闭后回到你刚才看的区）。</p>

  <div class="spec-h">§ 01 / 推荐档位（满分 100，口径来自 RUBRIC.md）</div>
  <table class="spec-tbl">
    <tr><th>档位</th><th>分数</th><th>含义</th><th>上限</th></tr>
    <tr><td class="mono">S</td><td class="mono">≥ 80</td><td>当天最值得看的</td><td class="mono">≤ 3 / 天</td></tr>
    <tr><td class="mono">A</td><td class="mono">65–79</td><td>值得收藏</td><td class="mono">S + A ≤ 8 / 天</td></tr>
    <tr><td class="mono">B</td><td class="mono">50–64</td><td>合格但不急</td><td class="mono">不限</td></tr>
    <tr><td class="mono">未评档</td><td class="mono">未完</td><td>还没走到评分这一步：不代表不好，只代表还没看</td><td class="mono">不限</td></tr>
    <tr><td class="mono">已淘汰</td><td class="mono">&lt; 50</td><td>或命中合规红线（注册机 / 破解 / 刷星迹象）</td><td class="mono">不推荐</td></tr>
  </table>

  <div class="spec-h">§ 02 / 状态（台账五态白名单）</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>观察中</dt><dd>已收录，先盯着看（默认态）</dd></div>
    <div class="spec-row"><dt>已收录</dt><dd>确认可用</dd></div>
    <div class="spec-row"><dt>正在使用</dt><dd>你自己已经在用（当前 0 条，这一态待启用）</dd></div>
    <div class="spec-row"><dt>研究中</dt><dd>证据不足，待复核：既不判死也不推荐（当前 0 条，待 P1-3）</dd></div>
    <div class="spec-row"><dt>已放弃</dt><dd>试过或评估过，不再跟</dd></div>
  </dl>

  <div class="spec-h">§ 03 / 风险等级</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>低</dt><dd>本地工具、不联网、许可清楚</dd></div>
    <div class="spec-row"><dt>中</dt><dd>会读写你的文件 / 需要密钥 / 许可待核</dd></div>
    <div class="spec-row"><dt>高</dt><dd>涉及账号权限、隐私数据、来源不明的可执行文件</dd></div>
    <div class="spec-row"><dt>未评</dt><dd><b>未评 ≠ 安全</b>：只表示还没评估过（本库多数条目属此列）</dd></div>
  </dl>

  <div class="spec-h">§ 04 / 分层徽章（P2-2；规则可在数据上复算，不是贴上去的标签）</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>🏢 官方</dt><dd>仓库 owner 命中白名单 <code>data/owner-whitelist.json</code>（$wlCount 个组织）→ 标记带厂名；<b>只降低核实成本、不加分</b>。当前 $offCount 条</dd></div>
    <div class="spec-row"><dt>🌱 新星</dt><dd>首次收录 ≤ <b>7</b> 天 <b>且</b>已评到 S/A 档（2026-10-17 收紧：原口径"≤14 天 + 质量信号"覆盖 74% 的条目，徽章失去区分度 ✗）。当前 <b>39</b> 条</dd></div>
    <div class="spec-row"><dt>🧊 冷门</dt><dd>星数 &lt; 1000 <b>但</b>质量好（S/A 档或体验分 ≥ 4）：冷门优质；2026-10-16 按你的要求由 💎 改为 🧊。当前 65 条</dd></div>
    <div class="spec-row"><dt>🧱 常青</dt><dd>库龄 &gt; 30 天 <b>且</b>近 7 天仍有提交。⚠️ 现在<b>恒为 0</b>：库本身只有 5 天历史，等库老了它才会出现（不假装有）</dd></div>
    <div class="spec-row"><dt>🧪 待观察</dt><dd>档位未评 <b>且</b>风险未评：证据不足，既不判死也不推。当前 161 条</dd></div>
    <div class="spec-row"><dt>👤 用户推荐</dt><dd>你主动提的项目：一律入库，但门禁未过会写明风险</dd></div>
  </dl>
  <p class="spec-note">🔥 与 💎 已停用（营销号观感；用户 2026-10-14 决定）：冷门一律 🧊，新星一律 🌱。徽章**排在其他标记第一位** ✓；徽章筛选已可用：筛选条里的「全部徽章」→ 会写进链接（例如 `#/all?badge=gem`，可分享、可后退）✓</p>
  <div class="spec-h">§ 05 / 标签与来源（可信度不同）</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>技术标签</dt><dd>来自 GitHub topics 与语言：机器写入，只说"是什么技术"，不代表用途</dd></div>
    <div class="spec-row"><dt>功能标签</dt><dd>人话层的"能干什么"：人工或 agent 撰写，搜索主要靠它</dd></div>
    <div class="spec-row"><dt>用户搜索词</dt><dd>同义词表（人工维护）：你说"修图"也能搜到"图片编辑"</dd></div>
  </dl>

  <div class="spec-h">§ 06 / 数据与免责</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>分数</dt><dd>启发式打分，不是权威评测；档位稀缺（S + A 每天 ≤ 8）</dd></div>
    <div class="spec-row"><dt>星数</dt><dd>采集时点的快照值，不是实时</dd></div>
    <div class="spec-row"><dt>风险</dt><dd>未评 ≠ 安全；高风险条目请先看它的 README 与许可</dd></div>
    <div class="spec-row"><dt>页面</dt><dd>只读单文件：数据全部内嵌、运行期外部请求 0、不写磁盘</dd></div>
    <div class="spec-row"><dt>版本</dt><dd>$buildStamp</dd></div>
    <div class="spec-row"><dt>更新</dt><dd>改完 data 后跑 sync-projects 再跑 build-overview（或双击根目录的刷新页面.cmd）</dd></div>
  </dl>

  <div class="spec-h">§ 07 / 链接与路由（可分享、可后退）</div>
  <dl class="spec-dl">
    <div class="spec-row"><dt>#/home</dt><dd>总览（封面 + § 01–§ 05 目录）</dd></div>
    <div class="spec-row"><dt>#/picks</dt><dd>发现：可深链到某天，#/picks/2026-10-16</dd></div>
    <div class="spec-row"><dt>#/all</dt><dd>全库：筛选写进链接，#/all?cat=AI/AI绘画&amp;tier=S（后退 = 撤销筛选）</dd></div>
    <div class="spec-row"><dt>#/p/owner/repo</dt><dd>单个项目的详情</dd></div>
    <div class="spec-row"><dt>#/plans</dt><dd>方案与工作区（也可 #/plans/id、#/ws/id）</dd></div>
    <div class="spec-row"><dt>#/legend</dt><dd>本页（叠加层，不改变你当前所在的区）</dd></div>
  </dl>
</div>
<div id="cmpBar"></div>
<div class="foot">
  数据来自 <code>data/projects.jsonl</code> + <code>data/events.jsonl</code>（由原始来源派生，可全量重建）。<b>本页是只读视图，数据已全部内嵌，双击即可用。</b><br>
  改状态：编辑 <code>data/seen.jsonl</code> 的 <code>status</code>（白名单 active/using/watching/researching/dropped；saved 为遗留值）并在 <code>data/status-log.jsonl</code> 追加一行，然后跑 <code>sync-projects.ps1</code> 与 <code>build-overview.ps1</code>。<br>
  改分类：只改 <code>data/taxonomy.json</code>（<b>分类不允许运行时自由创建</b>，新方向先写入 <code>taxonomy-suggestions.json</code> 等人工批准）。<br>
  字体：拉丁刊头 <b>Anton</b> $antonNote —— 中文一律系统字体栈；页面<b>运行期外部请求 = 0</b>。
</div>
<script>$jsBlock</script>
</body>
<!-- BUILD-STAMP: $buildStamp -->
</html>
"@

$out = P 'legacy\overview-v5.html'
# 2026-10-19：发布包不带 legacy/ 目录，直接写会报 "Could not find a part of the path"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $out) | Out-Null
[System.IO.File]::WriteAllText($out, $html, (New-Object System.Text.UTF8Encoding($false)))
$sz = [math]::Round((Get-Item $out).Length/1KB,1)
$per = (Get-Item $out).Length / [Math]::Max($rows.Count,1)
Write-Host "已生成：$out" -ForegroundColor Green
Write-Host "  工具 $($rows.Count) ｜ 已评分 $ratedN ｜ 今日新增 $todayNew ｜ 近 7 天有更新 $recentN"
Write-Host "  **单文件全部内嵌**：$sz KB（每项 $([math]::Round($per,0)) B）"
Write-Host "  按此密度 3650 项约 $([math]::Round($per*3650/1KB,0)) KB —— 双击即可用，无需服务器"

# 明确退出码（同 sync-projects）：**不写这句，成功时 $LASTEXITCODE 不会更新**，
# 调用方会读到上一条命令残留的退出码 → 把成功误判成失败 ✗（2026-10-16 实测）
exit 0
