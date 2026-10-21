# taxonomy-guard.ps1 — 分类建议四道闸（2026-10-21 P2）
#
# 只读。对 data/taxonomy-suggestions.jsonl 的每条建议跑四道闸：
#   1) 样本：examples >= 10
#   2) 定义：definition / scope_note 非空
#   3) 命名：与现有 l1/l2 不重名、不近名（Levenshtein <=1 或包含关系）
#   4) 重叠：examples 在 projects.jsonl 里的现有 l1 若 >=70% 已属同一类，则视为重叠
# 另检查 taxonomy.json 中标记 `_deprecated` 的类目必须有 `_替代`。
#
# 用法：
#   .\tools\taxonomy-guard.ps1
#   .\tools\taxonomy-guard.ps1 -Strict   # 有 BLOCK 时 exit 1（供门禁用）
#   .\tools\taxonomy-guard.ps1 -Json

[CmdletBinding()]
param(
  [switch]$Strict,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function P([string]$rel) { Join-Path $root $rel }

function Read-Jsonl([string]$rel) {
  $p = P $rel
  if (-not (Test-Path $p)) { return @() }
  $out = @()
  foreach ($l in [IO.File]::ReadAllLines($p, [Text.Encoding]::UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $out += ($l | ConvertFrom-Json) } catch { }
  }
  return $out
}
function Norm([string]$s) { return (($s -replace '[\s_\-—/、，,。.()（）]', '').ToLowerInvariant()) }
function Lev([string]$a, [string]$b) {
  if ($a -eq $b) { return 0 }
  $n = $a.Length; $m = $b.Length
  if ($n -eq 0) { return $m }; if ($m -eq 0) { return $n }
  $prev = New-Object int[] ($m + 1); $cur = New-Object int[] ($m + 1)
  for ($j = 0; $j -le $m; $j++) { $prev[$j] = $j }
  for ($i = 1; $i -le $n; $i++) {
    $cur[0] = $i
    for ($j = 1; $j -le $m; $j++) {
      $cost = if ($a[$i - 1] -eq $b[$j - 1]) { 0 } else { 1 }
      $cur[$j] = [math]::Min([math]::Min($cur[$j - 1] + 1, $prev[$j] + 1), $prev[$j - 1] + $cost)
    }
    $tmp = $prev; $prev = $cur; $cur = $tmp
  }
  return $prev[$m]
}

$tax = Get-Content (P 'data\taxonomy.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$l1Names = @($tax.'一级分类'.PSObject.Properties.Name)
$childNames = @()
$deprecatedIssues = @()
foreach ($l1p in $tax.'一级分类'.PSObject.Properties) {
  $l1 = $l1p.Value
  if ($l1.PSObject.Properties['_deprecated'] -and $l1._deprecated) {
    if (-not ($l1.PSObject.Properties['_替代'] -and $l1._替代)) { $deprecatedIssues += "一级分类「$($l1p.Name)」标了 _deprecated 却没有 _替代" }
  }
  if ($l1.PSObject.Properties['children']) {
    foreach ($c in $l1.children.PSObject.Properties) {
      $childNames += $c.Name
      if ($c.Value -is [pscustomobject] -and $c.Value.PSObject.Properties['_deprecated'] -and $c.Value._deprecated) {
        if (-not ($c.Value.PSObject.Properties['_替代'] -and $c.Value._替代)) { $deprecatedIssues += "二级分类「$($c.Name)」标了 _deprecated 却没有 _替代" }
      }
    }
  }
}

$proj = @{}
foreach ($p in (Read-Jsonl 'data\projects.jsonl')) { $proj[[string]$p.id] = $p }
$sugs = @(Read-Jsonl 'data\taxonomy-suggestions.jsonl' | Where-Object { $_.status -in @('pending', 'draft', 'under_review', 'approved') })

$results = @()
foreach ($s in $sugs) {
  $name = [string]$s.suggested_l1
  $l2s = @(([string]$s.suggested_l2) -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $examples = @($s.examples)
  $reasons = @()
  $warns = @()

  # 已批准且已落在 taxonomy 里的历史建议：不按新闸门重判，只提示
  $applied = $false
  if ([string]$s.status -eq 'approved') {
    foreach ($existing in $l1Names) { if ((Norm $name) -eq (Norm $existing)) { $applied = $true } }
  }

  if (-not $applied -and $examples.Count -lt 10) { $reasons += "样本不足：examples=$($examples.Count)（需 ≥10）" }
  if (-not [string]$s.definition) { if ($applied) { $warns += '缺 definition（历史条目）' } else { $reasons += '缺 definition' } }
  if (-not [string]$s.scope_note) { if ($applied) { $warns += '缺 scope_note（历史条目）' } else { $reasons += '缺 scope_note' } }

  foreach ($existing in $l1Names) {
    $a = Norm $name; $b = Norm $existing
    if (-not $a -or -not $b) { continue }
    if ($a -eq $b) { if ($applied) { $warns += "已落库：$existing" } else { $reasons += "与现有一级分类重名：$existing" }; continue }
    if ($a.Length -ge 2 -and $b.Length -ge 2 -and (Lev $a $b) -le 1) { $warns += "与现有一级分类近名：$existing" }
  }
  foreach ($l2 in $l2s) {
    foreach ($existing in $childNames) {
      if ((Norm $l2) -eq (Norm $existing)) { if ($applied) { $warns += "已落库：$existing" } else { $reasons += "与现有二级分类重名：$existing" } }
    }
  }

  $hitL1 = @{}
  foreach ($ex in $examples) {
    if ($proj.ContainsKey([string]$ex)) {
      $l1 = [string]$proj[[string]$ex].category.l1
      if ($l1) { $hitL1[$l1] = 1 + [int]$hitL1[$l1] }
    }
  }
  if ($hitL1.Count -and -not $applied) {
    $top = $hitL1.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
    $ratio = [double]$top.Value / [math]::Max(1, $examples.Count)
    if ($top.Key -ne $name -and $ratio -ge 0.7) {
      $reasons += ("与现有类重叠：examples 的 {0:P0} 已属「{1}」" -f $ratio, $top.Key)
    } elseif ($ratio -lt 0.3) {
      $warns += ("examples 在现有类中很分散（最高 {0} = {1:P0}）" -f $top.Key, $ratio)
    }
  }

  $verdict = if ($reasons.Count) { 'BLOCK' } else { 'PASS' }
  $results += [pscustomobject]@{
    l1 = $name; l2 = ($l2s -join ' / '); status = [string]$s.status
    examples = $examples.Count; verdict = $verdict; reasons = $reasons; warns = $warns
  }
}

if ($Json) {
  [pscustomobject]@{ suggestions = $results; deprecated = $deprecatedIssues } | ConvertTo-Json -Depth 6
} else {
  Write-Host '=== 分类建议四道闸 ===' -ForegroundColor Cyan
  if (-not $results.Count) { Write-Host '（没有待审建议）' -ForegroundColor DarkGray }
  foreach ($r in $results) {
    $color = if ($r.verdict -eq 'PASS') { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1} / {2}  examples={3}  status={4}" -f $r.verdict, $r.l1, $r.l2, $r.examples, $r.status) -ForegroundColor $color
    foreach ($x in $r.reasons) { Write-Host "   ✗ $x" -ForegroundColor Red }
    foreach ($x in $r.warns) { Write-Host "   ! $x" -ForegroundColor Yellow }
  }
  if ($deprecatedIssues.Count) { $deprecatedIssues | ForEach-Object { Write-Host "   ✗ $_" -ForegroundColor Red } }
  else { Write-Host '词表废弃项：无问题' -ForegroundColor DarkGray }
}

$blocked = @($results | Where-Object { $_.verdict -eq 'BLOCK' }).Count + $deprecatedIssues.Count
if ($Strict -and $blocked -gt 0) { exit 1 }
exit 0
