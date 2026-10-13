# Demo 数据包

这是给"想看看它长什么样"的人准备的**最小可跑数据集**（不是完整库）。

| 项 | 值 |
|---|---|
| 项目数 | 15 |
| 事件数 | 26 |
| 分类覆盖 | AI(9)、其他(3)、设计(2)、效率(1) |
| 来源 | **全部是真实公开的 GitHub 项目**（自动发现的为主，含 1 条已淘汰示例） |

## 里面**没有**什么（刻意去掉的）

- 用户自己添加的项目、个人备注（`data/user-notes.jsonl`）
- 工作区（`data/workspaces.jsonl`）
- 每日日报正文、抓取快照、推荐台账

## 怎么用它试跑

把本目录的四个文件覆盖到 `data/`（**先备份原库**），然后：

```powershell
& ".\tools\sync-projects.ps1" -Force
& ".\tools\build-overview.ps1"
& ".\tools\check-page.ps1"
```

页面会只剩这 15 个项目 —— 足够看清结构，也足够验证"换一份数据照样能跑"。

## 怎么重新生成

```powershell
& ".\tools\make-demo.ps1" -Count 15
```