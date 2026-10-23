# daily-backup.ps1 — 日报开工前的轻量数据备份（只读源文件，写 data/_backup/<date>/）
#
# 为什么：七件事顺序写、没有事务；失败时至少能回到开工前。
# 备份：台账、CSV、当日 picks/快照/元数据、投影（projects/events）、状态日志。
# 默认不覆盖已有备份；需要重做用 -Force。
#
# 用法：
#   .\tools\daily-backup.ps1
#   .\tools\daily-backup.ps1 -Date 2026-10-18
#   .\tools\daily-backup.ps1 -Force
# 退出码：0 = 已备份/已存在；1 = 失败

param(
  [string]$Date = '',
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { Write-Host "✗ 日期格式应为 YYYY-MM-DD：$Date" -ForegroundColor Red; exit 1 }

$dest = P "data\_backup\$Date\pre-daily"
if ((Test-Path $dest) -and -not $Force) {
  Write-Host "↷ 已存在备份：$dest（未覆盖；需要重做加 -Force）" -ForegroundColor DarkGray
  exit 0
}
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest -Force | Out-Null

$files = @(
  'data\seen.jsonl',
  'data\recommend-log.csv',
  'data\projects.jsonl',
  'data\events.jsonl',
  'data\status-log.jsonl',
  "data\picks\$Date.jsonl",
  "data\snapshots\$Date.jsonl",
  "data\meta\$Date.jsonl"
)

$copied = @()
foreach ($rel in $files) {
  $src = P $rel
  if (Test-Path $src) {
    $sub = Split-Path $rel -Parent
    $subName = if ($sub -match '^data\\(.+)$') { $Matches[1] } else { '' }
    $targetDir = if ($subName) { Join-Path $dest $subName } else { $dest }
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    $target = Join-Path $targetDir (Split-Path $rel -Leaf)
    Copy-Item $src $target -Force
    $copied += [ordered]@{
      file = $rel
      bytes = (Get-Item $src).Length
      sha256 = (Get-FileHash $src -Algorithm SHA256).Hash
    }
  }
}

$manifest = [ordered]@{
  date = $Date
  created_at = (Get-Date).ToString('o')
  source_root = $root
  files = $copied
}
[IO.File]::WriteAllText((Join-Path $dest 'manifest.json'), ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
Write-Host "✅ 备份 $($copied.Count) 个文件 → $dest" -ForegroundColor Green
