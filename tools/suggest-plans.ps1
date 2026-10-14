# suggest-plans.ps1 — 发现「库里工具攒够了、但没有对应方案」的用途方向，作为方案候选
#
# 解决的问题：data/plans.json 是人工写的固定场景。库变大后会出现：
# **某个方向的工具已经一堆了，但没有任何方案会带用户看到它们**（例如 AI 音乐攒了 6 个）。
# 本脚本用本地统计挖出这些方向，写成候选，等人批准 —— 和同义词候选、分类候选同一套思路。
#
# 用法：
#   & ".\tools\suggest-plans.ps1"                # 预览
#   & ".\tools\suggest-plans.ps1" -Apply          # 写入 data/plan-suggestions.jsonl（status=pending）
#   & ".\tools\suggest-plans.ps1" -MinTools 3     # 至少几个工具才算一个方向（默认 3）
param(
  [switch]$Apply,
  [int]$MinTools = 3
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

# ---- 已被方案覆盖的方向（l2 名称 + ft 关键词）----
$coveredL2 = @{}; $coveredFt = @{}
$planPath = P 'data\plans.json'
if (Test-Path $planPath) {
  try {
    $doc = Get-Content $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($pl in @($doc.plans)) {
      foreach ($r in @($pl.roles)) {
        foreach ($x in @($r.l2)) { if ($x) { $coveredL2["$x"] = $true } }
        foreach ($x in @($r.ft)) { if ($x) { $coveredFt["$x".ToLower()] = $true } }
      }
    }
  } catch {}
}

$all = @()
foreach ($l in (Get-Content (P 'data\projects.jsonl') -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch {}
}

# ---- 按二级分类统计（排除已淘汰、排除「其他工具」）----
$byL2 = @{}
foreach ($p in $all) {
  if ($p.status -eq 'dropped') { continue }
  $l2 = "$($p.category.l2)"
  if (-not $l2 -or $l2 -eq '其他工具') { continue }
  if (-not $byL2.ContainsKey($l2)) { $byL2[$l2] = @() }
  $byL2[$l2] += $p
}

$cands = @()
foreach ($k in $byL2.Keys) {
  $items = @($byL2[$k])
  if ($items.Count -lt $MinTools) { continue }
  if ($coveredL2.ContainsKey($k)) { continue }
  # 该方向的标签是否已被任何方案提到
  $fts = @($items | ForEach-Object { @($_.function_tags) } | Where-Object { $_ } | Sort-Object -Unique)
  $ftCovered = $false
  foreach ($f in $fts) { if ($coveredFt.ContainsKey("$f".ToLower())) { $ftCovered = $true; break } }
  $cands += [pscustomobject]@{
    l2 = $k; count = $items.Count
    top = @($items | Sort-Object { -$_.stars.current } | Select-Object -First 3 | ForEach-Object { $_.id })
    tags = @($fts | Select-Object -First 6)
    ft_covered = $ftCovered
  }
}
$cands = @($cands | Sort-Object { -$_.count })

Write-Host ""
Write-Host "=== 方案候选（工具攒够、但没有对应场景）===" -ForegroundColor Cyan
Write-Host ("  库里 {0} 条 ｜ 已有方案 {1} 个 ｜ 候选方向 {2} 个（阈值 ≥{3} 个工具）" -f $all.Count, (@($doc.plans).Count), $cands.Count, $MinTools)
Write-Host ""
foreach ($c in $cands) {
  $mark = if ($c.ft_covered) { '（标签已被别的方案提到，优先级低）' } else { '' }
  Write-Host ("  {0,-12} {1,2} 个工具 {2}" -f $c.l2, $c.count, $mark) -ForegroundColor White
  Write-Host ("      示例：{0}" -f ($c.top -join ', ')) -ForegroundColor Gray
  Write-Host ("      常见标签：{0}" -f ($c.tags -join ' / ')) -ForegroundColor DarkGray
  Write-Host ("      → 可加方案：「{0}」；用 & `".\tools\add-plan.ps1`" 固化" -f $c.l2) -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  只做候选：批准后才写进 data/plans.json。批准前先问用户「这个方向要不要做成固定方案」。" -ForegroundColor DarkGray

if ($Apply -and $cands.Count) {
  $rows = $cands | ForEach-Object {
    [pscustomobject]@{
      suggested_l2 = $_.l2; tool_count = $_.count; examples = $_.top; tags = $_.tags
      first_seen = (Get-Date).ToString('yyyy-MM-dd'); status = 'pending'
    } | ConvertTo-Json -Compress -Depth 4
  }
  Add-Content -Path (P 'data\plan-suggestions.jsonl') -Value ($rows -join "`r`n") -Encoding UTF8
  Write-Host ("✅ 已写入 {0} 条 → data\plan-suggestions.jsonl" -f @($rows).Count) -ForegroundColor Green
}
