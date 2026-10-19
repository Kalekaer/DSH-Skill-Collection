# reconcile.ps1 — 跨存储对账 + append 重复检测（只读）
#
# 检查：
#   1. picks S/A（排除 over_quota）↔ recommend-log.csv 已推荐
#   2. 日报正文（主日报 + 第二轮 + 3rd + 图像专题）↔ CSV 已推荐
#   3. picks / CSV / snapshots / events / meta 的重复键
#   4. 可选：-SheetCsv <导出的 Univer CSV> ↔ CSV（全部行，含淘汰）
#
# 特例：
#   - 2026-10-11 没有 picks，8 条推荐只在 CSV/日报/Univer（架构文档记录的兜底）
#   - 图像专题 5 条（2026-10-12）算推荐，方向=图像专题
#   - snapshots 同日多轮用 `date+full_name+round` 区分（2026-10-19 起 round 必填）；
#     这里只报重复键与缺 round 的行
#
# 用法：
#   .\tools\reconcile.ps1
#   .\tools\reconcile.ps1 -Json
#   .\tools\reconcile.ps1 -SheetCsv data\_tmp\recommend-sheet.csv
#   .\tools\reconcile.ps1 -SheetJson data\_tmp\sheet-63.json
# 退出码：0 = 无差异；1 = 有差异/重复

param(
  [string]$SheetCsv = '',
  [string]$SheetJson = '',
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
function JL($r) {
  if (-not (Test-Path (P $r))) { return @() }
  @([IO.File]::ReadAllLines((P $r), [Text.Encoding]::UTF8) | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
}

$picks = @()
Get-ChildItem (P 'data\picks') -Filter *.jsonl | ForEach-Object {
  $d = $_.BaseName
  foreach ($p in (Get-Content $_.FullName -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })) {
    $p | Add-Member -NotePropertyName _date -NotePropertyValue $d -Force
    $picks += $p
  }
}
$csv = @(Import-Csv (P 'data\recommend-log.csv'))

# 日报 S/A 条目
$reportItems = @()
Get-ChildItem (P 'reports') -Filter '2026-10-*.md' | ForEach-Object {
  $date = if ($_.BaseName -match '^(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $_.BaseName }
  $section = ''
  foreach ($line in (Get-Content $_.FullName -Encoding UTF8)) {
    if ($line -match '^#{1,2}\s+(.*)') { $section = $Matches[1]; continue }
    if ($section -notmatch '重点推荐|次级推荐|第二轮补跑|图像专题|精选') { continue }
    if ($line -match '^###\s+\d+\.\s+([^\s·]+)\s+·\s+([SA])\s*档') {
      $reportItems += [pscustomobject]@{ date = $date; repo = $Matches[1]; tier = $Matches[2] }
    } elseif ($line -match '^-\s+\*\*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)\*\*') {
      $reportItems += [pscustomobject]@{ date = $date; repo = $Matches[1]; tier = 'A' }
    }
  }
}
$reportItems = @($reportItems | Sort-Object date, repo -Unique)

$picksSA = @($picks | Where-Object { $_.tier -in @('S','A') -and (-not $_.PSObject.Properties['daily_status'] -or $_.daily_status -ne 'over_quota') })
$picksKeys = @($picksSA | ForEach-Object { "$($_.date)|$($_.full_name)" } | Sort-Object -Unique)
$csvRec = @($csv | Where-Object { $_.状态 -eq '已推荐' })
$csvKeys = @($csvRec | ForEach-Object { "$($_.首次推荐日)|$($_.仓库)" } | Sort-Object -Unique)
$reportKeys = @($reportItems | ForEach-Object { "$($_.date)|$($_.repo)" } | Sort-Object -Unique)

$issues = @()
# 10-11 无 picks 的 8 条是已知兜底
$csvOnlyAllowed = @($csvRec | Where-Object { $_.首次推荐日 -eq '2026-10-11' } | ForEach-Object { "$($_.首次推荐日)|$($_.仓库)" })

function Compare-Set($a, $b, $allowOnlyB, $label) {
  $onlyA = @($a | Where-Object { $b -notcontains $_ })
  $onlyB = @($b | Where-Object { $a -notcontains $_ -and $allowOnlyB -notcontains $_ })
  if ($onlyA.Count) { $script:issues += "$label：A 独有 $($onlyA.Count)（$($onlyA -join ', ')）" }
  if ($onlyB.Count) { $script:issues += "$label：B 独有 $($onlyB.Count)（$($onlyB -join ', ')）" }
}
Compare-Set $picksKeys $csvKeys $csvOnlyAllowed 'picks vs CSV'
# 2026-10-19：演示包/全新库可能还没有 reports/2026-10-*.md —— 没有日报正文就没有可对的对象，
# 直接跳过这一项，而不是把 CSV 全部报成「B 独有」。
if ($reportKeys.Count -gt 0) { Compare-Set $reportKeys $csvKeys @() '日报 vs CSV' }
else { Write-Host '   （reports/ 里还没有 2026-10-*.md：跳过「日报 vs CSV」）' -ForegroundColor DarkGray }

# 重复检测
$dupPicks = @($picks | Group-Object { "$($_.date)|$($_.full_name)" } | Where-Object Count -gt 1)
if ($dupPicks.Count) { $issues += "picks 重复 date+repo：$($dupPicks.Count) 组" }
$dupCsv = @($csv | Group-Object 仓库 | Where-Object Count -gt 1)
if ($dupCsv.Count) { $issues += "CSV 重复仓库：$($dupCsv.Count) 组" }
$snap = @(); Get-ChildItem (P 'data\snapshots') -Filter *.jsonl | ForEach-Object {
  $d = $_.BaseName
  foreach ($line in (Get-Content $_.FullName -Encoding UTF8 | Where-Object { $_.Trim() })) {
    $s = $line | ConvertFrom-Json
    $snap += [pscustomobject]@{ date = $d; repo = $s.full_name; round = [string]$s.round; raw = [string]$line }
  }
}
$snapNoRound = @($snap | Where-Object { -not $_.round })
if ($snapNoRound.Count) { $issues += "snapshots 缺 round：$($snapNoRound.Count) 行" }
$dupSnap = @($snap | Group-Object { "$($_.date)|$($_.repo)|$($_.round)" } | Where-Object Count -gt 1)
if ($dupSnap.Count) { $issues += "snapshots 重复 date+repo+round：$($dupSnap.Count) 组" }
$ev = JL 'data\events.jsonl'
$dupEv = @($ev | Group-Object { "$($_.id)|$($_.date)|$($_.type)|$($_.detail)|$($_.source)" } | Where-Object Count -gt 1)
if ($dupEv.Count) { $issues += "events 完全重复：$($dupEv.Count) 组" }

# 备注写了 B/C/D 档但 tier 为空 = 评测结论没落盘（只看当天，历史存量另有 41 条旧账）
$today = (Get-Date).ToString('yyyy-MM-dd')
$proj = JL 'data\projects.jsonl'
$noteTier = @($proj | Where-Object { [string]$_.first_seen -eq $today -and -not [string]$_.tier -and ([string]$_.note -match '[BCD]\s*档') })
if ($noteTier.Count) { $issues += "备注写了 B/C/D 档但 tier 为空：$($noteTier.Count) 条（$((@($noteTier | ForEach-Object { $_.id })) -join ', ')）" }

# 可选：Univer 导出的 CSV/JSON
if ($SheetCsv -or $SheetJson) {
  $sheet = @()
  if ($SheetJson) {
    $jp = if ([IO.Path]::IsPathRooted($SheetJson)) { $SheetJson } else { P $SheetJson }
    if (-not (Test-Path $jp)) { $issues += "找不到 SheetJson：$SheetJson" }
    else {
      $sheet = @(Get-Content $jp -Raw -Encoding UTF8 | ConvertFrom-Json | ForEach-Object {
          [pscustomobject]@{ 首次推荐日 = [string]$_.date; 仓库 = [string]$_.repo; 档位 = [string]$_.tier; 状态 = [string]$_.status }
        })
    }
  } else {
    $path = if ([IO.Path]::IsPathRooted($SheetCsv)) { $SheetCsv } else { P $SheetCsv }
    if (-not (Test-Path $path)) { $issues += "找不到 SheetCsv：$SheetCsv" }
    else { $sheet = @(Import-Csv $path) }
  }
  if ($sheet.Count) {
    $csvAll = @($csv | ForEach-Object { "$($_.首次推荐日)|$($_.仓库)|$($_.档位)|$($_.状态)" } | Sort-Object -Unique)
    $sheetAll = @($sheet | ForEach-Object { "$($_.首次推荐日)|$($_.仓库)|$($_.档位)|$($_.状态)" } | Sort-Object -Unique)
    Compare-Set $csvAll $sheetAll @() 'CSV vs Univer'
  }
}

if ($Json) {
  [ordered]@{
    picks = $picks.Count; picksSA = $picksSA.Count; csv = $csv.Count; csvRecommended = $csvRec.Count
    report = $reportItems.Count; sheet = if ($SheetCsv) { $sheet.Count } else { $null }
    duplicates = [ordered]@{ picks = $dupPicks.Count; csv = $dupCsv.Count; snapshots = $dupSnap.Count; events = $dupEv.Count }
    issues = $issues
  } | ConvertTo-Json -Depth 4
} else {
  "picks=$($picks.Count) S/A=$($picksSA.Count) ｜ CSV=$($csv.Count) 已推荐=$($csvRec.Count) ｜ 日报 S/A=$($reportItems.Count)"
  if ($issues.Count) { "❌ $($issues.Count) 个问题"; $issues | ForEach-Object { " - $_" }; exit 1 }
  "✅ 跨存储对账 + 重复检测：0 问题"
}
