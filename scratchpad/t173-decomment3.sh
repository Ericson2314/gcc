#!/bin/sh
# #173 -- the same repeated rationale block, in the SHARED sources that are
# compiled once per back end (target-*.cc and friends), not just gcc/config.
# Same ruling: the reasoning lives in scratchpad, the source states what it
# does.
set -e
cd "$(dirname "$0")/.."
n=0
for f in $(git grep -l 'rather than relying on -I<base>-inc' -- gcc); do
  awk '
    /^\/\* Compiled once per configured back end/ { skip = 1 }
    /^ *\/\* This source is compiled once per configured back end/ { skip = 1 }
    skip == 1 { if ($0 ~ /\*\/[ \t]*$/) skip = 0; next }
    { print }
  ' "$f" > "$f.t173" && mv "$f.t173" "$f"
  n=$((n + 1))
done
echo "de-commented $n shared file(s)"
git grep -c -- 'rather than relying on -I<base>-inc' -- gcc || echo "none left"
