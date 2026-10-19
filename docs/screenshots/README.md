# 截图说明（3 张就够）

> README 里的图位指向这个目录。**只需要 3 张**——不要十几张。
> 拍法：双击 `index.html`（或直接打开 `data/site/` 下的页面）→ 浏览器全屏（F11）→ `Win + Shift + S` 截图 → 存成下面这三个文件名。

| 文件名 | 拍什么 | README 里的图注 |
|---|---|---|
| `1-home.jpg` | **首页**：ARCHIVE 标题、四个入口（每日精选 / 全库 / 计划与工作区 / 图例）、下方 DATA 看板都在画面里 | 打开即用的本地项目档案站 |
| `2-daily.jpg` | **日报页**（`data/site/daily-layout-c-finsara.generated.html`）：01 主承重跨 + 02 模块阵列（带配图）+ 03 档案层 | 每天一页结构日报，S/A/B/C/D 是承重等级 |
| `3-plans.jpg` | **计划页**（`data/site/plans-shelf.generated.html`）：11 个组合预设 + 「我的工作区」 | 根据目标组合工具，而不是收藏链接 |

## 拍之前的两点注意

1. **只能用 demo 数据生成页面后拍**：仓库里的 `index.html` / `data/site/` 就是 demo 构建产物，别拿自己真实库的页面拍（会带出 259 条真实项目）。
2. **建议宽度**：浏览器窗口 ≥1200px 再截；窄屏会把入口和看板挤成单列。

## 拍完之后

把三张图放进本目录，然后：

```powershell
# 确认 README 的图位引用的就是这三个文件名
Select-String -Path ".\README.md" -Pattern 'docs/screenshots'
```

README 里的图位是 Markdown 图片语法，文件放进来即生效，**不需要改任何代码**。
