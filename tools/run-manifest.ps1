# run-manifest.ps1 — 日报七件事的运行清单（只写 data/runs/<date>.manifest.json）
#
# 为什么：七件事顺序写、没有事务；清单记录每一步是 ok / fail / pending，
# 失败时能看出“写到哪一步”，恢复时不用靠猜。
#
# 用法：
#   .\tools\run-manifest.ps1 -Init                 # 开工：建清单
#   .\tools\run-manifest.ps1 -Mark report -Status ok
#   .\tools\run-manifest.ps1 -Mark picks -Status fail -Note "写盘失败"
#   .\tools\run-manifest.ps1 -Sync                 # 收工：按文件推断状态
#   .\tools\run-manifest.ps1 -Show                 # 只看
# 退出码：0 = 正常；1 = 有 fail 步骤

param(
  [string]$Date = '',
  [switch]$Init,
  [string]$Mark = '',
  [ValidateSet('ok', 'fail', 'skipped', 'pending', 'unknown')]
  [string]$Status = 'ok',
  [string]$Note = '',
  [switch]$Sync,
  [switch]$Show
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { Write-Host "✗ 日期格式应为 YYYY-MM-DD：$Date" -ForegroundColor Red; exit 1 }

$steps = @('backup', 'queries', 'report', 'snapshot', 'seen', 'index', 'csv', 'picks', 'univer', 'build')
$mp = P "data\runs\$Date.manifest.json"
$m = $null
if (Test-Path $mp) { try { $m = Get-Content $mp -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $m = $null } }
if ($m) {
  # ConvertFrom-Json 的 steps 是 PSObject，转成 hashtable 才能按步骤名读写
  $sh = @{}
  foreach ($p in $m.steps.PSObject.Properties) { $sh[$p.Name] = $p.Value }
  $m | Add-Member -NotePropertyName steps -NotePropertyValue $sh -Force
}
if ($m) { foreach ($s in $steps) { if (-not $m.steps.ContainsKey($s)) { $m.steps[$s] = [ordered]@{ status = 'pending'; at = $null; note = 'added' } } } }
if ($Init -or -not $m) {
  $m = [ordered]@{ date = $Date; started_at = (Get-Date).ToString('o'); updated_at = (Get-Date).ToString('o'); steps = [ordered]@{} }
  foreach ($s in $steps) { $m.steps[$s] = [ordered]@{ status = 'pending'; at = $null; note = '' } }
  # 2026-10-19：发布包不带 data/runs/，直接写会报 "Could not find a part of the path"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $mp) | Out-Null
  [IO.File]::WriteAllText($mp, ($m | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
  Write-Host "✅ 清单已建：$mp" -ForegroundColor Green
  if ($Init) { exit 0 }
}
if ($Mark) {
  if ($steps -notcontains $Mark) { Write-Host "✗ 未知步骤：$Mark（可用：$($steps -join ', ')）" -ForegroundColor Red; exit 1 }
  $m.steps[$Mark] = [ordered]@{ status = $Status; at = (Get-Date).ToString('o'); note = $Note }
  $m.updated_at = (Get-Date).ToString('o')
  [IO.File]::WriteAllText($mp, ($m | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
}
if ($Sync) {
  $report = Test-Path (P "reports\$Date.md")
  $snap = Test-Path (P "data\snapshots\$Date.jsonl")
  $seenTxt = if (Test-Path (P 'data\seen.jsonl')) { Get-Content (P 'data\seen.jsonl') -Raw -Encoding UTF8 } else { '' }
  $seen = $seenTxt -match ('"last_seen":"' + [regex]::Escape($Date) + '"')
  $index = if (Test-Path (P 'reports\index.md')) { (Get-Content (P 'reports\index.md') -Raw -Encoding UTF8) -match ('\| ' + [regex]::Escape($Date) + ' \|') } else { $false }
  $csv = $false
  if (Test-Path (P 'data\recommend-log.csv')) { $csv = @(Import-Csv (P 'data\recommend-log.csv') | Where-Object { $_.首次推荐日 -eq $Date }).Count -gt 0 }
  $picks = Test-Path (P "data\picks\$Date.jsonl")
  $backup = Test-Path (P "data\_backup\$Date\pre-daily\manifest.json")
  $build = $picks -and ((Get-Item (P 'data\site\daily-layout-c-finsara.generated.html') -ErrorAction SilentlyContinue).LastWriteTime -gt (Get-Item (P "data\picks\$Date.jsonl")).LastWriteTime)
  $covPath = P "data\raw\$Date\coverage.json"
  $covStatus = ''
  if (Test-Path $covPath) { try { $covStatus = [string](Get-Content $covPath -Raw -Encoding UTF8 | ConvertFrom-Json).status } catch { $covStatus = '' } }
  $map = [ordered]@{ backup = $backup; report = $report; snapshot = $snap; seen = $seen; index = $index; csv = $csv; picks = $picks; build = $build; queries = ($covStatus -eq 'pass' -or $covStatus -eq 'warn') }
  foreach ($k in $map.Keys) {
    if ($steps -notcontains $k) { continue }
    if ($m.steps[$k].status -eq 'fail') { continue }   # 人工标 fail 不覆盖
    $m.steps[$k] = [ordered]@{ status = $(if ($map[$k]) { 'ok' } else { 'pending' }); at = (Get-Date).ToString('o'); note = 'sync' }
  }
  if ($covStatus) { $m.steps['queries'] = [ordered]@{ status = $(if ($covStatus -eq 'fail') { 'fail' } else { 'ok' }); at = (Get-Date).ToString('o'); note = "coverage: $covStatus" } }
  $m.updated_at = (Get-Date).ToString('o')
  [IO.File]::WriteAllText($mp, ($m | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
  # 2026-10-24：硬门禁——收工前跑数据契约校验；重复键 / 日期格式 / 枚举越界都别带着走
  $vOut = & (P 'tools\validate-lib.ps1') *>&1
  $vOut | Out-Host
  if ($LASTEXITCODE -ne 0) {
    Write-Host '✗ 数据契约校验未通过（validate-lib），先修再收工' -ForegroundColor Red
    exit 1
  }
}
if (-not $Init -and -not $Sync -and -not $Mark -or $Show) {
  Write-Host "== 清单 $Date ==" -ForegroundColor Cyan
  foreach ($k in $steps) {
    $st = $m.steps[$k]
    $color = switch ($st.status) { 'ok' { 'Green' } 'fail' { 'Red' } 'skipped' { 'Yellow' } default { 'DarkGray' } }
    Write-Host ("  {0,-9} {1,-8} {2}" -f $k, $st.status, $st.note) -ForegroundColor $color
  }
}
$bad = @($steps | Where-Object { $m.steps[$_].status -eq 'fail' })
if ($bad.Count) { exit 1 }