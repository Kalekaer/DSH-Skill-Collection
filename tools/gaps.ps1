# gaps.ps1 — 搜索缺口：记下「搜不到的词」，并给出补词建议
#
# 解决的问题：**搜索词表原来只增不减、且靠人想起来才加**。用户搜了没结果，这件事就消失了，
# 下次还是搜不到 —— 词表永远追不上库的增长。
#
# 本脚本做两件事：
#   1) -Add "<词>"：把一个缺口词记进 data/search-gaps.jsonl（页面上也能记，见 overview.html 的「记下这个词」）
#   2) 默认：逐个复检缺口词 —— 现在能搜到几条？和哪些已收录词最接近（编辑距离 ≤2）？
#      据此给出**具体补词建议**（把 X 加到 Y 的组里 / 新建一组）。
#
# 用法：
#   & ".\tools\gaps.ps1" -Add "插件市场"
#   & ".\tools\gaps.ps1"
param(
  [string]$Add = '',
  [int]$MaxDistance = 2
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
$gapPath = P 'data\search-gaps.jsonl'

function Add-Gap([string]$term) {
  $row = [pscustomobject]@{ term = $term; date = (Get-Date).ToString('yyyy-MM-dd'); hits = 0; source = 'manual' } | ConvertTo-Json -Compress
  Add-Content -Path $gapPath -Value $row -Encoding UTF8
  Write-Host "已记录缺口词：$term" -ForegroundColor Green
}

if ($Add) { Add-Gap $Add; exit 0 }
if (-not (Test-Path $gapPath)) { Write-Host '还没有缺口记录（data\search-gaps.jsonl 为空）。用 -Add "词" 添加。' -ForegroundColor Yellow; exit 0 }

$gaps = @()
foreach ($l in (Get-Content $gapPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $gaps += ($l | ConvertFrom-Json) } catch { $null = $_ }
}
if (-not $gaps.Count) { Write-Host "缺口记录为空。" -ForegroundColor Yellow; exit 0 }

# 全库 + 已有词表
$all = @()
foreach ($l in (Get-Content (P 'data\projects.jsonl') -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
}
$synGroups = @()
$synPath = P 'data\human\search-synonyms.jsonl'
if (Test-Path $synPath) {
  foreach ($l in (Get-Content $synPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $synGroups += ($l | ConvertFrom-Json) } catch { $null = $_ }
  }
}
$knownTerms = @()
foreach ($g in $synGroups) { $knownTerms += @($g.terms) }

function Lev([string]$a, [string]$b) {
  $m = $a.Length; $n = $b.Length
  if ($m -eq 0) { return $n }
  if ($n -eq 0) { return $m }
  $prev = @(0..$n)                                  # 长度 n+1
  for ($i = 1; $i -le $m; $i++) {
    # 注意：不要写 `(0) * $n` —— PowerShell 里那是**算术乘法**（结果 0），不是数组重复
    $cur = New-Object 'int[]' ($n + 1)
    $cur[0] = $i
    for ($j = 1; $j -le $n; $j++) {
      $cost = if ($a[$i-1] -eq $b[$j-1]) { 0 } else { 1 }
      $cur[$j] = [Math]::Min([Math]::Min($cur[$j-1] + 1, $prev[$j] + 1), $prev[$j-1] + $cost)
    }
    $prev = $cur
  }
  return $prev[$n]
}

function Search-Hits([string]$term) {
  $t = $term.ToLower()
  $hits = @()
  foreach ($p in $all) {
    if ($p.status -eq 'dropped') { continue }
    $hay = (@($p.id, $p.description, $p.note, $p.human.one_liner) + @($p.function_tags) + @($p.user_keywords) +
            @($p.topics) + @($p.category.l1, $p.category.l2)) -join ' '
    if ($hay.ToLower().Contains($t)) { $hits += $p.id }
  }
  return $hits
}

Write-Host ""
Write-Host "=== 搜索缺口复检（共 $($gaps.Count) 个词）===" -ForegroundColor Cyan
Write-Host ""
foreach ($g in $gaps) {
  $term = "$($g.term)"
  $hits = @(Search-Hits $term)
  $near = @()
  foreach ($k in ($knownTerms | Sort-Object -Unique)) {
    if ($k.Length -lt 2) { continue }
    if ((Lev $term.ToLower() $k.ToLower()) -le $MaxDistance) { $near += $k }
  }
  Write-Host ("  「{0}」 命中 {1} 条" -f $term, $hits.Count) -ForegroundColor White
  if ($hits.Count) {
    Write-Host ("      示例：{0}" -f (($hits | Select-Object -First 3) -join ', ')) -ForegroundColor Gray
    Write-Host "      → 建议：把这些项目现有的标签加进同义词表，让「$term」能扩展命中" -ForegroundColor DarkGray
  } elseif ($near.Count) {
    Write-Host ("      近似已收录词：{0}" -f ($near -join ', ')) -ForegroundColor Gray
    Write-Host "      → 建议：把「$term」并入上面某个词的组（同义）" -ForegroundColor DarkGray
  } else {
    Write-Host "      → 库里确实没有相关项目：需要**新词 + 可能的新项目**（走临时检索去 GitHub 找）" -ForegroundColor DarkYellow
  }
}
Write-Host ""
Write-Host "  补词流程：上面挑出要加的词 → 手工并入 data/human/search-synonyms.jsonl（或让 Agent 代劳）→ 跑 sync + build。" -ForegroundColor DarkGray
