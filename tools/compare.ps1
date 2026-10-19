# compare.ps1 — 项目对比（第二阶段功能 ⑦，2026-10-13 产品决策）
#
# 两种用法：
#   & ".\tools\compare.ps1" ownerA/repoA ownerB/repoB      # A vs B 对比表（Markdown，输出到控制台）
#   & ".\tools\compare.ps1" -Similar owner/repo [-Top 6]   # 找同类（同二级分类 + 功能标签重叠）
#
# 可选：-Save 把对比结果写入 reports\comparisons\YYYY-MM-DD-A-vs-B.md
#       **默认不落盘**——大量一次性比较会污染数据库；用户明确说「保存这次对比」才加 -Save。
#
# 数据全部来自 data/projects.jsonl（人话层 + 两级分类 + 功能标签 + 体验评分 + 风险），
# **不调用任何 API、不耗额度**；缺失字段标「（待补全）」，不编造。

param(
  [Parameter(Position=0)][string]$A,
  [Parameter(Position=1)][string]$B,
  [string]$Similar = '',
  [int]$Top = 6,
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
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
}

function Find-Repo([string]$key) {
  # 精确 id → 唯一匹配；否则按包含匹配（容忍只写 repo 名）
  $hit = @($all | Where-Object { $_.id -eq $key })
  if ($hit.Count -eq 1) { return $hit[0] }
  $hit = @($all | Where-Object { $_.id -like "*$key*" })
  if ($hit.Count -eq 1) { return $hit[0] }
  if ($hit.Count -gt 1) {
    Write-Host "「$key」匹配到 $($hit.Count) 条，请用完整 owner/repo：" -ForegroundColor Yellow
    $hit | ForEach-Object { Write-Host "   $($_.id)" -ForegroundColor Yellow }
  }
  return $null
}

function FnVal($p, [string]$key) {
  # 从 feature_note 取一项；取不到返回 $null（调用方标「待补全」）
  if ($p.human -and $p.human.feature_note) {
    $v = $p.human.feature_note.$key
    if ($v -is [array]) { return (@($v) -join '；') }
    if ($v) { return "$v" }
  }
  return $null
}

function ExpText($p) {
  if ($null -eq $p.experience -or $null -eq $p.experience.stars) { return '暂无体验分' }
  $s = '★' * [int]$p.experience.stars + '☆' * (5 - [int]$p.experience.stars)
  return "$s（$($p.experience.score)/100）"
}

function OneLiner($p) {
  if ($p.human -and $p.human.one_liner) { return $p.human.one_liner }
  if ($p.description) { return $p.description }
  if ($p.note) { return $p.note }
  return $null
}

# ============ 模式一：找同类 ============
if ($Similar) {
  $anchor = Find-Repo $Similar
  if (-not $anchor) { Write-Host "❌ 找不到 $Similar" -ForegroundColor Red; exit 1 }
  $aFt = @($anchor.function_tags)
  Write-Host ""
  Write-Host "=== 与 $($anchor.id) 同类的工具（按重合度排序）===" -ForegroundColor Cyan
  Write-Host "  锚点：$($anchor.category.l1) / $($anchor.category.l2) ｜ 标签：$($aFt -join '、')" -ForegroundColor DarkGray
  Write-Host ""
  $scored = @()
  foreach ($p in $all) {
    if ($p.id -eq $anchor.id) { continue }
    if ($p.status -eq 'dropped') { continue }   # 已淘汰的不掺和
    $shared = @($aFt | Where-Object { @($p.function_tags) -contains $_ })
    $sc = $shared.Count * 3
    $sameL2 = ($p.category.l2 -eq $anchor.category.l2)
    if ($sameL2) { $sc += 2 }
    if ($p.category.l1 -eq $anchor.category.l1) { $sc += 1 }
    # 门槛：至少有一个共同标签，或同二级分类——只同一级不算（否则办公软件会混进文件搜索）
    if (-not ($shared.Count -gt 0 -or $sameL2)) { continue }
    $scored += [pscustomobject]@{ p = $p; score = $sc; shared = $shared; sameL2 = $sameL2 }
  }
  $scored = @($scored | Sort-Object { -$_.score } | Select-Object -First $Top)
  if (-not $scored.Count) { Write-Host "  没有找到同类（可考虑把它的功能标签补进 data/human/function-tags.jsonl）" -ForegroundColor Yellow; exit 0 }
  foreach ($s in $scored) {
    $p = $s.p
    $one = OneLiner $p
    $oneTxt = if ($one) { $one.Substring(0, [Math]::Min(60, $one.Length)) } else { '（待补全）' }
    $basis = if ($s.shared.Count -gt 0) { "共同标签：$($s.shared -join '、')" } else { '同二级分类' }
    Write-Host ("  {0}  {1}  重合:{2}" -f $p.id, (ExpText $p), $s.score) -ForegroundColor White
    Write-Host ("      $oneTxt") -ForegroundColor Gray
    Write-Host ("      ★{0}  {1}/{2}  {3}  {4}" -f $p.stars.current, $p.category.l1, $p.category.l2, $p.license, $basis) -ForegroundColor DarkGray
  }
  Write-Host ""
  Write-Host "  要对比其中两个：& `".\tools\compare.ps1`" A B" -ForegroundColor DarkGray
  exit 0
}

# ============ 模式二：A vs B 对比 ============
if (-not $A -or -not $B) {
  Write-Host "用法：& `".\tools\compare.ps1`" ownerA/repoA ownerB/repoB　或　& `".\tools\compare.ps1`" -Similar owner/repo" -ForegroundColor Yellow
  exit 1
}
$pa = Find-Repo $A
$pb = Find-Repo $B
if (-not $pa) { Write-Host "❌ 找不到 $A" -ForegroundColor Red; exit 1 }
if (-not $pb) { Write-Host "❌ 找不到 $B" -ForegroundColor Red; exit 1 }

function Row([string]$label, $va, $vb) {
  $ta = if ($va) { "$va" -replace '\|', '／' } else { '（待补全）' }
  $tb = if ($vb) { "$vb" -replace '\|', '／' } else { '（待补全）' }
  "| $label | $ta | $tb |"
}

$lines = @()
$lines += "# 对比：$($pa.id) vs $($pb.id)"
$lines += ""
$lines += "> 生成于 $(Get-Date -Format 'yyyy-MM-dd HH:mm') ｜ 数据来自本地知识库（projects.jsonl），**未调用 API**；缺失标「（待补全）」。"
$lines += ""
$lines += "| 维度 | $($pa.id) | $($pb.id) |"
$lines += "|---|---|---|"
$lines += Row '一句话定位' (OneLiner $pa) (OneLiner $pb)
$lines += Row '是什么' (FnVal $pa '是什么') (FnVal $pb '是什么')
$lines += Row '核心功能' (FnVal $pa '核心功能') (FnVal $pb '核心功能')
$lines += Row '常见用途（适合谁）' (FnVal $pa '常见用途') (FnVal $pb '常见用途')
$lines += Row '使用案例' (FnVal $pa '使用案例') (FnVal $pb '使用案例')
$lines += Row '不适合' (FnVal $pa '不适合') (FnVal $pb '不适合')
$lines += Row '学习成本（上手难度）' $pa.tags.'上手难度' $pb.tags.'上手难度'
$lines += Row '运行环境（语言）' $pa.language $pb.language
$lines += Row '体验评分' (ExpText $pa) (ExpText $pb)
$lines += Row ('星数（' + $pa.stars.last_snapshot + ' 快照）') $pa.stars.current $pb.stars.current
$lines += Row '最近提交' ($(if ($pa.pushed_at) { try { '{0:yyyy-MM-dd}' -f [datetime]$pa.pushed_at } catch { "$($pa.pushed_at)" } })) ($(if ($pb.pushed_at) { try { '{0:yyyy-MM-dd}' -f [datetime]$pb.pushed_at } catch { "$($pb.pushed_at)" } }))
$lines += Row 'License' $pa.license $pb.license
$lines += Row '风险' ($(if ($pa.risk) { $pa.risk } else { $pa.tags.'风险等级' })) ($(if ($pb.risk) { $pb.risk } else { $pb.tags.'风险等级' }))
$lines += Row '档位' ($(if ($pa.tier) { "$($pa.tier) 档" } else { '—' })) ($(if ($pb.tier) { "$($pb.tier) 档" } else { '—' }))

# 怎么选（自动判断，只基于数据，不做价值背书）
$sugg = @()
$ea = $pa.experience; $eb = $pb.experience
if ($null -ne $ea.stars -and $null -ne $eb.stars -and $ea.stars -ne $eb.stars) {
  $win = if ($ea.stars -gt $eb.stars) { $pa.id } else { $pb.id }
  $sugg += "体验评分更高：**$win**（$($ea.stars)★ vs $($eb.stars)★）"
}
$ra = if ($pa.risk) { $pa.risk } else { $pa.tags.'风险等级' }
$rb = if ($pb.risk) { $pb.risk } else { $pb.tags.'风险等级' }
if ($ra -and $rb -and $ra -ne $rb) {
  $rank = @{ '低' = 1; '中' = 2; '高' = 3 }
  $win = if ($rank[$ra] -lt $rank[$rb]) { $pa.id } else { $pb.id }
  $sugg += "风险更低：**$win**（$ra vs $rb）"
}
$da = $pa.tags.'上手难度'; $db = $pb.tags.'上手难度'
if ($da -and $db -and $da -ne $db) {
  $rank2 = @{ '开箱即用' = 1; '轻配置' = 2; '要编程' = 3; '要部署' = 4 }
  if ($rank2[$da] -and $rank2[$db] -and $rank2[$da] -lt $rank2[$db]) { $sugg += "更易上手：**$($pa.id)**（$da vs $db）" }
  elseif ($rank2[$da] -and $rank2[$db]) { $sugg += "更易上手：**$($pb.id)**（$db vs $da）" }
}
$lines += ""
$lines += "## 怎么选（自动判断，仅供参考）"
$lines += ""
if ($sugg.Count) { $sugg | ForEach-Object { $lines += "- $_" } }
else { $lines += "- 两者在评分 / 风险 / 上手难度上没有拉开差距，建议按使用场景选（见上面「常见用途」行）" }
$lines += ""
$lines += "> 判断只基于本地数据（体验评分 / 风险 / 上手难度），不构成使用担保；用前请看各自仓库的 License 与最近维护状态。"

$out = $lines -join "`r`n"
Write-Host ""
Write-Host $out
Write-Host ""

if ($Save) {
  $dir = P 'reports\comparisons'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $safeA = ($pa.id -replace '[/\\]', '_'); $safeB = ($pb.id -replace '[/\\]', '_')
  $file = Join-Path $dir ("{0}-{1}-vs-{2}.md" -f (Get-Date -Format 'yyyy-MM-dd'), $safeA, $safeB)
  [System.IO.File]::WriteAllText($file, $out + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "已保存：$file" -ForegroundColor Green
}
