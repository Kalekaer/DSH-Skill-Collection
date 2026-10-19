# humanize-next.ps1 — 人话层补全流水线：列出「下一批该补的」，并给出可用素材
#
# **补全规则（GPT 评审 2026-10-13 拍板，已固化）**
#   * 新加入的项目优先补，老项目低优先；**永不追求 100% 覆盖**。
#   * 剩下的低星小众条目**永久标为「低优先，不主动补」**——它们已有一句话 + 分类 + 标签 + 评分，
#     页面也明确标了「介绍待补全」，继续补收益极低。
#
# 背景（GPT 评审第 1 优先）：库里 143 条，只有 45 条有完整人话层，98 条只有一句话。
# 普通人打开看到的是 owner/repo + 星数 + License，看不懂「这玩意能干嘛」。
#
# 为什么不做成"一次全补"：problem / example 这两项**无法用规则从描述里诚实推出**，
# 硬写就是编造。所以做成**可分批执行**的流水线：每次只补 N 条，跟着日报一起做，边际成本低。
#
# 素材优先级（能少花额度就少花）：
#   ① 项目自带**中文描述** → 多数 DSH 插件属于这类，可以直接写出「它是什么 / 适合谁 / 比如」
#   ② 只有英文描述 → 需要 1 次 API（读 README）才能写准
#   ③ 只有台账备注 → 素材最差，排最后
#
# 用法：
#   & ".\tools\humanize-next.ps1"              # 默认列 10 条（优先：已收藏 > 常用 > 星数高）
#   & ".\tools\humanize-next.ps1" -N 5         # 列 5 条
#   & ".\tools\humanize-next.ps1" -Only 中文    # 只看能用中文描述直接写的（0 额度）
param(
  [int]$N = 10,
  [ValidateSet('全部','中文','需抓取')][string]$Only = '全部'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function P([string]$rel) { Join-Path $root $rel }

$have = @{}
$introPath = P 'data\human\repo-intro.jsonl'
if (Test-Path $introPath) {
  foreach ($l in (Get-Content $introPath -Encoding UTF8)) {
    if (-not $l.Trim()) { continue }
    try { $o = $l | ConvertFrom-Json; if ($o.full_name) { $have[$o.full_name] = $true } } catch { $null = $_ }
  }
}

$all = @()
foreach ($l in (Get-Content (P 'data\projects.jsonl') -Encoding UTF8)) {
  if ([string]::IsNullOrWhiteSpace($l)) { continue }
  try { $all += ($l | ConvertFrom-Json) } catch { $null = $_ }
}

function HasCJK([string]$s) { return ($s -and ($s -match '[\u4e00-\u9fff]')) }

$todo = @()
foreach ($p in $all) {
  if ($have.ContainsKey($p.id)) { continue }
  if ($p.status -eq 'dropped') { continue }
  $desc = "$($p.description)"
  $kind = if (HasCJK $desc) { '中文' } elseif ($desc) { '需抓取' } else { '需抓取' }
  if ($Only -ne '全部' -and $kind -ne $Only) { continue }
  $pri = 50
  # 优先级（GPT 评审 2026-10-13 固化）：正在使用 > 研究中 > 用户自己加的 > 新加入的 > 星数高的
  # 注意：'saved'（收藏）已废弃，不要再往里加
  if ($p.status -eq 'using') { $pri = 0 }
  elseif ($p.status -eq 'researching') { $pri = 1 }
  elseif ($p.origin -eq 'user') { $pri = 2 }
  else {
    $fs = "$($p.first_seen)"
    if ($fs) { try { if (((Get-Date) - [datetime]$fs).TotalDays -le 3) { $pri = 3 } } catch { $null = $_ } }
  }
  if ($p.recommended -and $pri -gt 3) { $pri -= 1 }
  $todo += [pscustomobject]@{ p = $p; kind = $kind; pri = $pri }
}
$todo = @($todo | Sort-Object pri, { -$_.p.stars.current })

Write-Host ""
Write-Host ("=== 人话层待补：{0} 条（本次列 {1} 条）===" -f $todo.Count, [Math]::Min($N, $todo.Count)) -ForegroundColor Cyan
Write-Host "  优先顺序：收藏 > 研究中 > 用户自己加的 > 星数高的" -ForegroundColor DarkGray
Write-Host ""
$i = 0
foreach ($t in ($todo | Select-Object -First $N)) {
  $i++
  $p = $t.p
  $flag = if ($t.kind -eq '中文') { '✅ 有中文描述，可直接写（0 额度）' } else { '🔴 需要 1 次 API 读 README' }
  Write-Host ("  [{0}] {1}  ★{2}  {3}  {4}" -f $i, $p.id, $p.stars.current, $p.license, $flag) -ForegroundColor White
  Write-Host ("      现状一句话：{0}" -f $(if ($p.human.one_liner) { $p.human.one_liner } else { '（无）' })) -ForegroundColor Gray
  Write-Host ("      描述：{0}" -f $(if ($p.description) { $p.description } else { '（无）' })) -ForegroundColor DarkGray
  Write-Host ("      标签：{0}" -f (@($p.function_tags) -join ' / ')) -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  写完用：& `".\tools\add-intro.ps1`" -File <写好的一批.jsonl> -Sync" -ForegroundColor DarkGray
Write-Host "  纪律：**素材不够就写「待补全」，不要编造**；problem / example 必须有依据。" -ForegroundColor DarkGray
if ($Only -eq '全部') {
  $cn = @($todo | Where-Object { $_.kind -eq '中文' }).Count
  $need = @($todo | Where-Object { $_.kind -eq '需抓取' }).Count
  Write-Host ("  其中：可用中文描述直接写 {0} 条 ｜ 需抓取 {1} 条（每条 1 次 API）" -f $cn, $need) -ForegroundColor DarkGray
}
