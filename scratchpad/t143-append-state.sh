#!/bin/sh
# Append this task's STATE.md section, idempotently -- re-running must not
# duplicate it (a second copy of a section reads as two independent findings).
set -e
S=$(cd "$(dirname "$0")" && pwd)
SEC="$S/t143-state-section.md"
ST="$S/STATE.md"
[ -f "$SEC" ] || { echo "FATAL: $SEC missing"; exit 9; }
[ -f "$ST" ]  || { echo "FATAL: $ST missing"; exit 9; }
MARK='# #143 / #154 / #49 -- THREE "COMPILED ONCE AND SHARED" ITEMS, RE-MEASURED'
if grep -qF "$MARK" "$ST"; then
  echo "already appended; nothing to do"
  exit 0
fi
before=$(wc -l < "$ST")
cat "$SEC" >> "$ST"
after=$(wc -l < "$ST")
echo "STATE.md $before -> $after lines"
grep -qF "$MARK" "$ST" || { echo "FATAL: append did not take"; exit 9; }
