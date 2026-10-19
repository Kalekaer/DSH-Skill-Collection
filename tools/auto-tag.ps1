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
  [switch]$NoRebuild,
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
    try { $o = $l | ConvertFrom-Json; if ($o.full_name) { $existing[$o.full_name] = $true } } catch { $null = $_ }
  }
}

# 通用词：作标签没有区分度，跳过
# 共用宽词清单（data/wide-terms.json）：这些词太宽，不该被自动打标直接当功能标签，
# 也保证「标签不宽」与「分类器不轻信宽词」用的是同一份定义（用户需求 1/2）。
$script:WIDE = @()
$wideP = P 'data\wide-terms.json'
if (Test-Path $wideP) { try { $script:WIDE = @((Get-Content $wideP -Raw -Encoding UTF8 | ConvertFrom-Json).wide | Where-Object { $_ }) } catch { $null = $_ } }
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

# 自动标签质量闸（2026-10-18）：宁缺勿造，明显是句子/长短语/宽词的一律不要
function Test-Tag([string]$t) {
  $t = "$t".Trim()
  if ($t.Length -lt 2 -or $t.Length -gt 8) { return $false }
  if ($t -match '[，。；、：,.;:!?！？/\\|]') { return $false }
  if ($t -match '^\d') { return $false }
  if ($t -match '^(基于|本次|支持|可以|用于|实现|提供|一个|工具|功能|我们|你|它|这个|那个)') { return $false }
  if ($script:WIDE -contains $t.ToLower()) { return $false }
  if ($genericTopic -contains $t.ToLower()) { return $false }
  return $true
}

$all = @()
foreach ($l in (Get-Content $projPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
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
    if (-not (Test-Tag $tl)) { continue }
    if ($tags -notcontains $tl) { $tags += $tl }
    if ($tags.Count -ge 3) { break }
  }
  # ② 描述切段 → 标签 + 用户搜索词
  $segs = Split-Desc "$($p.description)"
  foreach ($s in $segs) {
    if (-not (Test-Tag $s)) { continue }
    if ($tags.Count -lt 5 -and $tags -notcontains $s) { $tags += $s }
    if ($kws -notcontains $s) { $kws += $s }
    if ($kws.Count -ge 5) { break }
  }
  # ③ 台账备注兜底：**2026-10-16 起停用（建议调整项 10 的根治方案）**。
  #
  # 停用原因（三次实测）：
  #   * `larashero3-dotcom/lieflat-less-ai-tone` → 打出「要求入库 / 不是 DSH 插件 / ⚠️结论可信度打折」
  #   * `Tencent/teamai-cli` → 打出「用来 / 它是什么 / 代码库图谱」
  # 备注是**人写给自己的话**，句式与功能短语不同；靠词表堵是打地鼠，且「备注写得越详细越容易中招」，
  # 与「给好备注」的要求直接冲突。
  # 现在的行为：描述与 topics 都取不出素材时**直接跳过**（走下面的「素材不足」报告），
  # 由人工用 `data/human/function-tags.jsonl` 手工补标签（`source=manual(...)`）。
  #
  # 如需恢复：把下面这行改成 $false，并接受“可能再次产出垃圾标签”。
  $noteFallbackEnabled = $false
  if ($noteFallbackEnabled -and -not $tags.Count -and $p.note) {
    $metaWords = @('星','提交','清单','核实','待','已','未','无','淘汰','推荐','候选','安装','用户','不符','FROZEN','冻结',
                   '入库','插件','可信','结论','打折','不适合','验证','来源','海报','截图','规则','判断','注意','风险',
                   '警告','版权','素材','敏感','供应链','许可','License','描述','用途','标签','分类','备注','记录',
                   '用来','是什么','怎么装','怎么用','分工','状态','支持','本项目','这个','那','另','或','须','应','先','后','要','说','写','看','会','能','可')
    foreach ($s in (Split-Desc "$($p.note)")) {
      if ($s -match '\d') { continue }
      if ($s.Length -lt 2 -or $s.Length -gt 8) { continue }
      $bad = $false
      foreach ($m in $metaWords) { if ($s.Contains($m)) { $bad = $true; break } }
      if ($bad) { continue }
      if ($tags -notcontains $s) { $tags += $s }
      if ($tags.Count -ge 3) { break }
    }
  }
  if (-not $kws.Count) { $kws = $tags }   # 需求 2：新标签必须带可搜的词（没有中文片段就用标签本身）
  # ③ 二级分类兜底：topics/描述都取不出时，用分类名（至少保证有标签可搜）
  if (-not $tags.Count) {
    $l2 = "$($p.category.l2)".Trim()
    if ($l2 -and $l2 -ne '其他' -and (Test-Tag $l2)) {
      $tags += $l2
      $kws += $l2
    }
  }
  if (-not $tags.Count) {
    # 素材不足要**可诊断**（原来只丢进一个数字里，看不出流水线是不是空转）
    $why = if (-not @($p.topics).Count) { '无 topics' } else { 'topics 全通用/宽词' }
    $seg = Split-Desc "$($p.description)"
    $why += if (-not "$($p.description)") { ' ｜ 无中文描述' } else { " ｜ 描述切段 $($seg.Count) 个" }
    $why += ' ｜ 二级分类也不可用'
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

if (-not $Apply) {   # 预览模式：只给人看，不写盘
  Write-Host ""
  Write-Host "（预览模式，未写盘。加 -Apply 实际写入）" -ForegroundColor Yellow
  exit 0
}

if ($plan.Count) {
  $lines = $plan | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }
  Add-Content -Path $tagPath -Value ($lines -join "`r`n") -Encoding UTF8
  Write-Host ""
  Write-Host ("✅ 已写入 {0} 条 → data\human\function-tags.jsonl" -f $plan.Count) -ForegroundColor Green
}

# ---------- 自动复核（第 2 次）：重新读盘，仍缺标签的用二级分类兜底 ----------
function Read-TagKeys {
  $m = @{}
  if (Test-Path $tagPath) {
    foreach ($l in (Get-Content $tagPath -Encoding UTF8)) {
      if (-not $l.Trim()) { continue }
      try { $o = $l | ConvertFrom-Json; if ($o.full_name) { $m[$o.full_name] = $true } } catch { $null = $_ }
    }
  }
  return $m
}
$now = Read-TagKeys
$still = @($all | Where-Object { $_.status -ne 'dropped' -and -not $now.ContainsKey($_.id) })
$extra = @()
foreach ($p in $still) {
  $l2 = "$($p.category.l2)".Trim()
  if (-not $l2 -or $l2 -eq '其他' -or -not (Test-Tag $l2)) { continue }
  $extra += [pscustomobject]@{
    full_name = $p.id; function_tags = @($l2); user_keywords = @($l2); synonyms = @()
    source = 'auto(reviewed-l2)'; written_at = (Get-Date).ToString('yyyy-MM-dd')
  }
}
if ($extra.Count) {
  $lines = $extra | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 5 }
  Add-Content -Path $tagPath -Value ($lines -join "`r`n") -Encoding UTF8
  Write-Host ("✅ 复核补写 {0} 条（二级分类兜底）" -f $extra.Count) -ForegroundColor Green
}
$now2 = Read-TagKeys
$left = @($all | Where-Object { $_.status -ne 'dropped' -and -not $now2.ContainsKey($_.id) })
Write-Host ("🔍 复核：库内 {0} 条 ｜ 已有标签 {1} 条 ｜ 仍缺 {2} 条（无可用分类，保留『未补』记录）" -f `
  $all.Count, $now2.Count, $left.Count) -ForegroundColor Cyan
if ($left.Count) { $left | Select-Object -First 8 | ForEach-Object { Write-Host ("    {0}" -f $_.id) -ForegroundColor DarkYellow } }

# P1-16：默认写盘后自动重建页面；-NoRebuild 供重建流程内部调用，避免递归
if (-not $NoRebuild) {
  & (P 'tools\rebuild-page.ps1') -Force
}
