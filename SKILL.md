---
name: quicklook-preview
description: Generate real macOS Quick Look preview images for local files. Use when the user asks for actual file preview screenshots, Quick Look thumbnails, Finder-like previews, or truthful effect images of HTML, Markdown, TXT, RTF, PDF, images, or other local documents.
metadata:
  short-description: Generate real Quick Look previews
---

# Quick Look Preview

Use this skill to create PNG screenshots that reflect macOS Quick Look's real preview of local files. This is useful when the user wants to show what generated files actually look like when opened or previewed, instead of a simulated renderer.

## Workflow

1. Confirm the files are local and readable.
2. Choose an output directory near the source files, such as `actual-effect-screenshots/`.
3. Generate previews with macOS Quick Look:

   ```bash
   qlmanage -t -s 1400 -o actual-effect-screenshots file1.html file2.md file3.txt
   ```

4. Remember Quick Look writes files as `<original-filename>.png` in the output directory.
5. Verify output with `ls -lh`, `file`, and visual inspection when available.
6. Tell the user these are actual Quick Look previews, not screenshots of a browser or platform editor.

## Script

For repeated runs, use the bundled script:

```bash
bash scripts/quicklook-preview.sh --out actual-effect-screenshots --size 1400 file1.html file2.md file3.txt
```

Resolve `scripts/quicklook-preview.sh` relative to this skill directory. The script creates the output directory, runs `qlmanage`, and lists generated PNGs.

## Notes

- This only works on macOS with Quick Look available.
- Quick Look previews for `.md` and `.txt` usually show plain text, not rendered Markdown or social-platform styling.
- HTML previews are Quick Look/WebKit previews, which may differ slightly from an interactive browser window.
- If sandboxing blocks `qlmanage`, rerun the command with the appropriate escalation flow.
- For web browser screenshots, use a browser automation skill instead; this skill is specifically for filesystem preview images.
