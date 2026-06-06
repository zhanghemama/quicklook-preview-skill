---
name: quicklook-preview
description: Generate real macOS Quick Look preview images for local files. Use when the user asks for actual file preview screenshots, Quick Look thumbnails, Finder-like previews, or truthful effect images of HTML, Markdown, TXT, RTF, PDF, images, or other local documents.
metadata:
  short-description: Generate real Quick Look previews
---

# Quick Look Preview

Use this skill to create PNG screenshots for local files. Most file types use macOS Quick Look's real thumbnail preview. HTML and RTF files use a full-page renderer by default: HTML avoids Quick Look charset guessing issues for UTF-8 fragments, and RTF avoids truncating long rich-text documents. Pass `--html-mode quicklook` or `--rtf-mode quicklook` when the user specifically wants the literal Quick Look thumbnail.

## Workflow

1. Confirm the files or directories are local and readable.
2. Choose an output directory near the source files, such as `actual-effect-screenshots/`.
3. Generate previews with the bundled script:

   ```bash
   bash scripts/quicklook-preview.sh --out actual-effect-screenshots --size 1400 file1.html file2.md file3.txt
   ```

4. Remember the script writes files as `<original-filename>.png` in the output directory. When `--out` is omitted, the default output directory is `actual-effect-screenshots/`; `previews/` is used only when explicitly passed with `--out previews` or a similar path.
5. Verify output with `ls -lh`, `file`, and visual inspection when available.
6. Tell the user these are actual Quick Look previews except for default HTML / RTF full-page rendering, and that they are not screenshots of a platform editor.

## Script

For repeated runs, use the bundled script:

```bash
bash scripts/quicklook-preview.sh --out actual-effect-screenshots --size 1400 file1.html file2.md file3.txt
```

Resolve `scripts/quicklook-preview.sh` relative to this skill directory. The script creates the output directory, runs the appropriate renderer, and lists generated PNGs.

HTML files use full-page rendering by default because Quick Look can mis-detect the encoding of UTF-8 HTML fragments that do not include a `<meta charset="utf-8">`. To force literal Quick Look thumbnails for HTML, pass:

```bash
bash scripts/quicklook-preview.sh --html-mode quicklook --out actual-effect-screenshots file.html
```

RTF files use full-page rendering by default because Quick Look thumbnail mode can truncate long RTF documents. The script converts RTF to temporary HTML with macOS `textutil`, then captures a full-page PNG with local Chrome headless. To force literal Quick Look thumbnails for RTF, pass:

```bash
bash scripts/quicklook-preview.sh --rtf-mode quicklook --out actual-effect-screenshots file.rtf
```

The script also accepts directories:

```bash
bash scripts/quicklook-preview.sh --out actual-effect-screenshots --size 1400 path/to/folder
```

Directory inputs are expanded recursively. Generated PNGs are mirrored under the output directory, such as `actual-effect-screenshots/folder/subdir/file.md.png`. Hidden files, hidden subdirectories, `.DS_Store`, and the output directory itself are skipped during directory expansion.

## Notes

- This only works on macOS with Quick Look available.
- HTML full-page rendering requires Node.js and local Google Chrome or Chromium. If unavailable, the script exits with an error; pass `--html-mode quicklook` when a literal Quick Look thumbnail is acceptable.
- RTF full-page rendering requires macOS `textutil`, Node.js, and local Google Chrome or Chromium. If unavailable, the script exits with an error; pass `--rtf-mode quicklook` when a literal Quick Look thumbnail is acceptable.
- Quick Look previews for `.md` and `.txt` usually show plain text, not rendered Markdown or social-platform styling.
- HTML previews are full-page browser renderings by default. Literal Quick Look/WebKit thumbnails may differ slightly and can be forced with `--html-mode quicklook`.
- If sandboxing blocks `qlmanage`, rerun the command with the appropriate escalation flow.
- For web browser screenshots, use a browser automation skill instead; this skill is specifically for filesystem preview images.
