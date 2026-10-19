# add-plan.ps1 — 把对话里配好的一套搭配，固化成网页里的固定方案
#
# 用途：`/tool-stack` 给出一套搭配后，用户说「写进网页里」→ 本脚本把它加进 data/plans.json，
#       之后 overview.html 的「🧩 按需求组方案」就多一个场景，用户自己点一下就能看。
#
# 用法：
#   & ".\tools\add-plan.ps1" -Id "ai-music" -Name "做 AI 音乐" -Triggers "音乐生成,做音乐,作曲" `
#     -Intro "做一段音乐通常要过这几步……" -Roles @(
#       @{ role='旋律生成'; why='音乐主体从这里来'; l2='AI音乐'; ft='音乐生成' },
#       @{ role='后期处理'; why='混音与母带';       l2='音频处理'; ft='音频编辑' }
#     ) -Sync
#
# 纪律：查重（id 或 name 重复直接拒绝，除非 -Force）；roles 的 l2/ft 可以留空的期望值，
#       页面匹配不到会显示「库里暂无」，等库大了自动填上。
param(
  [Parameter(Mandatory=$true)][string]$Id,
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$Triggers,
  [string]$Intro = '',
  [Parameter(Mandatory=$true)][array]$Roles,
  [switch]$Force,
  [switch]$Sync
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
$planPath = P 'data\plans.json'
if (-not (Test-Path $planPath)) { Write-Host "❌ 找不到 data\plans.json" -ForegroundColor Red; exit 1 }

$doc = Get-Content $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
$plans = @($doc.plans)

if (-not $Force) {
  $dupId = @($plans | Where-Object { $_.id -eq $Id })
  $dupName = @($plans | Where-Object { $_.name -eq $Name })
  if ($dupId.Count) { Write-Host "❌ 已存在同 id 的方案：$Id（要覆盖请加 -Force）" -ForegroundColor Red; exit 1 }
  if ($dupName.Count) { Write-Host "❌ 已存在同名方案：$Name（要覆盖请加 -Force）" -ForegroundColor Red; exit 1 }
}

$toArr = { param($v) if (-not $v) { return @() }; return @(@("$v" -split '[,，]') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$roleObjs = @()
foreach ($r in $Roles) {
  $roleObjs += [pscustomobject][ordered]@{
    role = "$($r.role)"
    why  = "$($r.why)"
    l2   = @(& $toArr $r.l2)
    ft   = @(& $toArr $r.ft)
  }
}
$new = [pscustomobject][ordered]@{
  id       = $Id
  name     = $Name
  triggers = @(& $toArr $Triggers)
  intro    = $Intro
  roles    = $roleObjs
}
$plans = @($plans) + $new
$doc.plans = $plans
$doc._版本 = '1.1.0'

$doc | ConvertTo-Json -Depth 10 | Set-Content -Path $planPath -Encoding UTF8
Write-Host ("✅ 已加入方案：{0}（{1} 个角色）→ data\plans.json（现有 {2} 个方案）" -f $Name, $roleObjs.Count, $plans.Count) -ForegroundColor Green
Write-Host "   下一步：页面会自动重建（见下）；想额外做一次页面自检就加 -Sync" -ForegroundColor DarkGray

# P1-16：**默认**写盘后自动重建页面（原来是加 -Sync 才重建 → 用户要的是"写完页面就变"）
#   -Sync 保留兼容（额外跑一次页面自检）；$env:DSH_SKIP_REBUILD=1 可临时关闭自动重建
& (P 'tools\rebuild-page.ps1')
if ($Sync) { & (P 'tools\check-page.ps1') }
