# sync-projects.ps1 — 从原始来源派生出统一项目档案与事件表
#
# 数据流：**原始来源 → 投影 → 视图**
#   原始来源（外部事实 + 用户操作，不可再生）
#     data/seen.jsonl、data/snapshots/*.jsonl、data/picks/*.jsonl、
#     data/recommend-log.csv、data/meta/*.jsonl、data/status-log.jsonl
#   投影（本脚本产出，可全量重建，**禁止手工编辑**）
#     data/projects.jsonl（当前状态投影）、data/events.jsonl（变化流水投影）
#
# 注意：projects 与 events **是同层投影**，都由同一批原始来源派生，events 不是 projects 的上游。
#       不要把任何单一文件称为"唯一事实源"——事实由多个来源共同构成。
#
# 幂等：输入指纹不变则跳过重建；可用 -Force 强制重建。
# 用法：
#   & ".\tools\sync-projects.ps1"
#   & ".\tools\sync-projects.ps1" -Force

param(
  [switch]$Force,
  [int]$StarsThreshold = -1   # <0 表示从 config.json 读
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

# ---------- 降级：没有原始层时不派生（2026-10-14 修复）----------
# 发布版 / demo 数据包按设计**不含** data\seen.jsonl（个人数据不发布）。
# 旧行为：空输入 → $projects 为空 → $projLines 为 $null → [IO.File]::WriteAllLines 抛
#         "Value cannot be null. (Parameter 'contents')"，退出码 1，用户看到的是 .NET 报错。
# 新行为：先判断原始层是否存在；不存在就说明原因、**零副作用**退出（连 tools/ 备份都不做）。
# 判据只看**去重台账** data\seen.jsonl —— 它是原始层的主文件。
# （2026-10-14 二次修正：第一版把 data\taxonomy.json / data\human\*.jsonl 也算原始层，
#   于是 demo 包被判定为"有原始层"，脚本继续往下跑，**静默把 projects.jsonl / events.jsonl 写成空**，
#   比原来的崩溃更糟。现在：缺台账 = 不派生，直接退出。）
if (-not (Test-Path (P 'data\seen.jsonl'))) {
  Write-Host ""
  Write-Host "=== 跳过同步：本工作区没有原始层 ===" -ForegroundColor Yellow
  Write-Host "  data\seen.jsonl 等原始文件都不存在 —— 这是**发布版 / demo 数据包**（个人数据按设计不发布）。"
  Write-Host "  没有原始层就没有可派生的东西，本次不做任何写入（含 tools/ 备份）。"
  Write-Host "  → 想让它变成你自己的库：先跑一次日报（对话里说「跑今天的日报」），"
  Write-Host "    生成 data\seen.jsonl 之后再执行本脚本即可正常重建 projects.jsonl / events.jsonl。"
  Write-Host ""
  exit 0
}

# ---------- 自动备份 tools/（2026-10-13 事故的教训：脚本无版本控制，误操作后无法回滚）----------
# 备份 tools/*.ps1 与 audit.ps1，按日期归档到 data/_backup/YYYY-MM-DD/。
# 恢复方法：从备份目录复制回 tools/。**这些脚本是不可再生的**（projects/events 能靠它们重建，它们自己不能）。
$bkRoot = P 'data\_backup'
if (-not (Test-Path $bkRoot)) { New-Item -ItemType Directory -Path $bkRoot -Force | Out-Null }
$bkDir = Join-Path $bkRoot (Get-Date -Format 'yyyy-MM-dd')
$toolFiles = @()
foreach ($pat in '*.ps1', '*.js') {
  $toolFiles += @(Get-ChildItem (P 'tools') -Filter $pat -File -ErrorAction SilentlyContinue)
}
$toolFiles += @(Get-ChildItem (P '.dsh\skills\github-daily-picks') -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
if ($toolFiles.Count -gt 0) {
  $need = $false
  foreach ($t in $toolFiles) {
    $dst = Join-Path $bkDir $t.Name
    if (-not (Test-Path $dst) -or (Get-FileHash $t.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $dst -Algorithm SHA256).Hash) { $need = $true; break }
  }
  if ($need) {
    New-Item -ItemType Directory -Path $bkDir -Force | Out-Null
    foreach ($t in $toolFiles) { Copy-Item $t.FullName (Join-Path $bkDir $t.Name) -Force }
    Write-Host "  已备份 $($toolFiles.Count) 个脚本 → data\_backup\$(Get-Date -Format 'yyyy-MM-dd')\" -ForegroundColor DarkGray
  }
}

# ---------- 读配置 ----------
$cfg = $null
try { $cfg = Get-Content (P 'config.json') -Raw | ConvertFrom-Json } catch {}
if ($StarsThreshold -lt 0) {
  $StarsThreshold = if ($cfg -and $cfg.events -and $cfg.events.stars_threshold) { [int]$cfg.events.stars_threshold } else { 30 }
}

# ---------- 收集流水 ----------
$seenPath   = P 'data\seen.jsonl'
$csvPath    = P 'data\recommend-log.csv'
$picksDir   = P 'data\picks'
$snapDir    = P 'data\snapshots'
$statusLog   = P 'data\status-log.jsonl'
$metaDir     = P 'data\meta'      # 元数据层（按天追加，是事件源之一，不能覆盖）
$backfillDir = P 'data\backfill'  # 一次性补录的来源凭证（不再直接读，历史已并入 meta/）
$humanDir    = P 'data\human'     # 人话层（项目介绍 / 功能标签 / 同义词；优先级高于自动推断）
$taxonomyPath= P 'data\taxonomy.json'  # 两级分类规则库（**分类只能从这里取，不允许运行时自由创建**）
$userNotesPath = P 'data\user-notes.jsonl'  # 用户自己的备注（个人数据，**与机器生成的人话层分开存**）

function Read-Jsonl([string]$path) {
  $out = @()
  if (-not (Test-Path $path)) { return $out }
  foreach ($l in Get-Content $path -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $out += ($l | ConvertFrom-Json) } catch { Write-Warning "跳过损坏行：$path" }
  }
  return $out
}

$seen    = Read-Jsonl $seenPath
$statuses= Read-Jsonl $statusLog

# --- 元数据层：按日期快照收集，供回放算变化 ---
# metaHistory[full_name] = @( {date, description, license, topics, archived, pushed_at, stars, release_at} ... ) 按 date 升序
$metaHistory = @{}
$metaDates = @()
if (Test-Path $metaDir) {
  Get-ChildItem $metaDir -Filter '*.jsonl' | Sort-Object Name | ForEach-Object {
    $d = $_.BaseName
    if ($d -match '^\d{4}-\d{2}-\d{2}$') {
      $metaDates += $d
      foreach ($m in (Read-Jsonl $_.FullName)) {
        if (-not $metaHistory.ContainsKey($m.full_name)) { $metaHistory[$m.full_name] = @() }
        $metaHistory[$m.full_name] += [pscustomobject]@{
          date = $d; description = $m.description; license = $m.license
          topics = @($m.topics | Where-Object { $_ }); archived = $m.archived; pushed_at = $m.pushed_at
          stars = $m.stars; release_at = $m.release_at
        }
      }
    }
  }
}
# 最新一份元数据（用于档案的当前值）
$metaMap = @{}
foreach ($k in $metaHistory.Keys) {
  $list = @($metaHistory[$k] | Sort-Object date)
  $metaMap[$k] = $list[-1]
}

# --- 人话层：项目介绍 / 功能标签 / 全局同义词 ---
# 人话层**优先级高于自动推断**：有就用人话层的，没有才用自动生成的。
$introMap = @{}
$tagMap   = @{}
$synGroups = @()
if (Test-Path $humanDir) {
  foreach ($x in (Read-Jsonl (Join-Path $humanDir 'repo-intro.jsonl')))    { $introMap[$x.full_name] = $x }
  foreach ($x in (Read-Jsonl (Join-Path $humanDir 'function-tags.jsonl'))) { $tagMap[$x.full_name]   = $x }
  $synGroups = Read-Jsonl (Join-Path $humanDir 'search-synonyms.jsonl')
}

# --- 用户备注层（个人数据，单独加载，避免重建投影时丢失）---
$userNotes = @{}
foreach ($n in (Read-Jsonl $userNotesPath)) {
  if (-not $userNotes.ContainsKey($n.full_name)) { $userNotes[$n.full_name] = @() }
  $userNotes[$n.full_name] += [pscustomobject]@{ date = $n.date; note = $n.note; by = $n.by }
}

# --- 收藏功能已于 2026-10-13 整体撤销（用户决定：用起来太麻烦繁琐）---
# 原 data/user-library.jsonl 与 tools/favorite.ps1 已删除；status 只表示生命周期，不再有"收藏"这一维。
# 历史：2026-10-13 曾把 status=saved 的 18 条迁移为 watching + user-library favorite，随后整块撤销。

# --- 宽词清单（data/wide-terms.json）---
# 用途：这些词出现在**弱信号**（topics/描述/仓库名）里不足以定分类，但出现在强信号里仍然算数。
# 见 Bug 测试报告 B7；量化过影响面：仅 5/143 条分类变化，其中 2 条是明确修好。
$script:WIDE = @()
$widePath = P 'data\wide-terms.json'
if (Test-Path $widePath) {
  try { $script:WIDE = @((Get-Content $widePath -Raw -Encoding UTF8 | ConvertFrom-Json).wide | Where-Object { $_ }) } catch {}
}

# --- 两级分类规则库 ---
# 纪律：分类**只能**从 taxonomy.json 取。匹配不到就归「其他 → 其他工具」，
#       不得运行时临时新建分类（否则会出现「AI绘画 / AI 绘图 / 生成式视觉」三个同义分类）。
#       发现新方向时应写入 data/taxonomy-suggestions.json，等人工批准。
$taxonomy = $null
if (Test-Path $taxonomyPath) {
  try { $taxonomy = Get-Content $taxonomyPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Warning "taxonomy.json 解析失败，两级分类将全部落到「其他」" }
}
function Get-TwoLevelCategory {
  param([string]$StrongText, [string]$WeakText)
  if (-not $taxonomy) { return @{ l1 = '其他'; l2 = '其他工具' } }
  # 两档匹配：**人话层标签（function_tags / user_keywords / synonyms）是强信号**，优先；
  # 描述 / topics / 备注是弱信号，强信号匹配不到才用。
  # 理由：描述里一个 "notes" 就能把文件搜索工具拽进「AI办公」（2026-10-13 实测 DigUp 踩坑）。
  foreach ($text in @($StrongText, $WeakText)) {
  $isWeak = ($text -eq $WeakText)   # 弱信号：宽词不参与定分类（B7）
    if (-not $text) { continue }
    $t = "$text".ToLower()
    $bestL1 = $null; $bestL2 = $null; $bestLen = 0
    foreach ($l1 in $taxonomy.'一级分类'.PSObject.Properties) {
      foreach ($l2 in $l1.Value.children.PSObject.Properties) {
        foreach ($kw in @($l2.Value)) {
          if (-not $kw) { continue }
          $k = $kw.ToLower()
          # 短关键词必须整词出现。ASCII 关键词放宽到 ≤4 字符（如 book 不能匹配 bookmark）；
          # **中文不做整词匹配**——中文没有词边界，`\b表格\b` 会漏掉「表格软件」这种真实用法。
          $ascii = ($k -match '^[\x00-\x7F]+$')
          $needBoundary = if ($ascii) { $k.Length -le 4 } else { $k.Length -le 3 }
          $hit = if ($needBoundary) { ($t -match ('\b' + [regex]::Escape($k) + '\b')) } else { $t.Contains($k) }
          # 宽词在**弱信号**里降权而不是忽略（B7）：完全忽略会让「唯一信号是 mcp/desktop/agents」的项目
# 掉进「其他」，反而更难找（实测 4 条里 3 条变差）。降权后：非宽词总能赢，只有宽词命中时它仍兜底。
          $effLen = if ($isWeak -and $script:WIDE -and ($script:WIDE -contains $k)) { $k.Length * 0.001 } else { $k.Length }
          if ($hit -and $effLen -gt $bestLen) { $bestL1 = $l1.Name; $bestL2 = $l2.Name; $bestLen = $effLen }
        }
      }
    }
    if ($bestL1) { return @{ l1 = $bestL1; l2 = $bestL2 } }
  }
  return @{ l1 = $taxonomy.'_其他分类'.'一级'; l2 = $taxonomy.'_其他分类'.'二级' }
}

# --- 使用体验五星评分（**独立于 S/A/B 推荐档**）---
# S/A/B 回答「今天值不值得推荐」；五星回答「我用起来爽不爽」。
#   易用性 30% ｜ 文档完整度 20% ｜ 功能成熟度 20% ｜ 维护活跃 15% ｜ 风险 15%
# 关键：**不看 star 数**。500 star 但装上就能用的工具可以是五星；
#       5 万 star 但要配半天环境的，只能三星。
function Get-ExperienceRating {
  param($Desc, $License, $PushedAt, $Risk, $HumanStatus, $Topics, $Archived)
  $d = if ($Desc) { ([string]$Desc).ToLower() } else { '' }
  $topicTxt = (@($Topics) -join ' ').ToLower()

  # **信息不足 → 不评分**。否则"没落盘描述"会被误判成"难用"，
  # 出现"60% 的项目都是 1 星"这种没有信息量的结果。
  # 判定：既没有 API 描述，也没有人话层 → 返回 null，页面显示「未评分」。
  if (-not $d -and $HumanStatus -ne 'complete') {
    return [pscustomobject]@{ stars = $null; score = $null; parts = $null; reason = '信息不足，未评分' }
  }

  # ① 易用性 30：有一键安装线索 + 不需要自建服务
  $ease = 0
  if ($d -match 'npx |pip install|pipx install|cargo install|brew install|npm install|一键|one-click|1-click|无需配置') { $ease = 30 }
  elseif ($d -match 'command-line|\bcli\b|terminal|命令行') { $ease = 22 }
  elseif ($d -match 'docker|compose|kubernetes|self-host|自建|需要.*服务器') { $ease = 12 }
  elseif ($d) { $ease = 18 }
  else { $ease = 8 }
  if ($d -match 'docker|compose|kubernetes|self-host') { $ease = [math]::Max(6, $ease - 8) }

  # ② 文档完整度 20：有 description 且偏长；有人话层更佳
  $doc = 0
  if ($d.Length -ge 120) { $doc = 20 } elseif ($d.Length -ge 60) { $doc = 16 } elseif ($d.Length -ge 20) { $doc = 12 } elseif ($d) { $doc = 8 }
  if ($HumanStatus -eq 'complete') { $doc = [math]::Min(20, $doc + 4) }
  if (-not $d) { $doc = 0 }

  # ③ 功能成熟度 20：星数只作弱信号（不是主依据）
  $mature = 10
  if ($Archived -eq $true) { $mature = 2 }
  elseif (@($Topics).Count -ge 8) { $mature = 18 }
  elseif (@($Topics).Count -ge 3) { $mature = 15 }
  elseif (@($Topics).Count -ge 1) { $mature = 12 }

  # ④ 维护活跃 15：看最近提交时间
  $active = 8
  if ($PushedAt) {
    try {
      $days = ([datetime]::Now - [datetime]$PushedAt).Days
      if ($days -le 7) { $active = 15 } elseif ($days -le 30) { $active = 13 }
      elseif ($days -le 90) { $active = 10 } elseif ($days -le 365) { $active = 5 } else { $active = 2 }
    } catch {}
  }

  # ⑤ 风险 15：风险低得满分
  $riskScore = switch ("$Risk") { '低' { 15 } '中' { 10 } '高' { 3 } default { 8 } }

  $total = $ease + $doc + $mature + $active + $riskScore   # 满分 100
  # 分档（按"有信息的项目"重新校准，避免人人低星）
  $stars = if ($total -ge 82) { 5 } elseif ($total -ge 68) { 4 } elseif ($total -ge 52) { 3 } elseif ($total -ge 40) { 2 } else { 1 }
  return [pscustomobject]@{
    stars = $stars; score = $total
    parts = [pscustomobject]@{ 易用性 = $ease; 文档完整度 = $doc; 功能成熟度 = $mature; 维护活跃 = $active; 风险 = $riskScore }
    reason = $null
  }
}

# picks：按 full_name 收集所有推荐决策
$picksByRepo = @{}
if (Test-Path $picksDir) {
  Get-ChildItem $picksDir -Filter '*.jsonl' | Sort-Object Name | ForEach-Object {
    foreach ($p in (Read-Jsonl $_.FullName)) {
      if (-not $picksByRepo.ContainsKey($p.full_name)) { $picksByRepo[$p.full_name] = @() }
      $picksByRepo[$p.full_name] += $p
    }
  }
}

# CSV：首次推荐日 / 档位 / 一句话 / 方向
$csvMap = @{}
if (Test-Path $csvPath) {
  foreach ($r in (Import-Csv $csvPath -Encoding UTF8)) { $csvMap[$r.仓库] = $r }
}

# ---------- 快照时间序列 ----------
$snapDates = @()
$snapsByRepo = @{}
if (Test-Path $snapDir) {
  Get-ChildItem $snapDir -Filter '*.jsonl' | Sort-Object Name | ForEach-Object {
    $d = $_.BaseName
    $snapDates += $d
    foreach ($s in (Read-Jsonl $_.FullName)) {
      if (-not $snapsByRepo.ContainsKey($s.full_name)) { $snapsByRepo[$s.full_name] = @() }
      $snapsByRepo[$s.full_name] += [pscustomobject]@{ date = $d; stars = $s.stars; forks = $s.forks; pushed_at = $s.pushed_at }
    }
  }
}

# ---------- 分类推断（按"命中来源"加权计分，结果可解释） ----------
# 权重依据：topics 是作者自己打的标签，最可信；description 次之；仓库名最弱（易误判，如 "image-gen" 里的 image）。
# 旧做法是"第一个关键词命中就拍板"，会把 `generat` 命中 "auto-generated docs" 而误判为"创作"。改为计分后取最高分。
$TAX = @{
  '领域' = @(
    @('AI',   'ai-agent|ai-tools|\bai\b|agent-skill|llm|gpt|diffusion|transformer|\bmcp\b|mcp-server|machine-learning|computer-vision|inference|prompt'),
    @('安全', 'security|exploit|\bcve\b|pentest|malware|firewall|vulnerab|encrypt'),
    @('数据', 'database|duckdb|\bsql\b|\betl\b|dataset|analytics|vector|ontology|storage'),
    @('运维', 'docker|kubernetes|\bk8s\b|deploy|observability|devops|helm|terraform|self-hosted'),
    @('效率', 'productivity|\bnote\b|todo|calendar|workflow|shortcut|launcher|personal-assistant'),
    @('学习', 'tutorial|course|\blearn\b|roadmap|awesome|interview|cheatsheet|explainer'),
    @('开发', 'developer-tools|code-quality|refactoring|static-analysis|\bcli\b|\bsdk\b|compiler|framework|debug|\bgit\b|codegen|coding')
  )
  '形态' = @(
    @('资源列表', 'awesome|collection|roadmap|\bbooks\b|interview|cheatsheet'),
    @('插件',     'plugin|extension|agent-skill|claude-skill|dsh-plugin|\bmcp\b|addon|integration'),
    @('桌面',     'desktop-app|\bdesktop\b|electron|tauri|\bgui\b|head unit|macos app'),
    @('Web',      'web app|browser|dashboard|frontend|website'),
    @('CLI',      '\bcli\b|command-line|command line|terminal|\btui\b'),
    @('框架',     'framework|\bengine\b|runtime|harness|platform'),
    @('模板',     'template|boilerplate|starter|scaffold'),
    @('库',       'library|\bsdk\b|package|binding|wrapper')
  )
  '用途' = @(
    @('自动化', 'automation|automate|\bbot\b|schedul|workflow'),
    @('监控',   'monitor|observability|metrics|alert|logging|trace'),
    @('部署',   'deploy|docker|kubernetes|hosting|self-host'),
    @('替代',   'alternative|replacement|instead of'),
    @('学习',   'tutorial|\blearn\b|study|explain|course'),
    @('创作',   'image generation|image editing|text-to-image|inpainting|photo edit|\bvideo\b|\baudio\b|\bdesign\b|render|draw'),
    @('提效',   'productivity|faster|efficient|boost|helper|utility|fuzzy|\bsearch\b')
  )
}
function Score-Tag {
  param($Pairs, $Map)
  $best = $null; $bestScore = 0
  foreach ($pair in $Map) {
    $label = $pair[0]; $pattern = $pair[1]
    $score = 0
    foreach ($p in $Pairs) {
      $t = "$($p[0])"; $w = [int]$p[1]
      if ($t -ne '' -and $t -match $pattern) { $score += $w }
    }
    if ($score -gt $bestScore) { $bestScore = $score; $best = $label }
  }
  return [pscustomobject]@{ tag = $best; score = $bestScore }
}

# 每维分值：**GitHub 原生字段优先**，关键词推断只作补充。
#   topics(原生,作者自打) 5 ｜ description(原生) 3 ｜ name(原生) 2 ｜ language(原生,仅形态维) 2 ｜ 备注(自撰) 1
$TAG_WEIGHTS = @{
  '领域' = @{ topics = 5; description = 3; name = 2; note = 1; language = 0 }
  '形态' = @{ topics = 5; description = 3; name = 2; note = 1; language = 2 }
  '用途' = @{ topics = 4; description = 3; name = 1; note = 1; language = 0 }
}
# language → 形态 的原生映射（语言本身就能排除一些形态）
$LANG_FORM = @{
  'TypeScript' = '插件'; 'JavaScript' = '插件'; 'Swift' = '桌面'; 'Kotlin' = '桌面'
  'C#' = '桌面'; 'C++' = '桌面'; 'Rust' = 'CLI'; 'Go' = 'CLI'; 'Shell' = 'CLI'
  'Python' = '库'; 'Jupyter Notebook' = '库'; 'HTML' = 'Web'; 'CSS' = 'Web'; 'Vue' = 'Web'
}

function Get-RepoTag {
  param($RepoMeta, [string]$FallbackText, [string]$Language)
  $topicsText = if ($RepoMeta -and $RepoMeta.topics) { (@($RepoMeta.topics) -join ' ').ToLower() } else { '' }
  $descText   = if ($RepoMeta -and $RepoMeta.description) { ([string]$RepoMeta.description).ToLower() } else { '' }
  $noteText   = if ($FallbackText) { ([string]$FallbackText).ToLower() } else { '' }
  $nameText   = if ($RepoMeta -and $RepoMeta.full_name) { ([string]$RepoMeta.full_name).ToLower() } else { '' }

  $tags = [ordered]@{}
  foreach ($dim in '领域','形态','用途') {
    $w = $TAG_WEIGHTS[$dim]
    $pairs = @(
      @($topicsText, $w.topics),
      @($descText,   $w.description),
      @($nameText,   $w.name),
      @($noteText,   $w.note)
    )
    $r = Score-Tag $pairs $TAX[$dim]
    # 语言原生映射：仅在形态维、且关键词没给出结果时兜底
    if ($dim -eq '形态' -and (-not $r.tag) -and $Language -and $LANG_FORM.ContainsKey($Language)) {
      $r = [pscustomobject]@{ tag = $LANG_FORM[$Language]; score = $w.language }
    }
    if (-not $r.tag) {
      $r = [pscustomobject]@{ tag = $(if ($dim -eq '领域') { '其他' } elseif ($dim -eq '形态') { '库' } else { '提效' }); score = 0 }
    }
    $tags[$dim] = $r.tag
    # 记录分值，供 tags_confidence 判定
    if ($dim -eq '领域') { $script:_domainScore = $r.score }
  }

  $archivedFlag = if ($RepoMeta) { $RepoMeta.archived } else { $null }
  $tags['成熟度'] = if ($archivedFlag -eq $true) { '归档' } else { '实验' }
  $tags['上手难度'] = if ($descText -match 'docker|compose|kubernetes|self-host|deploy') { '要部署' }
                     elseif ($descText -match 'npx |pip install|npm install|cargo install|command-line|\bcli\b') { '开箱即用' }
                     elseif ($descText -match 'python|typescript|javascript|rust|c\+\+|go\b') { '要编程' }
                     else { '轻配置' }
  # confidence：原生字段(topics/description)给出结论 = inferred；只靠兜底 = unknown
  $conf = if ($descText -or $topicsText) { 'inferred' } else { 'unknown' }
  return [pscustomobject]@{ tags = $tags; confidence = $conf }
}

# ---------- 事件收集 ----------
$events = New-Object System.Collections.ArrayList
function Add-Event([string]$id, [string]$date, [string]$type, [string]$detail, [string]$src) {
  [void]$events.Add([pscustomobject]@{ id = $id; full_name = $id; date = $date; type = $type; detail = $detail; src = $src })
}

$projects = New-Object System.Collections.ArrayList

foreach ($s in $seen) {
  $id = $s.full_name
  $parts = $id -split '/', 2
  $owner = $parts[0]; $name = if ($parts.Count -gt 1) { $parts[1] } else { '' }

  # --- 远端元数据：优先补录文件，其次视为缺失 ---
  $m = $metaMap[$id]
  $desc = $null; $lic = $null; $topics = @(); $archived = $null; $pushedAt = $null
  $descSource = 'missing'
  if ($m) {
    if ($m.description) { $desc = $m.description; $descSource = 'api' }
    $lic = $m.license
    if ($m.topics) { $topics = @($m.topics) }
    $archived = $m.archived
    $pushedAt = $m.pushed_at
  }

  # --- 快照序列 ---
  $snaps = @()
  if ($snapsByRepo.ContainsKey($id)) { $snaps = @($snapsByRepo[$id] | Sort-Object date) }
  $cur = if ($snaps.Count -gt 0) { $snaps[-1].stars } else { $s.last_stars }
  $first = if ($snaps.Count -gt 0) { $snaps[0].stars } else { $s.first_stars }
  $lastDate = if ($snaps.Count -gt 0) { $snaps[-1].date } else { $null }

  # delta_7d：最近 7 天内的第一份快照 → 最新
  $d7 = 0
  if ($snaps.Count -ge 2) {
    $cut = ([datetime]::ParseExact($lastDate, 'yyyy-MM-dd', $null)).AddDays(-7)
    $base = $snaps | Where-Object { ([datetime]::ParseExact($_.date, 'yyyy-MM-dd', $null)) -ge $cut } | Select-Object -First 1
    if ($base) { $d7 = [int]$cur - [int]$base.stars }
  }

  # 星数事件：逐对比较，仅记超阈值的
  if ($snaps.Count -ge 2) {
    for ($i = 1; $i -lt $snaps.Count; $i++) {
      $d = [int]$snaps[$i].stars - [int]$snaps[$i-1].stars
      if ([math]::Abs($d) -ge $StarsThreshold) {
        $type = if ($d -gt 0) { 'stars_up' } else { 'stars_drop' }
        Add-Event $id $snaps[$i].date $type ("{0}{1} 星（{2} → {3}）" -f $(if($d -gt 0){'+'}else{'−'}), [math]::Abs($d), $snaps[$i-1].stars, $snaps[$i].stars) 'snapshots'
      }
    }
  }

  # --- 推荐事件 ---
  # 主来源 picks/；但 2026-10-11 首日运行没有写 picks 文件，该日的 8 条推荐只存在于
  # recommend-log.csv。这里做缺失兜底：picks 里没有的日期，用 CSV 补齐，避免"推荐过但无事件"。
  # **不过滤 dropped**：已放弃的推荐仍有历史价值（pickDates 要认得出那天已有记录，否则 CSV 兜底会误注入）。
  # 是否算「推荐过」在写档案时用 tier 判定。
  $plist = @()
  if ($picksByRepo.ContainsKey($id)) { $plist = @($picksByRepo[$id] | Sort-Object date) }
  $pickDates = @($plist | ForEach-Object { $_.date })
  $csvR = $csvMap[$id]
  if ($csvR -and $csvR.首次推荐日 -and ($pickDates -notcontains $csvR.首次推荐日)) {
    $plist = @([pscustomobject]@{
      date = $csvR.首次推荐日; full_name = $id; tier = $csvR.档位
      score = $null; risk = $null; source = $csvR.方向; action = $null
      src = 'csv(兜底)'   # **自带身份标记**：以前靠「有没有 score」猜来源，无 score 的真实 picks 会被误标
    }) + $plist
    $plist = @($plist | Sort-Object date)
  }
  $recCount = 0
  foreach ($p in $plist) {
    # **已放弃的决策不产生「已推荐」事件**（那是淘汰记录，不是推荐）。
    # 但它必须留在 $plist 里，否则 pickDates 认不出当天已有记录，CSV 兜底会误注入假推荐。
    if ($p.tier -eq 'dropped') { continue }
    $recCount++
    $type = if ($recCount -eq 1) { 'recommended' } else { 're_recommended' }
    $scoreTxt = if ($p.score) { " · $($p.score) 分" } else { '' }
    $detail = if ($recCount -eq 1) { "$($p.tier) 档$scoreTxt$(if($p.action){" · 行动：$($p.action)"})" } else { "第 $recCount 次推荐，$($p.tier) 档$scoreTxt" }
    $evtSrc = if ($p.PSObject.Properties['src'] -and $p.src) { $p.src } else { 'picks' }
    Add-Event $id $p.date $type $detail $evtSrc
  }
  $lastPick = if ($plist.Count -gt 0) { $plist[-1] } else { $null }

  # --- 首次发现事件 ---
  $srcQ = if ($csvMap.ContainsKey($id) -and $csvMap[$id].方向) { $csvMap[$id].方向 }
          elseif ($lastPick) { $lastPick.source } else { '未知' }
  Add-Event $id $s.first_seen 'discovered' "首次收录，来源 $srcQ" 'seen'

  # --- 状态变化事件（需 status-log.jsonl，缺则跳过，不伪造） ---
  foreach ($st in ($statuses | Where-Object { $_.full_name -eq $id })) {
    Add-Event $id $st.date 'status_changed' "$($st.from) → $($st.to)" 'status-log'
  }

  # --- 维护事件 ---
  if ($pushedAt) {
    try {
      $days = ([datetime]::Now - [datetime]$pushedAt).Days
      if ($days -ge 90) { Add-Event $id $lastDate 'push_activity' "已 $days 天无提交" 'api' }
    } catch {}
  }

  # --- 分类标签 ---
  # 规则（v2.1）：**优先使用 GitHub 原生字段**，关键词推断只作补充，避免项目变多后分类漂移。
  #   领域   ← topics（作者自打的标签，最可靠）> description > note > id
  #   形态   ← language + topics + name（原生字段优先，能区分 CLI/库/桌面/Web/插件）
  #   用途   ← description + topics（这项工作原生字段给不了，只能推断）
  $tagsResult = Get-RepoTag -RepoMeta $m -FallbackText "$id $($s.note)" -Language $s.language
  $tags = $tagsResult.tags
  $tags['风险等级'] = if ($lastPick -and $lastPick.risk) { $lastPick.risk } else { '中' }
  $tagsConf = $tagsResult.confidence

  # --- 元数据变更事件（回放 data/meta/ 历史，逐对比较）---
  # 只有"当前快照"是算不出这些变化的，所以 meta 层必须按天追加。
  $hist = @()
  if ($metaHistory.ContainsKey($id)) { $hist = @($metaHistory[$id] | Sort-Object date) }
  if ($hist.Count -ge 2) {
    for ($i = 1; $i -lt $hist.Count; $i++) {
      $prev = $hist[$i-1]; $curr = $hist[$i]; $d = $curr.date
      if ($prev.license -ne $curr.license) {
        Add-Event $id $d 'license_changed' "$(if($prev.license){$prev.license}else{'无'}) → $(if($curr.license){$curr.license}else{'无'})" 'meta'
      }
      if ([bool]$prev.archived -ne [bool]$curr.archived) {
        Add-Event $id $d 'archived_changed' "$(if($curr.archived){'已归档'}else{'解除归档'})" 'meta'
      }
      # description / topics 变化合并为一次 metadata_updated，避免刷屏
      $descChanged = ($prev.description -ne $curr.description)
      $topicsChanged = (($prev.topics -join ',') -ne ($curr.topics -join ','))
      if ($descChanged -or $topicsChanged) {
        $what = @()
        if ($descChanged) { $what += '描述' }
        if ($topicsChanged) { $what += "topics($($curr.topics.Count) 个)" }
        Add-Event $id $d 'metadata_updated' "$($what -join ' + ') 有更新" 'meta'
      }
      # 分类变化：用当期元数据重算标签，与上一期比较
      $prevTag = (Get-RepoTag -RepoMeta $prev -FallbackText $id -Language $s.language).tags
      $changed = @()
      foreach ($dim in '领域','形态','用途') {
        if ($prevTag[$dim] -ne $tags[$dim]) { $changed += "$dim $($prevTag[$dim])→$($tags[$dim])" }
      }
      if ($changed.Count -gt 0) { Add-Event $id $d 'category_changed' ($changed -join '；') 'meta' }
    }
  }

  # --- release_detected：用原生 pushed_at + release_at 判定，不额外调 API ---
  # 判定：本次元数据相对上一份，pushed_at 前移 **且** 距上次被记为 release 已 ≥ 14 天。
  # 说明：Search API 不直接返回 release，这是"显著更新"的合理近似，非精确 release 记录。
  if ($hist.Count -ge 1) {
    $lastRel = $null
    $lastPush = $null
    foreach ($h in $hist) {
      if ($h.release_at) { $lastRel = [datetime]$h.release_at }
      $pushT = $null; if ($h.pushed_at) { try { $pushT = [datetime]$h.pushed_at } catch {} }
      if ($pushT -and $lastPush -and $pushT -gt $lastPush) {
        $gapOk = (-not $lastRel) -or (($pushT - $lastRel).TotalDays -ge 14)
        if ($gapOk) {
          Add-Event $id $h.date 'release_detected' "有显著更新（pushed_at $($pushT.ToString('yyyy-MM-dd'))）" 'meta'
          $lastRel = $pushT
        }
      }
      if ($pushT) { $lastPush = $pushT }
    }
  }

  $evCount = ($events | Where-Object { $_.id -eq $id }).Count

  # --- 人话层合并（优先级高于自动推断）---
  $intro = $introMap[$id]
  $ftag  = $tagMap[$id]
  $human = [pscustomobject]@{
    status       = if ($intro) { 'complete' } elseif ($s.note) { 'partial' } else { 'missing' }
    one_liner    = if ($intro) { $intro.one_liner } elseif ($s.note) { $s.note } else { $null }
    one_liner_src= if ($intro) { $intro.source } elseif ($s.note) { '仅台账备注' } else { 'missing' }
    problem      = if ($intro) { $intro.problem } else { $null }
    example      = if ($intro) { $intro.example } else { $null }
    feature_note = if ($intro) { $intro.feature_note } else { $null }
    written_at   = if ($intro -and $intro.written_at) { $intro.written_at } else { $null }
    note_extra   = if ($intro -and $intro.PSObject.Properties['note_extra']) { $intro.note_extra } else { $null }
  }
  # **禁止 `$x = if (...) { @() }` 写法**：PowerShell 里语句值返回空数组会塌成 $null，
  # 之后 @($null) 又变成「含一个 null 的数组」，序列化成 [null]，前端 .map 取值直接 TypeError。
  # 一律用「先初始化为 @()，再 if 赋值」。2026-10-13 卡片点不了就是这个坑造成的。
  $functionTags = @(); $userKeywords = @(); $synonyms = @()
  if ($ftag) {
    if ($ftag.function_tags) { $functionTags = @($ftag.function_tags | Where-Object { $_ }) }
    if ($ftag.user_keywords) { $userKeywords = @($ftag.user_keywords | Where-Object { $_ }) }
    if ($ftag.synonyms)      { $synonyms     = @($ftag.synonyms      | Where-Object { $_ }) }
  }
  # 用户备注（个人数据，来自 data/user-notes.jsonl）
  $userNotesArr = @()
  if ($userNotes.ContainsKey($id)) { $userNotesArr = @($userNotes[$id]) }

  # --- 两级分类（从 taxonomy.json 取，匹配不到归「其他→其他工具」）---
  # 强信号 = 人话层的功能标签 / 用户搜索词 / 同义词
  # 弱信号 = 描述 / GitHub topics / 仓库名
  #
  # **2026-10-13 修复（未定义变量）**：原写法是
  #     $weakText = @($desc, $topicText, $noteText, $id) -join ' '
  # 但 `$topicText` 全脚本只在那一行出现过（从未赋值），`$noteText` 只存在于 Get-RepoTag 函数内部
  #（函数局部变量不外泄）→ 两者在循环作用域都是 $null，**topics 实际没参与分类**。
  #
  # **台账备注的使用规则（2026-10-13 实测确定）**：
  #   * 只在「描述与 topics 都为空」时作兜底 —— 这类条目没有别的客观素材，备注是唯一线索
  #   * **已淘汰条目一律不用备注** —— 它们的备注是剔除理由（如「文档/电子书类，非工具」），
  #     当特征用会把电子书判成「AI办公」
  $topicsStr = @($topics) -join ' '
  $noteFallback = ''
  if (-not $desc -and -not $topicsStr -and $s.status -ne 'dropped') { $noteFallback = "$($s.note)" }
  $strongText = @(($functionTags -join ' '), ($userKeywords -join ' '), ($synonyms -join ' ')) -join ' '
  $weakText   = @($desc, $topicsStr, $noteFallback, $id) -join ' '
  $l2cat = Get-TwoLevelCategory -StrongText $strongText -WeakText $weakText

  # --- 使用体验五星（独立于 S/A/B 推荐档；**不看 star 数**）---
  $exp = Get-ExperienceRating -Desc $desc -License $lic -PushedAt $pushedAt -Risk $tags['风险等级'] `
                              -HumanStatus $human.status -Topics $topics -Archived $archived

  # --- 来源与评级状态 ---
  # origin 与 source **不是一回事**：source=来自哪个检索式（Q1/专题…）；origin=谁引入的（自动发现/用户推荐）
  # 用户主动推荐的项目未经日报流程筛选，故 tier 记 'unrated'，不伪装成 S/A/B。
  $origin = if ($s.PSObject.Properties['origin'] -and $s.origin) { $s.origin } else { 'auto' }
  $isUserAdded = ($origin -eq 'user')
  $tierOut = if ($isUserAdded -and -not $lastPick) { 'unrated' } elseif ($lastPick) { $lastPick.tier } else { $null }

  [void]$projects.Add([pscustomobject][ordered]@{
    id = $id; url = $s.url; owner = $owner; name = $name
    description = $desc; description_source = $descSource
    license = $lic; topics = $topics; archived = $archived; pushed_at = $pushedAt
    language = $s.language
    first_seen = $s.first_seen; last_seen = $s.last_seen
    recommended = ($tierOut -in @('S','A')) -and ($s.status -ne 'dropped'); recommend_count = $recCount
    last_recommended = if ($lastPick) { $lastPick.date } elseif ($s.PSObject.Properties['last_recommended']) { $s.last_recommended } else { $null }
    tier = $tierOut
    score = if ($lastPick) { $lastPick.score } else { $null }
    risk = if ($lastPick) { $lastPick.risk } else { $null }
    source = if ($lastPick) { $lastPick.source } else { $null }
    origin = $origin
    origin_note = if ($isUserAdded) { '用户推荐' } else { '自动发现' }
    action = if ($lastPick) { $lastPick.action } else { $null }
    status = $s.status
    tags = $tags
    category = [pscustomobject]@{ l1 = $l2cat.l1; l2 = $l2cat.l2 }
    experience = [pscustomobject]@{ stars = $exp.stars; score = $exp.score; parts = $exp.parts }
    tags_confidence = $tagsConf
    stars = [pscustomobject]@{
      current = $cur; first = $first
      delta_total = ([int]$cur - [int]$first); delta_7d = $d7
      last_snapshot = $lastDate; snapshots = $snaps.Count
      github = if ($m -and $m.stars) { [int]$m.stars } else { $null }
      github_at = if ($m -and $m.fetched_at) { $m.fetched_at } else { $null }
    }
    events_count = $evCount
    note = $s.note
    user_notes = $userNotesArr
    human = $human
    function_tags = $functionTags
    user_keywords = $userKeywords
    synonyms = $synonyms
    updated_at = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
  })
}

# ---------- 写盘（先算指纹，跳过无变化的写入） ----------
function Signature([string[]]$paths) {
  $sb = New-Object System.Text.StringBuilder
  foreach ($p in ($paths | Sort-Object)) {
    if (Test-Path $p) {
      $i = Get-Item $p
      [void]$sb.Append("$($i.Name):$($i.Length):$($i.LastWriteTimeUtc.Ticks);")
    }
  }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($sb.ToString()))
  return ([BitConverter]::ToString($hash) -replace '-','')
}

$srcPaths = @($seenPath, $csvPath, $statusLog)
if (Test-Path $snapDir) { $srcPaths += (Get-ChildItem $snapDir -Filter '*.jsonl').FullName }
if (Test-Path $picksDir) { $srcPaths += (Get-ChildItem $picksDir -Filter '*.jsonl').FullName }
if (Test-Path $metaDir) { $srcPaths += (Get-ChildItem $metaDir -Filter '*.jsonl').FullName }
if (Test-Path $humanDir) { $srcPaths += (Get-ChildItem $humanDir -Filter '*.jsonl').FullName }
if (Test-Path $userNotesPath) { $srcPaths += $userNotesPath }
if (Test-Path $taxonomyPath) { $srcPaths += $taxonomyPath }
$sig = Signature $srcPaths
$sigFile = P 'data\.projects-signature'

$projPath = P 'data\projects.jsonl'
$evPath   = P 'data\events.jsonl'
if (-not $Force -and (Test-Path $sigFile) -and (Test-Path $projPath) -and (Get-Content $sigFile -Raw).Trim() -eq $sig) {
  Write-Host "输入未变化，跳过重建（用 -Force 强制）。指纹：$($sig.Substring(0,12))…" -ForegroundColor DarkGray
  exit 0
}

# 保护：宁可什么都不做，也不能清空投影。
# （2026-10-14 实测：原始层被判空后，$projects 为空 → 仍会往下写，把 projects.jsonl / events.jsonl 覆写成空文件，
#   页面瞬间变"0 个工具"。空输入应当中止写盘，而不是静默擦除。）
if (@($projects).Count -eq 0) {
  Write-Host ""
  Write-Host "⚠ 没有任何可写入的项目 —— 为避免清空 projects.jsonl / events.jsonl，**本次不写盘**。" -ForegroundColor Yellow
  Write-Host "  请检查 data\seen.jsonl（去重台账）是否被清空或删除；确认无误后可加 -Force 重跑。"
  if (-not $Force) { exit 0 }
  Write-Host "  （已传 -Force：仍然继续写盘）" -ForegroundColor DarkYellow
}

$enc = New-Object System.Text.UTF8Encoding($false)
# 用 @() 强制成数组：空集合经管道会变成 $null，而 WriteAllLines 收到 null 会抛 .NET 异常（2026-10-14 修复）
$projLines = @($projects | Sort-Object id | ForEach-Object { ($_ | ConvertTo-Json -Depth 10 -Compress) })
[System.IO.File]::WriteAllLines($projPath, $projLines, $enc)

$evLines = @($events | Sort-Object date, id, type | ForEach-Object { ($_ | ConvertTo-Json -Depth 4 -Compress) })
[System.IO.File]::WriteAllLines($evPath, $evLines, $enc)

Set-Content -Path $sigFile -Value $sig -Encoding UTF8

# ---------- 汇总 ----------
$withDesc = ($projects | Where-Object { $_.description }).Count
$recN = ($projects | Where-Object { $_.recommended -eq $true }).Count
Write-Host ""
Write-Host "=== 同步完成 ===" -ForegroundColor Green
Write-Host "  projects.jsonl : $($projects.Count) 个项目（推荐过 $recN 条；有描述 $withDesc 条）"
Write-Host "  events.jsonl   : $($events.Count) 条事件"
Write-Host "  星数事件阈值   : ±$StarsThreshold"
$byType = $events | Group-Object type | Sort-Object Count -Descending
if ($byType) { Write-Host ("  事件分布       : " + (($byType | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join '  ')) }
Write-Host "  输入指纹       : $($sig.Substring(0,12))…"
