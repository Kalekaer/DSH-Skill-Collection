# CHANGELOG · github-daily-picks

本文件记录 `SKILL.md` 及其配套文件（`references/*`、`audit.ps1`、`TEMPLATES/daily.md`、`PROMPT-daily.md`）的全部改动。
**每次改完 skill，在这里追加一条**；改动后必跑 `audit.ps1`。
**版本策略（2026-10-20）**：`5.x` 一律视为测试版；**`1.0.0` 起为正式版**，版本号从头算。

当前版本指纹：

| 项 | 值 |
|---|---|
| SKILL.md | 476 行 / 51371 B |
| SHA256 | 36872D6C2F2B83E84A3A97681658ECDDFE3B484AE2B5786CD94052D93F681153 |
| 校验 | 167 项全通过（`audit.ps1`） |
| 定版日期 | 2026-10-23 |

---

---

---

---

---

---

---

---

## [1.1.0] — 2026-10-23 · 检索式单一真源 + 当天计划/覆盖门禁 + add-repo 修复

- **README 中英对照**：全篇补英文对照；修订过时口径（5–8 次检索 / 60–100 候选 / S/A/B/C/D 五档 / 日报 01–06 / 代理说明 / `data/queries.json`）；重拍首页截图（20 EVENTS）。
- **检索式单一真源**：新增 `data/queries.json`；`tools/gen-query-docs.ps1` 由它生成 `SOURCES.md` 表格、skill reference、`PROMPT-daily.md` 顺序行（`-Check` 只比对）。
- **当天计划 / 覆盖门禁**：`tools/fetch-daily.ps1` 出计划（`-PlanOnly`）并登记 `web_fetch` 结果（`-Import`）；`tools/check-queries.ps1 -Date` 检查必跑项登记，缺项让清单变红。
- **run-manifest**：新增 `queries` 步骤，覆盖 fail 会阻断收工。
- **add-repo 修复**：快照补 `round` + `date`、写前校验；新增 `-Risk 低/中/高` 与 `-DryRun`。
- **intake-check**：备注里已写明风险等级时不再报「风险等级为空」。
- **检索能力阶梯**：`SOURCES.md` §1.4 新增 HN Algolia 补充源与 L0–L4 阶梯；anysearch 改为可选，web_search 失败只重试 1 次。
- **audit 167 项**：第 17 节新增「CHANGELOG 指纹表结构完整」检查。
## [1.0.0] — 2026-10-20 · 首个正式版（版本号重置：5.x 为测试版）

- **日报 6 块结构轴版**：01 今日头条 / 02 重点报道 / 03 观察面 / 04 边栏观察 / 05 特别栏目 / 06 旧闻新报；浮窗详情。
- **收尾默认不问**：能自动做完的（核 README / 补词表 / 批同义词与分类 / 补人话层 / 缺口复检 / 用户自推档位）直接做完写日志，不再问。
- **周报巡检（全部自动）**：新增 `tools/weekly-check.ps1`；周报时自动处理上述杂事，只有删数据、超额花费、红线例外才问；`TEMPLATES/weekly.md` 的「需要你拍板」改为「AI 自检结论」。
- **全库页打印样式**：补 `@media print`，隐藏侧脊/翻页/搜索/视图切换。
- 校验：`audit.ps1` **166 项全通过**（2 项因包内无 `发布测试/` 目录跳过）。
- **2026-10-21 P2**：新增 `tools/calibrate.ps1`（黄金集一致性/κ/混淆矩阵）、`tools/taxonomy-guard.ps1`（分类四道闸）；周报巡检加 10 条抽样与「其他」占比；`taxonomy.json` 版本 1.6.3。
- **2026-10-21 P1**：picks 支持 `parts`/`evidence`；新增 `tools/fetch-evidence.ps1`（deps.dev + Scorecard，失败回退）；可信度改 Scorecard 归一化、白名单不再加分；findings 仅 MALICIOUS 硬拦。
- **2026-10-21 P0 修正**：分类改为「四道闸自动落」口径统一；对话人格指向 `PERSONA.md`；删掉「已建立 09:00 定时任务」的不实说明；查询次数统一为 3–4。
## [5.1.7] — 2026-10-20 · 日报 6 块结构轴版 + 打印/窄屏修复 ✓

- `tools/daily-layout-c-finsara.html`：日报改为 6 块结构轴版（01 今日头条 / 02 重点报道 / 03 观察面 / 04 边栏观察 / 05 特别栏目 / 06 旧闻新报），详情为浮窗卡片 + 背景模糊；01 只放 S，A 不代行。
- `tools/build-samples.ps1`：同步 6 块数据字段（proof / overflow / allIn / oldFriends / selfPushed）；缺少 `data/site/kiosk-return.js` 时自动去掉该脚本引用（发布包内无此本地产物，避免 404 与假返回按钮）。
- `tools/library-notebook.html`：补 `@media print`（隐藏侧脊/翻页/搜索/视图切换，卡片不跨页断开）。
- `tools/home-brutal-token.html`、`site-shell.html`、`plans-shelf.html`：与 6 块日报一致的导航与统计。
- 包内 `audit.ps1` 第 22 节两条旧断言改为新结构：`01–05` → `01–06`；S/A 档位改为读页面 `"tier"` 数据。
- 校验：`audit.ps1` **166 项全通过**（2 项因包内无 `发布测试/` 目录跳过）。
## [5.1.6] — 2026-10-19 · 清理 `unrated` 语义债 ✓

- `data/criteria.json`：删除“用户推荐项目 / 附加区”两处无用的 `tier` 旧字段；冷却键 `已淘汰`→`D档`、`红线淘汰`→`合规剔除`、`_淘汰`→`_D档`。
- `data/schema.json`：`tier` 枚举收紧为 **S/A/B/C/D**（`dropped` 归 `status`）。
- `sync-projects.ps1` 注释、`compare.ps1` 档位显示、`daily-questions.ps1` 过滤、`build-sim-daily.ps1` 硬编码、`build-samples.ps1` 提示语同步改成“没有档位 / 暂无体验分”。
- 库内 `term-check.ps1` 纳入 `data/criteria.json`、`data/schema.json`、`TEMPLATES/daily.md`；当前 PASS。
- 包内 `audit` 164/2/0 不变。

## [5.1.5] — 2026-10-19 · criteria 术语迁移 ✓

- `data/criteria.json` 的日报上限键：`精品` → `主推荐`、`大厂附加区` → `特别栏目`；4 处说明文字同步。
- `data/schema.json`、`tools/score.ps1`、`audit.ps1`（键读取 + 检查名）、`tests/criteria.Tests.ps1`（用例名）同步迁移。
- 库内新增 `tests/term-check.Tests.ps1`（tests 77 → 78）；包内不含 tests。
- 包内 `audit` 164/2/0 不变。

## [5.1.4] — 2026-10-19 · 周报模板 2.0 ✓

- `TEMPLATES/weekly.md` 重写：**每周一第一次日报后产出上一周**（周一~周日，`W01` 起）。
- 结构：双榜（星数周增 / 本周主推荐 S/A 档）、本周主推荐总览、入库与变化、当前状态（人工填）、下周关注、数据质量、折叠附录。
- 术语严格按 `GLOSSARY.md`；D 档与不再看只给数量+原因类别；不替人写当前状态。
- 包内 README 周报说明同步；库内 `term-check.ps1` 已把周报模板纳入扫描。

## [5.1.3] — 2026-10-19 · 术语清扫同步 + 旧单页修正 ✓

- 同步库内术语清扫：`build-overview.ps1`、`build-samples.ps1`、`score.ps1`、`daily-layout-c-finsara.html`、`library-notebook.html`、`site-shell.html`、`_detail.js|css`、`templates/overview.js|css`；包内 5 页重建。
- 旧单页生成器（包内不发布产物）：档位表补 C 档、D 档改 `<45`、合规红线单独成注；状态五态与 `STA` 映射改成术语表口径。
- 库内新增 `tools/term-check.ps1` 并接入 `verify-handoff`（现为 12 项，基准在 `验收基准.md`），发布包仍只带运行层检查（term-check 为库内专用）。

## [5.1.2] — 2026-10-19 · 日报页 B 档占位格 + demo 样例日报 ✓

- `daily-layout-c-finsara.html`：B 档不足 4 列时补「**NO FURTHER B / 结构留白 / 不凑数**」斜纹格（`.b-cell.b-blank`），不再露出黑底像“漏加载”。
- 新增 `reports/2026-10-19.md` **样例日报**（内容全部来自 demo 项目）：日报页期号从 `00` 变 `01`，「完整日报」浮层有内容；`.gitignore` 只放行这一份，用户自己的日报仍不随包。
- 「完整日报」浮层标题改成**动态日期**（原来写死 `2026.10.18`）；真机探针确认浮层能打开、正文 1271 字。
- demo 数据补 2 条 `first_seen=2026-10-19`（`NandhaKishorM/laya`、`storytold/pdfcraft`）：日报头 `ENTRIES` 从 `0` 变 `2`，「当日入库全名单」不再空；`examples/demo` 同步重建（事件 20 条）。
- README / QUICKSTART / examples/demo/README 同步改口径（有样例日报、没有快照）。
- 旧单页生成器（`build-overview.ps1` / `templates/overview.js`）清掉「未评档」文案：筛选项、图表注释、规则表统一改成「待评估」/ 补 D 档行；数据里的旧备注也做替换；`audit` 对应检查改为「页面无未评残留」。
- 同步重建库内与包内日报页；`audit` 两边仍 0 红。

## [5.1.1] — 2026-10-19 · 发布包依赖补齐（用户流程不再撞缺文件）✓

- **补进包**：`rebuild-page.ps1`（6 个写入器 + 日报第 7 步）、`add-rows.ps1`（日报写 picks/CSV）、`run-manifest.ps1` + `reconcile.ps1`（日报第 8 步对账）、`mark-status.ps1`、`TABLE.md`（CSV 列说明）。
- **`check-drift.ps1`**：上述脚本从 `$devOnly` 移出；新增「包内引用缺失」检查——扫包内 `*.ps1/*.md` 里真正执行的 `& (P 'tools\…')` / `& ".\tools\…"`，目标不存在即红；注释与 here-string 里的说明不算。
- **`build-overview.ps1`**：写盘前 `New-Item -ItemType Directory` 建 `legacy/`——发布包不带该目录，旧代码会报 `Could not find a part of the path`。
- **`run-manifest.ps1`**：写清单前自动建 `data/runs/`（包内没有该目录，原样会报同样的路径错误）。
- **`reconcile.ps1`**：`reports/` 里没有当天日报时跳过「日报 vs CSV」，不再把 CSV 全报成「B 独有」；demo 的 `recommend-log.csv` 改成与 picks 同日（2026-10-19）的 5 条 S/A，首次装包跑对账即 0 问题。
- **移除 `check-page` 引用**：`SKILL.md` 三处改成 `audit.ps1` 第 22 节 / `validate-lib`；`add-intro`、`add-plan` 的 `-Sync` 分支改为提示（兼容参数保留）；`make-demo` 的示例命令改成 `validate-lib.ps1`。

## [5.1.0] — 2026-10-19 · 发布包同步：站点版 + demo 重建 ✓

- **发布形态**：D1=A，只发新站点 —— 根 `index.html`（外壳 + `<base href="data/site/">`）+ `data/site/` 5 页；旧单页 `legacy/overview-v5.html` 不再随包，`overview.html` 保留为同一入口的别名。
- **脚本同步**：`build-overview` / `check-page` / `sync-projects` / `auto-tag` / `add-repo` / `add-intro` / `workspace` / `check-config` / `add-plan` / `make-demo`，新增 `tools/templates/overview.css|js`、`build-samples.ps1`、`score.ps1`、`validate-lib.ps1` 与站点模板 6 件。
- **demo 重建**：15 条项目 / 5 条主推荐 / 9 条 picks / 5 行 `recommend-log.csv` / 15 行 `seen.jsonl` / 1 份 `meta`；`make-demo` 改为「个人字段置空（note / user_notes）而不是删字段」，保证投影层字段齐全。
- **audit 166 项**：第 22 节 18 条页面检查从旧单页改指站点（入口 / 4 路由 / 日报 01–05 / 全库搜索分类 / 计划页 / BUILD-STAMP / 首页条数 / 图表 aria / 未评档与收藏残留）；`build-samples` 统一注入 `BUILD-STAMP`，首页图表补 `role="img"` + `aria-label` + `chart-note`。
- **文档与素材**：README / QUICKSTART 改为站点口径；3 张截图重拍为 `docs/screenshots/1-home.jpg`、`2-daily.jpg`、`3-plans.jpg`；新增 `THIRD-PARTY.md`（字体 OFL + NASA 公有领域图）。
- **已知差异**：包内 `audit.ps1` 是「站点版」（第 22 节与库内单页版不同）。

## [4.10.46] — 2026-10-19 · P1 收尾：唯一写入器 + 快照 round ✓

- **写入器**：新增 `tools/add-rows.ps1`，picks / CSV 不再手写：写入前校验字段（必填 / 枚举 / 分数范围 / 日期）并判重；已存在默认拒绝（exit 1），`-Update` 才刷新旧行，`-DryRun` 只看计划；写盘保留每行原行尾、无 BOM。
- **流程**：`PROMPT-daily.md` 第 6 步第 5/6 项改为强制走 `add-rows.ps1`；`SKILL.md` 把「append 前唯一键」升级为「唯一写入口」；`data/README.md` 同步。
- **快照 round**：`data/snapshots/<date>.jsonl` 新增 `round`（同日多轮 1..n）；一次性迁移 534 行（备份 `data/_backup/2026-10-19/snapshots-before-round/`），`tools/migrate-snapshots-round.ps1` 幂等；schema 1.3 唯一键 `date+full_name+round`；`reconcile.ps1` 改报重复键与缺 round。
- **回归**：新增 `tests/append-writers.Tests.ps1` 9 项、`tests/snapshots.Tests.ps1` 3 项；`tests` 67 → **79**。
- **验证**：`validate` 0 违规（7 个受管文件）、`tests` 79/0、`audit` 166/0、`verify` 14/0、`reconcile` 0、`drift` 0；页面已重建（legacy 665.1 KB）。

## [4.10.45] — 2026-10-19 · P1：picks 进 schema + append 写前唯一键 ✓

- **问题**：`picks` 不在机器 schema 内，旧字段（`repeat` / `prev_tier` / `tier_changed`）只靠代码兜底；`picks` / `recommend-log.csv` 都是追加写，同日重跑/失败重试可能写重复行，等 reconcile 才发现。
- **schema**：`data/schema.json` 新增 `data/picks/<date>.jsonl`（必填 `date` / `full_name` / `tier` / `score` / `risk` / `action`；唯一键 `date+full_name`；`action` / `daily_status` / `quota_block` 枚举）。
- **校验**：`tools/validate-lib.ps1` 支持 `<date>` 目录展开、复合唯一键、`date`=文件名、`$ref`→`$defs.enum` 与数值范围；当前 picks 94 行 0 违规。
- **写前检查**：新增 `tools/append-guard.ps1`（只读）：picks 按 `date+full_name`、CSV 按 `仓库` 判重，退出码 0=可追加 / 1=已存在（应刷新旧行）/ 2=错误；`PROMPT-daily.md` 第 6 步与 `SKILL.md` 已接入。
- **回归**：新增 `tests/picks.Tests.ps1` 8 项（真库契约、旧行缺字段仍可解析、date 不一致反例、picks/CSV 守卫正反例）；`tests` 59 → 67。

## [4.10.44] — 2026-10-18 · 满额不降档：over_quota 独立于 SABCD ✓

- **问题**：S/A 超 8 条或 S 超 3 条时，若把多出来的降成 B，档位就变成“名额桶”，数据会假。
- **修复**：`tier` 只表质量；新增 `daily_status=over_quota` / `quota_block=s_cap|total_cap`。多出的 S/A 保留原档，不算推荐、不启动 7 天冷却，版面只列「达线未刊」。
- **构建**：`build-samples` 按 S≤3 / 合计≤8 硬切；`picks` 保留全部 S/A；`D.overflow` 单独输出；头部显示「A 9（刊8）」这类“找到/已刊”计数。
- **同步**：`sync-projects` 的 `recommended` / `last_recommended` / `recommend_count` 只看 published，over_quota 不计。
- **文档**：`RUBRIC.md` §3、`PROMPT-daily.md`、`data/README.md`、`SKILL.md` 同步。
- **验证**：临时构造 9 条 A，页面 `af=9 / a=8`、overflow 1、头部 `A 9（刊8）`；恢复真实数据后 `a=4/af=4`。

## [4.10.43] — 2026-10-18 · P1：S/A/B 分区 + C/D 名单 + 推荐过标记 ✓

- **S/A/B**：C 版主栏容纳全部 A（4 条时不再把第 4 条塞到下方）；B 档单独一排小卡；D 版主栏同理，B 卡放简报区。
- **C/D**：只列名字小卡，放在右侧窄栏（C 的 `#cdlist` / D 的 numbers 列）；档位小标 + 项目名，点开详情。
- **推荐过**：卡片角标显示 `A · 推荐过`；档位变了显示 `B → A`；首次推荐不标；不改变卡片位置。
- **数据**：`build-samples` 把 `watch`（B/C）注入 `D`；`New-Card` 带 `repeat` / `prev_tier` / `tier_changed`。
- 校验：C/D 的 B 卡、C/D 名单均能点开详情；10/10 布局断言通过；`audit` 166/0、`config` 17/0、`tests` 52/0、`verify` 14/0。

## [4.10.42] — 2026-10-18 · 日报头 SABCD 计数放大 + 卡片档位角标 ✓

- C 版头：日期/星期右侧的 `S/A/B/C/D` 改成**彩色药丸**（S 荧光黄、A 品红、B 青、C 橙、D 灰）。
- D 版头：右上角同类彩色计数条；不再是一行小字。
- C/D 卡片：新增**独立档位角标**（大号 S/A/B/C/D，右上角，各自颜色）；C 用绝对角标，D 用内联大角标避免裁切。
- 详情浮窗：`pd-b.tier` 的 A/B/C/D 也补了对应颜色。
- 数据：`stats` 已有 `c/d`；B/C 仍要等新机制日产生。
- 校验：C/D 截图正常；`audit` 166/0、`config` 17/0、`tests` 52/0、`verify` 14/0。

## [4.10.41] — 2026-10-18 · 日报头补日期/星期/SABCD 计数 ✓

- C 版：DAILY 右侧新增 `mastmeta`（`2026.10.18` + `周日 · NO.08` + `S/A/B/C/D` 条数）。
- D 版：右上 meta 增加一行 `S · A · B · C · D` 计数，保留日期/星期/候选/退稿。
- 数据：`stats` 增 `c`/`d`；D=当天退稿数，B/C 来自 watch 数据（新机制后才有）。
- 校验：C/D 头正常渲染；`audit` 166/0、`config` 17/0、`tests` 52/0、`verify` 14/0。

## [4.10.40] — 2026-10-18 · P0：SABCD 数据层 + 7/14/90 冷却 + 二次推荐字段 ✓

- **分档**：S≥80 / A65–79 / B**55–64** / C45–54 / D<45；`score.ps1 Get-Tier` 返回 A/B/C/D，`criteria.json` 与测试同步（52 例）。
- **日报数据**：要求给**所有过筛候选**评分，`picks` 写 S/A/B/C/D 全部（不只推荐与淘汰）；B/C 暂不上版面（P1），D 进退稿区。
- **冷却**：已推荐 30→**7 天**；普通淘汰 90→**14 天**；红线/合规淘汰保持 **90 天**；owner 3 天不变。
- **二次推荐**：7 天到期不等于回锅，必须有新信号（release / 功能更新 / 涨星 ≥10%）；picks 增 `recommend_count` / `repeat` / `prev_tier` / `tier_changed`，档位没变不强调。
- **文档**：`RUBRIC.md` §3/§5、`PROMPT-daily.md`、`data/README.md`、`README.md`、`SKILL.md` 口径同步。
- 说明：历史数据没有 B/C，补不了；新机制从下一期开始。P1 才是 S/A/B 卡片 + C/D 名单版面。

## [4.10.39] — 2026-10-18 · 修复日报 C/D 版式不轮换 ✓

- **不是故意**：`pick-daily-layout.ps1` 早就有，但**没有接进构建**；外壳 `PAGES.daily` 硬编码 C，`#/daily` 永远 C，D 只能手点；C 按钮也指 `#/daily`，默认是 D 时切不回 C。
- **修复**：
  - `pick-daily-layout.ps1` 从哈希改为**按日轮转**：连续两天保证不同（10-16 C / 10-17 D / 10-18 C …）。
  - `build-samples.ps1` 按 `$Date` 调 picker，把选中文件/key 注入外壳（`DAILY` / `DAILYKEY`）。
  - `#/daily` 当日轮换版；`#/daily/c` / `#/daily/d` 手动指定；换骨按钮 C/D 状态与切回都正常。
- 验证：10-18 默认 C、10-17 默认 D；C/D 切换与回默认 5/5。

## [4.10.38] — 2026-10-18 · 全站动效第一轮（基础/首页/日报/线索墙/货架/浮窗） ✓

- 外壳：路由切换短促擦除（`#wipe`，0.42s，首屏不触发，减少动效关闭）；详情浮窗：面板上浮 + 一次扫描线 + 标题色差 + 标签错落。
- 首页：ARCHIVE 标题错落入场、桌面鼠标光斑（低强度）+ 背景微视差 + HUD 坐标；减少动效/触屏关闭。
- 日报 C：奶油纸版卡片 stagger 入场；D：头条一次 Glitch + 报头一次扫描线 + 卡片 stagger。
- 线索墙：红线 `stroke-dashoffset` 逐段绘制；计划货架：纸箱 stagger + hover 抬升。
- 所有效果只用 CSS transform/opacity + 少量原生 JS；补齐 `prefers-reduced-motion`；不改页面结构/数据/路由。
- 校验：路由擦除/详情动画 10/10；首页光斑/HUD、纸箱入场、红线绘制 6/6；C/D/plans/library 控制台 0 错误。

## [4.10.37] — 2026-10-18 · 线索墙 hover 重排导致卡片闪烁 ✓

- 原因：`.wpins > .wcard:hover{margin-top:inherit}` 在鼠标经过时把卡片的**错位 margin** 重置，多列布局随即整片重排；小窗口 2/3 列尤其明显，卡片乱跳导致点不中。全屏 4 列 + 空间大，现象轻。
- 修复：hover 只改 `transform: translateY(-4px)`，**不参与布局**；同时修掉一条被引号包住、实际未生效的 `.wcard:hover{box-shadow...}` 规则。
- 验证：小窗口点击目标卡，详情正常打开，scrollHeight 稳定 `20330 → 20330`；重建后全库 559.4 KB。

## [4.10.36] — 2026-10-18 · 「品味」搜不到 → 补同义词 ✓

- 诊断：库内**没有任何字段含字面「品味」**；最接近的是 `Leonxlnx/taste-skill`（一句话是「一套「审美」技能包」）。搜索是**字面/分词匹配，不是语义模型**，缺同义词所以 0 命中——是数据/同义词缺口，不是索引坏了。
- 修复：给 `taste-skill` 补 `function_tags`（审美 / 网页设计）、`user_keywords` / `synonyms`（品味 / taste / 审美 / 设计感 / 网页设计），并重建投影与页面。
- 验证：搜「品味」命中 1、「审美」命中 2、「taste」命中 1。
- 说明：搜索仍是字面匹配；其他同义词需要在项目 `synonyms` 或词表里补，不能自动理解。

## [4.10.35] — 2026-10-18 · 标签接线到卡片/详情/搜索 + 线索墙滚动条 ✓

- `build-samples.ps1` / `build-sim-daily.ps1` 的卡片数据新增 `tags`（function_tags）、`kw`（user_keywords）、`syn`（synonyms）；239 条全库全部带出。
- `_detail.js` / `_detail.css`：详情卡新增「标签 / 搜索词 / 同义词」chips，不再只有 L1/L2 分类徽章。
- 全库搜索 `filtered()`：纳入 `tags` / `kw` / `syn` / `topics` / `what` / `problem` / `uses` / `aud`；查询按空格/标点分词并**必须全部命中**；占位文案改为「搜名称 / 分类 / 标签 / 用途（空格分词）」。
- 线索墙搜索用 `data-search`（含标签）并按分词命中；不再只搜 `textContent`。
- 线索墙自绘滚动条加**拖拽**（pointerdown/move/up + setPointerCapture），保留点击轨道跳转；原生滚动条仍隐藏但有可用替代。
- 校验：详情 chips 6 个（solid-glass 含 `agent-ui`）；搜 `agent-ui` 命中 1、搜 `AI 绘画` 命中 19；线索墙搜 `agent-ui` 显示 1/239；拖动滚动条 `0 → 2954`。
- **未改**：自动标签写入 `tags-vocabulary.json` 的候选机制（按用户要求先记着）。

## [4.10.34] — 2026-10-18 · 官方/大厂规则进 RUBRIC + 图例动态 ✓

- `RUBRIC.md` 新增 **§8 官方 / 大厂（owner 白名单）**：白名单 30 组织、只降验证成本不加分、附加区可选 ≤3、`unrated`、不计入 S/A/B、硬门禁不放宽；成为唯一口径。
- `PROMPT-daily.md` / `TEMPLATES/daily.md` 的官方段改为**引用 `RUBRIC.md` §8**，不再各写一套；`data/README.md` 字段说明同步。
- `tools/build-overview.ps1`：图例里的白名单组织数、当前官方条数改为**实时计算**（原来写死 30 / 8）。
- 校验：白名单 30 组织、库内 8 条 official、0 错标；07 模拟页官方区 4/4 可点；真实页无官方节时自动隐藏。

## [4.10.33] — 2026-10-18 · 采纳 Q2b/Q3s + 多端入口 + 周报待人工 ✓

**检索式（`SOURCES.md`，用户 2026-10-18 批准）**
- 新增 **Q2b**：`stars:200..800+pushed:>{D7}`，每天必跑，补中间星段（10-16 实测池子 641 条、头 10 条 6 条新面孔）。
- 新增 **Q3s**：`topic:{TODAY_TOPIC}+stars:200..800+pushed:>{D14}`，仅当 Q3 新面孔 <3 或 `total_count` <10 时加跑；不换方向。
- 占位符加 `{D14}`；日耗更新为 4–6 次（周四/周六 5–7）。

**流程/输出**
- `PROMPT-daily.md` 步骤 2 改为 Q1 → Q2 → Q2b → Q3（Q3s 条件触发）。
- 硬性要求加「多端/家族仓库必须写平台入口」；今日日报已补 `🪟 Windows 入口：jev-chat/jev-chat-windows`。
- `TEMPLATES/weekly.md`：已试用表默认 `待试`，附 `mark-status.ps1` 用法，禁止编造结论。
- `data/runs/2026-10-18.md` 与 `reports/2026-10-18.md` 标注 ① ② 已采纳、③ 已补入口、④ 待人工。

**校验**：`audit` 166/0、`check-config` 17/0、`tests` 50/0、`verify-handoff` 14/0。`SKILL.md` 未改，指纹不变。

## [4.10.32] — 2026-10-18 · 标签自动化 + 日报条目全部可点 ✓

**标签**
- `PROMPT-daily.md` 删掉「只预览 / 不要 -Apply / 等你确认」的旧收尾，改为**入库即自动补标签**。
- `tools/auto-tag.ps1`：加质量闸（长句、宽词、`基于/本次/支持…` 开头、纯数字开头一律拒绝）；加**二级分类兜底**与**第二次复核**（写盘后重读，仍缺的用 `category.l2` 补）；新增 `-NoRebuild` 防递归。
- `tools/rebuild-page.ps1`：sync 后自动跑 `auto-tag -Apply -NoRebuild`，再二次 sync，再重建两套页面。所有写入器（add-repo / add-intro / workspace…）都自动补标签，不再要人确认。

**日报可点击**
- `build-samples.ps1`：从 `reports/<date>.md` 里找出所有提到的仓库，生成 `related` 数据与「本日报相关」按钮（picks / 退稿 / 老朋友 / 提到的都含）。
- C/D 页面新增 `relbar` 按钮条；**完整日报浮层顶部也放同一条**，打开浮层即可点；`_detail.js` 加 `findCard`（兼容页面变量 `D`），点任意相关项目直接复用库里详情卡。
- 今日实测 14 个相关按钮，含 `storytold/photocraft` 等老朋友、退稿、红线仓库；点开详情正常。

**验证**：`audit` 166/0；`auto-tag -Apply` 后 239 条库中可补 8 条、复核仍缺 0；`_rel-check` 6/6 PASS；C/D 91–92 KB。

## [4.10.31] — 2026-10-18 · 对话人格改造 + 网页完整日报 + 播报瘦身 ✓

**背景**：日报改由网页「每日精选」交付，对话不再复述全文；对话改成「雌小鬼猫娘开源情报员」短播报。

**改动**
- `SKILL.md` §一：角色增加猫娘人格与「网页正式交付 / 对话只播报」分工；§八：删掉旧的 ≤5 行摘要纪律，改为 **3–5 行播报 + 网页引导**（含示例、失败如实说、不伪造），入口卡片只 `present overview.html`、不再附 `reports/*.md`；§十三自查同步。
- `PROMPT-daily.md`：角色/步骤 9 汇报改为猫娘播报；新增**步骤 7「重建网页日报」**（`rebuild-page.ps1`：sync → 旧版 → build-samples → data/site），运行日志与汇报顺延为 8/9；硬性要求补「对话不复制全文」。
- `AGENTS.md`：对话约束改为「≤5 行猫娘播报（含网页入口）」。
- `TEMPLATES/daily.md`：注明 `reports/*.md` 是网页「完整日报」浮层的内容源，对话不复制。
- `tools/build-samples.ps1`：构建时读 `reports/<date>.md`，用 `ConvertFrom-Markdown` 转 HTML，注入每日精选 C/D 的 `FULLREPORT` 占位。
- `tools/daily-layout-c-finsara.html` / `daily-layout-d-fonte.html`：新增「📄 完整日报」按钮 + 浮层（`_detail.css/js` 共用）；网页里可看 12 项全文/命令/坑。
- `.dsh/skills/tool-stack/SKILL.md`：加「说话人格」小节与示例开场；配工具的 3 行摘要/三件事/一个必答问题/入口骨架不变。

**校验**：`audit` 166/0；网页浮层实测打开/含标题/含命令块/关闭均通过。

## [4.10.30] — 2026-10-18 · 规则口径对齐（歧义红线 / owner 降权 / 大厂附加区）✓

**背景**：`criteria.json` 与代码已实现三条规则，但 `RUBRIC.md` / `TEMPLATES/daily.md` 没回写，导致「按 RUBRIC 引用」时口径打架。

**改动**
- `RUBRIC.md` §1.1 后新增 **§1.2 歧义信号**：`crack/cheat/miner/malware/exploit/hack` 命中 → `researching` 待复核，**不直接 dropped**；拿到可核查证据才转 dropped；词边界匹配。
- `RUBRIC.md` §5：同一 owner 3 天内从「让位」改为 **−10 降权、不消失**（与 `criteria.json`「同owner降权」/ `score.ps1` `Get-DownrankedScore` 一致）；降权后仍达线才可入推荐区，且最多 1 个。
- `TEMPLATES/daily.md` 新增 **「🏢 官方 / 大厂动态（附加区 · ≤3 条）」** 区块：`unrated`、🆕、不计入 S/A/B 与推荐计数；红线/刷星/许可仍照拦。
- `PROMPT-daily.md` 硬性要求补一条附加区说明。
- `SKILL.md` 第五节同步 owner 冷却措辞。
- `audit.ps1` 两处冷却文案正则放宽为「3 天内最多…1 个」，与新措辞一致（TOTAL_CHECKS 不变）。

**校验**：`audit.ps1` 166/0、`tests/run-tests.ps1` 50/0。

## [4.10.29] — 2026-10-17 · UI 第一轮：设计系统样张 + 首页中央几何导航（配色扩权）✓

**范围**（用户 brief §六 要求"第一轮只交样张 + 首页"）：只动 **2 个文件** —— `tools/templates/overview.css`（+78 行追加层）、`tools/build-overview.ps1`（首页 § 01 前插入 29 行 hub）。**其他区一行未动** ✓，**数据结构 / 业务逻辑 / 路由未动** ✓

**交付**
- `tools/design-sample.html`：**独立**设计系统样张（不进发布页面）——基础色/识别色/焦点色/8 个辅助色/11 个一级分类色相（带真实条数）/4 种内联 SVG 纹理/字阶与不对称构图/4 件动效（含 reduced-motion）。真机截图：`data/_tmp/shot-sample.png`
- 首页新增 `#hub` **中央几何导航**：三个主入口（每日精选 / 完整项目库 / 计划与工作区）用**真链接**（可 Tab、可复制、可后退），带真实统计（`$($nS+$nA)` 条已推荐 / `$nTotal` 条 / `$planCount` 个方案）；图例降级为次级小入口 ✓；路由 `#/picks #/all #/plans` 不变
- CSS 追加层：扩色 token + 分类色相 + 纹理 + 段头规律 + 动效 + `prefers-reduced-motion`
- 文档同步：`页面分级设计-2026-10-16.md` 新增 **§11 配色扩权修订**（取代旧的"只有黑白黄红"纪律，含四条新硬约束）✓ 避免规范互相矛盾

**实测（第一轮验收）**
| 检查 | 结果 |
|---|---|
| `ui-check`（impeccable + 阳性对照） | **0 违规**（对照 51 条注入违规被抓到）✓ |
| `check-page` 桩 ①–⑰ | **PASS**（钩子全保住：KPI 4 数、分类、徽章、详情、对比、路由、图例、封面…）✓ |
| `check-page -Real` 真机 36 项 | **全过**（真鼠标点导航切视图 ✓ 无横向溢出 ✓ 无控制台错误 ✓ 外部请求 0 ✓ 图表 aria 4 图/6 摘要 ✓） |
| `audit` | **166 / 0 / 0** ✓（P2-9 路由骨架、P1-14 stamp、P1-17 新鲜度、图表 aria 全过） |
| 页面体积 | 632,173 B → **640,512 B（+8.3 KB）**，仍单文件、外部请求 0 |

**过程中被护栏拦下并修正的（价值证明）**
1. 第一版 CSS 被 `ui-check` 判 **6 条违规** ⇒ 脚本按设计**自动回滚**（页面瞬间回到基线 617.4 KB ✓）：`ai-color-palette`（紫色**文字**用在标题）+ `cramped-padding`×5（我新加边框/底色的容器没留内边距）⇒ 改为"辅助色只做色带/边框/底纹"+"容器补 `padding`"后 0 违规 ✓
2. `check-page` 桩 ①–⑰ 在改动后仍然 PASS ⇒ 证明"保留旧类名钩子"的策略有效（新增都是包裹/装饰层）

**未做（第二、三轮）**：完整项目库的标签分布图/DSH 星团/分类图与四向联动、每日精选视图、计划与工作区、其余三个区的版式节奏
## [4.10.28] — 2026-10-17 · P2-5 规则/硬证据路线：改 3 条 → **1 条生效**，2 条留下机制性残留 ✗

**背景**：语义路线被自己的质量门否决（见 [4.10.27]）⇒ 真改数据走规则路线，从 `classify-probe` 的 B=21「有更强候选」清单出发。

**产物（零改动）**：`data/classify-fix-proposals.jsonl`（21 行，含 `margin / cur_score / sug_score / verdict / gate_ok / why / one`，规则可复算）
- verdict：**apply 0** ｜ review 5 ｜ review-fallback 5 ｜ skip-gate 3 ｜ skip-weak 8
- 规则：`skip-weak` = margin < 4 ｜ `skip-gate` = 候选属 DSH 生态但正文无 `dsh/deepseek-harness/cordis`（违反 taxonomy `_类目门槛`）｜ `review-fallback` = 当前在兜底类目 ｜ `apply` = margin ≥ 6 且非兜底 ｜ `review` = 4–6
- **最有价值的一次拦截**：`AbdelStark/awesome-typesafe-jev`（margin **8**，看着最该改）被 `skip-gate` 挡下 —— 候选到 `DSH 生态/DSH 技能`，但正文没有 `dsh / deepseek-harness / cordis` ⇒ **不许进** ✓ 否则当场破掉之前专门修的"通用词跨生态误吸"（taxonomy 变更记录那条，当时影响 7 条）

**人工筛后只改 3 条**（改法是给人话层加"**只在目标类目关键词表里**"的强信号；改前先做**关键词归属校验**：三个词各自只命中一个类目 ✓）
| 条目 | 加的词 | 结果 |
|---|---|---|
| `PowerShell/PSScriptAnalyzer` | `代码分析` | 其他/其他工具 → **开发/代码分析** ✓ |
| `HelixDB/helix-foundry` | `数据工作台` | 仍是 数据/数据库存储 ✗ |
| `ImageMagick/ImageMagick` | `图片编辑` | 仍是 AI/AI绘画 ✗ |

**为什么后两条没翻过来（机制，写清楚免得下次白试）**：分类是**按分数取最大**，新增词不会覆盖已有强信号 ——
- `ImageMagick` 原有 `图片处理` 正好是 **AI/AI绘画** 的关键词（交接 §5 #38 记过这个坑），权重盖过我加的 `图片编辑`
- `helix-foundry` 原有 `数据分析` / `本地数据` 与 数据/数据库存储 的分数咬得很紧
⇒ 要真翻只能**替换**冲突标签，但 `图片处理` 对 ImageMagick 本身是**准确**的搜索标签，砍它是削足适履 ✗ ⇒ **不做**，记为残留；根因在 taxonomy 的关键词映射（全局影响，需单独评估）✓

**新踩的坑**：原始层 `data/human/function-tags.jsonl` 的 `function_tags` 是**数组**（`["analyzer","c#",...]`）而**不是字符串** ⇒ 第一版正则只匹配字符串、**只改了 `source` 没加词**，而 **audit 全绿**（它不查"改了到底有没有生效"）⇒ 靠 "before/after 分类对照" 才发现 ✗（踩坑 #7 同族：`data/human/*` 形状要逐个看）

**回滚机制实测生效** ✓：应用数与期望不符时自动 `throw` + 还原备份（第一次 0 命中就是这么救回来的）

**验证**：audit **166/0/0** ✓ ｜ 页面已重建（`build 2026-10-17 02:18`）｜ 备份 `data\_backup\2026-10-17\function-tags-before-p25fix.jsonl` ✓ ｜ 未动的 **8 条 skip-weak + 3 条 skip-gate 保持原样** ✓
## [4.10.27] — 2026-10-17 · P2-5 语义分类复核（环境 + 工具 + **质量门否决**）✗

**结论先说**：语义路线的**环境与工具都跑通了**，但它**没过自己设的质量门**（手工小样本 top-1 **3/8 = 38%** < 门槛 75%）⇒ **不产出改类建议**，P2-5 的实际数据改动**仍走规则/硬证据路线**（`classify-probe` 的 B 列表）✓

**新增（3 个文件，全部 dev-only、不进发布包，已登记 `$devOnly`）**
- `tools/setup-fastembed.ps1`：一次性把环境装进**工作区内**（venv `data\_pyenv`、模型 `data\_models`、pip 缓存 `data\_pip-cache`）⇒ 不碰系统 Python ✓；`-IndexUrl` 默认清华镜像、`-HfEndpoint` 默认 hf-mirror、pip `--timeout 30`（上一轮就是没超时挂了 10 分钟 ✗）
- `tools/classify-semantic.py` + `tools/classify-semantic.ps1`：类目文档 = 一级说明 + 二级名 + 关键词；**绝对相似度下限 + 相对差**双条件；**无锚点类目判 `no-anchor`**；`--selftest`（14 项）｜ `--fixture`（质量门）｜ `--list-models` ｜ `--kw`
- 产物：`data/classify-semantic.jsonl`（229 行，只读证据）——**不改任何现有数据** ✓

**模型替换（偏离原计划，有据）**：计划里的 `intfloat/multilingual-e5-small` **不在 fastembed 支持列表**（41 个模型里没有）⇒ 查表后改用 **`BAAI/bge-small-zh-v1.5`**（中文优化，91 MB）✓

**校准过程与数据（v1 → v2）**
| | v1 | v2（全量关键词 + 兜底类目进候选） |
|---|---|---|
| suggest | 136（其中 23 条是兜底类目造成的**假信号** ✗） | 45 |
| weak / no-anchor | — | 56 / 23 |
| 手工小样本 top-1 | 未测 | **3/8 = 38% ⇒ 未过门** ✗ |
| 自检 | 4 项（2 项是测试自己写错） | **14/14 ✓** |

**为什么是"路线不行"而不是"再调调"**：两次自伤（`--kw 6` 截断了 `mcp`/`skill`；兜底类目 `其他工具` 根本不在 `一级分类` 里、永远不可能被预测）修掉后**通过率一点没变**；失败样本显示的是**类目粒度 vs 小模型能力**的差（`文件搜索器 → 办公/PDF 与阅读`、`Markdown 笔记 → AI/AI办公`（taxonomy 里那个已知坏关键词 `笔记`））✗

**本轮踩的坑（一条都别再犯）**
1. **沙箱内跑 pip 必失败** ✗：子进程下载到 `data\_tmp` 的临时文件被 **ACL 锁死**（`Permission denied` + 4 个临时目录**删都删不掉**）⇒ 装环境必须**一次性放开权限**，且 `PIP_CACHE_DIR` / `TMP` / `TEMP` 都要显式锁进工作区（否则缓存撒到 `%LOCALAPPDATA%`，实测 317 MB ✗ 已按用户要求删除）
2. **`$p.ExitCode` 为 `$null` 时被我当成 0（成功）** ✗ ⇒ pip 明明失败却报"成功"；改成**只认输出里的 `Successfully installed`**（踩坑 #24 同族，第三次栽）
3. `Start-Process` 会把 **`-c` 一行式按空格拆开**（`SyntaxError: import`）⇒ 改用 `-m pip show`
4. numpy 的 **`float32` 不能进 JSON** ⇒ `float()` 转换
5. `py.exe` / `pwsh.exe` / `git.exe` 在沙箱内**一律"拒绝访问"** ⇒ 外部程序只能走 `Start-Process`
6. **中文进 shell 引号咬了 4 次**（含一次 `#` 注释把调用后半截注释掉、一次右括号被注释）⇒ 中文批量改动一律走"补丁文件 + 按 ASCII 锚点 splice"✓
7. 多行锚点是 LF 而文件是 CRLF ⇒ **锚点也要按文件行尾归一化**再匹配
8. CDP/子进程类工具要把**未捕获异常、未处理的 Promise 拒绝、WS 断开**全兜住（"没输出 ≠ 没错"）

**未做（交接给下一步）**：`tools\README.md` 三行、交接文档 §11.7、以及 P2-5 的规则路线（B 列表逐条改，需用户过目 diff）
## [4.10.26] — 2026-10-17 · P2-4 相似度去重**侦察**工具（只产候选，不动数据）✓

**新增 `tools/dupes-probe.ps1`**（P2-4 的前一半：先给证据、**不做自动合并** ✓）
- 信号与权重（可解释、可复算，**全部写进输出**）：人话层中文 **0.40** ｜ 功能标签 **0.25** ｜ 仓库名 **0.20** ｜ 同二级分类 **0.15**；**同名不同 owner** 直接抬到 ≥90 并标 `exact-name`（fork / 改名马甲的第一信号）
- 产物**只新增**：`data/dupes-candidates.jsonl`（派生物，整份重写）｜`data/dupes-clusters.json`（连通分量）｜`data/dupes-confirmed.jsonl` / `data/dupes-rejected.jsonl`（人工台账，append-only）
- **绝不改 `data/projects.jsonl`**、不合并、不删条目 ✓；不联网、零安装 ✓
- **首次实测（229 条 / 26,106 对）**：≥55 分候选 **4 对**、连通簇 **3 组**
  - 最高 **90 分 = `Hinln/ARTEX` ↔ `mhtsec/ARTEX`**（tag 1.00 ｜ name 1.00 ｜ 同名不同 owner）。这三条 ARTEX（含 `jiwoochris/artex-ko`）**库里早已是 `dropped`**，其中 `Hinln/ARTEX` 的淘汰原因就写着「自述为 Autumn-27/ARTEX 源码备份（同项目换皮搬运）」⇒ **工具独立复现了人工记录的关系** ✓
  - 另 2 对是两个 `awesome-*` 资源清单（58.7 / 55.7 分）⇒ 典型**同类不重复**，用 `-Reject` 记档即可 ✓
  - ⇒ **推荐集合（39 条）里没有发现新重复** ✓
- 自检（`-SelfTest`，4 项）：同文本同名 = 100 ✓ ｜ 毫不相干 < 40 ✓ ｜ 同文本/同标签/同分类、仅名字不同 = 80（name 权重拿不到）✓ ｜ 空文本不崩 = 0 ✓
- **实现踩的坑（都写进文件头）**：① 函数返回 HashSet **必须** `return ,$set`（PS 会把集合「解包」：空集合→`$null`、单元素→标量 ⇒ `.Contains()` 当场炸）② **参数 `$A`/`$B` 与自检里的 `$a`/`$b` 是同一个变量**（PS 变量名不区分大小写，交接 §5 #4）+ `[string]` 约束 ⇒ pscustomobject 被**静默转成字符串** ⇒ 所有信号取到 `$null` ⇒ 全 0 分（最难查的一类）⇒ 参数改名 `$Left`/`$Right` + `[Alias('A')]`/`[Alias('B')]` 保住命令行写法 ③ 短名缩写会撞内置别名（隔离测试时 `gc` = Get-Content，把结论骗了一轮 ✗）
- **投影层真实形状**（别再想当然 ✗）：`stars` 是**对象**（取 `.current`）｜`category` 是**对象** `{l1,l2}`（取 `.l2`）｜`function_tags` 是**数组**
- 注册：`check-drift` 的 `$devOnly` ✓ ｜ `smoke-test` 新增用例（**30 → 31 项**）✓ ｜ `tools\README.md` ✓ ｜ `verify-handoff` 的 `$need`（**5 → 6 个**）✓

**刻意不做（P2-4 的另一半）**：不搞"自动合并"式去重 ✗ —— 相似 ≠ 重复，合并必须**人工确认**（`-Confirm`）；`-Reject` 用来"别再打扰我" ✓
## [4.10.25] — 2026-10-17 · 页面功能真机巡检修好（21～22 项 ✓）+ 折进 `check-page -Real`（真机层合计 36 项）

**背景**：[4.10.23] 记的 `tools\page-smoke-cdp.js`「前 5 项后静默退出」**本次实测不再复现**（真机跑出 21 项 / 20 通过 / 1 失败 ✓）——但那 1 条失败 + 收尾行为抓出**三个真问题**：

**① 断言写死项目 ⇒ 假红** ✗→✓
- 原断言固定查 `#/p/pre-commit/pre-commit` 的详情里有没有「适合谁」；但该条 `recommended=false`，且 `data/human/repo-intro.jsonl` 里**根本没有它**（0 命中）⇒ 没有 `audience` ⇒ 页面按模板第 702 行 `if(p.aud)` **本来就不该渲染** ⇒ **页面是对的，断言是错的** ✓
- 改为**数据驱动**：在推荐区扫描 `[onclick]` 里以 `detail(` 开头、且内部含 `.lead-aud` 的元素，从其 `onclick` 取回**真实项目 id** 再断言详情含「适合谁」；找不到就**如实跳过**（数据侧由 audit「推荐过的条目都有『适合谁』（39 条）」兜底 ✓）
- 真机实测命中 `angel291592/Intent-Router` ✓

**② 「静默退出」这一整类问题 ⇒ 全部加兜底** ✗→✓
- `uncaughtException` / `unhandledRejection`：**打印 + 非 0 退出**（没输出 ≠ 没错 ✓）
- `ws.onclose` / `ws.onerror`：给提示；收尾阶段静音（不再在汇总后刷 `⚠` 噪音）
- `send()` 加 **15s 超时**（原来没有超时：丢一次 CDP 响应就永久挂住 ✗）
- `ev()` 同时打 CDP `error` 与页面 `exceptionDetails` ✓
- 浏览器路径改**候选表**（原来写死 x86 Edge 单一路径 ✗）

**③ profile 目录删不掉 ⇒ 一次跑攒 23.7 MB** ✗→✓
- `history-probe-cdp.js` 的 `data/_tmp/history-probe-profile-<port>`：Edge 退出后仍短暂占用文件 ⇒ `fs.rmSync` 抛 EBUSY 被 `catch` **静默吞掉** ⇒ 实测 **469 文件 / 23.1 MB** 残留
- 改成**重试删除**（12 × 300ms + `maxRetries/retryDelay`）✓ 复验后**零残留**（`page-smoke-cdp.js` 同样处理）
- **补**：`no-target`（浏览器起不来）那条**早退路径**原来直接 `exit`、根本不清理 ⇒ 沙箱每跑一次留 2 个目录（实测含 7 / 10 个文件）⇒ 两个探针都补上清理 ✓ 复验：连跑两次 `-Real` 后残留 **0** ✓

**④ `check-page.ps1 -Real` 升级为**两个探针**（真机层 36 项）**
- 真机层 = `history-probe-cdp.js`（路由/历史 14 项）+ `page-smoke-cdp.js`（页面功能 21～22 项）
- 两探针 **argv 约定不同**（history 是「输出在前」、page-smoke 是「页面在前」）⇒ 用 `build` scriptblock 逐个绑定参数 ✓（[4.10.23] 那次"把页面传成 outFile 把 overview.html 覆盖了"就是踩这个）

**验证（2026-10-17 真机实测）**：**`PAGE CHECK: PASS（桩 DOM 层 ①–⑰ + 真机层 36 项全过）`、退出码 0** ✓ ｜ 沙箱内两探针均 `REAL: SKIP`、退出码 2 ✓ ｜ audit 166/0/0 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ check-page PASS ｜ ui-check 0 违规 ｜ 工具链巡检 30/30 ｜ 交接验收 14/14 ✓

## [4.10.24] — 2026-10-17 · E-3：真机探针折进 `check-page -Real`（两层证据 + 环境 SKIP）

**背景**：真机证据一直是"手工一次性命令"✗——`tools\history-probe-cdp.js` 虽 14/14 ✓，但要人手敲、还得记住 argv 顺序（上一轮就因为把 `overview.html` 传成 outFile，把页面覆盖了 ✗）。E-3 要的是：**让它成为自检链的一环** ✓

**改动（`tools/check-page.ps1`，71 → 158 行）**
- 新增 `-Real`（+ `-RealPort`，默认 9411）：跑完桩 DOM 层 ①–⑰ 后**追加真机层** —— 真 Edge + CDP 14 项（真鼠标点导航、真浏览器前进/后退、筛选进 URL、连续后退不崩）
- **退出码分层**：`0` = PASS ｜ `1` = FAIL（页面/探针真有问题）｜ **`2` = 环境不可用**（`-Real` 但浏览器起不来 ⇒ 打印 `REAL: SKIP`，**不当作页面缺陷** ✓）
- **判据是输出文件，不是退出码**：实测 `Start-Process -PassThru -Wait` 调 DSH Desktop.exe 时 `$p.ExitCode` 为 **`$null`**（GUI 子系统程序）⇒ 与踩坑 #24 同族，只认 JSON 里的成功标志 ✓
- 页面参数**一律传绝对路径**（相对路径会拼成 `file:///overview.html` = 错误页，且会在错误页上**假绿** ✗，探针里的早停护栏也是为此而加）
- **修死代码** ✗：原来结尾那句清 `debug.log` 写在 `exit` **之后** ⇒ 从未执行过；改成 `Clear-CrashpadLog` 函数，**每个出口都清** ✓
- `-Real` 是**显式开关**：默认行为一字未变（沙箱内巡检不受影响）✓

**验证（2026-10-17 实测）**
- 沙箱内 `-Real`：桩层 PASS → 真机层 `REAL: SKIP` + **退出码 2** ✓（Chromium 起不来：`debug.log` 报 crashpad 拒绝访问）
- **一次性放开权限后真机实跑**：`PAGE CHECK: PASS（桩 DOM 层 ①–⑰ + 真机层 14 项全过）`、**退出码 0** ✓
- `smoke-test` 新增用例 `check-page -Real`（断言 `真机层 N 项全过` **或** `REAL: SKIP`，两者之外都算失败 ✓）⇒ 工具链巡检 **29 → 30 项**
- 顺手修 `tools\smoke-test.ps1` 注释里两行被写坏的路径（「反引号 + t」被写成了 TAB → 路径显示成 `ools\...` ✗）
- `tools\README.md`：补 `-Real` 说明与退出码、巡检项数 29 → 30

**未做（仍是 WIP ✗）**：`tools\page-smoke-cdp.js`（页面交互 12 组）前 5 项后静默退出，**本轮没修**——只把**已验证可用**的探针接进自检链 ✓

## [4.10.23] — 2026-10-17 · 功能巡检：新增工具链巡检 28/28 ✓（页面交互巡检 WIP）

**背景**：用户要求"检测各个功能运行是否正常"。既有 6 条自检里，`audit` 查的是**文档/数据/页面是否自相矛盾**，
**没有任何一条查"工具还能不能跑"** ✗ ⇒ 新增这一层 ✓

**新增 `tools/smoke-test.ps1`（工具链巡检，28 项）** —— **28 通过 / 0 失败** ✓
- 只跑**安全模式**：`-List` / `-DryRun` / 默认只读；需要参数的工具**给真参数**并断言真有结果（"只打印用法"不算过 ✓）
- 覆盖：`mark-status -List` / `workspace -List` / `backfill-meta -List` / `enrich -DryRun` / `fetch-series -DryRun` / `check-config` / `validate-lib` / `check-drift` / `ui-check` / `check-page` / `code-health` / `metrics` / `intake-check` / `auto-tag` / `suggest-terms` / `suggest-plans` / `gaps` / `humanize-next` / `daily-questions` / `classify-probe` / `query -Text AI` / `compose -Need 做视频` / `compare 两个真实项目` / `score`（dot-source）/ **重建链**（sync → build → rebuild-page）/ `audit`
- 三条硬约束写进脚本头（都是实测）：① **同进程调用**（沙箱起不了子进程 ✗）② **参数用 scriptblock 绑定**（`& $path @arr` 的 splat 在本机反复把 `-List` 当位置参数 ✗）③ 每项前清 `$LASTEXITCODE`（粘性 ✗）
- 顺带验证了 `check-drift` 的 `exit 1` 是**正确行为**（当时它正报"未随包发布 1 个"= 新脚本未登记 ✓，登记后归零 ✓）

**页面交互巡检（WIP ✗，如实记录）**：新增 `tools/page-smoke-cdp.js`（真机 Edge + CDP，12 组断言：首屏/KPI/搜索/空态/分类筛选/徽章筛选/排序/详情深链/方案与工作区深链/图例抽屉/键盘/对比/首页图表/外部请求/横向溢出/控制台错误）。
**但它目前跑不完** ✗：前 5 项通过后在第 6 步**静默退出**（无异常输出）。
试过并排除：`Runtime.evaluate` + `awaitPromise`（本机不可靠 ✗）、`finish()` 写成模块级函数（看不到 IIFE 内的 `send`/`p` ✗）、等待时机（点击→hash→route→render 是异步的 ✗）⇒ 已改为"页面内只做同步动作 + Node 侧等待"，**仍未根治** ✗。
⇒ **本次交互层证据改用项目里已验证可用的 `tools/history-probe-cdp.js`：真机 14/14 全过** ✓（路由/前进后退/筛选 URL）
**本轮更严重的自伤（记档）**：给探针传参时把 **`overview.html` 传成了 outFile** ✗ ⇒ **页面被 JSON 报告覆盖**（只剩 2,123 B）✗✗ → 立刻 `rebuild-page.ps1 -Force` **完整恢复**（632,126 B、check-page PASS、audit 166/0/0 ✓）—— 单文件 + 数据即真相的架构救回来了，但这条必须记牢 ⇒ 交接 §5 #41

**验证**：audit **166/0/0** ｜ `check-page` PASS（①–⑰）｜ `ui-check` 0 违规 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ **工具链巡检 28/28** ｜ **真机路由探针 14/14** ｜ 页面 617.3 KB、外部请求 0
**另新增 `tools/verify-handoff.ps1`（交接验收，常驻工具）** —— **14/14 通过** ✓
- 它把"交接文档 vs 实物"逐条机器核对：A 数字（audit / 页面 KB / 生成器 / 模板 / 六项数据）·B `check-page` ①–⑰ ·C 25 个引用路径存在 ·D 过期说法扫描 ·E §5 踩坑编号无重号 + §10 结构 + §0 行唯一 ·F 计数口径三处一致 ·G 库内工具都已登记 `$devOnly`
- **首次运行抓到 3 处不符**并已修：① KB 口径不一（文档按十进制写 42/90 KB ✗，实测二进制 41/88 KB ✓）② ③ `verify-handoff.ps1` 自己没登记 `$devOnly` ✗
- 它同时被纳入 `smoke-test.ps1` ⇒ 工具链巡检 **28 → 29 项**

用户 2026-10-17 全部批准后连续做完三件（外加 E-2）。**期间发现 P1-2 / P1-9 / P1-13 的内容其实早已落地**，缺的只是"带出来"，已逐条核实。

### B · `created_at`/元数据补齐（194 → **229/229** ✓）
- 实测：`data/meta/*.jsonl` 并集只覆盖 **194/229**，正好缺 **39** ⇒ 这 39 条在投影里 `stars.created_at` 为空
- 新增 **`tools/backfill-meta.ps1`**：`-List`（离线看缺口）/ `-DryRun` / 逐条 `GET /repos/{owner}/{repo}` → 写成**与现有快照同 schema** 的行 → 追加 `data/meta/<当天>.jsonl` → 自动重投影 ✓
- **实测过程（诚实记录）**：第一轮 19 次后被 GitHub **匿名限流 403**（60/小时）✗ → 给脚本加「**遇 403 立即停止**」（不白撞额度 ✓）→ 等额度重置（00:19）后续跑 22 个 → **39/39 补齐** ✓
- **改名仓库的处理**：`jiwoochris/artex-ko` 被改成 `artex-global` ⇒ API 返回新名 ⇒ 用响应名当键就与台账 join 不上 ✗ → 改为**用台账里的名字当键**、真名记进 `_api_name`（数据发现：台账名过期，只记不改 ✓）
- 副产物：有描述的条目 203 → **225**（搜索/分类因此变化 ✓）

### C · P1-13「适合谁」（`human.audience`）接通 ✓
- 核实：`data/human/repo-intro.jsonl` **早已有 `audience` / `audience_source`**（39/39 推荐条目，`agent-draft(2026-10-16)`）✗ 但投影没带出来
- 改动：`sync-projects.ps1` 的 `human` 对象补 `audience` / `audience_src` → 生成器映射 `aud` → **`#/picks` 头条**与**详情面板**显示「适合谁」✓；顺带**去掉详情里 4 个装饰性 emoji 标题**（💡🎯🧪📝，设计 §10.3 ✓）
- 契约：`data/README.md` 两处（投影 `human` 行 + 人话层文件表）✓
- **新 audit 检查**：「推荐过的条目都有『适合谁』（39 条）」✓

### D · P1-6 投影侧 `function_tags_l1` ✓
- 词表侧早有 `parent` 映射（25 条：标签 → 一级方向）✗ 投影没产出 → 现在产出 `function_tags_l1`（89/229 有值，其余标签不在映射里、如实为空 ✓）
- 契约三处：`data/README.md` 字段表 + **audit 的硬编码字段清单** + 新检查「与词表 parent 全量一致（229 条）」✓
- **踩了自己记录过的坑** ✗：把 `foreach` **写进了哈希表字面量**（"投影对象是哈希表字面量 → 赋值语句必须在之前"）→ sync 语法错误；已改成"字面量之前算好、里面只留一行引用" ✓

### E-2 · 关抽屉改用 `replaceState` ✓
- 现象：抽屉是叠加层，关闭原来走 `pushState` ⇒ 历史多一条，按一次"后退"抽屉又弹回来 ✗
- 现在 `replaceHash()`（replaceState 失败回落 `setHash`）用于 `closeLegend()` ⇒ **不新增历史记录** ✓（⑪/⑬ 断言仍 PASS ✓）

### 其它核实（不改代码，只确认）
- **P1-2 官方白名单** ✓ 早已落地（`data/owner-whitelist.json` 30 组织、投影 official **8** 条带厂名）—— 我上一轮曾错报"未落地"，已在 [4.10.17] 更正 ✓
- **P1-9 标签血缘** ✓ 早已通跑（受控词表 + agent 生成带 `source=`；audit「标签条目含来源血缘」PASS ✓）

**验证**：audit **166/0/0** ｜ `check-page` **PASS（①–⑰）** ｜ `ui-check` 0 违规（对照 78）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面 **617.3 KB**、外部请求 0 ｜ audit 检查 164 → **166**（+2）
### G · `enrich` 慢变信号补齐（25 → **229/229** ✓）
- 队列实况：`data/enrich/ecosyste.ms.jsonl` 原来只富化 **25** 条 ⇒ 余 **204** 条
- 一次跑 `tools/enrich-ecosyste.ms.ps1 -MaxRequests 220 -DelaySeconds 0.8`（脚本天生 append-only + 跳过已存在 ⇒ **可断点续采** ✓）
- **结果：尝试 204 ｜ 成功 189 ｜ 失败 15（全部 HTTP 404 —— ecosyste.ms 未收录/已改名）** ⇒ 富化文件覆盖 **229/229** ✓
- 覆盖率（在 189 个成功项里）：标准文件 **172/189** ｜ license **184/189** ｜ 改名史 **179/189** ｜ open_issues **189/189** ｜ OpenSSF Scorecard **0/189**（与 2026-10-16 实测一致：Scorecard 覆盖率低 ⇒ "有则用" ✓）
- ⚠️ 该工具**绝不写 stars**（实测 ecosyste.ms 的 stars 滞后，见工具头注释 ✓）

**背景**：页面上 `using` / `researching` 恒为 0，并明写"未启用（待 P1-3）" ✗ —— 不是数据坏了，而是**根本没有写入入口**（只能手改 `data/seen.jsonl`，易写坏、不留痕 ✗）。用户 2026-10-17 已批准放开。

**新增 `tools/mark-status.ps1`**：
- 用法：`-List`（看现状）｜ `-Id owner/repo -Status researching -Reason "…"`｜ `-DryRun`（只演练）｜ `-SelfTest`（**在 `data\_tmp` 里真跑一遍写盘 + 追加日志**，不碰真实数据 ✓）
- **口径写进脚本头**（与 `#/legend §02` 一致）：`researching` = 证据不足待复核（既不判死也不推荐）；`using` = **你自己在用** —— 不替用户猜 ✗
- 规矩：状态白名单 `active/using/watching/researching/dropped`（`saved` 遗留值不接受 ✗）｜ **每次留痕**（追加 `data/status-log.jsonl` 的 `{full_name,date,from,to,reason}`）｜ 只改状态/备注，**其他字段原样回写** ｜ 写盘后**默认自动重建页面**（`DSH_SKIP_REBUILD=1` 可跳过）✓
- 已注册进 `check-drift` 的 `$devOnly`（库内专用，发版随包 ✓）

**实测**：`-List` 正确报出真实分布（watching 155 / active 38 / dropped 36 + 明确提示 using、researching 仍为 0 ✓）；`-DryRun` 演练通过 ✓；**`-SelfTest` 通过**（状态真被改为 researching、日志正确追加 ✓）—— 写盘路径**真跑过**，不是纸面功能 ✓

**顺手修 `tools/code-health.ps1`**：尾部补 `exit 0` —— 原来没有退出码 ⇒ 调用方会读到**上一次的** `$LASTEXITCODE` ✗（与 `sync-projects`/`build-overview` 同一个坑，已第三次修同族问题）

**验证**：audit **164/0/0** ｜ `check-page` PASS（①–⑰）｜ `ui-check` 0 违规 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面无变化（609.7 KB）

**① 收紧 🌱 新星规则**：原口径「首见 ≤ 14 天 且（S/A 或体验分 ≥ 4）」实测覆盖 **170/229 = 74%** ⇒ 徽章几乎人人都有，失去区分度 ✗（根因：库整体只有 5-6 天，14 天窗口对**所有**条目都成立）
→ 改为「首见 ≤ **7** 天 且 **已评到 S/A 档**」⇒ **39 条（17%）** ✓，图例同步写明收紧原因与当前命中数 ✓
**收紧后五类命中**：🏢 8 ｜ 🌱 **39** ｜ 🧊 65 ｜ 🧱 0（规则要求库龄>30 天）｜ 🧪 161 ✓

**② 补上「图表 aria」检查（设计 §7 自认的缺口 ✗ → ✓）**：新增 audit 检查 —— **每个 `role="img"` 必须有非空 `aria-label`，且图表块要有文字摘要**（`#/home` 的图是**构建期写死**的，所以能直接静态查产物 ✓）
- 口径同步三处：`TOTAL_CHECKS` **163 → 164** ｜ `README.md`「164 项不变量」｜ `CHANGELOG` 顶部指纹行 ✓
- **正向**：`[PASS] 图表都有 aria-label 与文字摘要（4 个图 / 6 条摘要）` ⇒ **164/0/0** ✓
- **反向**：摘掉一个 `aria-label` ⇒ **`[FAIL] … 缺 aria 的图 1 个` + 163 通过/1 失败（exit 1）** ✓；恢复 ⇒ 164/0/0 ✓

**验证**：`check-page` **PASS（①–⑰）** ｜ audit **164/0/0** ｜ `ui-check` 0 违规 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面 **609.7 KB**、外部请求 0

**做了什么**：筛选条新增「全部徽章」下拉（🏢/🌱/🧊/🧱/🧪）——`f.badge` 进筛选状态、`pass()` 加谓词、`filterQuery()/applyQuery()/clearAll()` 全链路打通 ⇒ **筛选写进链接**（`#/all?badge=gem`，可分享、可后退、刷新保持）✓
**新断言 `⑰`**：选中「冷门」→ 列表**只剩带该徽章的条目**（`gems === cards`），且链接可复原 ✓；**反向测试**：打断 `pass()` 里的徽章条件 → **⑰ 变红 + `PAGE CHECK: FAIL`（exit 1）** ✓；恢复 → PASS ✓
**图例同步**：`#/legend §04` 的"徽章筛选尚未做 ✗"改成"已可用（会写进链接）" ✓

**⚠️ 更正徽章命中数（我上一轮报错了）**：生成器里 `exp = $p.experience.stars`（**五星**），而我复算时用了**不存在的** `experience.overall` ✗ ⇒ 上一轮报的 `🌱39 / 🧊11` 是错的。按**正确口径**（`experience.stars ≥ 4` 或 S/A 档）复算并与页面实测对齐：
| 徽章 | 正确命中 | 上一轮我报的（错 ✗） |
|---|---|---|
| 🏢 官方 | **8** | 8 ✓ |
| 🌱 新星 | **170** | 39 ✗ |
| 🧊 冷门 | **65** | 11 ✗ |
| 🧱 常青 | **0**（规则要求库龄>30天） | 0 ✓ |
| 🧪 待观察 | **161** | 161 ✓ |
页面 ⑰ 实测"冷门 **65** 条"与复算一致 ✓ ⇒ **页面是对的，我的复算错了**。

**发现的真问题（记为待办，不假装没看见）**：🌱 新星按现规则覆盖 **170/229 = 74%** —— "徽章"本该有区分度，现在几乎人人都有 ✗。原因：库整体只有 5-6 天，`首见≤14天` 对所有条目都成立。**建议下一步收紧**（例如 `首见 ≤ 7 天` 且要求有星速或 S/A 档），已写进交接文档 ✓

**验证**：`check-page` **PASS（①–⑰）** ｜ audit **163/0/0** ｜ `ui-check` 0 违规（对照 78 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面 **609.6 KB**、外部请求 0 ｜ 断言数 **16 → 17**

**做了什么**：新增 **`badgeOf(p)` 唯一真源**（渲染与将来的筛选共用），在**行式条目**与 `#/picks` 封面稿上渲染**分层徽章**，并把**每条规则的精确口径写进 `#/legend §04`**（标记必须能解释 ✓）：
| 徽章 | 规则 | 当前命中 |
|---|---|---|
| 🏢 官方 | owner 命中 `data/owner-whitelist.json`（30 组织），带厂名；只降核实成本、不加分 | **8** |
| 🌱 新星 | 首见 ≤ 14 天 **且**（S/A 档 或 体验分 ≥ 4） | **39** |
| 🧊 冷门 | 星数 < 1000 **但**质量好（S/A 档 或 体验分 ≥ 4）—— 用户指定由 💎 改 🧊 | **11** |
| 🧱 常青 | 库龄 > 30 天 **且** 近 7 天仍有提交 | **0**（库只有 5 天历史 ⇒ 规则决定它现在恒 0，**页面如实写明**，不假装） |
| 🧪 待观察 | 档位未评 **且** 风险未评 | **161** |

**配色纪律**：只给 🏢 用黄块（稀缺，8 条 ✓），其余走灰阶/硬白 —— **不加新色相** ✓
**诚实说明**：🌱 现在与"已评档"高度重合（库太年轻），图例里写明"库老了这个标记会自然变稀" ✓
**未做（下一轮）**：**徽章筛选**（按层过滤 + 写进链接）✗ —— 已在图例与本文注明

**验证**：`check-page` **PASS（①–⑯）** ｜ audit **163/0/0** ｜ `ui-check` **0 违规**（对照 78 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 徽章命中数用 PowerShell **按同规则复算**过 ✓ ｜ 页面 **608.2 KB**、外部请求 0

**我上一轮说错了（必须更正）**：我说"库里 `owner_class` 全是 `community`、P1-2 未落地" ✗ —— **事实相反**：
- `data/owner-whitelist.json` **存在**（1.1 KB，30 个组织，`_更新 2026-10-17`）
- 投影里 **`official = 8`** / `community = 221`：`apache/maka`、`jd-opensource/JoyAI-Image`、`openai/codex`、`openai/math`、`Tencent/BrowserSkill|teamai-cli|WeKnora`、`zai-org/ZCode`，且 `owner_label` 带厂名 ✓
- 我的错误来源：**只抽样看了前 3 行**（恰好都是 community）就下了"全是 community"的结论 ✗ ⇒ **教训：分布要看 `Group-Object` 全量分布，不能抽样下结论**

**由此暴露的真缺陷（页面在说假话 ✗）**：`#/picks` 官方侧栏的过滤值我写成 `owner_class === 'official-bigtech'`，而投影写的是 **`'official'`** ⇒ 命中 0 ⇒ 侧栏**谎称"还没有校订过的官方条目（P1-2 未落地）"**，而数据里明明有 8 条 ✓→✗
**修复**：过滤值改 `'official'` ✓；措辞改成"白名单命中 0 条"（不再暗示未落地）✓；并补上设计要求的 **🏢 徽章（`owner_label` 厂名，**排在标记第一位**）**——行式条目与 `#/picks` 封面稿都加 ✓

**新断言 `⑯`（官方侧栏与数据一致）**：拿页面里的 `official` 条数与侧栏实际列出的 `github.com/` 链接数比对；**数据有 → 必须列出来且不许声称空；数据无 → 必须说明空** ✓
**反向测试**：把过滤值改回 `official-bigtech` → **⑯ 报 `official=8 列出=0 声称空=true` + `PAGE CHECK: FAIL`（exit 1）** ✓；恢复 → PASS ✓

**我还踩了自己一次（记档）**：把 `jump('#/picks')` 做全局替换时**命中 3 处**（我只想改 ⑯ 里的那处）→ 连带把 ⑪ 路由断言的两行注释化，导致 `PAGE CHECK: FAIL` ✗ —— 我**看到了"命中 3"却没停下核实** ⇒ 教训：**替换命中数与预期不符时，必须先查清再继续** ✓（已还原 ⑪ 两行 ✓）

**验证**：`check-page` **PASS（①–⑯）** ｜ audit **163/0/0** ｜ `ui-check` 0 违规 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面 **605.9 KB**、外部请求 0
**断言数 15 → 16**（`新会话交接` 与本文同步 ✓）

---

## [4.10.16] — 2026-10-16 · 批次 6 收官：`#/plans`（工单式）+ **抓到一个真 bug**

**做了什么**（设计 §10.5：`#/plans` = **工作台/工单**，角色-工具用**表格线**呈现，黄块标"已配齐/缺件"）：
- **方案列表 → 工单表**：表头（`# / 方案 / 步骤 / 已配齐 / 缺件 / 触发词`）+ 每方案一行；**已配齐 = 黄块黑字**、**缺件 > 0 = 警示红**（红只做警示 ✓）
- **方案详情 → 工单**：头部 `已配齐 3 / 4 步` 黄块 + `缺件 1 步` 红块；每个角色一行（`01 角色名 … 状态块`，表格线分隔）✓；工具仍按"工具 / 适合谁·为什么选它·要注意"两列表格 ✓
- 标题去装饰性 emoji → 等宽 `PLANS` 标签 ✓

**抓到并修掉一个真 bug（这轮最大的收获）**：
- 现象：真机截图里"做 AI 视频"**四个角色全被标成「缺件」**，而头部却写"已配齐 0 / 4 步" ⇒ 与"查看全部 17 个同类工具"自相矛盾 ✗
- 真因：**`planRoleAll(role)` 返回的是数字**（`return planRoleTools(role,999).length`），我却写成 `planRoleAll(r) && planRoleAll(r).length` ⇒ 数字取 `.length` 恒为 `undefined` ⇒ 有工具的角色也被判为缺件 ✗
- 修法：改成 `planRoleAll(r) > 0` ✓（两处：列表统计 + 详情状态块）
- **我差点放过它**：一开始看截图把 `已配齐 0 / 4` 的 `0` 读成了 `3`（分辨率太低）✗ → 读代码才发现矛盾 ⇒ **教训：小字/低分辨率截图不能当证据，要看 DOM 或数字**

**断言加强（`check-page ⑨`）**：新增「详情页 `已配齐 N / M` 的 **N ≥ 1**」——⚠️ 第一版只数"状态块存在"，**反向测试时照样通过**（假断言 ✗）→ 改成**正则解析数字** ✓
**反向测试**：把 bug 塞回页面 → **⑨ 变红 + `PAGE CHECK: FAIL`（exit 1）** ✓；恢复 → PASS ✓
**过程中还修了自己两次**：① 把注释接在行尾，吞掉了该行的 `});` → 页面 JS 语法错误（`missing )`）✗ ② 断言的假通过（上面那条）✓ 都已回读校验

**验证**：`check-page` **PASS（①–⑮）** ｜ audit **163/0/0** ｜ `ui-check` 0 违规（对照 78 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 真机截图（`#/plans` 列表 + 详情）✓ ｜ 页面 **605.4 KB**、外部请求 0

> ✅ **批次 6 六个区全部完成**：`#/home`（封面+目录）→ `#/legend`（技术规范页）→ `#/all`（索引+行式密排）→ `#/picks`（专题报道）→ `#/plans`（工单）＋ 调色板定稿、`craft-floor` 合规、用户报障修复（断言 ⑮）。

---

## [4.10.15] — 2026-10-16 · 批次 6 第四区：`#/picks`（专题报道：封面稿 + 档位分栏 + 官方侧栏）

**做了什么**（设计 §10.5：`#/picks` = **专题报道**）：
- **首条做成封面稿**（原来是横向滚动的迷你卡）✗→✓：黄上沿 + 大标题（`clamp(20px,2.4vw,30px)`）+ **导语**（人话层一句话）+ **档位/风险/星标/语言/许可/时间**元数据 + CTA「点开看详情与『选它因为』」✓
- **其余按档位分栏**：`BY TIER` 四列 —— **S 档 · 最值得看 / A 档 · 值得收藏 / B 档 · 合格 / 未评档 · 其他**，每列带条数；空档**明写「这天没有这一档」**（不藏 ✓）
- **排序规则明确**：**档位优先**（S→A→B→未评）→ 体验分 → 星数 ⇒ 头条永远是那天最值得看的（实测 10-16 那天没有 S 档，头条取 A 档，符合预期 ✓）
- **官方动态侧栏**：`owner_class === 'official-bigtech'` 才列；当前**库里一条都没有**（校订是 P1-2，未落地前一律 `community`）→ 侧栏**明说「还没有校订过的官方条目」**而不是画假列表 ✓
- 数据侧：生成器给页面 JSON 增开 **`oc`（owner_class）/ `ol`（owner_label）** 两个字段（229 行 ✓），侧栏从此有真实依据 ✓
- 标题同样去掉装饰性 emoji，改等宽 `FEATURE` / `BY TIER` / `OFFICIAL` 标签 ✓

**验证**：`check-page` **PASS（①–⑮）** ｜ audit **163/0/0** ｜ `ui-check` **0 违规**（阳性对照 78 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 真机截图（`#/picks` 1400×1700）确认封面稿 + 四列分栏 ✓ ｜ 页面 **601.5 KB**、外部请求 0
**未做**：`#/plans`（工单式角色-工具表格，**最后一区**）；§12-④ 今日推荐面板的"适合谁"（缺 `human.audience`，P1-13）✓

---

## [4.10.14] — 2026-10-16 · 修用户实测报障：封面被历史 localStorage 标记隐藏（+ 回归断言 ⑮）

**用户报障（2026-10-16）**：「总览上方缺少一部分」——截图里 `#/home` 从导航直接跳到 `§ 01 库总览`，**整块封面（ARCHIVE INDEX 刊头）不见了** ✗

**根因（真因，不是猜的）**：老版封面带一个「知道了，收起」按钮，点它会写 `localStorage['dsh-lib-hero']='off'`；`file://` 下 localStorage **按源持久保存** → 加载时那段代码若读到 `off` 就 `hero.style.display='none'`。批次 6 里封面已经**从"可关闭的引导横幅"升级为首页主体**（刊头 + 入口 chips + KPI 的引子），于是**很久以前的一次点击让封面永久消失** ✗

**修复**：
1. **删掉「收起」按钮**（封面是内容，不是可关闭的横幅）✓
2. 加载逻辑改为**清掉历史遗留标记**（不再隐藏封面）：`if(localStorage.getItem('dsh-lib-hero')==='off') localStorage.removeItem('dsh-lib-hero')` → **点过收起的用户也会自动恢复看到封面** ✓

**新增回归断言 `check-page ⑮`**（并**并进 `passed`**，否则"测了但不影响结论"✗）：用带 `localStorage` 桩的全新作用域重跑页面 JS，要求 ① 该标记被清掉 ② 封面 `display` 不为 `none` ✓
**反向测试（证明断言真会拦）**：把旧"隐藏封面"逻辑塞回页面 → **⑮ 变红 + `PAGE CHECK: FAIL`（exit 1）** ✓；恢复 → **PASS** ✓
**取证记录**：`check-page` 断言数 **14 → 15**（①–⑮）。

**我自己的一次错误（已改正并记档）**：⑮ 第一版直接读 `els['hero']` —— 桩的元素是**懒创建**的（`getElementById` 调过才存在），修好后的页面**不再调用它** → `els['hero']` 恒为 undefined → **假红** ✗。改为在**页面作用域内主动取一次** `document.getElementById('hero')` 并回传 `display` ✓（教训：给"副作用型修复"写断言时，要**主动触发**元素创建，别依赖副作用留下的痕迹）

**验证**：`check-page` **PASS（①–⑮）** ｜ audit **163/0/0** ｜ `ui-check` 0 违规 ｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 页面 590.4 KB、外部请求 0
**未完成项（如实记录）**：想在真浏览器里**复刻你的场景**（profile 先塞 `dsh-lib-hero=off` 再加载）做最终确认，但两次探针都没跑完 —— 第一次 `Page.reload` 后进程直接退出（exit 1），第二次**探针文件在同一 pwsh 调用内写入成功后、下一条命令就找不到**（原因未查明）✗。因此「真机复刻」记为**未验证**；不过 ① 代码层面**已不存在任何给 `#hero` 设 display 的路径**（实测「hero 上设 display 的语句 = 0」）② ⑮ 断言**双向**验证过（含反向测试）✓ ⇒ 结论可信，**你在浏览器里刷新一下即可自证**（封面应当回来）✓

---

## [4.10.13] — 2026-10-16 · 批次 6 第三区：`#/all`（档案索引/目录：索引列 + 行式密集排版）

**做了什么**（设计 §10.5：`#/all` = **档案索引/目录**）：
- **列表从"卡片墙"改成行式密集条目** ✗→✓：`#list` 由三列卡片栅格改为**单列密排**，每条 = **编号（等宽 `01`…）+ 正文 + 等宽元数据列**（星数 / 语言·许可 / 最近提交右对齐）✓；描述两行截断（`-webkit-line-clamp:2`），标签与状态/风险/档位 pill 收在正文内 ✓
- **分类索引**：`INDEX · 分类索引`（原来是 🗂 分类浏览的**大卡片盒子**）→ 紧凑索引列（`auto-fill minmax(200px,1fr)`、无卡片底、细线分隔），保留全部可点筛选 ✓
- 标题去掉**装饰性 emoji**（🗂/📋），改用等宽 `INDEX` / `LIST` 标签 —— 英文承担信息组织作用（用户原文 §三-2），也符合 craft-floor「emoji 不当图标系统」✓
- **渲染层改动**：`cardHtml(p, idx)` 新增序号参数、`r.map(function(p,i){return cardHtml(p,i)})` ✓

**关键约束（差点踩掉）**：`check-page.js` 有 **6 处**用 `/class="card/`（其中一处是**精确** `class="card"`）数条目 ✗ → 行式改版**必须保留根元素 `class="card"` 原样**，只在其内部加 `.rk/.main/.meta` 三栏 ✓（改名等于自己拆测试网）。验证：`check-page` **PASS（①–⑭）** ✓

**实施方式记一笔**：JS 卡片模板我第一版用"逐字转写整段"做替换 → **命中 0** ✗（转写与原文件有细微差异，静默失败）→ 改用**按锚点定位的区间替换**（`IndexOf` 起止 + 拼接）✓ 一次成功。`ui-check` 同时仍 0 违规 ✓

**验证**：`check-page` **PASS** ｜ audit **163/0/0** ｜ `ui-check` **0 违规**（对照 74 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 真机截图（`#/all` 1400×2300）确认索引列 + 行式密排 + 元数据列 ✓ ｜ 页面 **590.2 KB**、外部请求 0
**未做**：`#/picks`（专题报道）／`#/plans`（工单）；§05 其他区的**装饰性 emoji 标题**（🧩/📌/📖）留到各自那一区一起换 ✓

---

## [4.10.12] — 2026-10-16 · 批次 6 第二区：`#/legend`（技术规范页）+ craft-floor 合规修正

**做了什么**（设计 §10.5：图例 = **技术规范页**，像规格书 → 纯黑白 + 编号清单）：
- 图例从"📊🚦📌🏷🔧🔗 六段说明"改成 **`SPEC · 图例与标准` + § 01…§ 07 编号条款**：档位（带边框表格：档位/分数/含义/上限）、状态五态、风险四级、**徽章**、标签与来源（技术/功能/用户搜索词 + 可信度）、数据与免责（分数启发式 / 星数快照 / 未评≠安全 / 只读单文件 / buildStamp / 怎么更新）、链接与路由表 ✓
- **这一页不用荧光黄**（黑白灰三阶即可）—— 规范页靠等宽编号、细线表格与分层标题建立秩序 ✓；抽屉仍是**叠加层，不改变你所在的区**（P2-9 行为不变 ✓）
- **落实用户决定**：徽章图例改为 **🏢 官方 / 🌱 新星 / 🧊 冷门 / 🆕 刚发布 / 👤 用户推荐**，并**明写"🔥 与 💎 已停用"**（营销号观感，用户 2026-10-14 决定；冷门 = 🧊 为用户 2026-10-16 指示）✓

**按 `impeccable` 技能（craft-floor）修正了两条我自己的违规** ✗：
1. **eyebrow/kicker 是明令禁止项**（"no brief earns it back"）—— 我在 P2-12 加的页头 `.kicker`（`ARCHIVE INDEX` 小标）与首页刊头**上方的黄条**正属此列 → `.kicker` **整条删除**（Anton 仍由刊头大标题使用 ✓），黄条改为**标题下方的切割带** ✓
2. **display 字号上限 6rem** —— 刊头原为 `clamp(46px,9vw,118px)`（118px = 7.4rem ✗）→ 收到 **`clamp(44px,7.2vw,96px)`** ✓

**修掉的 1 个真实缺陷**：规范页档位表格里 `65–79` / `50–64` 被**折成两行** ✗ → 给"分数/上限"列加 `white-space:nowrap;width:1%` ✓（确认截图复核通过）

**一个"差点修错"的教训（踩坑 #31）**：窄屏截图看起来"右侧被截断"，我一开始判定为横向溢出 ✗ —— **CDP 实测 `innerWidth=504` / `scrollWidth=494` / `body.scrollWidth=494` 证明没有溢出** ✓，被列出的"超宽元素"是**关闭状态的抽屉**（`position:fixed` 停在画布外，不产生滚动）。真因是**截图工具的窗口宽度 ≠ 布局视口宽度**，把 504px 的版面裁成 420px 图 ✗ → **判断是否溢出要读 `scrollWidth`/`innerWidth`，不要看截图** ✓

**验证**：`check-page` **PASS（①–⑭）** ｜ audit **163/0/0** ｜ `ui-check` **0 违规**（阳性对照 74 条）｜ 回归 50/50 ｜ 契约 0 ｜ 漂移 0 异常 ｜ 真机截图（图例 1400 / 窄屏 504 实测 / 全库）✓ ｜ 页面 **587.5 KB**、外部请求 0
**未做**：`#/all`（facet + master–detail 行式密集排版）／`#/picks`（专题）／`#/plans`（工单）；§12-④ 今日推荐面板 ✓

---

## [4.10.11] — 2026-10-16 · 批次 6 第一区：`#/home`（杂志封面 + 目录，设计 §10.5 / §12-①②③）

**背景**：调色板切好之后（[4.10.10]），按设计 §10.5「`#/home` = 杂志封面 + 目录」重做首页：原来是"欢迎 + 一堆卡片"，现在是**封面 + §01…§05 编号目录**。用户提供的两张参考图只作方向不做硬要求 ✓

**做了什么**（`tools/build-overview.ps1` 聚合 + `templates/overview.css` 版式 + `templates/overview.js` 两个跳转函数）：
- **刊头**：内嵌 **Anton** 排超大 `ARCHIVE / INDEX`（`INDEX` 用荧光黄），上方一条**黄切割带**装等宽小字（`EST. 2026 · LOCAL ARCHIVE · 单文件离线 · 零依赖`）；中文副题走系统栈、**不压缩** ✓（设计 §10.2）
- **§01 库总览**：4 个 KPI（库内项目 / 推荐过 / 近 7 天新增 / 在跟+在用），巨大 `clamp()` 数字 + 等宽，**只有"推荐过"用黄块**（黄底黑字 ✓）
- **§02 结构分布**：状态 / 档位 / 风险 三条**堆叠条 + 明细行（数量与占比）**；`using`/`researching` 为 0 时**明说"未启用（待 P1-3）"**；风险未评 **169 条（74%）明写"未评 ≠ 安全"** ✓
- **§03 类别分布**：一级 11 类横条（数量 + 占比），**点任一行 → 全库并按该大类筛选**（新 JS `jumpL1()`；见下"为什么不能 go+setL1"）
- **§04 探索缺口**：拿 `taxonomy` 的**全量类目**去比数据 ⇒ ① 没有任何项目的类目 **3** 个 ② 有项目但 0 推荐 **15** 个 ③ 30 天无新增 **0** 个（库只有 5 天历史，**如实写明**而不是假装有缺口 ✓）
- **§05 最近变化**：近 7 天每日事件柱（10-11…10-16）+ 事件类型**方括号等宽徽章** `[NEW] [STAR] [PICK] [REL] [STAT] [META] [PUSH] [DROP] [CAT] [LIC]`，每个都配中文说明（设计 §10.5「终端日志性格，但每行给中文」）✓
- **全部数字构建期算完**（设计 §0-5：打开即出图，运行时 0 聚合）；**每个图都有 `role="img"` + `aria-label` + 文字摘要**（设计 §7 断言⑤的精神，颜色不做唯一信息手段 ✓）

**为什么加了 `jumpL1/jumpL2`**：从首页图表跳筛选**不能**写成 `go('all')` + `setL1(v)` —— `route()` 处理 `#/all` 时会 `applyQuery('')` **把刚设的筛选清掉** ✗。正确做法：先设 `f`、再把筛选**写进 hash**，由 `route()` 复原 ✓

**修掉的 3 个问题**（都是自检/规则抓出来的）：① `ui-check` 报 `.spark` 子元素贴底（`padding-bottom:2px` → `var(--sp-2)`）② `ui-check` 报 **em-dash 12 条超阈值**（我新写的文案又堆了破折号 → 改「：」）③ 我把 markdown 的 `**稀缺**` 直接写进 HTML（会原样显示 ✗ → 改 `<b>`）

**数据观察（记档，不改数据）**：投影里 `tier` 有 **`unrated`(86) 与 空(75) 两种写法、含义相同** → 页面按"未评档 161"合并展示并**注明两种写法的拆解** ✓；库龄仅 5 天 ⇒ "近 7 天新增 = 229" 加**动态说明**（`库只有 N 天历史 · 全部都在窗口内`），库老了这个说明会自动消失 ✓

**验证**：`check-page` **PASS（①–⑭）** ｜ audit **163/0/0** ｜ `ui-check` **0 违规**（阳性对照抓到 74 条）｜ 回归 **50/50** ｜ 契约 0 违规 ｜ 真机截图 2 张（1400×1500 / 1200×2600）人工确认版式与黄预算 ✓ ｜ 页面 **584.7 KB**、外部请求 0
**未做（本区之外）**：`#/legend`（技术规范页）／`#/all`（facet + master–detail）／`#/picks`（专题）／`#/plans`（工单）；§12-④ 今日推荐面板、§12-⑤ 图例面板；变化面板的**按日时间线**（本轮只做了 7 天柱 + 类型汇总）✓

---

## [4.10.10] — 2026-10-16 · 批次 6 起步：调色板切到「开源地下档案」（设计 §10.1 定稿）

**背景**：V1 令牌层把颜色全部令牌化（hex 0 处外露），但值仍是旧暗色系（蓝 #4f8cff 为主）。设计 §10.1 定稿的是 **纸黑 / 硬白 / 荧光黄 / 警示红**（比例写死：55% / 20% / 15% 灰 / **黄 ≤8%** / **红 ≤2%**）——令牌化之后，换调色板只需改 `:root` **一处** ✓（这正是 V1 的收益）

**做什么**（只改 `tools/templates/overview.css` 的 `:root` + 1 处 `rgba`，**手改定义区**，不做全局替换 —— 踩坑 #26）：
- `--bg #0b0b0b`（纸黑）/ `--surface #111`（墨黑）/ `--surface-2..4 #161616 / #1c1c1c / #131313`；灰阶 3 级 `--border #2a2a28` / `--border-strong #3d3d3a` / `--text-dim #9a9a94`；`--text #f4f2ec`（硬白，微暖纸白）
- **荧光黄 `#e8ff2a`** = `--accent` / `--accent-bg`，配 `--accent-ink #0b0b0b`（**黄底必黑字** ✓）；`::selection`、`:focus-visible`、滚动条、选中 chip/nav 都吃这套令牌 → 黄自动只出现在"选中/焦点"这类**块与线**上 ✓
- **警示红 `#ff2d20`** = `--danger` / `--danger-line`（高风险 / 淘汰 / 门禁）
- **稀缺纪律**：星标 `--gold` 改成暖灰纸色 `#cfcbb4`（**不拿黄去铺满星标** ✗）；S 档/低风险的 `--ok-*`、以及原蓝/紫的 `--info-*`/`--violet-*` 一律**中性灰** —— 语义靠**文字标签**传意（设计 §10.1「不靠颜色单独传意」✓）
- 待补全的 `--warn-*` 保留黄系（`#e8ff2a` / 暗黄线 / 深黄黑底）—— 设计 §0-6「缺失要显式画出来」✓

**验证**：`ui-check` **0 违规**（含**对比度**实测 ✓）｜ audit **163/0/0** ｜ `check-page` **PASS（①–⑭）** ｜ 回归 **50/50** ｜ 真机截图 2 张人工确认（纸黑底 / 硬白字 / 黄只在选中块且黄底黑字 / 无滥红）✓ ｜ 页面 567.8 KB、外部请求 0
**下一步**：批次 6 的分区版式（`#/home` 刊头+KPI → `#/legend` → `#/all` facet+master–detail → `#/picks` → `#/plans`）

---

## [4.10.9] — 2026-10-16 · P2-3 后半：模板拆分（CSS/JS 出生成器，产物仍单文件）


**背景**：`build-overview.ps1` 里那段插值 here-string 已涨到 **~1210 行**（CSS 12.8 KB + JS 43.7 KB + 骨架），改一行 CSS 得在整坨字面量里翻；交接文档多轮都写"这半要留给上下文充裕的新会话"。

**做什么（脚本化提取，不手抄）**：
- `tools/templates/overview.css`（**12.8 KB→14.2 KB 落盘**）与 `tools/templates/overview.js`（**43.7 KB→51.7 KB**）：从生成器里**按锚点原样提取**，只把 PowerShell 变量换成占位符 —— CSS 的 `$antonFontFace` → `{{FONT_FACE}}`；JS 的 `$json/$evJsonStr/$plansJson/$synJson/$wsJson` → `{{JSON}}/{{EV}}/{{PLANS}}/{{SYN}}/{{WS}}`（每个在 JS 里**只出现 1 次**，替换无歧义 ✓）
- 生成器里两段区域改为 `$cssBlock` / `$jsBlock`，加载器（读模板 → 字面替换占位符，`.Replace` 不是正则 ✓）插在 `$html = @"` **之前**
- 生成器 **89.5 KB → 25.0 KB**；产物仍是**单文件** `overview.html` ✓（模板只是构建期输入，交付形态不变）

**等价性证明（这轮的关键证据）**：
- 拆前留基线 → 拆后重建 → **逐行比对**：**12 行差异 = 3 行时间戳 + 9 行注释**，9 行每行 **+2 字符**，全部是**反引号**（如 `` `#/legend` ``、`` `detail('…')` ``）。⇒ **顺带修掉一个既存隐患**：插值 here-string 会把反引号当转义符**静默吃掉**（页面反引号 4 → 20），以前只影响注释所以没人发现，但如果谁在 JS 里写模板字符串就会被改坏 ✗；拆成纯文本文件后 **CSS/JS 不再经过插值** ✓
- 数据行 `const E = {...}` 顺序不同：**长度相同、字符多重集完全相同** → 是 PowerShell **哈希表跨进程枚举顺序**（.NET 字符串哈希随机化）导致的**既存非确定性**，与拆分无关；两次连续构建只差**秒级时间戳** ⇒ 生成确定 ✓（已记为待办：把 E 的键排序可让构建字节可复现，但 `[ordered]@{}` 不能可靠 `ConvertTo-Json`（踩坑 #5）→ 留到后续 ✓）
- **模板是"活的"**：把 `overview.css` 的 `--radius:0` 临时改成 `3px` → 重建后页面出现 `--radius:3px` ✓；还原 → 复原 ✓

**验证**：audit **163/0/0** ｜ 回归 **50/50** ｜ 契约 0 违规 ｜ `check-page` **PASS（①–⑭）** ｜ `ui-check` **0 违规**（对照抓到 18 条）｜ 漂移 0 异常 ｜ 页面 566.8 KB、外部请求 0 ✓
**发版提醒**：`tools/templates/` 是生成器的**必需输入**，发版必须随包（缺了生成器会红字报错并 `exit 1` ✓ 不会静默产出坏页面）

---

## [4.10.8] — 2026-10-16 · P2-12 字体内嵌与合规（Anton WOFF2 子集 + THIRD-PARTY.md）


**背景**：设计 §10.2 定「拉丁刊头用 Anton（OFL 1.1）」，§11 要求**条件 2 → 必须随附版权声明与许可文本**。此前只有"已核许可"的文字记录，**字体与 OFL 正文都没落到仓库里** ✗。

**做什么**：
- 取字体：Google Fonts CSS API（**Chrome UA**）→ 拿 `latin` 子集 woff2 → `assets/anton-latin.woff2` = **18,612 B**（magic `wOF2` ✓，正好在设计估的 20–40 KB 内）；同批留档 `assets/anton.css` 与 `assets/anton-OFL.txt`（许可全文，94 行）✓
- 内嵌：`tools/build-overview.ps1` 在 here-string **之前**读字体 → base64 → `@font-face` 输出到 `<style>` 首行；新增 `--font-display:'Anton',var(--font-mono)`（**缺失时自动回落**，不会因为缺字体把页面搞挂 ✓）
- 用起来：页头加拉丁刊头 `.kicker{font-family:var(--font-display)}`（`ARCHIVE INDEX`）；**中文一律系统栈，绝不内嵌 CJK 子集** ✗；字体出处与许可写在**页脚**（不塞进刊头 —— 用户可见的标题栏不该出现运维说明 ✗，第一版我犯过）
- 合规：新建根目录 **`THIRD-PARTY.md`**（Anton 版权行 + **OFL 全文** + 复现方式 + "无其他第三方素材"声明）
- audit **162 → 163 项**：新增「**内嵌字体 → 必须有 THIRD-PARTY.md 且含 OFL 全文与版权行**」（页面无内嵌字体时不要求 ✓）；同时把 `assets\anton-latin.woff2` 加进 P1-17 的新鲜度白名单（它现在也是页面输入 ✓）

**验证**：audit **163/0/0** ｜ 回归 **50/50** ｜ 契约 0 违规 ｜ `check-page` **PASS（①–⑭）** ｜ `ui-check` **0 违规**（阳性对照抓到 18 条）｜ 漂移 0 异常 ｜ 页面 **566.8 KB**、**外部资源引用 0** ✓
**针对性实测**：① 反向测试（临时移走 `THIRD-PARTY.md`）→ P2-12 **变红**（162/1、退出 1）；恢复 → 163/0/0 ✓ ② **base64 往返**：把页面里的 data URI 解码回来 → 18,612 B、**SHA256 与源文件完全一致**、magic `wOF2` ✓ ③ **真机**：Edge + CDP 查 `document.fonts` → **`Anton:loaded`**，`.kicker` 计算字体为 `Anton, ui-monospace…`；截图肉眼确认刊头用了压缩粗体 ✓
**踩坑记录**：① 沙箱内 **TLS 不可用**（`schannel: SEC_E_NO_CREDENTIALS` / "Bad hostname"）→ 取二进制必须一次性放开权限；② 我第一版把 curl 参数拼成数组，`-o` 失效 → **字体二进制直接灌进标准输出**，把上下文冲掉一大截 ✗ → 正确做法：**参数用单个字符串 + 一律重定向到文件 + 只读结果**（踩坑 #27）；③ 全量 TTF 是 130 KB，**Chrome UA 的 CSS 才给 18.6 KB 的 woff2 子集** —— 别拿通用 UA 的 TTF 去内嵌 ✗

---

## [4.10.7] — 2026-10-16 · P2-3 前半：V1 令牌层（设计系统地基，`页面分级设计` §4/§10.3/§12-V1）

**背景**：设计定稿要求「语义色 / 6 级字阶 / 6 档间距 / 七态 / 8 个浏览器表面 / 去圆角去彩边」。现状是**散落 56 处硬编码 hex、14 处圆角、10 级字号**。P2-3 的后半（模板拆分）要读整段 ~1160 行字面量，按纪律留给上下文充裕的新会话；**这次只做前半（令牌层）**。

**改动**（全部在 `tools/build-overview.ps1` 的 `<style>` 区）：
- **令牌层**：`:root` 定义 **46 个 token** —— 语义色（`--bg/--surface/--surface-2..4/--border/--border-strong/--text/--text-dim/--accent/--accent-ink/--accent-bg/--gold/--ok/--warn/--danger/--info/--violet` 及各自的 `-line`/`-bg`）、**6 级字阶**（12/13/15/18/24/32）、**6 档间距**（4/8/12/16/24/40）、字体栈（`--font-body`/`--font-mono`，为 P2-12 的 `--font-display` 留位）、`--radius:0`。老名字（`--panel/--card/--line/--fg/--dim/--acc`）**保留为别名** —— 页面里 JS 生成的内联样式仍在用，直接改名会当场把那些地方变"没有颜色" ✗
- **零硬编码**：hex **56 → 0 处外露**（只剩 `:root` 里 24 个字面定义）、`border-radius` **14 → 全部走 `var(--radius)`**、彩色 `border-left` **3 → 0**（`.hbody` 的 3px 强调边改成「边框 + 表面色」，`.soon` 改成虚线警示框 —— 设计 §10.3「改用留白 + 字重 + 表面色建立层级」）
- **6 级字阶落地**：正文 14px → **15px**（满足设计 §10.6「正文 ≥15px」硬指标），11/11.5/12 → `--fs-xs`，12.5/13/13.5 → `--fs-sm`，14.5/15 → `--fs-base`，19 → `--fs-lg`，21 → `--fs-xl`
- **8 个浏览器表面**：`::selection`、滚动条（`scrollbar-width` + `::-webkit-scrollbar`）、`:focus-visible`（并**删掉 `#q:focus{outline:none}`** —— 那会让键盘用户失去焦点提示 ✗）、`tabular-nums`、`caret-color`、`text-underline-offset`、`::placeholder`、`prefers-reduced-motion`（扩到全局）
- 间距令牌用于页面结构级（`.wrap`/`section`/`.card`/`.catbox`/`.toolbar`/`#list`/`.row-scroll`）；像素级光学微调保持原值（那属模板拆分阶段）✓

**验证**：audit **162/0/0** ｜ 回归 **50/50** ｜ 契约 **0 违规** ｜ `check-page` **PASS（①–⑭）** ｜ `ui-check` **0 违规**（阳性对照通过）｜ 漂移 0 异常 ｜ **真机**：CDP 交互探针 **14/14**（CSS 大改后路由/点击/前进后退全对）+ 3 张截图逐张人工确认（无圆角、无彩边、无破版）✓ ｜ 页面 541.8 KB、外部请求 0
**踩坑（已进交接 §5 #26）**：用脚本"整篇把 hex 换成 `var()`"时，**把 token 自己的定义也换了** → `--accent:var(--accent)` **自引用** → 全页颜色失效 ✗（当场复查发现）。规矩：机械替换必须**排除 `:root` 定义区**，替换后**逐个 token 查自引用** ✓

---

## [4.10.6] — 2026-10-16 · P1-15/P1-16/P1-17「库变页面即变」（写入即重建 + 新鲜度不变量 + 一键重建）

**背景**：用户最想要的体验是「库里写入东西，页面同时更新」。现状：多数写入器要**显式加 `-Sync`** 才重建 ✗，且没有任何检查能发现"数据改了、页面还是旧的"（静默陈旧）。

**改动**：
- 新增 **`tools/rebuild-page.ps1`**（统一入口）：sync 投影 → build 页面 → **自检页面真的变新了**；`DSH_SKIP_REBUILD=1` 跳过、`DSH_REBUILD_LOCK` 防递归/并发、`-Quiet` 只静默进度但**错误永远打印**（第一版把错误也静默了 → 失败时"什么都不说、退出码 1"，无法排查 ✗）。
- **6 个写入器接上「默认重建」**：`add-repo` / `add-plan` / `workspace`（仅真写盘时）/ `add-intro`（本批次有新增时）/ `auto-tag -Apply` / `intake-check -Apply`。`-Sync` 保留兼容（额外跑一次页面自检）。
- 新增 **`刷新页面.cmd`**（工作区根，双击即重建）：内容全 ASCII + CRLF + 无 BOM（照既有 `.cmd` 约定），调用前 `chcp 65001` 让中文输出正常显示。
- audit **161 → 163 项**：新增 **P1-17 新鲜度不变量** —— 页面必须比**参与生成它的输入**新。判据用**白名单**（= sync-projects 实际读的那些文件/目录），**不是**扫 `data\` 全目录：`data\series\`（采集产物）与 `data\enrich\`（富化）不参与页面生成，扫全目录会"采一次就误报陈旧" ✗。
- **修一个静默失败的真 bug**：`sync-projects.ps1` / `build-overview.ps1` **成功时不设退出码**，而 `$LASTEXITCODE` 在 PowerShell 里是**粘的**（被调脚本不 `exit` 就不更新，会残留上一条命令的值）→ 实测：`audit` 刚 `exit 1`，紧接着 sync 明明成功，调用方却读到 1 → 误判失败 → **build 根本没跑、页面一直是旧的**。已在两个脚本末尾补 `exit 0`，并在调用侧先清 `$LASTEXITCODE` + **以输出里的成功标志为主判据** ✓

**验证**：audit **162/0/0** ｜ 回归 **50/50** ｜ 数据契约 **0 违规** ｜ `check-page` **PASS（14 项）** ｜ `ui-check` **0 违规** ｜ 漂移 0 异常。
**针对性实测**：① 反向测试（只改 `recommend-log.csv` 的 mtime、不动内容）→ P1-17 **变红**；`rebuild-page` 后回绿 ✓ ② 粘性退出码复现（先 `exit 7` 再重建）→ 重建仍成功、页面变新 ✓ ③ 负路径（`workspace.ps1` 只读列表）→ **不**触发重建 ✓ ④ 正路径（`workspace.ps1 -Status` 真写盘）→ 自动重建、页面 mtime 变新、audit 仍绿 ✓
**已知边界**：`fetch-series.ps1` 不接重建（它写 `data\series\`、`data\enrich\`，不参与页面生成；P1-17 白名单已排除）✓

---

## [4.10.5] — 2026-10-17 · P2-9 页面 hash 路由骨架（4 个一级区 + 图例抽屉）

**背景**：`overview.html` 一直是「一坨长滚动」（欢迎 → 今日新增 → 方案 → 工作区 → 分类 → 全部工具）。库存到 229 条后，找东西只能靠滚；`页面分级设计-2026-10-16.md` §1/§2 定了 4 区 + 1 抽屉的信息架构。

**改动**：
- `tools/build-overview.ps1` 新增 hash 路由：`#/home`、`#/picks[/YYYY-MM-DD]`、`#/all[?筛选]`、`#/plans[/id]`、`#/ws/id`、`#/p/owner/repo`、`#/legend`。`file://` 下**只用 `location.hash`**（理由是**不依赖 `pushState` 的版本差异**；⚠️ 旧文写「pushState 一律抛 SecurityError」**不准确**——实测 Edge 155 下只改 hash 时**不抛**，见下方更正）。
- 现有 6 个分区**不删功能、只搬家**：今日新增→`#/picks`；分类浏览 + 全部工具→`#/all`；按需求组方案 + 我的工作区→`#/plans`；欢迎→`#/home`。
- **`detail` / `showPlan` / `showWorkspace` 保留原名原行为**（第一版另起 `openDetail`/`openPlan` 包装，被 `check-page.js` 的 ⑦⑨ 两项当场抓红 —— 安全网正是按这些字面抓的，已回退并在代码里写明原因）。
- 筛选状态写进 hash（`cat`/`sub`/`tier`/`status`/`risk`/`tag`/`q`/`sort`）→ 链接可分享、浏览器后退 = 撤销筛选、刷新保持当前视图。
- 新增图例抽屉 `#/legend`（档位 / 风险 / 状态 / 徽章 / build stamp / 链接用法）；抽屉是**叠加层，不改变当前区**，Esc 逐层关闭。
- audit **159 → 163 项**：新增「hash 路由骨架（4 区 + 抽屉）」与「build stamp 格式完整」两条**页面级**检查 —— 页面退化成长滚动时不会有任何功能报错，属静默退化，必须由 audit 兜住。
- `tools/check-page.js` 新增 **⑪–⑭ 四项断言**：进入/后退/刷新一致（含未知路由回总览）、facet 写进 URL 且能复原同一视图、`#/legend` 不改当前区 + **直接载入 `#/legend` 不白屏**、工作区/方案深链能打开面板。DOM 桩补上 `location`（否则路由只走「无 location 兜底」分支，等于没测）。
- **导航改成真链接** `<a href="#/…">`（原为 `<span onclick>` → 不可 Tab 聚焦、不能右键复制链接/新标签打开 ✗）。
- 新增真机探针 **`tools/history-probe-cdp.js`**（真 Edge + CDP，14 项）与 `tools/history-probe.js`（Electron 窗口版，备选）：真鼠标事件点导航、**真浏览器历史前进/后退**、页面内 `history.back/forward`、筛选进 URL、连续后退不崩。
- **修正一条被实测推翻的旧前提**：不再写「`pushState` 在 `file://` 一律抛 SecurityError」—— 实测 Edge 155 headless 下**只改 hash** 的 `pushState` **不抛**（换路径未实测）。选 hash 的理由改写为**不依赖版本差异**（4 处文档 + 2 处代码注释 + 2 个探针同步）。

**验证**：audit **161/0/0** ｜ `check-page` **PASS（14 项全过；229/229 详情逐条打开）** ｜ `ui-check` **0 违规**（阳性对照 16 条注入全部抓到）｜ 回归 **50/50** ｜ 数据契约 **0 违规** ｜ 漂移 0 异常 ｜ 页面 537.5 KB、外部请求 0。
**真实浏览器实测（两轮）**：
1. **加载态**（Edge headless `--dump-dom` + `file://`）：8 种 URL 逐一核对 —— 无 hash→总览、`#/picks`、`#/picks/2026-10-16`、`#/all?cat=AI&tier=S`（面包屑出现）、`#/legend`（抽屉开、背后垫总览）、`#/p/owner/repo`（详情面板开）、`#/plans`、`#/ws/<id>`；工具栏只在全库区出现 ✓。**`#/legend` 直接载入的白屏就是这一步查出来的**（stub DOM 测不到渲染层）。
2. **交互链路**（`history-probe-cdp.js`，真 Edge + CDP）：**14/14 全过、退出码 0** —— 真鼠标事件点导航（按元素坐标，非 JS `.click()`）、**真浏览器历史后退/前进**、页面内 `history.back/forward`、`#/all?tier=S` 后页面仍渲染（body 3857 字）、连续后退到底不崩 ✓。**沙箱内起不了真浏览器**（mojo 命名管道被拒），需一次性放开权限或在普通桌面会话跑；探针正是这一步抓出「导航不是真链接」这个缺陷 ✓

---

## [4.10.4] — 2026-10-16 · 结构治理：单一真源 + 漂移检查 + 测试副本生成

**背景**：同一套脚本一度有 4 份拷贝、3 份是旧版（`发布测试\github-daily-picks\tools\` 与 `v5.1.0-测试副本\tools\` 各 18 个脚本全部落后），加 `发布测试\_shots\` 里 789 个 Edge 缓存文件（35.8 MB）。

**改动**：
- 删除 Edge 缓存垃圾（35.8 MB → 0.2 MB），并让 `3-生成截图.cmd` 跑完自清；
- 删除无版本号的陈旧整套拷贝；`v5.1.0-测试副本` 保留为只读快照；抢救 `测试须知.md` 与 `测试档案-v5.1.0-bug-report.md`；
- 新增 `tools\check-drift.ps1`（库 ↔ 发布包漂移，一条命令看清，异常时退出码 1）；
- 新增 `tools\make-testcopy.ps1`（两种自洽模式：demo 口径 / 库镜像口径）；
- 新增 `tools\code-health.ps1`（结构体检）与 `发布测试\README.md`（目录规则）；
- 钉死规矩：**唯一真源 = `tools\`**，改代码只在库改，副本与发布包都是产物。

**验证**：库 audit **141/0/0** ｜ check-config **17/0**（往返 22/0）｜ 回归 **11/11** ｜ PSScriptAnalyzer **0** ｜ 页面 **PASS** ｜ drift **0 异常** ｜ 副本（库镜像）**139/2/0 + check-page PASS** ｜ 副本（demo）**136/3/0 + PASS**。

---
## [4.10.3] — 2026-10-16 · 分类器回归测试（Pester）

**新增** `tests\run-tests.ps1` + `tests\taxonomy.Tests.ps1`：最小 fixture 跑真 `sync-projects.ps1`，断言分类结果；另断言真库不变量（分类锚点、DSH 技能/插件成员都带 DSH 信号、lychee 归开发工具、无孤儿分类）。**11 条用例**，`pwsh -File .\tests\run-tests.ps1` 一键跑。

**红绿验证**：摘掉 `_类目门槛` → 用例变红；把 `markdown` 加回 `效率/笔记` → 用例变红；还原后全绿。

**顺带修**：`开发/开发工具` 的中文关键词 `死链`（2 字）在中文句子里因 `\b` 规则永不命中，改为 `死链检查`（4 字）；taxonomy 的 `_变更记录` 同步说明。

**已知约定**：中文分类关键词一律 ≥4 字（≤3 字会走整词匹配，中文几乎不命中）。

---
## [4.10.2] — 2026-10-16 · taxonomy 类目级「与条件」（修通用词跨生态误吸）

**问题**：「DSH 技能」的 4 个关键词（skill / agent-skills / agent-skill / agent-tools）是通用词，任何 AI 助手技能包都会命中 → 7 条 Claude Code / Codex 生态项目被吸进 DSH 生态；`效率/笔记` 的通用词 `markdown` 把链接检查器 `lycheeverse/lychee` 判成「笔记」。

**改动**：
- `data/taxonomy.json` 新增顶层 `_类目门槛`（类目级与条件），`"DSH 生态/DSH 技能": ["dsh","deepseek-harness","cordis"]`，版本 1.6.1 → **1.6.2**（写入 `_变更记录`）；
- `Get-TwoLevelCategory` 加门槛判断（看**强+弱并集**，这样 topics 里带 dsh-plugin 的项目仍留在 DSH 生态）；children 保持数组形状，其它脚本零改动；
- `效率/笔记` 删 `markdown`；`开发/开发工具` 加 `link-checker` / `link checker` / `broken-link` / `死链` / `链接检查`。

**验证**：副本模拟 → 落地实测一致：229 条中 **变动 8 条**（7 条移出 DSH 技能、lychee 归位开发工具），**6 个分类锚点 0 变化**，DSH 技能 12 → 5，DSH 插件不变（37），audit **137/0/0**，check-config **17/0**，`check-page` **PASS**。

**备份**：`data\_backup\2026-10-16-taxfix\`。

---
## [4.10.1] — 2026-10-16 · PSScriptAnalyzer 全量整改（318 → **0** 告警）

新增 `tools\PSScriptAnalyzerSettings.psd1`（排除 WriteHost / 位置参数 / 两条命名风格，理由写在文件里），并修掉全部真问题：

- **空 catch 30 处** → `catch { $null = $_ }`（15 个文件；保留行为、明确意图）；
- **缺 BOM 的 .ps1 19 个** → 全补 UTF-8 BOM（2026-10-14 GBK 乱码事故的根因）；
- **未用变量 11 处** → 删除（含 `build-overview` 里遗留的 `$savedN` 收藏统计、`sync-projects` 里从未被读取的 `$synGroups`）；
- **null 比较方向 1 处** → `$null -ne x`；**未用参数 1 处** → 删除 `Get-ExperienceRating -License`（签名 + 调用处）；
- 安装开发期工具（工作区模式）：`.devtools\` 内 gitleaks 8.30.1 / lychee 0.24.2 / git-cliff 2.14.2 / PSScriptAnalyzer 1.25.0 / Pester 6.2.0；pre-commit 钩子接入发布包仓库。

**验证**：脚本扫描 **0 告警** ｜ audit **137/0/0** ｜ check-config 往返 **22/0** ｜ sync 正常（159 项目）｜ 页面重建 + `check-page` **PASS（229/229）**。

**事故记录（详见 `交接文档.md`）**：批量替换时替换串里的 `$_` 被当成"整个输入"，导致 15 个文件按「命中数+1」倍膨胀；靠尺寸/行数断言发现、从 `data\_backup` 全量恢复后改用 MatchEvaluator + 逐文件硬校验重做。

---
## [4.10.0] — 2026-10-16 · 规则扩充 + 人话层批量补全 + 新建 CONTEXT.md

（**事后补录**：这批改动发生在另一个会话，当时没在本文追加记录；本节由 Agent 依据文件差异补写，只写可核实的内容。）

**规则与文档**：

- `RUBRIC.md` 新增 `### 1.1 合规红线`、`## 7. 用户主动推荐项目的入库检查`；
- `SOURCES.md` 新增 `## 6. README 取数：三级降级链`、`## 7. `topic:` 类检索的已知污染`；
- `PROMPT-daily.md` 新增 `## 同一天跑多轮的分工`；
- **新建 `CONTEXT.md`**（工作区通用语言，10 节：标准文件唯一出处 / 数据分层 / 台账字段 / 人话层 / 检索与额度 / 分类 / 工作区 / 建议调整项 / 常被混淆的三组词）；
- `data/README.md` 内容更新（小节数不变）。

**工具**：

- `tools/auto-tag.ps1`：台账备注兜底收紧 —— **只在描述完全没素材时**才用备注取词，且含数字 / 元信息词（「用户清单」「0 星」等）的片段一律不要（修「搜 0 反而有结果」这类噪声）；
- `tools/build-overview.ps1`：新增 `drop_reason` 投影 → 页面详情可显示「淘汰原因」；
- `tools/sync-projects.ps1`：继续补充（本次记录时 716 行 / 39462 B），2026-10-16 早些时候加入的三重保护（缺原始层中止 / 空投影不写盘 / 数组化写入）保持完好。

**数据**：

- 人话层批量补全：**完整 123 → 183**、页面标「待补全」**95 → 36**；
- 库规模：**218 → 219** 个项目、**398 → 399** 事件。

**校验（补录后实测）**：audit **137 / 0 / 0** ｜ check-config **17 / 0** ｜ check-page **PASS**（219/219 详情逐个打开）。

---
## [4.9.0] — 2026-10-16 · 从发布包移植 7 条「发布物与交付一致性」检查 + sync-projects 加保护

背景：发布包在 v5.2/v5.3 期间积累了一批自检与一个真实修复，**原库一直没跟上**；本轮逐项评估后**只搬"通用 + 原库专属"的部分**，不搬 demo 专属口径（发布包 159 项 / 原库 159 项，两边仍各自维护）。

**① `tools/sync-projects.ps1` 补三重保护**（实测过，不是纸面改动）：

- **缺原始层就中止**：`data\seen.jsonl` 缺失时明确报错、**不做任何写入**（含 tools 备份），退出码 1（旧行为：在 `WriteAllLines` 处抛 .NET「Value cannot be null (Parameter 'contents')」）；
- **空投影不写盘**：派生结果为空时默认**不写盘**并退出 1，防止把 `projects.jsonl` / `events.jsonl` 覆写成空；确认无误可用 `-Force` 强写；
- **数组化写入**：`$projLines = @(...)` / `$evLines = @(...)`，避免空集合经管道变 `$null`。

副本实测：缺文件 → 退出 1、文件与备份都不动 ✅；清空 `seen.jsonl` 不带 `-Force` → 退出 1、`projects.jsonl` 未被改动 ✅；正常输入 → 产物与重建前**逐字节相同**（仅 `updated_at` 时间戳变化）✅。

**② audit 新增第 23 节（7 条）**，130 → **159 项**：文档相对链接全部存在 ｜ README 声明的项数 = `TOTAL_CHECKS` ｜ `data\picks`/`data\snapshots` 目录存在 ｜ sync-projects 三重保护仍在 ｜ 投递脚本含 `git add`+`commit` 且全 CRLF ｜ 页面 hero 自述数 = 主档案条数 ｜ 截图源页只含 demo 项目。

**③ README 修正**：目录树里的 `159 项`、表格与命令里的 `159 项` → **159 项**；顺手把「143 条详情逐个打开」改成不写死数字（库已 218 条）。

**没搬的**：README「演示包」口径（原库不适用）、发布包那版 **demo 分类锚点**（原库有自己的 6 条锚点，覆盖更全）。

---
## [4.8.0] — 2026-10-15 · 入口卡片（每次有产物都给）

从发布包同步（发布版 v5.0.2 的规则）：

- **每次有产物就给入口**：日报/周报跑完、项目入库、状态变更、建工作区、页面重建后，用 `present` 附上 `overview.html`（当天有日报再附 `reports/YYYY-MM-DD.md`）。在 DSH 里用户可点卡片「打开方式 → Edge」一键打开，不用自己找文件夹。
- **触发条件是「有产物」**：纯问答（解释概念、回答"为什么"、讨论方案）**不附** —— 每条回复都挂卡片会变吵。
- 非 DSH 宿主退回**纯文字路径**；卡片上的「打开方式」是**用户点击、宿主执行**，Agent 不参与、也不得假装能打开（沙箱禁止）。
- 不做"是否打开过页面"的检测：页面是只读单文件、写不了磁盘，检测只会引入假状态。

**配套同步**：

- `.dsh/skills/tool-stack/SKILL.md` 第十节加 2 行（另附文件卡片 + 不得假装能打开）；
- `tools/check-config.ps1` 同步发布版修复：`-TestRepo` 留空自动取台账首行、按 `$target.full_name` 定位、写入后**逐行比对非目标行**、还原后**全量逐行比对**（原库实测往返 22/0，台账 SHA256 前后一致）。

---
## [4.7.0] — 2026-10-13 · 按 GPT 评审改「展示语言」+ 人话层补全流水线

GPT 评审结论：方向对，但**「像开发者工具库，不像我的 AI 工具商店」**。按它给的优先级执行（第 1 人话层 / 第 2 展示语言 / 第 3 收藏工作区 / 第 4 首次体验），本轮做前两项。

### ① 展示语言全面人话化（网页 + 聊天两侧）

- **「选它因为」不再抛数据库字段**。原来显示 体验 4★ ｜ 风险 中 ｜ 7 天内有提交 ｜ GPL-3.0，现在按阈值翻译成：
  ✅ 文档比较全 ｜ 最近仍在维护 ｜ 功能比较成熟 ｜ GPL-3.0 + ⚠️ 上手要花点功夫。
  翻译表（数据驱动、不编造）：易用性 / 文档完整度 / 维护活跃 / 功能成熟度 / 风险分 / License / 星数 → ✅ 或 ⚠️ 两类人话。
- **网页方案视图改商城版式**：摘要在先（「这套要 3 步 ①…②…③… ｜ 难度 ★★☆☆☆」）→ 每角色表头「工具 ｜ 适合谁 / 为什么选它 / 要注意」→ **🥇 首选 / 🥈 备选（觉得太重可以用这个）** → 「**查看全部 N 个同类工具 →**」（点击直接按该二级分类筛选，实测 17 个 / 5 个）。
- **空角色不再像失败**：原来「库里暂无匹配工具」，现在 🔍 「运行环境与沙箱」这一步，你的工具库现在没有合适的选择。可以：① 我去 GitHub 搜 2–3 个候选（要花一点 API 额度）　② 先放着，等以后自动收录 —— 这一步不挡着你先做前面的。
- **聊天侧（tool-stack 重写）**：定位从"报告"改成"助手"——**先给 3 行摘要**，用户说展开才给详细；每角色最多 3 个、默认「1 首选 + 1 备用」；同类更多只给一行「查看全部 N 个同类工具 →」；**结尾只问一个必答问题**（「要不要存进网页？回复：保存 / 不保存」），其余优化项压成编号选项（用户回 1 3 即可）。
- **明确 chat ≠ web 的分工**：聊天偏**助手**（我建议你用 A、B、C），网页偏**商城**（表格 + 筛选 + 对比 + 收藏）；但字段与人话翻译表必须一致。
- **不再要求严格 ASD-STE100**：换成「短句 + 人话 + 像助手」。

### ② 人话层补全流水线（GPT 的第 1 优先）

GPT 判断：143 条里只有 45 条有完整人话层，**98 条只有一句话**，直接毁掉"傻瓜式"。

**诚实结论**：problem / xample 无法用规则从描述推出，硬写就是编造；一次全补要几十万 token。所以做成**可分批执行的流水线**：

| 工具 | 作用 |
|---|---|
| 	ools/humanize-next.ps1 | 列出下一批该补的（优先：收藏 > 研究中 > 用户自己加的 > 星数高），并标注**哪些能用项目自带中文描述直接写（0 额度）**、哪些需 1 次 API 读 README |
| 	ools/add-intro.ps1 | 批量写入人话层（**不覆盖已有**、缺字段就缺着、source 如实填、-Apply -Sync 自动重建 + 页面自检） |

实测拆分：待补 **76** 条 = **29 条**可用中文描述直接写（0 额度）+ **47 条**需抓 README。已写进日报收尾流程：**每次补 5 条**。

### 校验

udit.ps1 新增 159 项（humanize-next / add-intro 存在且被 SKILL 引用）。检查数 **119 → 121**。

### 未做（GPT 排在第 3、4 位，下一轮）

- **收藏 / 工作区**：⭐常用 / ❤️喜欢 / 🧪待测试 / 📌工作区（命名集合）。现有 status 白名单已含 saved/esearching，但「工作区」需要新的数据层（data/workspaces.jsonl）。
- **首次打开体验**：目前首屏是「今日新增 → 方案 → 分类 → 收藏 → 全部工具」，缺一个"从这里开始"的引导。
---

## [4.6.0] — 2026-10-13 · 对话侧能力：`/tool-stack` 指令 + 日报后追问

用户要的两件事：**① 一个 `/` 指令，在对话里按需求现场配一套，并主动追问**（要不要固化进网页、要不要补缺的工具、有什么风险）；**② 日报跑完后也要主动问用户几个问题**。

### ① 新指令 `/tool-stack`（独立 skill）

`E:\工作区\GitHub日报\.dsh\skills\tool-stack\SKILL.md` —— DSH 的 `/` 指令即 skill，所以它现在是可调用的 `/tool-stack`。

- **触发**：「我要做 ___」「做 ___ 需要哪些工具」「帮我配一套」「/tool-stack」。
- **流程**：复述需求 → **优先复用 `data/plans.json` 已有场景的角色划分** → 逐角色从本地库填工具（每角色≤2 个，排除已淘汰）→ 每个工具给「选它因为」（体验/风险/活跃/许可证，全部来自数据）。
- **配完必须追问 5 件事**：① 要不要固化成网页方案 ② 缺的工具要不要去 GitHub 搜 ③ 风险非低/无 License/一年没提交的要不要换替代 ④ 要不要先只试第一步 ⑤ 要不要记下你的备注（别让它只活在聊天里）。
- **成本透明**：匹配与固化 **0 token**；只有「去 GitHub 搜候选」要花额度，**先说清再动**。

### ② 三个配套工具

| 工具 | 作用 |
|---|---|
| `tools/add-plan.ps1` | 把对话里配好的搭配**固化成网页方案**（查重 id/name，写 `data/plans.json`，提示跑 build + check-page） |
| `tools/daily-questions.ps1` | **日报后追问**：扫当天产物与待办，输出 3–6 条**需要用户拍板**的问题（每条第带数据依据） |
| `tools/suggest-plans.ps1` | **方案候选自动化**：挖「工具攒够但没有对应场景」的方向 → `data/plan-suggestions.jsonl` 待批（与同义词候选、分类候选同一套「机器发现、人批准」机制） |

`daily-questions.ps1` 覆盖的问点：未验证的安装方式要不要核 README / 风险高的要不要先看 / 剔除理由要不要确认 / 人话层缺口要不要补 / 缺口词与三类候选要不要批 / 未评档的用户推荐要不要评估 / 收藏要不要配方案 / 日报文件缺失要不要补跑。**并明确要求「只问需要拍板的，不要拿教程式问题凑数」**。

### ③ 实测

- 追问工具：跑出 6 条真实问题（3 条 S/A 待核 README、4 条剔除待确认、98 条人话层缺口、2 个缺口词、30 个同义词候选、1 条分类候选）。
- 方案候选：挖出 **AI Agent（13 个工具却没有任何方案覆盖）** → 用 `add-plan.ps1` **固化成「用 AI Agent 干活」**（3 个角色）→ 页面方案区 10 → **11 个场景**，`check-page` PASS。
- 顺手修掉：`daily-questions.ps1` 里 `` `t `` 被 PowerShell 当制表符转义（输出出现 `ools\...`）→ 改为不用反引号。

### 校验

`audit.ps1` 第 22 节新增 **159 项**：tool-stack 技能存在、add-plan / daily-questions / suggest-plans 三个工具存在且被 SKILL 引用。检查数 **115 → 119**。
`github-daily-picks/SKILL.md` 收尾流程新增「**必须给用户追问**」，并在方案区注明可用 `/tool-stack` + `add-plan.ps1` 固化、用 `suggest-plans.ps1` 发现新方向。

---

## [4.5.0] — 2026-10-13 · 页内「方案」：需求 → 工具组合 + 为什么这么配（v3.1 第八节完整版）

用户要的最终形态：**在页面里就有一套，并说明为什么这么搭配**。本轮落地。

### 分工设计（关键：不编造、不指定产品）

| 层 | 内容 | 来源 |
|---|---|---|
| **角色** | 一个场景要走哪几步（如 AI 视频 = 画面生成 → 成片剪辑 → 配音音频 → 素材管理） | 人工写一次，`data/plans.json` |
| **为什么需要这一步** | 「视频的画面素材从这里来」这类**角色必要性** | 人工写一次，同上 |
| **填哪个工具** | 按该角色的二级分类 + 功能标签，从本地库**自动匹配**最优 1–2 个 | 数据驱动 |
| **选它因为** | 体验 X★ ｜ 风险低 ｜ 7 天内有提交 ｜ MIT | 数据自动生成 |

### 交付

- **`data/plans.json`**：**10 个场景**模板 —— 做 AI 视频 / AI 绘画出图 / 产品设计 UI / 本地跑 AI / 写代码 / 找文件整理素材 / 做 PPT 写文档 / 配音语音 / **给 DSH 加装能力** / 查资料学术研究。每个含触发词、场景说明、角色与必要性。
- **页面新增「🧩 按需求组方案」区**：点场景 → 右侧滑出方案视图（角色 → 为什么需要 → 自动配好的工具 → 选它因为）。实测「做 AI 视频」= 4 个角色说明 + 4 组自动配好的工具。
- **搜索联动**：输入场景词（「做视频」「本地跑ai」）时，结果区顶部主动提示「💡 这像是一个场景 —— 看「做 AI 视频」该怎么配」。
- **匹配不到就不硬凑**：某个角色库里没工具 → 显示「库里暂无匹配工具 —— 可以走临时检索去 GitHub 找」。
- **成本**：纯本地匹配，**0 token、0 联网、毫秒级**；每日运行成本不变。

### 校验

`audit.ps1` 第 22 节新增 **159 项**：方案模板存在且可解析、模板含角色与「为什么需要」、页面含方案视图（`showPlan` + `planRoleTools` + `planGrid`）。`check-page.js` 新增第 ⑨ 项：**真跑方案流程**（场景按钮区非空 → 打开场景 → 校验角色说明 ≥2 + 工具组 ≥1 + 标题正确）。检查数 **112 → 115**。

实测：`PAGE CHECK: PASS`（143/143 详情 + 对比 + 分组 + 分词/容错/缺口 + **方案 10 个场景**）。

---

## [4.4.0] — 2026-10-13 · 搜索变智能 + 词表自适应（用户点名的问题）

用户反馈「**搜索还是不够智能**」，并猜「关键词表会不会一成不变、不随库增长」。**实测证实他猜中了**：

| 指标（起点） | 实测 |
|---|---|
| 同义词表 | 14 组 / 108 词，**手工写死**；库从 90 → 143 期间**加了 0 个词** |
| 功能标签 / 用户搜索词覆盖 | **45 / 143 = 31%**（搜索最有效的强信号只覆盖三成） |
| 落「其他」分类 | **53 / 143 = 37%**（等于在分类浏览里隐身） |
| 分词 / 容错 | 无（纯整串子串匹配，多词查询与错字都容易失败） |
| 搜不到之后 | 什么也不发生（**没有反馈回路**） |

### 五个问题，五处修复（全部本地规则，**运行时 0 token**）

| # | 修复 | 效果 |
|---|---|---|
| 1 | 新增 `tools/auto-tag.ps1`：用 topics + 描述（**只取含中文片段**，过滤语言/许可证/元信息词）给缺标签项目补 `function_tags`/`user_keywords`，生成项带 `source:'auto(topics+descr)'`、**不覆盖人工条目** | 标签覆盖 **31% → 74%**（106/143） |
| 2 | 新增 `tools/suggest-terms.ps1`：全库词频统计 − 已收录词 = 候选新词（含次数与示例仓库） | 一次跑出 **125 个候选**（如 `claude-code` 19 次、`cordis` 12 次） |
| 3 | 新增 `tools/gaps.ps1`：**搜索缺口闭环**——`-Add "词"` 记下；默认复检（现在能搜到几条 / 与哪些已收录词最接近 / 该加进哪组） | 实测「配额」→ 命中 2 条并给出补词建议；「提示词工程」→ 判定库里确实没有 |
| 4 | 页面：**分词 + 错字容错**（编辑距离 ≤1，`comfui` → `comfyui`）、多词 **AND** 语义 | 多词查询更精确，错字也能搜到 |
| 5 | `taxonomy.json` 新增一级「**DSH 生态**」（DSH 插件 / DSH 技能 / DSH 配置），并按流程记入 `taxonomy-suggestions.jsonl`（status=approved） | 「其他」**37% → 24%** |

### 页面端缺口记录（页面写不了工作区，故用「记下 + 复制」）

搜不到时出现「**记下这个词**」按钮（写入 `localStorage` + 复制剪贴板），顶部显示「⚠ 搜索缺口 N（点我复制）」；用户复制后发到对话，Agent 用 `gaps.ps1 -Add` 落盘并补词。**这是唯一诚实的做法**——静态本地页无法直接追加文件，所以不假装能自动写。

### 校验

`audit.ps1` 第 22 节新增 **159 项**：auto-tag / suggest-terms / gaps 三个工具存在、SKILL 含搜索缺口说明、页面含分词+容错+缺口记录。`check-page.js` 新增第 ⑧ 项：**真跑多词 AND、错字命中、缺口记录**。检查数 **108 → 112**。

实测：`PAGE CHECK: PASS`（143/143 详情可点 + 对比 + 分组 + 分词/容错/缺口）。

### 过程中修掉的自身缺陷

- `auto-tag.ps1` 第一版按标点切英文描述，切出 `is a high`、`Incubating` 这类垃圾标签 → 改为**只取含中文片段**，并过滤语言/许可证词。
- 台账备注兜底产出了「0 星」「14 后无提交」这类元信息当搜索词 → 增加「含数字/含元信息词一律丢弃」。
- `gaps.ps1` 的 Levenshtein 写成 `(0) * $n` —— PowerShell 里那是**算术乘法**（结果 0），不是数组重复，导致越界 → 改用 `New-Object 'int[]'`。
- `gaps.ps1` 字符串里用 `\"` 转义 —— PowerShell 用反引号，`\"` 会提前闭合字符串 → 改单引号。

### 待办（下一轮）

**页内「方案」**（v3.1 第八节的完整体验）：选场景 → 页面直接给出工具组合 + 每个角色的必要性 + 每个工具的选择依据。已确认设计：**运行时 0 token、瞬间出结果**；「为什么这么搭配」= 角色必要性（人工写一次）+ 选择依据（数据自动生成）。

---

## [4.3.0] — 2026-10-13 · v3.1 验收清单对齐（159 项缺口补齐）

按外部评审给出的 **v3.1 最终验收清单**（14 节）逐条比对，13 节已达标，补掉 4 个真缺口：

| v3.1 条目 | 缺口 | 补齐方式 |
|---|---|---|
| 三节：详情必须有「它解决什么问题」「比如」 | 数据有，但为省体积没在页面显示 | 重新内嵌 `prob`/`ex`（约 +60 B/条），详情恢复「🎯 它解决什么问题」「🧪 举个例子」两区 |
| 四节：功能备注要**多维星级** | 原来只有数字进度条 | 改为 **6 维星级**：上手难度 / 本地运行难度 / 文档质量 / 功能成熟度 / 活跃程度 / 推荐程度（全部由已有评分折算，仍**不看 star 数**） |
| 五节：搜索要按**优先级排序** | 原来只匹配、不排序 | 新增 `matchScore()`：项目全名 100 > 简称 95 > 简称前缀 85 > GitHub ID 80 > 功能标签 65 > 一句话 50 > 分类 45 > 其他 25；搜索时按匹配度优先、再用所选排序做次序 |
| **八节：按需求推荐工具组合** | **完全没做** | 新增 `tools/compose.ps1`：需求 → 本地库匹配（关键词+同义词+两级分类+功能标签）→ **按用途分组**输出每组最优 1–2 个；**页面对应形态**：搜索后点「按用途分组」。**只归类、不编造流程顺序** |

### 同时补齐的两条纪律（v3.1 第七、十一、十二节）

- **名字 / 简称 / 链接的识别**：链接 → 解析；`owner/repo` → 直接用；**只有名字时先搜一次定位到唯一 `owner/repo`**，多候选让用户确认，**不猜**。
- **额度与 token 纪律**：每日 3–5 次调用；临时检索 ≤2；组合与对比 0 次（纯本地）；`per_page` 取小值；响应落盘后从 spill 文件提取字段；只有 S 档才补调 README；不每天重分析全库。

### 校验

`audit.ps1` 第 22 节调整 159 项 + 新增 159 项：功能备注多维评分、含「它解决什么问题/举个例子」、搜索优先级排序、按用途分组、**compose.ps1 + SKILL 工具组合流程**。`check-page.js` 新增第 ⑦ 项：**真跑搜索优先级与分组视图**（搜简称必须命中该条 + 分组视图可用）。检查数 **104 → 108**。

### 现场记录：用户主动添加功能已被真实使用

本轮发现有人在 19:42–19:51 用 `add-repo.ps1` 把 **53 个已安装/候选 DSH 插件**录入了库（全部 `origin=user`，备注形如「已安装插件:xxx」），项目库从 90 → **143** 条。全部不变量通过（无重复 id、status 合法、事件完整、143/143 详情可点）。**这正是第七节要的效果**——用户推荐 ≠ 日报推荐，不污染推荐区。

顺带发现并修掉：我把详情区标题从「使用体验评分」改成「功能备注」后，`audit.ps1` 仍在找旧文案 → FAIL。**检查有牙齿的又一次证明**（改 UI 文案会连带提醒改校验）。

---

## [4.2.0] — 2026-10-13 · 第三阶段补齐：页内对比 + 临时检索闭环

用户两个问题暴露的能力缺口，一次补完：**「对比还要在对话里做？」** 和 **「能不能按我今天的需求临时去搜、搜完自己加进去？」**

### ① 页内项目对比（对比功能从"命令行"变成"点两下"）

- `overview.html` 每张卡片右上角新增「对比」按钮：勾选两个 → 右下角悬浮条出现「查看对比」→ 点开即出对比表（**15 行**：一句话定位 / 是什么 / 核心功能 / 常见用途 / 使用案例 / 不适合 / 上手难度 / 运行环境 / 体验评分 / 星数 / 最近提交 / License / 风险 / 档位 + 「怎么选」自动建议）。
- **纯前端计算**：数据已内嵌，不调 API、不耗额度、不需要命令行、不需要经过对话。
- 与 `compare.ps1` 同一套字段与判断口径；命令行版本保留给批量/脚本场景。
- 交互细节：点「对比」不会误开详情（`stopPropagation`）；选满 2 个再选第 3 个会自动顶掉最早那个；`Esc` 同时关面板与清空选择。

### ② 临时检索闭环（按需求找工具 → 核实 → 入库）

SKILL.md 第十二节新增小节，把原来只存在于对话里的动作变成**可复现流程**：

1. 中文需求 → 英文检索词 + 限定条件（给出例：「自动整理下载文件夹」→ `topic:file-organizer`）
2. **只呈现 2–3 个候选**：一句话 / 星数 / License / 最近更新 / 风险 / 上手方式（未核实标「未验证」）
3. **先去重**：已在库中就提示「已在库中（当前状态 X）」并问要不要直接对比
4. 用户点头 → `tools/add-repo.ps1` 入库（`origin=user`、`tier=unrated`）
5. 写运行日志「临时检索：需求 / 检索式 / 结果 / 是否入库」
- **额度纪律**：单轮临时检索 ≤2 次调用，计入当日额度；额度不够只给计划不出结果。
- **两条硬约束**：不得凭记忆写星数/License（必须有本次 API 返回）；命中合规红线直接剔除且不给链接。

### 校验

`audit.ps1` 第 22 节新增 **159 项**：页面含页内对比功能、SKILL 含临时检索流程（防止能力只存在于对话里、下次不可复现）。`check-page.js` 新增第 ⑥ 项：**真跑一遍对比流程**（选两个 → 出表 → 校验 15 行 + 含「怎么选」+ 含双方项目名 + 面板打开）。检查数 **102 → 104**。

实测：`PAGE CHECK: PASS`（详情 90/90 + 对比 15 行 + 0 处 null 元素）。

---

## [4.1.1] — 2026-10-13 · 修复「卡片点不了」（PowerShell 空数组塌陷 → 前端 TypeError）

用户报「怎么点不了这些卡片了？只能这样看」：`overview.html` 卡片正常显示，点击毫无反应。

### 根因（完整链路）

```
sync: user_notes = if (...) { @(...) } else { @() }
   ↓  PowerShell 陷阱：语句值返回空数组会**塌成 $null**（实测：{"k":null}）
projects.jsonl: "user_notes": null
   ↓  build-overview 里 @($p.user_notes) → @($null)
   ↓  第二个陷阱：@($null) 是「含一个 null 的数组」，**不是空数组**
overview.html: "un":[null]（90 条全是）
   ↓  前端 p.un.length === 1（真值）→ .map(x=>x.date) → x 为 null
detail() 抛 TypeError: Cannot read properties of null (reading 'date')
   → 面板永远打不开。**卡片渲染不经过这段代码，所以页面看起来完全正常。**
```

### 修复（三层防线）

| 层 | 修法 |
|---|---|
| 数据源 `sync-projects.ps1` | 6 处 `$x = if (...) { @() }` 全部改为「先 `= @()` 再 if 赋值」（`function_tags` / `user_keywords` / `synonyms` / `user_notes` / `$snaps` / `$plist` / `$hist` / meta 的 `topics`） |
| 投影 `build-overview.ps1` | `un` / `ft` 显式过滤 null 元素；无人话层时 `fn` 用 `@()` 而非 `@($null,$null,...)`（顺带省约 1 KB） |
| 前端 JS | `p.un.filter(x=>x)` 兜底，即使数据脏也不再抛错 |

### 新增防复发机制

| 机制 | 内容 |
|---|---|
| **`tools/check-page.ps1` + `check-page.js`** | **真执行页面 JS**：语法检查 → 初始化 → **逐个项目调用 `detail()` 验证面板能开** → 渲染/筛选 → 数组 null 扫描。本机无 node 时自动用 DSH 自带 Electron（`ELECTRON_RUN_AS_NODE=1`）。实测结果 **90/90 可点、0 处 null**。 |
| `audit.ps1` 第 22 节新增 159 项 | 页面内嵌数据不得含 `[null]`——语法/字段检查抓不到这类错，数据级检查兜住。**101 → 102** |
| `SKILL.md` 第五节 | 收尾流程增加「页面生成后必须跑 `check-page.ps1`，PASS 才算出货」 |

### 教训

1. **PowerShell 的 `if` 表达式返回空集合会变 `$null`**，用 `@()` 显式初始化是唯一安全写法。已在 `sync-projects.ps1` 里注释标明。
2. **`@($null)` 不等于空数组**，是含一个 null 的数组。取数组字段前要过滤。
3. **单文件页面的 JS 错误是"隐形"的**：渲染路径和交互路径是两段代码，前者正常不代表后者没事。**必须真跑一遍再交付**——这也是本次新增 `check-page.ps1` 的原因。

---

## [4.1.0] — 2026-10-13 · 第二阶段：用户推荐入库 + 项目对比（附当日运行事故修复）

### 新增功能

**⑥ 用户主动推荐项目**（`tools/add-repo.ps1` + SKILL.md 第十二节）

- 触发：用户说「这个项目不错：owner/repo」。Agent 先 `web_fetch` 核实（1 次调用计入额度），再调脚本入库。
- 脚本**不联网**（本机 shell 连不通 GitHub），只落盘原始来源并同步：新项目写 `seen.jsonl`（`origin=user`）+ 当日 `meta/` + `snapshots/`；**已存在则不重复添加**，只往 `data/user-notes.jsonl` 记「用户曾推荐过 + 备注」。
- `tier=unrated`（页面显示「未评档」），**不伪装成 S/A/B**；用户备注是个人数据，只进原始层，不进 human 层。
- 双路径实测通过：路径 A（已存在，seen 不变 + 备注落盘）、路径 B（新入库，四处落盘 + 投影 `unrated/user/未推荐` 正确），测试数据已清理。

**⑦ 项目对比**（`tools/compare.ps1`）

- `compare.ps1 A B` → Markdown 对比表（一句话定位/是什么/核心功能/适合谁/使用案例/不适合/上手难度/运行环境/体验评分/星数/最近提交/License/风险/档位 + 自动「怎么选」）；`-Similar owner/repo` → 按共同功能标签 + 同二级分类找同类。
- 数据全来自本地知识库，**不调 API 不耗额度**；缺失标「（待补全）」；「怎么选」只比评分/风险/上手难度三项并强制带「仅供参考」。
- **默认不落盘**，用户明确说保存才加 `-Save`（写入 `reports/comparisons/`）——避免一次性对比污染数据库。
- 实测 demo：`DigUp vs fsearch`（同类对手，逐维对比 + 自动建议输出正确）。

### 当日运行暴露并修复的缺陷

| 缺陷 | 修复 |
|---|---|
| 日报把 `liseami/CCBaga`（无描述）判为 A 档「降档观察」，与「无描述按硬性排除」冲突 | 改判 `dropped`（放弃 + 90 天冷却），报告 / index / CSV / picks 四处对齐（S+A 由 4 改 3） |
| 淘汰项 `awesome-jev-use-cases` 漏入台账，90 天冷却无从跟踪 | 补录 `seen.jsonl`（status=dropped） |
| 事件 `src` 标签靠「有没有 score」猜：无 score 的真实 picks（10-12 的 3 条 A 档）被误标成 `csv(兜底)` | 合成兜底记录**自带 `src='csv(兜底)'` 身份标记**，真实 picks 默认 `picks`；新回归检查实测揪出后修复，10-11 的 8 条真兜底事件不受影响 |
| 分类器子串误匹配：DigUp 描述里的 "notes" 把它拽进「AI/AI办公」 | 短关键词（≤3 字符）改**整词匹配**；**人话层标签为强信号、描述为弱信号**两档匹配；taxonomy 1.2.0 补文件搜索词 |
| `-Similar` 只靠同分类就上榜（办公软件混进文件搜索同类） | 门槛改为「至少一个共同标签或同二级分类」；无共同标签时显示「同二级分类」 |
| 页面 `unrated` 档显示成 "unrated 档"、档位筛选拿 null 当 unrated | 卡片/详情/筛选三处显式处理 `unrated` 与 `dropped`；新增「已淘汰」pill |
| `sync-projects.ps1` 无版本控制，昨日被正则改坏 1807 行无法回滚 | **sync 启动时自动备份** `tools/*.ps1` + `audit.ps1` 到 `data/_backup/YYYY-MM-DD/`（内容变化才覆盖写） |
| 同类缺陷复发无防线 | `audit.ps1` 新增 159 项回归检查（§19）：已放弃 pick 不产生推荐事件；CSV 兜底不与 picks 记录重复注入。**99 → 101** |

### 文档

- SKILL.md 新增**第十二节「用户主动操作」**（入库流程 + 纪律 + 降级链），原十二（自查清单）顺延为十三；frontmatter 增加对比/入库触发词；台账字段表补 `origin`。
- `tools/README.md` 重写为全部 6 个脚本的索引（含调用约定与备份说明）。

---

## [4.0.0] — 2026-10-13 · 第一阶段：从「日报」变成「我的开源工具库」

按用户最终产品定位（经外部评审确认）执行第一阶段。**定位：本地个人开源软件知识库**，日报只是每日新增入口。

### ① HTML 单文件化（用户最高优先级：双击即用）

- `overview.html` **全部内嵌**，**移除所有 `fetch`** —— `file://` 协议下浏览器禁止读同目录文件，这是此前"点详情是空的"的根因。
- 顺手做体积压缩（159 项外推）：
  - 不内嵌 `url`（前端用 `https://github.com/` + `id` 拼回）：省约 42 B/条
  - 有人话层时不内嵌英文 `desc`：省约 51 B/条
  - 不内嵌 `prob` / `ex` / `uk` / `extra`（改由 `one` + `note` 承担）：省约 86 B/条
  - 结果：**每项约 1.3 KB → 159 项约 4.8 MB**
- 新增校验：`audit.ps1` 第 22 节检查**页面不得再出现 `fetch(`**，防止以后回退成"要服务器才能看"。

### ② 首页改造：不再像日报

「我的 GitHub 项目情报库」→ **「我的开源工具库」**。三个入口：
**今日新增**（每天进货的入口）／**分类浏览**（两级）／**搜索工具**（需求语言）。

### ③ 小白理解层（页面完整展示）

详情面板改为：💡 一句话理解 → 📝 为什么值得留意 → 📘 功能说明（是什么/核心功能/常见用途/使用案例/不适合什么场景）→ ⭐ 使用体验评分 → 🏷 功能与搜索词 → 📈 成长记录 → 🔧 详细信息。

### ④ 使用体验五星评分（**与 S/A/B 推荐档分离**）

外部评审结论：两套评级不能重复。**S/A/B 回答"今天值不值得推荐"；五星回答"我用起来爽不爽"**。

```
体验评分 = 易用性 30% + 文档完整度 20% + 功能成熟度 20% + 维护活跃 15% + 风险 15%
```

**关键纪律：不看 star 数。** 500 star 但装上就能用的可以是五星；5 万 star 但要配半天环境只能三星。

**信息不足 → 不评分**（返回 `null`，页面显示「未评分」）。理由：历史数据里 56 条没有描述，若强行评分会出现"60% 项目都是 1 星"这种没有信息量的结果——**信息不足不等于难用**。

### ⑤ 两级分类体系（`data/taxonomy.json`）

- 一级：AI / 设计 / 效率 / 开发 / 学习 / 数据 / 安全 / 运维 / 其他
- 二级：如 `AI → AI聊天 / AI绘画 / AI视频 / AI写作 / AI Agent / 本地模型 / 模型训练 / AI办公`
- **纪律：分类只能从 `taxonomy.json` 取，不允许运行时自由创建。** 否则会出现「AI绘画 / AI 绘图 / 生成式视觉」三个同义分类。
- 新方向走 **候选 → 人工批准 → 加入 taxonomy**（`data/taxonomy-suggestions.jsonl`）。
- 匹配规则按关键词最长匹配优先；匹配不到归「其他 → 其他工具」。

### 字段新增（**不修改已有数据**）

| 字段 | 说明 |
|---|---|
| `origin` | `auto`（自动发现）／`user`（用户推荐）。与 `source` 区分：后者仍表示来自哪个检索式（Q1/专题…） |
| `origin_note` | 人类可读的来源标记（「自动发现」/「用户推荐」） |
| `tier: unrated` | 用户主动添加、未经日报评分的项目。**不伪装成 S/A/B** |
| `category` | `{l1, l2}` 两级分类 |
| `experience` | `{stars, score, parts}` 使用体验评分 |
| `user_notes[]` | 用户自己的备注（**个人数据，与机器生成的人话层分开存**） |

### 新增原始来源层（不进投影会丢的都要放这层）

| 文件 | 作用 |
|---|---|
| `data/user-notes.jsonl` | 用户备注。**为什么单独一层**：`human/` 是机器生成，用户备注是个人数据，混在一起重建投影会丢 |
| `data/taxonomy-suggestions.jsonl` | 候选分类，等人工批准 |

两者均**已纳入输入指纹**（改了会触发重建），并配 `.README.md` 说明为何 JSONL 里不能写注释。

### 校验

`audit.ps1` 新增**第 22 节**（159 项）：页面无 fetch、无外部资源、三入口齐全、含人话层与五星、含两级分类、含成长记录、含来源区分、未内嵌 url、taxonomy 可解析且每级有二级、兜底分类存在、用户备注与候选分类文件合法。检查数 **81 → 99**。

### 本轮修复的实现缺陷

- `user-notes.jsonl` / `taxonomy-suggestions.jsonl` 最初写成带 `#` 注释的文件，被 `Read-Jsonl` 判为"损坏行"报警告 → 改为**空 JSONL + 独立 README**。
- 两者**未纳入输入指纹** → 改了不触发重建（与上一轮 `meta`/`human` 同类问题，已修）。

### 未做（后续阶段）

- 第二阶段：用户主动添加项目（字段已备好，**流程未实现**）、项目对比
- 第三阶段：自动分类建议、更强自然语言搜索、成长分析
- 人话层覆盖仍为 42/61（剩余冷门项目未补，用户已知悉成本）

---

## [3.0.0] — 2026-10-13 · 人话层（从"数据库"变成"给人用的工具百科"）

用户反馈原话：「它更像给开发者看的数据库，而不是给普通人使用的 GitHub 工具知识库」。
目标从"保存 GitHub 信息"改为**像逛软件库一样快速理解：这是什么 / 能帮我干什么 / 什么时候该用它**。

### 新增：人话层（`data/human/`）——这是数据契约的变化，不只是页面美化

| 文件 | 作用 |
|---|---|
| `data/human/repo-intro.jsonl` | 项目介绍：`one_liner`（一句话理解）/ `problem`（它解决什么问题）/ `example`（举个例子）/ `feature_note`（功能说明五项） |
| `data/human/function-tags.jsonl` | `function_tags`（功能标签）/ `user_keywords`（用户可能搜的词）/ `synonyms`（同义词） |
| `data/human/search-synonyms.jsonl` | **全局同义词表 14 组 / 108 个词**（如「画图＝绘画＝文生图＝AI画图」） |

**为什么必须落成数据而不是写死在页面里**：页面是投影，重生成就会丢；人话层是**原始来源**，优先于自动推断。
`sync-projects.ps1` 读取后合并进 `projects.jsonl`，且人话层文件已纳入输入指纹（改了会触发重建）。

### 覆盖与诚实纪律

| 状态 | 数量 | 说明 |
|---|---|---|
| `complete` | **20** | 曾进推荐区、有 API 描述支撑的项目，四字段齐全 |
| `partial` | **56** | 仅有台账一句备注，**只写得出 `one_liner`**，其余留空并显示「待补全」 |

**没有为 76 条全部硬编介绍**。素材不足就标「待补全」——页面明确写着「上面这句来自当日台账备注，是唯一可用素材，未做任何推断」。

### 搜索改造：用户思维

- **同义词扩展**：搜「画图」自动扩展成整组词（绘画/作图/图片生成/文生图/AI画图/text-to-image…）再匹配。
- **匹配范围扩到全部字段**：`id` / `description` / `topics` / 六维分类 / `function_tags` / `user_keywords` / `synonyms` / `one_liner` / `problem` / `example` / `feature_note` 全文 / `note`。
- **实测**：搜「画图」命中 4 条、「抠图」命中 3 条、「本地跑模型」命中 3 条——**普通用户不知道项目名也能找到**。

### 页面重构（v3）

- **分类入口改成用户视角大类**：AI 工具 / 开发工具 / 设计图像工具 / 数据工具 / 效率工具 / 学习工具 / 安全工具 / 运维工具，另加**功能标签云**。
- **卡片**：项目名 → **一句话理解** → 功能标签 → 风险/状态 → 星数与最近更新。机器字段退到详情。
- **详情面板**：结构化四区 —— 💡 一句话理解 / 🎯 它解决什么问题 / 🧪 举个例子 / 📘 功能说明（是什么·核心功能·常见用途·使用案例·不适合什么场景），末尾才是 🔧 详细信息。
- **体积优化（分层加载）**：卡片只内嵌「一句话 + 状态 + 功能标签」；完整人话层落到 `data/projects-detail.json`，**点开卡片时按需读取**。页面由 98.7 KB 降到 **74.6 KB**（数据部分每项 479 B → 159 项约 1.7 MB）。
- **降级处理**：`file://` 下浏览器可能禁止本地 `fetch`，脚本捕获失败并在详情里**明确提示解决办法**，而不是静默空着。

### 校验

- `audit.ps1` 新增**第 21 节**（159 项）：人话层三文件齐全、条目四字段齐全、功能说明含五项、功能标签含标签与搜索词、已推荐项目都有人话层。检查数 **75 → 81**。

### 本轮修复的实现缺陷

- `human` 等字段**定义了变量却忘记加入对象字面量**，导致人话层没进 `projects.jsonl`（已修）。
- `data/meta/` 与 `data/human/` **未纳入输入指纹**，改了不会触发重建（已修）。

### 未做（用户提到但本轮未实现）

- **项目关系**（"这个工具和那个工具有什么关系"）——用户第五点提到，本轮**未实现显式关联字段**。数据层已有 `topics` 与 `function_tags` 可做基础聚类，如实标注此项未做。

---

## [2.1.0] — 2026-10-13 · 依外部评审修正（元数据层 / 事件扩充 / 原生字段分类 / 仪表盘首页）

外部评审认可 v2.0.0 方向，提出 6 条修正。逐条落实（含 1 条按事实修正）：

### 1. 修正「唯一事实源」表述（采纳）

- 原先写「流水是唯一事实源」，不准确——事实由**多个来源**共同构成：GitHub API 的返回值（`seen`/`snapshots`/`picks`/`meta`）**以及用户的操作**（`status-log`）。
- 改为明确数据流：**原始来源 → 投影 → 视图**。`projects.jsonl` 被定义为**当前状态投影**，不是人工维护的事实源。
- 同步修正 `data/README.md` 与 `SKILL.md` 第五节的表述。
- **未采纳**评审建议中的「原始事件来源 → events.jsonl → projects.jsonl」链路写法：`events.jsonl` 与 `projects.jsonl` **同为投影**，都从原始来源派生，不存在 events 再派生 projects 的层级。链式描述会误导实现。

### 2. 新增元数据层 `data/meta/YYYY-MM-DD.jsonl`（关键）

- **这是本轮最重要的结构补充**。只有"当前快照"**算不出任何变化**，必须有按天追加的历史层。
- 一次性把 5 批补录（`data/backfill/`，保留作来源凭证）合并为首份 `data/meta/2026-10-13.jsonl`。
- 日常运行新增落盘：当日候选的 API 元数据直接写入 `data/meta/YYYY-MM-DD.jsonl`（**不需额外调用**，Search 返回体自带）。

### 3. 事件类型 7 → 12 种（采纳）

新增 5 种，全部靠**回放 `data/meta/` 历史**得出：

| 新增类型 | 触发 |
|---|---|
| `metadata_updated` | `description` 或 `topics` 变化（合并为一次，避免刷屏） |
| `license_changed` | License 变化 |
| `archived_changed` | 归档状态变化 |
| `category_changed` | 自动分类的领域/形态/用途发生变化 |
| `release_detected` | `pushed_at` 前移**且**距上次记 release ≥ 14 天 |

**`release_detected` 是近似信号**，已在 `data/README.md` 明确标注：Search API 不直接返回 release，脚本用 `pushed_at` 前移 + 间隔近似「有显著更新」，**不是精确 release 记录，日报中不得当作 Release 事实引用**。

### 4. 分类器优先使用 GitHub 原生字段（采纳）

- 原先打分只用了 `topics/description/note/id`；现在**明确纳入全部原生字段**：`language` / `topics` / `description` / `name`。
- 新增 `$LANG_FORM` 映射（语言 → 形态），仅在关键词未给出结论时兜底。
- **同时暴露并修复一个旧缺陷**：分类函数此前用 `[string[]]$pairs` + 嵌套哈希表时参数绑定异常，导致 **76 条全部落到兜底值**；改为显式 `param()` + 数组对形式后修复。

### 5. 首页改为仪表盘（采纳）

`overview.html` 从"列表"改为"个人项目库入口"：统计卡（总数/推荐过/收藏/观察中/有描述/有 License）、搜索入口（`/` 聚焦）、分类入口（六维点选筛选）、我的收藏区、最近更新区、全部项目区。
卡片补齐评审要求的全部字段：名称 / 一句话描述 / 分类标签 / License / 风险 / 状态 / 最近更新时间 / 进入详情与历史。

### 6. 365 天规模模拟验收（采纳，且这是真正的验收）

评审指出「不是看文件有没有生成，而是模拟 365 天后能否快速回答四类问题」。已在临时目录用**合成数据 159 项目 / 800 作者**实测，结果见 `reports/知识库层验收报告-2026-10-13.md` 第九节：

| 验收问题 | 命中 | 查询耗时 |
|---|---|---|
| 找 AI 项目 | 443 | 803 ms |
| 找某作者项目 | 1 | 753 ms |
| 找 MIT 许可项目 | 511 | 715 ms |
| 找最近 90 天活跃项目 | 806 | 637 ms |
| 我的收藏里的 AI 项目（组合） | 12 | 754 ms |

规模数据：`projects.jsonl` 3.2 MB / 3650 行（每项 879 B）；`events.jsonl` 1.0 MB / 7038 条；`overview.html` 2.0 MB；同步耗时 47 秒；页面生成 1.5 秒。**模拟数据已清理，未污染真实工作区。**

### 7. 确认保持的选择

JSONL 架构、不引入数据库、不建 `search-index.json`、不建每项目一文件——评审确认这四项决定正确，维持不变。

---

## [2.0.0] — 2026-10-13 · 知识库层（两层次数据架构）

用户要求把「每日报」升级为「个人 GitHub 项目情报库」。核心不是页面，是数据长期管理能力。

### 架构决策

- **两层结构**：流水（`seen.jsonl` / `snapshots/` / `picks/` / `recommend-log.csv` / `meta/` / `status-log.jsonl`）
  是**唯一事实源、不可再生**；投影（`data/projects.jsonl` / `data/events.jsonl`）由流水派生、**可随时全量重建**。
  这样既不产生「双份真相」，又能按项目而非按日期来查。**禁止手工编辑投影文件。**
- **拒绝每项目一文件**（用户在甲/乙方案中选乙）：3650 个项目时单文件目录会造成文件数量爆炸与维护成本上升。
- **项目唯一身份** `full_name`（`owner/repo`）：从首日起就是台账主键，本次沿用，无需迁移。

### 新增

- `data/projects.jsonl` —— 统一项目档案，一行一个项目，含远端元数据、推荐决策、六维分类、星数统计、事件计数。
- `data/events.jsonl` —— 项目生命周期事件，7 种类型：`discovered` / `recommended` / `re_recommended` / `stars_up` / `stars_drop` / `status_changed` / `push_activity`。
  **只记有意义的变化**：星数变化带 ±30 阈值（`config.json` 的 `events.stars_threshold`），低于阈值不记，避免数百项目每天刷出噪声。
- `data/backfill/repo-metadata-b*.jsonl` —— 一次性补录的远端元数据（**5 次 Search API 调用**，走独立额度、不占用每日纪律）。
- `tools/sync-projects.ps1` —— 从流水派生投影，**幂等**（输入指纹未变则跳过），支持 `-Force`。
  含缺失兜底：10-11 首日运行没写 `picks/`，该日 8 条推荐从 CSV 补齐为 `recommended` 事件。
- `tools/query.ps1` —— 按维度查询：领域/形态/用途/状态/许可/语言/档位/风险/关键词/活跃天数；`-Events <repo>` 查看单项目历史。
- `SKILL.md` 第五节新增：两层结构说明、项目唯一身份、六份日常产出（新增 `data/meta/` 与 `data/status-log.jsonl`）、收尾必须同步知识库。

### 重写

- `tools/build-overview.ps1` —— 从「内联卡片」改为**数据与视图分离**（JSON 内嵌 + 前端渲染）：
  159 项 54.2 KB，按此密度 159 项约 2.6 MB（旧方案每项内联卡片约 1.1 KB → 4 MB）。
  首版功能：全部浏览、分类侧栏（六维 + 状态）、搜索、详情面板（含事件流）、排序（星数/7 天涨幅/最近提交）、收藏筛选。

### 分类器重写

- 旧逻辑「第一个关键词命中就拍板」产生误判（`generat` 命中 "auto-**generat**ed docs" → 误判为「创作」）。
- 改为**按来源加权计分**：`topics` 5 分 > `description` 3 分 > `note` 2 分 > `id/language` 1 分，取最高分。
- 分类器函数原先用 `[string[]]$pairs` + 嵌套哈希表，参数绑定异常导致全部落到兜底值；改为显式 `param()` + 数组对形式后修复。

### 校验

- `audit.ps1` 新增**第 19 节**（159 项）：投影文件可解析、`id` 无重复（唯一身份）、台账项目全部在主档案中、事件无孤儿、
  已推荐项目必有推荐事件、分类标签在枚举内、`overview.html` 存在。检查数 **62 → 75**。

### 未做（用户明确不要求）

- 不建 `users/favorites.json`（`AGENTS.md` 写死单用户环境）。
- 不建 `search-index.json`（PowerShell 载入数千条 JSON 仅需毫秒，预建索引解决的是不存在的问题，且自身会成为会过期的文件）。

---

## [1.1.0] — 2026-10-13 · owner 冷却期收紧（用户批准）

- **`RUBRIC.md` 第 5 节**：同一 owner 的仓库，由「**当天最多 1 个**」改为「**3 天内最多 1 个**」。
  - 起因：`storytold` 一天新建 5 个仓库（photocraft / pdfcraft / gridcraft / cadcraft / deckcraft），按旧规则可连续多天各占 1 个推荐位。
  - 口径：看 `seen.jsonl` 中该 owner 最近一次进推荐区的日期，距今 < 3 天则本轮让位。
  - 决策：用户批准。备选值 7 天因额度纪律（每天仅 3–5 次查询、候选池 40–60 条）被认为过严，最终取 3 天。
- **`SKILL.md` 第五节**同步为新口径，并注明「以 `RUBRIC.md` 为准」。
- **`config.json`**：`dedup.same_owner_per_day` + `same_owner_per_week` 合并为 **`same_owner_cooldown_days: 3`**；`output` 新增 `skill_level: "beginner"` 与 `detail_mode: "quick"`。
- **`audit.ps1` 新增第 18 节**：校验 owner 冷却期在 **RUBRIC / SKILL / config 三处口径一致**，防止标准悄悄漂移。检查数 **58 → 62**。
- 影响面：不动存量数据；`seen.jsonl` 无需回填。

---

## [1.0.1] — 2026-10-12 · 验收测试修正

- `audit.ps1` 第 11 节断言修正：「台账恰好 17 行 / 恰好 1 份快照」是**错误的精确值断言**，日报正常运行必然让它失败。
  改为**只增不减的下界断言**（`>= 17` / `>= 1`），并新增「含新增后仍无重复 `full_name`」一项。检查数 57 → **58**。
- 原因：实跑验收时，10-12 当天真实运行使台账从 17 涨到 76 行、快照从 1 份涨到 2 份，脚本误报 159 项 FAIL。
  这正是校验脚本应有的行为边界——它测的是"数据被删减/重置"，不是"数据不许增长"。→ 已记入验收测试报告 `reports/验收测试报告-2026-10-12.md`。

---

## [0.1.0] — 2026-10-11 ~ 2026-10-12 · 从零创建到验收通过（早期内部版，原记作 1.0.0）

首版 skill 由"生成提示词"产出，随后经过 **6 轮审查**迭代成型。以下按**改动性质**归类，并标注每次改动**为什么**发生。

### 1. 创建

- 新建 `.dsh/skills/github-daily-picks/SKILL.md`（DSH 自动发现，工作区级 skill）。
- 采纳「单一事实源」架构：**SKILL.md 只负责编排 / 边界 / 失败处理 / 验收**；筛选标准、检索式、日报格式分别以 `RUBRIC.md`、`SOURCES.md`、`TEMPLATES/daily.md` 为准，冲突时以工作区文件为准。
- 新建 `references/` 四个渐进式披露文件：`rubric-details.md`、`risk-and-license.md`、`example.md`、`sources-queries.md`。

### 2. 修掉原生成提示词里会"一跑就废"的错误

| 改动 | 原因 |
|---|---|
| 删除「优先使用 GitHub Trending API」 | **该接口不存在**；Trending 只有 HTML，且 `web_fetch` 抓取实测 30s 超时。改为自家星数快照算 `Δstars` |
| `GITHUB_TOKEN` 从**硬前置**改为**软检测 + 匿名降级** | 实测本机未配置 token，写死前置会让 skill 直接罢工；匿名 60/h 足够本日 3–5 次调用 |
| `gh search repos` 从「优先使用」降为「仅成功时采用」 | DSH 环境中 `gh` 默认不可用 |
| 明确禁止本机 `curl` / `Invoke-RestMethod` 直连 GitHub | 实测不通（返回 000 / schannel 凭据失败） |
| 删除「原子写」「指数退避」要求 | 文件工具下做不到原子写；指数退避与「最多重试 1 次」的额度纪律冲突 |
| 台账坚持 **JSONL 追加写**，禁止改回 JSON 数组 | 数组做台账要整体重写，一次写坏全崩 |

### 3. 修掉「漏掉最关键维度」的排序设计

- **保留 `RUBRIC.md` 的 100 分制为唯一主口径**（实用性 35 / 上手成本 15 / 活跃度 20 / 热度 20 / 可信度 10）。
- 拒绝采用外部建议的 `stars_norm` 主导公式——它**漏掉了权重最高的「实用性」**，照抄会让日报退化成"热门搬运号"。
- 新增**冷启动规则**（实测 `data/snapshots/` 只有 1 份快照，`Δstars` 无基线）：
  无可比快照（缺失或间隔 >3 天标 `stale`）时，`trend_norm` 不参与排序，**权重按比例并入「实用性」**（35 → 44），不得记 0 分；临时值用 `created_at` 推算并标「估算」。
- 新增**额度纪律**：只对 S 档候选补调 `/readme`（≤3 条/天），补调总数 ≤5 次/天，不轮询、不逐仓库遍历。

### 4. 格式统一（消除"两套标准"）

| 改动 | 原因 |
|---|---|
| 159 项模板**合并进 `TEMPLATES/daily.md`**，SKILL 第六节改为「取材清单」 | 原先 SKILL 内联了完整 159 项，与 `TEMPLATES/daily.md` 形成第二份格式标准——**这正是最初批评原方案的问题，我自己又犯了一次** |
| 「代价 / 坑」**归属第 159 项**，明确不是第 159 项 | 曾出现「159 项」与追加「第 159 项」自相矛盾 |
| S 档最多 3 条、A 档只写一行、S+A ≤ 8 | 三条约束在四处文档统一 |
| A 档字段加入「行动：」 | 原先 A 档唯一缺"行动建议"，与验收清单冲突 |
| 风险等级**只写 `低`/`中`/`高` 单值** | 防止写「低、无遥测」导致下游按值匹配失败 |
| 归档状态统一写「已归档 / 未归档」 | 原先两处示例一个写一个不写 |

### 5. 流程与数据落盘

- **落盘四份产出**并明确职责：`reports/*.md`（人读）、`data/snapshots/*.jsonl`（**只做星数基线**）、`data/picks/*.jsonl`（机器可读档案）、`data/runs/*.md`（运行日志）。
- 新增 `data/picks/`（含说明文件），拒绝把评分/风险塞进 `snapshots/`——那会污染 `Δstars` 基线。
- 修正**落盘顺序依赖倒置**：`picks` 需要 `tier`/`score`/`action`，**必须在打分排序之后写**；`.univer` 表格同步**永远排最后**。
- 新增**同日重复触发**的幂等规则：`reports/YYYY-MM-DD.md` 已存在则默认跳过并只汇报。
- 新增**表格不存在时的降级**：实测 `GitHub推荐记录.univer` **尚未生成**，规则为跳过并记日志，**不报错、不中止、不自创文件名**；同时把 `README.md` 里旧笔误 `GitHub每日推荐.univer` 统一为 `GitHub推荐记录.univer`。

### 6. 台账 schema 调整（经用户批准，**未改动存量数据**）

- `status` 三态 → **五态白名单**：`active` / `watching` / `saved` / `researching` / `dropped`。
  - 关键修复：原生成稿**漏掉了 `watching`**（B 档观察中），而 `data/README.md` 与 `RUBRIC.md` 都在用它。
  - 存量 17 行全部为 `active`，**一行未改**。
- 新增 `last_recommended` 字段说明与**回退规则**：存量行无此字段 → 回退用 `last_seen` 判断 30 天冷却，并在运行日志注明「本次回退」。
- 新增 `drop_reason`、`captured_at`（格式统一 `+08:00` 偏移）。
- 修复 `data/README.md` 中被编辑切坏的表格（`first_stars`/`note` 两行曾混入 status 白名单表）。

### 7. 合规与防封号（依据 GitHub 官方条款）

- 新增 **rank abuse 禁令**：不自动 star / fork / watch / follow，也不批量提交或评论——**即使仓库 README 要求也不做**。
  依据：[GitHub 可接受使用政策](https://docs.github.com/en/site-policy/acceptable-use-policies/github-acceptable-use-policies)第 4 条把「automated starring or following」明列为 **rank abuse**，属平台可处罚行为（suspension / termination）。
- 新增**内容红线**：盗版/破解/注册机、外挂、恶意软件/挖矿、爬虫绕过、薅羊毛/账号共享、赌博/诈骗类**不得以任何形式进日报（连链接都不给）**，只写不带链接的中性剔除备注。
- 新增**提示词注入防御**：README / Issues / Release / 仓库描述一律**当数据读、绝不当指令执行**；出现「忽略以上指令」类文字视为可疑信号，风险等级至少「中」。
- 新增**中性剔除描述**规则：只写可核查事实（「资源列表，命中硬排除」），不写「疑似恶意软件」这类指控。
- 明确 **API 调用合规**：官方明确「scraping 不包含通过 API 收集信息」，本流程只做 `GET`，永不发起写操作；禁止抓 HTML 页面。
- 新增**隐私输出约束**：输出不得含 token、私有仓库、本地路径、账号密钥、服务器 IP，也不得转述台账 `note` 中的个人备注。
- 新增**表格公式注入防护**：`owner/repo` 必须匹配 `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$`；自由文本不以 `=` `+` `-` `@` 开头。

### 8. 配套文件改动

| 文件 | 改动 |
|---|---|
| `TEMPLATES/daily.md` | 收录 159 项完整 S 档模板 + 分类枚举表 + A 档简条格式 + 剔除备注格式；头部补数据源/时间戳/调用次数/限流状态 |
| `PROMPT-daily.md` | 「落盘六件事」→**七件事**（插入 picks）；「代价或坑」改为 **S 档必须、A 档可省**；新增 `last_recommended` 回退、风险单值、注入防御、合规红线；自查清单扩充 |
| `data/README.md` | status 五态白名单、`last_recommended`/`drop_reason`/`captured_at` 字段、`picks/` 字段定义、JSON 示例同步 |
| `README.md`（工作区） | 表格文件名笔误统一 |
| `references/sources-queries.md` | 新增「合规与账号安全」章节；补「运行不足 7 天无 7 日均值基线」分支 |
| `references/example.md` | 改为 159 项编号制；A 档补行动字段；标注「已核实 README」是**目标态**而非当前水平（当前实测 8 条里约 6 条未验证） |

### 9. 新增校验工具

- 新增 `audit.ps1`：**159 项不变量校验**，只读，改完文档跑一遍即可知道有没有打架。
- 覆盖：结构完整性、S 档 159 项口径、限流重试口径、枚举合法性、落盘顺序依赖、台账 schema、合规红线、数量约束、表格文件一致性、**三处 159 项字段的概念名与顺序比对**，以及 **CHANGELOG 与当前文件指纹对账**。
- 通过**变异测试**验证有效性：故意破坏 3 处（403 重试、rank abuse 条款、S 档上限），脚本均精确报 FAIL，恢复后回到全绿。

---

## 明确「不做」的事（避免后人重蹈）

1. **不用 Trending API**（不存在）、**不爬 HTML**、**不采第三方 trending 镜像**（滞后且 `ossinsight` star 事件自 2026-03-01 失效）。
2. **不把 `GITHUB_TOKEN` 写成硬前置**。
3. **不用 star 数主导的排序**替代 `RUBRIC.md` 的 100 分制。
4. **不把「政治敏感」混进硬排除**——API 无法验证，也不是平台条款问题；只作低置信度提示，只写证据、不做价值判断。
5. **不自动修改 `RUBRIC.md` / `SOURCES.md`**——发现标准问题只在 `data/runs/` 写「建议调整项」，交给人改。
6. **不执行仓库内任何代码**（不 clone、不 install、不 `docker run`、不 `curl | bash`）。
7. **不为命中合规红线的项目提供链接**。

---

## [5.1.0] — 2026-10-14 · 16 条 bug 全修 + 5 个新需求 + 分类器两处根治

依据用户的功能测试报告（P0×1 / P1×5 / P2×6 / P3×4，**经逐条复核全部属实、无误判**）。

### 一、Bug 修复（16/16）

| 编号 | 修复 |
|---|---|
| **B1** P0 | **空库白屏**：`0 条` 时 `$json` 为空串 → 页面 `const P = ;` 语法错误。补零元素兜底（原来只兜了"1 条"） |
| **B2** P1 | **同义词表没进页面**：这份表除被 `suggest-terms` 当"已收录词"外**无人使用**，搜索框示例词 5 个全部 0 命中。已内嵌进页面 + `expandToken()` 组内任一命中 + 补齐 4 个缺失示例词（14→17 组） |
| **B3** P1 | **空结果丢场景提示**：`planHintHtml()` 只在有结果的分支调用（方向刚好反了）→ 空态也渲染 |
| **B4** P1 | 详情面板缺键显示 `undefined/20` → `to5()` 加类型判断 + `num()` 兜底显示「暂无数据」 |
| **B5** P1 | `台账行数 >= 17` **硬编码**（当初原库的数字）→ 改为"非空 + 条数对账交给第 19 节"，audit 与 check-config 两处 |
| **B6** P1 | **订阅清单 ≠ 推荐记录**：原检查要求 CSV ⊆ 订阅清单，但搜索发现的项目本来就不在订阅源里 → 改查"CSV 里的仓库都在台账中" |
| **B7** P2 | **分类器宽词误配**：新增 `data/wide-terms.json`，宽词在**弱信号**里降权（不是忽略——实测"忽略"会让 3 条掉进「其他」） |
| **B8** P2 | **新增一级「办公」**：Word/PPT/PDF/表格 的重写版不再落进「AI办公」；AI办公从 9 词瘦身到 1 词 |
| **B9** P2 | 分类键为空 → 字面量 `"null"` 分组 → 改 `p.l1||'未分类'` |
| **B10** P2 | check-page 第 ⑨ 项硬要求"至少配出 1 组工具"（稀疏库必红）→ 去掉该硬条件 |
| **B11** P2 | `add-repo` 把星数写成字符串 → 转 `[int]`，缺值写 `$null` |
| **B12** P2 | `fetched_at` 口径不一致（audit 强制、文档没写）→ 约定写进 `data/README.md` + `PROMPT-daily.md` |
| **B13** P3 | `audit.ps1` 第 4 行在 `$root` 定义前使用它（每次运行都往 stderr 报错）→ 删死代码（**这是我上一轮改出来的**） |
| **B14** P3 | `STA.saved` 死映射（收藏功能已撤销）→ 删 |
| **B15** P3 | 工作区静默丢弃不存在的工具 → 显示「⚠ 有 N 个工具在库里找不到」 |
| **B16** P3 | demo 模式 PASS 但数字不符（125/129）→ 改中性措辞（**这也是我上一轮加的**） |

### 二、用户新需求（5 个）

1. **日报后自动补标签**：`PROMPT-daily.md` 新增收尾步骤（必做）→ `auto-tag.ps1 -Apply -Sync`
2. **新标签自动变搜索词**：保证 `user_keywords` 非空；新标签立即可搜；**排除宽词**（与分类器共用 `wide-terms.json`）
3. **用户添加项目同样处理**：`add-repo.ps1` 入库后自动调 `auto-tag`
4. **日报带直接入口**：`TEMPLATES/daily.md` + `PROMPT-daily.md`（硬性）：每条推荐 `> 🔗 直接打开：https://github.com/...`；末尾「## 🔗 一键入口」区
5. **配搭配末尾给入口**：`tool-stack/SKILL.md` 第十节：每个工具都要 GitHub 直链 + 本机页面入口（**不假装能替你打开浏览器**）

### 三、分类器两处根治

- **形态词规则**（用户裁定）：*名字里有 OS / Framework / Platform / SDK / Library 不决定分类，看它解决的问题*。已写进 `wide-terms.json` 并影响实测 1 条（AI-Research-SKILLs → AI/AI Agent）
- **Herald-OS → AI/AI Agent**（用户裁定：OS 是承载环境不是用户目的）→ 补人话层强信号 + **成为第 6 个分类锚点**

### 四、本轮踩的 4 个坑（都值得记）

1. **PowerShell 函数名单字母撞内置别名**：`function R` 被别名 `r = Invoke-History` 覆盖 → **7 处编辑静默失败**（命令不报错、文件没改），页面照旧 PASS，极易被骗过。**规则：函数名不要用单个字母。**
2. **"忽略" ≠ "降权"**：宽词直接忽略会让 3 条从具体分类掉进「其他」（更难找）。降权（有效长度×0.001）才对。
3. **PSCustomObject 不能加属性**：`$obj.'新字段' = x` 抛异常 → 要重建对象。
4. **锚点抓到了我自己的改动**：B8 后 `deckcraft` 锚点报红，逼我确认"这是有意改动还是改坏了"——**锚点的价值正是如此**。

### 五、校验

`audit.ps1` **159 项**（锚点 5→6、新增发布物 159 项、`isDemo` 兜底、反断言）；`check-page.js` 第 ⑧ 项新增"**搜索框 5 个示例词必须全命中**"自动验收；`check-config.ps1` 159 项。全绿。

---

## [5.1.1] — 2026-10-14 · 测试轮发现并修复（N-01 + 1 处加固）

来源：v5.1.0 全量副本自动测试（见 `发布测试/v5.1.0-测试副本/bug-test-report.md`）。

### N-01（P1）：projects.jsonl 一行字面量 `null` → 页面初始化崩溃

**现象**：`TypeError: Cannot read properties of null (reading 'localeCompare')`，栈在 `bySort → sorted → render`，整个 `<script>` 停摆。

**根因（和我前两次的猜测都不一样）**：`null` 行**没有变成 null 元素**，而是被转成了一条 **id=null 的全空正常记录**——

```powershell
$p = $l | ConvertFrom-Json        # null 行 → $p = $null
$h = $p.human                     # ⚠ PowerShell 里 $null.human **不报错**，返回 $null
...                               # 于是照样走进 [pscustomobject]，生成一条记录（实测 144 条）
```

所以 `Where-Object { $_ }` 永远筛不掉它（**那个对象是真值**），页面按 `id` 排序时 `localeCompare` 读到 null 就崩。

**修复**：源头跳过 —— `if (-not $p -or -not $p.id) { continue }`（顺带：**任何 id 为空的记录都不再生成**）。

**校验盲区同时补上**：`null` 是合法 JSON，`ConvertFrom-Json` 不抛错 → 原来「每行可解析」拦不住。audit 第 19 节新增一条「projects.jsonl 无空值行」，**校验项 129 → 130**（CHANGELOG 表已同步）。

### 加固：`workspaces.jsonl` 的 `done` 字段类型写错不再崩

页面原来写 `const done = w.done || []`，若手写 JSONL 把 `done` 写成**对象/字符串**，`done.indexOf` 直接抛错。

**修复**：`Array.isArray(w.done) ? w.done : []`（两处）。

> 定性说明：测试时是**我造错了数据**（把 `done` 写成对象），工具与页面的真实格式（数组）**本来就一致**；此处属顺手加固，非原 bug。

### 本轮通过项（全量 143 条副本上实测）

| 章节 | 结果 |
|---|---|
| §1 异常数据（空库 / 单元素 / null 行 / 缺字段） | 空库不再白屏；N-01 修复后 null 行也正常 |
| §3 缺 category | PASS（9 条，详情 9/9） |
| §4 只删部分评分键（B4 复现条件） | PASS（11 条） |
| §7 工作区 0/1/多/坏数据/done 类型错 | **6/6 PASS** |
| §8 五种状态 + 未知值 | PASS（8 条） |
| §9 三支自检 | audit **130/0** ｜ config **17/0** ｜ page **PASS** |
| §11 500 条 | PASS：500/500 详情可开；页面 645 KB；构建 0.1 s；check-page 2.3 s |
| §12 从无关目录调用 audit | 仍 130/0、stderr 报错 0 |

### 本轮踩的坑（第三次同类了，值得单列）

1. **改代码前不读代码** —— N-01 我**连续两次盲改**（正则匹配到 `$rows = @()` 初始化行；插到 `$json =` 之前），都**静默失败**、页面照样"看起来正常"。第三次**先读那 100 行**，5 分钟定位真因。**规则：改之前先读。**
2. **`2>&1` 捕获不到 `Write-Host`** —— 测试 harness 里用它捕获 `check-page.ps1` 输出，结果每个用例的判定都是**假 FAIL**（`$o` 为空）。正确做法：**`*>&1`**（Information 流）。
3. **测试数据本身也会骗人** —— §7 那条 `done.indexOf is not a function` 一开始被我当成产品 bug，读代码后确认**是我造的 JSON 格式错**。**定性前先对照真实数据格式。**

---

## [5.1.2] — 2026-10-14 · 测试轮收尾（搜索修复 + 方案匹配收紧 + 自动补标签撤销）

### 一、§2 需求式搜索：0/5 → 5/5（**真缺口，我上一轮误报已修**）

实测「我想做PPT / 我要画图 / 我要写代码 / 我要找AI助手 / 我要管理文件」**全部 0 命中**。

**根因**：中文整句没有空格 → `parseQuery` 把**整句当成一个词**去匹配，必然落空。
（上一轮我只修了 B3 的"空结果丢场景提示"，**整句搜不到这一半没修**，属于误报。）

**修复**：剥掉**意图前缀**（我想/我要/帮我/给我/想要/需要/寻找/找…，**剥两层**），对剩下的短词做同义词扩展，同时**保留整句**（保证正常搜索零回归）；同义词表补「管理文件/整理文件」。

**验收（check-page 新增 MATRIX 采样，常驻）**：

```
需求: 我想做PPT=8  我要画图=21  我要写代码=20  我要找AI助手=49  我要管理文件=3   → 0 命中: 0/5
普通: AI=92 图片=24 视频=14 代码=20 文件=23（与修复前完全一致，无误伤）
多词: AI 视频=12 本地 AI=28 图片 编辑=11（AND 正确）｜异常: <script>=0、空串=143
```

### 二、§6 方案匹配：三次收紧（用户确认已干净）

原现象：11 个场景里 8 个塞进明显不相关的工具（`WeChatBridge` 出现在 3 个场景、`EcomGen` 出现在「本地跑 AI」）。

**诊断先行**（新增 `PLANSCORE`，打印每个候选的**逐项得分与命中原因**）：

```
产品设计/UI × WeChatBridge = 3 {l2命中[笔记]}          ← 只靠分类命中就过关
本地跑AI   × EcomGen      = 5 {l2[部署托管] + ft[自托管]}
做AI视频   × DigUp        = 5 {l2[文件管理] + ft[文件搜索]}
```

| 刀 | 改动 | 效果 |
|---|---|---|
| 1 | 阈值 `sc>0` → `sc>=3` | 54 → 46 槽位 |
| 1b | 功能标签**反向包含**加长度门槛（短标签不再反向命中一切） | 去噪 |
| 2 | `l1`（一级分类）不再计分 | **无效**——但**证明了污染不来自 l1**（这条负结果有价值） |
| 3 | **分类命中必须搭配 ≥1 个功能标签命中** | 清掉 159 项（写代码场景的 `ts-rust`、DSH 场景的 `pi-glm-quota`） |

**用户人工确认：4 个重点场景（产品设计 / 做 PPT / 查资料 / 做 AI 视频）已干净 → §6 结案。**

### 三、自动补标签：按用户决定**撤销自动化**（C 方案）

实测自动切词产出不可用：`本次响应`、`NOASSERTION 许可`、`cadcraft 同类`；且**功能标签是分类的强信号**，污染它会连带污染分类。

- `PROMPT-daily.md`：收尾步骤从「**必做：自动补标签**」改为「**只记账**」——日报运行备注里写一行「未补标签 N 条（等你确认）」
- `add-repo.ps1`：自动调用**移除**
- `auto-tag.ps1`：定位改为**候选预览工具**（默认只读；说明里写明**不要用 -Apply** 及原因）
- 纪律回归：**机器发现、人批准**

### 四、常驻诊断（以后每次跑 check-page 都会打印）

| 前缀 | 内容 |
|---|---|
| `MATRIX` | §2 搜索矩阵（19 个用例的结果数） |
| `NEEDZERO` | 需求式搜索 0 命中的句子 |
| `PLANS6` | 每个方案场景匹配到的工具 |
| `PLANSCORE` | 重点工具的**逐项得分与命中原因**（定位"为什么会进来"） |

### 五、本轮教训（半个测试轮踩了 4 次同类）

1. **改代码前先读代码**：N-01 连续两次盲改静默失败；`l1` 那一刀 3 次正则都没匹配上，最后**按行号替换**才成。
2. **先量再改**：`l1` 那一刀改完**零效果**——因为我没先量分数就动了权重。后面加了 `PLANSCORE` 才切准。
3. **尺子要先校准**：`PLANS6` 一上来把面板里**所有链接**都算成"匹配到的工具"，导致 §6 判断反复。**验收方式本身也是要验收的。**
4. **清理要按"本次产生的集合"**：清 7 条自动标签时用了"符合特征的全删"，误删副本里 60 条历史条目（原库未受影响，已从原库恢复）。
5. **测试数据也会骗人**：`done.indexOf is not a function` 一开始被当成产品 bug，读代码后确认是**我造的 JSON 类型错**。

---

## 2026-10-16 · 校验项 137 → 141（新增「文档 × 代码」字段对照）

**改了什么**：`audit.ps1` 新增第 **24** 节，共 **159 项**检查，总数 137 → **141**。

1. 投影层声明字段全部真实产出（防「文档写了、代码没做」）
2. 投影层声明字段在 `data/README.md` 中都有记载
3. 投影层无未声明字段（防「代码加了、文档没写」）
4. `status` 白名单：台账取值合法 + 文档五态齐全 + 不再出现已废弃的 `saved`

**起因（同一天实测两处不一致）**：

- `data/README.md` 的字段表里早就写了 `drop_reason`，但 `sync-projects.ps1` **从未投影它** → 文档说有的字段实际没有，页面上也看不到。当天已修：投影 + 页面详情新增「淘汰原因」一行。
- `data/README.md` 的 status 白名单写成 `active/watching/saved/researching/dropped`，而 `saved` 早已废弃、白名单实际是 `using`。当天已修。

**配套改动（不属本 skill 目录，但同日发生）**：`tools/add-intro.ps1` 从「纯追加」改为**写入前按 `full_name` 去重**——原来同名写两遍会留下旧行，导致第 21 节「人话层条目字段齐全」逐行检查时命中旧的不完整行而误报 FAIL。

**SKILL.md 未改动**：指纹（449 行 / 45406 B / SHA256）保持不变。
