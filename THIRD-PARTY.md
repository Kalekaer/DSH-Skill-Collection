# THIRD-PARTY NOTICES · 第三方许可

本项目生成的 `overview.html` **内嵌**了 Anton 字体（base64 data URI）；日报 C 版通过 `@font-face` 引用**本地** `assets/anton-latin.woff2` 与 `assets/fonts/BebasNeue-Regular.ttf` → **运行期外部请求 = 0** ✓。
按各自许可的要求，此处保留**版权声明**与**许可全文**。

## 1. Anton（拉丁刊头体）

| 项 | 值 |
|---|---|
| 文件 | `assets/anton-latin.woff2`（Google Fonts 提供的 **latin 子集**，18612 B） |
| 来源 | <https://fonts.google.com/specimen/Anton> ｜ `google/fonts` 仓库 `ofl/anton/` |
| 版权 | Copyright 2020 The Anton Project Authors (<https://github.com/googlefonts/AntonFont.git>) |
| 许可 | **SIL Open Font License 1.1**（OFL **条件 2**：随附版权声明与许可文本 → 就是本文件） |
| 内嵌位置 | `tools/build-overview.ps1` 生成的 `@font-face`（CSS 变量 `--font-display`） |
| 用途 | **只用于拉丁**刊头/标签；中文一律系统字体栈 —— **不内嵌任何 CJK 子集** ✗ |

> 复现：`assets/anton-latin.woff2` 取自 Google Fonts CSS API（Chrome UA）返回的 `latin` 子集 URL；
> 同一批次的原始响应留档为 `assets/anton.css`（CSS）与 `assets/anton-OFL.txt`（许可全文），便于核对。
> 复采命令见 `素材清单.md`。

## 2. Bebas Neue（拉丁数字/编号）

| 项 | 值 |
|---|---|
| 文件 | `assets/fonts/BebasNeue-Regular.ttf`（61,400 B） |
| 来源 | `google/fonts` 仓库 `ofl/bebasneue/` |
| 版权 | Copyright 2010 The Bebas Neue Project Authors |
| 许可 | **SIL Open Font License 1.1**（全文 `assets/fonts/OFL-BebasNeue.txt`） |
| 用途 | 日报 C 版的结构编号、版号、小数字；拉丁 only |

## 3. NASA 结构摄影（公有领域）

日报 C 版的结构图版使用 NASA 自有摄影，**只做灰度 + 半调 + 压暗处理**，不改原意。
依据 [NASA Media Usage Guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/)：NASA 自有素材一般不受版权保护、可商用；画面不含 NASA 徽标/标识。

| 文件 | NASA ID | 内容 | 摄影师 | 尺寸 | 字节 |
|---|---|---|---|---|---|
| `assets/bg/nasa-vab-highbay.jpg` | KSC-20180620-PH_GEB01_0004 | Vehicle Assembly Building High Bay 3 work platforms | NASA/Glenn Benson | 1920×1279 | 528,420 |
| `assets/bg/nasa-pad39b-steel.jpg` | KSC-2010-4941 | Launch Pad 39B rotating service structure dismantling | NASA/Jim Grossmann | 1920×1285 | 388,569 |
| `assets/bg/nasa-mobile-launcher.jpg` | KSC-20180314-PH_JBS01_0013 | Mobile Launcher steel structure before sunrise | NASA/Ben Smegelsky | 1280×1920 | 104,286 |
| `assets/bg/nasa-engine-test.jpg` | 6778720 | Saturn Apollo Program engine test | NASA | 1920×1536 | 200,990 |

> 原始直链与 SHA256 见 `assets/bg/SOURCES.md`；页面引用**本地文件**，运行期外部请求 = 0。

## 4. 其他第三方素材

**无** —— 页面不使用任何图表库 / 图标库 / 前端框架；网格、斜线、半调与噪点纹理为 CSS/SVG 自制。
中文与等宽字体使用**系统字体栈**（随系统授权，不随本项目分发）✓

## 5. Special Elite（草稿 02「影印拼贴」使用）

| 项 | 值 |
|---|---|
| 文件 | `assets/fonts/SpecialElite-Regular.ttf`（166,180 B） |
| 来源 | `google/fonts` 仓库 `apache/specialelite/` |
| 许可 | **Apache License 2.0**（全文 `assets/fonts/SpecialElite-LICENSE.txt`） |
| 用途 | 影印草稿的打字机标注；可商用、可嵌入，保留许可与版权声明 |

---

## SIL Open Font License 1.1（全文）

Copyright 2020 The Anton Project Authors (https://github.com/googlefonts/AntonFont.git)

This Font Software is licensed under the SIL Open Font License, Version 1.1.
This license is copied below, and is also available with a FAQ at:
http://scripts.sil.org/OFL


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded, 
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.