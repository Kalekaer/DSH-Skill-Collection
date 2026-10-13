# daily-questions.ps1 — 跑完日报后，生成「该问用户的几个问题」
#
# 用户要的效果：自动化跑完后，不要只丢一份日报，而是**主动问几件需要他决定的事**。
# 本脚本扫描当天的产物与待办，输出 3–6 条具体问题（每条都带数据依据）——不猜、不空问。
#
# 用法：
#   & ".\tools\daily-questions.ps1"
#   & ".\tools\daily-questions.ps1" -Date 2026-10-13
param(
  [string]$Date = '',
  [int]$Max = 6
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }

function Count-Lines([string]$rel) {
  $p = P $rel
  if (-not (Test-Path $p)) { return 0 }
  return @(Get-Content $p -Encoding UTF8 | Where-Object { $_.Trim() }).Count
}

$q = @()

# ---- ① 今天的推荐里有没有需要人工确认的 ----
$picksPath = P "data\picks\$Date.jsonl"
if (Test-Path $picksPath) {
  $picks = @()
  foreach ($l in (Get-Content $picksPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $picks += ($l | ConvertFrom-Json) } catch {}
  }
  $sa = @($picks | Where-Object { $_.tier -in @('S','A') })
  $high = @($sa | Where-Object { $_.risk -eq '高' })
  if ($sa.Count) { $q += "今天推荐了 $($sa.Count) 条（S/A）。其中安装方式我标了「未验证」的：**要不要我去核一次 README**，把命令补实？" }
  if ($high.Count) { $q += "有 $($high.Count) 条风险等级是「高」：$(($high | ForEach-Object { $_.full_name }) -join '、')。**要不要先看它们的风险说明再决定**？" }
  $dropped = @($picks | Where-Object { $_.tier -eq 'dropped' })
  if ($dropped.Count) { $q += "今天剔除了 $($dropped.Count) 条（合规红线/资源列表等）。**要不要我把剔除理由列给你确认**，确认后记入 90 天冷却？" }
}

# ---- ② 人话层缺口 ----
$projPath = P 'data\projects.jsonl'
$proj = @()
if (Test-Path $projPath) {
  foreach ($l in (Get-Content $projPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $proj += ($l | ConvertFrom-Json) } catch {}
  }
}
$partial = @($proj | Where-Object { $_.human.status -eq 'partial' })
$missing = @($proj | Where-Object { $_.human.status -eq 'missing' })
if ($partial.Count + $missing.Count -gt 0) {
  $q += "库里还有 $($partial.Count) 条只有一句话、$($missing.Count) 条完全没介绍。**要不要我挑其中你感兴趣的几条补全**（需要一次 API 调用核实）？"
}

# ---- ③ 词表/分类/方案的候选积累 ----
$gapN = Count-Lines 'data\search-gaps.jsonl'
if ($gapN) { $q += "有 **$gapN 个搜不到的词**记在缺口清单里（data/search-gaps.jsonl）。要不要我复检一遍并把该补的并进同义词表？" }
$synN = Count-Lines 'data\human\synonym-suggestions.jsonl'
if ($synN) { $q += "同义词候选有 **$synN 个待批**（tools/suggest-terms.ps1 挖的）。要不要我挑最靠前的 5–10 个加进词表？" }
$taxN = Count-Lines 'data\taxonomy-suggestions.jsonl'
if ($taxN) { $q += "分类候选有 **$taxN 条**（data/taxonomy-suggestions.jsonl）。要不要看一眼、批准哪些进正式分类？" }
$planN = Count-Lines 'data\plan-suggestions.jsonl'
if ($planN) { $q += "**方案候选有 $planN 条**：库里有几个用途方向工具攒够了但没有对应场景。要不要我加进 data/plans.json？" }

# ---- ④ 用户推荐的项目是否要处理 ----
$userNew = @($proj | Where-Object { $_.origin -eq 'user' -and $_.tier -eq 'unrated' -and $_.status -ne 'dropped' })
if ($userNew.Count) {
  $q += "你推荐入库的 **$($userNew.Count) 条还是「未评档」**（没进过日报评分）。要不要挑几条走一遍完整评估，或者用 compare.ps1 -Similar 看它们的同类？"
}
$savedN = @($proj | Where-Object { $_.status -eq 'saved' }).Count
if ($savedN) { $q += "你收藏了 **$savedN 条**。要不要我按「按用途分组」给这些收藏也配一套方案（`/tool-stack`）？" }

# ---- ⑤ 今天的日报是否已产出 ----
if (-not (Test-Path (P "reports\$Date.md"))) {
  $q += "**今天的日报文件还没生成**（reports/$Date.md 不存在）。要不要现在跑一遍每日流程？"
}

# ---- 输出 ----
Write-Host ""
Write-Host "=== $Date 收尾追问（挑 3–5 条问用户即可）===" -ForegroundColor Cyan
Write-Host ""
$i = 0
foreach ($item in ($q | Select-Object -First $Max)) {
  $i++
  Write-Host ("  {0}. {1}" -f $i, $item) -ForegroundColor Gray
}
if (-not $q.Count) { Write-Host "  今天没有需要用户决定的事，如实说「一切正常」即可。" -ForegroundColor DarkGray }
Write-Host ""
Write-Host "  规则：**只问需要用户拍板的**，不要拿教程式问题凑数；用户没空就只给第 1 条。" -ForegroundColor DarkGray
