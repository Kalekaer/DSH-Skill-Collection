# check-page.ps1 — 真跑一遍 overview.html 的内嵌 JS，验证卡片能点、筛选能用
#
# 为什么需要：单文件页面 JS 出错时**页面照常渲染**，只有点击才暴露。
# 2026-10-13「卡片点不了」就是这类问题（数据里混进 [null] → detail() 抛 TypeError）。
# 语法检查、数据检查都抓不到，只有真执行才行。
#
# 用法：& ".\tools\check-page.ps1"
# 退出码：0 = PASS，1 = FAIL
#
# JS 运行时优先级：PATH 里的 node → DSH 自带的 Electron（ELECTRON_RUN_AS_NODE=1 当 Node 用）
# 注意：本机 shell 连不通网络与此无关；这里只做本地文件求值。

$ErrorActionPreference = 'Stop'
# Electron 每次启动都会在 CWD 写 crashpad 日志（debug.log）—— 运行期垃圾，跑完就删
Remove-Item (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'debug.log') -Force -ErrorAction SilentlyContinue
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$ovPath = P 'overview.html'
if (-not (Test-Path $ovPath)) { Write-Host "❌ 找不到 overview.html，先跑 build-overview.ps1" -ForegroundColor Red; exit 1 }

# 抽出内嵌 JS
$html = Get-Content $ovPath -Raw -Encoding UTF8
$m = [regex]::Match($html, '(?s)<script>(.*)</script>')
if (-not $m.Success) { Write-Host "❌ 页面里找不到 <script> 块" -ForegroundColor Red; exit 1 }

$tmp = P 'data\_tmp'
if (-not (Test-Path $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }
$pageJs = Join-Path $tmp 'page.js'
$resFile = Join-Path $tmp 'check-page-result.txt'
$harness = P 'tools\check-page.js'
[System.IO.File]::WriteAllText($pageJs, $m.Groups[1].Value, (New-Object System.Text.UTF8Encoding($false)))
Remove-Item $resFile -ErrorAction SilentlyContinue

# 找 JS 运行时
$node = Get-Command node -ErrorAction SilentlyContinue
$exe = $null; $useElectron = $false
if ($node) { $exe = $node.Source }
else {
  foreach ($cand in @("$env:ProgramFiles\DSH Desktop\DSH Desktop.exe", 'E:\DSH Desktop\DSH Desktop.exe', "${env:LOCALAPPDATA}\Programs\DSH Desktop\DSH Desktop.exe")) {
    if ($cand -and (Test-Path $cand)) { $exe = $cand; $useElectron = $true; break }
  }
}
if (-not $exe) { Write-Host "❌ 没有可用的 JS 运行时（既没有 node，也没找到 DSH Desktop.exe）" -ForegroundColor Red; exit 1 }

if ($useElectron) {
  # Electron 是 GUI 子系统程序：用 `&` 调用时，只要外层再套一层管道/重定向，
  # PowerShell 就会报「StandardOutputEncoding is only supported when standard output is redirected」。
  # 用 Start-Process 起独立进程，彻底避开标准流接管问题（子进程自己写结果文件）。
  $env:ELECTRON_RUN_AS_NODE = '1'
  try {
    Start-Process -FilePath $exe -ArgumentList @($harness, $pageJs, $resFile) -NoNewWindow -Wait
  } finally {
    Remove-Item Env:\ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
  }
} else {
  & $exe $harness $pageJs $resFile
}
Start-Sleep -Seconds 2

if (-not (Test-Path $resFile)) { Write-Host "❌ 检查未产出结果（运行时启动失败？）" -ForegroundColor Red; exit 1 }

$lines = Get-Content $resFile -Encoding UTF8
$lines | ForEach-Object { Write-Host "  $_" }
$verdict = ($lines | Where-Object { $_ -match '^RESULT:' } | Select-Object -Last 1)
Write-Host ""
if ($verdict -match 'PASS') { Write-Host "PAGE CHECK: PASS —— 卡片可点、筛选可用、数据无 null 元素" -ForegroundColor Green; exit 0 }
else { Write-Host "PAGE CHECK: FAIL —— 见上面 ❌ 行" -ForegroundColor Red; exit 1 }

# Electron 在运行过程中会重新生成 crashpad 日志 —— 结束时再清一次，保持工作区干净
Remove-Item (Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'debug.log') -Force -ErrorAction SilentlyContinue
