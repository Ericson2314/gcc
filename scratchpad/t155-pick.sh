#!/bin/sh
# #155 -- PICK A BASE SET THAT TESTS THE FIX, rather than one that passes.
#
# i386 + aarch64 + rs6000 has ZERO hand-written collisions even in the UNFIXED
# tree, so it would link before and after and would demonstrate nothing.  A
# base set is only evidence if the fix is what makes the difference.
#
# So: for each candidate 4th base, report the names it collides on against
# {i386, aarch64, rs6000}, split into
#   RENAMED  -- in MULTI_TARGET_RENAME_NAMES, i.e. fixed by this task
#   BLOCKING -- not in the list, i.e. would still fail to link
# A candidate is usable exactly when BLOCKING is empty and RENAMED is not --
# the second half matters, or the set is a control rather than an arm.
set -u
S=$(cd "$(dirname "$0")" && pwd)
C=${1:?collide-hand.txt}
M=$(cd "$S/../gcc" && pwd)/Makefile.in
[ -s "$C" ] || { echo "REFUSING TO SCORE: $C missing or empty"; exit 9; }

awk '/^MULTI_TARGET_RENAME_NAMES = /,/[^\\]$/' "$M" \
  | sed 's/^MULTI_TARGET_RENAME_NAMES = //; s/\\$//' \
  | tr -s ' \t' '\n' | grep . | sort -u > /tmp/t155-ren.txt
nr=$(grep -c . /tmp/t155-ren.txt)
[ "$nr" -gt 5 ] || { echo "REFUSING TO SCORE: parsed only $nr rename names"; exit 9; }
echo "arm 0 ok: $nr rename names"

CORE="i386 aarch64 rs6000"
cands=$(awk '{for(i=3;i<=NF;i++) print $i}' "$C" | sort -u \
        | grep -vE '^(i386|aarch64|rs6000)$')

for b in $cands; do
  ren=""; blk=""
  # Every colliding line involving BOTH b and one of the core bases.
  while read -r line; do
    sym=$(echo "$line" | awk '{print $2}')
    bases=$(echo "$line" | cut -d' ' -f3-)
    echo "$bases" | grep -qw "$b" || continue
    hit=0
    for c in $CORE; do echo "$bases" | grep -qw "$c" && hit=1; done
    [ "$hit" = 1 ] || continue
    n=$(echo "$sym" | sh "$S/eb-shell.sh" "c++filt" 2>/dev/null | sed 's/(.*//; s/.*:://')
    [ -n "$n" ] || n=$sym
    if grep -qx "$n" /tmp/t155-ren.txt; then ren="$ren $n"; else blk="$blk $n"; fi
  done < "$(grep -v mt_probe "$C" > /tmp/t155-ch.txt; echo /tmp/t155-ch.txt)"
  [ -n "$ren$blk" ] || continue
  if [ -z "$blk" ]; then
    echo "USABLE   $b   renamed:$ren"
  else
    echo "blocked  $b   BLOCKING:$blk"
  fi
done
