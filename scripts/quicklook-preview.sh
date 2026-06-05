#!/usr/bin/env bash
set -euo pipefail

out_dir="actual-effect-screenshots"
size="1400"
files=()

usage() {
  printf 'Usage: %s [--out DIR] [--size PX] FILE...\n' "$0"
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
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        files+=("$1")
        shift
      done
      ;;
    -*)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

if [[ ${#files[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

mkdir -p "$out_dir"
qlmanage -t -s "$size" -o "$out_dir" "${files[@]}"

printf '\nGenerated preview files:\n'
for file in "${files[@]}"; do
  base="$(basename "$file")"
  preview="$out_dir/$base.png"
  if [[ -f "$preview" ]]; then
    printf '%s\n' "$preview"
  fi
done
