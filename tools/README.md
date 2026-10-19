# tools/ — 流水线脚本一览

> 本包发的是**站点版**：页面由 `build-samples.ps1` 用 `data/` 生成到 `data/site/`，入口是根 `index.html`。
> 旧单页（`legacy/overview-v5.html`）不再随包；`build-overview.ps1` 仍保留，用于需要单文件页时自行生成。

| 脚本 | 作用 | 何时跑 |
|---|---|---|
| `sync-projects.ps1` | 从原始来源重建 `projects.jsonl` + `events.jsonl`（幂等，输入没变自动跳过；`-Force` 强制）。**开头自动备份 tools/ 到 `data/_backup/YYYY-MM-DD/`** | 每次改了原始来源之后 |
| `build-samples.ps1` | **站点生成器**：读 `data/` → 注入 5 个模板 → 写 `data/site/` + 根 `index.html`（每页带 `BUILD-STAMP`） | sync 之后 / 改页面之后 |
| `build-overview.ps1` | 生成旧版单页 `legacy/overview-v5.html`（单文件全内嵌，历史页；本包默认不带产物） | 想单独要一个单文件页时 |
| `query.ps1` | 命令行查询项目库（`-Tag/-Status/-Text/-Top`，支持同义词扩展） | 需要快速查库时 |
| `compare.ps1` | **项目对比**：`.\tools\compare.ps1 A B` 出对比表；`-Similar owner/repo` 找同类；`-Save` 才落盘。**不调 API** | 用户说「比较 A 和 B」「找类似 X」 |
| `add-repo.ps1` | **用户推荐项目入库**：Agent 先 `web_fetch` 核实，再把字段传进来；已存在则只记用户备注。**脚本本身不联网** | 用户说「这个项目不错：owner/repo」 |
| `compose.ps1` | **工具组合建议**：按需求从库里挑工具并**按用途分组**（每组最优 1–2 个）。只归类、不编造流程 | 用户说「我要做 ___」 |
| `auto-tag.ps1` | 给缺标签的项目**自动补功能标签/搜索词**（topics + 中文描述片段；不覆盖人工条目） | 批量入库后 |
| `suggest-terms.ps1` | 挖「还没进词表」的新词作为同义词候选（频率 + 示例仓库） | 库每涨 30–50 条 |
| `gaps.ps1` | **搜索缺口闭环**：`-Add "词"` 记下搜不到的词；默认复检并给补词建议 | 用户说「搜不到」之后 |
| `add-plan.ps1` | 把 /tool-stack 配好的一套**固化成网页方案**（查重后写 `data/plans.json`） | 用户说「写进网页里」 |
| `suggest-plans.ps1` | 挖「工具攒够但没有对应场景」的方向 → `data/plan-suggestions.jsonl` 待批 | 库明显变大后 |
| `daily-questions.ps1` | 日报跑完后生成「该问用户的几个问题」（带数据依据，只问要拍板的） | **每日流程收尾** |
| `humanize-next.ps1` | 列出「还缺人话介绍」的项目，按优先级给待补清单 | 想补介绍时 |
| `add-intro.ps1` | 批量写人话介绍（一句话 / 痛点 / 例子 / 功能说明五项） | 补介绍时 |
| `workspace.ps1` | 建 / 改工作区（目标、状态、工具、进度、备注） | 用户说「建个工作区」 |
| `make-demo.ps1` | 从库里抽 15 条生成可公开的 demo 数据包（个人字段置空） | 发版前 |
| `check-config.ps1` | 校验 `config.json` 与标准不冲突 + status 读写实测（`-StatusRoundTrip -Restore`） | 改配置后 / 验收 |
| `score.ps1` | 按 `data/criteria.json` 打分（规则分 `score`，与体验分分开） | 评分时 |
| `validate-lib.ps1` | 数据契约校验（零依赖，读 `data/schema.json`）：必填字段 / 枚举 / 唯一键 / 日期 | 改数据后 |

## 站点模板（不是脚本，但改页面要动它们）

| 文件 | 作用 |
|---|---|
| `site-shell.html` | 站点外壳：4 个 hash 路由（`#/daily` `#/all` `#/plans`）+ 图例抽屉 + 底部导航坞 |
| `home-brutal-token.html` | 首页：入口 + DATA 看板（分类分布 / 事件 / 档位 / 标签热度，图表带 aria） |
| `daily-layout-c-finsara.html` | 每日精选：01 主承重跨 / 02 模块阵列 / 03 档案层 / 04 特别栏目 / 05 记忆层 |
| `library-notebook.html` | 全库：搜索 + 分类 + 徽章 + 卡片墙 + 翻页 |
| `plans-shelf.html` | 计划与工作区：11 个组合预设 + 我的工作区 |
| `_detail.js` / `_detail.css` | 卡片详情浮层（点任意卡片打开） |
| `templates/overview.css` / `overview.js` | 旧单页的样式与脚本（`build-overview.ps1` 用；站点不走它） |

## 调用约定

- 全部在工作区根目录用 `& ".\tools\xxx.ps1"` 调用（沙箱下 `pwsh -File` 不可用）。
- `sync-projects.ps1` → `build-samples.ps1` 是**标准重建链**，可随时全量重建；
  `add-repo.ps1` 写的是**原始来源**（seen / meta / snapshots / user-notes），写错要手工修对应行。
- 脚本本体**不可再生**——sync 每次运行会自动备份到 `data\_backup\`，误改后从那里复制回来。
