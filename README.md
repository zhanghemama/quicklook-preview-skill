# Quick Look Preview

用 macOS Quick Look 为本地文件生成真实预览图。

这个脚本不依赖 Codex。它主要对 macOS 自带的 `qlmanage` 做了一层简单封装，适合把 HTML、Markdown、TXT、RTF、PDF 等文件生成 PNG 预览图，用来展示“这个文件直接预览时长什么样”。其中 HTML 和 RTF 默认使用完整页面渲染，避免 HTML 片段编码被 Quick Look 猜错、或长 RTF 被缩略图截断。

## 适用场景

- 给工具产物生成真实文件预览图。
- 展示 HTML、Markdown、知乎文本、小红书文本等不同输出文件的实际预览效果。
- 批量生成 Finder / Quick Look 风格的文件缩略图。
- 验证一个文件被 macOS 直接预览时的表现。

## 前提条件

只支持 macOS，因为普通文件预览依赖系统自带的 Quick Look：

```bash
qlmanage -h
```

如果这条命令能显示帮助信息，就可以使用。

HTML / RTF 的默认完整页面模式还需要本机有 Node.js 和 Google Chrome 或 Chromium。

## 脚本位置

项目内草稿：

```text
scripts/quicklook-preview.sh
```

Codex skill 安装版：

```text
~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh
```

两份脚本功能一样。在这个仓库里可以用 `scripts/quicklook-preview.sh`；在任意目录里日常命令行使用时，推荐用安装版路径 `~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh`。

## 基本用法

不传 `--out` 时，图片会生成到当前工作目录下的 `actual-effect-screenshots/`：

```bash
bash scripts/quicklook-preview.sh your.html output.md
```

等价于：

```bash
bash scripts/quicklook-preview.sh \
  --out actual-effect-screenshots \
  your.html \
  output.md
```

想生成到别的目录，就显式传 `--out`。比如生成到 `previews/`：

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  your.html \
  output.md
```

完整参数示例：

```bash
bash scripts/quicklook-preview.sh \
  --out actual-effect-screenshots \
  --size 1400 \
  your.html \
  output.md \
  your.zhihu.txt \
  your.xhs.txt
```

参数说明：

- `--out`：预览图输出目录，默认是 `actual-effect-screenshots`。
- `--size`：预览图长边尺寸，默认是 `1400`。
- `--html-mode`：HTML 生成模式，默认是 `fullpage`。可选 `fullpage` 或 `quicklook`。
- `--rtf-mode`：RTF 生成模式，默认是 `fullpage`。可选 `fullpage` 或 `quicklook`。
- 后面的路径：要生成预览图的一个或多个本地文件或文件夹。

HTML 默认使用完整页面渲染：脚本会用本机 Chrome 的 headless 模式打开 HTML 并截取完整页面。这样 HTML fragment 即使没有 `<meta charset="utf-8">`，也能避免 Quick Look 误判编码导致中文乱码。

如果你想要严格的 Quick Look HTML 方形缩略图，可以显式指定：

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  --html-mode quicklook \
  path/to/file.html
```

RTF 默认使用完整页面渲染：脚本会先用 macOS 自带的 `textutil` 把 RTF 转成临时 HTML，再用本机 Chrome 的 headless 模式截取完整页面，避免 Quick Look 缩略图只截到前半部分。

如果你想要严格的 Quick Look 方形缩略图，可以显式指定：

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  --rtf-mode quicklook \
  path/to/file.rtf
```

HTML / RTF 完整页面模式需要本机安装 Google Chrome 或 Chromium。如果浏览器不可用，命令会报错，避免悄悄生成一张乱码或被截断的缩略图；需要 Quick Look 缩略图时请显式使用 `--html-mode quicklook` 或 `--rtf-mode quicklook`。

## 输出文件名

脚本会把结果写成：

```text
<原文件名>.png
```

例如：

```text
your_file.preview.html
```

会生成：

```text
actual-effect-screenshots/your_file.preview.html.png
```

## 当前项目示例

在项目目录中执行：

```bash
cd path/to/quicklook-preview-skill

bash scripts/quicklook-preview.sh \
  --out actual-effect-screenshots \
  --size 1400 \
  your_file.preview.html \
  output.md \
  your_file.zhihu.txt \
  your_file.xhs.txt
```

会得到：

```text
actual-effect-screenshots/your_file.preview.html.png
actual-effect-screenshots/output.md.png
actual-effect-screenshots/your_file.zhihu.txt.png
actual-effect-screenshots/your_file.xhs.txt.png
```

上面这个示例生成到 `actual-effect-screenshots/`，是因为命令里写了 `--out actual-effect-screenshots`。如果命令里写的是 `--out previews/test-rtf-skill`，就会生成到 `previews/test-rtf-skill/`。

## 单个文件示例

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  --size 1200 \
  path/to/quicklook-preview-skill/output.md
```

输出：

```text
previews/output.md.png
```

## 文件夹批量示例

可以直接把文件夹路径放在命令最后。脚本会递归处理文件夹里的普通文件，并在输出目录里保留原文件夹结构：

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  --size 1200 \
  path/to/articles
```

如果文件夹内容是：

```text
articles/index.html
articles/output.md
articles/social/xhs.txt
```

会生成：

```text
previews/articles/index.html.png
previews/articles/output.md.png
previews/articles/social/xhs.txt.png
```

目录批量模式会跳过隐藏文件、隐藏子目录和 `.DS_Store`。如果输出目录刚好在输入目录里面，也会自动跳过输出目录，避免重复处理已经生成的 PNG。

## 输出目录规则

只有 `--out` 决定图片写到哪里：

- 不写 `--out`：写到默认目录 `actual-effect-screenshots/`。
- 写 `--out previews`：写到 `previews/`。
- 写 `--out previews/test-rtf-skill`：写到 `previews/test-rtf-skill/`。
- 传入单个文件：图片直接放在输出目录下，例如 `previews/output.md.png`。
- 传入文件夹：脚本会在输出目录下保留输入文件夹名和子目录结构，例如 `previews/articles/social/xhs.txt.png`。

## 重要说明

除默认 HTML / RTF 完整页面模式外，这些图片是 macOS Quick Look 的真实预览图；它们不是知乎或小红书发布后的真实页面截图。

不同文件类型的效果会不一样：

- HTML：默认使用完整页面渲染，避免 HTML fragment 缺少 charset 时被 Quick Look 截成乱码；使用 `--html-mode quicklook` 时会回到系统 Quick Look 缩略图效果。
- Markdown：通常显示为纯文本预览，不一定会渲染成 Markdown 样式。
- TXT：显示为纯文本预览。
- RTF：默认使用完整页面渲染，避免长文档被 Quick Look thumbnail 截断；使用 `--rtf-mode quicklook` 时会回到系统 Quick Look 缩略图效果。
- PDF：显示 PDF 页面预览。

如果你要展示“文件直接打开或直接预览的真实效果”，用这个脚本是合适的。

如果你要展示“浏览器里打开 HTML 的真实网页效果”，应该使用浏览器截图。

如果你要展示“知乎 / 小红书发布后的真实效果”，需要在对应平台编辑器或发布预览中截图。

## 常见问题

### 为什么 Markdown 没有像网页那样排版？

因为 Quick Look 对 `.md` 文件通常按文本文件预览。它展示的是这个 Markdown 文件在系统预览中的真实效果，而不是某个 Markdown 编辑器或网站渲染后的效果。

### 为什么小红书或知乎文本看起来像纯文本？

`.txt` 文件在 Quick Look 里就是纯文本预览。这个结果可以证明工具输出的是平台可复制文本，但不能代表粘贴进平台编辑器后的最终样式。

### 可以批量生成吗？

可以。把多个文件或文件夹路径放在命令最后即可：

```bash
bash scripts/quicklook-preview.sh \
  --out previews \
  article.html \
  article.md \
  article.zhihu.txt \
  article.xhs.txt \
  path/to/articles
```

### 可以不用 Codex 吗？

可以。这个脚本是普通 Bash 脚本，可以直接在终端执行。
