#!/bin/sh
# Group a target's debt into NAMED FAMILIES rather than directories.
#
# The directory ranking buries a coherent item as twenty rows of ten: aarch64's
# function multiversioning is `mv-*.c' and `fmv*.c' across dozens of files, and
# x86_64's whole residual is one HFmode family spread over `part-vect-*hf*' and
# `avx512fp16-*'.  AB1900D5279BA137F-BOARD.md flagged exactly this for the mv
# population and had to say it in prose.
#
# usage: agent-a01e6c604f26604a7-families.sh <mt-sum> <stock-sum> <pattern>...
set -u
export LC_ALL=C
MT=${1:?mt sum}; shift
ST=${1:?stock sum}; shift
for f in "$MT" "$ST"; do
  grep -q '=== gcc Summary' "$f" || { echo "FATAL: $f truncated"; exit 9; }
done
TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0
key () {
  sed -n 's/^\(PASS\|FAIL\|XPASS\|XFAIL\|UNSUPPORTED\|UNRESOLVED\|ERROR\): \(.*\)$/\1\t\2/p' "$1" \
  | awk -F'\t' '{ n[$2]++; printf "%s#%d\t%s\n", $2, n[$2], $1 }' | sort -t"$(printf '\t')" -k1,1
}
key "$MT" > "$TD/mt"; key "$ST" > "$TD/st"
join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 "$TD/st" "$TD/mt" > "$TD/j"
awk -F'\t' '$2=="PASS" && $3!="PASS" { print $1 }' "$TD/j" > "$TD/reg"
TOT=$(wc -l < "$TD/reg")
[ "$TOT" -gt 0 ] || { echo "FATAL: empty debt -- nothing to group"; exit 9; }
echo "total debt: $TOT"
acc=0
for p in "$@"; do
  n=$(grep -c -- "$p" "$TD/reg" || true)
  acc=$((acc+n))
  printf '%8d  %s\n' "$n" "$p"
done
# The REMAINDER is printed, always.  A family list that accounts for 40% of the
# debt while looking like a complete explanation is this project's own
# over-attribution failure; the leftover row makes it impossible to read that
# way.  (Patterns may overlap, so the sum can exceed the total -- said here
# rather than silently.)
printf '%8d  <-- sum of the patterns above (they may overlap)\n' "$acc"
printf '%8d  <-- debt matched by NONE of them\n' \
  "$(grep -v -e "$(printf '%s\\|' "$@" | sed 's/\\|$//')" "$TD/reg" | wc -l)"
