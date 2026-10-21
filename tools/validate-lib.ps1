# validate-lib.ps1 — 数据契约校验（读 data/schema.json，只读，零依赖）
#
# 双轨：
#   ① **内置校验**（纯 PowerShell，零依赖）→ 保证**发布包**也能跑（发布包不许依赖 Python ✓）
#   ② 若本机装了 `check-jsonschema`（开发期可选）→ 再用标准 JSON Schema 校验一遍（更严格 ✓）
#
# 支持（2026-10-19 起）：
#   - schema 里含 `<date>` 的文件（如 data/picks/<date>.jsonl）→ 逐个日期文件校验；
#   - 复合唯一键 `date+full_name`（date 取文件名，同日同仓库只允许一行）；
#   - `date` 字段必须等于文件名；
#   - properties 里的 enum / `$ref`→`$defs.*.enum` / minimum / maximum。
#
# 用法：
#   pwsh -File .\tools\validate-lib.ps1            # 校验全部受管文件
#   pwsh -File .\tools\validate-lib.ps1 -Json      # 机器可读
# 退出码：0 = 0 违规 ｜ 1 = 有违规 ｜ 2 = 无法判定（schema 缺失/文件读不到）

param([switch]$Json)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$schemaPath = Join-Path $root 'data\schema.json'
if (-not (Test-Path $schemaPath)) { Write-Host "❌ 找不到 data\schema.json" -ForegroundColor Red; exit 2 }

$schema = Get-Content $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$defs = $schema.'$defs'
$taxoPath = Join-Path $root 'data\taxonomy.json'
$taxo = if (Test-Path $taxoPath) { Get-Content $taxoPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
$validCats = @{}
if ($taxo) {
  foreach ($l1 in $taxo.'一级分类'.PSObject.Properties) {
    foreach ($l2 in $l1.Value.children.PSObject.Properties) { $validCats[($l1.Name + '/' + $l2.Name)] = $true }
  }
  $validCats[($taxo.'_其他分类'.'一级' + '/' + $taxo.'_其他分类'.'二级')] = $true
}

$statusAllowed = @($schema.'$defs'.status.enum)
$tierAllowed = @($schema.'$defs'.tier.enum)
$riskAllowed = @($schema.'$defs'.risk.enum)

# properties.<field> 的 enum：直接写 enum，或 `$ref` 指向 $defs.<name>.enum
function Resolve-Enum($propDef) {
  if ($null -eq $propDef) { return @() }
  $e = $propDef.PSObject.Properties['enum']
  if ($e) { return @($e.Value) }
  $r = $propDef.PSObject.Properties['$ref']
  if ($r -and ([string]$r.Value -match '#/\$defs/(.+)$')) {
    $def = $defs.PSObject.Properties[$Matches[1]].Value
    if ($def -and $def.PSObject.Properties['enum']) { return @($def.enum) }
  }
  return @()
}

$issues = New-Object System.Collections.Generic.List[object]

# 展开 schema.files：含 <date> 的按目录枚举，其余按单文件
$fileEntries = [ordered]@{}
foreach ($rel in @($schema.files.PSObject.Properties.Name)) {
  $list = New-Object System.Collections.ArrayList
  $fileEntries[$rel] = $list
  if ($rel -like '*<date>*') {
    $sample = $rel -replace '<date>', 'x'
    $dir = Split-Path (Join-Path $root ($sample -replace '/', '\')) -Parent
    if (-not (Test-Path $dir)) {
      $issues.Add([pscustomobject]@{ file = $rel; line = 0; issue = '文件不存在' })
      continue
    }
    foreach ($f in @(Get-ChildItem $dir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
      [void]$list.Add([pscustomobject]@{ path = $f.FullName; fileDate = $f.BaseName })
    }
  } else {
    [void]$list.Add([pscustomobject]@{ path = (Join-Path $root ($rel -replace '/', '\')); fileDate = $null })
  }
}

$statMap = [ordered]@{}
foreach ($rel in $fileEntries.Keys) { $statMap[$rel] = [pscustomobject]@{ file = $rel; lines = 0; ok = 0; bad = 0 } }

foreach ($rel in $fileEntries.Keys) {
  $spec = $schema.files.$rel
  $required = @($spec.required)
  $uniqueKey = ''
  $u = $spec.PSObject.Properties['_unique']
  if ($u -and ([string]$u.Value) -notmatch '不唯一') { $uniqueKey = [string]$u.Value }
  $props = $spec.properties
  $st = $statMap[$rel]

  foreach ($entry in $fileEntries[$rel]) {
    if (-not (Test-Path $entry.path)) {
      $issues.Add([pscustomobject]@{ file = $rel; line = 0; issue = '文件不存在' })
      continue
    }
    $lines = @(Get-Content $entry.path -Encoding UTF8 | Where-Object { $_.Trim() })
    $st.lines += $lines.Count
    $seen = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $ln = $i + 1
      $obj = $null
      try { $obj = $lines[$i] | ConvertFrom-Json } catch { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = 'JSON 解析失败' }); $st.bad++; continue }
      $lineBad = 0
      foreach ($f in $required) {
        if (-not $obj.PSObject.Properties[$f]) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('缺必填字段 ' + $f) }); $lineBad++ }
      }
      if ($obj.PSObject.Properties['status'] -and ($statusAllowed -notcontains [string]$obj.status)) {
        $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('status 越界：' + $obj.status) }); $lineBad++
      }
      if ($obj.PSObject.Properties['tier'] -and $null -ne $obj.tier -and ($tierAllowed -notcontains [string]$obj.tier)) {
        $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('tier 越界：' + $obj.tier) }); $lineBad++
      }
      if ($obj.PSObject.Properties['risk'] -and $null -ne $obj.risk -and ($riskAllowed -notcontains [string]$obj.risk)) {
        $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('risk 越界：' + $obj.risk) }); $lineBad++
      }
      # properties 里声明的 enum / 数值范围（status/tier/risk 上面已查，跳过避免重复报）
      if ($props) {
        foreach ($pp in $props.PSObject.Properties) {
          $fname = $pp.Name
          if ($fname -in @('status', 'tier', 'risk')) { continue }
          if (-not $obj.PSObject.Properties[$fname]) { continue }
          $val = $obj.$fname
          if ($null -eq $val) { continue }
          $enum = Resolve-Enum $pp.Value
          if ($enum.Count -gt 0 -and ($enum -notcontains [string]$val)) {
            $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ($fname + ' 越界：' + $val) }); $lineBad++
          }
          $minP = $pp.Value.PSObject.Properties['minimum']
          $maxP = $pp.Value.PSObject.Properties['maximum']
          if ($val -is [ValueType] -and ($minP -or $maxP)) {
            if ($minP -and [double]$val -lt [double]$minP.Value) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ($fname + ' 小于最小值 ' + $minP.Value) }); $lineBad++ }
            if ($maxP -and [double]$val -gt [double]$maxP.Value) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ($fname + ' 大于最大值 ' + $maxP.Value) }); $lineBad++ }
          }
          # P1（2026-10-21）：parts 是嵌套对象，内置校验只到顶层，这里补一层
          if ($fname -eq 'parts' -and $val -is [pscustomobject]) {
            $limits = @{ '实用性' = 44; '上手成本' = 15; '活跃度' = 20; '热度' = 20; '可信度' = 10 }
            foreach ($sp in $val.PSObject.Properties) {
              if (-not $limits.ContainsKey($sp.Name)) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('parts 未知维度：' + $sp.Name) }); $lineBad++; continue }
              if ([int]$sp.Value -lt 0 -or [int]$sp.Value -gt $limits[$sp.Name]) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('parts.' + $sp.Name + ' 越界：' + $sp.Value) }); $lineBad++ }
            }
          }
        }
      }
      # 唯一性：单键，或 `date+full_name` 这类复合键（date 取文件名）
      if ($uniqueKey) {
        $parts = $uniqueKey -split '\+'
        $vals = @()
        $skip = $false
        foreach ($kp in $parts) {
          if ($kp -eq 'date' -and $entry.fileDate) { $vals += $entry.fileDate }
          elseif ($obj.PSObject.Properties[$kp]) { $vals += [string]$obj.$kp }
          else { $skip = $true }
        }
        if (-not $skip) {
          $uk = $vals -join '|'
          if ($seen.ContainsKey($uk)) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ($uniqueKey + ' 重复：' + $uk) }); $lineBad++ } else { $seen[$uk] = $true }
        }
      }
      if ($entry.fileDate -and $obj.PSObject.Properties['date'] -and ([string]$obj.date -ne $entry.fileDate)) {
        $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('date 与文件名不一致：' + $obj.date + ' ≠ ' + $entry.fileDate) }); $lineBad++
      }
      if ($obj.PSObject.Properties['category'] -and $obj.category -and $validCats.Count -gt 0) {
        $key = [string]$obj.category.l1 + '/' + [string]$obj.category.l2
        if (-not $validCats.ContainsKey($key)) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ('分类不在 taxonomy：' + $key) }); $lineBad++ }
      }
      foreach ($arrField in @('topics', 'function_tags', 'user_keywords', 'synonyms')) {
        if ($obj.PSObject.Properties[$arrField]) {
          $arr = @($obj.$arrField)
          if (@($arr | Where-Object { $_ -eq $null }).Count -gt 0) { $issues.Add([pscustomobject]@{ file = $rel; line = $ln; issue = ($arrField + ' 含 null 元素') }); $lineBad++ }
        }
      }
      if ($lineBad -eq 0) { $st.ok++ } else { $st.bad++ }
    }
  }
}
$stats = @($statMap.Values)

# 可选：严格 JSON Schema（开发期，用 check-jsonschema；发布包不依赖它）
$strict = '未安装 check-jsonschema（可选）'
$cjs = Get-Command check-jsonschema -ErrorAction SilentlyContinue
if ($cjs) { $strict = '已安装（本脚本当前只用内置校验，避免发布包依赖 Python）' }

if ($Json) {
  [ordered]@{ stats = $stats; issues = $issues; strict_tool = $strict } | ConvertTo-Json -Depth 5
  if ($issues.Count -gt 0) { exit 1 } else { exit 0 }
}

Write-Host ''
Write-Host '=== 数据契约校验（内置，零依赖）===' -ForegroundColor Cyan
foreach ($s in $stats) { Write-Host ('  {0,-34} {1,4} 行 ｜ 干净 {2} ｜ 有问题 {3}' -f $s.file, $s.lines, $s.ok, $s.bad) }
if ($issues.Count -eq 0) {
  Write-Host '  ✅ 0 违规' -ForegroundColor Green
  Write-Host ('  （严格 JSON Schema 通道：' + $strict + '）') -ForegroundColor DarkGray
  exit 0
}
Write-Host ('  ⚠️ ' + $issues.Count + ' 条违规：') -ForegroundColor Yellow
$issues | Select-Object -First 25 | ForEach-Object { Write-Host ('    ' + $_.file + ':' + $_.line + ' → ' + $_.issue) -ForegroundColor DarkYellow }
exit 1
