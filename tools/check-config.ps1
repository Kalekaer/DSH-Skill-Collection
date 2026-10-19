param(
  [switch]$StatusRoundTrip,   # 追加 status 写入/读取往返测试
  [switch]$Restore,           # 往返测试后恢复原值（强烈建议开启）
  [string]$TestRepo = ''          # 留空 = 自动取台账首行（原默认值是个人库专属仓库，不属于发布包）
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cfgPath = Join-Path $root 'config.json'
$seenPath = Join-Path $root 'data\seen.jsonl'
# demo/发布版判据（Bug 测试报告 B5）：没有 seen.jsonl = 不是完整个人库 → 条目数类检查自动通过
$isDemo = -not (Test-Path (Join-Path $root 'data\seen.jsonl'))
$csvPath = Join-Path $root 'data\recommend-log.csv'

$script:pass = 0; $script:fail = 0
function Chk([string]$name, [bool]$ok, [string]$detail = '') {
  if ($ok) { $script:pass++; Write-Host ("  [PASS] {0}" -f $name) -ForegroundColor Green }
  else     { $script:fail++; Write-Host ("  [FAIL] {0} {1}" -f $name, $detail) -ForegroundColor Red }
}

Write-Host "`n=== 1. config.json 可解析且字段合法 ==="
$cfg = $null
try { $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json; Chk "config.json JSON 合法" $true }
catch { Chk "config.json JSON 合法" $false $_.Exception.Message }
if ($cfg) {
  Chk "output.daily_limit <= output.hard_max" ($cfg.output.daily_limit -le $cfg.output.hard_max) "daily=$($cfg.output.daily_limit) hard=$($cfg.output.hard_max)"
  Chk "output.s_tier_max <= hard_max" ($cfg.output.s_tier_max -le $cfg.output.hard_max)
  Chk "hard_max == 8（与 RUBRIC.md 一致）" ($cfg.output.hard_max -eq 8) "实际 $($cfg.output.hard_max)"
  Chk "s_tier_max == 3（与 SKILL.md 一致）" ($cfg.output.s_tier_max -eq 3) "实际 $($cfg.output.s_tier_max)"
  Chk "risk.max_allowed 是 低/中/高 之一" (@('低','中','高') -contains $cfg.risk.max_allowed)
  Chk "notify.channels 非空" ($cfg.notify.channels.Count -ge 1)
  $wd = $cfg.sources.topics_by_weekday
  $need = @('周一','周二','周三','周四','周五','周六','周日')
  $miss = $need | Where-Object { -not $wd.PSObject.Properties[$_] }
  Chk "topics_by_weekday 覆盖 7 天" ($miss.Count -eq 0) "缺 $($miss -join ',')"
}

Write-Host "`n=== 2. config.json 与 RUBRIC.md / SOURCES.md 不冲突 ==="
$rubric = Get-Content (Join-Path $root 'RUBRIC.md') -Raw
Chk "hard_max 与 RUBRIC 的『合计 8 条』一致" ($rubric -match '合计 8 条')
$sources = Get-Content (Join-Path $root 'SOURCES.md') -Raw
Chk "SOURCES.md 周一 topic 为 ai-agent" ($sources -match '\| 周一 \| `ai-agent`')
Chk "config 周一 topic 与 SOURCES.md 相同" ($cfg.sources.topics_by_weekday.'周一' -eq 'ai-agent')
$rubricOwner = if ($rubric -match '(\d+) 天内最多.{0,4}1 个') { [int]$Matches[1] } else { $null }
Chk "owner 冷却期：RUBRIC 与 config 一致" ($null -ne $rubricOwner -and $rubricOwner -eq $cfg.dedup.same_owner_cooldown_days) "RUBRIC=$rubricOwner config=$($cfg.dedup.same_owner_cooldown_days)"

Write-Host "`n=== 3. 订阅清单与 recommend-log.csv 对齐 ==="
if (Test-Path $csvPath) {
  $csv = Import-Csv $csvPath
  $csvRepos = $csv | ForEach-Object { $_.仓库 } | Sort-Object -Unique
  # B6（Bug 测试报告）：订阅清单是「每天扫的来源」，recommend-log.csv 是「推荐过谁」——
  # 搜索发现的项目本来就不在订阅源里，要求 CSV ⊆ 订阅清单是错的检查。
  # 改成有意义的：CSV 里的仓库必须都能在台账里找到（否则是脏数据）。
  $ledgerNames = @()
  $seenP = Join-Path $root 'data\seen.jsonl'
  if (Test-Path $seenP) {
    foreach ($l in (Get-Content $seenP -Encoding UTF8)) {
      if (-not $l.Trim()) { continue }
      try { $ledgerNames += ($l | ConvertFrom-Json).full_name } catch { $null = $_ }
    }
  }
  $csvNotInLedger = @($csvRepos | Where-Object { $ledgerNames -notcontains $_ })
  Chk "CSV 里的仓库都在台账中（订阅清单允许超出）" ($isDemo -or ($csvNotInLedger.Count -eq 0)) "缺 $($csvNotInLedger -join ', ')"
  $badUrl = $cfg.subscriptions | Where-Object { $_.url -notmatch '^https://github\.com/[^/]+/[^/]+$' }
  Chk "订阅 URL 格式合法" ($badUrl.Count -eq 0) "异常 $($badUrl.name -join ', ')"
}

Write-Host "`n=== 4. 台账读取与 status 合法性 ==="
$rows = @()
$badLines = 0
# demo / 发布版没有 data\seen.jsonl：先判存在再读，否则 Get-Content 会抛「找不到路径」红字（2026-10-14 修复）
$seenLinesRead = if (Test-Path $seenPath) { Get-Content $seenPath } else { @() }
foreach ($line in $seenLinesRead) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  try { $rows += ($line | ConvertFrom-Json) } catch { $badLines++ }
}
Chk "台账所有行可解析" ($badLines -eq 0) "损坏 $badLines 行"
Chk "台账非空（条数对账见第 3 节）" ($isDemo -or ($rows.Count -ge 1)) "实际 $($rows.Count)$([char]0x0020)"
$allowed = @('active','using','watching','researching','dropped')
$badStatus = $rows | Where-Object { $allowed -notcontains $_.status }
Chk "所有 status 在白名单内" ($badStatus.Count -eq 0) "越界 $(($badStatus | ForEach-Object { "$($_.full_name)=$($_.status)" }) -join ', ')"
$dist = $rows | Group-Object status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Host ("        分布：{0}" -f ($dist -join '  '))

if ($StatusRoundTrip) {
  Write-Host "`n=== 5. status 写入 / 读取往返测试（实测收藏状态可保存）==="
  # demo / 发布版没有 data\seen.jsonl → 往返测试**不适用**，明确跳过。
  # （2026-10-14 修复：旧行为在这里报 FAIL 并 exit 1，而 README 又让用户跑这条带 -StatusRoundTrip 的命令，
  #   等于官方命令在官方包上自带红灯；"不适用"与"真失败"必须分开。）
  if ($isDemo) {
    Write-Host "  [SKIP] status 往返测试 —— 本工作区没有 data\seen.jsonl（发布版 / demo 包），按设计跳过" -ForegroundColor DarkYellow
    $target = $null
  } else {
    $target = $rows | Where-Object { $_.full_name -eq $TestRepo } | Select-Object -First 1
    if (-not $target) {
      $target = $rows | Select-Object -First 1
      if ($target) { Write-Host ("        [提示] 目标 {0} 不在台账，改用台账首行 {1} 做往返测试" -f $TestRepo, $target.full_name) -ForegroundColor Yellow }
    }
  }
  if (-not $target -and -not $isDemo) {
    Write-Host "  [SKIP] status 往返测试 —— 台账为空，没有可测目标" -ForegroundColor DarkYellow
  } elseif ($target) {
    # 2026-10-15 修复：写盘/回读必须按**解析出来的** $target.full_name 找行，不能再用 -TestRepo。
    # 旧写法只在「-TestRepo 恰好就是台账里那一条」时成立；一旦走进"回退到台账首行"或 -TestRepo 留空，
    # 下面的正则就找不到目标行 → 写入与恢复全部失效（副本实测 3 项 FAIL）。
    $tName = $target.full_name
    $originalStatus = $target.status
    Write-Host ("        目标：{0}  原 status={1}" -f $tName, $originalStatus)

    # 用文本替换而不是重写整个文件，保证其它行逐字节不动
    $targetLine = (Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$tName`"") } | Select-Object -First 1)
    # 2026-10-15（GPT 评审）：写入前先留一份**完整快照**，写入后逐行比对"非目标行"。
    # 旧写法「其它行未被改动（抽样比对首行）」是**自己与自己比**，恒为真 —— 等于没有检查。
    $beforeLines = @(Get-Content $seenPath)
    $tIdx = -1
    for ($i = 0; $i -lt $beforeLines.Count; $i++) { if ($beforeLines[$i] -ceq $targetLine) { $tIdx = $i; break } }
    $raw = Get-Content $seenPath -Raw
    $newLine = $targetLine -replace '"status":"[^"]*"', '"status":"saved"'
    $raw2 = $raw.Replace($targetLine, $newLine)
    Set-Content -Path $seenPath -Value $raw2 -NoNewline

    # 重新读取，确认写入生效
    $afterLines = @(Get-Content $seenPath)
    $after = Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$tName`"") } | Select-Object -First 1 | ConvertFrom-Json
    Chk "写入后 status 变为 saved（可保存）" ($after.status -eq 'saved') "实际 $($after.status)"
    Chk "写入只影响目标行（行数不变）" ($afterLines.Count -eq $rows.Count)
    $changed = @()
    for ($i = 0; $i -lt $beforeLines.Count; $i++) {
      if ($i -eq $tIdx) { continue }   # 目标行允许变
      if ($i -ge $afterLines.Count -or $beforeLines[$i] -cne $afterLines[$i]) { $changed += ($i + 1) }
    }
    Chk "非目标行逐字节未变（$([Math]::Max(0, $beforeLines.Count - 1)) 行）" ($changed.Count -eq 0) ("被改动的行号: " + ($changed -join ', '))

    if ($Restore) {
      $raw3 = Get-Content $seenPath -Raw
      $curLine = (Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$tName`"") } | Select-Object -First 1)
      $restored = $curLine -replace '"status":"[^"]*"', "`"status`":`"$originalStatus`""
      Set-Content -Path $seenPath -Value $raw3.Replace($curLine, $restored) -NoNewline
      $afterLines2 = @(Get-Content $seenPath)
      $back = Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$tName`"") } | Select-Object -First 1 | ConvertFrom-Json
      Chk "已恢复到原值 $originalStatus" ($back.status -eq $originalStatus) "实际 $($back.status)"
      # 还原后必须与"测试前"逐行一致（整体比对，含目标行）
      $diff2 = @()
      for ($i = 0; $i -lt $beforeLines.Count; $i++) {
        if ($i -ge $afterLines2.Count -or $beforeLines[$i] -cne $afterLines2[$i]) { $diff2 += ($i + 1) }
      }
      Chk "还原后与测试前逐行一致（$($beforeLines.Count) 行）" ($diff2.Count -eq 0) ("有差异的行号: " + ($diff2 -join ', '))
    } else {
      Write-Host "        [注意] 未传 -Restore，$tName 的 status 现在仍是 saved" -ForegroundColor Yellow
    }
  }
}

Write-Host ("`nCONFIG CHECK: {0} 通过 / {1} 失败" -f $script:pass, $script:fail) -ForegroundColor ($(if ($script:fail -eq 0) {'Green'} else {'Red'}))

# P1-16：-StatusRoundTrip 会动 data\status-log.jsonl（页面输入之一）——**恢复原值后仍要重建**，
# 否则它的 mtime 变新而页面没变 → audit 的 P1-17 会（合理地）变红 ✗（$env:DSH_SKIP_REBUILD=1 可关）
if ($StatusRoundTrip -and $script:fail -eq 0) { & (Join-Path $root 'tools\rebuild-page.ps1') -Quiet }

if ($script:fail -gt 0) { exit 1 } else { exit 0 }
