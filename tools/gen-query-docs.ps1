# gen-query-docs.ps1 — 把 data/queries.json 渲染进三份文档（唯一真源 → 生成）
#
# 为什么：Q 表以前抄在 SOURCES.md / references/sources-queries.md / PROMPT-daily.md 三处，
#         已经在漂（reference 缺 Q2b/Q3s/Q3c/Q2c/Q2d，Q5 同号不同义）。
# 现在：queries.json 是唯一真源；本脚本生成三处文档块；-Check 只比对不写盘。
#
# 用法：
#   & .\tools\gen-query-docs.ps1            # 生成/刷新三份文档
#   & .\tools\gen-query-docs.ps1 -Check     # 只比对：0=一致 / 1=有差异
#   & .\tools\gen-query-docs.ps1 -Check -Json
#
# 退出码：0 = 已写 / 一致；1 = -Check 发现差异；2 = 真源或文档结构错误

param(
  [switch]$Check,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P($r) { Join-Path $root $r }
$enc = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8([string]$path) { [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) }
function To-LF([string]$s) { $s -replace "`r`n", "`n" }
function Eol-Of([string]$s) { if ($s.Contains("`r`n")) { "`r`n" } else { "`n" } }
function Apply-Eol([string]$s, [string]$eol) { if ($eol -eq "`r`n") { (To-LF $s) -replace "`n", "`r`n" } else { To-LF $s } }

function Url-Q([string]$q) {
  $q = $q -replace ' ', '+'
  $q = $q -replace '>', '%3E'
  return $q
}

$qPath = P 'data\queries.json'
if (-not (Test-Path $qPath)) { Write-Host "✗ 找不到 $qPath" -ForegroundColor Red; exit 2 }
try { $spec = Get-Content $qPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Host "✗ queries.json 不是合法 JSON" -ForegroundColor Red; exit 2 }

# ---------- 校验 ----------
$errs = @()
$ids = @($spec.queries | ForEach-Object { [string]$_.id })
if ($ids.Count -ne @($ids | Sort-Object -Unique).Count) { $errs += 'id 有重复' }
foreach ($q in $spec.queries) {
  if ([int]$q.per_page -lt 1 -or [int]$q.per_page -gt 100) { $errs += "$($q.id) per_page 越界" }
  if ($q.frequency -notmatch '^(daily|weekly:\d(,\d)*|conditional|manual)$') { $errs += "$($q.id) frequency 非法：$($q.frequency)" }
  if ($q.q -and $q.q -match '\{([A-Z0-9_]+)\}' -and -not ($spec.placeholders -contains "{$($Matches[1])}")) {
    # 只提示，不阻断：允许 {OWNER}/{REPO} 这类
  }
}
if ($errs.Count) { $errs | ForEach-Object { Write-Host "✗ $_" -ForegroundColor Red }; exit 2 }

# ---------- SOURCES 表格块 ----------
function Cell-Q($q) {
  if ($q.mode -eq 'search') {
    $u = "q=$(Url-Q $q.q)"
    if ($q.sort) { $u += "&sort=$($q.sort)&order=$($q.order)" }
    $u += "&per_page=$($q.per_page)"
    return '`' + $u + '`'
  }
  if ($q.mode -eq 'repo') { return '逐个 `GET ' + $q.q + '`，每次最多 ' + $q.per_page + ' 个' }
  if ($q.mode -eq 'probe') { return '见 §1.3（每周三 1 次）' }
  if ($q.mode -eq 'external') { return ('`' + $q.q + '`（' + $q.note + '）') }
  return ''
}
function Cell-Count($q) {
  if ($q.mode -eq 'probe') { return '15 探针 / 出 ≤5 名' }
  if ($q.mode -eq 'repo') { return '≤' + $q.per_page }
  return [string]$q.per_page
}

$rows = @()
$rows += '| 编号 | 用途 | 检索式（URL 编码后） | 取数 |'
$rows += '|---|---|---|---|'
foreach ($q in $spec.queries) {
  $rows += ('| {0} | {1} | {2} | {3} |' -f $q.id, $q.name, (Cell-Q $q), (Cell-Count $q))
}
$sourcesBlock = "<!-- QGEN:START -->`n" + ($rows -join "`n") + "`n<!-- QGEN:END -->"

# ---------- PROMPT 顺序块 ----------
$dailyIds = @($spec.queries | Where-Object { $_.frequency -eq 'daily' } | ForEach-Object { $_.id })
$order = ($dailyIds -join ' → ')
$wd = $spec.weekdays
$extras = @()
foreach ($k in @('3', '4', '6')) {
  if ($wd.$k.extras) { $wn = @{'3'='周三';'4'='周四';'6'='周六'}; $extras += ($wn[$k] + ' + ' + (@($wd.$k.extras) -join '、')) }
}
$orderText = "当天顺序：$order（$($extras -join '；')；Q3 新面孔 <3 或 total_count <10 时加跑 Q3s）。"
$promptBlock = "<!-- QGEN:ORDER:START -->`n   $orderText`n   <!-- QGEN:ORDER:END -->"

# ---------- reference 全文 ----------
function Weekday-Rows() {
  $names = @{ '1' = '周一'; '2' = '周二'; '3' = '周三'; '4' = '周四'; '5' = '周五'; '6' = '周六'; '7' = '周日' }
  $out = @()
  foreach ($k in @('1', '2', '3', '4', '5', '6', '7')) {
    $w = $wd.$k
    $add = if ($w.extras) { (@($w.extras) | ForEach-Object { $_ }) -join '、' } else { '—' }
    $t = '`' + $w.topic + '`'
    if ($w.topic2) { $t += ' + `' + $w.topic2 + '`' }
    $out += ('| {0} | {1} | {2} |' -f $names[$k], $t, $add)
  }
  return $out
}

$refRows = @()
foreach ($q in $spec.queries) {
  if ($q.mode -ne 'search') { continue }
  $u = 'https://api.github.com/search/repositories?q=' + (Url-Q $q.q)
  if ($q.sort) { $u += "&sort=$($q.sort)&order=$($q.order)" }
  $u += "&per_page=$($q.per_page)"
  $refRows += ('| {0} | {1} | `{2}` |' -f $q.id, $q.per_page, $u)
}

$tpl = Read-Utf8 (P 'tools\templates\sources-queries.md.tpl')
$ref = $tpl.Replace('{{REF_ROWS}}', ($refRows -join "`n")).Replace('{{WEEKDAY_ROWS}}', ((Weekday-Rows) -join "`n"))

# ---------- 应用 ----------
$targets = @(
  @{ path = (P 'SOURCES.md');                 kind = 'sources' },
  @{ path = (P '.dsh\skills\github-daily-picks\references\sources-queries.md'); kind = 'file' },
  @{ path = (P 'PROMPT-daily.md');            kind = 'prompt' }
)

$diffs = @()
foreach ($t in $targets) {
  if (-not (Test-Path $t.path)) { $diffs += "$($t.path) 不存在"; continue }
  $old = Read-Utf8 $t.path
  $eol = Eol-Of $old

  switch ($t.kind) {
    'sources' {
      if ($old -notmatch '(?s)<!-- QGEN:START -->') { $diffs += 'SOURCES.md 缺 QGEN 标记'; break }
      $new = [regex]::Replace($old, '(?s)<!-- QGEN:START -->.*?<!-- QGEN:END -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $sourcesBlock })
  $new = Apply-Eol $new (Eol-Of $old)
    }
    'file' {
      $new = Apply-Eol $ref $eol
    }
    'prompt' {
      if ($old -notmatch '(?s)<!-- QGEN:ORDER:START -->') { $diffs += 'PROMPT-daily.md 缺 QGEN:ORDER 标记'; break }
      $new = [regex]::Replace($old, '(?s)<!-- QGEN:ORDER:START -->.*?<!-- QGEN:ORDER:END -->', [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $promptBlock })
  $new = Apply-Eol $new (Eol-Of $old)
    }
  }

  if ($null -eq $new) { continue }
  if ($Check) {
    if ((To-LF $old) -ne (To-LF $new)) { $diffs += (Split-Path $t.path -Leaf) }
  } else {
    if ((To-LF $old) -ne (To-LF $new)) { [IO.File]::WriteAllText($t.path, $new, $enc) }
  }
}

if ($Check) {
  if ($Json) { [ordered]@{ ok = ($diffs.Count -eq 0); diffs = $diffs } | ConvertTo-Json -Compress }
  if ($diffs.Count) { Write-Host ("✗ 文档与 queries.json 不一致：{0}" -f ($diffs -join ', ')) -ForegroundColor Red; exit 1 }
  Write-Host '✓ 三份文档与 queries.json 一致' -ForegroundColor Green
  exit 0
}

Write-Host '✓ 已从 queries.json 生成文档' -ForegroundColor Green
