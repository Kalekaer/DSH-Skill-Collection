# 数据源与检索式

所有请求走 DSH 的 `web_fetch`（宿主网络，实测可达 `api.github.com`）。**不要**用本机 PowerShell/curl 直连，本机到 GitHub 的 HTTPS 不通。

## 1. 主源：GitHub Search API

基址：`https://api.github.com/search/repositories`

日期占位符在运行时替换：`{D7}` = 7 天前，`{D30}` = 30 天前，格式 `YYYY-MM-DD`。

| 编号 | 用途 | 检索式（URL 编码后） | 取数 |
|---|---|---|---|
| Q1 | 新星爆发（近 7 天新建） | `q=created:>{D7}+stars:>150&sort=stars&order=desc&per_page=20` | 20 |
| Q2 | 近 30 天新星（过滤玩具） | `q=created:>{D30}+stars:>800&sort=stars&order=desc&per_page=15` | 15 |
| Q3 | 方向定向（**按星期轮换**，见第 2 节） | `q=topic:{TODAY_TOPIC}+created:>{D30}+stars:>200&sort=stars&order=desc&per_page=10` | 10 |
| Q3b | 实用小工具（每周三、六加跑） | `q=topic:cli+created:>{D30}+stars:>300&sort=stars&order=desc&per_page=10` | 10 |
| Q4 | 老朋友续热（台账内仓库复检） | 逐个 `GET /repos/{owner}/{repo}`，只对进入候选的老面孔调用，**每次最多 5 个** | ≤5 |
| Q5 | 备用：聚合检索 | `web_search`：「今日 GitHub trending 2026-10-11」 | 8 |

实际 URL 示例（Q1，D7=2026-10-04）：

```
https://api.github.com/search/repositories?q=created:%3E2026-10-04+stars:%3E150&sort=stars&order=desc&per_page=20
```

Search 返回体里**已包含** `stargazers_count`、`forks_count`、`language`、`description`、`topics`、`created_at`、`pushed_at`、`license`，因此 Q1–Q3 不需要额外请求，一天 3 次调用就能拿到全部候选。

## 2. Q3 方向按星期轮换（已确认的口味）

一天只跑一个方向，避免日报注水；每天轮着来，一周覆盖全。周三、周六额外加跑 Q3b（实用小工具）。

| 星期 | `{TODAY_TOPIC}` | 加跑 |
|---|---|---|
| 周一 | `ai-agent` | — |
| 周二 | `mcp` | — |
| 周三 | `self-hosted` | Q3b `cli` |
| 周四 | `windows` | — |
| 周五 | `automation` | — |
| 周六 | `developer-tools` | Q3b `cli` |
| 周日 | `llm` | — |

备用方向词池（轮换表跑腻了就换）：`powershell`、`cli`、`devops`、`utilities`、`productivity`、`local-first`、`docker`。

「实用小工具」的判定不靠 topic，靠 `RUBRIC.md` 第 2 节的「实用性 + 上手成本」两项——凡是单文件、零依赖、即装即用的，这两项天然得分高。

## 3. 额度与礼仪

| 项 | 匿名 | 有 token |
|---|---|---|
| core | 60 / 小时 | 5000 / 小时 |
| search | 10 / 分钟 | 30 / 分钟 |
| 本方案日耗 | 约 3–5 次 | — |

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
