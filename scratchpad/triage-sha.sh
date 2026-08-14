#!/bin/sh
# Task triage: ancestry-test every commit SHA named in PRINCIPLES.md / STATE.md.
# A named-cause list is a measurement with a timestamp; this settles each entry.
set -u
cd "$(dirname "$0")/.." || exit 1
grep -ohE '\b[0-9a-f]{7,12}\b' scratchpad/PRINCIPLES.md scratchpad/STATE.md | sort -u > scratchpad/triage-shas.txt
echo "candidate tokens: $(wc -l < scratchpad/triage-shas.txt)"
while read -r s; do
  git cat-file -e "${s}^{commit}" 2>/dev/null || continue
  if git merge-base --is-ancestor "$s" HEAD 2>/dev/null; then r=IN-HEAD; else r=NOT-ANCESTOR; fi
  printf '%s %s %s\n' "$r" "$s" "$(git log -1 --format=%s "$s" | cut -c1-72)"
done < scratchpad/triage-shas.txt
