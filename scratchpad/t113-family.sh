#!/bin/sh
# TASK #113 -- is any member of the move/clear family an EXISTENCE predicate?
#
# This decides the SHAPE of the conversion, so it is measured rather than
# assumed.  If every back end defines a member (directly or through a
# defaults.h floor that is evaluated in the back end's OWN translation unit)
# then the field is a plain value thunk.  If some back end has none and there
# is no floor, the field needs the three-state `has_' flag that INIT_EXPANDERS
# has -- because then "absent" is a real answer and must not be spelled as a
# null pointer that could equally mean a stale object.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098
G=$W/gcc
cd "$G" || exit 9
tot=$(ls config/*/*.h | wc -l)
echo "back-end headers scanned: $tot  (a header count, NOT a back-end count)"
for m in MOVE_MAX MOVE_MAX_PIECES STORE_MAX_PIECES COMPARE_MAX_PIECES \
         MOVE_RATIO CLEAR_RATIO SET_RATIO MAX_MOVE_MAX; do
  n=$(grep -lE "^[ 	]*#[ 	]*define[ 	]+$m\b" config/*/*.h | wc -l)
  f=$(grep -cE "^[ 	]*#[ 	]*ifndef[ 	]+$m[ 	]*$" defaults.h)
  echo "$m: defined in $n back-end headers; defaults.h floor: $f"
done
echo
echo "=== back ends (cpu dirs) with NO MOVE_MAX definition anywhere in their dir"
for d in config/*/; do
  ls "$d"*.h > /dev/null 2>&1 || continue
  grep -lE "^[ 	]*#[ 	]*define[ 	]+MOVE_MAX\b" "$d"*.h > /dev/null 2>&1 \
    || echo "  $d"
done
