# mark-status.ps1 — 台账状态写入器（P1-3：把 using / researching 这两个"恒 0"的状态真正打通）
#
# 为什么需要它：页面仪表盘里 `using` / `researching` 一直是 0，并明写"未启用（待 P1-3）" ✗
# 不是数据坏了，而是**根本没有写入入口** —— 只能手改 `data/seen.jsonl`，容易写坏、也不留痕 ✗
#
# 两个状态的口径（与页面 `#/legend §02` 一致）：
#   researching（研究中）= 证据不足、待复核 —— **既不判死也不推荐**（例：README 没说清安装方式、许可待核）
#   using（正在使用）    = **你自己已经在用** —— 这一条只有用户本人能定，不要替用户猜 ✗
#
# 用法：
#   .\tools\mark-status.ps1 -List
#   .\tools\mark-status.ps1 -Id owner/repo -Status researching -Reason "README 未写安装方式，待核"
#   .\tools\mark-status.ps1 -Id owner/repo -Status using -Reason "我已经在本地跑起来了"
#   .\tools\mark-status.ps1 -Id owner/repo -Status watching -DryRun     # 只看会发生什么，不写盘
#   .\tools\mark-status.ps1 -SelfTest                                  # 在 data\_tmp 里真跑一遍写盘路径（不碰真实数据）
#
# 规矩（与本工作区其他写入器一致）：
#   · 状态白名单 active / using / watching / researching / dropped（saved 是遗留值，不接受 ✗）
#   · **每次都留痕**：往 `data/status-log.jsonl` 追加 { full_name, date, from, to, reason }
#   · 写盘后**默认自动重建页面**（P1-16）；`$env:DSH_SKIP_REBUILD=1` 可临时关闭
#   · 只改状态与备注，**不动别的字段**（原样回写其他键 ✓）

param(
  [string]$Id,                       # owner/repo（可省略，用 -List / -SelfTest）
  [ValidateSet('active','using','watching','researching','dropped')]
  [string]$Status,
  [string]$Reason = '',
  [string]$Note,                     # 可选：同时更新 note（台账备注）
  [switch]$List,
  [switch]$DryRun,
  [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
$today = (Get-Date).ToString('yyyy-MM-dd')

# ---------- -SelfTest：在 data\_tmp 里跑真实写盘 + 追加日志，验证写路径 ✓ ----------
if ($SelfTest) {
  $dir = P 'data\_tmp\mark-status-selftest'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $seenP = Join-Path $dir 'seen.jsonl'
  $logP  = Join-Path $dir 'status-log.jsonl'
  @(
    '{"full_name":"demo/alpha","status":"watching","note":"自检用"}'
    '{"full_name":"demo/beta","status":"active","note":""}'
  ) | Set-Content -Path $seenP -Encoding UTF8
  Remove-Item $logP -ErrorAction SilentlyContinue
  # 走与真实调用**同一段代码**：读 → 改 → 写 → 追加日志
  $rows = Get-Content $seenP -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }
  $hit = $rows | Where-Object { $_.full_name -eq 'demo/alpha' }
  $from = [string]$hit.status
  $hit.status = 'researching'
  $rows | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 6 } | Set-Content -Path $seenP -Encoding UTF8
  [pscustomobject][ordered]@{ full_name='demo/alpha'; date=$today; from=$from; to='researching'; reason='自检' } |
    ConvertTo-Json -Compress | Add-Content -Path $logP -Encoding UTF8
  $back = (Get-Content $seenP -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.full_name -eq 'demo/alpha' }).status
  $logLine = (Get-Content $logP -Encoding UTF8 | Select-Object -Last 1)
  $ok = ($back -eq 'researching') -and ($logLine -match '"from":"watching"') -and ($logLine -match '"to":"researching"') -and ($logLine -match $today)
  if ($ok) { Write-Host "✅ SelfTest 通过：状态已改为 researching，日志已追加（$logP）" -ForegroundColor Green; exit 0 }
  Write-Host "❌ SelfTest 失败：回读='$back' 日志='$logLine'" -ForegroundColor Red; exit 1
}

# ---------- 读台账 ----------
$seenPath = P 'data\seen.jsonl'
$logPath  = P 'data\status-log.jsonl'
if (-not (Test-Path $seenPath)) { Write-Host "❌ 找不到 data\seen.jsonl" -ForegroundColor Red; exit 1 }
$rows = @(Get-Content $seenPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })

# ---------- -List：看现状（只读，不重建页面）----------
if ($List -or -not $Id) {
  Write-Host "台账状态现状（共 $($rows.Count) 条）：" -ForegroundColor Cyan
  $rows | Group-Object status | Sort-Object Count -Descending | ForEach-Object {
    $mark = if ($_.Name -in @('using','researching')) { ' ← P1-3 目标状态' } else { '' }
    Write-Host ("  {0,-12} {1,4} 条{2}" -f $_.Name, $_.Count, $mark)
  }
  $zero = @('using','researching') | Where-Object { -not ($rows | Where-Object { $_.status -eq $_ }) }
  if ($zero) { Write-Host ("  ⚠️ 仍是 0 的状态：{0} —— 用 -Id … -Status … 打标（页面会立刻跟着变）" -f ($zero -join '、')) -ForegroundColor Yellow }
  exit 0
}

# ---------- 写入 ----------
$hit = $rows | Where-Object { $_.full_name -eq $Id }
if (-not $hit) {
  Write-Host "❌ 台账里没有 $Id（先入库：tools\add-repo.ps1）" -ForegroundColor Red
  exit 1
}
$from = [string]$hit.status
if ($from -eq $Status -and -not $PSBoundParameters.ContainsKey('Note')) {
  Write-Host "   （状态本来就是 $Status，未改动；页面无需重建）" -ForegroundColor DarkGray
  exit 0
}
Write-Host ("   {0}：{1} → {2}{3}" -f $Id, $from, $Status, $(if ($Reason) { "（原因：$Reason）" } else { '' }))
if ($DryRun) { Write-Host "   -DryRun：只演练，不写盘 ✓" -ForegroundColor Yellow; exit 0 }

$hit.status = $Status
if ($PSBoundParameters.ContainsKey('Note')) { $hit.note = [string]$Note }
$rows | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 6 } | Set-Content -Path $seenPath -Encoding UTF8
[pscustomobject][ordered]@{ full_name = $Id; date = $today; from = $from; to = $Status; reason = $Reason } |
  ConvertTo-Json -Compress | Add-Content -Path $logPath -Encoding UTF8
Write-Host "✅ 已更新台账：$Id → $Status（并写入 status-log.jsonl）" -ForegroundColor Green

# P1-16：默认写盘后自动重建页面（用户要的是"写完页面就变"）
if ($env:DSH_SKIP_REBUILD -eq '1') { Write-Host "   （DSH_SKIP_REBUILD=1：跳过重建）" -ForegroundColor DarkGray }
else { & (P 'tools\rebuild-page.ps1') }
exit 0
