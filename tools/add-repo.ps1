# add-repo.ps1 — 用户主动添加项目（第二阶段功能 ⑥，2026-10-13 产品决策）
#
# 场景：用户在对话里说「这个 GitHub 项目不错：owner/repo」。
# Agent 先用 web_fetch 取 https://api.github.com/repos/{owner}/{repo}（1 次调用，计入当日额度），
# 核实存在性 / License / 活跃度 / 风险，再把返回字段传给本脚本入库。
#
# 本脚本**不做网络请求**（本机 shell 连不通 GitHub）——只负责落盘原始来源并同步。
#
# 用法（Agent 侧）：
#   & ".\tools\add-repo.ps1" -FullName owner/repo -Stars 1234 -Language Rust -License MIT `
#     -Description "..." -PushedAt "2026-10-12T00:00:00Z" -Note "事实性备注" -UserNote "朋友推荐，说很好用"
#   可选：-Status active|using|watching|researching|dropped（默认 watching）　-NoSync（只落盘不重建）
#
# 行为：
#   * 新项目  → 追加 seen.jsonl（origin=user）+ data/meta/今天.jsonl + data/snapshots/今天.jsonl，
#               然后自动跑 sync + build（可用 -NoSync 跳过）
#   * 已存在  → **不重复添加**；把「用户曾推荐过 + 备注」追加进 data/user-notes.jsonl（原始层）
#
# 纪律（与 SKILL.md 第十二节一致）：
#   * 用户推荐 ≠ 日报推荐：origin=user，tier 由 sync 记为 unrated，**不伪装成 S/A/B**
#   * 用户备注是**个人数据**，只进 data/user-notes.jsonl（原始层），不进 human 层（机器生成）
#   * Agent 不得代替用户写备注；用户没说就记「用户再次提及推荐」

param(
  [Parameter(Mandatory=$true)][string]$FullName,
  [string]$Stars = '',
  [string]$Forks = '',
  [string]$Language = '',
  [string]$License = '',
  [string]$Description = '',
  [string]$PushedAt = '',
  [string]$Archived = 'false',
  [string]$Topics = '',           # 逗号分隔，如 "rust,cli"
  [string]$OpenIssues = '',
  [string]$CreatedAt = '',
  [string]$Status = 'watching',
  [string]$Note = '',             # 台账备注（只写事实，不写臆测）
  [string]$UserNote = '',         # 用户备注（用户原话）
  [switch]$NoSync
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

if ($FullName -notmatch '^[A-Za-z0-9_.\-]+/[A-Za-z0-9_.\-]+$') {
  Write-Host "❌ full_name 格式不对：'$FullName'（应为 owner/repo）" -ForegroundColor Red; exit 1
}
$validStatus = @('active','using','watching','researching','dropped')
if ($validStatus -notcontains $Status) {
  Write-Host "❌ status 非法：'$Status'（白名单：$($validStatus -join ' / ')）" -ForegroundColor Red; exit 1
}

$today = (Get-Date).ToString('yyyy-MM-dd')
$now   = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')

# ---- 读台账，判断是否已存在（唯一身份 = full_name）----
$exists = $false
$seenPath = P 'data\seen.jsonl'
if (Test-Path $seenPath) {
  foreach ($l in (Get-Content $seenPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    if ($l -match ('"full_name":"' + [regex]::Escape($FullName) + '"')) { $exists = $true; break }
  }
}

if ($exists) {
  # ---- 路径 A：已在库中 → 不重复创建，只记用户提及 ----
  $noteTxt = if ($UserNote) { $UserNote } else { '用户再次提及推荐（无备注）' }
  $unLine = [pscustomobject]@{ full_name=$FullName; date=$today; note=$noteTxt; by='user' } | ConvertTo-Json -Compress
  Add-Content -Path (P 'data\user-notes.jsonl') -Value $unLine -Encoding UTF8
  Write-Host "↩ $FullName 已在库中，未重复添加；已记录用户提及（$today）：$noteTxt" -ForegroundColor Yellow
} else {
  # ---- 路径 B：新项目入库（origin=user）----
  $row = [ordered]@{
    full_name=$FullName; url="https://github.com/$FullName"
    first_seen=$today; last_seen=$today
    recommended=$false; recommend_count=0
    status=$Status; language=$Language
    first_stars=$(if ($Stars -match '^\d+$') { [int]$Stars } else { $null }); last_stars=$(if ($Stars -match '^\d+$') { [int]$Stars } else { $null })   # B11：schema 要求数字，不能落字符串
    note=$(if ($Note) { $Note } else { '用户推荐入库' })
    origin='user'
  }
  Add-Content -Path $seenPath -Value ([pscustomobject]$row | ConvertTo-Json -Compress) -Encoding UTF8

  # 元数据层（当日）—— description/license/topics 进主档案的关键来源
  $topicsArr = @()
  if ($Topics) { $topicsArr = @($Topics -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
  $metaRow = [ordered]@{
    full_name=$FullName
    description=$(if ($Description) { $Description } else { $null })
    license=$(if ($License) { $License } else { $null })
    topics=$topicsArr
    archived=($Archived -eq 'true')
    pushed_at=$PushedAt
    stars=$(if ($Stars -match '^\d+$') { [int]$Stars } else { $null })
    forks=$(if ($Forks -match '^\d+$') { [int]$Forks } else { 0 })
    open_issues=$(if ($OpenIssues -match '^\d+$') { [int]$OpenIssues } else { $null })
    created_at=$CreatedAt
    fetched_at=$now
  }
  $metaFile = P "data\meta\$today.jsonl"
  Add-Content -Path $metaFile -Value ([pscustomobject]$metaRow | ConvertTo-Json -Compress) -Encoding UTF8

  # 快照（星数基线，明天起可算 Δstars）
  $snapRow = [ordered]@{
    full_name=$FullName
    stars=$(if ($Stars -match '^\d+$') { [int]$Stars } else { 0 })
    forks=$(if ($Forks -match '^\d+$') { [int]$Forks } else { 0 })
    created_at=$CreatedAt; pushed_at=$PushedAt; captured_at=$now
  }
  Add-Content -Path (P "data\snapshots\$today.jsonl") -Value ([pscustomobject]$snapRow | ConvertTo-Json -Compress) -Encoding UTF8

  if ($UserNote) {
    $unLine = [pscustomobject]@{ full_name=$FullName; date=$today; note=$UserNote; by='user' } | ConvertTo-Json -Compress
    Add-Content -Path (P 'data\user-notes.jsonl') -Value $unLine -Encoding UTF8
  }
  Write-Host "✅ 已入库：$FullName（origin=user，未评档，status=$Status）" -ForegroundColor Green
}

# 需求 3：用户主动添加的项目，也要自动补标签与搜索词（与日报同一条流水线）
if (-not $NoSync) {
  & (P 'tools\sync-projects.ps1') -Force
  & (P 'tools\build-overview.ps1')
}
