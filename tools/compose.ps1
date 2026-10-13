# compose.ps1 — 按需求给「工具组合」建议（v3.1 验收第八节）
#
# 场景：用户说「我要做一个 AI 视频」「我要做产品设计」——不是找单个工具，而是**要一套搭配**。
# 做法：拿需求去本地库匹配（关键词 + 同义词 + 两级分类 + 功能标签），命中的工具**按用途分组**输出，
#       每组给出最优的 1–2 个。**不调用任何 API、不耗额度。**
#
# 用法：
#   & ".\tools\compose.ps1" -Need "AI视频"
#   & ".\tools\compose.ps1" -Need "产品设计" -PerGroup 3 -Save
#
# 纪律（必须保持）：
#   * 只做**归类**，不编造「第几步做什么」的流程——工具之间怎么搭由用户决定。
#   * 缺失字段标「（待补全）」，不猜。
#   * 已淘汰（dropped）的项目不参与。

param(
  [Parameter(Mandatory=$true)][string]$Need,
  [int]$PerGroup = 2,
  [switch]$Save
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$projPath = P 'data\projects.jsonl'
if (-not (Test-Path $projPath)) { Write-Host "❌ 找不到 data\projects.jsonl，先跑 sync-projects.ps1" -ForegroundColor Red; exit 1 }

$all = @()
foreach ($l in (Get-Content $projPath -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch {}
}

# ---- 需求扩展：命中同义词组就把整组词都算上（和 query.ps1 同一套逻辑）----
$synPath = P 'data\human\search-synonyms.jsonl'
$terms = @($Need.ToLower())
if (Test-Path $synPath) {
  foreach ($l in (Get-Content $synPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $g = $l | ConvertFrom-Json } catch { continue }
    $hit = @($g.terms | Where-Object { $_.ToLower().Contains($Need.ToLower()) -or $Need.ToLower().Contains($_.ToLower()) })
    if ($hit.Count -gt 0) { $terms += ($g.terms | ForEach-Object { $_.ToLower() }) }
  }
}
$terms = @($terms | Sort-Object -Unique)

function Get-Score($p) {
  $s = 0
  $ft  = @($p.function_tags) | ForEach-Object { "$_".ToLower() }
  $uk  = @($p.user_keywords) | ForEach-Object { "$_".ToLower() }
  $syn = @($p.synonyms)      | ForEach-Object { "$_".ToLower() }
  $cat = @("$($p.category.l1)".ToLower(), "$($p.category.l2)".ToLower())
  $one = ("$($p.human.one_liner)").ToLower()
  $nt  = ("$($p.note)").ToLower()
  $id  = ("$($p.id)").ToLower()
  foreach ($t in $terms) {
    if (-not $t) { continue }
    # 强信号：功能标签 / 用户搜索词 / 二级分类名
    if (@($ft  | Where-Object { $_.Contains($t) }).Count) { $s += 4 }
    if (@($uk  | Where-Object { $_.Contains($t) }).Count) { $s += 4 }
    if (@($cat | Where-Object { $_ -eq $t -or $_.Contains($t) }).Count) { $s += 3 }
    if (@($syn | Where-Object { $_.Contains($t) }).Count) { $s += 2 }
    if ($one.Contains($t)) { $s += 2 }
    if ($id.Contains($t))  { $s += 2 }
    if ($nt.Contains($t))  { $s += 1 }
  }
  return $s
}

$scored = @()
foreach ($p in $all) {
  if ($p.status -eq 'dropped') { continue }
  $sc = Get-Score $p
  if ($sc -gt 0) { $scored += [pscustomobject]@{ p = $p; score = $sc } }
}

$today = (Get-Date).ToString('yyyy-MM-dd')
$lines = @()
$lines += "# 工具组合建议：$Need"
$lines += ""
$lines += "> 生成于 $(Get-Date -Format 'yyyy-MM-dd HH:mm') ｜ 依据本地库（关键词 + 同义词 + 两级分类 + 功能标签）｜ **未调用 API**"
$lines += "> 这里只做**按用途归类**，不替你规定流程顺序；具体怎么搭由你决定。缺失标「（待补全）」。"
$lines += ""

if ($scored.Count -eq 0) {
  $lines += "本地库里没有匹配到相关工具。可以：① 换一个说法（如「画图」→「AI绘画」）；② 用临时检索去 GitHub 找（第十二节）。"
} else {
  # 按二级分类分组
  $groups = @{}
  foreach ($s in $scored) {
    $k = "$($s.p.category.l1) → $($s.p.category.l2)"
    if (-not $groups.ContainsKey($k)) { $groups[$k] = @() }
    $groups[$k] += $s
  }
  $ordered = @($groups.Keys | Sort-Object { -((@($groups[$_]) | Measure-Object -Property score -Maximum).Maximum) })
  $lines += "命中 $($scored.Count) 个相关工具，按用途分成 $($ordered.Count) 组："
  $lines += ""
  $i = 0
  foreach ($k in $ordered) {
    $i++
    $items = @($groups[$k] | Sort-Object { -$_.score }, { -($_.p.experience.score) } | Select-Object -First $PerGroup)
    $lines += "## $i. $k"
    $lines += ""
    foreach ($it in $items) {
      $p = $it.p
      $exp = if ($null -ne $p.experience.stars) { ('★' * [int]$p.experience.stars) + ('☆' * (5 - [int]$p.experience.stars)) + "（$($p.experience.score)/100）" } else { '未评分' }
      $risk = if ($p.risk) { $p.risk } else { $p.tags.'风险等级' }
      $lic = if ($p.license) { $p.license } else { '许可未知' }
      $one = if ($p.human.one_liner) { $p.human.one_liner } elseif ($p.description) { $p.description } else { '（待补全）' }
      $ft = if (@($p.function_tags).Count) { ($p.function_tags -join ' / ') } else { '（无标签）' }
      $lines += "- **$($p.id)** ｜ $exp ｜ $lic ｜ 风险 $risk ｜ ★$($p.stars.current)"
      $lines += "  - $one"
      $lines += "  - 功能标签：$ft"
    }
    $lines += ""
  }
  $lines += "---"
  $lines += ""
  $lines += '想细看某两个的差别：在 overview.html 里勾选两张卡片 →「查看对比」，或跑 tools\compare.ps1 A B。'
  $lines += '同类型还有更多：跑 tools\compare.ps1 -Similar owner/repo（换成完整仓库名）。'
}

$out = $lines -join "`r`n"
Write-Host ""
Write-Host $out
Write-Host ""

if ($Save) {
  $dir = P 'reports\compositions'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $safe = ($Need -replace '[\\/:*?"<>|]', '_')
  $file = Join-Path $dir ("{0}-{1}.md" -f $today, $safe)
  [System.IO.File]::WriteAllText($file, $out + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "已保存：$file" -ForegroundColor Green
}
