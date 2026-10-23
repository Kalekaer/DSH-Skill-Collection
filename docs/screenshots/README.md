# 截图说明（3 张就够）/ Screenshot guide (3 images is enough)

> README 里的图位指向这个目录。**只需要 3 张**——不要十几张。
> The image slots in README point here. **Three are enough** — do not add a dozen.
>
> 拍法：双击 `index.html`（或直接打开 `data/site/` 下的页面）→ 浏览器全屏（F11）→ `Win + Shift + S` 截图 → 存成下面这三个文件名。
> How to shoot: open the pages, go full screen, capture, and save with the names below.

| 文件名 / File | 拍什么 / What to capture | README 里的图注 / Caption |
|---|---|---|
| `1-home.jpg` | **首页**：ARCHIVE 标题、四个入口、下方 DATA 看板 / Home: ARCHIVE title, four entries, DATA board | 打开即用的本地项目档案站 / A local project archive that just works |
| `2-daily.jpg` | **日报页**：01 今日头条 + 02 重点报道 + 03 观察面 + 04 边栏观察（05/06 特别栏目与旧闻新报）/ Daily page: 01 headline + 02 features + 03 observation + 04 margin (05/06 special & old friends) | 每天一页结构日报，S/A/B/C/D 是承重等级 / A structured daily brief; S/A/B/C/D are load-bearing tiers |
| `3-plans.jpg` | **计划页**：11 个组合预设 + 「我的工作区」 / Plans: 11 presets + workspaces | 根据目标组合工具，而不是收藏链接 / Compose tools by goal, not bookmarks |

## 拍之前的两点注意 / Before shooting

1. **只能用 demo 数据生成页面后拍**：仓库里的 `index.html` / `data/site/` 就是 demo 构建产物，别拿自己真实库的页面拍（会带出真实项目，当前库约 **294 条**）。
   **Only shoot pages built from demo data**: the shipped pages are demo builds; never shoot your real library (currently about **294 projects**).
2. **建议宽度**：浏览器窗口 ≥1200px 再截；窄屏会把入口和看板挤成单列。
   **Width**: use a window of at least 1200px; narrower viewports collapse the entries and board into one column.

## 拍完之后 / After shooting

把三张图放进本目录，然后：
Put the three images here, then:

```powershell
# 确认 README 的图位引用的就是这三个文件名
# Confirm README's image slots reference these three filenames
Select-String -Path ".\README.md" -Pattern 'docs/screenshots'
```

README 里的图位是 Markdown 图片语法，文件放进来即生效，**不需要改任何代码**。
The image slots are plain Markdown; dropping the files in is enough — no code changes needed.