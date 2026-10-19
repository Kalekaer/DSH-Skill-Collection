# suggest-terms.ps1 — 从库里自动挖「还没有被词表覆盖」的新词，作为同义词候选
#
# 解决的问题：同义词表原来只有 14 组 108 词、手工写死。库从 90 涨到 143，它一个字没加 ——
# **词表不随库增长，搜「功能」就会越来越搜不到。** 本脚本用本地统计挖候选，0 token。
#
# 做法：统计全库 function_tags / user_keywords / topics / 描述切段 的词频，
#       减去「已收录」（同义词表 + taxonomy 关键词），剩下的按频次排序输出候选。
#
# 用法：
#   & ".\tools\suggest-terms.ps1"                # 预览前 25 个候选
#   & ".\tools\suggest-terms.ps1" -Apply          # 写入 data/human/synonym-suggestions.jsonl（status=pending）
#   & ".\tools\suggest-terms.ps1" -MinCount 2     # 只保留出现 ≥2 次的（默认 2）
param(
  [switch]$Apply,
  [int]$MinCount = 2,
  [int]$Top = 25
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

# ---- 已收录的词（同义词表 + taxonomy 关键词）----
$known = @{}
$synPath = P 'data\human\search-synonyms.jsonl'
if (Test-Path $synPath) {
  foreach ($l in (Get-Content $synPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $g = $l | ConvertFrom-Json; foreach ($t in @($g.terms)) { $known["$t".ToLower()] = $true } } catch { $null = $_ }
  }
}
$taxPath = P 'data\taxonomy.json'
if (Test-Path $taxPath) {
  try {
    $tax = Get-Content $taxPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($l1 in $tax.'一级分类'.PSObject.Properties) {
      $known[$l1.Name.ToLower()] = $true
      foreach ($l2 in $l1.Value.children.PSObject.Properties) {
        $known[$l2.Name.ToLower()] = $true
        foreach ($k in @($l2.Value)) { $known["$k".ToLower()] = $true }
      }
    }
  } catch { $null = $_ }
}

# ---- 统计词频 ----
$count = @{}
$example = @{}
function Add-Term([string]$t, [string]$repo) {
  $x = "$t".Trim()
  if ($x.Length -lt 2 -or $x.Length -gt 12) { return }
  if ($x -match '^\d+$') { return }
  if ($x -match '\d') { return }                       # 含数字的多是版本/日期/星数，不是功能词
  $metaWords = @('档观察','清单','待补','已推荐','候选','核实','不符','无提交','零依赖','保持不变','再装')
  foreach ($m in $metaWords) { if ($x.Contains($m)) { return } }
  $k = $x.ToLower()
  if ($known.ContainsKey($k)) { return }
  if (-not $count.ContainsKey($k)) { $count[$k] = 0; $example[$k] = @() }
  $count[$k]++
  if ($example[$k].Count -lt 3 -and $example[$k] -notcontains $repo) { $example[$k] += $repo }
}
$generic = @('ai','llm','typescript','javascript','python','rust','go','java','cli','desktop','electron','web',
             'tools','tool','library','framework','api','ui','ux','css','html','node','npm','docker','app','code',
             'open-source','plugin','plugins','github','deepseek','dsh','agent')
$all = @()
foreach ($l in (Get-Content (P 'data\projects.jsonl') -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
}
foreach ($p in $all) {
  if ($p.status -eq 'dropped') { continue }
  foreach ($t in @($p.function_tags)) { if ($generic -notcontains "$t".ToLower()) { Add-Term "$t" $p.id } }
  foreach ($t in @($p.user_keywords)) { if ($generic -notcontains "$t".ToLower()) { Add-Term "$t" $p.id } }
  foreach ($t in @($p.topics))        { if ($generic -notcontains "$t".ToLower()) { Add-Term "$t" $p.id } }
  # 描述里的中文短语
  $d = "$($p.description)"
  if ($d) {
    foreach ($seg in ($d -split '[：:，,、；;。\.\|/（）()【】\[\]—\-]')) {
      $s = "$seg".Trim()
      if ($s -notmatch '[\u4e00-\u9fff]') { continue }
      Add-Term $s $p.id
    }
  }
}

$cands = @($count.Keys | Where-Object { $count[$_] -ge $MinCount } |
  Sort-Object { -$count[$_] } | Select-Object -First $Top)

Write-Host ""
Write-Host "=== 同义词候选（库里出现 ≥$MinCount 次、且词表还没收录）===" -ForegroundColor Cyan
Write-Host ("  全库 {0} 条 ｜ 候选词 {1} 个（显示前 {2}）" -f $all.Count, (@($count.Keys | Where-Object { $count[$_] -ge $MinCount }).Count), $cands.Count)
Write-Host ""
foreach ($c in $cands) {
  Write-Host ("  {0,-24} {1,3} 次  例：{2}" -f $c, $count[$c], (($example[$c] | Select-Object -First 2) -join ', ')) -ForegroundColor Gray
}
Write-Host ""
Write-Host "  提示：这些词是**候选**，不是自动生效。批准后手工并入 data/human/search-synonyms.jsonl 的对应组。" -ForegroundColor DarkGray

if ($Apply) {
  $out = P 'data\human\synonym-suggestions.jsonl'
  $rows = $cands | ForEach-Object {
    [pscustomobject]@{
      term = $_; count = $count[$_]; examples = @($example[$_] | Select-Object -First 3)
      first_seen = (Get-Date).ToString('yyyy-MM-dd'); status = 'pending'
    } | ConvertTo-Json -Compress -Depth 4
  }
  if ($rows) {
    Add-Content -Path $out -Value ($rows -join "`r`n") -Encoding UTF8
    Write-Host ("✅ 已写入 {0} 条 → data\human\synonym-suggestions.jsonl" -f @($rows).Count) -ForegroundColor Green
  }
}
