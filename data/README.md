# 数据字典

## seen.jsonl — 去重台账（主键 `full_name`）

一行一个 JSON 对象：

```json
{"full_name":"owner/repo","url":"https://github.com/owner/repo","first_seen":"2026-10-11","last_seen":"2026-10-12","recommended":true,"recommend_count":1,"last_recommended":"2026-10-12","status":"active","language":"Rust","first_stars":4359,"last_stars":5100,"note":"Word 的 Rust 重写，S 档"}
```

> **存量 17 行没有 `last_recommended` 与 `drop_reason`**，这是预期状态：读不到 `last_recommended` 时回退用 `last_seen` 判断 30 天冷却，并在运行日志注明「本次回退」。**不要为补齐字段改写存量行。**

| 字段 | 含义 |
|---|---|
| `first_seen` / `last_seen` | 首次收录 / 最近出现日期 |
| `recommended` | 是否进过日报推荐区（决定 30 天冷却） |
| `recommend_count` | 被推荐次数 |
| `status` | 状态白名单（**生命周期**，见下表） |
| `last_recommended` | 最近一次进日报推荐区的日期，30 天冷却的唯一依据；**存量行没有此字段**，读不到时回退用 `last_seen` 并在运行日志注明回退 |
| `drop_reason` | 淘汰原因（仅 `status: dropped` 时写） |
| `first_stars` / `last_stars` | 首次与最近记录的星数，用于快速算增速 |
| `note` | 一句话判断，供下次快速回忆 |

`status` 取值白名单（不得自由发挥新值；**存量 17 行只有 `active`，不作改写**）：

| 值 | 含义 | 引入时间 |
|---|---|---|
| `active` | 已收录、未处置 | 首日即有 |
| `using` | **我正在使用**（唯一需要跨会话记住的个人状态，GPT 评审 2026-10-13 拍板只加这一个） | 2026-10-13 新增 |
| `watching` | B 档观察中（对应 `RUBRIC.md` 第 3 节 B 档）｜也用于「我关注它的发展」 | 首日即有 |
| `saved` | **遗留值：不要再写**。曾用于「用户收藏」，2026-10-13 当天先迁到 `data/user-library.jsonl`、**同日晚间整个收藏功能被撤销（用户决定：太麻烦繁琐）**，该文件与 `tools/favorite.ps1` 均已删除 | 2026-10-11 引入，2026-10-13 废弃 |
| `researching` | 用户研究中 | 2026-10-11 起新增，可选 |
| `dropped` | 已放弃，90 天冷却（**软删除**；个人知识库最怕误删，不提供物理删除） | 首日即有 |

> **不要再加"收藏 / 喜欢 / 待测试 / 想用 / 关注"这类标记**（GPT 评审原话：*这些都会重新变垃圾*）。个人状态只用上表这一个 `using`。

> 2026-10-13 迁移记录：原 `status: saved` 的 18 条已改为 `watching`（当时同步写过 `user-library.jsonl`，随后该功能整体撤销、文件删除）。改动记在 `data/status-log.jsonl`。
> **注意**：日报「行动建议」字段里的 `收藏` 取值（`试玩 / 收藏 / 研究 / 放弃`）仍然有效，那是**日报对项目的建议**，与被撤销的"我的收藏"功能无关。

## snapshots/YYYY-MM-DD.jsonl — 每日星数快照

```json
{"full_name":"owner/repo","stars":4359,"forks":1335,"created_at":"2026-10-07T08:34:24Z","pushed_at":"2026-10-11T06:03:11Z","captured_at":"2026-10-11T09:03:00+08:00"}
```

用途：**只做一件事**——算 Δstars/天。间隔 > 3 天的旧快照标记 `stale`，不参与排序。

**不要把评分、风险等级、淘汰原因写进快照**，那会让这个文件变成大杂烩，污染增速基线；这些内容放 `picks/`（见下）。

`captured_at` 格式统一为带 **`+08:00` 偏移**的 ISO 8601（如 `2026-10-11T09:03:00+08:00`）。存量行没有该字段 → 用**文件日期补齐**即可，不作为硬校验。

## picks/YYYY-MM-DD.jsonl — 机器可读的推荐档案

与 `reports/YYYY-MM-DD.md` 同源的机器可读版，一行一个条目（推荐与淘汰都记）：

```json
{"date":"2026-10-12","full_name":"owner/repo","tier":"S","score":86,"risk":"低","source":"Q1","action":"saved","captured_at":"2026-10-12T09:03:00+08:00"}
```

| 字段 | 含义 |
|---|---|
| `date` | 归属日期，与文件名一致 |
| `full_name` | 主键，与 `seen.jsonl` 对齐 |
| `tier` | `S` / `A`（推荐档位）；淘汰项写 `dropped` |
| `score` | 按 `RUBRIC.md` 的 100 分制得分 |
| `risk` | `低` / `中` / `高` |
| `source` | 来自哪个检索式（`Q1`–`Q5`、`Q3b`、`老朋友`、`方向匹配`） |
| `action` | 行动建议：`试玩` / `收藏` / `研究` / `放弃`（对应用户侧的 `saved` / `researching` / `dropped`） |
| `captured_at` | 采集时刻（带时区） |
| `drop_reason` | 仅淘汰项写，与 `seen.jsonl` 一致 |

用途：画趋势图、统计方向分布、核对"某天为什么没推荐某仓库"。**它是派生产物，丢了不影响日报**；`seen.jsonl` 与 `snapshots/` 才是不可再生的原始数据。

## runs/YYYY-MM-DD.md — 运行日志

每次运行一条，必须写：执行的查询、成功/失败、实际 API 调用次数、候选数、异常与建议调整项。

**判断任务是否健康的最快方式**：看最近 7 天 `runs/` 里有几天是成功的。

---

# 知识库层（v2，2026-10-13 起）

> **数据流：原始来源 → 投影 → 视图。**
>
> ```
> 原始来源（外部事实 + 用户操作，不可再生）
>   seen.jsonl · snapshots/ · picks/ · recommend-log.csv · meta/ · status-log.jsonl
>       │
>       │  tools/sync-projects.ps1（幂等，可反复全量重建）
>       ▼
> 投影（当前状态视图，可重建，**禁止手工编辑**）
>   projects.jsonl（当前状态投影） · events.jsonl（生命周期事件）
>       │
>       │  tools/build-overview.ps1
>       ▼
> 视图
>   overview.html
> ```
>
> **不要把某一个文件称为「唯一事实源」。** 事实由多个来源共同构成：GitHub API 的返回值、以及用户的操作。
> `projects.jsonl` 只是这些来源的**当前状态投影**。要改内容就改原始来源，然后重建投影。

## projects.jsonl — 统一项目档案（派生视图）

一行一个项目，**主键 `full_name`**。同一个仓库永远只有一条记录。

```json
{"id":"repowise-dev/repowise","url":"https://github.com/repowise-dev/repowise","owner":"repowise-dev","name":"repowise","description":"...","description_source":"api","license":"AGPL-3.0","topics":["mcp"],"archived":false,"pushed_at":"2026-10-11T00:00:00Z","language":"Python","first_seen":"2026-10-12","last_seen":"2026-10-12","recommended":true,"recommend_count":1,"last_recommended":"2026-10-12","tier":"S","score":80,"risk":"中","source":"Q5","action":"试玩","status":"active","tags":{"领域":"开发","形态":"CLI","用途":"提效","成熟度":"活跃","上手难度":"要编程","风险等级":"中"},"tags_confidence":"inferred","stars":{"current":7504,"first":7504,"delta_total":0,"delta_7d":0,"last_snapshot":"2026-10-12","snapshots":1},"events_count":3,"note":"...","updated_at":"2026-10-13T00:40:00+08:00"}
```

| 字段 | 含义 |
|---|---|
| `id` / `url` / `owner` / `name` | 身份。`id` 即 `full_name`，是唯一标识与去重依据 |
| `description` / `license` / `topics` / `archived` / `pushed_at` | **GitHub 远端元数据**。可能缺失，用 `description_source` 标明：`api`=来自 API，`missing`=**历史数据缺失** |
| `first_seen` / `last_seen` | 首次收录 / 最近一次出现在候选里的日期 |
| `recommended` / `recommend_count` / `last_recommended` | 推荐记录（冷却期依据） |
| `tier` / `score` / `risk` / `source` / `action` | 最近一次推荐决策。未进过推荐区则为 `null` |
| `status` | 五态白名单同台账：`active`/`watching`/`saved`/`researching`/`dropped` |
| `tags` | 六维分类（与 `TEMPLATES/daily.md` 同枚举）。**自动推断**，见 `tags_confidence` |
| `tags_confidence` | `inferred`（按关键词推断）/ `api`（依据 API 字段）/ `unknown`（信息不足） |
| `stars` | `current` / `first` / `delta_total` / `delta_7d` / `last_snapshot` / `snapshots`(快照次数) / **`github`**（API 实测值） / **`github_at`**（实测时刻）。快照值可审计、用于算增速；实测值更新但不可审计，**两者分别标注，不混为一谈** |
| `events_count` | 该项目在 `events.jsonl` 中的事件条数 |
| `note` | 一句话判断。**派生自台账，不要在此手工编辑** |

**纪律**：本文件由 `tools/sync-projects.ps1` **全量重建**，**禁止手工编辑**。要改内容，改流水或改脚本；手工改会在下次同步时被覆盖。

## events.jsonl — 项目生命周期事件（派生视图）

一行一个事件，**只记有意义的变化**，不记每天的例行扫描。按 `date` 升序。

```json
{"id":"repowise-dev/repowise","full_name":"repowise-dev/repowise","date":"2026-10-12","type":"recommended","detail":"S 档 · 80 分 · 行动：试玩","src":"picks"}
```

| `type` | 触发条件 | `detail` 示例 |
|---|---|---|
| `discovered` | 首次出现在候选里 | `首次收录，来源 Q1` |
| `recommended` | 首次进推荐区 | `S 档 · 80 分 · 行动：试玩` |
| `re_recommended` | 第 2 次及以后进推荐区 | `第 2 次推荐，A 档 · 71 分` |
| `stars_up` | 与上一份快照相比**涨幅 ≥ 阈值**（默认 +30） | `+120 星（间隔 1 天）` |
| `stars_drop` | 相比上一份快照**减少 ≥ 阈值** | `−45 星` |
| `status_changed` | `status` 发生变化（来源 `status-log.jsonl`） | `active → saved` |
| `push_activity` | 超过 90 天无提交 | `已 95 天无提交` |
| `metadata_updated` | `description` 或 `topics` 变化（来源 `meta/`） | `描述 + topics(15 个) 有更新` |
| `license_changed` | License 变化（来源 `meta/`） | `AGPL-3.0 → MIT` |
| `archived_changed` | 归档状态变化（来源 `meta/`） | `已归档` / `解除归档` |
| `category_changed` | 自动分类的领域/形态/用途发生变化（来源 `meta/`） | `领域 其他→AI` |
| `release_detected` | `pushed_at` 前移**且**距上次记 release ≥ 14 天 | `有显著更新（pushed_at 2026-10-12）` |

**关于后 5 种事件的前提**：它们都靠**回放 `data/meta/` 历史**得出，因此**元数据层必须按天追加、不能覆盖**。只有一份"当前快照"是算不出任何变化的。

`release_detected` 是**近似信号**：Search API 不直接返回 release，脚本用 `pushed_at` 前移 + 14 天间隔来近似"有显著更新"，**不是精确的 release 记录**，日报中不得当作 Release 事实引用。

**阈值与噪声控制**：星数变化默认阈值 **+30**，低于阈值不记事件——否则数千个项目每天都会产生事件，`events.jsonl` 会退化成噪声。阈值定义在 `config.json` 的 `events.stars_threshold`。

**纪律**：同样由 `tools/sync-projects.ps1` 全量重建，**禁止手工编辑**。

## 重建与查询

```powershell
# 全量重建 projects.jsonl 与 events.jsonl（幂等，可反复跑）
& ".\tools\sync-projects.ps1"

# 按条件查询（分类 / 状态 / 关键词 / 活跃度 / License / 收藏）
& ".\tools\query.ps1" -Tag "AI" -Status saved -Text "agent"

# 重建总览页
& ".\tools\build-overview.ps1"
```

## 补历史数据的说明

2026-10-13 之前收录的项目，`description` / `license` / `topics` / `archived` / `pushed_at` **未落盘**（当时只存了需要的字段）。
处理方式：**只对曾进入推荐区的项目做一次性补录**（补录来源记录在 `data/backfill/`），其余标记 `description_source: "missing"`，**不伪造**。

---

# 人话层（v3，2026-10-13 起）

> **为什么要单独一层**：`description` 是**给机器看的**（作者写的英文技术摘要），
> 普通用户打开知识库想知道的是：**"这是什么？能帮我干什么？我什么时候该用它？"**
> 这两件事不是一回事，所以人话层单独维护、单独补全。

## 三个数据文件

| 文件 | 作用 | 谁写 |
|---|---|---|
| `data/human/repo-intro.jsonl` | 项目介绍：一句话 / 痛点 / 使用场景 / 功能备注 | 人工或 Agent 撰写，**不在日常流程里自动改** |
| `data/human/function-tags.jsonl` | 功能标签与用户搜索词（含同义词） | 同上 |
| `data/human/search-synonyms.jsonl` | 全局同义词表（如「画图=绘画=文生图」） | 同上 |

**它们的优先级高于自动推断**：`sync-projects.ps1` 读取后合并进 `projects.jsonl`，人话层缺的字段留空并标 `human_status`。

## 人话层字段（`repo-intro.jsonl`）

```json
{"full_name":"jd-opensource/JoyAI-Image","one_liner":"这是一个能在自己电脑上跑的多模态 AI 图像模型，可以帮你把文字变成图片、按指令改图，也能看懂图片内容。","problem":"以前想在本地做文生图和改图，得分别装好几种模型互相接；现在一个模型就能覆盖理解、生成、编辑三件事。","example":"比如你有一张产品照，想把背景换成纯白并微调光线，输入一句\"把背景改成纯白，光线柔和一点\"就能得到新图，不用重新拍。","feature_note":{"是什么":"一个开源的统一多模态图像基础模型（8B 视觉语言模型 + 16B 图像生成模型）。","核心功能":["文生图","按指令改图","图片理解（看图问答）"],"常见用途":["本地生成配图","商品图后期","研究多模态模型"],"使用案例":["给文章配插图","把草图变成成图","按自然语言指令改照片"],"不适合":["没有独立显卡的机器（需 CUDA GPU）","只想要点开就用的在线工具的人"]},"source":"api+人工撰写","written_at":"2026-10-13"}
```

| 字段 | 说明 |
|---|---|
| `one_liner` | **格式固定**：「这是一个给____使用的____，可以帮你____。」必须用普通人能懂的话，不用英文术语 |
| `problem` | 「以前 → 现在」两段式：以前用户遇到什么麻烦，这个工具怎么解决 |
| `example` | **必须给真实使用场景**，要具体到"你有一张产品照"这种程度，不能写"可以用于图像处理" |
| `feature_note` | 六项：`是什么` / `核心功能`(≤3) / `常见用途` / `使用案例` / `不适合`。**这是软件介绍页，不是 README 摘要** |
| `source` | `api+人工撰写`（有 API 描述支撑）／`仅台账备注`（素材不足）／`待补` |
| `written_at` | 撰写日期 |

**诚实纪律**：
- `source` 标 `仅台账备注` 的条目，**只写得出 `one_liner`**，其余字段留空并在页面显示「待补全」。
- **不得凭项目名猜测功能**。素材不足就是素材不足，标「待补」，不编。

## 功能标签与用户搜索词（`function-tags.jsonl`）

```json
{"full_name":"jd-opensource/JoyAI-Image","function_tags":["AI绘画","图片生成","文生图","图像编辑","设计辅助"],"user_keywords":["画图","绘画","图片生成","AI画图","做图","生成图片","改图","抠图","设计"],"synonyms":["文生图","text-to-image","AI画画","作图"]}
```

| 字段 | 说明 |
|---|---|
| `function_tags` | **功能标签**：这个工具属于哪类功能（面向分类浏览） |
| `user_keywords` | **用户可能搜的词**：普通用户会怎么描述这个需求（含口语） |
| `synonyms` | **同义词**：与上面互通的写法（中英、简繁、口语） |

**为什么需要**：普通用户**不知道项目名**。想找 AI 绘图工具时，他会搜「画图」「绘画」「头像」，不会搜 `stable diffusion`。
所以搜索必须同时匹配这些字段，而不只是项目名和英文描述。

## 全局同义词表（`search-synonyms.jsonl`）

```json
{"group":"图像生成","terms":["画图","绘画","作图","图片生成","文生图","AI画图","AI画画","text-to-image","t2i","image generation","绘图","出图"]}
```

搜索时先查这张表：用户搜「画图」，会自动扩展成整组词再匹配。**这张表是模糊搜索的关键**。

## 搜索匹配范围（全部字段）

`projects.jsonl` 里以下字段**全部参与搜索**：
`id` · `description` · `topics` · `tags`（六维分类）· `function_tags` · `user_keywords` · `synonyms` · `one_liner` · `problem` · `example` · `feature_note` 全部文本 · `note`

## 在 `projects.jsonl` 中的呈现

```json
"human": {
  "status": "complete|partial|missing",
  "one_liner": "...", "problem": "...", "example": "...",
  "feature_note": { "是什么":"...", "核心功能":[...], "常见用途":[...], "使用案例":[...], "不适合":[...] }
},
"function_tags": ["AI绘画","图片生成"],
"user_keywords": ["画图","绘画","AI画图"],
"synonyms": ["文生图","text-to-image"]
```

`human.status` 三态：
- `complete` —— 人话层齐全（有 API 描述 + 人工撰写）
- `partial` —— 只有 `one_liner`（素材仅够一句话）
- `missing` —— 完全无素材，页面显示「待补全」

## 覆盖现状（2026-10-13）

| 状态 | 数量 | 说明 |
|---|---|---|
| `complete` | 20 | 曾进推荐区、已补录 API 描述的项目 |
| `partial` | 56 | 仅台账一句备注，只写得出 `one_liner` |

**不要为了凑满 `complete` 而编造**。人话层可以慢慢补——每天新收录的项目会天然带 API 描述，增量会逐步补齐。

## meta/YYYY-MM-DD.jsonl 的 `fetched_at` 约定

**每一行都必须带 `fetched_at`**（该行数据是什么时候抓的）——事件回放排序依赖它。

```json
{"date":"2026-10-13","full_name":"owner/repo","stars":123,"fetched_at":"2026-10-13T09:03:00+08:00"}
```

- 日报流程写 meta 时**必须写**；`tools/add-repo.ps1` 已经会写。
- 存量行若缺该字段：**用文件日期补齐**即可，不作硬校验（与 `captured_at` 同一口径）。
- `audit.ps1` 第 20 节会检查这一点；**跑完日报若报红，就是这一步漏了**。
