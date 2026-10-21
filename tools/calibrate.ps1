# calibrate.ps1 — 黄金集校准（2026-10-21 P2）
#
# 用途：拿人工/预判标签对 agent 的推荐判断做一致性检查，改 rubric 前后各跑一次。
# 只读；输出 Markdown 报告（默认写 data/_tmp/calibration.md）。
#
# 标签映射（4 类 → 0–5）：
#   🔥必须推 = 5 ｜ 👍值得入库 = 4 ｜ 😐留观 = 3 ｜ 🗑应淘汰 = 1
#
# 用法：
#   .\tools\calibrate.ps1
#   .\tools\calibrate.ps1 -Out data\runs\calibration-2026-10-21.md
#   .\tools\calibrate.ps1 -UseGuess:$false   # 只用 human 字段（当前为空，会提示样本不足）

[CmdletBinding()]
param(
  [string]$Golden = 'data\golden-set.jsonl',
  [string]$Out = '',
  [bool]$UseGuess = $true,
  [string]$HumanCsv = 'data\golden-set.human.csv'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$enc = New-Object System.Text.UTF8Encoding($false)
$gp = Join-Path $root $Golden
if (-not (Test-Path $gp)) { Write-Host "✗ 找不到 $Golden" -ForegroundColor Red; exit 1 }

function Map-Label([string]$s) {
  switch -Regex ($s) {
    '必须推' { return 5 }
    '值得' { return 4 }
    '留观|观察' { return 3 }
    '淘汰|不推|避雷' { return 1 }
    default { return $null }
  }
}

$humanMap = @{}
if (Test-Path (Join-Path $root $HumanCsv)) {
  try {
    foreach ($h in (Import-Csv (Join-Path $root $HumanCsv) -Encoding UTF8)) {
      if ($h.id -and $h.human_0_5 -match '^\s*[0-5]\s*$') { $humanMap[[string]$h.id] = [int]$h.human_0_5 }
    }
  } catch { }
}
$rows = @()
foreach ($l in [IO.File]::ReadAllLines($gp, [Text.Encoding]::UTF8)) {
  if (-not $l.Trim()) { continue }
  try { $o = $l | ConvertFrom-Json } catch { continue }
  if ($humanMap.Count -gt 0 -and -not $humanMap.ContainsKey([string]$o.id)) { continue }
  $humanRaw = if ($humanMap.ContainsKey([string]$o.id)) { [string]$humanMap[[string]$o.id] } elseif ($UseGuess -and -not [string]$o.human) { [string]$o.guess } else { [string]$o.human }
  $hr = if ($humanRaw -match '^\s*[0-5]\s*$') { [int]$humanRaw } else { Map-Label $humanRaw }
  $ar = Map-Label ([string]$o.agent)
  if ($null -eq $hr -or $null -eq $ar) { continue }
  $rows += [pscustomobject]@{ id = [string]$o.id; humanRaw = $humanRaw; human = $hr; agent = $ar; why = [string]$o.agent_why; source = $(if ([string]$o.human) { 'human' } else { 'guess' }) }
}

if (-not $rows.Count) { Write-Host '没有可用标签。' -ForegroundColor Yellow; exit 0 }
$n = $rows.Count
$exact = @($rows | Where-Object { $_.human -eq $_.agent }).Count
$within1 = @($rows | Where-Object { [math]::Abs($_.human - $_.agent) -le 1 }).Count
$mae = [math]::Round((($rows | ForEach-Object { [math]::Abs($_.human - $_.agent) }) | Measure-Object -Average).Average, 3)

# Cohen's kappa（4 类，未加权）
$cats = @(5, 4, 3, 1)
$po = $exact / $n
$pe = 0.0
foreach ($c in $cats) {
  $ph = @($rows | Where-Object { $_.human -eq $c }).Count / $n
  $pa = @($rows | Where-Object { $_.agent -eq $c }).Count / $n
  $pe += $ph * $pa
}
$kappa = if ($pe -lt 1) { [math]::Round(($po - $pe) / (1 - $pe), 3) } else { $null }

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('# 黄金集校准报告')
[void]$lines.Add('')
$labelSrc = if ($humanMap.Count -gt 0) { '`human` CSV（data/golden-set.human.csv）' } elseif ($UseGuess) { '`guess`（human 为空时的代用）' } else { '`human`' }
[void]$lines.Add("样本：**$n** 条 ｜ 标签来源：" + $labelSrc)
[void]$lines.Add('')
[void]$lines.Add('| 指标 | 值 |')
[void]$lines.Add('|---|---|')
[void]$lines.Add("| 完全一致 | $exact / $n（$([math]::Round(100*$po,1))%） |")
[void]$lines.Add("| 相差 ≤1 档 | $within1 / $n（$([math]::Round(100*$within1/$n,1))%） |")
[void]$lines.Add("| 平均绝对误差 MAE | $mae |")
[void]$lines.Add("| Cohen's κ | $kappa |")
[void]$lines.Add('')
[void]$lines.Add('## 混淆矩阵（行=人类，列=agent）')
[void]$lines.Add('')
[void]$lines.Add('| 人类 \ agent | 5 必须推 | 4 值得 | 3 留观 | 1 淘汰 |')
[void]$lines.Add('|---|---:|---:|---:|---:|')
foreach ($h in $cats) {
  $cells = foreach ($a in $cats) { @($rows | Where-Object { $_.human -eq $h -and $_.agent -eq $a }).Count }
  [void]$lines.Add("| $h | " + ($cells -join ' | ') + ' |')
}
[void]$lines.Add('')
$dis = @($rows | Where-Object { $_.human -ne $_.agent } | Sort-Object { [math]::Abs($_.human - $_.agent) } -Descending)
[void]$lines.Add("## 分歧清单（$($dis.Count) 条）")
[void]$lines.Add('')
if ($dis.Count) {
  [void]$lines.Add('| 仓库 | 人类 | agent | agent 理由 | 差距 |')
  [void]$lines.Add('|---|---:|---:|---|---:|')
  foreach ($d in $dis) { [void]$lines.Add("| $($d.id) | $($d.human) | $($d.agent) | $($d.why) | $([math]::Abs($d.human-$d.agent)) |") }
} else { [void]$lines.Add('无分歧。') }
[void]$lines.Add('')
if ($n -lt 30) { [void]$lines.Add('> ⚠️ 样本 <30，结论只能看方向，别当验收线。') }
if (-not [string]$Out) { $Out = 'data\_tmp\calibration.md' }
$outPath = Join-Path $root $Out
$dir = Split-Path -Parent $outPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[IO.File]::WriteAllText($outPath, ($lines -join "`r`n"), $enc)

Write-Host ("校准完成：n={0} 一致={1}（{2}%） MAE={3} κ={4}" -f $n, $exact, [math]::Round(100*$po,1), $mae, $kappa) -ForegroundColor Cyan
Write-Host "报告 → $Out" -ForegroundColor DarkGray
