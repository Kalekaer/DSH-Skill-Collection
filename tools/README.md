# tools/ — 流水线脚本一览

| 脚本 | 作用 | 何时跑 |
|---|---|---|
| `sync-projects.ps1` | 从原始来源重建 `projects.jsonl` + `events.jsonl`（幂等，输入没变自动跳过；`-Force` 强制）。**开头自动备份 tools/ 到 `data/_backup/YYYY-MM-DD/`** | 每次改了原始来源之后 |
| `build-overview.ps1` | 生成 `overview.html`（单文件全内嵌，双击即用）。❗**页面骨架 here-string 里只有 HTML**：CSS 在 `templates\overview.css`、JS 在 `templates\overview.js`（P2-3 后半拆分）→ **改样式/交互请改模板文件**，改完重建即生效 | sync 之后 |
| `query.ps1` | 命令行查询项目库（`-Tag/-Status/-Text/-Top`，支持同义词扩展） | 需要快速查库时 |
| （页内） | **项目对比**：直接在 overview.html 勾选两张卡片 → 右下角「查看对比」，**纯前端、不用命令行** | 用户自己想比两个工具时 |
| `compare.ps1` | **项目对比**（第二阶段⑦）：`.\tools\compare.ps1 A B` 出对比表；`-Similar owner/repo` 找同类；`-Save` 才落盘。**不调 API** | 用户说「比较 A 和 B」「找类似 X」 |
| `add-repo.ps1` | **用户推荐项目入库**（第二阶段⑥）：Agent 先 `web_fetch` 核实，再把字段传进来；已存在则只记用户备注。**脚本本身不联网** | 用户说「这个项目不错：owner/repo」 |
| `compose.ps1` | **工具组合建议**（v3.1 第八节）：按需求从库里挑工具并**按用途分组**（每组最优 1–2 个）。只归类、不编造流程。**不调 API** | 用户说「我要做 ___」 |
| `auto-tag.ps1` | 给缺标签的项目**自动补功能标签/搜索词**（topics + 中文描述片段；不覆盖人工条目）。批量入库后跑 | 用户一次加了多个项目后 |
| `suggest-terms.ps1` | 挖「还没进词表」的新词作为同义词候选（频率 + 示例仓库），**让词表随库增长** | 库每涨 30–50 条 |
| `gaps.ps1` | **搜索缺口闭环**：`-Add "词"` 记下搜不到的词；默认复检并给补词建议 | 用户说「搜不到」之后 |
| `add-plan.ps1` | 把 /tool-stack 配好的一套**固化成网页方案**（查重后写 data/plans.json） | 用户说「写进网页里」 |
| `daily-questions.ps1` | 收尾只输出**真需要拍板**的问题（风险高的项目、发版/删数据/花钱）；其余自动做完不问，输出为空就别问（2026-10-20 改） | **每日流程收尾** |
| `suggest-plans.ps1` | 挖「工具攒够但没有对应场景」的方向 → data/plan-suggestions.jsonl 待批 | 库明显变大后 |
| `check-config.ps1` | 校验 `config.json` 与标准不冲突 + status 读写实测（`-StatusRoundTrip -Restore`） | 改配置后 / 验收 |
| `check-page.ps1` | **真跑页面 JS**（`+ check-page.js`）：语法 → 初始化 → **逐个项目验证卡片能点开** → 筛选 → **hash 路由 ⑪–⑭**（进入/后退/刷新一致、facet 复原、legend 冷启动不白屏、深链开面板）→ 数组 null 扫描。单文件页 JS 出错时页面照常渲染，只有真跑才发现 ｜ **加 `-Real` 再跑真机层**（真 Edge + CDP **两个探针：路由 14 + 页面功能 21～22 = 36 项**；沙箱内 Chromium 起不来 → 打印 SKIP、退出码 2，**不代表页面坏**） | **每次 build-overview 之后，PASS 才算出货** |
| `history-probe-cdp.js` | **真机探针**（真 Edge + CDP，14 项）：真鼠标事件点导航、**真浏览器历史前进/后退**、页面内 `history.back/forward`、筛选进 URL、连续后退不崩 → 结果落 `data\_tmp\hist.json`（退出码 0=全过 / 2=有失败）。**沙箱内起不了浏览器**（需一次性放开权限，或在普通桌面会话跑）。**已被 `check-page.ps1 -Real` 包装** ✓（E-3，2026-10-17） | 改了路由/导航之后，想确认真机行为 |
| `history-probe.js` | 同上，**Electron 窗口版**（备选；`webContents.navigationHistory` 真机后退）。❗**不要**设 `ELECTRON_RUN_AS_NODE`（那会退化成 Node，就不是真浏览器了） | 上面那条跑不动时 |
| `page-smoke-cdp.js` | **页面功能真机巡检**（真 Edge + CDP，21～22 项）：首屏/KPI、搜索与空态、分类、徽章、排序、详情深链 + 一句话理解 + **适合谁**、方案/工作区深链、图例抽屉、`/` 快捷键、对比条、首页图表、外部请求 0、无横向溢出、无控制台错误 → 结果落 `data\_tmp\page-smoke.json`（退出码 0/1/2）。❗**断言是数据驱动的**（从推荐区里找**真带 `aud`** 的条目），绝不写死项目 ✗（写死 `pre-commit` 曾造成假红，2026-10-17 修） | 改了页面交互后（一般不用手敲：`check-page.ps1 -Real` 会跑） |
| `dupes-probe.ps1` | **P2-4 相似度去重侦察**（离线、零安装、**只产候选、绝不改现有数据**）：全部项目两两算相似度（人话层中文 0.40 + 功能标签 0.25 + 仓库名 0.20 + 同二级分类 0.15；**同名不同 owner** 直接抬到 ≥90）→ 候选对 + 连通簇 + 确认/否决台账：`data\dupes-candidates.jsonl`、`data\dupes-clusters.json`、`data\dupes-confirmed.jsonl`、`data\dupes-rejected.jsonl`（退出码 0/1，带 `-SelfTest` 4 项） | 想复查"库里有没有重复 / 换皮马甲"时；**相似 ≠ 重复，确认前不要合并** ✗ |
| `classify-semantic.ps1` | **P2-5 语义分类复核入口**（包装 `classify-semantic.py`）：venv / 模型 / 缓存全在工作区内 → `& ".\tools\classify-semantic.ps1"`（`-SelfTest` 秒级逻辑自检 ｜ `-Fixture` 手工小样本质量门 ｜ `-Json`）｜ 退出码 0 ｜ 1 ｜ **2 = 环境未就绪** | 想用语义向量复核分类时（**质量门不过就别信它的建议** ✗） |
| `classify-semantic.py` | 分析本体（fastembed `BAAI/bge-small-zh-v1.5`）：类目文档 = 一级说明 + 二级名 + 关键词（`--kw 0` = 全部）｜ **绝对下限 sim + 相对差** 双条件 ｜ **无锚点类目判 `no-anchor`**（不冒充 suggest）｜ `--list-models` / `--fixture` / `--selftest` | 同上 |
| `setup-fastembed.ps1` | **一次性**把语义环境装进工作区内（venv → `data\_pyenv`、模型 → `data\_models`、pip 缓存 → `data\_pip-cache`，**不碰系统 Python** ✓）：`-IndexUrl` 默认清华镜像、`-HfEndpoint` 默认 hf-mirror、pip 超时 30s | 换机器 / 重装时（**要放开权限**：沙箱内 python 子进程与 ACL 都不行 ✗） |
| `rebuild-page.ps1` | **写入即重建的统一入口**（P1-16）：sync 投影 → build 页面 → **自检页面真的变新**。写入器写盘后自动调用；`$env:DSH_SKIP_REBUILD=1` 跳过、`-Quiet` 只静默进度（**错误永远打印**）、`-Force` 强制重算投影 | 一般不用手跑；想手动同步就双击根目录 **`刷新页面.cmd`** |
| `smoke-test.ps1` | **功能巡检（工具链层）**：把每个工具用安全模式真跑一遍并断言输出标志（**30 项**）→ `& ".\tools\smoke-test.ps1"` ✓ | 任何时候（改动工具后建议跑）
| `validate-lib.ps1` | **数据契约校验**（零依赖，读 `data/schema.json`）：必填字段 / 枚举 / 唯一键 / `date`=文件名 / 分类；2026-10-19 起含 `data/picks/<date>.jsonl` 与 `data/snapshots/<date>.jsonl` | 改数据或 `schema.json` 之后
| `add-rows.ps1` | **picks / CSV 的唯一写入口**（2026-10-19）：写入前校验字段 + 判重；已存在默认拒绝，`-Update` 刷新旧行，`-DryRun` 只看计划 | 写 `data/picks/<date>.jsonl` / `recommend-log.csv` 时（**不要再手写**）
| `migrate-snapshots-round.ps1` | 给 `data/snapshots/*.jsonl` 补 `round`（同日多轮编号 1..n，幂等）；默认 dry-run，`-Apply` 才写盘 | 一次性迁移 / 以后补历史快照
| `append-guard.ps1` | **append 写前唯一键**（只读，2026-10-19）：picks 按 `date+full_name`、CSV 按 `仓库` 判重；退出码 0=可追加 / 1=已存在（**刷新旧行，不要再追加**）/ 2=参数错误 | 写 `data/picks/<date>.jsonl` 或 `recommend-log.csv` 之前
| `verify-handoff.ps1` | **交接验收**：把 `新会话交接-*.md` 里的数字/路径/编号/口径与实物逐条对账 → `& ".\tools\verify-handoff.ps1"` ✓ | 改完交接后必跑
| `fetch-evidence.ps1` | 抓评分证据（2026-10-21）：deps.dev 项目事实/包映射/SLSA/findings + 可选 Scorecard 18 项 → `data/enrich/evidence.jsonl`；只读、失败回退、按天缓存 | 打分前 / 周报巡检 |
| `weekly-check.ps1` | **周报巡检**（2026-10-20，只读）：列出人话层缺口、同义词待批、缺口词、分类/方案建议、用户自推缺档位、高风险主推荐、缺日、发布态；周报时由 AI 按清单自动处理，只有删数据/超额花费/红线例外才问 | 每周出周报前 |
| `build-weekly.ps1` | **周报页生成器**（2026-10-20）：按 `周报设计-2026-10-20.md` §3 口径算 found / scored / 主推荐 / 新入库 / 星数周增 / 状态变更，换掉样张里的数据与周标签 → `data/site/weekly-<周日>.generated.html`；`-Check` 只算不写（W01 与样张逐项对得上） | 每周一日报落盘后 |
| `build-monday.ps1` | **周一入口**（2026-10-20）：确保上周周报存在 → 构建周一日报 → 顶部中央注入 `WEEKLY / Wxx` 入口；`-DryRun` 只打印计划、`-Page` 在副本上演练注入 | 每周一 |
| `responsive-probe-cdp.js` | **620 / 打印 / reduced-motion 三档真机验收**（2026-10-20，六页 × 三档 = 42 项）：620 宽无横向溢出、打印隐藏交互控件/无溢出、reduced-motion 无运行中动画 → 结果落 `data\_tmp\responsive-probe.json`（退出码 0/1/2；需一次性放开浏览器权限） | 改版式/动效/打印样式后 |

## 调用约定

- 全部在工作区根目录用 `& ".\tools\xxx.ps1"` 调用（沙箱下 `pwsh -File` 不可用）。
- `sync-projects.ps1` / `build-overview.ps1` 是**投影生成器**，可随时全量重建；
  `add-repo.ps1` 写的是**原始来源**（seen/meta/snapshots/user-notes），写错要手工修对应行。
- 脚本本体**不可再生**——sync 每次运行会自动备份到 `data\_backup/`，误改后从那里复制回来。
