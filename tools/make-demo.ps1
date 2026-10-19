# make-demo.ps1 — 生成一份可公开的 demo 数据包（examples/demo/）
#
# 为什么需要：别人 clone 这个仓库时，看到的应该是**能跑起来的东西**，而不是空的目录。
# 但真实库里有 53 条用户自己加的项目 + 个人备注 + 工作区 —— **不适合公开**。
#
# 做法（GPT 评审 2026-10-13 定的方案 B + 小真实 demo）：
#   * 只取**真实公开项目**（不生成假项目，假项目会降低可信度）
#   * **优先取自动发现的项目**（origin=auto），少取用户自己加的那些
#   * **剥掉所有个人数据**：user_notes / library / 工作区 / 私人备注
#   * 保留完整结构：projects.jsonl + events.jsonl + plans.json + README.md
#
# 用法：
#   & ".\tools\make-demo.ps1"            # 默认 15 条
#   & ".\tools\make-demo.ps1" -Count 20
param(
  [int]$Count = 15
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }
$outDir = P 'examples\demo'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# ---- 读真实项目 ----
$all = @()
foreach ($l in (Get-Content (P 'data\projects.jsonl') -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
}

# ---- 选样本：自动发现的优先；覆盖尽量多的分类；带 1 条已淘汰的（展示状态机）----
$auto = @($all | Where-Object { $_.origin -eq 'auto' -and $_.status -ne 'dropped' -and $_.human.status -eq 'complete' })
$picked = @()
foreach ($p in ($auto | Sort-Object { -$_.stars.current })) {
  if ($picked.Count -ge ($Count - 1)) { break }
  $cat = "$($p.category.l2)"
  # 每个二级分类最多 2 条，保证覆盖面
  $n = @($picked | Where-Object { $_.category.l2 -eq $cat }).Count
  if ($n -ge 2) { continue }
  $picked += $p
}
# 补一条已淘汰的，展示 dropped 状态
$dropped = @(@($all | Where-Object { $_.status -eq 'dropped' -and $_.origin -eq 'auto' }) + @($all | Where-Object { $_.status -eq 'dropped' }))[0]
if ($dropped) { $picked += $dropped }
$ids = @($picked | ForEach-Object { $_.id })

# ---- 剥个人数据后写 projects.jsonl ----
# 2026-10-19：audit 166 要求投影层字段齐全（score / source / kind / owner_class /
# function_tags_l1 / note / user_notes …）。所以「个人内容」改成**置空**而不是删字段；
# 只删真正属于个人库的 library。note / user_notes 一律空串。
$projLines = foreach ($p in $picked) {
  $o = $p.PSObject.Copy()
  foreach ($f in 'library') {
    if ($o.PSObject.Properties[$f]) { $o.PSObject.Properties.Remove($f) }
  }
  if ($o.PSObject.Properties['note']) { $o.note = '' }
  if ($o.PSObject.Properties['user_notes']) { $o.user_notes = '' }
  $o | ConvertTo-Json -Compress -Depth 8
}
[System.IO.File]::WriteAllLines((Join-Path $outDir 'projects.jsonl'), $projLines, (New-Object System.Text.UTF8Encoding($false)))

# ---- 只保留这些项目的事件 ----
$evLines = @()
$evPath = P 'data\events.jsonl'
if (Test-Path $evPath) {
  foreach ($l in (Get-Content $evPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $e = $l | ConvertFrom-Json } catch { continue }
    if ($ids -contains $e.id) { $evLines += ($e | ConvertTo-Json -Compress -Depth 6) }
  }
}
[System.IO.File]::WriteAllLines((Join-Path $outDir 'events.jsonl'), $evLines, (New-Object System.Text.UTF8Encoding($false)))

# ---- plans.json 原样复制（那是官方模板，不含个人数据）----
Copy-Item (P 'data\plans.json') (Join-Path $outDir 'plans.json') -Force

# ---- taxonomy 也复制（分类体系是公开规则）----
if (Test-Path (P 'data\taxonomy.json')) { Copy-Item (P 'data\taxonomy.json') (Join-Path $outDir 'taxonomy.json') -Force }

# ---- demo 的 README ----
$catList = @($picked | Group-Object { $_.category.l1 } | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)($($_.Count))" }) -join '、'
$readme = @"
# Demo 数据包

这是给"想看看它长什么样"的人准备的**最小可跑数据集**（不是完整库）。

| 项 | 值 |
|---|---|
| 项目数 | $($picked.Count) |
| 事件数 | $($evLines.Count) |
| 分类覆盖 | $catList |
| 来源 | **全部是真实公开的 GitHub 项目**（自动发现的为主，含 1 条已淘汰示例） |

## 里面**没有**什么（刻意去掉的）

- 用户自己添加的项目、个人备注（``data/user-notes.jsonl``）
- 工作区（``data/workspaces.jsonl``）
- 每日日报正文、抓取快照、推荐台账

## 怎么用它试跑

把本目录的四个文件覆盖到 ``data/``（**先备份原库**），然后：

``````powershell
& ".\tools\sync-projects.ps1" -Force
& ".\tools\build-overview.ps1"
& ".\tools\check-page.ps1"
``````

页面会只剩这 $($picked.Count) 个项目 —— 足够看清结构，也足够验证"换一份数据照样能跑"。

## 怎么重新生成

``````powershell
& ".\tools\make-demo.ps1" -Count 15
``````
"@
[System.IO.File]::WriteAllText((Join-Path $outDir 'README.md'), $readme, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "✅ demo 已生成 → examples\demo\" -ForegroundColor Green
Write-Host ("   项目 {0} 条（真实公开项目；来源：自动发现 {1} + 已淘汰 {2}）" -f $picked.Count, @($picked | Where-Object { $_.origin -eq 'auto' }).Count, @($picked | Where-Object { $_.status -eq 'dropped' }).Count)
Write-Host ("   事件 {0} 条 ｜ 分类覆盖 {1} 个一级" -f $evLines.Count, @($picked | Group-Object { $_.category.l1 }).Count)
Write-Host "   已剥掉：user_notes / library / 个人备注 / 工作区" -ForegroundColor DarkGray
