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
#     -Description "..." -PushedAt "2026-10-12T00:00:00Z" -Note "事实性备注" -UserNote "朋友推荐，说很好用" `
#     -Risk 低
#   可选：-Status active|using|watching|researching|dropped（默认 watching）　-NoSync（只落盘不重建）
#         -DryRun（只打印将写入的行，不落盘、不重建；用于自测）
#
# 行为：
#   * 新项目  → 追加 seen.jsonl（origin=user + risk）+ data/meta/今天.jsonl + data/snapshots/今天.jsonl
#               （快照带 date + round），然后自动跑 sync + build（可用 -NoSync 跳过）
#   * 已存在  → **不重复添加**；把「用户曾推荐过 + 备注」追加进 data/user-notes.jsonl（原始层）
#
# 纪律（与 SKILL.md 第十二节一致）：
#   * 用户推荐 ≠ 日报推荐：origin=user，sync 会补 SABCD；默认进老朋友动态，**不伪装成主推荐**
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
  [ValidateSet('', '低', '中', '高')][string]$Risk = '',
  [switch]$NoSync,
  [switch]$DryRun
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

# 快照 round：按「同一个仓库当天已用的最大 round」+1（schema 唯一键 date+full_name+round）
function Get-SnapshotRound([string]$date, [string]$repo) {
  $p = P "data\snapshots\$date.jsonl"
  $max = 0
  if (Test-Path $p) {
    foreach ($l in (Get-Content $p -Encoding UTF8)) {
      if (-not $l.Trim()) { continue }
      try { $o = $l | ConvertFrom-Json } catch { continue }
      if ([string]$o.full_name -eq $repo -and [int]$o.round -gt $max) { $max = [int]$o.round }
    }
  }
  return ($max + 1)
}

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
  $unObj = [pscustomobject]@{ full_name=$FullName; date=$today; note=$noteTxt; by='user' }
  if ($DryRun) {
    Write-Output ('DRYRUN ' + ([ordered]@{ action='exists'; user_note=$unObj } | ConvertTo-Json -Depth 5 -Compress))
    exit 0
  }
  Add-Content -Path (P 'data\user-notes.jsonl') -Value ($unObj | ConvertTo-Json -Compress) -Encoding UTF8
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
  if ($Risk) { $row['risk'] = $Risk }

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

  # 快照（星数基线，明天起可算 Δstars）：必须带 round + date
  $snapRow = [ordered]@{
    date=$today
    round=(Get-SnapshotRound $today $FullName)
    full_name=$FullName
    stars=$(if ($Stars -match '^\d+$') { [int]$Stars } else { 0 })
    forks=$(if ($Forks -match '^\d+$') { [int]$Forks } else { 0 })
    created_at=$CreatedAt; pushed_at=$PushedAt; captured_at=$now
  }

  # 写前校验：坏行不落盘
  if ([int]$snapRow.round -lt 1) { Write-Host "❌ 快照 round 计算失败：$($snapRow.round)" -ForegroundColor Red; exit 2 }
  if ($null -eq $snapRow.stars -or [int]$snapRow.stars -lt 0) { Write-Host "❌ 快照 stars 非法：$($snapRow.stars)" -ForegroundColor Red; exit 2 }
  if ([string]$snapRow.date -notmatch '^\d{4}-\d{2}-\d{2}$') { Write-Host "❌ 快照 date 非法：$($snapRow.date)" -ForegroundColor Red; exit 2 }

  if ($DryRun) {
    $plan = [ordered]@{
      action   = 'insert'
      seen     = $row
      meta     = $metaRow
      snapshot = $snapRow
      user_note = $(if ($UserNote) { [pscustomobject]@{ full_name=$FullName; date=$today; note=$UserNote; by='user' } } else { $null })
    }
    Write-Output ('DRYRUN ' + ($plan | ConvertTo-Json -Depth 6 -Compress))
    exit 0
  }

  Add-Content -Path $seenPath -Value ([pscustomobject]$row | ConvertTo-Json -Compress) -Encoding UTF8
  $metaFile = P "data\meta\$today.jsonl"
  Add-Content -Path $metaFile -Value ([pscustomobject]$metaRow | ConvertTo-Json -Compress) -Encoding UTF8
  Add-Content -Path (P "data\snapshots\$today.jsonl") -Value ([pscustomobject]$snapRow | ConvertTo-Json -Compress) -Encoding UTF8

  if ($UserNote) {
    Add-Content -Path (P 'data\user-notes.jsonl') -Value ([pscustomobject]@{ full_name=$FullName; date=$today; note=$UserNote; by='user' } | ConvertTo-Json -Compress) -Encoding UTF8
  }
  Write-Host "✅ 已入库：$FullName（origin=user，默认老朋友动态，status=$Status，risk=$(if($Risk){$Risk}else{'未填'})）" -ForegroundColor Green
}

# 需求 3：用户主动添加的项目，也要自动补标签与搜索词（与日报同一条流水线）
if (-not $NoSync) {
  & (P 'tools\sync-projects.ps1') -Force
  # --- P0-6 统一入库门禁（不分来源；2026-10-16 新增）---
  try {
    $gate = ((& (P 'tools\intake-check.ps1') -Id $FullName -Json 2>$null) | Out-String) | ConvertFrom-Json
    if ($gate -and $gate.summary) {
      $hard = [int]$gate.summary.hard_fail
      if ($hard -gt 0) {
        $hits = @($gate.rows | Where-Object { $_.hardN -gt 0 } | ForEach-Object { $_.hard }) -join '；'
        Write-Host ("  ⚠️ 门禁：" + $FullName + " 有 " + $hard + " 项硬门禁未过 → 用户推荐照办 + 已写明风险") -ForegroundColor Yellow
        Write-Host ("     原因：" + $hits) -ForegroundColor DarkYellow
        Add-Content -Path (P 'data\user-notes.jsonl') -Value ([pscustomobject]@{ full_name = $FullName; date = $today; note = ('门禁提示：' + $hits); by = 'gate' } | ConvertTo-Json -Compress) -Encoding UTF8
      } else { Write-Host ("  ✅ 门禁通过：" + $FullName) -ForegroundColor Green }
    }
  } catch { Write-Host ("  ⚠️ 门禁未执行（不阻断入库）：" + $_.Exception.Message) -ForegroundColor DarkYellow }
  # P1-16：统一走 rebuild-page（sync + build + **自检页面真的变新了**），
  #   而不是只调 build-overview —— 后者没有"页面是否真的更新"的护栏
  & (P 'tools\rebuild-page.ps1')
}