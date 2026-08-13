#!/bin/sh
# #133 -- append this task's section to STATE.md, and REFUSE if it is already
# there, so a second run cannot double it.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
if grep -q '^# TASK #133 --' "$S/STATE.md"; then
  echo "REFUSE: STATE.md already has a #133 section"; exit 9
fi
before=$(wc -l < "$S/STATE.md")
cat "$S/t133-state-section.md" >> "$S/STATE.md"
after=$(wc -l < "$S/STATE.md")
echo "STATE.md $before -> $after lines"
grep -c '^# TASK #133 --' "$S/STATE.md"
