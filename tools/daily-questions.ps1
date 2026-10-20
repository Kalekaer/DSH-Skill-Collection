# daily-questions.ps1 — 收尾只输出「真需要拍板」的问题（2026-10-20 改）
#
# 旧版会凑 3–6 条（核 README / 补词表 / 批同义词 / 补人话层 …）让用户点菜；
# 现在这些能自动做完的直接做完，写进运行日志，不再问。
# 只剩两类值得打断用户：
#   ① 今天主推荐里风险等级「高」的项目，要不要先看风险说明再决定用不用；
#   ② 发版 / 删数据 / 花钱 / 红线例外 —— 这类由 Agent 在发生时当面问，不由本脚本凑。
# 输出为空 = 别问。
#
# 用法：
#   & ".\tools\daily-questions.ps1"
#   & ".\tools\daily-questions.ps1" -Date 2026-10-13

param(
  [string]$Date = '',
  [int]$Max = 1
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }

$q = @()

# ---- 唯一来源：今天主推荐（S/A）里风险「高」的 ----
$picksPath = P "data\picks\$Date.jsonl"
if (Test-Path $picksPath) {
  $picks = @()
  foreach ($l in (Get-Content $picksPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $picks += ($l | ConvertFrom-Json) } catch { $null = $_ }
  }
  $high = @($picks | Where-Object { $_.tier -in @('S', 'A') -and $_.risk -eq '高' })
  if ($high.Count) {
    $names = ($high | ForEach-Object { $_.full_name }) -join '、'
    $q += "主推荐里 $($high.Count) 条风险「高」：$names。**要不要先看风险说明，再决定用不用？**"
  }
}

# ---- 输出 ----
Write-Host ""
Write-Host "=== $Date 需要拍板（有就 1 条，没有就别问）===" -ForegroundColor Cyan
Write-Host ""
if (-not $q.Count) {
  Write-Host "  没有需要拍板的事。别问，直接说结果。" -ForegroundColor DarkGray
  exit 0
}
$i = 0
foreach ($item in ($q | Select-Object -First ([Math]::Max(1, $Max)))) {
  $i++
  Write-Host ("  {0}. {1}" -f $i, $item) -ForegroundColor Gray
}
Write-Host ""
Write-Host "  规则：只问这一条；其余自动做完写进运行日志。" -ForegroundColor DarkGray
