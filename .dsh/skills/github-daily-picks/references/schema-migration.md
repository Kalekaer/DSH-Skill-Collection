# 已执行：`seen.jsonl` / `snapshots` schema 调整

> 状态：**已批准并执行**（2026-10-11）。
> 决策来源：用户确认「A 改 / B 仅新行 / D 新建 `data/picks/`」。
> 执行结果：只改了说明书 `data/README.md`，**未改动任何存量数据**。

## A. `status` 五态 —— ✅ 已执行

- `data/README.md` 的 status 说明已从三态扩为五态白名单：`active` / `watching` / `saved` / `researching` / `dropped`。
- **存量 17 行（全部为 `active`）未作任何改写。**

## B. `last_recommended` —— ✅ 按「仅新行」执行

- 存量 17 行**保持无此字段**，不回填。
- SKILL.md 已规定：读不到该字段时**回退用 `last_seen`** 判断 30 天冷却，并在 `data/runs/` 注明「本次回退」。
- 副作用（已知、可接受）：老条目按 `last_seen` 粗算，可能**多冷却几天**，属保守方向，不会误推。

## C. `captured_at` —— ✅ 已执行

- 新快照行带上该字段；存量行缺失时**用文件日期补齐**，不作为硬校验。

## D. 机器可读档案 —— ✅ 新建 `data/picks/`

- 位置：`data/picks/YYYY-MM-DD.jsonl`，字段定义见 `data/README.md`。
- **没有**把这些字段塞进 `snapshots/`，以保持那里作为纯星数基线的单一职责。

## 遗留事项

- 存量 17 行没有 `last_recommended`，属预期状态，**无需补做**。
- 首个 `data/picks/` 数据文件将在下一次跑日报时生成（目前只有 `data/picks/README.md` 说明文件）。
