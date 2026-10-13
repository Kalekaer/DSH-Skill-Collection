# workspace.ps1 — 我的工作区（写 data/workspaces.jsonl）
#
# 与 plans.json 的分工（GPT 评审定的）：
#   plans.json        = **官方模板**：「做 AI 视频」该走哪几步，不可变、人人一样
#   workspaces.jsonl  = **用户实例**：「我的 B 站视频工作区」，有目标、进度、备注，你自己增删改
#
# 用法：
#   & ".\tools\workspace.ps1" -List
#   & ".\tools\workspace.ps1" -New -Id "bilibili-video" -Name "我的 B 站视频工作区" `
#       -Goal "每周做 2 条 AI 短视频" -Note "主要做游戏区" -Tools "owner/repo1,owner/repo2"
#   & ".\tools\workspace.ps1" -Add -Id "bilibili-video" -Tools "owner/repo3"
#   & ".\tools\workspace.ps1" -Done -Id "bilibili-video" -Tools "owner/repo1"    # 勾选已完成
#   & ".\tools\workspace.ps1" -Status -Id "bilibili-video" -Value "已完成"
#   & ".\tools\workspace.ps1" -Remove -Id "bilibili-video"
param(
  [switch]$List,
  [switch]$New,
  [switch]$Add,
  [switch]$Done,
  [switch]$Remove,
  [switch]$Status,
  [string]$Id = '',
  [string]$Name = '',
  [string]$Goal = '',
  [string]$Note = '',
  [string]$Tools = '',
  [string]$Value = '',
  [switch]$Sync
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
$wsPath = P 'data\workspaces.jsonl'

function Read-WS {
  $out = @()
  if (Test-Path $wsPath) {
    foreach ($l in (Get-Content $wsPath -Encoding UTF8)) {
      if ([string]::IsNullOrWhiteSpace($l)) { continue }
      try { $out += ($l | ConvertFrom-Json) } catch {}
    }
  }
  return $out
}
function Write-WS($items) {
  $lines = foreach ($w in $items) {
    [pscustomobject][ordered]@{
      id = "$($w.id)"; name = "$($w.name)"; goal = "$($w.goal)"
      status = "$($w.status)"; tools = @($w.tools); done = @($w.done)
      note = "$($w.note)"; created = "$($w.created)"; updated = "$($w.updated)"
    } | ConvertTo-Json -Compress -Depth 4
  }
  [System.IO.File]::WriteAllLines($wsPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
}
function Split-Tools([string]$t) {
  if (-not $t) { return @() }
  return @($t -split '[,，]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

$ws = Read-WS
$today = (Get-Date).ToString('yyyy-MM-dd')

if ($List -or (-not $New -and -not $Add -and -not $Done -and -not $Remove -and -not $Status)) {
  Write-Host ""
  Write-Host ("=== 我的工作区（{0} 个）===" -f @($ws).Count) -ForegroundColor Cyan
  foreach ($w in $ws) {
    $n = @($w.tools).Count; $d = @($w.done).Count
    Write-Host ("  📌 {0}  [{1}] {2}/{3} 完成" -f $w.name, $w.status, $d, $n) -ForegroundColor White
    if ($w.goal) { Write-Host ("      目标：{0}" -f $w.goal) -ForegroundColor Gray }
    foreach ($t in @($w.tools)) { Write-Host ("      $(if(@($w.done) -contains $t){'✅'}else{'⬜'}) $t") -ForegroundColor DarkGray }
  }
  if (-not @($ws).Count) { Write-Host "  （空。用 -New 建一个）" -ForegroundColor DarkGray }
  Write-Host ""
  exit 0
}

if (-not $Id) { Write-Host "❌ 需要 -Id" -ForegroundColor Red; exit 1 }
$exist = @($ws | Where-Object { "$($_.id)" -eq $Id })[0]

if ($Remove) {
  if (-not $exist) { Write-Host "没有这个工作区：$Id" -ForegroundColor Yellow; exit 0 }
  Write-WS @($ws | Where-Object { "$($_.id)" -ne $Id })
  Write-Host "✅ 已删除工作区：$Id" -ForegroundColor Green
} elseif ($New) {
  if ($exist) { Write-Host "❌ 已存在同名 id：$Id（改名或先 -Remove）" -ForegroundColor Red; exit 1 }
  if (-not $Name) { Write-Host "❌ -New 需要 -Name" -ForegroundColor Red; exit 1 }
  $item = [pscustomobject][ordered]@{
    id = $Id; name = $Name; goal = $Goal; status = '进行中'
    tools = (Split-Tools $Tools); done = @(); note = $Note; created = $today; updated = $today
  }
  Write-WS @(@($ws) + $item)
  Write-Host ("✅ 已建工作区：{0}（{1} 个工具）" -f $Name, @($item.tools).Count) -ForegroundColor Green
} else {
  if (-not $exist) { Write-Host "❌ 没有这个工作区：$Id" -ForegroundColor Red; exit 1 }
  $t = @($exist.tools); $dn = @($exist.done)
  if ($Add)    { foreach ($x in (Split-Tools $Tools)) { if ($t -notcontains $x) { $t += $x } } }
  if ($Done)   { foreach ($x in (Split-Tools $Tools)) { if ($dn -notcontains $x) { $dn += $x } } }
  $st = if ($Status -and $Value) { $Value } else { "$($exist.status)" }
  $item = [pscustomobject][ordered]@{
    id = $exist.id; name = $exist.name; goal = "$($exist.goal)"; status = $st
    tools = $t; done = $dn; note = "$($exist.note)"; created = "$($exist.created)"; updated = $today
  }
  Write-WS @(@($ws | Where-Object { "$($_.id)" -ne $Id }) + $item)
  Write-Host ("✅ 已更新工作区：{0}（{1} 个工具，{2} 个完成）" -f $item.name, $t.Count, $dn.Count) -ForegroundColor Green
}

if ($Sync) {
  & (P 'tools\build-overview.ps1')
}
