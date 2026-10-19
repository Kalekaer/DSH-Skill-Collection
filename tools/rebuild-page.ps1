# rebuild-page.ps1 — 「写入即重建」统一入口（P1-16）
#
# 谁调它：**各个写入器在成功写盘之后**调一次（add-repo / auto-tag -Apply / add-intro /
#         add-plan / workspace / fetch-series / intake-check -Apply / gaps …）。
# 它做什么：sync-projects（重建投影）→ build-overview（重建页面）→ **自检页面确实变新了**。
#
# 为什么不用文件监听器（FileSystemWatcher）：要常驻进程、事件会抖（一次写盘触发多次）、
# 沙箱里还得多养一个后台进程 ✗ —— 用户要的是"库里写入东西，页面同时更新"，
# **写后钩子 + 单实例锁**就够，且行为可预测 ✓
#
# 开关：
#   $env:DSH_SKIP_REBUILD=1    跳过重建（批量操作 / 测试 / 想手动控制时用）
#   $env:DSH_REBUILD_LOCK=1    （内部）防递归与并发
#   -Quiet                     只静默**进度**；⚠️ **错误与自检失败永远打印**（2026-10-16 教训：
#                              第一版把错误也静默了 → 失败时"什么都不说、退出码 1"，无法排查 ✗）
# 退出码：0 = 重建成功 ｜ 1 = 重建失败（页面可能仍是旧内容）
#
# 用法：& ".\tools\rebuild-page.ps1" [-Quiet] [-Force]

param(
  [switch]$Quiet,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

# $Always=true 的行不受 -Quiet 影响（错误、自检结论必须看得见）
function Say([string]$msg, [string]$color = 'Gray', [switch]$Always) {
  if ($Always -or -not $Quiet) { Write-Host $msg -ForegroundColor $color }
}
function Fail([string]$msg, $extra) {
  Say ""
  Say "   ❌ $msg" 'Red' -Always
  if ($extra) { @($extra) | Select-Object -Last 8 | ForEach-Object { Say "      $_" 'DarkRed' -Always } }
  Say "   → 页面可能仍是旧内容；修好后重跑：& `".\tools\rebuild-page.ps1`"" 'Red' -Always
  exit 1
}

if ($env:DSH_SKIP_REBUILD -and $env:DSH_SKIP_REBUILD -ne '0') {
  Say "   ↷ 跳过自动重建（DSH_SKIP_REBUILD=1）" 'DarkGray'; exit 0
}
if ($env:DSH_REBUILD_LOCK) {
  Say "   ↷ 已在重建中，跳过重复触发" 'DarkGray'; exit 0
}

$env:DSH_REBUILD_LOCK = '1'
try {
  $ovPath = P 'legacy\overview-v5.html'
  $before = if (Test-Path $ovPath) { (Get-Item $ovPath).LastWriteTime } else { [datetime]::MinValue }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()

  Say "== 自动重建页面（P1-16：写盘后同步）==" 'Cyan'

  # ⚠️ 两个坑（2026-10-16 实测踩到）：
  #   ① `$out = & script` **抓不到 Write-Host 的输出**（它走信息流，不进取值流）→ 必须 `*>&1`；
  #   ② 数组 splat `@('-Force')` 会被当成**位置参数**（实测报「无法把 '-Force' 转成 Int32」）
  #      → 具名参数要**显式分支**传，别用 splat。
  try {
    $LASTEXITCODE = 0   # 先清残留，见下方坑③
    if ($Force) { $syncOut = & (P 'tools\sync-projects.ps1') -Force *>&1 }
    else        { $syncOut = & (P 'tools\sync-projects.ps1') *>&1 }
  } catch {
    Fail "sync-projects 抛错：$($_.Exception.Message)" ($_ | Out-String)
  }
  # ⚠️ 坑③（2026-10-16 实测，最难查的一个）：`$LASTEXITCODE` 是**粘的** —— 被调脚本不显式
  #    `exit` 时它**不会更新**，会残留同进程里上一条命令的退出码。实测：audit 刚 `exit 1`，
  #    紧接着 sync 明明成功，这里却读到 1 → 误判「投影重建失败」→ build 根本没跑、页面一直是旧的 ✗
  #    对策：① 调用前清 0；② **以输出里的成功标志为主判据**（下面那段）；③ 已给 sync/build 末尾补 `exit 0`（根治）
  $syncExit = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  if ($syncExit -ne 0) { Fail "投影重建失败（sync-projects 退出码 $syncExit）" $syncOut }

  # 静默也要能证明它跑过（踩坑 #2：只跑语法检查 ≠ 真跑过）
  # 三种都算成功：① 真重建（"=== 同步完成 ===" + projects 行）② 幂等跳过（"输入未变化，跳过重建"）
  #   ⚠️ ② 是**正常路径**（同一份数据重复触发写后钩子），一开始我只认 ① → 当场误报 ❌
  $syncLine   = @($syncOut | Where-Object { $_ -match 'projects\.jsonl\s*:' }) | Select-Object -First 1
  $evLine     = @($syncOut | Where-Object { $_ -match 'events\.jsonl\s*:' }) | Select-Object -First 1
  $didRebuild = [bool]($syncOut -match '同步完成')
  $didSkip    = [bool]($syncOut -match '输入未变化|跳过重建')
  if (-not $didRebuild -and -not $didSkip) {
    Fail "sync-projects 没有输出成功标志（既无『同步完成』也无『输入未变化』）—— 拒绝当成功" $syncOut
  }
  if ($syncLine) { Say ("   ↳ " + ($syncLine -replace '^\s+', '')) 'DarkGray' }
  if ($evLine)   { Say ("   ↳ " + ($evLine -replace '^\s+', '')) 'DarkGray' }
  if ($didSkip -and -not $syncLine) {
    $skipLine = @($syncOut | Where-Object { $_ -match '输入未变化|跳过重建' }) | Select-Object -First 1
    Say ("   ↳ 投影无需重建（" + ($skipLine -replace '^\s+', '') + "）") 'DarkGray'
  }

  # 入库即自动补标签（2026-10-18 起）：不再等人确认；auto-tag 内部会做两次复核
  try {
    $LASTEXITCODE = 0
    $tagOut = & (P 'tools\auto-tag.ps1') -Apply -NoRebuild *>&1
    foreach ($l in @($tagOut | Where-Object { $_ -match '已写入|复核补写|复核：' })) {
      Say ("   ↳ " + ($l -replace '^\s+', '')) 'DarkGray'
    }
  } catch {
    Say ("   ⚠ 自动补标签失败（继续重建）：" + $_.Exception.Message) 'Yellow'
  }
  # 标签是 human 层，写完后必须再投影一次，页面才拿得到
  try {
    $LASTEXITCODE = 0
    $sync2 = & (P 'tools\sync-projects.ps1') -Force *>&1
  } catch {
    Fail "标签写入后二次投影失败：$($_.Exception.Message)" ($_ | Out-String)
  }
  if ($LASTEXITCODE -ne 0) { Fail "标签写入后二次投影失败（sync-projects 退出码 $LASTEXITCODE）" $sync2 }

  try { $LASTEXITCODE = 0; $buildOut = & (P 'tools\build-overview.ps1') *>&1 }
  catch { Fail "build-overview 抛错：$($_.Exception.Message)" ($_ | Out-String) }
  $buildExit = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  if ($buildExit -ne 0) { Fail "页面生成失败（build-overview 退出码 $buildExit）" $buildOut }

  # 旧版工具库重建后，再重建新站点（data/site + 根入口），保证写后钩子两套都更新
  try { $LASTEXITCODE = 0; $siteOut = & (P 'tools\build-samples.ps1') *>&1 }
  catch { Fail "build-samples 抛错：$($_.Exception.Message)" ($_ | Out-String) }
  $siteExit = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  if ($siteExit -ne 0) { Fail "站点重建失败（build-samples 退出码 $siteExit）" $siteOut }

  # ---------- 自检：页面必须真的变新（P1-17 的不变量，这里先自查一次）----------
  $after = if (Test-Path $ovPath) { (Get-Item $ovPath).LastWriteTime } else { [datetime]::MinValue }
  $html  = if (Test-Path $ovPath) { [System.IO.File]::ReadAllText($ovPath) } else { '' }
  $stamp = ([regex]::Match($html, '<!-- BUILD-STAMP: (.*?) -->')).Groups[1].Value
  $kb    = [math]::Round((Get-Item $ovPath).Length / 1KB, 1)
  $sw.Stop()

  if ($after -le $before) {
    Fail "页面时间戳没变（仍是 $($before.ToString('HH:mm:ss.fff'))）—— build-overview 没有真正写盘" $buildOut
  }
  if (-not $stamp) { Fail "页面里找不到 BUILD-STAMP —— 生成器可能被改坏" $buildOut }

  Say "   ✅ 页面已重建：$stamp（$kb KB，$([math]::Round($sw.Elapsed.TotalSeconds,1)) 秒）" 'Green'
  exit 0
}
finally {
  Remove-Item Env:\DSH_REBUILD_LOCK -ErrorAction SilentlyContinue
}
