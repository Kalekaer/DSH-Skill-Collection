# check-queries.ps1 — 检索式的静态一致性 + 当天覆盖检查
#
# 两种模式：
#   -Static           文档与 data/queries.json 是否一致；config.json 的星期/调用区间是否对得上
#   -Date <date>      当天该跑的 Q 是否都登记了 raw（data/raw/<date>/r<N>/）
#   -Date <date> -Strict  覆盖为 fail 时退出码 1（默认 fail 也退出 1；warn 退出 2）
#
# 覆盖判定：
#   ok       = 有成功的 raw
#   failed   = 有登记但响应缺 items（403/错误页）
#   missing  = 该跑、但完全没有登记
#   skipped  = 条件未触发 / 实验位 / manual
#
# 退出码：0 = pass；1 = fail；2 = warn；3 = 参数/真源错误

param(
  [string]$Date = '',
  [switch]$Static,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
$enc = New-Object System.Text.UTF8Encoding($false)

if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
$specPath = P 'data\queries.json'
if (-not (Test-Path $specPath)) { Write-Host '✗ 缺 data/queries.json' -ForegroundColor Red; exit 3 }
$spec = Get-Content $specPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ---------- 静态 ----------
if ($Static) {
  $issues = @()
  $gen = & (P 'tools\gen-query-docs.ps1') -Check *>&1
  if ($LASTEXITCODE -ne 0) { $issues += ('文档与 queries.json 不一致：' + (($gen | Select-Object -Last 1) -replace '^✗ ', '')) }

  $cfg = Get-Content (P 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $names = @{ '1' = '周一'; '2' = '周二'; '3' = '周三'; '4' = '周四'; '5' = '周五'; '6' = '周六'; '7' = '周日' }
  foreach ($k in @('1', '2', '3', '4', '5', '6', '7')) {
    $a = [string]$spec.weekdays.$k.topic
    $b = [string]$cfg.sources.topics_by_weekday.($names[$k])
    if ($a -ne $b) { $issues += ("星期表不一致：周{0} queries={1} config={2}" -f $k, $a, $b) }
  }
  $daily = @($spec.queries | Where-Object { $_.frequency -eq 'daily' }).Count
  if ([int]$cfg.sources.search_min_calls -ne $daily) { $issues += ("config.search_min_calls={0}，实际 daily={1}" -f $cfg.sources.search_min_calls, $daily) }
  $maxExtra = 0
  foreach ($k in @('1', '2', '3', '4', '5', '6', '7')) { $n = @($spec.weekdays.$k.extras).Count; if ($n -gt $maxExtra) { $maxExtra = $n } }
  $maxPossible = $daily + $maxExtra + 1   # +1 给条件查询 Q3s
  if ([int]$cfg.sources.search_max_calls -lt $maxPossible) { $issues += ("config.search_max_calls={0}，最多可能需要 {1}" -f $cfg.sources.search_max_calls, $maxPossible) }

  if ($Json) { [ordered]@{ ok = ($issues.Count -eq 0); issues = $issues } | ConvertTo-Json -Compress }
  if ($issues.Count) { $issues | ForEach-Object { Write-Host "✗ $_" -ForegroundColor Red }; exit 1 }
  Write-Host '✓ 静态一致：文档 / 星期表 / 调用区间' -ForegroundColor Green
  exit 0
}

# ---------- 覆盖 ----------
if ($Date -lt [string]$spec.enforce_from) {
  if ($Json) { [ordered]@{ date = $Date; status = 'skipped'; reason = "早于 enforce_from $($spec.enforce_from)" } | ConvertTo-Json -Compress }
  Write-Host ("↷ {0} 早于 enforce_from（{1}），跳过覆盖检查" -f $Date, $spec.enforce_from) -ForegroundColor DarkGray
  exit 0
}

$base = P ("data\raw\{0}" -f $Date)
if (-not (Test-Path $base)) {
  if ($Json) { [ordered]@{ date = $Date; status = 'fail'; reason = '没有 raw 目录（当天计划未生成）' } | ConvertTo-Json -Compress }
  Write-Host ("✗ {0} 没有 data/raw 目录 —— 当天计划没生成，视为漏跑" -f $Date) -ForegroundColor Red
  exit 1
}
$rounds = Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^r(\d+)$' } | Sort-Object { [int]($_.Name -replace '^r', '') }
$roundDir = $null
for ($i = $rounds.Count - 1; $i -ge 0; $i--) { if (Test-Path (Join-Path $rounds[$i].FullName 'plan.json')) { $roundDir = $rounds[$i]; break } }
if (-not $roundDir) {
  Write-Host ("✗ {0} 没有 plan.json" -f $Date) -ForegroundColor Red
  exit 1
}
$plan = Get-Content (Join-Path $roundDir.FullName 'plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$metaPath = Join-Path $roundDir.FullName 'meta.json'
$imports = @()
if (Test-Path $metaPath) { $imports = @((Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json).imports) }
$byId = @{}
foreach ($m in $imports) {
  $id = [string]$m.id
  $cur = $byId[$id]
  if (-not $cur) { $byId[$id] = $m; continue }
  if ([bool]$m.ok -and -not [bool]$cur.ok) { $byId[$id] = $m; continue }
  if ([bool]$m.ok -eq [bool]$cur.ok -and [int]$m.attempt -gt [int]$cur.attempt) { $byId[$id] = $m }
}

# 新面孔（用于 Q3s 判定）
$seen = @{}
$seenPath = P 'data\seen.jsonl'
if (Test-Path $seenPath) { foreach ($line in (Get-Content $seenPath -Encoding UTF8 | Where-Object { $_.Trim() })) { try { $o = $line | ConvertFrom-Json; $seen[([string]$o.full_name).ToLower()] = 1 } catch { } } }

$results = @()
$fail = 0; $warn = 0
foreach ($it in @($plan.items)) {
  $id = [string]$it.id
  $m = $byId[$id]
  $isCond = ($it.kind -eq 'conditional')
  $condMet = $false; $condWhy = ''

  if ($isCond) {
    $q3 = $byId['Q3']
    if ($q3 -and $q3.ok) {
      $q3file = Join-Path $roundDir.FullName ([string]$q3.file)
      if (Test-Path $q3file) {
        $q3json = Get-Content $q3file -Raw -Encoding UTF8 | ConvertFrom-Json
        $newFaces = if ($null -ne $q3.newFaces) { [int]$q3.newFaces } else { @($q3json.items | Where-Object { -not $seen.ContainsKey(([string]$_.full_name).ToLower()) }).Count }
        $total = if ($null -ne $q3.total_count) { [int]$q3.total_count } else { [int]$q3json.total_count }
        $condMet = ($newFaces -lt 3) -or ($total -lt 10)
        $condWhy = "Q3 newFaces=$newFaces total=$total"
      }
    } else { $condWhy = 'Q3 未成功，条件无法评估' }
  }

  $st = 'missing'
  if ($isCond) {
    if ($condMet) { $st = if ($m -and $m.ok) { 'ok' } elseif ($m) { 'failed' } else { 'missing' } }
    else { $st = 'skipped' }
  } elseif ($it.kind -eq 'probe') {
    $st = if ($m -and $m.ok) { 'ok' } else { 'skipped' }
  } else {
    if ($m -and $m.ok) { $st = 'ok' } elseif ($m) { $st = 'failed' } else { $st = 'missing' }
  }

  if ($st -eq 'missing' -and [bool]$it.required) { $fail++ }
  if ($st -eq 'failed') { $warn++ }
  $results += [ordered]@{ id = $id; status = $st; required = [bool]$it.required; reason = $(if ($isCond) { $condWhy } else { '' }) }
}

$status = if ($fail -gt 0) { 'fail' } elseif ($warn -gt 0) { 'warn' } else { 'pass' }
$cov = [ordered]@{
  date = $Date; round = [int]$plan.round; status = $status
  fail = $fail; warn = $warn
  queries = $results
  checked_at = (Get-Date).ToString('s')
}
[IO.File]::WriteAllText((Join-Path $base 'coverage.json'), ($cov | ConvertTo-Json -Depth 6), $enc)

if ($Json) { $cov | ConvertTo-Json -Depth 6; exit $(if ($status -eq 'fail') { 1 } elseif ($status -eq 'warn') { 2 } else { 0 }) }
switch ($status) {
  'pass' { Write-Host ("✓ 覆盖 pass：r{0}，{1} 条查询" -f $plan.round, $results.Count) -ForegroundColor Green; exit 0 }
  'warn' { Write-Host ("⚠ 覆盖 warn：{0} 条失败（日报需标「数据不完整」）" -f $warn) -ForegroundColor Yellow; exit 2 }
  default {
    Write-Host ("✗ 覆盖 fail：{0} 条必跑未登记" -f $fail) -ForegroundColor Red
    $results | Where-Object { $_.status -eq 'missing' -and $_.required } | ForEach-Object { Write-Host ("   - {0}" -f $_.id) }
    exit 1
  }
}
