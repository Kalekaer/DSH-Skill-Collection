# add-rows.ps1 — picks / recommend-log.csv 的唯一写入口（写入前判重 + 字段校验）
#
# 为什么需要它：append 型文件没有数据库唯一约束。append-guard 只能"写前问一句"，
#   忘了问就还是会写重复行。本脚本把「校验 → 判重 → 追加/刷新」放在同一次调用里：
#   - picks：唯一键 date+full_name（data/picks/<date>.jsonl）
#   - csv  ：唯一键 仓库（data/recommend-log.csv）
#
# 用法：
#   # rows.jsonl：一行一个 JSON 对象（picks 行的字段见 data/README.md；CSV 行用列名做键）
#   .\tools\add-rows.ps1 -Target picks -Date 2026-10-19 -From data\_tmp\picks-rows.jsonl
#   .\tools\add-rows.ps1 -Target picks -Date 2026-10-19 -From <rows> -Update   # 刷新同日旧行
#   .\tools\add-rows.ps1 -Target csv -From data\_tmp\csv-rows.jsonl -Update    # 刷新已有仓库
#   .\tools\add-rows.ps1 ... -DryRun -Json                                     # 只看计划，不写盘
#
# 退出码：0 = 已写入（或 dry-run 无冲突）｜1 = 拒绝（重复/字段非法）｜2 = 参数/文件错误

param(
  [Parameter(Mandatory)][ValidateSet('picks', 'csv')][string]$Target,
  [string]$Date = (Get-Date).ToString('yyyy-MM-dd'),
  [string]$From = '',
  [switch]$Update,
  [switch]$DryRun,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
function Fail([string]$msg, [int]$code = 2) {
  if ($Json) { [pscustomobject]@{ ok = $false; target = $Target; error = $msg } | ConvertTo-Json -Depth 4 }
  else { Write-Host "❌ $msg" -ForegroundColor Red }
  exit $code
}

if (-not $From) { Fail '缺少 -From（一行一个 JSON 的 rows 文件）' }
$fromPath = if ([IO.Path]::IsPathRooted($From)) { $From } else { P $From }
if (-not (Test-Path $fromPath)) { Fail "找不到 rows 文件：$From" }

$picksTier = @('S', 'A', 'B', 'C', 'D')
$riskVals = @('低', '中', '高')
$actionVals = @('试玩', '收藏', '研究', '放弃', '观察', '继续观察')
$dailyStatusVals = @('published', 'over_quota')
$quotaVals = @('s_cap', 'total_cap')
$csvTier = @('S', 'A', 'B', 'C', 'D')
$csvStatus = @('已推荐', '在用', '弃用', '观察', '已放弃')

# 读 rows（一行一个 JSON）
$rows = @()
$lineNo = 0
foreach ($line in ([IO.File]::ReadAllLines($fromPath, [Text.Encoding]::UTF8) | Where-Object { $_.Trim() })) {
  $lineNo++
  try { $rows += ($line | ConvertFrom-Json) } catch { Fail "rows 第 $lineNo 行不是合法 JSON" }
}
if ($rows.Count -eq 0) { Fail 'rows 文件里没有有效行（空文件）' }

# 保留每行原始的行尾，改写时不把混合行尾洗掉
function Split-Lines([string]$text) {
  $out = New-Object System.Collections.ArrayList
  $pos = 0
  while ($pos -lt $text.Length) {
    $nl = $text.IndexOf("`n", $pos)
    if ($nl -lt 0) {
      [void]$out.Add([pscustomobject]@{ Text = $text.Substring($pos); Eol = '' })
      $pos = $text.Length
    } else {
      $content = $text.Substring($pos, $nl - $pos)
      if ($content.EndsWith("`r")) { $content = $content.Substring(0, $content.Length - 1); $eol = "`r`n" } else { $eol = "`n" }
      [void]$out.Add([pscustomobject]@{ Text = $content; Eol = $eol })
      $pos = $nl + 1
    }
  }
  return $out
}
function Get-DominantEol($lines) {
  $crlf = @($lines | Where-Object { $_.Eol -eq "`r`n" }).Count
  $lf = @($lines | Where-Object { $_.Eol -eq "`n" }).Count
  if ($lf -gt $crlf) { return "`n" }
  return "`r`n"
}
function Format-CsvField($v) {
  if ($null -eq $v) { return '' }
  $s = [string]$v
  if ($s -match '[",\r\n]') { return '"' + ($s -replace '"', '""') + '"' }
  return $s
}
function Join-Csv($fields, [string[]]$header) {
  return (($header | ForEach-Object { Format-CsvField $fields[$_] }) -join ',')
}

# ---------- 目标文件与现有行 ----------
$path = ''
$lines = $null
$header = @()
$existingRows = @()

if ($Target -eq 'picks') {
  if ($Date -notmatch '^\d{4}-\d{2}-\d{2}$') { Fail "Date 不是 YYYY-MM-DD：$Date" }
  $path = P ("data\picks\$Date.jsonl")
  if (Test-Path $path) {
    $lines = @(Split-Lines ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)))
    foreach ($l in $lines) {
      if (-not $l.Text.Trim()) { continue }
      try { $existingRows += ($l.Text | ConvertFrom-Json) } catch { Fail "现有 picks/$Date.jsonl 有非法行，先人工修" }
    }
  } else {
    $lines = New-Object System.Collections.ArrayList
  }
  $appendEol = if ($lines.Count) { Get-DominantEol $lines } else { "`r`n" }
} else {
  $path = P 'data\recommend-log.csv'
  if (-not (Test-Path $path)) { Fail '找不到 data\recommend-log.csv' }
  $lines = @(Split-Lines ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)))
  if ($lines.Count -eq 0) { Fail 'recommend-log.csv 是空文件' }
  $header = @($lines[0].Text -split ',')
  $existingRows = @(Import-Csv $path)
  $appendEol = Get-DominantEol $lines
}

# ---------- 校验 + 判重 ----------
$invalid = @()
$conflicts = @()
$newRows = @()
$updateRows = @()   # @{ index = <line index>; merged = <object> }
$seenKeys = @{}

function Add-Key([string]$k) {
  if ($seenKeys.ContainsKey($k)) { $script:invalid += "rows 内部重复键：$k"; return $false }
  $script:seenKeys[$k] = $true
  return $true
}

for ($i = 0; $i -lt $rows.Count; $i++) {
  $r = $rows[$i]
  if ($Target -eq 'picks') {
    if (-not $r.PSObject.Properties['date']) {
      $ordered = [ordered]@{ date = $Date }
      foreach ($p in $r.PSObject.Properties) { $ordered[$p.Name] = $p.Value }
      $r = [pscustomobject]$ordered
    }
    $errs = @()
    foreach ($f in @('date', 'full_name', 'tier', 'score', 'risk', 'action')) {
      if (-not $r.PSObject.Properties[$f]) { $errs += "缺字段 $f" }
    }
    if ([string]$r.date -ne $Date) { $errs += "date=$($r.date) 与 -Date 不一致" }
    if ([string]$r.full_name -notmatch '^[^/\s]+/[^/\s]+$') { $errs += "full_name 不是 owner/repo：$($r.full_name)" }
    if ([string]$r.tier -notin $picksTier) { $errs += "tier 非法：$($r.tier)" }
    if ($null -ne $r.risk -and [string]$r.risk -notin $riskVals) { $errs += "risk 非法：$($r.risk)" }
    if ($null -ne $r.action -and [string]$r.action -notin $actionVals) { $errs += "action 非法：$($r.action)" }
    if ($null -ne $r.score -and ($r.score -isnot [ValueType] -or [double]$r.score -lt 0 -or [double]$r.score -gt 100)) { $errs += "score 非法：$($r.score)" }
    if ($r.PSObject.Properties['daily_status'] -and [string]$r.daily_status -notin $dailyStatusVals) { $errs += "daily_status 非法：$($r.daily_status)" }
    if ($r.PSObject.Properties['quota_block'] -and [string]$r.quota_block -notin $quotaVals) { $errs += "quota_block 非法：$($r.quota_block)" }
    # P1（2026-10-21）：分维度得分 / 证据（可选；有则校验形状与范围）
    if ($r.PSObject.Properties['parts'] -and $null -ne $r.parts) {
      $limits = @{ '实用性' = 44; '上手成本' = 15; '活跃度' = 20; '热度' = 20; '可信度' = 10 }
      foreach ($pp in $r.parts.PSObject.Properties) {
        if (-not $limits.ContainsKey($pp.Name)) { $errs += "parts 未知维度：$($pp.Name)"; continue }
        if ([int]$pp.Value -lt 0 -or [int]$pp.Value -gt $limits[$pp.Name]) { $errs += "parts.$($pp.Name) 越界：$($pp.Value)" }
      }
    }
    if ($r.PSObject.Properties['evidence'] -and $null -ne $r.evidence -and $r.evidence -isnot [pscustomobject]) { $errs += 'evidence 必须是对象' }
    if ($errs.Count) { $invalid += ("第 $($i + 1) 行：" + ($errs -join '；')); continue }

    $key = $Date + '|' + [string]$r.full_name
    if (-not (Add-Key $key)) { continue }
    $idx = -1
    for ($j = 0; $j -lt $existingRows.Count; $j++) {
      if ([string]$existingRows[$j].full_name -eq [string]$r.full_name) { $idx = $j; break }
    }
    if ($idx -ge 0) {
      if (-not $Update) { $conflicts += "picks/$Date 已有 $($r.full_name)（tier=$($existingRows[$idx].tier)）"; continue }
      $merged = [ordered]@{}
      foreach ($p in $existingRows[$idx].PSObject.Properties) { $merged[$p.Name] = $p.Value }
      foreach ($p in $r.PSObject.Properties) { $merged[$p.Name] = $p.Value }
      $updateRows += [pscustomobject]@{ index = $idx; merged = $merged }
    } else {
      $newRows += $r
    }
  } else {
    $errs = @()
    if (-not $r.PSObject.Properties['仓库'] -or -not [string]$r.仓库) { $errs += '缺字段 仓库' }
    if ($r.PSObject.Properties['首次推荐日'] -and ([string]$r.首次推荐日 -notmatch '^\d{4}-\d{2}-\d{2}$')) { $errs += "首次推荐日 不是 YYYY-MM-DD" }
    if ($r.PSObject.Properties['档位'] -and [string]$r.档位 -notin $csvTier) { $errs += "档位 非法：$($r.档位)" }
    if ($r.PSObject.Properties['状态'] -and [string]$r.状态 -notin $csvStatus) { $errs += "状态 非法：$($r.状态)" }
    foreach ($p in $r.PSObject.Properties) {
      if ($header -notcontains $p.Name) { $errs += "未知列：$($p.Name)" }
    }
    if ($errs.Count) { $invalid += ("第 $($i + 1) 行：" + ($errs -join '；')); continue }

    $key = [string]$r.仓库
    if (-not (Add-Key $key)) { continue }
    $idx = -1
    for ($j = 0; $j -lt $existingRows.Count; $j++) {
      if ([string]$existingRows[$j].仓库 -eq $key) { $idx = $j; break }
    }
    if ($idx -ge 0) {
      if (-not $Update) { $conflicts += "recommend-log.csv 已有 $key（首次推荐日=$($existingRows[$idx].首次推荐日)，状态=$($existingRows[$idx].状态)）"; continue }
      $fields = @{}
      foreach ($h in $header) { $fields[$h] = $existingRows[$idx].$h }
      foreach ($p in $r.PSObject.Properties) { $fields[$p.Name] = $p.Value }
      $updateRows += [pscustomobject]@{ index = $idx; fields = $fields }
    } else {
      if (-not $r.PSObject.Properties['首次推荐日'] -or -not [string]$r.首次推荐日) { $invalid += "第 $($i + 1) 行：新行缺字段 首次推荐日"; continue }
      $newRows += $r
    }
  }
}

if ($invalid.Count -or $conflicts.Count) {
  if ($Json) {
    [pscustomobject]@{ ok = $false; target = $Target; date = $Date; invalid = $invalid; conflicts = $conflicts; would_append = $newRows.Count; would_update = $updateRows.Count } | ConvertTo-Json -Depth 4
  } else {
    Write-Host "⛔ 拒绝写入：$($invalid.Count) 条非法，$($conflicts.Count) 条冲突" -ForegroundColor Yellow
    $invalid | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    $conflicts | ForEach-Object { Write-Host "  ⛔ $_（要刷新旧行请加 -Update）" -ForegroundColor Yellow }
  }
  exit 1
}

# ---------- DryRun ----------
if ($DryRun) {
  if ($Json) {
    [pscustomobject]@{ ok = $true; dry_run = $true; target = $Target; date = $Date; append = $newRows.Count; update = $updateRows.Count } | ConvertTo-Json -Depth 4
  } else {
    Write-Host ("✅ 计划：追加 {0} 行，刷新 {1} 行（dry-run，未写盘）" -f $newRows.Count, $updateRows.Count) -ForegroundColor Green
    $newRows | ForEach-Object { Write-Host ('  + ' + $(if ($Target -eq 'picks') { $_.full_name } else { $_.仓库 })) }
    $updateRows | ForEach-Object { Write-Host ('  ~ 第 ' + ($_.index + 1) + ' 行') }
  }
  exit 0
}

# ---------- 写盘 ----------
$outLines = New-Object System.Collections.ArrayList
if ($Target -eq 'picks') {
  $lineIndex = -1
  foreach ($l in $lines) {
    if (-not $l.Text.Trim()) { [void]$outLines.Add([pscustomobject]@{ Text = $l.Text; Eol = $l.Eol }); continue }
    $lineIndex++
    $hit = @($updateRows | Where-Object { $_.index -eq $lineIndex })[0]
    if ($hit) { [void]$outLines.Add([pscustomobject]@{ Text = ($hit.merged | ConvertTo-Json -Compress); Eol = $l.Eol }) }
    else { [void]$outLines.Add([pscustomobject]@{ Text = $l.Text; Eol = $l.Eol }) }
  }
  if ($outLines.Count -and -not $outLines[$outLines.Count - 1].Eol) { $outLines[$outLines.Count - 1].Eol = $appendEol }
  foreach ($r in $newRows) { [void]$outLines.Add([pscustomobject]@{ Text = ($r | ConvertTo-Json -Compress); Eol = $appendEol }) }
} else {
  [void]$outLines.Add([pscustomobject]@{ Text = $lines[0].Text; Eol = $lines[0].Eol })
  for ($j = 1; $j -lt $lines.Count; $j++) {
    $l = $lines[$j]
    if (-not $l.Text.Trim()) { [void]$outLines.Add($l); continue }
    $hit = @($updateRows | Where-Object { $_.index -eq ($j - 1) })[0]
    if ($hit) { [void]$outLines.Add([pscustomobject]@{ Text = (Join-Csv $hit.fields $header); Eol = $l.Eol }) }
    else { [void]$outLines.Add($l) }
  }
  if ($outLines.Count -and -not $outLines[$outLines.Count - 1].Eol) { $outLines[$outLines.Count - 1].Eol = $appendEol }
  foreach ($r in $newRows) {
    $fields = @{}
    foreach ($h in $header) { $fields[$h] = if ($r.PSObject.Properties[$h]) { $r.$h } else { '' } }
    [void]$outLines.Add([pscustomobject]@{ Text = (Join-Csv $fields $header); Eol = $appendEol })
  }
}

$text = ($outLines | ForEach-Object { $_.Text + $_.Eol }) -join ''
[IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))

if ($Json) {
  [pscustomobject]@{ ok = $true; target = $Target; date = $Date; append = $newRows.Count; update = $updateRows.Count; file = ($path.Substring($root.Length + 1)) } | ConvertTo-Json -Depth 4
} else {
  Write-Host ("✅ 已写入：追加 {0} 行，刷新 {1} 行 → {2}" -f $newRows.Count, $updateRows.Count, ($path.Substring($root.Length + 1))) -ForegroundColor Green
}
exit 0
