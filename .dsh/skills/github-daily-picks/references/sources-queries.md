# 检索式 URL 模板（`SOURCES.md` 的展开版）

> **口径以 `SOURCES.md` 为准**，本文件只补 URL 写法与调用细节，不新增数据源、不改编号、不改取数。
> 日期占位符运行时替换：`{D7}` = 7 天前，`{D30}` = 30 天前，格式 `YYYY-MM-DD`。

## 1. 请求写法

- 通道：`web_fetch`（宿主网络）。**不要**用本机 PowerShell / curl 直连，实测不通。
- 一次一个 URL，**串行执行**，不要并发轰炸（search 额度只有 10/分钟）。
- 有 `GITHUB_TOKEN` 时附加请求头 `Authorization: Bearer <token>`（**不要把 token 写进任何落盘文件或输出**）；没有就匿名跑。
- 建议同时带 `Accept: application/vnd.github+json`。若 `web_fetch` 不便设置请求头，则直接匿名调用即可，不要为了加头而绕路。

## 2. 检索式映射

| 编号 | 取数 | URL 模板 |
|---|---|---|
| Q1 | 20 | `https://api.github.com/search/repositories?q=created:%3E{D7}+stars:%3E150&sort=stars&order=desc&per_page=20` |
| Q2 | 15 | `https://api.github.com/search/repositories?q=created:%3E{D30}+stars:%3E800&sort=stars&order=desc&per_page=15` |
| Q3 | 10 | `https://api.github.com/search/repositories?q=topic:{TODAY_TOPIC}+created:%3E{D30}+stars:%3E200&sort=stars&order=desc&per_page=10` |
| Q3b | 10 | `https://api.github.com/search/repositories?q=topic:cli+created:%3E{D30}+stars:%3E300&sort=stars&order=desc&per_page=10`（**周三、周六加跑**） |
| Q4 | ≤5 | 逐个 `https://api.github.com/repos/{owner}/{repo}`（仅老朋友复检） |
| Q5 | ≤3 | `https://api.github.com/repos/{owner}/{repo}/readme`（**仅 S 档候选，核实安装方式**） |

## 3. 可直接复制的完整示例

以 `2026-10-11` 运行、`D7 = 2026-10-04`、`D30 = 2026-09-11`、`TODAY_TOPIC = llm`（周日）为例：

```
https://api.github.com/search/repositories?q=created:%3E2026-10-04+stars:%3E150&sort=stars&order=desc&per_page=20
https://api.github.com/search/repositories?q=created:%3E2026-09-11+stars:%3E800&sort=stars&order=desc&per_page=15
https://api.github.com/search/repositories?q=topic:llm+created:%3E2026-09-11+stars:%3E200&sort=stars&order=desc&per_page=10
https://api.github.com/repos/OWNER/REPO/readme
```

日期回推（补跑场景）：用户说「补跑 2026-10-05」→ `D7 = 2026-09-28`、`D30 = 2026-09-05`，产出的日报写入 `reports/2026-10-05.md`，**不得覆盖已有文件**。

## 4. Q3 方向轮换（以 `SOURCES.md` 第 2 节为准）

| 星期 | `{TODAY_TOPIC}` | 加跑 |
|---|---|---|
| 周一 | `ai-agent` | — |
| 周二 | `mcp` | — |
| 周三 | `self-hosted` | Q3b `cli` |
| 周四 | `windows` | — |
| 周五 | `automation` | — |
| 周六 | `developer-tools` | Q3b `cli` |
| 周日 | `llm` | — |

## 5. 返回体字段速查

Search 返回的 `items[]` 里已可直接取用：`full_name`、`html_url`、`description`、`language`、`topics`、`stargazers_count`、`forks_count`、`created_at`、`pushed_at`、`license.spdx_id`、`archived`、`fork`。

**因此 Q1–Q3 不需要任何额外请求**就能完成硬过滤与打分；只有要核实"怎么上手"或复检老面孔时才用 Q4 / Q5。

## 6. 常见响应与处理

| 响应 | 含义 | 动作 |
|---|---|---|
| `200` + `items: []` | 本次检索无结果 | 记录并继续；不要放宽条件重试 |
| `403` + `API rate limit exceeded` | 额度用尽 | **不重试**，记录到运行日志，用已有数据继续；若一条都没拿到，按「全部数据源失败」处理 |
| `422` | 检索式不合法 | 记录检索式原文，跳过该条，不要猜原因重写 |
| 超时 / fetch failed | 网络或宿主限制 | **最多重试 1 次**，仍失败则记录并跳过 |
| `total_count` 骤降 | 可能被限流降级或检索式写错 | 在运行日志的「异常」里写明 |
| 运行不足 7 天 | 没有「近 7 日均值」可比 | 用**已有运行天数的均值**代替；只有 1 天时不做异常判断，只记录本次 `total_count` |

## 7. 落盘位置

- 人读日报：`reports/YYYY-MM-DD.md`（格式以 `TEMPLATES/daily.md` 为准）
- 星数快照：`data/snapshots/YYYY-MM-DD.jsonl`
- 推荐档案：`data/picks/YYYY-MM-DD.jsonl`
- 运行日志：`data/runs/YYYY-MM-DD.md`（含调用次数、失败查询、建议调整项）
- **不要**新建 `data/YYYY-MM-DD.json`——机器可读版就是 `picks/`。

## 8. 合规与账号安全（红线，不要越）

- **唯一禁止的写入类动作**：star / fork / watch / follow / 提交 / 评论。GitHub 可接受使用政策第 4 条把「automated starring or following」明确列为 **rank abuse（刷榜）**，属于平台明示可处罚行为。本流程只做 `GET`，**永不发起任何写操作**。
- **API 调用是合规的**：官方明确「scraping 不包含通过我们的 API 收集信息」，本流程走 `api.github.com` 而非抓 HTML；每天 3–5 次调用远低于限额，不构成 excessive bandwidth。
- **不要抓 HTML 页面**（`github.com/trending` 等）：那才算 scraping，且实测超时，已排除。
- **合规红线仓库不作为日报内容**：为盗版 / 破解 / 外挂 / 恶意软件类项目导流，会让日报本身变成传播渠道。这类只写**不带链接**的中性剔除备注。
- **只取公开信息**：不读私有仓库、不联系人、不发邮件；台账只存公开仓库名与星数，不含个人信息。
- **表格安全**：`owner/repo` 必须匹配 `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$`；`note` 等自由文本**不要以 `=` `+` `-` `@` 开头**，避免同步到 `.univer` 表格时被当成公式。
