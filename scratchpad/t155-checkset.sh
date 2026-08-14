#!/bin/sh
# #155 -- for a PROPOSED base set, list every hand-written collision within it
# and say whether each is covered by MULTI_TARGET_RENAME_NAMES.
#
# t155-pick.sh scores each candidate against the CORE only.  That is not the
# same question: two candidates can be individually usable and collide with
# EACH OTHER.  This checks the set as a whole, which is the thing actually
# being built.
#
# usage: t155-checkset.sh <collide-hand.txt> <base>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
C=${1:?collide file}; shift
[ $# -ge 2 ] || { echo "FATAL: need at least 2 bases"; exit 9; }
M=$(cd "$S/../gcc" && pwd)/Makefile.in
[ -s "$C" ] || { echo "REFUSING TO SCORE: $C missing or empty"; exit 9; }

awk '/^MULTI_TARGET_RENAME_NAMES = /,/[^\\]$/' "$M" \
  | sed 's/^MULTI_TARGET_RENAME_NAMES = //; s/\\$//' \
  | tr -s ' \t' '\n' | grep . | sort -u > /tmp/t155-ren.txt
nr=$(grep -c . /tmp/t155-ren.txt)
[ "$nr" -gt 5 ] || { echo "REFUSING TO SCORE: parsed only $nr rename names"; exit 9; }
echo "set: $*   ($nr rename names)"

nblk=0; nren=0
grep -v mt_probe "$C" > /tmp/t155-ch.txt
while read -r line; do
  sym=$(echo "$line" | awk '{print $2}')
  bases=$(echo "$line" | cut -d' ' -f3-)
  # How many of the PROPOSED bases define this name?
  k=0; who=""
  for b in "$@"; do
    if echo "$bases" | grep -qw "$b"; then k=$((k+1)); who="$who $b"; fi
  done
  [ "$k" -ge 2 ] || continue      # not a collision WITHIN this set
  n=$(echo "$sym" | sh "$S/eb-shell.sh" "c++filt" 2>/dev/null | sed 's/(.*//; s/.*:://')
  [ -n "$n" ] || n=$sym
  if grep -qx "$n" /tmp/t155-ren.txt; then
    echo "  RENAMED  $n  --$who"; nren=$((nren+1))
  else
    echo "  BLOCKING $n  --$who"; nblk=$((nblk+1))
  fi
done < /tmp/t155-ch.txt

echo
echo "  $nren covered by the rename list, $nblk blocking"
# NON-VACUITY: a set with no collisions at all is a CONTROL, not an arm -- it
# would link before and after and demonstrate nothing about the fix.
if [ "$nren" = 0 ] && [ "$nblk" = 0 ]; then
  echo "  WARNING: this set has NO collisions even unfixed, so it is a control"
  echo "  and not evidence for the fix."
fi
[ "$nblk" = 0 ] || exit 1
