# tools/ — 流水线脚本一览

| 脚本 | 作用 | 何时跑 |
|---|---|---|
| `sync-projects.ps1` | 从原始来源重建 `projects.jsonl` + `events.jsonl`（幂等，输入没变自动跳过；`-Force` 强制）。**开头自动备份 tools/ 到 `data/_backup/YYYY-MM-DD/`** | 每次改了原始来源之后 |
| `build-overview.ps1` | 生成 `overview.html`（单文件全内嵌，双击即用） | sync 之后 |
| `query.ps1` | 命令行查询项目库（`-Tag/-Status/-Text/-Top`，支持同义词扩展） | 需要快速查库时 |
| （页内） | **项目对比**：直接在 overview.html 勾选两张卡片 → 右下角「查看对比」，**纯前端、不用命令行** | 用户自己想比两个工具时 |
| `compare.ps1` | **项目对比**（第二阶段⑦）：`.\tools\compare.ps1 A B` 出对比表；`-Similar owner/repo` 找同类；`-Save` 才落盘。**不调 API** | 用户说「比较 A 和 B」「找类似 X」 |
| `add-repo.ps1` | **用户推荐项目入库**（第二阶段⑥）：Agent 先 `web_fetch` 核实，再把字段传进来；已存在则只记用户备注。**脚本本身不联网** | 用户说「这个项目不错：owner/repo」 |
| `compose.ps1` | **工具组合建议**（v3.1 第八节）：按需求从库里挑工具并**按用途分组**（每组最优 1–2 个）。只归类、不编造流程。**不调 API** | 用户说「我要做 ___」 |
| `auto-tag.ps1` | 给缺标签的项目**自动补功能标签/搜索词**（topics + 中文描述片段；不覆盖人工条目）。批量入库后跑 | 用户一次加了多个项目后 |
| `suggest-terms.ps1` | 挖「还没进词表」的新词作为同义词候选（频率 + 示例仓库），**让词表随库增长** | 库每涨 30–50 条 |
| `gaps.ps1` | **搜索缺口闭环**：`-Add "词"` 记下搜不到的词；默认复检并给补词建议 | 用户说「搜不到」之后 |
| `add-plan.ps1` | 把 /tool-stack 配好的一套**固化成网页方案**（查重后写 data/plans.json） | 用户说「写进网页里」 |
| `daily-questions.ps1` | 日报跑完后生成「该问用户的几个问题」（带数据依据，只问要拍板的） | **每日流程收尾** |
| `suggest-plans.ps1` | 挖「工具攒够但没有对应场景」的方向 → data/plan-suggestions.jsonl 待批 | 库明显变大后 |
| `check-config.ps1` | 校验 `config.json` 与标准不冲突 + status 读写实测（`-StatusRoundTrip -Restore`） | 改配置后 / 验收 |
| `check-page.ps1` | **真跑页面 JS**（`+ check-page.js`）：语法 → 初始化 → **逐个项目验证卡片能点开** → 筛选 → 数组 null 扫描。单文件页 JS 出错时页面照常渲染，只有真跑才发现 | **每次 build-overview 之后，PASS 才算出货** |

## 调用约定

- 全部在工作区根目录用 `& ".\tools\xxx.ps1"` 调用（沙箱下 `pwsh -File` 不可用）。
- `sync-projects.ps1` / `build-overview.ps1` 是**投影生成器**，可随时全量重建；
  `add-repo.ps1` 写的是**原始来源**（seen/meta/snapshots/user-notes），写错要手工修对应行。
- 脚本本体**不可再生**——sync 每次运行会自动备份到 `data\_backup/`，误改后从那里复制回来。
