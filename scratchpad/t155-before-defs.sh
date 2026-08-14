#!/bin/sh
# #155 -- THE BEFORE ARM, SCORED AS DEFINITIONS, WITHOUT NEEDING A LINK.
#
# The point of scoring definitions rather than the linker's complaints:
#
#   * `nm -u' reads IDENTICALLY before and after a rename fix -- the reference
#     is still there, it merely resolves -- and it has fooled an agent here.
#   * `ld' is an UNDER-count.  libbackend.a is an ARCHIVE, so a duplicate is
#     diagnosed only when both members happen to be pulled in for other
#     reasons; it once reported 7 of 40.  Never size this set with the linker.
#
# So this reads the OBJECTS of an UNFIXED tree and reports, per name, how many
# bases define it bare.  It needs no cc1 and no successful link, which matters
# because the unfixed tree cannot produce one -- that is the defect.
#
# usage: t155-before-defs.sh <unfixed-builddir> <base>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}; shift
[ $# -ge 2 ] || { echo "FATAL: need at least 2 bases"; exit 9; }
case "$B" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
w=$(mktemp -d)

echo "== arm 0: NON-VACUITY (a base with no objects is ABSENT, not clean)"
tot=0
for b in "$@"; do
  n=$(ls "$G/mt-$b"/*.o 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] || { echo "  REFUSING TO SCORE: base $b has no objects"; exit 9; }
  sh "$S/eb-shell.sh" "cd $G && nm --defined-only mt-$b/*.o" 2>/dev/null \
    | awk '$2 ~ /^[TDBR]$/ { print $3 }' | sort -u > "$w/$b.txt"
  d=$(grep -c . "$w/$b.txt" || true)
  printf '  %-10s %2d objects, %5d global definitions\n' "$b" "$n" "$d"
  tot=$((tot + d))
done
# A tool not on PATH pipes into grep -c as 0, in the direction that makes the
# answer look correct.
[ "$tot" -gt 0 ] || { echo "REFUSING TO SCORE: nm read nothing"; exit 9; }

echo
echo "== names defined BARE by more than one base (each is a hard link failure)"
for b in "$@"; do sed "s/\$/ $b/" "$w/$b.txt"; done \
  | awk '{ c[$1]++; d[$1] = d[$1] " " $2 }
         END { for (n in c) if (c[n] > 1) printf "%d %s %s\n", c[n], n, d[n] }' \
  | sort -rn -k1 > "$w/collide.txt"
echo "  $(grep -c . "$w/collide.txt" || true) colliding names"
sed 's/^/    /' "$w/collide.txt"
rm -rf "$w"
