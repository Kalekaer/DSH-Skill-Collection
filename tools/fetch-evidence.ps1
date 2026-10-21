# fetch-evidence.ps1 — 抓评分证据（deps.dev + OpenSSF Scorecard）（2026-10-21 P1）
#
# 只读、只追加缓存；不写 picks、不改评分。证据进 data/enrich/evidence.jsonl，由 Agent 打分时引用。
# 失败一律记录，不抛错、不阻塞（开箱即用原则）。
#
# 用法：
#   .\tools\fetch-evidence.ps1 -Ids 'expressjs/express','ossf/scorecard'
#   .\tools\fetch-evidence.ps1 -FromPicks -Date 2026-10-21 -Limit 10
#   .\tools\fetch-evidence.ps1 -Ids 'owner/repo' -FullScorecard
# 退出码：0 完成（个别失败也 0）；1 参数/环境错误

[CmdletBinding()]
param(
  [string[]]$Ids = @(),
  [string]$Date = '',
  [switch]$FromPicks,
  [string]$Out = 'data\enrich\evidence.jsonl',
  [int]$Limit = 20,
  [switch]$FullScorecard
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function P([string]$rel) { Join-Path $root $rel }
$enc = New-Object System.Text.UTF8Encoding($false)
$today = (Get-Date).ToString('yyyy-MM-dd')

if ($FromPicks) {
  if (-not $Date) { $Date = (Get-Date).ToString('yyyy-MM-dd') }
  $pp = P "data\picks\$Date.jsonl"
  if (-not (Test-Path $pp)) { Write-Host "✗ 找不到 $pp" -ForegroundColor Red; exit 1 }
  $Ids = @(Get-Content $pp -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json } |
      Where-Object { $_.tier -in @('S', 'A') } | ForEach-Object { [string]$_.full_name })
}
$Ids = @($Ids | Where-Object { $_ } | Select-Object -Unique)
if (-not $Ids.Count) { Write-Host '没有要抓的 id。' -ForegroundColor DarkGray; exit 0 }

# 缓存：同一天同一 id 不重复抓
$seen = @{}
$outPath = P $Out
if (Test-Path $outPath) {
  foreach ($l in [IO.File]::ReadAllLines($outPath, [Text.Encoding]::UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $o = $l | ConvertFrom-Json } catch { continue }
    if ($o.id -and $o.fetched_at -and (@($o.errors).Count -eq 0)) {
      $dt = $null
      try { $dt = [datetime]$o.fetched_at } catch { $dt = $null }
      if ($dt) { $seen["$($o.id)|$($dt.ToString('yyyy-MM-dd'))"] = $true }
    }
  }
}

function Get-Json([string]$url, [int]$timeout = 20) {
  # 本机 PowerShell 的 TLS 栈对 api.deps.dev 报 SSL 失败（2026-10-21 实测），curl --insecure 可通
  $raw = $null
  for ($i = 0; $i -lt 2 -and -not $raw; $i++) {
    $raw = & curl.exe -s --insecure --max-time $timeout -H 'User-Agent: dsh-daily-evidence' $url 2>$null
    if (-not $raw) { Start-Sleep -Milliseconds 400 }
  }
  if (-not $raw) { return $null }
  try { return ($raw -join "`n" | ConvertFrom-Json) } catch { return $null }
}
function Enc([string]$s) { return [uri]::EscapeDataString($s) }

$rows = New-Object System.Collections.ArrayList
$done = 0
foreach ($id in $Ids) {
  if ($done -ge $Limit) { break }
  if ($seen.ContainsKey("$id|$today")) { Write-Host "· 跳过（今日已抓）：$id" -ForegroundColor DarkGray; continue }
  $rec = [ordered]@{ id = $id; fetched_at = (Get-Date).ToString('o'); errors = @() }
  $encId = Enc("github.com/$id")

  $proj = Get-Json "https://api.deps.dev/v3alpha/projects/$encId"
  if ($proj) {
    $sc = $null
    if ($proj.scorecard -and $null -ne $proj.scorecard.overallScore) { $sc = [double]$proj.scorecard.overallScore }
    $checks = @{}
    if ($proj.scorecard -and $proj.scorecard.checks) {
      foreach ($chk in $proj.scorecard.checks) { $checks[[string]$chk.name] = [int]$chk.score }
    }
    $rec['depsdev'] = [ordered]@{
      license = [string]$proj.license; stars = [int]$proj.starsCount; forks = [int]$proj.forksCount
      openIssues = [int]$proj.openIssuesCount; scorecardOverall = $sc; checks = $checks
    }
  }
  else { $rec.errors += 'depsdev project unavailable' }

  $pv = Get-Json "https://api.deps.dev/v3alpha/projects/$encId`:packageversions"
  if ($pv -and $pv.versions) {
    $src = @($pv.versions | Where-Object { $_.relationType -eq 'SOURCE_REPO' }) | Select-Object -First 1
    if (-not $src) { $src = @($pv.versions) | Select-Object -First 1 }
    if ($src) {
      $vk = $src.versionKey
      $verified = $false
      if ($src.attestations) { $verified = @($src.attestations | Where-Object { $_.verified }).Count -gt 0 }
      $rec['package'] = [ordered]@{ system = [string]$vk.system; name = [string]$vk.name; version = [string]$vk.version; slsaVerified = $verified }
      if ($vk.system -and $vk.name -and $vk.version) {
        $furl = "https://api.deps.dev/v3alpha/systems/$([string]$vk.system)/packages/$(Enc([string]$vk.name))/versions/$(Enc([string]$vk.version)):findings"
        $fd = Get-Json $furl
        if ($fd) {
          $all = @()
          foreach ($bucket in @($fd.requestedVersion, $fd.defaultVersion)) {
            if ($bucket -and $bucket.findings) { $all += @($bucket.findings) }
          }
          if ($fd.packageFindings) { $all += @($fd.packageFindings) }
          $rec['findings'] = @($all | ForEach-Object { [ordered]@{ type = [string]$_.type; risk = [string]$_.risk } })
          if ($fd.recommendedVersions) { $rec['recommendedVersions'] = @($fd.recommendedVersions | ForEach-Object { [string]$_.version }) }
        }
        else { $rec.errors += 'depsdev findings unavailable' }
      }
    }
  }
  else { $rec.errors += 'depsdev packageversions unavailable' }

  if ($FullScorecard) {
    $scFull = Get-Json "https://api.securityscorecards.dev/projects/github.com/$id"
    if ($scFull) {
      $cm = @{}
      foreach ($chk in @($scFull.checks)) { $cm[[string]$chk.name] = [int]$chk.score }
      $rec['scorecardFull'] = [ordered]@{ overall = if ($null -ne $scFull.score) { [double]$scFull.score } else { $null }; date = [string]$scFull.date; checks = $cm }
    }
    else { $rec.errors += 'scorecard unavailable' }
  }

  [void]$rows.Add($rec)
  $done++
  Write-Host ("✓ {0}  depsdev={1} findings={2} scorecard={3}" -f $id, $(if ($rec.Contains('depsdev')) { 'ok' } else { '—' }), $(if ($rec.Contains('findings')) { $rec.findings.Count } else { '—' }), $(if ($rec.Contains('scorecardFull')) { 'ok' } else { '—' })) -ForegroundColor DarkGreen
  Start-Sleep -Milliseconds 350
}

if ($rows.Count) {
  $lines = @($rows | ForEach-Object { ($_ | ConvertTo-Json -Depth 8 -Compress) })
  [IO.File]::AppendAllLines($outPath, [string[]]$lines, $enc)
  Write-Host ("追加 {0} 条 → {1}" -f $rows.Count, $Out) -ForegroundColor Cyan
}
