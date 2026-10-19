# 数据源与检索式

请求**优先走 DSH 的 `web_fetch`**（宿主网络，实测可达 `api.github.com`）。**本机 PowerShell/curl 带代理（`http://127.0.0.1:2080`）同样可达**（2026-10-16 实测：匿名 `limit=60`、46/46 成功、`tools\fetch-series.ps1` 即走此路）；**批量/额度**场景用本机脚本 + `-Proxy`，token 可选（`DSH_GITHUB_TOKEN`）。

## 1. 主源：GitHub Search API

基址：`https://api.github.com/search/repositories`

日期占位符在运行时替换：`{D7}` = 7 天前，`{D14}` = 14 天前，`{D30}` = 30 天前，格式 `YYYY-MM-DD`。

| 编号 | 用途 | 检索式（URL 编码后） | 取数 |
|---|---|---|---|
| Q1 | 新星爆发（近 7 天新建） | `q=created:>{D7}+stars:>150&sort=stars&order=desc&per_page=20` | 20 |
| Q2 | 近 30 天新星（过滤玩具） | `q=created:>{D30}+stars:>800&sort=stars&order=desc&per_page=15` | 15 |
| Q2b | 中间星段（200–800★，近 7 天有推送） | `q=stars:200..800+pushed:>{D7}&sort=stars&order=desc&per_page=15` | 15 |
| Q3 | 方向定向（**按星期轮换**，见第 2 节） | `q=topic:{TODAY_TOPIC}+created:>{D30}+stars:>200&sort=stars&order=desc&per_page=10` | 10 |
| Q3s | Q3 星段兜底（**仅当 Q3 新面孔 <3 或 total_count <10 时加跑**） | `q=topic:{TODAY_TOPIC}+stars:200..800+pushed:>{D14}&sort=stars&order=desc&per_page=10` | 10 |
| Q3b | 实用小工具（每周三、六加跑） | `q=topic:cli+created:>{D30}+stars:>300&sort=stars&order=desc&per_page=10` | 10 |
| Q3c | 第二方向（**每周四加跑**，2026-10-15 起） | `q=topic:{TODAY_TOPIC2}+created:>{D30}+stars:>200&sort=stars&order=desc&per_page=10` | 10 |
| Q4 | 老朋友续热（台账内仓库复检） | 逐个 `GET /repos/{owner}/{repo}`，只对进入复查的老面孔调用，**每次最多 5 个** | ≤5 |
| Q5 | 备用：聚合检索 | `web_search`：「今日 GitHub trending 2026-10-11」 | 8 |

实际 URL 示例（Q1，D7=2026-10-04）：

```
https://api.github.com/search/repositories?q=created:%3E2026-10-04+stars:%3E150&sort=stars&order=desc&per_page=20
```

Search 返回体里**已包含** `stargazers_count`、`forks_count`、`language`、`description`、`topics`、`created_at`、`pushed_at`、`license`，因此 Q1–Q3c 不需要额外请求。**Q2b 每天加跑**（补中间星段）；**Q3s 只在 Q3 拉不到新面孔时加跑** → 一天 **4–6 次**调用（周四/周六可能 5–7 次）。

### 1.1 Q2b / Q3s 为什么加（2026-10-18 采纳）

- **Q2b 中间星段**：Q1（7 天新库）和 Q2（30 天 800★+）的头部已被台账占满；10-16 实测 `stars:200..800` 的池子约 **641 条**，头 10 条里 **6 条是新面孔**。Q2b 只要求「近 7 天有推送」，不限创建时间，专门捞「已经有人用、但还没爆」的项目。
- **Q3s 星段兜底**：Q3 的 `created:>{D30}+stars:>200` 在 `docker`（3 条）、`utilities`（0 条）这类小方向会直接空；兜底改为**不限创建时间**、只看 `stars:200..800 + 近 14 天推送`，并保留同一个 `topic`，避免换方向。
- 触发：Q3 结果里**新面孔 <3** 或 `total_count <10` 才加跑 Q3s；Q3 正常时不跑，控制额度。
- 这两条只改**检索式**，不改 `RUBRIC.md` 的筛选/打分标准。

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
| 本方案日耗 | 约 4–6 次 | — |

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

