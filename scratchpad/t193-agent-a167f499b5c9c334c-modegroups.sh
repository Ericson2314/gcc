#!/bin/sh
# #193 -- the FOUR semantic variants of insn-modes.h, named, with the diff
# between them.  Run after t193-...-modeprov.sh has established the count.
set -u
G=${1:?build dir}/gcc
O=${MT_OUT:-/tmp/t193-groups-$$}
rm -rf "$O"; mkdir -p "$O"
for p in "$G"/insn-modes-*.h; do
  case "$p" in *insn-modes-inline-*) continue ;; esac
  b=$(basename "$p" .h | sed 's/^insn-modes-//')
  tail -n +3 "$p" | sed -e 's,/\*[^*]*\*/,,g' -e 's/[[:space:]]*$//' > "$O/$b.txt"
  echo "$(md5sum "$O/$b.txt" | cut -c1-12) $b"
done | sort > "$O/keys.txt"
awk '{print $1}' "$O/keys.txt" | uniq -c | sort -rn | while read -r n k; do
  echo "== variant $k : $n bases"
  awk -v k="$k" '$1==k {printf "   %s", $2}' "$O/keys.txt"; echo
done
echo
first=$(head -1 "$O/keys.txt" | awk '{print $2}')
echo "=== diffs of every other variant against $first"
awk '{print $1}' "$O/keys.txt" | sort -u | while read -r k; do
  b=$(awk -v k="$k" '$1==k {print $2; exit}' "$O/keys.txt")
  [ "$b" = "$first" ] && continue
  echo "--- $first vs $b"
  diff "$O/$first.txt" "$O/$b.txt" | head -40
done
echo "output: $O"
