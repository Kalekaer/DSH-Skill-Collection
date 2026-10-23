# fetch-daily.ps1 — 当天检索的「计划 + 登记」层（**不联网**）
#
# 为什么：检索式以前只活在文档里，Agent 每次手拼 URL、也没有地方存原始返回。
# 现在：
#   1. -PlanOnly（默认）：从 data/queries.json 生成当天该跑的 URL 清单 → data/raw/<date>/r<N>/plan.json
#   2. -Import <Q> -File <json>：把 web_fetch 取回的响应登记成 raw，并更新 meta.json
# 本机直连已被禁止（config.forbid_local_direct_connect），脚本**不发任何网络请求**。
#
# 用法：
#   & .\tools\fetch-daily.ps1 -PlanOnly
#   & .\tools\fetch-daily.ps1 -Date 2026-10-23 -PlanOnly
#   & .\tools\fetch-daily.ps1 -Import Q2b -File data\_tmp\q2b.json
#   & .\tools\fetch-daily.ps1 -PlanOnly -Json
#
# 退出码：0 = 正常；1 = 参数/文件问题；2 = 真源缺失

param(
  [string]$Date = '',
  [int]$Round = 0,
  [switch]$PlanOnly,
  [string]$Import = '',
  [string]$File = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
$enc = New-Object System.Text.UTF8Encoding($false)

if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { Write-Host "✗ 日期格式：$Date" -ForegroundColor Red; exit 1 }

$specPath = P 'data\queries.json'
if (-not (Test-Path $specPath)) { Write-Host '✗ 缺 data/queries.json' -ForegroundColor Red; exit 2 }
$spec = Get-Content $specPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-IsoWeekday([datetime]$d) { $n = [int]$d.DayOfWeek; if ($n -eq 0) { 7 } else { $n } }
$dt = [datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
$wd = [string](Get-IsoWeekday $dt)
$dayCfg = $spec.weekdays.$wd
if (-not $dayCfg) { Write-Host "✗ queries.json 缺星期 $wd" -ForegroundColor Red; exit 2 }

function Resolve-Q([string]$q) {
  $q = $q.Replace('{D7}', $dt.AddDays(-7).ToString('yyyy-MM-dd'))
  $q = $q.Replace('{D14}', $dt.AddDays(-14).ToString('yyyy-MM-dd'))
  $q = $q.Replace('{D30}', $dt.AddDays(-30).ToString('yyyy-MM-dd'))
  $q = $q.Replace('{TODAY_TOPIC}', [string]$dayCfg.topic)
  $q = $q.Replace('{TODAY_TOPIC2}', [string]$dayCfg.topic2)
  return $q
}

function Build-Url($item) {
  $q = Resolve-Q $item.q
  $u = 'https://api.github.com/search/repositories?q=' + ($q.Replace(' ', '+').Replace('>', '%3E'))
  if ($item.sort) { $u += "&sort=$($item.sort)&order=$($item.order)" }
  if ($item.per_page) { $u += "&per_page=$($item.per_page)" }
  return $u
}

# ---------- 组当天计划 ----------
function New-Plan {
  $items = @()
  foreach ($q in $spec.queries) {
    if ($q.enabled -eq $false) { continue }
    $freq = [string]$q.frequency
    $take = $false
    if ($freq -eq 'daily') { $take = $true }
    elseif ($freq -eq 'conditional') { $take = $true }
    elseif ($freq -match '^weekly:(.+)$') { $take = (@($Matches[1].Split(',')) -contains $wd) }
    elseif ($freq -eq 'manual') { $take = $false }
    if (-not $take) { continue }

    $isCond = ($freq -eq 'conditional')
    $items += [ordered]@{
      id          = [string]$q.id
      name        = [string]$q.name
      kind        = if ($isCond) { 'conditional' } elseif ($q.mode -eq 'probe') { 'probe' } else { 'search' }
      url         = if ($q.mode -eq 'search') { Build-Url $q } else { '' }
      per_page    = [int]$q.per_page
      required    = [bool]$q.required
      conditional = if ($isCond) { $q.when } else { $null }
    }
  }
  # 计划里永远包含 Q3s 的条件说明；是否真的跑由 coverage 判定
  return $items
}

function Get-RoundDir([int]$r) { P ("data\raw\{0}\r{1}" -f $Date, $r) }
function Get-MaxRound {
  $base = P ("data\raw\{0}" -f $Date)
  if (-not (Test-Path $base)) { return 0 }
  $dirs = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^r(\d+)$' }
  if (-not $dirs) { return 0 }
  return ($dirs | ForEach-Object { [int]($_.Name -replace '^r', '') } | Measure-Object -Maximum).Maximum
}

# ---------- Import ----------
function Extract-Json([string]$text) {
  $a = $text.IndexOf('{'); $b = $text.LastIndexOf('}')
  if ($a -lt 0 -or $b -le $a) { throw '文件里找不到 JSON' }
  return $text.Substring($a, $b - $a + 1)
}

if ($Import) {
  if (-not $File) { Write-Host '✗ -Import 需要 -File' -ForegroundColor Red; exit 1 }
  $fp = if ([IO.Path]::IsPathRooted($File)) { $File } else { P $File }
  if (-not (Test-Path $fp)) { Write-Host "✗ 找不到 $fp" -ForegroundColor Red; exit 1 }
  $raw = [IO.File]::ReadAllText($fp, [Text.Encoding]::UTF8)
  $resp = $null
  try { $resp = Extract-Json $raw | ConvertFrom-Json } catch { }
  $r = if ($Round -gt 0) { $Round } else { $max = Get-MaxRound; if ($max -eq 0) { 1 } else { $max } }
  $dir = Get-RoundDir $r
  New-Item -ItemType Directory -Force -Path $dir | Out-Null

  $ok = ($resp -and $resp.PSObject.Properties['items'])
  $items = if ($ok) { @($resp.items) } else { @() }

  # attempt 自增：同一 Q 重试不覆盖旧文件（raw 只增不改）
  $metaPath = Join-Path $dir 'meta.json'
  $meta = if (Test-Path $metaPath) { Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{ date = $Date; round = $r; imports = @() } }
  $list = @($meta.imports)
  $prev = @($list | Where-Object { [string]$_.id -eq $Import })
  $next = 1
  if ($prev.Count) { $next = ([int](($prev | ForEach-Object { [int]$_.attempt }) | Measure-Object -Maximum).Maximum) + 1 }
  $fileName = if ($ok) { "$Import.$next.json" } else { "$Import.$next.error.json" }
  if ($ok) {
    [IO.File]::WriteAllText((Join-Path $dir $fileName), ($resp | ConvertTo-Json -Depth 20 -Compress), $enc)
  } else {
    [IO.File]::WriteAllText((Join-Path $dir $fileName), $raw.Substring(0, [Math]::Min(2000, $raw.Length)), $enc)
  }
  $newFaces = $null
  if ($ok -and $Import -eq 'Q3') {
    $seen = @{}
    if (Test-Path (P 'data\seen.jsonl')) { foreach ($line in (Get-Content (P 'data\seen.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() })) { try { $o = $line | ConvertFrom-Json; $seen[([string]$o.full_name).ToLower()] = 1 } catch { } } }
    $newFaces = @($items | Where-Object { -not $seen.ContainsKey(([string]$_.full_name).ToLower()) }).Count
  }
  $list += [pscustomobject]@{
    id = $Import; attempt = $next; at = (Get-Date).ToString('s'); ok = [bool]$ok
    items = $items.Count; total_count = if ($ok) { [int]$resp.total_count } else { $null }
    newFaces = $newFaces
    file = $fileName
  }
  $meta | Add-Member -NotePropertyName imports -NotePropertyValue $list -Force
  [IO.File]::WriteAllText($metaPath, ($meta | ConvertTo-Json -Depth 8), $enc)

  if ($Json) { [ordered]@{ ok = $ok; id = $Import; round = $r; items = $items.Count } | ConvertTo-Json -Compress }
  if ($ok) { Write-Host ("✓ 已登记 {0}：{1} 条 → {2}" -f $Import, $items.Count, (Split-Path $dir -Leaf)) -ForegroundColor Green }
  else { Write-Host ("✗ {0} 不是合法的 search 响应（缺 items）→ 已记 error" -f $Import) -ForegroundColor Red; exit 1 }
  exit 0
}

# ---------- PlanOnly ----------
$r = if ($Round -gt 0) { $Round } else {
  $max = Get-MaxRound
  if ($max -eq 0) { 1 }
  else {
    $dir = Get-RoundDir $max
    $hasRaw = @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^Q\d|^Q[0-9]' }).Count -gt 0
    if ($hasRaw) { $max + 1 } else { $max }
  }
}
$dir = Get-RoundDir $r
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$planPath = Join-Path $dir 'plan.json'
$items = New-Plan
$plan = [ordered]@{
  date = $Date; round = $r; weekday = [int]$wd
  topic = [string]$dayCfg.topic; topic2 = [string]$dayCfg.topic2
  generated_at = (Get-Date).ToString('s')
  items = $items
}
[IO.File]::WriteAllText($planPath, ($plan | ConvertTo-Json -Depth 8), $enc)

if ($Json) { $plan | ConvertTo-Json -Depth 8; exit 0 }
Write-Host ("计划 {0} · r{1} · 周{2} · topic={3}" -f $Date, $r, $wd, $dayCfg.topic) -ForegroundColor Cyan
foreach ($i in $items) {
  Write-Host ("  [{0}] {1}  {2}" -f $i.id, $(if ($i.kind -eq 'search') { '搜索' } elseif ($i.kind -eq 'probe') { '实验' } else { '条件' }), $(if ($i.url) { $i.url } else { '—' }))
}
Write-Host ("→ {0}" -f $planPath) -ForegroundColor DarkGray
