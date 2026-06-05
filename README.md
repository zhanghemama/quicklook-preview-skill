# Quick Look Preview

用 macOS Quick Look 为本地文件生成真实预览图。

这个脚本不依赖 Codex。它只是对 macOS 自带的 `qlmanage` 做了一层简单封装，适合把 HTML、Markdown、TXT、RTF、PDF 等文件生成 PNG 预览图，用来展示“这个文件直接预览时长什么样”。

## 适用场景

- 给工具产物生成真实文件预览图。
- 展示 HTML、Markdown、知乎文本、小红书文本等不同输出文件的实际预览效果。
- 批量生成 Finder / Quick Look 风格的文件缩略图。
- 验证一个文件被 macOS 直接预览时的表现。

## 前提条件

只支持 macOS，因为它依赖系统自带的 Quick Look：

```bash
qlmanage -h
```

如果这条命令能显示帮助信息，就可以使用。

## 脚本位置

项目内草稿：

```text
quicklook-preview.sh
```

Codex skill 安装版：

```text
.codex/skills/quicklook-preview/scripts/quicklook-preview.sh
```

两份脚本功能一样。日常命令行使用时，推荐使用安装版路径。

## 基本用法

```bash
bash ~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh \
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
- 后面的文件路径：要生成预览图的一个或多个本地文件。

## 输出文件名

Quick Look 会把结果写成：

```text
<原文件名>.png
```

例如：

```text
codex-for-every-role.preview.html
```

会生成：

```text
actual-effect-screenshots/codex-for-every-role.preview.html.png
```

## 当前项目示例

在项目目录中执行：

```bash
cd path/to/format-skill

bash ~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh \
  --out actual-effect-screenshots \
  --size 1400 \
  codex-for-every-role.preview.html \
  output.md \
  codex-for-every-role.zhihu.txt \
  codex-for-every-role.xhs.txt
```

会得到：

```text
actual-effect-screenshots/codex-for-every-role.preview.html.png
actual-effect-screenshots/output.md.png
actual-effect-screenshots/codex-for-every-role.zhihu.txt.png
actual-effect-screenshots/codex-for-every-role.xhs.txt.png
```

## 单个文件示例

```bash
bash ~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh \
  --out previews \
  --size 1200 \
  path/to/format-skill/output.md
```

输出：

```text
previews/output.md.png
```

## 重要说明

这些图片是 macOS Quick Look 的真实预览图，不是浏览器截图，也不是知乎或小红书发布后的真实页面截图。

不同文件类型的效果会不一样：

- HTML：通常会用 Quick Look / WebKit 预览，接近浏览器中的静态页面效果。
- Markdown：通常显示为纯文本预览，不一定会渲染成 Markdown 样式。
- TXT：显示为纯文本预览。
- RTF：会保留一部分富文本样式。
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

可以。把多个文件路径放在命令最后即可：

```bash
bash ~/.codex/skills/quicklook-preview/scripts/quicklook-preview.sh \
  --out previews \
  article.html \
  article.md \
  article.zhihu.txt \
  article.xhs.txt
```

### 可以不用 Codex 吗？

可以。这个脚本是普通 Bash 脚本，可以直接在终端执行。
