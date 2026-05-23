#!/usr/bin/env bash
#
# install.sh — install the 6502 skills into a coding agent's skills directory.
#
# By default the skills are symlinked, so edits in this repo are picked up
# everywhere. Use --copy for a standalone copy (e.g. on Windows, or to vendor
# the skills into another repo).
#
# Examples:
#   ./install.sh --claude              # Claude Code, personal (~/.claude/skills)
#   ./install.sh --agents              # open standard (~/.agents/skills): opencode, Kilo, Codex
#   ./install.sh --claude --agents     # both at once
#   ./install.sh --opencode --kilo     # each agent's own global skills dir
#   ./install.sh --to ./myproj/.claude/skills   # an explicit directory
#   ./install.sh --agents --copy       # copy instead of symlink
#
set -euo pipefail

SKILLS=(6502-instruction-set 6502-memory-map 6502-merlin-assembler 6502-sweet16 6502-to-rust)
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

mode="symlink"
declare -a targets=()

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)   targets+=("$HOME/.claude/skills") ;;          # Claude Code (personal)
    --agents)   targets+=("$HOME/.agents/skills") ;;          # open standard: opencode, Kilo, Codex
    --opencode) targets+=("$HOME/.config/opencode/skills") ;; # opencode (global)
    --kilo)     targets+=("$HOME/.kilo/skills") ;;            # Kilo Code (global)
    --to)       shift; [ $# -gt 0 ] || { echo "--to needs a directory" >&2; exit 1; }; targets+=("$1") ;;
    --copy)     mode="copy" ;;
    --symlink)  mode="symlink" ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ ${#targets[@]} -eq 0 ]; then
  echo "No target. Pass one of --claude --agents --opencode --kilo, or --to DIR." >&2
  echo >&2
  usage >&2
  exit 1
fi

for dest in "${targets[@]}"; do
  mkdir -p -- "$dest"
  # Resolve to a real path and refuse a destination that is the source repo or
  # nested inside it: the rm -rf below would delete the canonical skill dirs.
  dest_real="$(cd -- "$dest" && pwd -P)"
  case "$dest_real/" in
    "$SRC"/* )
      echo "refusing to install into $dest_real: it is inside the source repo ($SRC)." >&2
      echo "install into a different directory (e.g. ~/.claude/skills or ~/.agents/skills)." >&2
      exit 1 ;;
  esac
  for s in "${SKILLS[@]}"; do
    rm -rf -- "${dest_real:?}/$s"
    if [ "$mode" = copy ]; then
      cp -R -- "$SRC/$s" "$dest_real/$s"
    else
      ln -s -- "$SRC/$s" "$dest_real/$s"
    fi
    printf '  %-8s %s/%s\n' "$mode" "$dest_real" "$s"
  done
  echo "installed ${#SKILLS[@]} skills into $dest_real"
done
