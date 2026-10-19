# Demo 数据包

这是给「想看看它长什么样 / 想重置」的人准备的**最小可跑数据集**（不是完整库）。

| 项 | 值 |
|---|---|
| 项目数 | 15 |
| 事件数 | 20 |
| 当日新增（ENTRIES） | 2（demo 故意留 2 条 first_seen=当天，用来展示「当日入库全名单」） |
| 主推荐（S/A） | 5 |
| 分类覆盖 | 6 个一级分类 |
| 来源 | **全部是真实公开的 GitHub 项目**（不含作者个人添加的项目） |

## 里面有什么

- `projects.jsonl`：投影层（15 条，字段与正式库一致）
- `events.jsonl`：事件流（收录 / 推荐 / 二次推荐）
- `plans.json`：11 个组合预设
- `taxonomy.json`：两级分类定义

## 里面**没有**什么（刻意去掉的）

- 个人备注（`note` / `user_notes` 一律空串）
- 用户自己添加的项目、工作区、状态变更史
- 日报正文、每日星数快照、真实推荐台账（`data/recommend-log.csv` 只有 5 行 demo）
- 个人长期表（`GitHub推荐记录.univer`）

## 怎么用它重置

把本目录四个文件覆盖到 `data/`（**先备份原库**），然后：

```powershell
& ".\tools\sync-projects.ps1" -Force
& ".\tools\build-samples.ps1" -Date 2026-10-19
```

页面会回到 15 个项目 —— 足够看清结构，也足够验证「换一份数据照样能跑」。

## 怎么重新生成

```powershell
& ".\tools\make-demo.ps1" -Count 15
```
