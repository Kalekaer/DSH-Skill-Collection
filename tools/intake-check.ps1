# intake-check.ps1 — 统一入库自检（**不分来源**：用户推荐 / 自动发现 / 历史存量，一视同仁）
#
# 用户要求（2026-10-16）：凡是入库了都要自检，不管怎么入的，只要在库里就得保证没错。
# 因此本脚本做两件事：
#   ① 门禁体检：逐条检查"库里每一条"是否满足入库标准，分【硬门禁】与【软提示】两栏
#   ② 自动打标签：给缺标签的项目，从 GitHub topics / language / license 生成**机器标签**候选
#
# 设计纪律
#   * **默认只读**：不带 -Apply 只出报告，绝不写盘（`-Apply` 仅写 function-tags.jsonl，且只补不改）
#   * **离线可跑**：只读本库已有数据（projects.jsonl / taxonomy.json / human/*.jsonl），不联网、不花额度
#   * **不改现有数据**：报告写 data\_tmp\；补标签只**追加**缺的条目，绝不覆盖人工写的
#   * **合规红线一票否决**：命中即拦（**用户推荐也不例外**）
#
# 用法
#   pwsh -File .\tools\intake-check.ps1                    # 全库体检（只读，默认行为）
#   pwsh -File .\tools\intake-check.ps1 -Id openai/codex   # 只查一条（入库前预检用）
#   pwsh -File .\tools\intake-check.ps1 -Fix               # 只出"补标签候选"预览
#   pwsh -File .\tools\intake-check.ps1 -Fix -Apply        # 真正写入缺失的机器标签
#   pwsh -File .\tools\intake-check.ps1 -Json              # 机器可读

param(
  [string]$Id = '',
  [switch]$Fix,
  [switch]$Apply,
  [switch]$Json,
  [int]$StaleDays = 30
)

$ErrorActionPreference = 'Stop'
$root    = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$projPath = Join-Path $root 'data\projects.jsonl'
$txPath   = Join-Path $root 'data\taxonomy.json'
$tagPath  = Join-Path $root 'data\human\function-tags.jsonl'
$tmpDir   = Join-Path $root 'data\_tmp'
if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null }

# ---------- 合规红线词表（与 RUBRIC §1.1 对齐；命中即拦，用户推荐也不例外） ----------
# 明确违规（命中即硬拦；全部用词边界匹配，避免 "on crack" 这类俚语误伤）
$REDLINES_HARD = @(
  '激活工具','注册机','破解','外挂','作弊','修改器','挖矿','木马',
  '验证码代解','指纹伪造','批量注册','接码','羊毛','账号共享','赌博','诈骗','资金盘',
  'keygen','warez','aimbot','ransomware','stealer',
  'captcha.{0,3}solv','bypass.{0,3}cloudflare'
)
# 歧义信号（**不判死**，只报"待复核"）：这些词在正经项目里也常见
$REDLINES_SOFT = @('crack','cheat','miner','malware','exploit','hack')

function Read-Jsonl([string]$p) {
  $out = @()
  if (-not (Test-Path $p)) { return $out }
  Get-Content $p -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object {
    try { $out += ($_ | ConvertFrom-Json) } catch { $null = $_ }
  }
  return $out
}

$proj = @(Read-Jsonl $projPath)
if ($Id) { $proj = @($proj | Where-Object { $_.id -eq $Id }) }
if ($proj.Count -eq 0) { Write-Host "没有匹配的项目（-Id $Id）" -ForegroundColor Red; exit 1 }

$tx = Get-Content $txPath -Raw -Encoding UTF8 | ConvertFrom-Json
$validCat = @{}
foreach ($l1 in $tx.'一级分类'.PSObject.Properties) {
  foreach ($l2 in $l1.Value.children.PSObject.Properties) { $validCat[($l1.Name + '/' + $l2.Name)] = $true }
}
$validCat[($tx.'_其他分类'.'一级' + '/' + $tx.'_其他分类'.'二级')] = $true

$existingTags = @{}
foreach ($r in (Read-Jsonl $tagPath)) { if ($r.full_name) { $existingTags[[string]$r.full_name] = $true } }

# ---------- 门禁定义：硬（必修）/ 软（应修，须在 note 里说明） ----------
$rows = @()
$tagFixes = @()
$hardFail = 0; $softWarn = 0
$now = Get-Date

foreach ($p in $proj) {
  $id      = [string]$p.id
  $hard    = @()
  $soft    = @()
  $note    = @([string]$p.note, [string]$p.user_notes, [string]$p.human.one_liner, [string]$p.human.note_extra) -join ' '
  $txt     = @($id, [string]$p.description, ((@($p.topics)) -join ' '), ((@($p.function_tags)) -join ' ')) -join ' '
  $txtLow  = $txt.ToLower()

  # --- 硬门禁 ---
  if ($id -notmatch '^[^/]+/[^/]+$')                        { $hard += 'id 不是 owner/repo 形式' }
  if (-not $p.description -and -not $p.human.one_liner)     { $hard += '描述与人话层都为空' }
  if (-not $validCat.ContainsKey($p.category.l1 + '/' + $p.category.l2)) { $hard += "分类不在 taxonomy（$($p.category.l1)/$($p.category.l2)）" }
  # dropped 不再参与搜索/推荐，标签不是必需；只对未淘汰条目要求功能标签。
  if ($p.status -ne 'dropped' -and (@($p.function_tags)).Count -eq 0) { $hard += '无功能标签（搜功能搜不到）' }

  # 合规红线：命中即必须已是 dropped
  $hitHard = @($REDLINES_HARD | Where-Object { $txtLow -match ('(?<![a-z0-9])' + $_ + '(?![a-z0-9])') })
  if ($hitHard.Count -gt 0 -and $p.status -ne 'dropped') { $hard += ('命中合规红线但未 dropped：' + ($hitHard -join '/')) }
  $hitSoft = @($REDLINES_SOFT | Where-Object { $txtLow -match ('(?<![a-z0-9])' + $_ + '(?![a-z0-9])') })
  if ($hitSoft.Count -gt 0 -and $p.status -ne 'dropped') { $soft += ('疑似敏感词（需复核，不判死）：' + ($hitSoft -join '/')) }

  # --- 软提示（应修，但必须在备注里说明理由） ---
  $lic = [string]$p.license
  if (-not $lic -or $lic -match 'NOASSERTION') {
    if ($note -notmatch '无许可|无 License|许可不明|NOASSERTION') { $soft += '许可缺失但备注未说明' }
  }
  if ($p.pushed_at) {
    $days = [math]::Round(($now - [datetime]$p.pushed_at).TotalDays, 0)
    if ($days -gt $StaleDays -and $note -notmatch '停更|未更新|最后推送') { $soft += "停更 $days 天但备注未说明" }
  }
  if ($p.archived -eq $true -and $p.status -ne 'dropped')   { $soft += '已归档但未 dropped' }
  if (-not [string]$p.risk -and $note -notmatch '风险(等级)?[:：]?\s*(低|中|高)|【风险】') { $soft += '风险等级为空' }
  if ($p.status -ne 'dropped' -and -not (Test-Path (Join-Path $root 'data\series'))) { $null = $null }

  # --- 补标签候选（机器标签：只用 GitHub 官方 topics / 语言，不猜中文） ---
  if ((@($p.function_tags)).Count -eq 0 -and -not $existingTags.ContainsKey($id)) {
    $cand = @()
    foreach ($t in @($p.topics)) { $t2 = [string]$t; if ($t2 -and $t2.Length -ge 3) { $cand += $t2 } }
    if ($p.language) { $cand += ([string]$p.language).ToLower() }
    $cand = @($cand | Sort-Object -Unique)
    if ($cand.Count -gt 0) { $tagFixes += [pscustomobject]@{ id = $id; tags = $cand; source = 'auto(topics+language)' } }
  }

  if ($hard.Count) { $hardFail++ }
  if ($soft.Count) { $softWarn++ }
  $rows += [pscustomobject]@{
    id = $id; origin = [string]$p.origin; status = [string]$p.status
    hard = ($hard -join '；'); soft = ($soft -join '；')
    hardN = $hard.Count; softN = $soft.Count
  }
}

# ---------- 输出 ----------
$summary = [ordered]@{
  checked_at   = (Get-Date -Format 's')
  scope        = if ($Id) { "single:$Id" } else { 'all' }
  total        = $rows.Count
  hard_fail    = $hardFail
  soft_warn    = $softWarn
  tag_missing  = $tagFixes.Count
}
$reportPath = Join-Path $tmpDir ('intake-check-' + (Get-Date -Format 'yyyy-MM-dd-HHmmss') + '.json')
[System.IO.File]::WriteAllText($reportPath, (([ordered]@{ summary = $summary; rows = $rows; tag_fixes = $tagFixes }) | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))

if ($Json) {
  [ordered]@{ summary = $summary; rows = $rows; tag_fixes = $tagFixes } | ConvertTo-Json -Depth 6
} else {
  Write-Host ''
  Write-Host '=== 统一入库自检（不分来源） ===' -ForegroundColor Cyan
  Write-Host ("  检查 {0} 条 ｜ ❌ 硬门禁不过 {1} ｜ ⚠️ 软提示 {2} ｜ 缺标签 {3}" -f $summary.total, $hardFail, $softWarn, $tagFixes.Count)
  if ($hardFail) {
    Write-Host ''
    Write-Host '  ── ❌ 硬门禁不过（必修：字段/分类/标签/合规）──' -ForegroundColor Red
    $rows | Where-Object { $_.hardN -gt 0 } | Sort-Object hardN -Descending | Select-Object -First 40 | ForEach-Object {
      Write-Host ("    {0,-44} [{1}] {2}" -f $_.id, $_.origin, $_.hard)
    }
  }
  if ($softWarn) {
    Write-Host ''
    Write-Host '  ── ⚠️ 软提示（应修：在备注里说明即可）──' -ForegroundColor Yellow
    $rows | Where-Object { $_.hardN -eq 0 -and $_.softN -gt 0 } | Sort-Object softN -Descending | Select-Object -First 20 | ForEach-Object {
      Write-Host ("    {0,-44} {1}" -f $_.id, $_.soft)
    }
  }
  if ($Fix -and $tagFixes.Count) {
    Write-Host ''
    Write-Host '  ── 补标签候选（机器标签：GitHub topics + 语言）──' -ForegroundColor Cyan
    $tagFixes | Select-Object -First 20 | ForEach-Object { Write-Host ("    {0,-44} → {1}" -f $_.id, ($_.tags -join ', ')) }
    if ($Apply) {
      $lines = @()
      foreach ($f in $tagFixes) {
        # 黑名单过滤（P1-10 教训：垃圾模式绝不许再写进来）+ 带 user_keywords（否则撞 audit 不变量 ✗）
        $vocPath = Join-Path $root 'data\tags-vocabulary.json'
        $bl = @()
        if (Test-Path $vocPath) { try { $bl = @((Get-Content $vocPath -Raw -Encoding UTF8 | ConvertFrom-Json).blacklist) } catch { $null = $_ } }
        $clean = @($f.tags | Where-Object { $bl -notcontains [string]$_ })
        if ($clean.Count -eq 0) { continue }
        $lines += ([ordered]@{ full_name = $f.id; function_tags = $clean; user_keywords = @($clean | Select-Object -First 2); synonyms = @(); source = ($f.source + '+voca'); written_at = (Get-Date -Format 'yyyy-MM-dd') } | ConvertTo-Json -Compress)
      }
      Add-Content -Path $tagPath -Value ($lines -join "`r`n") -Encoding UTF8
      Write-Host ("  ✅ 已追加 {0} 条机器标签到 data\human\function-tags.jsonl（未覆盖任何人工条目）" -f $tagFixes.Count) -ForegroundColor Green
      # P1-16：**真的写盘了**才重建页面（预览模式不重建；$env:DSH_SKIP_REBUILD=1 可关）
      & (P 'tools\rebuild-page.ps1') -Force
    } else {
      Write-Host '  （预览模式：加 -Apply 才写入）' -ForegroundColor Yellow
    }
  }
  Write-Host ("`n  报告: " + $reportPath.Substring($root.Length + 1)) -ForegroundColor DarkGray
}

if ($Json) { exit 0 }   # -Json：只报结果，不用退出码掐断调用者（add-repo 门禁 P0-6）
if ($hardFail -gt 0) { exit 1 } else { exit 0 }
