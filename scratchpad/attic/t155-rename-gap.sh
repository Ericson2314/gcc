#!/bin/sh
# #155 -- IS `MULTI_TARGET_RENAME_NAMES' COMPLETE FOR N BASES?
#
# The N-way successor to scratchpad/t150-rename-gap.sh, which is itself the
# successor to the `scratchpad/sweep.sh' that gcc/Makefile.in names as its
# authority and that DID NOT EXIST.  Three things are different here:
#
#   1. t150-rename-gap.sh refuses any build dir not named for the worktree that
#      wrote it, so it cannot be run at all from another agent's tree.  That
#      guard is right and is the reason for this copy rather than an edit --
#      editing it would repoint an instrument whose past readings someone may
#      still be relying on.  (PRINCIPLES: leave a superseded instrument in
#      place unmodified so the two readings can be compared.)
#
#   2. It sweeps only mt-<base>/*.o -- the hand-written config/ sources.  This
#      one ALSO sweeps the generated insn-*-<base>.o and target-*-<base>.o,
#      because "the generated code is already namespaced" is a written
#      invariant and a written invariant is not a checked one.  The two
#      populations are reported SEPARATELY, so a collision appearing in the
#      generated set is visible as the different (and worse) finding it is
#      rather than being averaged into the hand-written count.
#
#   3. It reports, for each colliding name, HOW MANY BASES define it and WHICH.
#      A name in three bases and a name in two are the same line to `uniq -d'
#      and are not the same problem.
#
# BLIND SPOTS, stated because a clean result from an instrument with unexamined
# ones is worth very little:
#   * WEAK/COMDAT symbols are excluded by the T/D/B/R filter.  A strong-symbol
#     sweep on this branch has already hidden a COMDAT defect (`optab_handler').
#     This script cannot see that class.
#   * It sees only back ends that COMPILED.  Under `make -k' a base that never
#     built contributes no symbols, which reads identically to a base that
#     collides with nothing.  Arm 0 therefore prints the per-base definition
#     counts, and a base showing 0 is called out rather than summed away.
#   * A macro expanding to option state (global_options.x_*) is invisible to
#     nm by construction.  That is a different bug class, not this one.
#
# usage: t155-rename-gap.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's|.*/mt-||')
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 2 ] || { echo "REFUSING TO SCORE: found $nb base dirs under $G"; exit 9; }
echo "arm 0: $nb configured bases"

work="$B/t155-rg"
rm -rf "$work"; mkdir -p "$work"
tot=0; empty=""
for b in $bases; do
  sh "$S/eb-shell.sh" "cd $G && nm --defined-only mt-$b/*.o" 2> "$work/$b.err" \
    | awk '$2 ~ /^[TDBR]$/ { print $3 }' | sort -u > "$work/hand-$b.txt"
  sh "$S/eb-shell.sh" "cd $G && nm --defined-only insn-*-$b*.o target-*-$b.o" 2> "$work/$b-gen.err" \
    | awk '$2 ~ /^[TDBR]$/ { print $3 }' | sort -u > "$work/gen-$b.txt"
  h=$(grep -c . "$work/hand-$b.txt" || true)
  g=$(grep -c . "$work/gen-$b.txt" || true)
  printf '  %-12s hand-written %5d   generated %5d\n' "$b" "$h" "$g"
  [ "$h" -gt 0 ] || empty="$empty $b"
  tot=$((tot + h + g))
done
# A tool that is not on PATH pipes into grep -c as 0 -- in the direction that
# makes the answer look correct.  Refuse rather than report a clean sweep.
[ "$tot" -gt 0 ] || { echo "REFUSING TO SCORE: nm read nothing (not in the dev shell?)"; exit 9; }
[ -z "$empty" ] || echo "  NOTE: these bases defined NOTHING hand-written, so they are"
[ -z "$empty" ] || echo "        ABSENT from the collision set rather than clean:$empty"

report () {
  what=$1; pat=$2
  echo
  echo "== $what: names defined by MORE THAN ONE base"
  for b in $bases; do sed "s/\$/ $b/" "$work/$pat-$b.txt"; done \
    | awk '{ c[$1]++; d[$1] = d[$1] " " $2 }
           END { for (n in c) if (c[n] > 1) printf "%3d %s %s\n", c[n], n, d[n] }' \
    | sort -rn > "$work/collide-$pat.txt"
  n=$(grep -c . "$work/collide-$pat.txt" || true)
  echo "  $n colliding names"
  head -80 "$work/collide-$pat.txt" | sed 's/^/    /'
}
report "HAND-WRITTEN config/ objects" hand
report "GENERATED per-base objects (expected: ZERO -- they are namespaced)" gen

echo
echo "NOTE: ld reports only the subset whose archive members are both pulled in"
echo "-- it once reported 7 of 40.  This sweep is the authority; the linker is"
echo "an UNDER-count of it.  Never size this set with the linker."
