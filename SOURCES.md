# 数据源与检索式

请求**优先走 DSH 的 `web_fetch`**（宿主网络，实测可达 `api.github.com`）。本机代理（`http://127.0.0.1:2080`）本身可用：**`curl.exe` 与 Python `urllib` 走代理可达**（2026-10-23 实测 HTTPS 200 / search remaining=10），但两者在普通沙箱里会被拒绝执行，需宿主终端或申请权限；**PowerShell 的 `Invoke-RestMethod/-WebRequest`（.NET/schannel）HTTPS 实测不通**，不要用它抓 GitHub。**批量/额度**场景才用本机脚本，token 可选（`DSH_GITHUB_TOKEN`）。

## 1. 主源：GitHub Search API

基址：`https://api.github.com/search/repositories`

日期占位符在运行时替换：`{D7}` = 7 天前，`{D14}` = 14 天前，`{D30}` = 30 天前，格式 `YYYY-MM-DD`。

<!-- QGEN:START -->
| 编号 | 用途 | 检索式（URL 编码后） | 取数 |
|---|---|---|---|
| Q1 | 新星爆发（近 7 天新建） | `q=created:%3E{D7}+stars:%3E150&sort=stars&order=desc&per_page=20` | 20 |
| Q2 | 近 30 天新星（过滤玩具） | `q=created:%3E{D30}+stars:%3E800&sort=stars&order=desc&per_page=15` | 15 |
| Q2b | 中间星段（200–800★，顶部） | `q=stars:200..800+pushed:%3E{D7}&sort=stars&order=desc&per_page=15` | 15 |
| Q2c | 中间星段（200–800★，按活跃度） | `q=stars:200..800+pushed:%3E{D7}&sort=updated&order=desc&per_page=15` | 15 |
| Q2d | 实验槽（星速探针） | 见 §1.3（每周三 1 次） | 15 探针 / 出 ≤5 名 |
| Q3 | 方向定向（按星期轮换） | `q=topic:{TODAY_TOPIC}+created:%3E{D30}+stars:%3E200&sort=stars&order=desc&per_page=10` | 10 |
| Q3s | 星段兜底 | `q=topic:{TODAY_TOPIC}+stars:200..800+pushed:%3E{D14}&sort=stars&order=desc&per_page=10` | 10 |
| Q3b | 实用小工具（cli） | `q=topic:cli+created:%3E{D30}+stars:%3E300&sort=stars&order=desc&per_page=10` | 10 |
| Q3c | 第二方向（developer-tools） | `q=topic:{TODAY_TOPIC2}+created:%3E{D30}+stars:%3E200&sort=stars&order=desc&per_page=10` | 10 |
| Q4 | 老朋友续热（逐仓库复检） | 逐个 `GET /repos/{OWNER}/{REPO}`，每次最多 5 个 | ≤5 |
| Q5 | 读 README（S 档核实） | 逐个 `GET /repos/{OWNER}/{REPO}/readme`，每次最多 5 个 | ≤5 |
| Q6 | 备用：聚合检索 | `web_search`（非 GitHub API；失败改用 HN Algolia 等 JSON 源，仅外部讨论信号） | 8 |
<!-- QGEN:END -->

实际 URL 示例（Q1，D7=2026-10-15）：

```
https://api.github.com/search/repositories?q=created:%3E2026-10-15+stars:%3E150&sort=stars&order=desc&per_page=20
```

Search 返回体里**已包含** `stargazers_count`、`forks_count`、`language`、`description`、`topics`、`created_at`、`pushed_at`、`license`，因此 Q1–Q3c 与 Q2c 不需要额外请求（Q2d 的探针要逐个 `GET /repos`，不在此列）。**Q2b 每天加跑**（补中间星段）；**Q2c 每天加跑**（同星段、按最近更新采样，补 Q2b 的「天花板偏差」）；**Q2d 每周三 1 次**（实验槽）；**Q3s 只在 Q3 拉不到新面孔时加跑** → 一天 **5–7 次**调用（周三/周四/周六可能 6–8 次）。

### 1.1 Q2b / Q3s 为什么加（2026-10-18 采纳）

- **Q2b 中间星段**：Q1（7 天新库）和 Q2（30 天 800★+）的头部已被台账占满；10-16 记录 `stars:200..800` 的池子约 **641 条**（⚠️ 与 10-22 同式实测的两万条级不一致，待复核，见 §1.2），头 10 条里 **6 条是新面孔**。Q2b 只要求「近 7 天有推送」，不限创建时间，专门捞「已经有人用、但还没爆」的项目。
- **Q3s 星段兜底**：Q3 的 `created:>{D30}+stars:>200` 在 `docker`（3 条）、`utilities`（0 条）这类小方向会直接空；兜底改为**不限创建时间**、只看 `stars:200..800 + 近 14 天推送`，并保留同一个 `topic`，避免换方向。
- 触发：Q3 结果里**新面孔 <3** 或 `total_count <10` 才加跑 Q3s；Q3 正常时不跑，控制额度。
- 这两条只改**检索式**，不改 `RUBRIC.md` 的筛选/打分标准。

### 1.2 Q2c 为什么加（2026-10-22 用户决定）

- Q2b 的星段 `200..800` 没错，错在 `sort=stars&order=desc` **只取区间顶部**：10-22 同式多次实测池子约 **2 万条**（20,227–20,784，计数会跳），头 15 条是 **11 个 800★ + 4 个 799★**，全是 2015–2022 的老项目；反过来 `order=asc` 则全是 200★，同样贴边。
- Q2c 用**同一星段 + `sort=updated`**：结果沿整个星段铺开（10-22 实测 15 条落在 **200–467★**），能捞到「最近有动静的中段项目」。
- 两条并存、**Q2b 不改不删**：Q2b 看「这段里最成熟的」，Q2c 看「这段里最近最活跃的」。
- 代价：Q2c 会混进「每天推送的大仓库」（KDE / grafana 这类），靠 `RUBRIC.md` 的硬排除与打分筛掉。

### 1.3 Q2d 实验槽（2026-10-22 起，每周三 1 次）

- 目的：给「找还没爆的项目」留一个**可迭代的试验位**，不污染主流程。
- 规则：
  1. 每次只试**一种**新方法，方法池轮换（星速探针 / Hacker News 信号 / 主题桶采样 / 按创建月份切窗）；
  2. 结果**只写** `data/_tmp/q2d-<date>.jsonl` 与运行日志，**不入库、不进 picks、不进日报**；
  3. 连续 **2 周**在同一指标上优于 Q2b/Q2c 基线，才提议转正（改本文件须用户批准）；
  4. 失败 / 无数据照常记录，不阻塞日报。

**方法池（按推荐顺序）**

| 方法 | 怎么做 | 成本 | 已知坑 |
|---|---|---|---|
| 星速探针 | 挑 15 个中段仓库（600–800 / 450–600 / 300–450 / 200–300 各 3–4 个），周三布、下周三收，算 7 日 Δstars/天，取前 5 | 15 次 core / 次 | 样本小、窗口只有 7 天；fork/star<0.02、无 release、0 issue 的先剔除 |
| HN 信号 | Algolia 接口搜 24–48 小时内提到 `github.com` 且 points ≥50 的帖子，抽仓库、过滤到中段 | 1–2 次网页请求 | 英文圈偏科；讨论和涨速高度相关，不能当独立证据 |
| 主题桶采样 | 3–4 个主题各取 5 条中段，拼成一份名单 | 3–4 次 search | 主题选偏就偏；只解决覆盖，不解决「老而不涨」 |
| 创建月份切窗 | 按 `created` 月份切窗口，池子小、没有 800 天花板 | 1–4 次 search | 不是「涨速」信号，只适合当对照 |

**验收（每周三记一次）**

| 指标 | 怎么算 | 门槛 |
|---|---|---|
| precision@5 | 5 个名字里 B 档及以上的比例 | ≥ 0.6 |
| 增量 | Q2b / Q2c 当周结果里没出现过的条数 | ≥ 2 |
| 耗时 | 从开跑到出结论 | ≤ 15 分钟 |

连续 **2 周**都过线 → 提议转正；不过线 → 换下一个方法；两次都不行 → 写进「明确不做」。

### 1.4 可选补充源：HN Algolia（只做「外部讨论」信号）

**不是通用搜索**，只在需要判断「某仓库 / 工具在 Hacker News 上有没有人讨论」时用；不用于发现新工具（发现仍走 Q1–Q5）。

- 端点：`https://hn.algolia.com/api/v1/search_by_date?query={关键词}&tags=story&numericFilters=created_at_i%3E{90 天前时间戳}&hitsPerPage=5`
  - 用 `search_by_date`（按时间），不用 `search`（按相关度，会混进旧帖）
- 命中判定（满足其一才算「有讨论」，否则不算）：
  1. `hit.url` 等于 `https://github.com/{owner}/{repo}`（忽略大小写、末尾斜杠）
  2. `hit.title` 包含完整 `{owner}/{repo}`
- 覆盖范围只有 Hacker News 一个社区，**不得据此说「全网都在讨论」**；未见命中只能写「HN 未见讨论」。
- 通道：`web_fetch`，不占 GitHub 额度；失败 / 限流就放弃，标「未检索到外部讨论」。

**检索能力阶梯（任何任务都按这个顺序，不绑死单一工具）**

| 层 | 通道 | 用途 |
|---|---|---|
| L0 | `web_fetch` + GitHub API | 日报全部检索、仓库事实、发现 |
| L1 | anysearch（**可选**，会话里有才用） | 通用网页检索 / 素材 |
| L2 | `web_search` | 通用检索备用；失败重试 1 次即弃 |
| L3 | `web_fetch` + 已知 JSON API（HN Algolia / npm / PyPI / deps.dev） | 讨论信号 / 包事实 |
| L4 | 都没有 | 明说检索了什么、为什么没有；标「未验证」，不编造 |

- 单任务总调用 ≤2 次（含核实）；换通道算一次。
- `web_fetch` 整体不可用 = 当天不出日报，只写运行日志——这不是「降级」。

## 2. Q3 方向按星期轮换（已确认的口味）

一天只跑一个方向，避免日报注水；每天轮着来，一周覆盖全。周三、周六额外加跑 Q3b（实用小工具）；**周四额外加跑 Q3c（第二方向）**。

| 星期 | `{TODAY_TOPIC}` | 加跑 |
|---|---|---|
| 周一 | `ai-agent` | — |
| 周二 | `mcp` | — |
| 周三 | `self-hosted` | Q3b `cli` |
| 周四 | `windows` | Q3c `developer-tools` |
| 周五 | `automation` | — |
| 周六 | `developer-tools` | Q3b `cli` |
| 周日 | `llm` | — |

备用方向词池（轮换表跑腻了就换）：`powershell`、`cli`、`devops`、`utilities`、`productivity`、`local-first`、`docker`。

**周四为什么跑两个方向（2026-10-15，用户决定"1A"）**：`windows` 单一方向池子偏小 —— 2026-10-15 实测 `total_count=31`，当天检索结果只有 30 条（周三为 40 条）。当天实测各方向在 `created:>{D30} stars:>200` 口径下的池子：`windows` 31 ｜ `developer-tools` 28 ｜ `local-first` 11 ｜ `productivity` 4 ｜ `docker` 3 ｜ `devops` 1 ｜ `utilities` 0。**选了池子最大的 `developer-tools`**。

> **已知取舍**：`developer-tools` 同时是周六的 `{TODAY_TOPIC}`，两个方向会看到同一批仓库（第二次出现时通常已在台账里，只会进「老朋友动态」）。若觉得重复，两个改法任选：① 把周四 Q3c 换成别的方向（实测备用词池都很小，收益有限）；② 把 Q3c 改成**不带 topic 的宽检索**（`q=created:>{D30}+stars:>200`）——那才是真正能把周四检索结果拉起来的一步，但它不再是"一个方向"，需要另行确认。

「实用小工具」的判定不靠 topic，靠 `RUBRIC.md` 第 2 节的「实用性 + 上手成本」两项——凡是单文件、零依赖、即装即用的，这两项天然得分高。

## 3. 额度与礼仪

| 项 | 匿名 | 有 token |
|---|---|---|
| core | 60 / 小时 | 5000 / 小时 |
| search | 10 / 分钟 | 30 / 分钟 |
| 本方案日耗 | 约 5–7 次（周三 7–8） | — |

- **一次跑完，不轮询**。失败就记录并跳过，不重试超过 1 次。
- 记录每次运行的实际调用次数到 `data/runs/`，便于发现额度异常。

## 4. 已排除的源

| 源 | 原因 |
|---|---|
| `github.com/trending` HTML | `web_fetch` 30s 超时，不稳定 |
| `api.ossinsight.io/v1/trends/*` | 官方标注 star 事件数据自 2026-03-01 起不可用，返回空结果 |
| GitHub GraphQL | 匿名不允许（limit 0） |
| 各类第三方 trending 镜像站 | 数据滞后一天以上，无法验证口径 |

## 5. 增速怎么算

官方 trending 的口径拿不到，改用自己的快照：

```
Δstars = 今日 stargazers_count − 最近一次快照中该仓库的 stargazers_count
增速   = Δstars / 间隔天数
```

间隔超过 3 天的快照标记为 `stale`，只做参考、不参与排序。

## 6. README 取数：三级降级链（2026-10-16 定稿）

日报与「补人话层」都依赖 README。本机网络环境会变（2026-10-15 曾整天 `fetch failed`，2026-10-16 用户挂梯子后恢复），因此**固定按下面的顺序试，命中即停，不重试超过 1 次**：

| 顺序 | 通道 | 说明 |
|---|---|---|
| ① | `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/README.md` | **首选**。纯文本、不占 GitHub API 额度。分支先 `main`，404 再 `master` |
| ② | `https://cdn.jsdelivr.net/gh/{owner}/{repo}@{branch}/README.md` | 镜像。**只服务"已被缓存过"的文件**：命中返回 200；未命中会 **302 跳回 `raw.githubusercontent.com`**（此时直接放弃本通道，不要重试） |
| ③ | `GET /repos/{owner}/{repo}/readme`（`api.github.com`） | 兜底。返回 **base64**，需本地解码；响应较大时会落 spill 文件，可从文件解码。**占 core 额度** |

**已知不可用（不要再试）**：`cdn.statically.io`、`raw.githack.com`、`rawcdn.githack.com`、`gitcdn.link`、`r.jina.ai`、`fastly.jsdelivr.net`（与主域同样 302）；`github.com/.../blob/...` 页面能打开但返回的是导航壳，正文在截断之后，不可用。

**分支与文件名**：默认分支以 `GET /repos/{o}/{r}` 的 `default_branch` 为准；文件名除 `README.md` 外，也可能是 `README.zh-CN.md`、`readme.md`。

## 7. `topic:` 类检索的已知污染（2026-10-16 记）

`topic:dsh-plugin` 实测有 **19,309** 个仓库，但**标签被蹭**：`Molunerfinn/PicGo`（图床上传）、`reactive-resume/reactive-resume`（简历）、`Tencent/WeKnora`（RAG 平台）等与 DSH 无关的仓库也打了该标签。

- **结论：热门 `topic:` 不能只按 star 排序取头部**，必须逐条看描述与 topics 是否真相关。
- 判断某组织是否真有相关项目时，用 `org:{name} topic:{topic}` 取真实交集（实测腾讯 org 296 个仓库里只有 2 个带 `dsh-plugin`）。
