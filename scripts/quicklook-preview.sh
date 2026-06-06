#!/usr/bin/env bash
set -euo pipefail

out_dir="actual-effect-screenshots"
size="1400"
html_mode="fullpage"
rtf_mode="fullpage"
inputs=()
source_files=()
target_dirs=()
preview_files=()
dir_labels=()
out_abs=""
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  printf 'Usage: %s [--out DIR] [--size PX] [--html-mode fullpage|quicklook] [--rtf-mode fullpage|quicklook] FILE_OR_DIR...\n' "$0"
  printf '\n'
  printf 'Files are written as <filename>.png in the output directory.\n'
  printf 'Directories are expanded recursively and mirrored under the output directory.\n'
  printf 'Hidden files and hidden subdirectories are skipped during directory expansion.\n'
  printf 'HTML files use full-page rendering by default; use --html-mode quicklook for Quick Look thumbnails.\n'
  printf 'RTF files use full-page rendering by default; use --rtf-mode quicklook for Quick Look thumbnails.\n'
}

abs_path() {
  local path="$1"
  local dir
  local base

  if [[ -d "$path" ]]; then
    (cd "$path" && pwd -P)
    return
  fi

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

unique_dir_label() {
  local base="$1"
  local label="$base"
  local index=2
  local existing

  while :; do
    if [[ ${#dir_labels[@]} -gt 0 ]]; then
      for existing in "${dir_labels[@]}"; do
        if [[ "$existing" == "$label" ]]; then
          label="${base}_${index}"
          index=$((index + 1))
          continue 2
        fi
      done
    fi

    dir_labels+=("$label")
    printf '%s\n' "$label"
    return
  done
}

add_source_file() {
  local file="$1"
  local target_dir="$2"
  local preview="$target_dir/$(basename "$file").png"

  source_files+=("$file")
  target_dirs+=("$target_dir")
  preview_files+=("$preview")
}

file_ext() {
  local base
  local ext

  base="$(basename "$1")"
  if [[ "$base" != *.* ]]; then
    printf '\n'
    return
  fi

  ext="${base##*.}"
  printf '%s\n' "$ext" | tr '[:upper:]' '[:lower:]'
}

can_render_html_fullpage() {
  command -v node >/dev/null 2>&1 &&
    [[ -f "$script_dir/html-fullpage-screenshot.mjs" ]]
}

can_render_rtf_fullpage() {
  command -v textutil >/dev/null 2>&1 && can_render_html_fullpage
}

render_quicklook_thumbnail() {
  local file="$1"
  local target_dir="$2"

  qlmanage -t -s "$size" -o "$target_dir" "$file"
}

render_html_fullpage() {
  local file="$1"
  local preview="$2"
  local attempt

  if ! can_render_html_fullpage; then
    printf 'HTML full-page rendering requires node and scripts/html-fullpage-screenshot.mjs.\n' >&2
    return 1
  fi

  for attempt in 1 2 3; do
    if node "$script_dir/html-fullpage-screenshot.mjs" \
      --input "$file" \
      --output "$preview" \
      --width "$size"; then
      return 0
    fi

    if [[ "$attempt" -lt 3 ]]; then
      printf 'Retrying HTML full-page rendering: %s\n' "$file" >&2
      sleep 1
    fi
  done

  return 1
}

render_rtf_fullpage() {
  local file="$1"
  local preview="$2"
  local tmp_dir
  local html_file
  local attempt

  if ! can_render_rtf_fullpage; then
    printf 'RTF full-page rendering requires textutil, node, and scripts/html-fullpage-screenshot.mjs.\n' >&2
    return 1
  fi

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/quicklook-preview-rtf.XXXXXX")"
  html_file="$tmp_dir/$(basename "$file").html"

  if ! textutil -convert html -output "$html_file" "$file"; then
    rm -rf "$tmp_dir"
    return 1
  fi

  for attempt in 1 2; do
    if render_html_fullpage "$html_file" "$preview"; then
      rm -rf "$tmp_dir"
      return 0
    fi

    if [[ "$attempt" -lt 2 ]]; then
      printf 'Retrying RTF full-page rendering: %s\n' "$file" >&2
      sleep 1
    fi
  done

  rm -rf "$tmp_dir"
  return 1
}

render_preview() {
  local file="$1"
  local target_dir="$2"
  local preview="$3"
  local ext

  ext="$(file_ext "$file")"

  if [[ "$ext" == "html" || "$ext" == "htm" ]]; then
    if [[ "$html_mode" == "fullpage" ]]; then
      if ! render_html_fullpage "$file" "$preview"; then
        printf 'Failed to render full-page HTML preview: %s\n' "$file" >&2
        printf 'Use --html-mode quicklook if you want the original Quick Look thumbnail behavior.\n' >&2
        return 1
      fi

      return
    fi
  fi

  if [[ "$ext" == "rtf" && "$rtf_mode" == "fullpage" ]]; then
    if ! render_rtf_fullpage "$file" "$preview"; then
      printf 'Failed to render full-page RTF preview: %s\n' "$file" >&2
      printf 'Use --rtf-mode quicklook if you want the original Quick Look thumbnail behavior.\n' >&2
      return 1
    fi

    return
  fi

  render_quicklook_thumbnail "$file" "$target_dir"
}

add_directory() {
  local dir="$1"
  local dir_abs
  local dir_name
  local dir_label
  local file
  local rel
  local rel_dir
  local target_dir

  dir_abs="$(abs_path "$dir")"
  dir_name="$(basename "$dir_abs")"
  dir_label="$(unique_dir_label "$dir_name")"

  while IFS= read -r -d '' file; do
    if [[ "$file" == "$out_abs" || "$file" == "$out_abs"/* ]]; then
      continue
    fi

    if [[ "$(basename "$file")" == ".DS_Store" ]]; then
      continue
    fi

    if [[ ! -r "$file" ]]; then
      printf 'Skipping unreadable file: %s\n' "$file" >&2
      continue
    fi

    rel="${file#"$dir_abs"/}"
    rel_dir="$(dirname "$rel")"

    if [[ "$rel_dir" == "." ]]; then
      target_dir="$out_dir/$dir_label"
    else
      target_dir="$out_dir/$dir_label/$rel_dir"
    fi

    add_source_file "$file" "$target_dir"
  done < <(
    find "$dir_abs" \
      \( -path "$out_abs" -o -path "$out_abs/*" \) -prune -o \
      \( -type d -name '.*' ! -path "$dir_abs" \) -prune -o \
      -type f ! -name '.DS_Store' ! -name '.*' -print0
  )
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      out_dir="$2"
      shift 2
      ;;
    --size)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      size="$2"
      shift 2
      ;;
    --html-mode)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      case "$2" in
        fullpage|quicklook)
          html_mode="$2"
          ;;
        *)
          printf 'Invalid --html-mode: %s\n' "$2" >&2
          usage >&2
          exit 2
          ;;
      esac
      shift 2
      ;;
    --rtf-mode)
      if [[ $# -lt 2 ]]; then
        usage >&2
        exit 2
      fi
      case "$2" in
        fullpage|quicklook)
          rtf_mode="$2"
          ;;
        *)
          printf 'Invalid --rtf-mode: %s\n' "$2" >&2
          usage >&2
          exit 2
          ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        inputs+=("$1")
        shift
      done
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      inputs+=("$1")
      shift
      ;;
  esac
done

if [[ ${#inputs[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

mkdir -p "$out_dir"
out_abs="$(abs_path "$out_dir")"

for input in "${inputs[@]}"; do
  if [[ -d "$input" ]]; then
    add_directory "$input"
  elif [[ -f "$input" ]]; then
    if [[ ! -r "$input" ]]; then
      printf 'Unreadable file: %s\n' "$input" >&2
      exit 1
    fi

    add_source_file "$input" "$out_dir"
  else
    printf 'Path is not a file or directory: %s\n' "$input" >&2
    exit 1
  fi
done

if [[ ${#source_files[@]} -eq 0 ]]; then
  printf 'No readable files found.\n' >&2
  exit 1
fi

for index in "${!source_files[@]}"; do
  mkdir -p "${target_dirs[$index]}"
  render_preview "${source_files[$index]}" "${target_dirs[$index]}" "${preview_files[$index]}"
done

printf '\nGenerated preview files:\n'
for preview in "${preview_files[@]}"; do
  if [[ -f "$preview" ]]; then
    printf '%s\n' "$preview"
  else
    printf 'Missing expected preview: %s\n' "$preview" >&2
  fi
done
