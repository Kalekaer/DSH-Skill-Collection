# weekly-check.ps1 — 周报巡检（2026-10-20）
#
# 目的：把以前「问用户」的收尾杂事，改成周报时由 AI 统一检查、统一处理。
# 本脚本只读：只报告状态和建议动作，不写任何数据。
#
# 处理原则（写进 SKILL 的周报段）：
#   - 能自动做完的：直接做，写进运行日志，不问用户。
#   - 只有三类需要人：删数据、超额 API 花费、红线例外。
#
# 用法：& ".\tools\weekly-check.ps1"
# 退出码：0 正常；1 有读取失败

param([string]$Date = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
$start = ([datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).AddDays(-6)).ToString('yyyy-MM-dd')
$days = @(0..6 | ForEach-Object { ([datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).AddDays($_ - 6)).ToString('yyyy-MM-dd') })

function Lines([string]$rel) {
  $p = P $rel
  if (-not (Test-Path $p)) { return 0 }
  return @(Get-Content $p -Encoding UTF8 | Where-Object { $_.Trim() }).Count
}
function JsonLines([string]$rel) {
  $p = P $rel
  $out = @()
  if (-not (Test-Path $p)) { return $out }
  foreach ($l in (Get-Content $p -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $out += ($l | ConvertFrom-Json) } catch { $null = $_ }
  }
  return $out
}

$proj = JsonLines 'data\projects.jsonl'
$auto = @()
$ask = @()

# ---------- 1. 人话层缺口 ----------
$miss = @($proj | Where-Object { $_.human.status -eq 'missing' })
$part = @($proj | Where-Object { $_.human.status -eq 'partial' })
if ($miss.Count + $part.Count -gt 0) {
  $auto += "人话层：缺 $($miss.Count) 条、半条 $($part.Count) 条 → 用库内现成描述补，每次最多 5 条（0 额度）"
}

# ---------- 2. 同义词待批 ----------
$syn = JsonLines 'data\human\synonym-suggestions.jsonl'
$synPend = @($syn | Where-Object { $_.status -ne 'approved' -and $_.status -ne 'rejected' })
if ($synPend.Count) {
  $top = (@($synPend | Sort-Object { [int]$_.count } -Descending | Select-Object -First 5 | ForEach-Object { "$($_.term)($($_.count))" }) -join '、')
  $auto += "同义词：待批 $($synPend.Count) 条 → count ≥ 5 的直接并进最贴近的组（当前最高：$top）"
}

# ---------- 3. 搜不到的缺口 ----------
$gaps = JsonLines 'data\search-gaps.jsonl'
if ($gaps.Count) {
  $zero = @($gaps | Where-Object { [int]$_.hits -le 0 }).Count
  $auto += "缺口词：$($gaps.Count) 个（0 命中 $zero 个）→ 复检后 0 命中的移除，有命中的并入词表"
}

# ---------- 4. 分类 / 方案 待批 ----------
$tax = JsonLines 'data\taxonomy-suggestions.jsonl'
$taxPend = @($tax | Where-Object { $_.status -eq 'pending' })
if ($taxPend.Count) { $auto += "分类建议：$($taxPend.Count) 条待批 → 先跑 tools\taxonomy-guard.ps1；四道闸 PASS 才落，其余记运行日志" }
$plan = JsonLines 'data\plan-suggestions.jsonl'
$planPend = @($plan | Where-Object { $_.status -eq 'pending' -or -not $_.status })
if ($planPend.Count) { $auto += "方案建议：$($planPend.Count) 条 → 工具够 3 个且不重复的自动写进 data/plans.json" }

# ---------- 5. 用户自推缺档位 ----------
$noTier = @($proj | Where-Object { $_.origin -eq 'user' -and $_.tier -notin @('S', 'A', 'B', 'C', 'D') -and $_.status -ne 'dropped' })
if ($noTier.Count) { $auto += "用户自推：$($noTier.Count) 条没档位 → 按 criteria.json 自动评分并落档" }

# ---------- 6. 高风险主推荐 ----------
$high = @()
foreach ($d in $days) {
  $p = P "data\picks\$d.jsonl"
  if (-not (Test-Path $p)) { continue }
  foreach ($l in (Get-Content $p -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $pk = $l | ConvertFrom-Json } catch { continue }
    if ($pk.tier -in @('S', 'A') -and $pk.risk -eq '高') { $high += "$($pk.full_name)@$d" }
  }
}
if ($high.Count) { $auto += "高风险主推荐：$($high.Count) 条 → 周报里给结论（用/不用/观察），不再单条问用户" }

# ---------- 7. 日报 / 运行日志缺日 ----------
$missRep = @($days | Where-Object { -not (Test-Path (P "reports\$_.md")) })
$missRun = @($days | Where-Object { -not (Test-Path (P "data\runs\$_.md")) })
if ($missRep.Count) { $auto += "日报缺 $($missRep.Count) 天：$($missRep -join '、') → 能补就补，补不了写进周报的数据质量段" }
if ($missRun.Count) { $auto += "运行日志缺 $($missRun.Count) 天：$($missRun -join '、') → 同上" }

# ---------- 8. 发布态 ----------
$rel = P 'release\github-daily-picks'
if (Test-Path $rel) {
  $auto += "发布包：跑 check-drift；无异常就同步 + 构建 + 包内 audit + commit；push 前看远端凭据"
}

# ---------- 9. 分类质量抽样 ----------
$otherN = @($proj | Where-Object { $_.category.l1 -eq '其他' }).Count
$otherRate = if ($proj.Count) { [math]::Round(100.0 * $otherN / $proj.Count, 1) } else { 0 }
$seed = [int](($Date -replace '-', ''))
$sample = @($proj | Get-Random -SetSeed $seed -Count ([math]::Min(10, $proj.Count)))
Write-Host ""
Write-Host "  分类抽样（人工复核 10 条）：" -ForegroundColor DarkCyan
foreach ($sp in $sample) { Write-Host ("    {0}  →  {1} / {2}" -f $sp.id, $sp.category.l1, $sp.category.l2) -ForegroundColor DarkGray }
Write-Host ("  「其他」占比：{0}%（{1}/{2}）｜ 复核后把不一致写进周报「数据质量」" -f $otherRate, $otherN, $proj.Count) -ForegroundColor DarkGray
# ---------- 输出 ----------
Write-Host ""
Write-Host "=== 周报巡检 · $start → $Date ===" -ForegroundColor Cyan
Write-Host ""
if (-not $auto.Count) { Write-Host "  没有要处理的。别问，写「一切正常」。" -ForegroundColor DarkGray }
else {
  $i = 0
  foreach ($a in $auto) { $i++; Write-Host ("  {0}. {1}" -f $i, $a) -ForegroundColor Gray }
}
Write-Host ""
Write-Host "  需要人的只有三类：删数据、超额 API 花费、红线例外。" -ForegroundColor DarkGray
Write-Host "  其余全部由 AI 在周报时自动处理，并写进 data/runs。" -ForegroundColor DarkGray
