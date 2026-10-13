# add-intro.ps1 — 批量写入人话层介绍（配合 humanize-next.ps1 使用）
#
# 用法：
#   & ".\tools\add-intro.ps1" -File "data\_batch\2026-10-13-intro.jsonl"      # 预览
#   & ".\tools\add-intro.ps1" -File "..." -Apply -Sync                          # 写入 + 重建
#
# 输入文件：一行一个 JSON，字段与 data/human/repo-intro.jsonl 一致：
#   {"full_name":"owner/repo","one_liner":"...","problem":"...","example":"...",
#    "feature_note":{"是什么":"...","核心功能":[".."],"常见用途":[".."],"使用案例":[".."],"不适合":[".."]},
#    "source":"derived(desc) | api+人工撰写 | 仅台账备注"}
#
# 纪律：
#   * **不覆盖**已有人话层条目（除非 -Force）
#   * 缺字段就缺着（页面会显示「待补全」），**不要为了凑齐 4 项编造**
#   * `source` 必须如实填：能写准就写 `derived(desc)`；只有一句话的就写 `仅台账备注`
param(
  [Parameter(Mandatory=$true)][string]$File,
  [switch]$Apply,
  [switch]$Force,
  [switch]$Sync
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$srcPath = if ([System.IO.Path]::IsPathRooted($File)) { $File } else { P $File }
if (-not (Test-Path $srcPath)) { Write-Host "❌ 找不到输入文件：$srcPath" -ForegroundColor Red; exit 1 }

$existing = @{}
$introPath = P 'data\human\repo-intro.jsonl'
if (Test-Path $introPath) {
  foreach ($l in (Get-Content $introPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $o = $l | ConvertFrom-Json; if ($o.full_name) { $existing[$o.full_name] = $true } } catch {}
  }
}

$rows = @(); $skipped = @(); $bad = @()
foreach ($l in (Get-Content $srcPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  $o = $null
  try { $o = $l | ConvertFrom-Json } catch { $bad += $l.Substring(0, [Math]::Min(40, $l.Length)); continue }
  if (-not $o.full_name) { $bad += '(缺 full_name)'; continue }
  if ($existing.ContainsKey($o.full_name) -and -not $Force) { $skipped += $o.full_name; continue }
  if (-not $o.PSObject.Properties['written_at']) { $o | Add-Member -NotePropertyName written_at -NotePropertyValue (Get-Date).ToString('yyyy-MM-dd') -Force }
  if (-not $o.PSObject.Properties['source']) { $o | Add-Member -NotePropertyName source -NotePropertyValue 'derived(desc)' -Force }
  $rows += ($o | ConvertTo-Json -Compress -Depth 6)
}

Write-Host ""
Write-Host ("=== 待写入 {0} 条 ｜ 跳过（已有）{1} 条 ｜ 解析失败 {2} 条 ===" -f $rows.Count, $skipped.Count, $bad.Count) -ForegroundColor Cyan
if ($skipped.Count) { Write-Host ("  跳过：{0}" -f (($skipped | Select-Object -First 5) -join ', ')) -ForegroundColor DarkGray }
if ($bad.Count) { Write-Host ("  失败行：{0}" -f ($bad -join ' | ')) -ForegroundColor Yellow }
if (-not $rows.Count) { Write-Host "没有要写的。" -ForegroundColor Yellow; exit 0 }

if (-not $Apply) { Write-Host "（预览模式，加 -Apply 实际写入）" -ForegroundColor Yellow; exit 0 }
Add-Content -Path $introPath -Value ($rows -join "`r`n") -Encoding UTF8
Write-Host ("✅ 已写入 {0} 条 → data\human\repo-intro.jsonl" -f $rows.Count) -ForegroundColor Green
if ($Sync) {
  & (P 'tools\sync-projects.ps1') -Force
  & (P 'tools\build-overview.ps1')
  & (P 'tools\check-page.ps1')
}
