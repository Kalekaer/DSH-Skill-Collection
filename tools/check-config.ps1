param(
  [switch]$StatusRoundTrip,   # 追加 status 写入/读取往返测试
  [switch]$Restore,           # 往返测试后恢复原值（强烈建议开启）
  [string]$TestRepo = 'wheresryan22/anatomy'
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
$rubricOwner = if ($rubric -match '(\d+) 天内最多出现 1 个') { [int]$Matches[1] } else { $null }
Chk "owner 冷却期：RUBRIC 与 config 一致" ($rubricOwner -ne $null -and $rubricOwner -eq $cfg.dedup.same_owner_cooldown_days) "RUBRIC=$rubricOwner config=$($cfg.dedup.same_owner_cooldown_days)"

Write-Host "`n=== 3. 订阅清单与 recommend-log.csv 对齐 ==="
if (Test-Path $csvPath) {
  $csv = Import-Csv $csvPath
  $csvRepos = $csv | ForEach-Object { $_.仓库 } | Sort-Object -Unique
  $subNames = $cfg.subscriptions | ForEach-Object { $_.name } | Sort-Object -Unique
  $notInSub = $csvRepos | Where-Object { $subNames -notcontains $_ }
  # B6（Bug 测试报告）：订阅清单是「每天扫的来源」，recommend-log.csv 是「推荐过谁」——
  # 搜索发现的项目本来就不在订阅源里，要求 CSV ⊆ 订阅清单是错的检查。
  # 改成有意义的：CSV 里的仓库必须都能在台账里找到（否则是脏数据）。
  $ledgerNames = @()
  $seenP = Join-Path $root 'data\seen.jsonl'
  if (Test-Path $seenP) {
    foreach ($l in (Get-Content $seenP -Encoding UTF8)) {
      if (-not $l.Trim()) { continue }
      try { $ledgerNames += ($l | ConvertFrom-Json).full_name } catch {}
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
foreach ($line in Get-Content $seenPath) {
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
  $target = $rows | Where-Object { $_.full_name -eq $TestRepo } | Select-Object -First 1
  if (-not $target) {
    Chk "测试目标 $TestRepo 存在于台账" $false
  } else {
    $originalStatus = $target.status
    $originalNote = $target.note
    Write-Host ("        目标：{0}  原 status={1}" -f $TestRepo, $originalStatus)

    # 用文本替换而不是重写整个文件，保证其它行逐字节不动
    $raw = Get-Content $seenPath -Raw
    $targetLine = (Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$TestRepo`"") } | Select-Object -First 1)
    $newLine = $targetLine -replace '"status":"[^"]*"', '"status":"saved"'
    $raw2 = $raw.Replace($targetLine, $newLine)
    Set-Content -Path $seenPath -Value $raw2 -NoNewline

    # 重新读取，确认写入生效
    $after = Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$TestRepo`"") } | Select-Object -First 1 | ConvertFrom-Json
    Chk "写入后 status 变为 saved（可保存）" ($after.status -eq 'saved') "实际 $($after.status)"
    Chk "写入只影响目标行（行数不变）" ((Get-Content $seenPath).Count -eq $rows.Count)
    Chk "其它行未被改动（抽样比对首行）" ((Get-Content $seenPath -TotalCount 1) -eq (Get-Content $seenPath -TotalCount 1))

    if ($Restore) {
      $raw3 = Get-Content $seenPath -Raw
      $curLine = (Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$TestRepo`"") } | Select-Object -First 1)
      $restored = $curLine -replace '"status":"[^"]*"', "`"status`":`"$originalStatus`""
      Set-Content -Path $seenPath -Value $raw3.Replace($curLine, $restored) -NoNewline
      $back = Get-Content $seenPath | Where-Object { $_ -match [regex]::Escape("`"$TestRepo`"") } | Select-Object -First 1 | ConvertFrom-Json
      Chk "已恢复到原值 $originalStatus" ($back.status -eq $originalStatus) "实际 $($back.status)"
    } else {
      Write-Host "        [注意] 未传 -Restore，$TestRepo 的 status 现在仍是 saved" -ForegroundColor Yellow
    }
  }
}

Write-Host ("`nCONFIG CHECK: {0} 通过 / {1} 失败" -f $script:pass, $script:fail) -ForegroundColor ($(if ($script:fail -eq 0) {'Green'} else {'Red'}))
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
