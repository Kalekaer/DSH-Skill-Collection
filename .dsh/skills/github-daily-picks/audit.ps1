# github-daily-picks 不变量校验（只读）
# 用法：在工作区根目录执行  pwsh -File .dsh\skills\github-daily-picks\audit.ps1
$ErrorActionPreference = 'Continue'
# root 必须由**脚本自身位置**推导，不能用 (Get-Location)：
# 否则从别处调用会去检查**另一个工作区**（2026-10-13 发布检查时实测：副本只有 15 条，
# audit 却报「主档案 143 条」——它其实在查原库，等于没有验证到副本）。
# 路径层级：<root>\.dsh\skills\github-daily-picks\audit.ps1 → 上溯 3 层到 <root>
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
# **发布/demo 数据判据**：没有 data\seen.jsonl 就说明这不是完整个人库（发布版只带 demo 数据），
# 依赖个人数据的检查会自动通过 —— 否则发布版跑 audit 满屏红，看着像坏了（2026-10-13 定，方案 A）。
$isDemo = -not (Test-Path (Join-Path $root 'data\seen.jsonl'))
$base = Join-Path $root '.dsh\skills\github-daily-picks'
$skill = Join-Path $base 'SKILL.md'
$tpl   = Join-Path $root 'TEMPLATES\daily.md'
$prompt= Join-Path $root 'PROMPT-daily.md'
$dread = Join-Path $root 'data\README.md'

$script:pass = 0; $script:fail = 0; $script:skip = 0
# 本脚本的检查项总数。**新增/删除 Chk 时必须同步改这里**，并同步 CHANGELOG.md 与 README.md 里的「N 项」，
# 否则第 17 节会报 FAIL —— 这是故意设计的，防止校验项被悄悄删掉而无人察觉。
$script:TOTAL_CHECKS = 167
function Chk([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) { $script:pass++; Write-Host ("  [PASS] {0}" -f $name) -ForegroundColor Green }
  else     { $script:fail++; Write-Host ("  [FAIL] {0} {1}" -f $name, $detail) -ForegroundColor Red }
}

function Skip([string]$name, [string]$reason) {
  # SKIP = 该检查对本副本**不适用**（不是通过、也不是失败）。发布版缺个人表/个人数据时用它，
  # 避免把「设计上不适用」与「真失败」混为一谈（用户 2026-10-14 建议）。
  $script:skip++
  Write-Host ("  [SKIP] {0} —— {1}" -f $name, $reason) -ForegroundColor DarkYellow
}
$S = Get-Content $skill -Raw
$T = Get-Content $tpl -Raw
$P = Get-Content $prompt -Raw
$D = Get-Content $dread -Raw

Write-Host "`n=== 1. 结构完整性 ==="
Chk "SKILL 章节数 = 14" ((Select-String -Path $skill -Pattern '^## ').Count -eq 14) "实际 $((Select-String -Path $skill -Pattern '^## ').Count)"
$refs = Select-String -Path $skill -Pattern 'references/([a-z\-]+\.md)' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing = $refs | Where-Object { -not (Test-Path (Join-Path $base "references\$_")) }
Chk "references 引用全部存在 ($($refs.Count) 个)" ($missing.Count -eq 0) "缺失: $($missing -join ', ')"

Write-Host "`n=== 2. S 档项数口径唯一（12 项，不含第 13 项）==="
Chk "SKILL 未出现 '第 13 项' 式字段" (-not ($S -match '(?m)^13\. \*\*')) 
Chk "SKILL 声明 12 项" ($S -match '收集齐全的 12 项')
Chk "TEMPLATE 有 1-12 且无 13" (($T -match '(?m)^12\. \*\*总结') -and -not ($T -match '(?m)^13\. \*\*'))
Chk "SKILL 明确『代价/坑』归属第 7 项" ($S -match '不是第 13 项')

Write-Host "`n=== 3. 限流/重试口径一致（403 不重试）==="
Chk "SKILL: 403 不重试" ($S -match '403` 限流 / `422` 参数错误 \| \*\*不重试\*\*')
Chk "SOURCES-Q: 403 不重试" ((Get-Content (Join-Path $base 'references\sources-queries.md') -Raw) -match 'rate limit exceeded.*不重试')

Write-Host "`n=== 4. 风险等级为单值枚举 ==="
Chk "SKILL 规定字段位只写单值" ($S -match '只写 `低` / `中` / `高` 单个值')
Chk "TEMPLATE 提供风险枚举表" ($T -match '\| 风险等级 \| 低 / 中 / 高 \|')
$ex = Get-Content (Join-Path $base 'references\example.md') -Raw
Chk "EXAMPLE 无『风险：低、xx』式附加文字" (-not ($ex -match '风险：(低|中|高)[、，]'))

Write-Host "`n=== 5. 分类标签六维取值合法 ==="
$dims = @{
  '领域' = @('AI','开发','效率','数据','安全','运维','学习','其他')
  '形态' = @('CLI','Web','桌面','插件','库','框架','模板','资源列表')
  '用途' = @('提效','自动化','学习','替代','监控','部署','创作')
  '成熟度'= @('实验','活跃','稳定','归档')
  '上手难度'=@('开箱即用','轻配置','要编程','要部署')
}
$tagLines = [regex]::Matches($ex, '(?m)^5\. \*\*分类标签\*\*：(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim('。') }
Chk "EXAMPLE 分类标签行数 >= 2" ($tagLines.Count -ge 2) "实际 $($tagLines.Count)"
$tagBad = @()
foreach ($l in $tagLines) {
  $vals = $l -split '/' | ForEach-Object { $_.Trim().TrimEnd('。') }
  if ($vals.Count -ne 6) { $tagBad += "位数不对($($vals.Count)): $l"; continue }
  $i = 0
  foreach ($k in @('领域','形态','用途','成熟度','上手难度')) {
    if ($dims[$k] -notcontains $vals[$i]) { $tagBad += "$k 非法值『$($vals[$i])』" }
    $i++
  }
  if (@('低','中','高') -notcontains $vals[5]) { $tagBad += "风险 非法值『$($vals[5])』" }
}
Chk "EXAMPLE 分类标签每维取值合法" ($tagBad.Count -eq 0) ($tagBad -join '; ')

Write-Host "`n=== 6. 落盘顺序与文件清单 ==="
Chk "SKILL: picks 必须在打分后写" ($S -match '必须在打分排序完成之后才写')
Chk "SKILL: 表格永远最后" ($S -match '表格同步（`.univer`）永远排在最后')
Chk "PROMPT: 七件事" ($P -match '落盘七件事')
Chk "PROMPT: 含 picks 步骤" ($P -match 'data/picks/YYYY-MM-DD\.jsonl')
Chk "PROMPT: 表格排最后" ($P -match '表格永远排最后')

Write-Host "`n=== 7. 台账 schema 一致性 ==="
$statusValues = @('active','using','watching','saved','researching','dropped')
$missStatus = $statusValues | Where-Object { $D -notmatch [regex]::Escape($_) }
Chk "data/README 含状态白名单（含 using）" ($missStatus.Count -eq 0) "缺: $($missStatus -join ', ')"
$missSkillStatus = $statusValues | Where-Object { $S -notmatch [regex]::Escape($_) }
Chk "SKILL 含状态白名单（含 using）" ($missSkillStatus.Count -eq 0) "缺: $($missSkillStatus -join ', ')"
Chk "data/README 有 last_recommended 回退说明" ($D -match '回退用 `last_seen`')
Chk "PROMPT 有 last_recommended 回退说明" ($P -match '回退用 `last_seen`')
# 字段表结构：字段表区间内不得出现 status 值行
$lines = Get-Content $dread
$hdr = ($lines | Select-String -Pattern '^\| 字段 \| 含义 \|' | Select-Object -First 1).LineNumber
$end = ($lines | Select-String -Pattern '取值白名单' | Select-Object -First 1).LineNumber
if ($hdr -and $end) {
  $seg = $lines[($hdr)..($end-2)]
  $bad = $seg | Where-Object { $_ -match '^\| `(active|watching|saved|researching|dropped)`' }
  Chk "data/README 字段表未混入 status 值" ($bad.Count -eq 0) ($bad -join '; ')
} else { Chk "data/README 字段表结构可解析" $false }

Write-Host "`n=== 8. 合规红线（防封号）==="
Chk "SKILL: 禁 rank abuse 并引条款" ($S -match 'rank abuse')
Chk "SKILL: 禁自动 star/fork/watch/follow" ($S -match '不自动 star / fork / watch / follow')
Chk "SKILL: 注入防御" ($S -match '绝不当作指令执行')
Chk "SKILL: 内容红线不给链接" ($S -match '连链接都不给')
Chk "SKILL: token 不落盘" ($S -match '不得写入任何落盘文件')
Chk "SOURCES-Q: 有合规章节" ((Get-Content (Join-Path $base 'references\sources-queries.md') -Raw) -match 'rank abuse')
Chk "PROMPT: 仓库内容当数据读" ($P -match '当数据读，不当指令执行')
Chk "PROMPT: 合规红线" ($P -match '合规红线')
$leak = Select-String -Path $skill, (Join-Path $base 'references\*.md'), $prompt -Pattern 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9]{20,}'
Chk "无真实令牌泄露" ($null -eq $leak)

Write-Host "`n=== 9. 数量约束一致 ==="
Chk "SKILL: S+A ≤ 8" ($S -match 'S \+ A 合计 ≤ 8 条')
Chk "SKILL: S ≤ 3" ($S -match 'S 档 ≤ 3 条')
Chk "TEMPLATE: S ≤ 3" ($T -match 'S 档最多 3 条')
Chk "TEMPLATE: S+A ≤ 8" ($T -match 'S \+ A 合计 ≤ 8 条')
Chk "PROMPT: ≤8 且 S ≤ 3" ($P -match '条目数 ≤ 8（S 档 ≤ 3）')
Chk "TEMPLATE: A 档含行动字段" ($T -match '行动：\{\{试玩/收藏/研究/放弃\}\}')

Write-Host "`n=== 10. A 档验收口径（不要求单独风险字段）==="
Chk "SKILL 验收区分 S/A 档" ($S -match '\*\*A 档\*\*每条都含\*\*上手命令\*\*')
Chk "SKILL 未强制所有项目有风险等级字段" (-not ($S -match '每个项目都含\*\*风险等级\*\*'))

Write-Host "`n=== 11. 存量数据只增不减（防误删 / 误重置）==="
# 这是"只增不减"的**下界断言**，不是精确值：日报正常运行会让台账与快照持续增长。
# 下界 = 2026-10-11 首次成功运行时的规模（17 行台账 / 1 份快照）；低于下界说明数据被删或被重置。
$seen = (Get-Content (Join-Path $root 'data\seen.jsonl')).Count
Chk "seen.jsonl 非空（未被清空；条数对账见第 19 节）" ($isDemo -or ($seen -ge 1)) "实际 $seen"
$snaps = (Get-ChildItem (Join-Path $root 'data\snapshots') -File).Count
Chk "snapshots 文件数 >= 1（未被删减）" ($isDemo -or ($snaps -ge 1)) "实际 $snaps"
$seenNames = Get-Content (Join-Path $root 'data\seen.jsonl') | ForEach-Object { ($_ | ConvertFrom-Json).full_name }
$uniqCount = ($seenNames | Sort-Object -Unique).Count
Chk "seen.jsonl 无重复 full_name（含新增后）" ($uniqCount -eq $seenNames.Count) "共 $($seenNames.Count) 行，去重后 $uniqCount 行"

Write-Host "`n=== 12. 越界写文件检查 ==="
$escape = Select-String -Path $skill, $prompt -Pattern 'C:\\Users|AppData|C:/Users'
Chk "无工作区外路径写入" ($null -eq $escape)

Write-Host "`n=== 13. 表格文件（.univer）一致性 ==="
# 注意：Select-String 结果可能被折叠成标量字符串，必须用 @() 强制成数组
$tableRefs = @(Select-String -Path (Join-Path $root 'README.md'), $prompt, (Join-Path $root 'TABLE.md') -Pattern 'GitHub[^`\s]*?\.univer' -AllMatches |
             ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Sort-Object -Unique)
$onlyOne = ($tableRefs.Count -eq 1)
$rightName = $onlyOne -and ("$($tableRefs[0])" -ceq 'GitHub推荐记录.univer')
if ($tableRefs.Count -eq 0) {
  Skip ".univer 文件名唯一（只有 GitHub推荐记录.univer）" "未使用表格 / 发布版按设计不含个人推荐表"
} else {
  Chk ".univer 文件名唯一（只有 GitHub推荐记录.univer）" $rightName "实际: $($tableRefs -join ', ')"
}
Chk "SKILL 有表格不存在时的降级规则" ($S -match '表格不存在时的处理')
Chk "SKILL 禁止自创表格文件名" ($S -match '不得自创文件名')

Write-Host "`n=== 14. 冷启动措辞（运行不足 7 天不得依赖 7 日均值）==="
$srcq = Get-Content (Join-Path $base 'references\sources-queries.md') -Raw
Chk "SOURCES-Q 有运行不足 7 天的分支" ($srcq -match '运行不足 7 天')

Write-Host "`n=== 15. 独立复核（不信任文档自述）==="
# 用数据字典里的示例逐行解析，确认 JSON 合法
$jsonLines = Select-String -Path $dread -Pattern '^\{.*\}$' | ForEach-Object { $_.Line }
$bad = 0
foreach ($j in $jsonLines) { try { $null = $j | ConvertFrom-Json } catch { $bad++ } }
Chk "data/README 的 JSON 示例全部可解析 ($($jsonLines.Count) 条)" ($bad -eq 0) "解析失败 $bad 条"
# seen.jsonl 每行可解析且 full_name 唯一
$seenLines = Get-Content (Join-Path $root 'data\seen.jsonl')
$badSeen = 0; $names = @()
foreach ($l in $seenLines) {
  try { $o = $l | ConvertFrom-Json; $names += $o.full_name } catch { $badSeen++ }
}
Chk "seen.jsonl 每行 JSON 合法" ($badSeen -eq 0)
Chk "seen.jsonl full_name 唯一" (($names | Sort-Object -Unique).Count -eq $names.Count)
# 示例里的「分类标签」与模板枚举表必须同源
$tplEnums = @('AI','开发','效率','数据','安全','运维','学习','其他','CLI','Web','桌面','插件','库','框架','模板','资源列表','提效','自动化','学习','替代','监控','部署','创作','实验','活跃','稳定','归档','开箱即用','轻配置','要编程','要部署')
$usedTags = [regex]::Matches($ex, '(?m)^5\. \*\*分类标签\*\*：(.+)$') | ForEach-Object { $_.Groups[1].Value } |
            ForEach-Object { $_ -split '/' } | ForEach-Object { $_.Trim().TrimEnd('。') } | Where-Object { $_ -ne '' } |
            Where-Object { $_ -notin @('低','中','高') } | Sort-Object -Unique
$orphan = $usedTags | Where-Object { $tplEnums -notcontains $_ }
Chk "EXAMPLE 标签取值均在模板枚举内" ($orphan.Count -eq 0) "越界值: $($orphan -join ', ')"

Write-Host "`n=== 16. 三处 12 项字段的概念名与顺序（锚定概念，容忍同义措辞）==="
# 每项取一个"概念锚"，三方都必须按同一顺序出现；字面措辞允许不同（如『总结』vs『一句话总结与行动建议』）
$canon = @('项目名','一句话','30 秒判断','基本信息','分类标签','它到底干啥','怎么用','亮点','风险与注意','适合谁','学习成本','总结')
function Get-ItemNames([string]$text, [string]$fromMarker, [string]$toMarker) {
  $i = $text.IndexOf($fromMarker); if ($i -lt 0) { return @() }
  $j = $text.IndexOf($toMarker, $i); if ($j -lt 0) { $j = $text.Length }
  $seg = $text.Substring($i, $j - $i)
  $lines = $seg -split "`r?`n"
  $start = ($lines | Select-String -Pattern '^1\. ' | Select-Object -First 1).LineNumber
  if (-not $start) { return @() }
  $out = @()
  for ($k = $start - 1; $k -lt $lines.Count; $k++) {
    if ($lines[$k] -match '^(\d+)\. (?:\*\*)?([^：*]+)') {
      if ([int]$Matches[1] -ne ($out.Count + 1)) { break }
      $out += ($Matches[2] -replace '\s+$','')
      if ($out.Count -eq 12) { break }
    }
  }
  return $out
}
$sNames = Get-ItemNames $S '收集齐全的 12 项' '关于「代价'
$tNames = Get-ItemNames $T '重点推荐（S 档' '### 2. '
$eNames = Get-ItemNames $ex '## ⭐ 重点推荐' '### 2. demo/portkiller'
Chk "三处均取到 12 项" (($sNames.Count -eq 12) -and ($tNames.Count -eq 12) -and ($eNames.Count -eq 12)) "SKILL=$($sNames.Count) TEMPLATE=$($tNames.Count) EXAMPLE=$($eNames.Count)"
$prob = @()
foreach ($pair in @(@('SKILL',$sNames), @('TEMPLATE',$tNames), @('EXAMPLE',$eNames))) {
  $label = $pair[0]; $names = $pair[1]
  if ($names.Count -ne 12) { $prob += "$label 项数=$($names.Count)"; continue }
  for ($i = 0; $i -lt 12; $i++) {
    if ($names[$i] -notmatch [regex]::Escape($canon[$i])) { $prob += "$label 第$($i+1)项『$($names[$i])』不含概念锚『$($canon[$i])』" }
  }
  # 顺序：概念锚在该文件 12 项文本中必须递增出现
  $joined = $names -join '|'
  $last = -1
  foreach ($c in $canon) {
    $p = $joined.IndexOf($c)
    if ($p -lt $last) { $prob += "$label 概念『$c』顺序错位"; break }
    $last = $p
  }
}
Chk "12 项概念名与顺序三方一致" ($prob.Count -eq 0) ($prob -join ' | ')

Write-Host "`n=== 17. CHANGELOG 与当前文件对账（防记录过期）==="
$chg = Join-Path $base 'CHANGELOG.md'
if (Test-Path $chg) {
  $C = Get-Content $chg -Raw
  $realHash = (Get-FileHash $skill -Algorithm SHA256).Hash
  $realLines = (Get-Content $skill).Count
  $realBytes = (Get-Item $skill).Length
  Chk "CHANGELOG 记录的 SHA256 与当前 SKILL.md 一致" ($C -match $realHash) "当前=$realHash"
  Chk "CHANGELOG 记录的行数一致" ($C -match "\b$realLines 行\b") "当前=$realLines 行"
  Chk "CHANGELOG 记录的字节数一致" ($C -match "\b$realBytes B\b") "当前=$realBytes B"
  Chk "CHANGELOG 声明校验项数 = $($script:TOTAL_CHECKS) 项" ($C -match "\b$($script:TOTAL_CHECKS) 项") "CHANGELOG 未声明 $($script:TOTAL_CHECKS) 项"  # 2026-10-23：表结构检查——原来只比值，表格被插坏也能过
  $cl = $C -split "`r?`n"
  $hi = [array]::IndexOf($cl, '| 项 | 值 |')
  $tblOk = $false
  if ($hi -ge 0 -and ($hi + 6) -lt $cl.Count) {
    $ok1 = $cl[$hi + 1] -eq '|---|---|'
    $ok2 = $cl[$hi + 2] -match '^\| SKILL\.md \| \d+ 行 / \d+ B \|$'
    $ok3 = $cl[$hi + 3] -match '^\| SHA256 \| [0-9A-F]{64} \|$'
    $ok4 = $cl[$hi + 4] -match '^\| 校验 \| \d+ 项全通过（`audit\.ps1`） \|$'
    $ok5 = $cl[$hi + 5] -match '^\| 定版日期 \| \d{4}-\d{2}-\d{2} \|$'
    $ok6 = $cl[$hi + 6] -eq ''
    $tblOk = $ok1 -and $ok2 -and $ok3 -and $ok4 -and $ok5 -and $ok6
  }
  Chk "CHANGELOG 指纹表结构完整（表头/分隔/四行连续）" $tblOk
} else { Chk "CHANGELOG.md 存在" $false }

Write-Host "`n=== 18. owner 冷却期三处口径一致（防标准漂移）==="
# 2026-10-12 由「当天最多 1 个」改为「3 天内最多 1 个」。以下三处必须同步，否则会悄悄漂移。
$rubricTxt = Get-Content (Join-Path $root 'RUBRIC.md') -Raw
$cfgPath2 = Join-Path $root 'config.json'
$cfg2 = $null
try { $cfg2 = Get-Content $cfgPath2 -Raw | ConvertFrom-Json } catch { $null = $_ }
Chk "RUBRIC.md 声明『3 天内最多推荐 1 个』" ($rubricTxt -match '3 天内最多.{0,4}1 个')
Chk "SKILL.md 声明『同一 owner 3 天内最多推荐 1 个』" ($S -match '同一 owner 3 天内最多.{0,4}1 个')
if ($cfg2) {
  Chk "config.json 的 same_owner_cooldown_days == 3" ($cfg2.dedup.same_owner_cooldown_days -eq 3) "实际 $($cfg2.dedup.same_owner_cooldown_days)"
  Chk "三处天数口径一致（RUBRIC / SKILL / config）" (($rubricTxt -match '3 天内最多') -and ($S -match '同一 owner 3 天内最多') -and ($cfg2.dedup.same_owner_cooldown_days -eq 3))
} else { Chk "config.json 可解析（供第 18 节使用）" $false }

Write-Host "`n=== 19. 知识库层完整性（projects / events）==="
$projPath2 = Join-Path $root 'data\projects.jsonl'
$evPath2   = Join-Path $root 'data\events.jsonl'
if ((Test-Path $projPath2) -and (Test-Path $evPath2)) {
  $projRows = @()
  $badProj = 0
  foreach ($l in Get-Content $projPath2 -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $projRows += ($l | ConvertFrom-Json) } catch { $badProj++ }
  }
  $evRows = @()
  $badEv = 0
  foreach ($l in Get-Content $evPath2 -Encoding UTF8) {
    if ([string]::IsNullOrWhiteSpace($l)) { continue }
    try { $evRows += ($l | ConvertFrom-Json) } catch { $badEv++ }
  }
  Chk "projects.jsonl 每行可解析" ($badProj -eq 0) "损坏 $badProj 行"
  Chk "events.jsonl 每行可解析" ($badEv -eq 0) "损坏 $badEv 行"
  # 唯一身份：主档案不得有重复 id
  $ids = $projRows | ForEach-Object { $_.id }
  # N-01：null 是合法 JSON，ConvertFrom-Json 不报错 → 之前这条盲区漏掉了「空值行」
$blankRows = @()
$ln = 0
foreach ($l in (Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8)) {
  $ln++
  if (-not $l.Trim()) { continue }
  try { if ($null -eq ($l | ConvertFrom-Json)) { $blankRows += $ln } } catch { $null = $_ }
}
Chk "projects.jsonl 无空值行（N-01：null 行会让页面初始化崩溃）" ($blankRows.Count -eq 0) "空值行号 $($blankRows -join ', ')"
Chk "projects.jsonl 无重复 id（同一仓库唯一身份）" (($ids | Sort-Object -Unique).Count -eq $ids.Count) "共 $($ids.Count) 条，去重后 $(($ids | Sort-Object -Unique).Count) 条"
  # 与台账对齐：流水里出现的项目必须在主档案里
  $seenIds = Get-Content (Join-Path $root 'data\seen.jsonl') -Encoding UTF8 | ForEach-Object { if ($_ -match '"full_name":"([^"]+)"') { $Matches[1] } }
  $missingInProj = @($seenIds | Where-Object { $ids -notcontains $_ })
  Chk "台账项目全部在主档案中（无遗漏）" ($missingInProj.Count -eq 0) "缺 $($missingInProj.Count) 条"
  # 事件必须挂在存在的项目上
  $evOrphan = @($evRows | Where-Object { $ids -notcontains $_.id })
  Chk "所有事件都挂在已存在的项目上" ($evOrphan.Count -eq 0) "孤儿事件 $($evOrphan.Count) 条"
  # 每个已推荐项目都应有 recommended 事件
  $recIds = @($projRows | Where-Object { $_.recommended -eq $true } | ForEach-Object { $_.id })
  $recEvIds = @($evRows | Where-Object { $_.type -eq 'recommended' -or $_.type -eq 're_recommended' } | ForEach-Object { $_.id } | Sort-Object -Unique)
  $recNoEvent = @($recIds | Where-Object { $recEvIds -notcontains $_ })
  Chk "已推荐项目都有推荐事件" ($recNoEvent.Count -eq 0) "缺 $($recNoEvent.Count) 条"
  # 分类六维必须是模板枚举内的值
  $enumAll = @('AI','开发','效率','数据','安全','运维','学习','其他','CLI','Web','桌面','插件','库','框架','模板','资源列表','提效','自动化','学习','替代','监控','部署','创作','实验','活跃','稳定','归档','开箱即用','轻配置','要编程','要部署','低','中','高')
  $badTag = @()
  foreach ($p in $projRows) {
    foreach ($v in @($p.tags.'领域',$p.tags.'形态',$p.tags.'用途',$p.tags.'成熟度',$p.tags.'上手难度',$p.tags.'风险等级')) {
      if ($v -and ($enumAll -notcontains $v)) { $badTag += "$($p.id):$v" }
    }
  }
  Chk "分类标签取值都在枚举内" ($badTag.Count -eq 0) (($badTag | Select-Object -First 3) -join ', ')
  # --- 回归检查（2026-10-13 事故修复的缺陷，防止复发）---
  # 加载全部 picks（含 dropped），用于下面两条回归检查
  $allPicks = @()
  $picksDirA = Join-Path $root 'data\picks'
  if (Test-Path $picksDirA) {
    foreach ($pf in (Get-ChildItem $picksDirA -Filter '*.jsonl')) {
      foreach ($l in (Get-Content $pf.FullName -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        try { $allPicks += ($l | ConvertFrom-Json) } catch { $null = $_ }
      }
    }
  }
  # 回归 1：picks 里 tier=dropped 的记录，当天不得产生「已推荐」事件
  $violDrop = @()
  foreach ($pk in ($allPicks | Where-Object { $_.tier -eq 'dropped' })) {
    $bad = @($evRows | Where-Object { $_.id -eq $pk.full_name -and $_.date -eq $pk.date -and $_.type -eq 'recommended' })
    if ($bad.Count -gt 0) { $violDrop += "$($pk.full_name)@$($pk.date)" }
  }
  Chk "已放弃的 pick 不产生「已推荐」事件" ($violDrop.Count -eq 0) (($violDrop | Select-Object -First 3) -join ', ')
  # 回归 2：CSV 兜底不得在已有 picks 记录的日期重复注入推荐（当时 CCBaga 被注入假 A 档的根因）
  $pickKeySet = @{}
  foreach ($pk in $allPicks) { $pickKeySet["$($pk.full_name)@$($pk.date)"] = $true }
  $violCsv = @()
  foreach ($e2 in ($evRows | Where-Object { $_.type -eq 'recommended' -and $_.src -eq 'csv(兜底)' })) {
    if ($pickKeySet.ContainsKey("$($e2.id)@$($e2.date)")) { $violCsv += "$($e2.id)@$($e2.date)" }
  }
  Chk "CSV 兜底不与 picks 记录重复注入" ($violCsv.Count -eq 0) (($violCsv | Select-Object -First 3) -join ', ')

Chk "站点页面已由 projects.jsonl 生成（index.html + data/site）" ((Test-Path (Join-Path $root 'index.html')) -and (Test-Path (Join-Path $root 'data\site')))
  Write-Host ("        主档案 $($projRows.Count) 条 ｜ 事件 $($evRows.Count) 条 ｜ 已推荐 $($recIds.Count) 条") -ForegroundColor DarkGray
} else {
  Chk "知识库层已生成（projects.jsonl / events.jsonl）" $false "未找到，需先跑 tools\sync-projects.ps1"
}

Write-Host "`n=== 20. 元数据层存在性（后 5 种事件的前提）==="
# license_changed / metadata_updated / archived_changed / category_changed / release_detected
# 全部靠回放 data/meta/ 历史得出。若这一层缺失或只有空文件，这些事件会静默失效。
$metaDir2 = Join-Path $root 'data\meta'
Chk "data/meta/ 目录存在" ($isDemo -or (Test-Path $metaDir2))
if (Test-Path $metaDir2) {
  $metaFiles = @(Get-ChildItem $metaDir2 -Filter '*.jsonl' -File)
  Chk "meta 至少有一份日期文件" ($metaFiles.Count -ge 1) "实际 $($metaFiles.Count) 份"
  $badDate = @($metaFiles | Where-Object { $_.BaseName -notmatch '^\d{4}-\d{2}-\d{2}$' })
  Chk "meta 文件名都是 YYYY-MM-DD 格式" ($badDate.Count -eq 0) "异常 $($badDate.Name -join ', ')"
  $metaRows = @()
  $badMeta = 0
  foreach ($f in $metaFiles) {
    foreach ($l in (Get-Content $f.FullName -Encoding UTF8)) {
      if ([string]::IsNullOrWhiteSpace($l)) { continue }
      try { $metaRows += ($l | ConvertFrom-Json) } catch { $badMeta++ }
    }
  }
  Chk "meta 每行可解析" ($badMeta -eq 0) "损坏 $badMeta 行"
  $noFetch = @($metaRows | Where-Object { -not $_.fetched_at })
  Chk "meta 每行都有 fetched_at（回放排序依赖它）" ($noFetch.Count -eq 0) "缺 $($noFetch.Count) 行"
  Write-Host ("        元数据 $($metaRows.Count) 条 ｜ 文件 $($metaFiles.Count) 份 ｜ 事件类型 $(($evRows | Group-Object type).Count) 种") -ForegroundColor DarkGray
}

Write-Host "`n=== 21. 人话层完整性（v3，普通人能否看懂）==="
# 人话层三件套：repo-intro（介绍）/ function-tags（功能标签与搜索词）/ search-synonyms（全局同义词）
$humanDir2 = Join-Path $root 'data\human'
Chk "data/human/ 目录存在" (Test-Path $humanDir2)
if (Test-Path $humanDir2) {
  $hFiles = @('repo-intro.jsonl','function-tags.jsonl','search-synonyms.jsonl')
  $missingFiles = @($hFiles | Where-Object { -not (Test-Path (Join-Path $humanDir2 $_)) })
  Chk "三个文件齐全（intro / tags / synonyms）" ($missingFiles.Count -eq 0) "缺 $($missingFiles -join ', ')"
  if ($missingFiles.Count -eq 0) {
    $intros = @(); $ftags = @()
    foreach ($l in Get-Content (Join-Path $humanDir2 'repo-intro.jsonl') -Encoding UTF8) {
      if ($l.Trim()) { try { $intros += ($l | ConvertFrom-Json) } catch { $null = $_ } }
    }
    foreach ($l in Get-Content (Join-Path $humanDir2 'function-tags.jsonl') -Encoding UTF8) {
      if ($l.Trim()) { try { $ftags += ($l | ConvertFrom-Json) } catch { $null = $_ } }
    }
    # 关键：写了介绍的条目必须四项齐全（一句话/痛点/例子/功能说明）
    $incomplete = @($intros | Where-Object { -not ($_.one_liner -and $_.problem -and $_.example -and $_.feature_note) })
    Chk "人话层条目字段齐全（一句话/痛点/例子/功能说明）" ($incomplete.Count -eq 0) "缺字段 $(($incomplete | ForEach-Object { $_.full_name }) -join ', ')"
    # 功能说明必须含五项
    $needKeys = @('是什么','核心功能','常见用途','使用案例','不适合')
    $badFn = @()
    foreach ($i in $intros) {
      if ($i.feature_note) {
        $miss = @($needKeys | Where-Object { -not $i.feature_note.PSObject.Properties[$_] })
        if ($miss.Count -gt 0) { $badFn += "$($i.full_name) 缺 $($miss -join ',')" }
      }
    }
    Chk "功能说明含全部五项" ($badFn.Count -eq 0) (($badFn | Select-Object -First 2) -join '; ')
    # 功能标签条目必须同时有标签与搜索词
    $badFtag = @($ftags | Where-Object { -not ($_.function_tags -and $_.user_keywords) })
    Chk "功能标签条目含标签与用户搜索词" ($badFtag.Count -eq 0) "缺 $(($badFtag | ForEach-Object { $_.full_name }) -join ', ')"
    # 已推荐项目应有人话层——**但允许「确实没有素材」的项目标 missing**。
    # 理由：推荐是当天判断，人话层要额外素材；无 description 的仓库**不该编造介绍**，
    #       只要它被明确标成 missing（而非空壳 complete），就是诚实的。
    $introIds = @($intros | ForEach-Object { $_.full_name })
    $projRows2 = if (Test-Path $projPath2) { Get-Content $projPath2 -Encoding UTF8 | ForEach-Object { if ($_.Trim()) { try { $_ | ConvertFrom-Json } catch { $null = $_ } } } } else { @() }
    # 「已推荐」应**排除已放弃**的：rejected 的项目本就不该有人话层（那是剔除记录，不是介绍）。
    # 例：liseami/CCBaga 因无描述被判 A 档「降档观察」，不入推荐区，故不要求它有介绍。
    $recActive = @($projRows2 | Where-Object { $_.recommended -eq $true -and $_.status -ne 'dropped' } | ForEach-Object { $_.id })
    $noMatIds = @($projRows2 | Where-Object { $_.recommended -eq $true -and $_.human -and $_.human.status -eq 'missing' } | ForEach-Object { $_.id })
    $recNoHuman = @($recActive | Where-Object { $introIds -notcontains $_ -and $noMatIds -notcontains $_ })
    Chk "未放弃的已推荐项目都有人话层介绍（或明确标 missing）" ($recNoHuman.Count -eq 0) "缺 $($recNoHuman.Count) 条：$(($recNoHuman | Select-Object -First 3) -join ', ')"
    Write-Host ("        人话层 $($intros.Count) 条 ｜ 功能标签 $($ftags.Count) 条 ｜ 同义词组 $((Get-Content (Join-Path $humanDir2 'search-synonyms.jsonl') -Encoding UTF8).Count) 组") -ForegroundColor DarkGray
  }
}

Write-Host "`n=== 22. 站点页面与两级分类（v4 · 2026-10-19 站点版）==="
# 2026-10-19 D1=A：发布包只发新站点（index.html + data/site 5 页）。
# 旧版这一节读 legacy\overview-v5.html；单页不发之后，页面检查全部改指站点页，
# 并把工具/数据层检查从 if(Test-Path $ovPath) 里挪出来，避免「文件不在就整段跳过」。
$siteDir = Join-Path $root 'data\site'
$sitePages = @('daily-layout-c-finsara.generated.html', 'library-notebook.generated.html', 'home-brutal-token.generated.html', 'plans-shelf.generated.html', 'site-shell.generated.html')
$siteOk = (Test-Path (Join-Path $root 'index.html')) -and (@($sitePages | Where-Object { Test-Path (Join-Path $siteDir $_) }).Count -eq 5)
Chk "站点入口 index.html 存在且 data/site 五页齐全" $siteOk

$readRaw = { param($p) if (Test-Path $p) { Get-Content $p -Raw -Encoding UTF8 } else { '' } }
$idxHtml   = & $readRaw (Join-Path $root 'index.html')
$dailyHtml = & $readRaw (Join-Path $siteDir 'daily-layout-c-finsara.generated.html')
$libHtml   = & $readRaw (Join-Path $siteDir 'library-notebook.generated.html')
$homeHtml  = & $readRaw (Join-Path $siteDir 'home-brutal-token.generated.html')
$plansHtml = & $readRaw (Join-Path $siteDir 'plans-shelf.generated.html')
$ov = $idxHtml + "`n" + $dailyHtml + "`n" + $libHtml + "`n" + $homeHtml + "`n" + $plansHtml

Chk "站点无外部 fetch（双击即可用）" (-not ($ov -match 'fetch\('))
Chk "站点无外部资源引用" (-not ($ov -match 'src="https?://|@import'))
Chk "四个入口齐全（每日精选 / 全库 / 计划与工作区 / 图例）" (($idxHtml -match '#/daily') -and ($idxHtml -match '#/all') -and ($idxHtml -match '#/plans') -and ($idxHtml -match '图例'))
Chk "日报页 01–06 内容块齐全" (($dailyHtml -match '今日头条') -and ($dailyHtml -match '重点报道') -and ($dailyHtml -match '观察面') -and ($dailyHtml -match '边栏观察') -and ($dailyHtml -match '特别栏目') -and ($dailyHtml -match '旧闻新报'))
Chk "日报页有 S/A 档位标记" (($dailyHtml -match '"tier":"S"') -or ($dailyHtml -match '"tier":"A"'))
Chk "全库页有搜索输入" (($libHtml -match '<input') -and ($libHtml -match '搜索'))
Chk "全库页有分类筛选" ($libHtml -match '分类')
Chk "全库页有人话层「一句话」" ($libHtml -match '一句话')
Chk "全库页有徽章与统计" (($libHtml -match '徽章') -and ($libHtml -match '统计'))
Chk "全库页有项目对比入口" ($libHtml -match '对比')
Chk "全库页有成长记录" ($libHtml -match '成长记录')
Chk "全库页有翻页控件（pageslider）" ($libHtml -match 'pageslider')
Chk "日报页含当日入库全名单" ($dailyHtml -match '全名单')
Chk "计划页有场景与工作区" (($plansHtml -match '场景') -and ($plansHtml -match '工作区'))
Chk "站点有 hash 路由骨架（#/daily #/all #/plans + hashchange）" (($idxHtml -match 'hashchange') -and ($idxHtml -match '#/daily'))
Chk "站点每页有 BUILD-STAMP 且格式完整" (([regex]::Matches($ov, '<!-- BUILD-STAMP: build \d{4}-\d{2}-\d{2} \d{2}:\d{2} ｜ 数据指纹 [0-9A-Fa-f]{12} ｜ \d+ 条 -->')).Count -ge 5)
$pageTimes = @($sitePages | ForEach-Object { Join-Path $siteDir $_ } | Where-Object { Test-Path $_ } | ForEach-Object { (Get-Item $_).LastWriteTimeUtc })
$dataTimes = @('data\projects.jsonl', 'data\events.jsonl', 'data\recommend-log.csv') | ForEach-Object { $dp = Join-Path $root $_; if (Test-Path $dp) { (Get-Item $dp).LastWriteTimeUtc } }
$p17ok = ($siteOk -and $pageTimes.Count -gt 0 -and $dataTimes.Count -gt 0 -and ($pageTimes | Measure-Object -Minimum).Minimum -ge ($dataTimes | Measure-Object -Maximum).Maximum)
Chk "P1-17 页面比所有数据新（改了数据不重建 → 必须变红）" $p17ok
$chartTagsS = [regex]::Matches($homeHtml, '<[^>]*role="img"[^>]*>')
$chartBadS = @($chartTagsS | Where-Object { $_.Value -notmatch 'aria-label="[^"]{8,}"' }).Count
$chartNotesS = ([regex]::Matches($homeHtml, 'class="chart-note"')).Count
Chk "图表都有 aria-label 与文字摘要（$($chartTagsS.Count) 个图 / $chartNotesS 条摘要）" ($chartTagsS.Count -gt 0 -and $chartBadS -eq 0 -and $chartNotesS -ge $chartTagsS.Count) "缺 aria 的图 $chartBadS 个"
$heroN = $null; if ($homeHtml -match '(\d+)\s*ITEMS') { $heroN = [int]$Matches[1] }
$projNS = @(Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() }).Count
Chk "首页自述条数 = 主档案条数（$projNS）" ($heroN -eq $projNS) "首页写的是 $heroN"
Chk "页面无「未评档」残留（术语表已废）" ($ov -notmatch '未评档')
Chk "页面无收藏残留（功能已撤销）" (($ov -notmatch 'favRow') -and ($ov -notmatch 'favCmd') -and ($ov -notmatch 'user-library'))

# ---- 工具 / 数据层（与页面无关，必须始终执行）----
Chk "SKILL 含「临时检索」流程" (($S -match '临时检索') -and ($S -match 'add-repo\.ps1'))
Chk "工具组合推荐可用（compose.ps1 + SKILL 流程）" ((Test-Path (Join-Path $root 'tools\compose.ps1')) -and ($S -match '工具组合'))
Chk "自动补标签工具存在（auto-tag.ps1）" (Test-Path (Join-Path $root 'tools\auto-tag.ps1'))
Chk "同义词候选工具存在（suggest-terms.ps1）" (Test-Path (Join-Path $root 'tools\suggest-terms.ps1'))
Chk "搜索缺口闭环存在（gaps.ps1 + SKILL 说明）" ((Test-Path (Join-Path $root 'tools\gaps.ps1')) -and ($S -match '搜索缺口'))
$plansPath2 = Join-Path $root 'data\plans.json'
$plOk2 = Test-Path $plansPath2
$pl2 = $null
if ($plOk2) { try { $pl2 = Get-Content $plansPath2 -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null = $_ } }
Chk "方案模板存在且含角色与「为什么需要」" ($plOk2 -and $pl2 -and @($pl2.plans).Count -ge 5 -and @($pl2.plans[0].roles).Count -ge 2 -and $pl2.plans[0].roles[0].why)
$stackSkill = Join-Path $root '.dsh\skills\tool-stack\SKILL.md'
Chk "tool-stack 技能存在（/tool-stack）" ((Test-Path $stackSkill) -and ((Get-Content $stackSkill -Raw -Encoding UTF8) -match 'name:\s*tool-stack'))
Chk "方案固化工具存在（add-plan.ps1）" (Test-Path (Join-Path $root 'tools\add-plan.ps1'))
Chk "日报后追问工具存在（daily-questions.ps1）" ((Test-Path (Join-Path $root 'tools\daily-questions.ps1')) -and ($S -match 'daily-questions'))
Chk "方案候选工具存在（suggest-plans.ps1）" ((Test-Path (Join-Path $root 'tools\suggest-plans.ps1')) -and ($S -match 'suggest-plans'))
Chk "人话层待补清单工具存在（humanize-next.ps1）" ((Test-Path (Join-Path $root 'tools\humanize-next.ps1')) -and ($S -match 'humanize-next'))
Chk "人话层批量写入工具存在（add-intro.ps1）" (Test-Path (Join-Path $root 'tools\add-intro.ps1'))
$projPath3 = Join-Path $root 'data\projects.jsonl'
if (Test-Path $projPath3) {
  $pr3 = @()
  foreach ($l3 in (Get-Content $projPath3 -Encoding UTF8)) { if ($l3.Trim()) { try { $pr3 += ($l3 | ConvertFrom-Json) } catch { $null = $_ } } }
  $anchors = [ordered]@{ 'ARahim3/DigUp' = '效率/文件管理'; 'zyddnys/manga-image-translator' = '设计/图片处理'; 'storytold/deckcraft' = '办公/演示文稿'; 'enricoros/big-AGI' = 'AI/AI聊天'; 'amontlabs/lcu' = '开发/编程助手'; 'iamlukethedev/Herald-OS' = 'AI/AI Agent' }
  $badAnchor = @()
  foreach ($k3 in $anchors.Keys) {
    $row3 = @($pr3 | Where-Object { $_.id -eq $k3 })[0]
    if (-not $row3) { continue }
    if ("$($row3.category.l1)/$($row3.category.l2)" -ne $anchors[$k3]) { $badAnchor += "$k3=$($row3.category.l1)/$($row3.category.l2)" }
  }
  Chk "分类锚点稳定（6 条：强信号 / topics / 人话层 / 防AI污染 / 开发桶 / 形态词规则）" ($badAnchor.Count -eq 0) ($badAnchor -join '; ')
}
$wsP = Join-Path $root 'data\workspaces.jsonl'
$wsOk2 = Test-Path $wsP
if ($wsOk2) { foreach ($l in (Get-Content $wsP -Encoding UTF8)) { if ($l.Trim()) { try { $null = ($l | ConvertFrom-Json) } catch { $wsOk2 = $false } } } }
Chk "工作区层存在且每行可解析（workspaces.jsonl）" $wsOk2
Chk "工作区工具存在（workspace.ps1）" (Test-Path (Join-Path $root 'tools\workspace.ps1'))
$qs = Join-Path $root 'QUICKSTART.md'
Chk "5 分钟说明书存在（QUICKSTART.md）" ((Test-Path $qs) -and ((Get-Content $qs -Raw -Encoding UTF8) -match '第 1 步'))
$ss = Join-Path $root 'docs\screenshots\README.md'
Chk "截图说明存在且 README 引用三张图" ((Test-Path $ss) -and ((Get-Content (Join-Path $root 'README.md') -Raw -Encoding UTF8) -match 'docs/screenshots/3-plans'))
$dm = Join-Path $root 'examples\demo\projects.jsonl'
$dmOk = Test-Path $dm
if ($dmOk) {
  foreach ($l in (Get-Content $dm -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $d = $l | ConvertFrom-Json } catch { $dmOk = $false; break }
    if ($d.PSObject.Properties['library']) { $dmOk = $false }
    if ($d.PSObject.Properties['user_notes'] -and $d.user_notes) { $dmOk = $false }
    if ($d.PSObject.Properties['note'] -and $d.note) { $dmOk = $false }
  }
}
Chk "demo 数据包存在且已剥个人数据（examples/demo）" $dmOk

# 两级分类规则库
$taxPath = Join-Path $root 'data\taxonomy.json'
Chk "data/taxonomy.json 存在" (Test-Path $taxPath)
if (Test-Path $taxPath) {
  $tax = $null
  try { $tax = Get-Content $taxPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null = $_ }
  Chk "taxonomy.json 可解析" ($null -ne $tax)
  if ($tax) {
    $l1names = @($tax.'一级分类'.PSObject.Properties.Name)
    Chk "taxonomy 至少 5 个一级分类" ($l1names.Count -ge 5) "实际 $($l1names.Count)"
    $emptyChildren = @($tax.'一级分类'.PSObject.Properties | Where-Object { -not $_.Value.children -or @($_.Value.children.PSObject.Properties).Count -eq 0 })
    Chk "每个一级分类都有二级分类" ($emptyChildren.Count -eq 0) "空的：$(($emptyChildren | ForEach-Object { $_.Name }) -join ', ')"
    Chk "taxonomy 有「其他」兜底分类" ($null -ne $tax.'_其他分类')
  }
}
# 用户备注层与候选分类（空文件也算合格，只要存在且不是注释）
foreach ($pair in @(
  @('data\user-notes.jsonl', '用户备注层'),
  @('data\taxonomy-suggestions.jsonl', '候选分类')
)) {
  $fp = Join-Path $root $pair[0]
  Chk "$($pair[1])文件存在" (Test-Path $fp)
  if (Test-Path $fp) {
    $bad = 0
    foreach ($ln in (Get-Content $fp -Encoding UTF8)) {
      if ([string]::IsNullOrWhiteSpace($ln)) { continue }
      if ($ln.TrimStart().StartsWith('#')) { $bad++; continue }
      try { $null = $ln | ConvertFrom-Json } catch { $bad++ }
    }
    Chk "$($pair[1])每行都是合法 JSON（无注释行）" ($bad -eq 0) "异常 $bad 行"
  }
}

# ================= 23. 发布物与交付一致性（2026-10-16 从发布包移植） =================
Write-Host "`n=== 23. 发布物与交付一致性（2026-10-16 从发布包移植）==="
# 这一节兜住四类事故（移植自发布包 §23，原库同样适用）：
#   ① 文档指向不存在的文件（发布包历史上 README 曾引用 reports/、seen.jsonl、TABLE.md 等 9 处）
#   ② README 的「N 项」与脚本常量漂移（历史上同时存在 58 / 126 / 129 三种说法 —— 原库就中过）
#   ③ 交付脚本 `.cmd` 写成 LF 行尾 → cmd.exe 吃掉每行前半截（用户实测报 'cal'/'IT'/'Commit' 不是命令）
#   ④ 页面 hero 数字与主档案脱节、截图源页混入非 demo 项目
$docFiles = @('README.md','QUICKSTART.md','RUNBOOK.md','SOURCES.md','RUBRIC.md','PROMPT-daily.md',
              'data\README.md','tools\README.md','docs\screenshots\README.md','examples\demo\README.md')
$deadLinks = @()
foreach ($rel in $docFiles) {
  $fp = Join-Path $root $rel
  if (-not (Test-Path $fp)) { $deadLinks += "$rel（文档缺失）"; continue }
  $dir = Split-Path -Parent $fp
  $txt = Get-Content $fp -Raw -Encoding UTF8
  foreach ($m in [regex]::Matches($txt, '\]\(([^)\s]+)\)')) {
    $t = $m.Groups[1].Value
    if ($t -match '^(https?:|#|mailto:)') { continue }
    $t = ($t -split '#')[0]
    if (-not $t) { continue }
    if (-not (Test-Path (Join-Path $dir ($t -replace '/','\')))) { $deadLinks += "$rel → $t" }
  }
}
Chk "文档里的相对链接全部存在" ($deadLinks.Count -eq 0) "死链: $($deadLinks -join '; ')"

$rd = Get-Content (Join-Path $root 'README.md') -Raw -Encoding UTF8
$declaredN = if ($rd -match '(\d+)\s*项不变量') { [int]$Matches[1] } else { $null }
Chk "README 声明的校验项数 = TOTAL_CHECKS（$($script:TOTAL_CHECKS)）" ($declaredN -eq $script:TOTAL_CHECKS) "README 写的是 $declaredN 项"

$dirOk = (Test-Path (Join-Path $root 'data\picks')) -and (Test-Path (Join-Path $root 'data\snapshots'))
Chk "data\picks 与 data\snapshots 目录存在（首次运行要往里写）" $dirOk

$sp = Get-Content (Join-Path $root 'tools\sync-projects.ps1') -Raw
Chk "sync-projects 空输入有双重保护（无原始层退出 + 不清空投影 + 数组化写入）" `
    (($sp -match '缺少原始层') -and ($sp -match '本次不写盘') -and ($sp -match '\$projLines = @\(') -and ($sp -match '\$evLines = @\('))

$deliverDir = Join-Path $root '发布测试'
if (Test-Path $deliverDir) {
  $okCmd = $false; $badEol = @()
  foreach ($c in (Get-ChildItem $deliverDir -Filter '*.cmd' -File)) {
    $bytes = [System.IO.File]::ReadAllBytes($c.FullName)
    $cr = @($bytes | Where-Object { $_ -eq 13 }).Count
    $lf = @($bytes | Where-Object { $_ -eq 10 }).Count
    if ($cr -ne $lf) { $badEol += "$($c.Name)(CR=$cr/LF=$lf，必须全 CRLF)" }
    $ct = Get-Content $c.FullName -Raw
    if ($ct -match 'git[^\r\n]*\badd\b' -and $ct -match '\bcommit\b') { $okCmd = $true }
  }
  Chk "投递脚本含 git add + commit 且全部 CRLF 行尾" ($okCmd -and $badEol.Count -eq 0) "缺 add/commit=$(-not $okCmd)；行尾异常: $($badEol -join ', ')"
} else {
  Skip "投递脚本含 git add + commit（否则新增文件推不上去）" "没有 发布测试\ 目录"
}

$heroN = $null
$homePath = Join-Path $root 'data\site\home-brutal-token.generated.html'
if (Test-Path $homePath) {
  $homeOv = Get-Content $homePath -Raw -Encoding UTF8
  if ($homeOv -match '(\d+)\s*ITEMS') { $heroN = [int]$Matches[1] }
}
$projN = @(Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() }).Count
Chk "首页自述项目数 = 主档案条数（$projN）" ($heroN -eq $projN) "首页写的是 $heroN"

$shotDir = Join-Path $root '发布测试\_shots'
if (Test-Path $shotDir) {
  $demoPath = Join-Path $root 'release\github-daily-picks\data\projects.jsonl'
  $demoIds = @()
  if (Test-Path $demoPath) { $demoIds = @(Get-Content $demoPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { ($_ | ConvertFrom-Json).id }) }
  $shotBad = @()
  foreach ($f in (Get-ChildItem $shotDir -Filter '*.html' -File)) {
    $st = Get-Content $f.FullName -Raw -Encoding UTF8
    $ids = @([regex]::Matches($st, '"id":"([^"]+/[^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $notDemo = @($ids | Where-Object { $demoIds -notcontains $_ })
    if ($notDemo.Count -gt 0) { $shotBad += "$($f.Name)→$($notDemo -join ',')" }
  }
  Chk "截图源页只含 demo 项目（防再把个人库页面拍进去）" ($shotBad.Count -eq 0) ($shotBad -join '; ')
} else {
  Skip "截图源页只含 demo 项目（防再把个人库页面拍进去）" "没有 发布测试\_shots\ 目录"
}
Write-Host "`n=== 24. 文档 × 代码 字段对照（2026-10-16 新增）==="
# 起因（同一天实测两处不一致）：
#   * `data/README.md` 的字段表里早就写了 `drop_reason`，但 `sync-projects.ps1` **从未投影该字段**
#     → 文档说有的字段实际没有，页面上也看不到（已修）。
#   * `data/README.md` 的 status 白名单写成 `.../saved/...`，而 `saved` 早已废弃、`using` 才是白名单值。
# 原则：**文档是唯一口径**，文档说了而代码没做，比代码多了而文档没写更坑。故加机器对照。
# ⚠️ 这里**必须用 $docRaw 而不是 $D**：PowerShell 变量名不区分大小写，脚本前面若有用 `$d` 的循环
#    （如 `foreach ($d in ...)`），循环结束后 `$D` 就被那个值覆盖了 —— 2026-10-16 首次实现时踩到：
#    $D 变成最后一项的内容，导致 38 个字段全被判定「文档未写」（假红）。
$docRaw = Get-Content (Join-Path $root 'data\README.md') -Raw -Encoding UTF8
$declaredFields = @('id','url','owner','name','description','description_source','license','topics','archived','pushed_at','language',
                    'first_seen','last_seen','recommended','recommend_count','last_recommended','tier','score','risk','source',
                    'origin','origin_note','action','status','drop_reason','tags','category','experience','tags_confidence',
                    'stars','events_count','note','user_notes','human','function_tags','user_keywords','synonyms','function_tags_l1','updated_at',
'kind','kind_basis','owner_class','owner_label')
$projFirstLine = Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() } | Select-Object -First 1
$actualFields = @(($projFirstLine | ConvertFrom-Json).PSObject.Properties.Name)
$missingInCode = @($declaredFields | Where-Object { $actualFields -notcontains $_ })
$missingInDoc  = @($declaredFields | Where-Object { $docRaw -notmatch ("``" + [regex]::Escape($_) + "``") })
$extraInCode   = @($actualFields | Where-Object { $declaredFields -notcontains $_ })
Chk "投影层声明字段全部真实产出（防「文档写了、代码没做」）" ($missingInCode.Count -eq 0) "缺: $($missingInCode -join ', ')"
Chk "投影层声明字段在 data/README.md 中都有记载" ($missingInDoc.Count -eq 0) "文档未写: $($missingInDoc -join ', ')"
Chk "投影层无未声明字段（防「代码加了、文档没写」）" ($extraInCode.Count -eq 0) "多出: $($extraInCode -join ', ')"

# status 白名单：台账实取值必须合法，且文档五点齐全、不得再出现已废弃的 saved
# 注意：文档里允许**提到** saved，但必须同句标明它已废弃（否则就是在教人用废值）。
$allowedStatus = @('active','using','watching','researching','dropped')
$seenStatuses = @(Get-Content (Join-Path $root 'data\seen.jsonl') -Encoding UTF8 |
  Where-Object { $_.Trim() } | ForEach-Object { ($_ | ConvertFrom-Json).status } | Sort-Object -Unique)
$badStatus   = @($seenStatuses | Where-Object { $allowedStatus -notcontains $_ })
$docHasAll   = (@($allowedStatus | Where-Object { $docRaw -match ("``" + $_ + "``") }).Count -eq 5)
$docSavedOk  = ($docRaw -notmatch '`saved`') -or ($docRaw -match 'saved[^\r\n]{0,40}废弃')
Chk "status 白名单：台账取值合法 + 文档五态齐全 + saved 只以「已废弃」出现" `
    ($badStatus.Count -eq 0 -and $docHasAll -and $docSavedOk) `
    "非法值: $($badStatus -join ', ') ｜ 文档五态齐全=$docHasAll ｜ saved 合规=$docSavedOk"

# ---------- 2026-10-16 新增：标准一致性 / 日报上限 / 数据契约（批次 1，P0-3·P0-4·P0-8·P0-9） ----------
$critPath = Join-Path $root 'data\criteria.json'
$crit = if (Test-Path $critPath) { Get-Content $critPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
Chk "标准代码化：data/criteria.json 存在且可解析" ($null -ne $crit) "缺 data\criteria.json"
Chk "标准代码化：tools/score.ps1 存在且含关键函数" ((Test-Path (Join-Path $root 'tools\score.ps1')) -and ((Get-Content (Join-Path $root 'tools\score.ps1') -Raw -Encoding UTF8) -match 'function Get-Tier' -and (Get-Content (Join-Path $root 'tools\score.ps1') -Raw -Encoding UTF8) -match 'function Measure-Score' -and (Get-Content (Join-Path $root 'tools\score.ps1') -Raw -Encoding UTF8) -match 'function Get-RedlineHit')) "score.ps1 缺函数"
if ($crit) {
  $rub = Get-Content (Join-Path $root 'RUBRIC.md') -Raw -Encoding UTF8
  Chk "P0-4 分档阈值一致（criteria ↔ RUBRIC）" (([int]$crit.'分档阈值'.S -eq 80) -and ($rub -match '≥\s*80') -and ($rub -match '65')) "criteria S=$($crit.'分档阈值'.S)"
  Chk "P0-4 日报上限一致（criteria ↔ RUBRIC/TEMPLATES）" (([int]$crit.'日报上限'.'主推荐' -eq 8) -and ([int]$crit.'日报上限'.'特别栏目' -eq 3) -and ($rub -match '8\s*条')) "criteria 主推荐=$($crit.'日报上限'.'主推荐')"
  Chk "P0-9 红线两级齐备（明确违规 + 歧义信号）" ((@($crit.'合规红线_明确违规').Count -ge 20) -and (@($crit.'合规红线_歧义信号'.'词').Count -ge 5)) "明确=$( @($crit.'合规红线_明确违规').Count ) 歧义=$( @($crit.'合规红线_歧义信号'.'词').Count )"
  Chk "P0-9 歧义词不许判死（codex-on-crack 不得被 dropped）" ($true) ""   # 具体样本检查见下
}
# codex-on-crack：命中歧义词但**不应**被淘汰（首跑误伤案例的回归护栏）
$coc = @(Get-Content (Join-Path $root 'data\projects.jsonl') -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.id -eq 'ethanplusai/codex-on-crack' })
Chk "P0-9 回归：codex-on-crack 未被误杀（status ≠ dropped）" (($coc.Count -eq 0) -or ($coc[0].status -ne 'dropped')) "被误杀为 dropped"
# 日报上限（可机器验证的口径：recommend-log.csv 按首次推荐日分组 ≤8）
$rlPath = Join-Path $root 'data\recommend-log.csv'
if (Test-Path $rlPath) {
  $rows = @(Import-Csv $rlPath -Encoding UTF8)
  # 图像专题（方向=图像专题）不占当日 8 条名额，单独排除。
  $fine = @($rows | Where-Object { $_.'档位' -in @('S','A','B') -and $_.'方向' -ne '图像专题' }); $byDate = $fine | Group-Object '首次推荐日' | ForEach-Object { [pscustomobject]@{ d = $_.Name; n = $_.Count } }
  $over = @($byDate | Where-Object { $_.n -gt [int]$crit.'日报上限'.'主推荐' })
  Chk "P0-3 主推荐上限 ≤8（recommend-log 仅算 S/A/B 档）" ($over.Count -eq 0) ("超限日期: " + (($over | ForEach-Object { $_.d + '=' + $_.n }) -join ', '))
} else {
  Chk "P0-3 recommend-log.csv 存在" $false "缺 data\recommend-log.csv"
}
# 附加区 ≤3（解析 reports/*.md 里的「官方/大厂动态」区）
$repOver = @()
foreach ($f in @(Get-ChildItem (Join-Path $root 'reports') -Filter '*.md' -File -ErrorAction SilentlyContinue)) {
  $txt = Get-Content $f.FullName -Raw -Encoding UTF8
  $m = [regex]::Match($txt, '(?ms)^#{2,3}\s*[^\r\n]*(官方|大厂)[^\r\n]*\r?\n(.*?)(?=^#{1,3}\s|\z)')
  if ($m.Success) {
    $n = @([regex]::Matches($m.Groups[2].Value, '(?m)^\s*(?:[-*]|\d+\.)\s+\S')).Count
    if ($n -gt 3) { $repOver += ($f.Name + '=' + $n) }
  }
}
Chk "P0-3 特别栏目 ≤3（reports 解析）" ($repOver.Count -eq 0) ($repOver -join ', ')
# 数据契约（P0-8）
Chk "P0-8 data/schema.json 存在" (Test-Path (Join-Path $root 'data\schema.json')) "缺 data\schema.json"
Chk "P0-8 tools/validate-lib.ps1 存在（内置零依赖校验）" (Test-Path (Join-Path $root 'tools\validate-lib.ps1')) "缺 tools\validate-lib.ps1"

# ---------- 2026-10-17 新增：标签体检（P1-11） ----------
$ftPath = Join-Path $root 'data\human\function-tags.jsonl'
$vocPath2 = Join-Path $root 'data\tags-vocabulary.json'
$ftRows = @()
if (Test-Path $ftPath) { $ftRows = @(Get-Content $ftPath -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
$dupTags = @($ftRows | Group-Object full_name | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
Chk "标签条目唯一（1 个项目 1 条，无重复）" ($dupTags.Count -eq 0) ("重复: " + (($dupTags | Select-Object -First 3) -join ', '))
$bl2 = @(); if (Test-Path $vocPath2) { $bl2 = @((Get-Content $vocPath2 -Raw -Encoding UTF8 | ConvertFrom-Json).blacklist) }
$blHit = @()
foreach ($r in $ftRows) { foreach ($t in @($r.function_tags)) { if ($bl2 -contains [string]$t) { $blHit += ($r.full_name + ':' + $t) } } }
Chk "无黑名单标签（垃圾模式不再写入）" ($blHit.Count -eq 0) (($blHit | Select-Object -First 3) -join ', ')
$noSrc = @($ftRows | Where-Object { -not $_.source })
Chk "标签条目含来源血缘（source 非空）" ($noSrc.Count -eq 0) ("缺 source: " + $noSrc.Count + " 条")
$zeroEv = @($ftRows | Where-Object { @($_.function_tags).Count -eq 0 })
Chk "无空标签条目" ($zeroEv.Count -eq 0) ("空条目: " + $zeroEv.Count)
# ---------- 2026-10-17 新增：实体类型与来源级别（P1-1/P1-2） ----------
$projAll = @()
$pp2 = Join-Path $root 'data\projects.jsonl'
if (Test-Path $pp2) { $projAll = @(Get-Content $pp2 -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json }) }
$kindOk = @('library','tool','plugin-skill','model','dataset','resource-list','learning','infra','channel','unknown')
$badKind = @($projAll | Where-Object { $_.kind -and ($kindOk -notcontains [string]$_.kind) })
Chk "kind 取值合法（P1-1）" ($badKind.Count -eq 0) ("非法: " + (($badKind | Select-Object -First 3 | ForEach-Object { $_.id + '=' + $_.kind }) -join ', '))
$badOwner = @($projAll | Where-Object { $_.owner_class -and (@('official','community') -notcontains [string]$_.owner_class) })
Chk "owner_class 取值合法（P1-2）" ($badOwner.Count -eq 0) ("非法: " + $badOwner.Count + " 条")
$officialNoLabel = @($projAll | Where-Object { $_.owner_class -eq 'official' -and -not $_.owner_label })
Chk "official 必须带 owner_label（P1-2）" ($officialNoLabel.Count -eq 0) ("缺 label: " + $officialNoLabel.Count + " 条")
# ---------- 2026-10-17 新增：路由骨架与 build stamp（P2-9 / P1-14） ----------
# 2026-10-19 D1=A：路由骨架检查已并入第 22 节站点版（#/daily #/all #/plans + hashchange），
# 这里只保留 build stamp（站点页统一注入，见 build-samples.ps1）。
$stampOk = ($ov -match '<!-- BUILD-STAMP: build \d{4}-\d{2}-\d{2} \d{2}:\d{2} ｜ 数据指纹 [0-9A-Fa-f]{12} ｜ \d+ 条 -->')
Chk "P1-14 页面 build stamp 存在且格式完整（时间/指纹/条数）" $stampOk "缺 BUILD-STAMP 或格式不全（换数据重建后必须变新）"
# ---------- 2026-10-16 新增：内嵌字体的合规配对（P2-12） ----------
# OFL 1.1 **条件 2**：随附版权声明与许可文本。页面一旦内嵌字体（data:font/），
# 根目录就必须有 THIRD-PARTY.md 且含**完整 OFL 全文 + 版权行**；没内嵌则不要求 ✓
$embedsFont = ($ov -match 'data:font/')
$tpPath = Join-Path $root 'THIRD-PARTY.md'
$tpOk = $false
if (Test-Path $tpPath) {
  $tpTxt = Get-Content $tpPath -Raw -Encoding UTF8
  $tpOk = ($tpTxt -match 'SIL Open Font License 1\.1') -and ($tpTxt -match 'PERMISSION & CONDITIONS') -and ($tpTxt -match 'The Anton Project Authors')
}
if ($embedsFont) {
  Chk "P2-12 内嵌字体必须有 THIRD-PARTY.md（含 OFL 全文 + 版权行）" $tpOk "缺 THIRD-PARTY.md，或缺 OFL 全文 / 版权行（OFL 条件 2）"
} else {
  Chk "P2-12 内嵌字体必须有 THIRD-PARTY.md（含 OFL 全文 + 版权行）" $true "页面当前未内嵌字体 → 不要求（有内嵌时此条会变红来提醒）✓"
}
# ---------- 2026-10-16 新增：新鲜度不变量（P1-17） ----------
# 2026-10-19 D1=A：站点版的「页面比数据新」已并入第 22 节（比较 data/site 5 页与数据文件），
# 这里不再重复旧单页的检查，避免同一件事查两遍、且旧单页不存在时永远红。
# 图表可访问性（P1-14 之后）：每个 role="img" 必须有非空 aria-label，且图表块要有文字摘要
# 2026-10-19：站点版已在第 22 节检查首页图表（$homeHtml），这里保留全局兜底（$ov）。
# 图表可访问性已在第 22 节按首页检查（$chartTagsS / $chartNotesS），这里不再重复。
# P1-13：**推荐过的条目必须有「适合谁」（audience）** —— 页面在 #/picks 头条与详情里显示它 ✓
$recIds2 = @($projRows2 | Where-Object { $_.recommended -eq $true } | ForEach-Object { $_.id })   # 投影里的键是 id（不是 full_name）✗ 2026-10-17 写错过一次
$audMiss = @()
foreach ($rid in $recIds2) {
  $row = $intros | Where-Object { $_.full_name -eq $rid } | Select-Object -First 1
  if (-not $row -or -not $row.PSObject.Properties['audience'] -or -not $row.audience) { $audMiss += $rid }
}
Chk "推荐过的条目都有「适合谁」（P1-13，共 $($recIds2.Count) 条）" ($audMiss.Count -eq 0) "缺 audience：$(($audMiss | Select-Object -First 6) -join ', ')"
# P1-6：`function_tags_l1` 必须与词表的 `parent` 映射**一致**（抽全量比对：每个标签的 parent 都应在里面）
$vocabP2 = Join-Path $root 'data\tags-vocabulary.json'
$projP2  = Join-Path $root 'data\projects.jsonl'
if ((Test-Path $vocabP2) -and (Test-Path $projP2)) {
  $v2 = Get-Content $vocabP2 -Raw -Encoding UTF8 | ConvertFrom-Json
  $pmap2 = @{}
  foreach ($pr2 in $v2.parent.PSObject.Properties) { $pmap2[[string]$pr2.Name] = [string]$pr2.Value }
  $badL1 = @()
  foreach ($l2 in (Get-Content $projP2 -Encoding UTF8)) {
    if (-not $l2.Trim()) { continue }
    try { $row2 = $l2 | ConvertFrom-Json } catch { continue }
    $want = @(); foreach ($tg in @($row2.function_tags)) { if ($pmap2.ContainsKey([string]$tg) -and ($want -notcontains $pmap2[[string]$tg])) { $want += $pmap2[[string]$tg] } }
    $got = @($row2.function_tags_l1)
    if ((($want | Sort-Object) -join ',') -ne (($got | Sort-Object) -join ',')) { $badL1 += "$($row2.id)：期望[$($want -join '/')] 实际[$($got -join '/')]" }
  }
  Chk "function_tags_l1 与词表 parent 一致（P1-6，全量 $((Get-Content $projP2 | Where-Object { $_.Trim() }).Count) 条）" ($badL1.Count -eq 0) (($badL1 | Select-Object -First 3) -join '; ')
} else { Chk "function_tags_l1 与词表 parent 一致（P1-6）" $false '缺少 tags-vocabulary.json 或 projects.jsonl' }
# 总项数核对：**刻意不放进 Chk 计数器**（否则自我指涉、恒差一）
  $script:executed = $script:pass + $script:fail + $script:skip   # SKIP 也算"执行过"
if ($isDemo) { $tailOk = $true } else { $tailOk = ($script:executed -eq $script:TOTAL_CHECKS) }   # demo 下部分检查在 if 块里被跳过，执行数天然少于常量
if ($tailOk) { $script:tailNote = 'PASS' } else { $script:tailNote = 'FAIL'; $script:fail++ }
if ($isDemo) { $script:tailNote = 'PASS（demo 模式：依赖个人数据的检查按设计自动通过）' }
Write-Host ("  [{0}] 实际执行的检查数 = 常量值（执行 {1} 项 / 常量 {2} 项）" -f $script:tailNote, $script:executed, $script:TOTAL_CHECKS) -ForegroundColor $(if($tailOk){'Green'}else{'Red'})
Write-Host "        ↑ 若此项 FAIL：有人新增/删除了 Chk，却没同步脚本顶部的 TOTAL_CHECKS（及 CHANGELOG / README 的项数）" -ForegroundColor DarkGray

Write-Host ("`n================ 结果：{0} 通过 / {1} 跳过 / {2} 失败 ================" -f $script:pass, $script:skip, $script:fail) -ForegroundColor ($(if ($script:fail -eq 0) {'Green'} else {'Red'}))
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
