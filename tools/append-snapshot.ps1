# append-snapshot.ps1 — 按「date+repo 最大 round +1」写入当天快照，日期强制 ISO 8601
#
# 为什么需要它：快照原来由 Agent 手写 JSONL，round 靠手填、日期可能被 [string] 成
#   10/14/2026 23:21:44；2026-10-24 两批采集都写 round=1，撞出 2 条唯一键重复。
#   本脚本把「取 round、ISO 化、唯一键检查」收进一个入口，避免再靠记忆。
#
# 用法：
#   .\tools\append-snapshot.ps1 -From rows.jsonl                 # dry-run：只打印计划
#   .\tools\append-snapshot.ps1 -From rows.jsonl -Apply          # 实际追加
#   .\tools\append-snapshot.ps1 -From rows.jsonl -Date 2026-10-24 -CapturedAt 2026-10-24T16:10:00+08:00 -Apply
#   rows.jsonl 每行：{ full_name, stars, forks?, created_at?, pushed_at?, captured_at? }
#
# 退出码：0 成功（dry-run 也算）；1 数据不合法；2 参数/文件错误
param(
  [Parameter(Mandatory=$true)][string]$From,
  [string]$Date = (Get-Date).ToString('yyyy-MM-dd'),
  [string]$CapturedAt = '',
  [switch]$Apply,
  [switch]$Json
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
function Fail([string]$msg) { if ($Json) { Write-Output (@{ ok = $false; error = $msg } | ConvertTo-Json -Compress) } else { Write-Host "✗ $msg" -ForegroundColor Red }; exit 1 }

if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { Fail "日期格式应为 YYYY-MM-DD：$Date" }
if (-not (Test-Path $From)) { Fail "找不到输入文件：$From" }

function To-Iso([object]$v, [string]$field, [string]$default) {
  if ($null -eq $v -or [string]$v -eq '') { return $default }
  if ($v -is [datetime]) { return $v.ToString('yyyy-MM-ddTHH:mm:ssZ') }
  $s = [string]$v
  if ($s -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') { return $s }
  if ($s -match '^(\d{1,2})/(\d{1,2})/(\d{4}) (\d{2}):(\d{2}):(\d{2})$') {
    return ('{0}-{1:D2}-{2:D2}T{3}:{4}:{5}Z' -f $Matches[3], $Matches[1], $Matches[2], $Matches[4], $Matches[5], $Matches[6])
  }
  Fail "日期格式无法识别：$field=$s（只接受 ISO 8601 或 M/d/yyyy H:mm:ss）"
}

$raw = Get-Content $From -Raw -Encoding UTF8
$rows = @()
try {
  if ($raw.TrimStart().StartsWith('[')) { $rows = @($raw | ConvertFrom-Json) }
  else { $rows = @($raw -split "`r?`n" | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
} catch { Fail "输入不是合法 JSON/JSONL：$($_.Exception.Message)" }
if ($rows.Count -eq 0) { Fail '输入为空' }

$snapPath = P "data\snapshots\$Date.jsonl"
$existing = @()
if (Test-Path $snapPath) { $existing = @(Get-Content $snapPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
$maxByRepo = @{}
foreach ($e in $existing) {
  $r = [int]$e.round
  $fn = [string]$e.full_name
  if (-not $maxByRepo.ContainsKey($fn) -or $r -gt $maxByRepo[$fn]) { $maxByRepo[$fn] = $r }
}

$capDefault = if ($CapturedAt) { $CapturedAt } else { (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz') }
$plan = @()
foreach ($row in $rows) {
  $fn = [string]$row.full_name
  if ($fn -notmatch '^[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+$') { Fail "full_name 非法：$fn" }
  $starsRaw = $row.stars
  if ($null -eq $starsRaw -or [string]$starsRaw -notmatch '^\d+$') { Fail "stars 必须是非负整数：$fn" }
  $forks = if ($null -ne $row.forks -and [string]$row.forks -match '^\d+$') { [int]$row.forks } else { $null }
  $created = To-Iso $row.created_at 'created_at' ''
  $pushed  = To-Iso $row.pushed_at  'pushed_at'  ''
  $cap     = To-Iso $row.captured_at 'captured_at' $capDefault
  $next = if ($maxByRepo.ContainsKey($fn)) { $maxByRepo[$fn] + 1 } else { 1 }
  $maxByRepo[$fn] = $next
  $plan += [pscustomobject][ordered]@{ date = $Date; round = $next; full_name = $fn; stars = [int]$starsRaw; forks = $forks; created_at = $created; pushed_at = $pushed; captured_at = $cap }
}

# 写前唯一键（date+full_name+round），按构造不可能重复，仍检查一遍防逻辑漂移
$keys = @{}
foreach ($p in $plan) {
  $k = "$($p.date)|$($p.full_name)|$($p.round)"
  if ($keys.ContainsKey($k)) { Fail "唯一键重复：$k" }
  $keys[$k] = $true
}

if ($Json) {
  Write-Output (@{ ok = $true; date = $Date; count = $plan.Count; apply = [bool]$Apply; rows = $plan; out = $snapPath } | ConvertTo-Json -Depth 6 -Compress)
} else {
  Write-Host ("快照计划：{0} 行 → {1}{2}" -f $plan.Count, $snapPath, $(if ($Apply) { '（写入）' } else { '（dry-run）' })) -ForegroundColor Cyan
  foreach ($p in $plan) { Write-Host ("  {0}  round={1}  stars={2}  captured={3}" -f $p.full_name, $p.round, $p.stars, $p.captured_at) }
}

if (-not $Apply) { exit 0 }

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $snapPath) | Out-Null
$text = ($plan | ForEach-Object { $_ | ConvertTo-Json -Compress }) -join "`r`n"
[IO.File]::AppendAllText($snapPath, $text + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
if (-not $Json) { Write-Host '✅ 已追加' -ForegroundColor Green }

# 写后立刻校验（重复键 / 日期格式 / 枚举）
$v = & (P 'tools\validate-lib.ps1') *>&1
if ($LASTEXITCODE -ne 0) { $v | Out-Host; Fail '写入后 validate-lib 未通过' }
exit 0