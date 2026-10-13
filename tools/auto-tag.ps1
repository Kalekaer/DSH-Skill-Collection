# auto-tag.ps1 — 给缺功能标签的项目自动生成 function_tags / user_keywords
#
# 为什么需要：搜索最有效的强信号是「功能标签 + 用户搜索词」，但**只有人话层覆盖的项目才有**（45/143 = 31%）。
# 后果：库越大、没标签的项目越多，搜「功能」越搜不到。本脚本用**本地规则**从已有素材补标签，
# 不调用任何 API、不花 token。
#
# 素材来源（按可信度）：GitHub topics → 项目描述 → 台账备注
# 纪律：
#   * **不覆盖人工写的条目**（data/human/function-tags.jsonl 里已有的 full_name 一律跳过）
#   * 生成的条目带 `source` 字段标明来源（`auto(topics+descr)`），便于以后区分与人工修订
#   * 素材不足就不写（宁缺勿造）
#
# 用法：
#   & ".\tools\auto-tag.ps1"              # 预览（默认，不写盘）
#   & ".\tools\auto-tag.ps1" -Apply       # 实际写入
#   & ".\tools\auto-tag.ps1" -Apply -Sync # 写完顺手 sync + build

param(
  [switch]$Apply,
  [switch]$Sync,
  [int]$Show = 8
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$projPath = P 'data\projects.jsonl'
$tagPath  = P 'data\human\function-tags.jsonl'
if (-not (Test-Path $projPath)) { Write-Host "❌ 找不到 projects.jsonl" -ForegroundColor Red; exit 1 }

# 已有条目（人工 + 之前自动生成的）——一律不覆盖
$existing = @{}
if (Test-Path $tagPath) {
  foreach ($l in (Get-Content $tagPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $o = $l | ConvertFrom-Json; if ($o.full_name) { $existing[$o.full_name] = $true } } catch {}
  }
}

# 通用词：作标签没有区分度，跳过
# 共用宽词清单（data/wide-terms.json）：这些词太宽，不该被自动打标直接当功能标签，
# 也保证「标签不宽」与「分类器不轻信宽词」用的是同一份定义（用户需求 1/2）。
$script:WIDE = @()
$wideP = P 'data\wide-terms.json'
if (Test-Path $wideP) { try { $script:WIDE = @((Get-Content $wideP -Raw -Encoding UTF8 | ConvertFrom-Json).wide | Where-Object { $_ }) } catch {} }
$genericTopic = @('ai','llm','typescript','javascript','python','rust','go','java','cli','desktop','electron',
                  'web','tools','tool','library','framework','api','ui','ux','css','html','node','npm','docker',
                  'open-source','oss','app','software','code','dev','developer-tools')
# 描述里切出来的常见功能词/虚词，作关键词价值低
$stopSeg = @('提供','支持','一个','为','的','和','与','可','能','用于','基于','实现','工具','功能','插件','系统',
             '应用','设计','管理','开源','本地','快速','简单','完整','全新','免费','中文','桌面','命令行','以及',
             '可以','通过','使用','进行','包括','类型','各种','多个','自动','智能','真实','全部','统一','轻量',
             '深度','高性能','现代化','可视化','一体化','一站式',
             'Rust','Python','JavaScript','TypeScript','Node','Go','Java','Apache','MIT','GPL','AGPL','BSD','License')

function Split-Desc([string]$d) {
  if (-not $d) { return @() }
  $raw = $d -split '[：:，,、；;。\.\|/（）()【】\[\]—\-]|把|被|与|和|并|可以|支持|用于|可将|可将|以及'
  $out = @()
  foreach ($s in $raw) {
    $t = "$s".Trim()
    if ($t.Length -lt 2 -or $t.Length -gt 14) { continue }   # 放宽 8→14：中文描述的正常短语常是 9-14 字（原规则把它们全丢了）
    if ($stopSeg -contains $t) { continue }
    # **只取含中文的片段**：英文描述按标点切出来的多是句子残片（如 "is a high"），没有标签价值；
    # 英文关键词由 topics 提供，不从这里取。
    if ($t -notmatch '[\u4e00-\u9fff]') { continue }
    if ($out -notcontains $t) { $out += $t }
  }
  return $out
}

$all = @()
foreach ($l in (Get-Content $projPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch {}
}

$plan = @(); $script:skipWhy = @()
foreach ($p in $all) {
  # 只认「人话层文件里有没有这条」——不要看 projects.jsonl（那是投影，可能还没同步，会误判成"已有标签"）
  if ($existing.ContainsKey($p.id)) { continue }
  if ($p.status -eq 'dropped') { continue }                         # 已淘汰不补

  $tags = @(); $kws = @()
  # ① topics → 标签（英文原词，去掉通用词）
  foreach ($t in @($p.topics)) {
    $tl = "$t".ToLower().Trim()
    if (-not $tl -or $genericTopic -contains $tl -or $script:WIDE -contains $tl) { continue }   # 宽词不进自动标签
    if ($tags -notcontains $tl) { $tags += $tl }
    if ($tags.Count -ge 3) { break }
  }
  # ② 描述切段 → 标签 + 用户搜索词
  $segs = Split-Desc "$($p.description)"
  foreach ($s in $segs) {
    if ($tags.Count -lt 5 -and $tags -notcontains $s) { $tags += $s }
    if ($kws -notcontains $s) { $kws += $s }
    if ($kws.Count -ge 5) { break }
  }
  # ③ 台账备注兜底：**只在描述完全没素材时**用，且必须像"功能短语"。
  # 备注里常混着「用户清单」「0 星」「2026-09-14 后无提交」这类元信息——那些作搜索词是噪声，
  # 会把「搜 0」变成有结果。所以：含数字 / 含元信息词的片段一律不要。
  if (-not $tags.Count -and $p.note) {
    $metaWords = @('星','提交','清单','核实','待','已','未','无','淘汰','推荐','候选','安装','用户','不符','FROZEN','冻结')
    foreach ($s in (Split-Desc "$($p.note)")) {
      if ($s -match '\d') { continue }
      $bad = $false
      foreach ($m in $metaWords) { if ($s.Contains($m)) { $bad = $true; break } }
      if ($bad) { continue }
      if ($tags -notcontains $s) { $tags += $s }
      if ($tags.Count -ge 3) { break }
    }
  }
  if (-not $kws.Count) { $kws = $tags }   # 需求 2：新标签必须带可搜的词（没有中文片段就用标签本身）
  if (-not $tags.Count) {
    # 素材不足要**可诊断**（原来只丢进一个数字里，看不出流水线是不是空转）
    $why = if (-not @($p.topics).Count) { '无 topics' } else { 'topics 全通用/宽词' }
    $seg = Split-Desc "$($p.description)"
    $why += if (-not "$($p.description)") { ' ｜ 无中文描述' } else { " ｜ 描述切段 $($seg.Count) 个" }
    $script:skipWhy += [pscustomobject]@{ id = $p.id; why = $why }
    continue
  }

  $plan += [pscustomobject]@{
    full_name      = $p.id
    function_tags  = @($tags | Select-Object -First 5)
    user_keywords  = @($kws   | Select-Object -First 5)
    synonyms       = @()
    source         = 'auto(topics+descr)'
    written_at     = (Get-Date).ToString('yyyy-MM-dd')
  }
}

Write-Host ""
if ($script:skipWhy.Count) {
  Write-Host "  素材不足的原因（前 8 条）：" -ForegroundColor DarkYellow
  $script:skipWhy | Select-Object -First 8 | ForEach-Object { Write-Host ("    {0} → {1}" -f $_.id, $_.why) -ForegroundColor DarkGray }
}
Write-Host ""
Write-Host "=== 自动打标计划 ===" -ForegroundColor Cyan
Write-Host ("  库里共 {0} 条 ｜ 已有标签 {1} 条 ｜ 本次可补 {2} 条 ｜ 素材不足跳过 {3} 条" -f `
  $all.Count, $existing.Count, $plan.Count, ($all.Count - $existing.Count - $plan.Count))
Write-Host ""
Write-Host "  预览（前 $Show 条）：" -ForegroundColor DarkGray
$plan | Select-Object -First $Show | ForEach-Object {
  Write-Host ("    {0}" -f $_.full_name) -ForegroundColor White
  Write-Host ("      标签：{0}" -f ($_.function_tags -join ' / ')) -ForegroundColor Gray
  Write-Host ("      搜索词：{0}" -f ($_.user_keywords -join ' / ')) -ForegroundColor DarkGray
}

if (-not $Apply) {   # 定位：候选预览，不是自动补标签（用户 2026-10-14 决定 C 方案）
  Write-Host ""
  Write-Host "（预览模式，未写盘。加 -Apply 实际写入）" -ForegroundColor Yellow
  exit 0
}
if (-not $plan.Count) { Write-Host "没有需要补的条目。" -ForegroundColor Yellow; exit 0 }

$lines = $plan | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }
Add-Content -Path $tagPath -Value ($lines -join "`r`n") -Encoding UTF8
Write-Host ""
Write-Host ("✅ 已写入 {0} 条 → data\human\function-tags.jsonl" -f $plan.Count) -ForegroundColor Green

if ($Sync) {
  & (P 'tools\sync-projects.ps1') -Force
  & (P 'tools\build-overview.ps1')
}
