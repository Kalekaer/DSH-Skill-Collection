# score.ps1 — 打分与规则的**纯函数**实现（读 data/criteria.json，不写任何文件）
#
# 为什么要有它：原先把规则写在 RUBRIC.md（散文）里、把实现埋在 700 行 sync 脚本里 ✗
# 现在规则进 criteria.json（机器可读），判定进本文件（可单测），RUBRIC.md 只留人话说明 ✓
# audit 会检查「RUBRIC ↔ criteria.json ↔ score.ps1」三者一致（P0-4）✓
#
# 用法（可 dot-source 做测试）：
#   . .\tools\score.ps1
#   Get-Tier 79            → 'A'
#   Measure-Score @{实用性=30;上手成本=10} 'tool'   → 归一化到 0..100
#   Test-Redline 'xxx crack xxx'  → @{ 硬=@(); 软=@('crack') }
#
# 纪律：本文件**只读**、**无副作用**、**不联网**、**零外部依赖**。

$script:CriteriaPath = Join-Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)) 'data\criteria.json'
$script:CriteriaCache = $null

function Get-Criteria {
  [CmdletBinding()]
  param([string]$Path = '')
  if ($Path) { return (Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json) }
  if ($script:CriteriaCache) { return $script:CriteriaCache }
  if (-not (Test-Path $script:CriteriaPath)) { throw "找不到 criteria.json：$script:CriteriaPath" }
  $script:CriteriaCache = Get-Content $script:CriteriaPath -Raw -Encoding UTF8 | ConvertFrom-Json
  return $script:CriteriaCache
}

function Get-Tier {
  [CmdletBinding()]
  param([Parameter(Mandatory)][int]$Score)
  $c = Get-Criteria
  if ($Score -ge [int]$c.'分档阈值'.S) { return 'S' }
  if ($Score -ge [int]$c.'分档阈值'.A) { return 'A' }
  if ($Score -ge [int]$c.'分档阈值'.B) { return 'B' }
  if ($Score -ge [int]$c.'分档阈值'.C) { return 'C' }
  return 'D'
}

function Measure-Score {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][hashtable]$Parts,   # 形如 @{ 实用性=30; 上手成本=10; ... }（原始得分，非权重）
    [string]$Kind = 'tool'
  )
  $c = Get-Criteria
  $disabled = @()
  $prop = $c.'按类型停用维度'.PSObject.Properties[$Kind]
  if ($prop) { $disabled = @($prop.Value) }

  $got = 0.0; $max = 0.0
  foreach ($d in $c.'打分维度') {
    $name = [string]$d.'名称'
    if ($disabled -contains $name) { continue }
    $w = [double]$d.'权重'
    $max += $w
    if ($Parts.ContainsKey($name)) { $got += [double]$Parts[$name] }
  }
  if ($max -le 0) { return 0 }
  # 归一化：停用维度后仍返回 0..100（否则不同 kind 的分数不可比）
  return [int][math]::Round(100.0 * $got / $max, 0)
}

function Get-RedlineHit {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Text)
  $c = Get-Criteria
  $low = $Text.ToLower()
  $hard = @()
  foreach ($w in @($c.'合规红线_明确违规')) {
    $p = '(?<![a-z0-9])' + [regex]::Escape(([string]$w).ToLower()) + '(?![a-z0-9])'
    if ($low -match $p) { $hard += [string]$w }
  }
  $soft = @()
  foreach ($w in @($c.'合规红线_歧义信号'.'词')) {
    $p = '(?<![a-z0-9])' + [regex]::Escape(([string]$w).ToLower()) + '(?![a-z0-9])'
    if ($low -match $p) { $soft += [string]$w }
  }
  return @{ 硬 = $hard; 软 = $soft }
}

function Test-HardExclude {
  [CmdletBinding()]
  param(
    [string]$Description = '',
    [string]$Id = '',
    [switch]$IsFork,
    [switch]$IsArchived,
    [int]$Stars = 0,
    [double]$ForkRatio = -1,
    [int]$DaysSincePush = 0,
    [int]$DaysSincePushMax = 180
  )
  $hits = @()
  if ([string]::IsNullOrWhiteSpace($Description) -and [string]::IsNullOrWhiteSpace($Id)) { $hits += '无描述且无标识' }
  if ($IsFork) { $hits += 'fork/镜像/搬运' }
  if ($IsArchived) { $hits += 'archived' }
  if ($DaysSincePush -gt $DaysSincePushMax) { $hits += ('停更 ' + $DaysSincePush + ' 天 > ' + $DaysSincePushMax) }
  # 资源合集判定（精确化，避免误杀 "awesome-dsh-plugin/dsh-find-plugin" 这类正当项目 ✗）
  # 规则：① id 的 **repo 部分**以 awesome- 开头才算；② 描述里出现 awesome 且同时有 list/collection/curated/resources 语境才算
  if (-not [string]::IsNullOrWhiteSpace($Id) -and $Id.Contains('/')) {
    $repo = ($Id -split '/')[1].ToLower()
    if ($repo -like 'awesome-*' -or $repo -like '*-collection' -or $repo -like '*-awesome') { $hits += '资源合集：仓库名 awesome-*/-collection' }
  }
  if (-not [string]::IsNullOrWhiteSpace($Description)) {
    $low = $Description.ToLower()
    if ($low.Contains('awesome') -and ($low -match 'list|collection|curated|resources')) { $hits += '资源合集迹象：awesome + list/collection' }
    foreach ($kw in @('roadmap', 'interview-questions', 'books')) { if ($low.Contains($kw)) { $hits += ('资源合集迹象：' + $kw) } }
  }
  if ($Stars -ge 1000 -and $ForkRatio -ge 0 -and $ForkRatio -lt 0.02) { $hits += ('刷星迹象：fork/star=' + [math]::Round($ForkRatio, 4)) }
  return $hits
}

function Test-DailyCap {
  [CmdletBinding()]
  param([Parameter(Mandatory)][int]$Count, [switch]$Extra)
  $c = Get-Criteria
  $cap = if ($Extra) { [int]$c.'日报上限'.'特别栏目' } else { [int]$c.'日报上限'.'主推荐' }
  return @{ 上限 = $cap; 数量 = $Count; 通过 = ($Count -le $cap) }
}

function Test-StatusAllowed {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Status)
  $c = Get-Criteria
  return (@($c.'状态白名单') -contains $Status)
}

function Get-DownrankedScore {
  <#
    P2-1 同 owner 冷却降权：同一 owner 在窗口天数内已出过项目 → 扣分（不消失）。
    参数：-Score 原始分；-SameOwnerWithinWindow 该 owner 是否在窗口内出现过
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][int]$Score, [switch]$SameOwnerWithinWindow)
  $c = Get-Criteria
  if (-not $SameOwnerWithinWindow) { return $Score }
  $pen = 10
  $prop = $c.PSObject.Properties['同owner降权']
  if ($prop -and $prop.Value.'降权分值') { $pen = [int]$prop.Value.'降权分值' }
  return [Math]::Max(0, $Score - $pen)
}

function Test-ExplorationQuota {
  <#
    P1-4 探索配额：8 条主推荐里至少 2 条应为"未推荐过且首次发现 ≤14 天"的新星。
    返回 @{ 需要; 已有; 通过 }
  #>
  [CmdletBinding()]
  param([Parameter(Mandatory)][int]$DailyCount, [Parameter(Mandatory)][int]$ExplorationCount)
  $c = Get-Criteria
  $need = 2
  $prop = $c.PSObject.Properties['探索配额']
  if ($prop -and $prop.Value.'每天保留给新星或低star优质') { $need = [int]$prop.Value.'每天保留给新星或低star优质' }
  if ($DailyCount -lt $need) { $need = $DailyCount }
  return @{ 需要 = $need; 已有 = $ExplorationCount; 通过 = ($ExplorationCount -ge $need) }
}
