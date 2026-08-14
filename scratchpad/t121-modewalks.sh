#!/bin/sh
# #121 -- THE SIZE OF THE REMAINING WORK.
#
# The `MODE_RANDOM'-for-holes fix in genmodes.cc is correct and is NOT landed,
# because it converts a large population of SILENT wrong answers into ICEs all
# at once, and one of them (`init_expmed', which runs on every compilation)
# takes ordinary compilation down with it.  This counts the sites that have to
# be converted first, so the next agent gets a population rather than a wall.
#
# The pattern: shared, target-independent code that walks modes BY ORDINAL
# rather than through `FOR_EACH_MODE*'.  `FOR_EACH_MODE*' follows `mode_next',
# which stays dense over the selected base's own modes and never enters a hole.
# An ordinal walk does enter holes, because `MIN_MODE_<CLASS>' and
# `MAX_MODE_<CLASS>' are the SHARED NUMBERING's bounds -- they span every
# configured back end's modes, not this one's.
#
# Two shapes are counted separately because they need different fixes:
#
#   A  `for (i = 0; i < NUM_MACHINE_MODES; ++i)' plus a class predicate.
#      These are mostly fine ONCE holes are MODE_RANDOM: the predicate stops
#      rejecting nothing and starts rejecting holes.  They are the sites the
#      fix REPAIRS.
#
#   B  `for (mode = MIN_MODE_<CLASS>; mode <= MAX_MODE_<CLASS>; mode++)'.
#      These have no class predicate at all -- the bounds ARE the predicate --
#      so with holes reclassified they walk straight into a hole and whatever
#      they call next sees a mode of a class it did not expect.  These are the
#      sites the fix BREAKS, and they are the work.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
G=$SRC/gcc

test -d "$G" || { echo "FATAL: no $G"; exit 9; }

# Shared code only: anything under config/ is per-base and legitimately knows
# its own modes.
find_shared () {
  find "$G" -maxdepth 2 -name '*.cc' -o -maxdepth 2 -name '*.h' \
    | grep -v "/config/" | grep -v "/testsuite/" | LC_ALL=C sort
}

n=$(find_shared | wc -l)
[ "$n" -gt 100 ] || { echo "FATAL: only $n shared sources found; the search is wrong, and an undercount here reads as 'few sites'"; exit 9; }
echo "scanning $n shared sources"

echo
echo "=== SHAPE B -- ordinal range walks over a class (the work)"
find_shared | while IFS= read -r f; do
  grep -Hn 'MIN_MODE_[A-Z_]*;.*<=.*MAX_MODE_[A-Z_]*' "$f" 2>/dev/null
done | sed "s,$G/,,"

echo
echo "=== SHAPE B count"
find_shared | while IFS= read -r f; do
  grep -h 'MIN_MODE_[A-Z_]*;.*<=.*MAX_MODE_[A-Z_]*' "$f" 2>/dev/null
done | wc -l

echo
echo "=== SHAPE A -- raw 0..NUM_MACHINE_MODES walks (repaired by the fix)"
find_shared | while IFS= read -r f; do
  grep -Hn '< *NUM_MACHINE_MODES' "$f" 2>/dev/null
done | sed "s,$G/,," | head -40

echo
echo "=== SHAPE A count"
find_shared | while IFS= read -r f; do
  grep -h '< *NUM_MACHINE_MODES' "$f" 2>/dev/null
done | wc -l
