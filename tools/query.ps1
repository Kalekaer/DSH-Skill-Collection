# query.ps1 — 按条件查询项目档案（读 projects.jsonl，不写任何文件）
#
# 用法示例：
#   & ".\tools\query.ps1"                                  # 概览：总数 + 各维分布
#   & ".\tools\query.ps1" -Tag AI                          # 找 AI 类项目
#   & ".\tools\query.ps1" -Tag AI -Status saved            # 我收藏的 AI 项目
#   & ".\tools\query.ps1" -Text agent                      # 关键词（名/描述/topics）
#   & ".\tools\query.ps1" -License MIT -Language Python     # 按许可与语言
#   & ".\tools\query.ps1" -ActiveWithinDays 90              # 最近 90 天有提交
#   & ".\tools\query.ps1" -RecommendedOnly -Top 10          # 只看推荐过的，取前 10
#   & ".\tools\query.ps1" -Events repowise-dev/repowise     # 看某个项目的历史变化

param(
  [string]$Tag,                 # 领域/形态/用途/成熟度/上手难度/风险等级 的任一取值
  [string]$Status,
  [string]$Text,
  [string]$License,
  [string]$Language,
  [string]$Tier,
  [string]$Risk,
  [int]$ActiveWithinDays = 0,
  [switch]$RecommendedOnly,
  [string]$Events,              # 传 full_name 时改为显示该项目的事件流
  [int]$Top = 0
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

function Read-Jsonl([string]$p) {
  if (-not (Test-Path $p)) { return @() }
  $out = @()
  foreach ($l in Get-Content $p -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $out += ($l | ConvertFrom-Json) } catch { $null = $_ }
  }
  return $out
}

$projPath = Join-Path $root 'data\projects.jsonl'
if (-not (Test-Path $projPath)) {
  Write-Host "找不到 data\projects.jsonl，请先运行：& `".\tools\sync-projects.ps1`"" -ForegroundColor Red
  exit 1
}
$all = Read-Jsonl $projPath

# ---- 同义词扩展：用户搜「画图」时，自动扩展成整组词再匹配 ----
$synGroups = Read-Jsonl (Join-Path $root 'data\human\search-synonyms.jsonl')
function Expand-Query([string]$q) {
  if (-not $q) { return @() }
  $terms = @($q.ToLower())
  foreach ($g in $synGroups) {
    $hit = @($g.terms | Where-Object { $_.ToLower().Contains($q.ToLower()) -or $q.ToLower().Contains($_.ToLower()) })
    if ($hit.Count -gt 0) { $terms += ($g.terms | ForEach-Object { $_.ToLower() }) }
  }
  return ($terms | Sort-Object -Unique)
}
# 所有参与搜索的文本（人话层 + 原生字段 + 自动分类 + 功能标签 + 用户搜索词）
function SearchableText($p) {
  $fnTxt = ''
  if ($p.human -and $p.human.feature_note) {
    $fn = $p.human.feature_note
    $parts = @()
    foreach ($k in $fn.PSObject.Properties.Name) {
      $v = $fn.$k
      $parts += if ($v -is [array]) { ($v -join ' ') } else { "$v" }
    }
    $fnTxt = ($parts -join ' ')
  }
  $tagTxt = ''
  if ($p.tags) { $tagTxt = ($p.tags.PSObject.Properties | ForEach-Object { $_.Value }) -join ' ' }
  $h = @()
  if ($p.human) { $h = @($p.human.one_liner, $p.human.problem, $p.human.example) }
  return (@(
    $p.id, $p.description, $p.note, $tagTxt, $fnTxt,
    ($p.topics -join ' '),
    ($p.function_tags -join ' '),
    ($p.user_keywords -join ' '),
    ($p.synonyms -join ' '),
    ($h -join ' ')
  ) -join ' ').ToLower()
}

# ---- 事件模式 ----
if ($Events) {
  $evs = (Read-Jsonl (Join-Path $root 'data\events.jsonl')) | Where-Object { $_.id -eq $Events } | Sort-Object date
  if (-not $evs) { Write-Host "没有找到 $Events 的事件记录。" ; exit 0 }
  $p = $all | Where-Object { $_.id -eq $Events } | Select-Object -First 1
  Write-Host ""
  Write-Host "=== $Events 的历史变化 ===" -ForegroundColor Cyan
  if ($p) {
    Write-Host "  描述   : $($p.description)"
    Write-Host "  许可   : $($p.license)   语言: $($p.language)   归档: $($p.archived)"
    Write-Host "  分类   : $($p.tags.'领域') / $($p.tags.'形态') / $($p.tags.'用途')"
    $ghTxt = ''
    if ($p.stars.github) {
      $atRaw = [string]$p.stars.github_at
      $at = if ($atRaw) { $atRaw.Substring(0, [Math]::Min(10, $atRaw.Length)) } else { '—' }
      $ghTxt = "，实测 $($p.stars.github)（$at）"
    }
    Write-Host "  状态   : $($p.status)   星数: $($p.stars.current)（快照 $($p.stars.last_snapshot)）$ghTxt"
    Write-Host "  推荐   : $(if($p.recommended){"$($p.tier) 档 · $($p.score) 分 · $($p.last_recommended)"}else{'未推荐'})"
  }
  Write-Host ""
  Write-Host "  日期        类型            说明" -ForegroundColor DarkGray
  foreach ($e in $evs) { Write-Host ("  {0}  {1,-15} {2}" -f $e.date, $e.type, $e.detail) }
  Write-Host ""
  Write-Host "  共 $($evs.Count) 条事件"
  exit 0
}

# ---- 过滤 ----
$r = $all
if ($Tag) {
  $r = $r | Where-Object { $_.tags.'领域' -eq $Tag -or $_.tags.'形态' -eq $Tag -or $_.tags.'用途' -eq $Tag -or $_.tags.'成熟度' -eq $Tag -or $_.tags.'上手难度' -eq $Tag -or $_.tags.'风险等级' -eq $Tag }
}
if ($Status)    { $r = $r | Where-Object { $_.status -eq $Status } }
if ($License)   { $r = $r | Where-Object { $_.license -eq $License } }
if ($Language)  { $r = $r | Where-Object { $_.language -eq $Language } }
if ($Tier)      { $r = $r | Where-Object { $_.tier -eq $Tier } }
if ($Risk)      { $r = $r | Where-Object { $_.risk -eq $Risk } }
if ($RecommendedOnly) { $r = $r | Where-Object { $_.recommended -eq $true } }
if ($Text) {
  # 用户思维搜索：先做同义词扩展，再匹配**所有**字段（含人话层、功能标签、用户搜索词）
  $terms = Expand-Query $Text
  $r = $r | Where-Object {
    $hay = SearchableText $_
    $hit = $false
    foreach ($t in $terms) { if ($hay.Contains($t)) { $hit = $true; break } }
    $hit
  }
}
if ($ActiveWithinDays -gt 0) {
  $cut = (Get-Date).AddDays(-$ActiveWithinDays)
  $r = $r | Where-Object {
    if (-not $_.pushed_at) { return $false }
    try { return ([datetime]$_.pushed_at) -ge $cut } catch { return $false }
  }
}
$r = $r | Sort-Object { -[int]($_.stars.current) }
if ($Top -gt 0) { $r = $r | Select-Object -First $Top }

# ---- 无过滤条件时输出概览 ----
$noFilter = -not ($Tag -or $Status -or $Text -or $License -or $Language -or $Tier -or $Risk -or $ActiveWithinDays -gt 0 -or $RecommendedOnly)
if ($noFilter) {
  Write-Host ""
  Write-Host "=== 项目档案概览 ===" -ForegroundColor Cyan
  Write-Host "  总项目: $($all.Count)  推荐过: $(($all | Where-Object { $_.recommended -eq $true }).Count)  收藏: $(($all | Where-Object { $_.status -eq 'saved' }).Count)"
  Write-Host "  有描述: $(($all | Where-Object { $_.description }).Count)  （其余为历史数据缺失）"
  foreach ($dim in '领域','形态','用途','成熟度','上手难度','风险等级') {
    $g = $all | Group-Object { $_.tags.$dim } | Sort-Object Count -Descending
    Write-Host ("  {0,-6}: {1}" -f $dim, (($g | ForEach-Object { "$($_.Name)($($_.Count))" }) -join '  '))
  }
  Write-Host ""
  Write-Host "  用法示例：& `".\tools\query.ps1`" -Tag AI -Status saved" -ForegroundColor DarkGray
  exit 0
}

# ---- 结果（人话层优先展示）----
Write-Host ""
Write-Host "=== 命中 $($r.Count) 条 ===" -ForegroundColor Cyan
foreach ($p in $r) {
  $flags = @()
  if ($p.recommended) { $flags += "$($p.tier)档" }
  if ($p.status -ne 'active') { $flags += $p.status }
  if ($p.license) { $flags += $p.license }
  $flagTxt = if ($flags) { "  [" + ($flags -join ' ') + "]" } else { '' }
  Write-Host ("  {0}{1}" -f $p.id, $flagTxt) -ForegroundColor White
  # ① 人话层优先
  if ($p.human -and $p.human.one_liner) {
    Write-Host ("      " + $p.human.one_liner)
    if ($p.human.example) { Write-Host ("      例：" + $p.human.example.Substring(0,[Math]::Min(88,$p.human.example.Length))) -ForegroundColor DarkGray }
    if ($p.human.status -eq 'partial') { Write-Host "      （详细说明待补全：仅有台账备注）" -ForegroundColor DarkYellow }
  } elseif ($p.description) {
    Write-Host ("      " + $p.description.Substring(0,[Math]::Min(96,$p.description.Length))) -ForegroundColor DarkGray
  }
  # ② 功能标签（用户能看懂的）
  $ft = if ($p.function_tags) { $p.function_tags -join ' · ' } else { '' }
  $uk = if ($p.user_keywords) { "  ｜ 可搜：" + (($p.user_keywords | Select-Object -First 4) -join '/') } else { '' }
  if ($ft) { Write-Host ("      功能：" + $ft + $uk) -ForegroundColor DarkGray }
  # ③ 机器字段退到末行
  Write-Host ("      ★ {0} ｜ {1} / {2} ｜ {3} ｜ 事件 {4} 条" -f $p.stars.current, $p.tags.'领域', $p.tags.'形态', $p.language, $p.events_count) -ForegroundColor DarkGray
}
Write-Host ""
