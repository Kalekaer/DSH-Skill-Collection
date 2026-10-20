# build-samples.ps1 — 把真实数据注入「定稿样例」，产出可直接双击的 .generated.html
#
# 为什么要有它（交接 §11.3 点名的唯一硬缺口）：
#   以前每轮注入都是临时命令行，data/_tmp 里只有产物、没有生成器；
#   要重新生成 home / 日报 C·D / 全库 的预览，只能重写注入逻辑（还踩过"填了值没删标记"的坑）。
#   这里固化成一条命令：读 data → 填空 → 清标记 → 断言 → 报告。
#
# 用法：
#   .\tools\build-samples.ps1                 # 用最新一份 picks
#   .\tools\build-samples.ps1 -Date 2026-10-16
#   .\tools\build-samples.ps1 -Layout c       # 只重建 C
#   .\tools\build-samples.ps1 -Layout c,notebook
#
# 输出：data/_tmp/<源文件名>.generated.html（与源文件同名 + .generated）
# 规则：
#   - 源文件里的 /*__XXX__*/ 是**占位符**，不是 bug（见交接 §4 顶部提示）；
#   - 填值后必须把标记本身删掉（交接 §7.1 踩过：/*__TOTAL__*/229 变成页面垃圾）；
#   - 本脚本结尾统一清残留并断言 0，再报告条数。

[CmdletBinding()]
param(
  [string]$Date = '',
  [string[]]$Layout = @('c', 'notebook', 'home', 'plans', 'site'),
  [string]$Root = ''
)

$ErrorActionPreference = 'Stop'
$Cfg = [ordered]@{}
function Fail($msg) { Write-Host "✗ $msg" -ForegroundColor Red; exit 1 }
function OK($msg) { Write-Host "✓ $msg" -ForegroundColor DarkGreen }
function Info($msg) { Write-Host "· $msg" -ForegroundColor DarkGray }

# ---------- 定位仓库根 ----------
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
$Root = (Resolve-Path $Root).Path
function P([string]$rel) { Join-Path $Root $rel }
$tmp = P 'data\_tmp'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp | Out-Null }

# ---------- 读库 ----------
$projPath = P 'data\projects.jsonl'
if (-not (Test-Path $projPath)) { Fail "找不到 $projPath（先跑 tools\sync-projects.ps1）" }
$proj = @{}
$all = New-Object System.Collections.ArrayList
foreach ($l in [System.IO.File]::ReadAllLines($projPath, [Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $o = $l | ConvertFrom-Json } catch { continue }
  if (-not $o -or -not $o.id) { continue }
  $proj[$o.id] = $o
  [void]$all.Add($o)
}
if ($all.Count -eq 0) { Fail 'projects.jsonl 解析出 0 条，检查文件编码/内容' }

# ---------- 日期：默认取最新一份 picks ----------
$pickDir = P 'data\picks'
$pickFiles = @(Get-ChildItem $pickDir -Filter '*.jsonl' -File | Sort-Object Name)
if (-not $pickFiles.Count) { Fail "找不到 $pickDir\*.jsonl" }
if (-not $Date) {
  $Date = [System.IO.Path]::GetFileNameWithoutExtension($pickFiles[-1].Name)
}
$pickPath = Join-Path $pickDir "$Date.jsonl"
if (-not (Test-Path $pickPath)) { Fail "找不到 $pickPath" }
$dt = [datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)

# ---------- 事件：候选数 = 当天 discovered；最近 release 日期用于二次推荐 ----------
$cand = 0
$releaseById = @{}
$evPath = P 'data\events.jsonl'
if (Test-Path $evPath) {
  foreach ($l in [System.IO.File]::ReadAllLines($evPath, [Text.Encoding]::UTF8)) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if ($e -and $e.date -eq $Date -and $e.type -eq 'discovered') { $cand++ }
    if ($e -and $e.type -eq 'release_detected' -and $e.full_name) {
      $rid = [string]$e.full_name
      if (-not $releaseById.ContainsKey($rid) -or [string]$e.date -gt $releaseById[$rid]) { $releaseById[$rid] = [string]$e.date }
    }
  }
}

# ---------- 期号 = reports 里日报的份数 ----------
$issue = @(Get-ChildItem (P 'reports') -File -Filter '*.md' |
  Where-Object { $_.BaseName -match '^\d{4}-\d{2}-\d{2}$' }).Count
$issueNo = '{0:D2}' -f $issue

# ---------- picks：推荐 / 退稿 ----------
# ---------- 统一的「项目卡片」字段（日报 / 全库共用；浮窗靠它）----------
# 一条卡片 = 页面能显示的全部信息；缺字段就留空，浮窗会自己藏掉空区块。
function New-Card($p, $pk) {
  $h = $p.human
  $fn = $null; if ($h) { $fn = $h.feature_note }
  $what = ''; $feats = @(); $uses = @(); $cases = @(); $unfit = @()
  if ($fn) {
    $what = [string]$fn.'是什么'
    $feats = @($fn.'核心功能' | Where-Object { $_ -and "$_" -ne '' })
    $uses = @($fn.'常见用途' | Where-Object { $_ -and "$_" -ne '' })
    $cases = @($fn.'使用案例' | Where-Object { $_ -and "$_" -ne '' })
    $unfit = @($fn.'不适合' | Where-Object { $_ -and "$_" -ne '' })
  }
  $statusMap = @{ watching = '观望'; active = '活跃'; using = '在用'; dropped = '已弃'; researching = '调研中'; saved = '收藏' }
  $st = [string]$p.status
  $stCn = if ($statusMap.ContainsKey($st)) { $statusMap[$st] } else { $st }

  $note = [string]$p.note
  $note = $note.Replace('未评档，不进推荐区', '默认老朋友动态，不占主推荐').Replace('未评档', 'SABCD 档').Replace('淘汰', 'D 档').Replace('候选', '检索结果').Replace('跟踪', '以后还看不看').Replace('退稿', 'D 档原因').Replace('回锅', '二次推荐')
  if ($note.Length -gt 1600) { $note = $note.Substring(0, 1600) + '…' }

  $card = [ordered]@{
    id      = [string]$p.id
    url     = 'https://github.com/' + [string]$p.id
    tier    = if ($pk) { [string]$pk.tier } else { [string]$p.tier }
    score   = if ($pk -and $null -ne $pk.score) { [int]$pk.score } else { $null }
    risk    = if ($pk) { [string]$pk.risk } else { [string]$p.risk }
    action  = if ($pk) { [string]$pk.action } else { '' }
    stars   = if ($p.stars) { [int]$p.stars.current } else { 0 }
    d7      = if ($p.stars) { [int]$p.stars.delta_7d } else { 0 }
    forks   = if ($p.stars) { [int]$p.stars.forks } else { 0 }
    lic     = [string]$p.license
    lang    = [string]$p.language
    l1      = [string]$p.category.l1
    l2      = [string]$p.category.l2
    one     = if ($h -and $h.one_liner) { ([string]$h.one_liner).Replace('淘汰原因','D 档原因').Replace('淘汰','剔除').Replace('精品','主推荐').Replace('候选','检索结果').Replace('跟踪','记录') } else { ([string]$p.description).Replace('淘汰原因','D 档原因').Replace('淘汰','剔除').Replace('精品','主推荐').Replace('候选','检索结果').Replace('跟踪','记录') }
    problem = if ($h) { [string]$h.problem } else { '' }
    example = if ($h) { [string]$h.example } else { '' }
    aud     = if ($h) { [string]$h.audience } else { '' }
    what    = $what
    feats   = $feats
    uses    = $uses
    cases   = $cases
    unfit   = $unfit
    note    = $note
    exp     = [ordered]@{
      stars = if ($p.experience) { $p.experience.stars } else { $null }
      score = if ($p.experience) { $p.experience.score } else { $null }
      parts = if ($p.experience) { $p.experience.parts } else { $null }
    }
    first   = [string]$p.first_seen
    last    = [string]$p.last_seen
    pushed  = if ($p.pushed_at) { ([string]$p.pushed_at).Substring(0, 10) } else { '' }
    created = if ($p.stars) { [string]$p.stars.created_at } else { '' }
    evc     = [int]$p.events_count
    topics  = @($p.topics | Where-Object { $_ } | Select-Object -First 8)
    tags    = @($p.function_tags | Where-Object { $_ } | Select-Object -First 12)
    kw      = @($p.user_keywords | Where-Object { $_ } | Select-Object -First 12)
    syn     = @($p.synonyms | Where-Object { $_ } | Select-Object -First 12)
    repeat  = if ($pk -and $pk.PSObject.Properties['repeat']) { [bool]$pk.repeat } else { $false }
    prev_tier = if ($pk -and $pk.PSObject.Properties['prev_tier']) { [string]$pk.prev_tier } else { '' }
    tier_changed = if ($pk -and $pk.PSObject.Properties['tier_changed']) { [bool]$pk.tier_changed } else { $false }
    rec     = [bool]$p.recommended
    lastRec = if ($p.last_recommended) { [string]$p.last_recommended } else { '' }
    rel     = if ($releaseById.ContainsKey([string]$p.id)) { [string]$releaseById[[string]$p.id] } else { '' }
    recCount = if ($p.recommend_count) { [int]$p.recommend_count } else { 0 }
    status  = $stCn
    drop    = [string]$p.drop_reason
  }
  return $card
}

$picksAll = New-Object System.Collections.ArrayList
$repeatCards = New-Object System.Collections.ArrayList
$rejects = New-Object System.Collections.ArrayList
$watch = New-Object System.Collections.ArrayList
foreach ($l in [System.IO.File]::ReadAllLines($pickPath, [Text.Encoding]::UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $pk = $l | ConvertFrom-Json } catch { continue }
  if (-not $pk -or -not $pk.full_name) { continue }
  $p = $proj[$pk.full_name]
  if (-not $p) { Info "picks 里的 $($pk.full_name) 不在库中，跳过"; continue }
  if ($pk.tier -in @('dropped', 'D')) {
    # D 档也保留完整卡片（点名字能开详情看「退稿原因」），另补一个 reason 给名单用
    $dc = New-Card -p $p -pk $pk
    if ($dc.tier -eq 'dropped') { $dc.tier = 'D' }
    $dc['reason'] = if ($pk.drop_reason) { [string]$pk.drop_reason } elseif ($p.drop_reason) { [string]$p.drop_reason } else { '' }
    [void]$rejects.Add($dc)
  }
  elseif ($pk.tier -in @('B', 'C')) {
    # B/C 只进 watch，不占 S/A 版面
    [void]$watch.Add((New-Card -p $p -pk $pk))
  }
  else {
    $card = New-Card -p $p -pk $pk
    $isRepeat = ([string]$pk.repeat -eq 'true') -or ($pk.repeat -eq $true)
    if ($isRepeat) { [void]$repeatCards.Add($card) }
    else { [void]$picksAll.Add($card) }
  }
}

# 满额只影响“今天刊不刊”，绝不把 A 降成 B：
# S≤3、S+A≤8 之外的 S/A 进 overflow，档位/分数保持不变。
$picks = New-Object System.Collections.ArrayList
$overflow = New-Object System.Collections.ArrayList
$sPub = 0; $pubTotal = 0
foreach ($card in @($picksAll | Sort-Object @{ Expression = { if ($_.tier -eq 'S') { 0 } else { 1 } } }, @{ Expression = { if ($null -ne $_.score) { [double]$_.score } else { 0 } }; Descending = $true })) {
  $block = $null
  if ($card.tier -eq 'S' -and $sPub -ge 3) { $block = 's_cap' }
  elseif ($pubTotal -ge 8) { $block = 'total_cap' }
  if ($block) { [void]$overflow.Add($card) }
  else {
    [void]$picks.Add($card)
    $pubTotal++
    if ($card.tier -eq 'S') { $sPub++ }
  }
}
# 只有 B/C 的日子也要能出页（watch 非空）；0 候选仍拒绝重建，避免把抓取失败日写成空版。
if ($picks.Count -eq 0 -and $rejects.Count -eq 0 -and $overflow.Count -eq 0 -and $watch.Count -eq 0) { Fail "$pickPath 里没有可用条目" }

# ---------- 版面展示上限（2026-10-18 用户定：B≤4、C+D≤8）----------
# 只影响「每日精选」版面；picks / CSV / 台账 / 全库 / 冷却全部保留全量。
$bMax = 4; $cdMax = 8
$cfgPath = P 'config.json'
if (-not (Test-Path $cfgPath)) { Fail "缺少 config.json，无法确定版面展示上限（B≤4 / C+D≤8）" }
try {
  $cfgObj = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($null -ne $cfgObj.output.b_max_display) { $bMax = [int]$cfgObj.output.b_max_display }
  if ($null -ne $cfgObj.output.cd_max_display) { $cdMax = [int]$cfgObj.output.cd_max_display }
} catch { Fail "config.json 读取失败，展示上限必须 fail closed（B≤4 / C+D≤8）：$($_.Exception.Message)" }
if ($bMax -lt 1) { Fail "config.json 的 b_max_display 非法：$bMax" }
if ($cdMax -lt 1) { Fail "config.json 的 cd_max_display 非法：$cdMax" }
$scoreOf = { param($x) if ($null -ne $x.score) { [double]$x.score } else { -1 } }
$bAll = @($watch | Where-Object { $_.tier -eq 'B' } | Sort-Object @{ Expression = $scoreOf; Descending = $true })
$cAll = @($watch | Where-Object { $_.tier -eq 'C' } | Sort-Object @{ Expression = $scoreOf; Descending = $true })
$dAll = @($rejects | Sort-Object @{ Expression = $scoreOf; Descending = $true })
$bShown = @($bAll | Select-Object -First $bMax)
$cdPool = @($cAll) + @($dAll)
$cdShown = @($cdPool | Select-Object -First $cdMax)
$cShown = @($cdShown | Where-Object { $_.tier -eq 'C' })
$dShown = @($cdShown | Where-Object { $_.tier -eq 'D' -or $_.tier -eq 'dropped' })
$watch = @($bShown) + @($cShown)
$rejects = @($dShown)
if ($bShown.Count -gt $bMax) { Fail "B 展示数 $($bShown.Count) 超过上限 $bMax（构建器逻辑错误）" }
if ($cdShown.Count -gt $cdMax) { Fail "C+D 展示数 $($cdShown.Count) 超过上限 $cdMax（构建器逻辑错误）" }

# ---------- 统计（找到 / 已列）----------
$sFound = @($picksAll | Where-Object { $_.tier -eq 'S' }).Count
$aFound = @($picksAll | Where-Object { $_.tier -eq 'A' }).Count
$sCount = @($picks | Where-Object { $_.tier -eq 'S' }).Count
$aCount = @($picks | Where-Object { $_.tier -eq 'A' }).Count
$bCount = $bShown.Count
$cCount = $cShown.Count
$dCount = $dShown.Count
$cdCount = $cdShown.Count
$cdFound = $cdPool.Count
$cdHidden = $cdFound - $cdCount
$bHidden = $bAll.Count - $bCount
# 新入库 = 当天 first_seen 的项目数；日报不再允许没有档位。
$newCount = @($all | Where-Object { $_.first_seen -eq $Date }).Count
$evaluated = @($picksAll).Count + $bAll.Count + $cAll.Count + $dAll.Count
$unCount = 0

$catMap = [ordered]@{}
foreach ($p in $all) {
  $k = [string]$p.category.l1
  if (-not $k) { $k = '未分类' }
  if ($catMap.Contains($k)) { $catMap[$k] = [int]$catMap[$k] + 1 } else { $catMap[$k] = 1 }
}
$cats = @($catMap.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object {
    [ordered]@{ l1 = [string]$_.Key; n = [int]$_.Value }
  })

$tagSet = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($p in $all) {
  if (-not $p.tags) { continue }
  foreach ($v in $p.tags.PSObject.Properties) { if ($v.Value) { [void]$tagSet.Add([string]$v.Value) } }
}

# 日报首图只从「够亮」的 5 张里轮换（2026-10-17 用 37px 抽样实测亮度：
#   146 pad-structure / 135 engine-test / 134 robot-arm / 118 pad39b / 99 highbay；
#   其余 4 张 <90，灰度/双色调压上去会糊成一团，只当素材不排首图。
# 轮换：按「日」取模，同一天结果稳定、隔天自动换图（用户要求"不要一直一模一样"）。
$brightRank = @('nasa-pad-structure.jpg', 'nasa-engine-test.jpg', 'nasa-robot-arm.jpg', 'nasa-pad39b-steel.jpg', 'nasa-vab-highbay.jpg')
$imgs = @($brightRank | Where-Object { Test-Path (P "assets\bg\$_") } | ForEach-Object { '../../assets/bg/' + $_ })
if ($imgs.Count -gt 1) {
  $off = [int]$dt.Day % $imgs.Count
  $rot = @()
  for ($i = 0; $i -lt $imgs.Count; $i++) { $rot += $imgs[($i + $off) % $imgs.Count] }
  $imgs = $rot
}

$week = @('周日', '周一', '周二', '周三', '周四', '周五', '周六')[[int]$dt.DayOfWeek]

# ---------- 组 DAILY（手工拼数组：ConvertTo-Json 会把单元素数组写成对象）----------
$J = { param($o) ($o | ConvertTo-Json -Depth 4 -Compress) }
$picksJson = '[' + (($picks | ForEach-Object { & $J $_ }) -join ',') + ']'
$rejJson = '[' + (($rejects | ForEach-Object { & $J $_ }) -join ',') + ']'
$catJson = '[' + (($cats | ForEach-Object { & $J $_ }) -join ',') + ']'
$imgJson = '[' + (($imgs | ForEach-Object { '"' + ($_ -replace '\\', '/') + '"' }) -join ',') + ']'

# ---------- 日报报头证明统计（FOUND / SCORED / NEW）----------
# FOUND = 当天快照去重后的检索结果数；无快照时回退到当日 discovered 数。
$found = 0
$snapPath = P "data\snapshots\$Date.jsonl"
if (Test-Path $snapPath) {
  try {
    $found = @(Get-Content $snapPath -Encoding UTF8 | Where-Object { $_.Trim() } |
        ForEach-Object { [string]($_ | ConvertFrom-Json).full_name } | Sort-Object -Unique).Count
  } catch { $found = 0 }
}
if ($found -le 0) { $found = [int]$cand }

# SCORED = 当天真正评过的全部条目（含满额未刊与二次推荐；B/C/D 也计入）。
$scoredCards = @(); $scoredSeen = @{}
foreach ($sc in @(@($picksAll) + @($overflow) + @($repeatCards) + @($bAll) + @($cAll) + @($dAll))) {
  if (-not $sc -or -not $sc.id) { continue }
  if (-not $scoredSeen.ContainsKey([string]$sc.id)) { $scoredSeen[[string]$sc.id] = $true; $scoredCards += $sc }
}
function Get-TierCountMap($cards) {
  $m = [ordered]@{ S = 0; A = 0; B = 0; C = 0; D = 0 }
  foreach ($c in @($cards)) {
    $t = [string]$c.tier
    if ($t -eq 'dropped') { $t = 'D' }
    if ($m.Contains($t)) { $m[$t] = [int]$m[$t] + 1 }
  }
  return $m
}
# NEW = first_seen 当天的项目，按库内档位统计。
$newCards = @($all | Where-Object { [string]$_.first_seen -eq $Date })
$proofJson = '{"found":' + [int]$found + ',"scoredTotal":' + $scoredCards.Count + ',"scored":' + (Get-TierCountMap $scoredCards | ConvertTo-Json -Compress) +
  ',"newTotal":' + $newCards.Count + ',"new":' + (Get-TierCountMap $newCards | ConvertTo-Json -Compress) + ',"library":' + $all.Count + '}'

$daily = '{'
$daily += '"date":"' + $Date + '",'
$daily += '"iso":"' + $Date + '",'
$daily += '"shortDate":"' + $dt.ToString('yyyy.MM.dd') + '",'
$daily += '"week":"' + $week + '",'
$daily += '"issue":"' + $issueNo + '",'
$daily += '"band":"' + $dt.ToString('yyyy') + ' · ' + $dt.ToString('MM') + ' · ' + $dt.ToString('dd') + ' · ' + $week + ' — NO.' + $issueNo + ' — 新入库 ' + $newCount + ' → 推荐 ' + $picks.Count + '",'
$daily += '"stats":{"cand":' + $cand + ',"new":' + $newCount + ',"rec":' + $picks.Count + ',"s":' + $sCount + ',"a":' + $aCount + ',"sf":' + $sFound + ',"af":' + $aFound +
' ,"b":' + $bCount + ',"ba":' + $bAll.Count + ',"bh":' + $bHidden + ',"c":' + $cCount + ',"ca":' + $cAll.Count +
' ,"d":' + $dCount + ',"da":' + $dAll.Count + ',"cd":' + $cdCount + ',"cda":' + $cdFound + ',"cdh":' + $cdHidden +
' ,"rej":' + $dAll.Count + ',"un":' + $unCount + ',"total":' + $all.Count + ',"cats":' + $cats.Count + ',"tags":' + $tagSet.Count + '},'
$daily += '"cats":' + $catJson + ','
$daily += '"imgs":' + $imgJson + ','
$daily += '"picks":' + $picksJson + ','
$daily += '"rejects":' + $rejJson
$daily += '}'
$daily = $daily.Substring(0, $daily.Length - 1) + ',"proof":' + $proofJson + '}'
$daily = $daily.Replace('</', '<\/')   # 防止数据里出现 </script> 提前闭合脚本

# ---------- 完整日报 HTML（网页「每日精选」的全文浮层；reports/<date>.md 是内容源）----------
$reportHtml = '<p>（本期完整日报未生成）</p>'
$reportPath = P "reports\$Date.md"
$reportMd = ''
if (Test-Path $reportPath) {
  try {
    $reportMd = [System.IO.File]::ReadAllText($reportPath, [Text.Encoding]::UTF8)
    $reportHtml = ($reportMd | ConvertFrom-Markdown).Html
  } catch {
    $reportHtml = '<p>（完整日报解析失败，见 reports\' + $Date + '.md）</p>'
  }
}

# ---------- 本期全部已评条目（S/A + B/C + D），用于“入库全名单”与去重 ----------
$evalIds = @(
  @($picksAll) + @($bAll) + @($cAll) + @($dAll) + @($repeatCards) | ForEach-Object { [string]$_.id }
)

# ---------- 特别栏目（大厂/官方；报告有本节优先，没有就从库里官方项目取 3 条）----------
$officialCards = @()
$officialPool = @($all | Where-Object { $_.owner_class -eq 'official' -and ($evalIds -notcontains [string]$_.id) } |
  Sort-Object { [string]$_.first_seen } -Descending)
$officialSeen = @{}
if ($reportMd) {
  $om = [regex]::Match($reportMd, '(?s)## 🏢 官方 / 大厂动态.*?(?=\r?\n## |\z)')
  if ($om.Success) {
    foreach ($p in $officialPool) {
      if ($om.Value.Contains([string]$p.id) -and -not $officialSeen.ContainsKey([string]$p.id)) {
        $oc = New-Card -p $p -pk $null
        $oc.score = $null; $oc.action = '看看'
        $officialCards += $oc; $officialSeen[[string]$p.id] = $true
      }
    }
  }
}
if (-not $officialCards.Count) {
  foreach ($p in ($officialPool | Select-Object -First 3)) {
    if ($officialSeen.ContainsKey([string]$p.id)) { continue }
    $oc = New-Card -p $p -pk $null
    $oc.score = $null; $oc.action = '看看'
    $officialCards += $oc
  }
}

# ---------- 老朋友回顾（报告里有这一节才出；与主稿/特别栏目重合时主稿优先）----------
$oldFriendCards = @()
if ($reportMd) {
  $ofm = [regex]::Match($reportMd, '(?s)## 👀 老朋友动态.*?(?=\r?\n## |\z)')
  if ($ofm.Success) {
    $ofIds = @($officialCards | ForEach-Object { [string]$_.id })
    foreach ($p in $all) {
      if ($ofm.Value.Contains([string]$p.id) -and ($evalIds -notcontains [string]$p.id) -and ($ofIds -notcontains [string]$p.id) -and [string]$p.status -ne 'dropped') {
        $oldFriendCards += New-Card -p $p -pk $null
      }
    }
  }
}

# ---------- 今日新入库、但没有档位----------
$officialIds = @($officialCards | ForEach-Object { [string]$_.id })
# 二次推荐只进“老朋友动态”，绝不进主推荐/主跨；与特别栏目重合时特别栏目优先。
foreach ($rc in @($repeatCards)) {
  if (($officialIds -notcontains [string]$rc.id) -and -not (@($oldFriendCards | Where-Object { [string]$_.id -eq [string]$rc.id }).Count)) {
    $oldFriendCards += $rc
  }
}
$noTierCards = @($all | Where-Object {
    [string]$_.first_seen -eq $Date -and
    ($evalIds -notcontains [string]$_.id) -and
    ($officialIds -notcontains [string]$_.id) -and
    [string]$_.origin -ne 'user'
  })
if ($noTierCards.Count -gt 0) {
  $names = (@($noTierCards | ForEach-Object { [string]$_.id }) -join '、')
  Fail "今日有 $($noTierCards.Count) 条自动发现没有档位：$names。先补 picks 再重建。"
}
$noTierCards = @()
$unCount = 0

# ---------- 本日报相关项目（picks / 退稿 / 老朋友 / 报告里提到的，全部可点开详情）----------
$relatedCards = @()
if ($reportMd) {
  foreach ($p in $all) {
    if ($reportMd.Contains([string]$p.id)) { $relatedCards += New-Card -p $p -pk $null }
  }
}
$officialCards = @($officialCards | Select-Object -First 3)
$relatedCards += $officialCards
$relatedCards += $oldFriendCards
$relOrder = @{}; $oi = 0
foreach ($p in @($picks)) { if (-not $relOrder.ContainsKey($p.id)) { $relOrder[$p.id] = $oi++ } }
foreach ($p in @($rejects)) { if (-not $relOrder.ContainsKey($p.id)) { $relOrder[$p.id] = $oi++ } }
foreach ($p in @($oldFriendCards)) { if (-not $relOrder.ContainsKey($p.id)) { $relOrder[$p.id] = $oi++ } }
$relatedCards = @($relatedCards | Sort-Object { if ($relOrder.ContainsKey($_.id)) { $relOrder[$_.id] } else { 999 } })
$seenRel = @{}; $relatedCards = @($relatedCards | Where-Object { if ($seenRel.ContainsKey($_.id)) { $false } else { $seenRel[$_.id] = $true; $true } })
$relJson = '[' + (($relatedCards | ForEach-Object { & $J $_ }) -join ',') + ']'
$ofJson = '[' + (($officialCards | ForEach-Object { & $J $_ }) -join ',') + ']'
$oldFriendCards = @($oldFriendCards)
$selfPushedCards = @($all | Where-Object { [string]$_.origin -eq 'user' -and [string]$_.status -ne 'dropped' } | ForEach-Object { New-Card -p $_ -pk $null })

# 老朋友动态的“二次推荐”：满 7 天 + 新信号（新提交或近 7 天涨星 ≥10%）。
# 只做标记，不占主推荐；计算用的日期是 last_recommended，从未推荐过则用 first_seen。
function Set-SecondaryFlag($cards) {
  foreach ($c in @($cards)) {
    $base = if ($c.lastRec) { [string]$c.lastRec } else { [string]$c.first }
    $baseDt = $null
    try { $baseDt = [datetime]::ParseExact($base, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { }
    if (-not $baseDt -or ($dt - $baseDt).Days -lt 7) { continue }
    $pushedDt = $null
    if ($c.pushed) { try { $pushedDt = [datetime]::ParseExact([string]$c.pushed, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { } }
    $relDt = $null
    if ($c.rel) { try { $relDt = [datetime]::ParseExact([string]$c.rel, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { } }
    $newPush = $pushedDt -and (($dt - $pushedDt).Days -le 7)
    $newRelease = $relDt -and (($dt - $relDt).Days -le 7)
    $starSignal = ([int]$c.stars -gt 0) -and ([int]$c.d7 -ge [Math]::Max(10, [int]($c.stars * 0.1)))
    if ($newPush -or $newRelease -or $starSignal) { $c.repeat = $true }
  }
}
Set-SecondaryFlag $oldFriendCards
Set-SecondaryFlag $selfPushedCards
$oldJson = '[' + (($oldFriendCards | ForEach-Object { & $J $_ }) -join ',') + ']'
$selfJson = '[' + (($selfPushedCards | ForEach-Object { & $J $_ }) -join ',') + ']'
$bAllJson = '[' + (($bAll | ForEach-Object { & $J $_ }) -join ',') + ']'
$cAllJson = '[' + (($cAll | ForEach-Object { & $J $_ }) -join ',') + ']'
$watchJson = '[' + (($watch | ForEach-Object { & $J $_ }) -join ',') + ']'
$overflowJson = '[' + (($overflow | ForEach-Object { & $J $_ }) -join ',') + ']'
$allInSeen = @{}; $allInCards = @()
foreach ($c in @(@($picksAll) + @($bAll) + @($cAll) + @($dAll) + @($noTierCards))) {
  if ([string]$c.first -ne $Date) { continue }
  if (-not $allInSeen.ContainsKey([string]$c.id)) { $allInSeen[[string]$c.id] = $true; $allInCards += $c }
}
$allInJson = '[' + (($allInCards | ForEach-Object { & $J $_ }) -join ',') + ']'
$dailyCore = $daily.Substring(0, $daily.Length - 1) + ',"related":' + $relJson + ',"official":' + $ofJson + ',"watch":' + $watchJson + ',"overflow":' + $overflowJson + '}'
$daily = $dailyCore.Substring(0, $dailyCore.Length - 1) + ',"oldFriends":' + $oldJson + ',"selfPushed":' + $selfJson + ',"bAll":' + $bAllJson + ',"cAll":' + $cAllJson + ',"allIn":' + $allInJson + '}'
$daily = $daily.Replace('</', '<\/')
$dailyCore = $dailyCore.Replace('</', '<\/')
$relatedHtml = if ($relatedCards.Count) {
  ($relatedCards | ForEach-Object { '<button type="button" class="relchip" data-pid="' + [Security.SecurityElement]::Escape($_.id) + '">' + [Security.SecurityElement]::Escape($_.id) + '</button>' }) -join ''
} else { '<span class="relempty">（本期没有可链接条目）</span>' }

$Cfg.date = $Date; $Cfg.issue = $issueNo; $Cfg.picks = $picks.Count; $Cfg.rejects = $dAll.Count

# ---------- 组 PROJ（全库手账本用）----------
$recCount = @($all | Where-Object { $_.recommended }).Count
$projRows = New-Object System.Collections.ArrayList
foreach ($p in $all) {
  $card = New-Card -p $p
  $card['gem'] = $false
  $card['org'] = ([string]$p.owner_class -eq 'official')
  [void]$projRows.Add($card)
}
$projJson = '[' + (($projRows | ForEach-Object { & $J $_ }) -join ',') + ']'
$projJson = $projJson.Replace('</', '<\/')

# ---------- 首页可视化数据（全部来自真实统计）----------
$tierMap = @{ 'S' = 0; 'A' = 0; 'B' = 0; 'C' = 0; 'D' = 0; 'dropped' = 0 }
$statusMap = @{ 'active' = 0; 'watching' = 0; 'dropped' = 0 }
foreach ($p in $all) {
  $tv = [string]$p.tier
  if ($tv -in @('S', 'A', 'B', 'C', 'D')) { $tierMap[$tv]++ }
  elseif ($tv -eq 'dropped') { $tierMap['dropped']++ }
  else { $tierMap['D']++ }
  $sv = [string]$p.status
  if ($statusMap.ContainsKey($sv)) { $statusMap[$sv]++ } else { $statusMap['watching']++ }
}
$tierRows = @(
  [ordered]@{ k = 'S 档'; n = $tierMap['S'] }
  [ordered]@{ k = 'A 档'; n = $tierMap['A'] }
  [ordered]@{ k = 'B 档'; n = $tierMap['B'] }
  [ordered]@{ k = 'C 档'; n = $tierMap['C'] }
  [ordered]@{ k = 'D 档'; n = $tierMap['D'] + $tierMap['dropped'] }
)
$statusRows = @(
  [ordered]@{ k = '观望'; n = $statusMap['watching'] }
  [ordered]@{ k = '活跃'; n = $statusMap['active'] }
  [ordered]@{ k = '已弃'; n = $statusMap['dropped'] }
)

# 标签词频：用 topics（deepseek-harness / dsh-plugin 这类真标签），不是 tags 里的"实验/中"评级
$tagFreq = @{}
foreach ($p in $all) {
  if (-not $p.topics) { continue }
  foreach ($v in $p.topics) {
    if (-not $v) { continue }
    $k = [string]$v
    if ($tagFreq.ContainsKey($k)) { $tagFreq[$k]++ } else { $tagFreq[$k] = 1 }
  }
}
$tagRows = @($tagFreq.GetEnumerator() | Sort-Object -Property @{ Expression = { $_.Value }; Descending = $true }, @{ Expression = { $_.Key }; Descending = $false } | Select-Object -First 8 | ForEach-Object {
    [ordered]@{ t = [string]$_.Key; n = [int]$_.Value }
  })

# 近 7 天事件（升序，标签 MM-dd）
$evByDay = @{}
$evTotal = 0
if (Test-Path $evPath) {
  foreach ($l in [System.IO.File]::ReadAllLines($evPath, [Text.Encoding]::UTF8)) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if (-not $e -or -not $e.date) { continue }
    $evTotal++
    if ($evByDay.ContainsKey($e.date)) { $evByDay[$e.date]++ } else { $evByDay[$e.date] = 1 }
  }
}
$sparkRows = @()
for ($i = 6; $i -ge 0; $i--) {
  $dd = $dt.AddDays(-$i)
  $cnt = if ($evByDay.ContainsKey($dd.ToString('yyyy-MM-dd'))) { $evByDay[$dd.ToString('yyyy-MM-dd')] } else { 0 }
  $sparkRows += [ordered]@{ d = $dd.ToString('MM-dd'); n = [int]$cnt }
}

$planCount = 0
$plansPath = P 'data\plans.json'
if (Test-Path $plansPath) {
  try { $planCount = @((Get-Content $plansPath -Raw -Encoding UTF8 | ConvertFrom-Json).plans).Count } catch { $planCount = 0 }
}

$tierJson = '[' + (($tierRows | ForEach-Object { & $J $_ }) -join ',') + ']'
$statusJson = '[' + (($statusRows | ForEach-Object { & $J $_ }) -join ',') + ']'
$sparkJson = '[' + (($sparkRows | ForEach-Object { & $J $_ }) -join ',') + ']'
$tagsJson = '[' + (($tagRows | ForEach-Object { & $J $_ }) -join ',') + ']'

# ---------- 浮窗片段（三页共用，单一出处）----------
$detailCss = [System.IO.File]::ReadAllText((P 'tools\_detail.css'), [Text.Encoding]::UTF8)
$detailJs  = [System.IO.File]::ReadAllText((P 'tools\_detail.js'), [Text.Encoding]::UTF8)


# ---------- 组合预设 / 工作区（货架页）----------
$plansPath2 = P 'data\plans.json'
$plansArr = @()
if (Test-Path $plansPath2) {
  try { $plansArr = @((Get-Content $plansPath2 -Raw -Encoding UTF8 | ConvertFrom-Json).plans) } catch { $plansArr = @() }
}
$plansOut = New-Object System.Collections.ArrayList
foreach ($pl in $plansArr) {
  $rolesOut = New-Object System.Collections.ArrayList
  foreach ($role in @($pl.roles)) {
    $l2 = @($role.l2 | Where-Object { $_ })
    $ft = @($role.ft | Where-Object { $_ })
    $match = @($all | Where-Object {
        $pjt = @($_.function_tags | Where-Object { $_ })
        (($_.category.l2) -and ($l2 -contains $_.category.l2)) -or (@($pjt | Where-Object { $ft -contains $_ }).Count -gt 0)
      } | Where-Object { [string]$_.tier -ne 'dropped' })
    $top = @($match | Sort-Object -Property { if ($_.stars) { [int]$_.stars.current } else { 0 } } -Descending)
    $topTools = @($top | ForEach-Object {
        $hh = $_.human
        [ordered]@{
          name = [string]$_.id
          tier = [string]$_.tier
          stars = if ($_.stars) { [int]$_.stars.current } else { 0 }
          one  = if ($hh -and $hh.one_liner) { ([string]$hh.one_liner).Replace('淘汰原因','D 档原因').Replace('淘汰','剔除').Replace('精品','主推荐').Replace('候选','检索结果').Replace('跟踪','记录') } elseif ($_.description) { ([string]$_.description).Replace('淘汰原因','D 档原因').Replace('淘汰','剔除').Replace('精品','主推荐').Replace('候选','检索结果').Replace('跟踪','记录') } else { '' }
          lic  = [string]$_.license
        }
      })
    [void]$rolesOut.Add([ordered]@{
        role  = [string]$role.role
        why   = [string]$role.why
        n     = $match.Count
        crit  = [ordered]@{ l2 = $l2; ft = $ft }
        tools = $topTools
      })
  }
  $distinct = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($r in $rolesOut) { foreach ($t in @($r['tools'])) { if ($t -and $t['name']) { [void]$distinct.Add([string]$t['name']) } } }
  [void]$plansOut.Add([ordered]@{
      id        = [string]$pl.id
      name      = [string]$pl.name
      intro     = [string]$pl.intro
      triggers  = @($pl.triggers | Where-Object { $_ })
      roles     = @($rolesOut)
      toolCount = $distinct.Count
      hits      = @($rolesOut | ForEach-Object { $_.n } | Measure-Object -Sum).Sum
    })
}
$plansJson = '[' + (($plansOut | ForEach-Object { & $J $_ }) -join ',') + ']'

$wsPath2 = P 'data\workspaces.jsonl'
$wsOut = New-Object System.Collections.ArrayList
if (Test-Path $wsPath2) {
  foreach ($l in [System.IO.File]::ReadAllLines($wsPath2, [Text.Encoding]::UTF8)) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $w = $l | ConvertFrom-Json } catch { continue }
    if (-not $w -or -not $w.id) { continue }
    $done = @($w.done | Where-Object { $_ })
    $tools = @($w.tools | Where-Object { $_ } | ForEach-Object {
        $pp = $proj[$_]
        [ordered]@{
          id    = [string]$_
          name  = [string]$_
          tier  = if ($pp) { [string]$pp.tier } else { '' }
          stars = if ($pp -and $pp.stars) { [int]$pp.stars.current } else { 0 }
          one   = if ($pp -and $pp.human -and $pp.human.one_liner) { [string]$pp.human.one_liner } elseif ($pp) { [string]$pp.description } else { '' }
          done  = ($done -contains $_)
        }
      })
    $note = [string]$w.note
    if ($note.Length -gt 900) { $note = $note.Substring(0, 900) + '…' }
    [void]$wsOut.Add([ordered]@{
        id      = [string]$w.id
        name    = [string]$w.name
        goal    = [string]$w.goal
        status  = [string]$w.status
        note    = $note
        created = [string]$w.created
        updated = [string]$w.updated
        tools   = $tools
        done    = $done
      })
  }
}
$wsJson = '[' + (($wsOut | ForEach-Object { & $J $_ }) -join ',') + ']'
# ---------- 注入 ----------
$targets = @{
  'c'        = @{ src = 'tools\daily-layout-c-finsara.html'; out = 'daily-layout-c-finsara.generated.html' }
  'layouts'  = @{ src = 'tools\daily-layouts.html'; out = 'daily-layouts.generated.html' }
  'notebook' = @{ src = 'tools\library-notebook.html'; out = 'library-notebook.generated.html' }
  'home'     = @{ src = 'tools\home-brutal-token.html'; out = 'home-brutal-token.generated.html' }
  'plans'    = @{ src = 'tools\plans-shelf.html'; out = 'plans-shelf.generated.html' }
  'site'     = @{ src = 'tools\site-shell.html'; out = 'site-shell.generated.html' }
}

function Inject-Token([string]$text, [string]$name, [string]$value) {
  $hit = $false
  foreach ($tail in @('null', '0', '[]')) {
    $tok = "/*__${name}__*/$tail"
    if ($text.Contains($tok)) { $text = $text.Replace($tok, $value); $hit = $true }
  }
  if ($text.Contains("/*__${name}__*/")) { $text = $text.Replace("/*__${name}__*/", $value); $hit = $true }
  return @{ text = $text; hit = $hit }
}

$enc = New-Object System.Text.UTF8Encoding($false)

# 日报版面：单一结构轴版（2026-10-19 起 D 版合并进 C，不再按日轮换）
$dailyKey = 'c'
$dailyFile = 'daily-layout-c-finsara.generated.html'
Info "日报版面：STRUCTURE AXIS（$dailyFile）"

# 手账本的页数（按 5/4/3 循环切）：与页面里的 planSizes() 同一算法
$nbPages = 0; $leftN = $all.Count; $k3 = 0
while ($leftN -gt 0) { $leftN -= [Math]::Min(@(5, 4, 3)[$k3 % 3], $leftN); $nbPages++; $k3++ }

foreach ($k in $Layout) {
  $key = $k.ToLower()
  if (-not $targets.ContainsKey($key)) { Info "未知 layout「$k」，跳过（可选 c / layouts / notebook / home / plans / site）"; continue }
  $t = $targets[$key]
  $srcPath = P $t.src
  if (-not (Test-Path $srcPath)) { Fail "找不到源文件 $srcPath" }
  $s = [System.IO.File]::ReadAllText($srcPath, [Text.Encoding]::UTF8)

  $tokens = switch ($key) {
    'c' { @{ DAILY = $daily; FULLREPORT = $reportHtml; RELATED = $relatedHtml; DETAIL_CSS = $detailCss; DETAIL_JS = $detailJs } }
    'layouts' { @{ DAILY = $daily } }
    'notebook' { @{ PROJ = $projJson; TOTAL = [string]$all.Count; REC = [string]$recCount; ISSUE = $issueNo; CATS = [string]$cats.Count; DETAIL_CSS = $detailCss; DETAIL_JS = $detailJs } }
    'home' { @{ CATS = $catJson; TIER = $tierJson; STATUS = $statusJson; SPARK = $sparkJson; TAGS = $tagsJson; TOTAL = [string]$all.Count; PLANS = [string]$planCount; WS = [string]$wsOut.Count; EVENTS = [string]$evTotal; LATEST = $Date } }
    'plans' { @{ PLANS = $plansJson; WS = $wsJson } }
    'site' { @{ TOTAL = [string]$all.Count; REC = [string]$recCount; DAILY = $dailyFile; DAILYKEY = $dailyKey } }
  }
  $hits = 0
  foreach ($name in @($tokens.Keys)) {
    $r = Inject-Token $s $name $tokens[$name]
    $s = $r.text
    if ($r.hit) { $hits++ }
  }
  if ($hits -eq 0) { Fail "$($t.src) 里没有可注入的占位符——模板被改坏了？" }

  # 清残留标记（§7.1：填值必须连标记一起删）
  $left = [regex]::Matches($s, '/\*__[A-Z0-9_]+__\*/')
  if ($left.Count -gt 0) { $s = [regex]::Replace($s, '/\*__[A-Z0-9_]+__\*/', '') }
  $after = [regex]::Matches($s, '/\*__[A-Z0-9_]+__\*/').Count
  if ($after -ne 0) { Fail "清理后仍有 $after 处占位符" }

# 2026-10-20：kiosk-return.js 是本地上线产物（返回历史档案浮窗）；发布包里没有这个文件。
#   包里生成时去掉引用，避免 404 + 页面上出现一个点不动的「← 历史档案」按钮。
if ($key -eq 'c' -and -not (Test-Path (P 'data\site\kiosk-return.js'))) {
  $s = [regex]::Replace($s, '(?s)\s*<script src="kiosk-return\.js"></script>', '')
  Info '本环境没有 kiosk-return.js：已去掉引用（发布包/独立使用）'
}

  # 2026-10-19：站点每页统一带 BUILD-STAMP（audit P1-14 / P1-17 靠它判断「页面比数据新」）
  $sig12 = (Get-FileHash (P 'data\projects.jsonl') -Algorithm SHA256).Hash.Substring(0,12)
  $stampLine = '<!-- BUILD-STAMP: build ' + (Get-Date).ToString('yyyy-MM-dd HH:mm') + ' ｜ 数据指纹 ' + $sig12 + ' ｜ ' + $all.Count + ' 条 -->'
  if ($s -match '</head>') { $s = $s -replace '</head>', ($stampLine + "`n</head>") } else { $s = $stampLine + "`n" + $s }

  $outFile = $t.out
  $outPath = Join-Path $tmp $outFile
  [System.IO.File]::WriteAllText($outPath, $s, $enc)
  $kb = [math]::Round((Get-Item $outPath).Length / 1KB, 1)
  if ($key -eq 'notebook') {
    OK ("{0,-34} {1,7} KB  全库 {2} 条 · 推荐 {3} · {4} 页" -f $outFile, $kb, $all.Count, $recCount, $nbPages)
  }
  else {
    OK ("{0,-34} {1,7} KB  推荐 {2} · 退稿 {3} · 候选 {4} · 期号 {5}" -f $outFile, $kb, $picks.Count, $rejects.Count, $cand, $issueNo)
  }
  if ($left.Count -gt 0) { Info "（顺带清掉 $($left.Count) 处旧标记）" }
}

OK "数据来源：$Date ｜ 库内 $($all.Count) 条 ｜ 分类 $($cats.Count) 类 ｜ 标签 $($tagSet.Count) 个"

# 同步到本地正式目录 data/site（_tmp 继续当构建暂存）
$siteDir = P 'data\site'
if (-not (Test-Path $siteDir)) { New-Item -ItemType Directory -Path $siteDir -Force | Out-Null }
$sitePages = @(
  'site-shell.generated.html', 'home-brutal-token.generated.html',
  'daily-layout-c-finsara.generated.html',
  'library-notebook.generated.html', 'plans-shelf.generated.html'
)
$copied = 0
foreach ($p in $sitePages) {
  $src = Join-Path $tmp $p
  if (Test-Path $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $siteDir $p) -Force; $copied++ }
}
OK "同步到 data\site：$copied 个页面"

# 根入口 = 站点外壳 + <base href="data/site/">：打开根就是 ARCHIVE 首页，不再有独立 hub
$shellPath = Join-Path $siteDir 'site-shell.generated.html'
if (Test-Path $shellPath) {
  $shellHtml = [System.IO.File]::ReadAllText($shellPath, [Text.Encoding]::UTF8)
  if ($shellHtml -notmatch '<base ') {
    $shellHtml = $shellHtml -replace '<head>', "<head>`n<base href=`"data/site/`">"
  }
  [System.IO.File]::WriteAllText((P 'index.html'), $shellHtml, $enc)
  [System.IO.File]::WriteAllText((P 'overview.html'), $shellHtml, $enc)
  OK 'index.html / overview.html（根入口 → data\site 的档案站首页）'
}
Info "打开：data\_tmp\<名称>.generated.html（源文件含占位符，不能直接双击）"
