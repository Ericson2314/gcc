#!/bin/sh
# #155 -- score a build log's LINK wall.  DEFINITIONS, not references.
#
# THE STAMP IS CHECKED FIRST AND THE SCRIPT REFUSES WITHOUT IT.  PRINCIPLES
# section 4: "A LOG BEING WRITTEN LOOKS EXACTLY LIKE A LOG THAT FINISHED."  An
# agent reported 13 -> 7 errors and withdrew both figures because neither build
# had completed.  A partial log is non-empty, contains real compile lines, and
# greps clean, so existence and non-emptiness cannot tell.  t155-build.sh writes
# <tag>.rc only after make RETURNS, and removes it first, so a killed build
# cannot leave a stale stamp.
#
# WHAT IS SCORED, AND WHY IT IS NOT `nm -u'.  `nm -u' reads IDENTICALLY before
# and after a rename fix -- the reference is still there, it merely resolves --
# and it has fooled an agent on this branch.  The two figures below are
#   * DISTINCT SYMBOL NAMES multiply defined, and
#   * how many BACK ENDS those names span,
# because 606 diagnostics once came from two back ends and a line count says
# nothing.
#
# usage: t155-score.sh <builddir> <tag>
set -u
D=${1:?build dir}
TAG=${2:?tag}
case "$D" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/$TAG.rc" ] || { echo "REFUSING TO SCORE: no $D/$TAG.rc -- the build did not return"; exit 9; }
L="$D/$TAG.err"
[ -f "$L" ] || { echo "REFUSING TO SCORE: no $L"; exit 9; }
echo "stamp: make rc=$(cat "$D/$TAG.rc")   log $(grep -c . "$L") lines"

# NON-VACUITY: a log with no compile/link activity at all scores zero of
# everything, which is the shape of success.  Require evidence it ran.
act=$(grep -c 'Entering directory\|Error\|error:\|warning:' "$L" || true)
[ "$act" -gt 0 ] || { echo "REFUSING TO SCORE: $L shows no activity"; exit 9; }

echo
echo "== multiple definition: DISTINCT NAMES (not lines)"
grep 'multiple definition of' "$L" \
  | sed "s/.*multiple definition of \`//; s/'.*//" | sort -u > "$D/$TAG.multdef"
nm=$(grep -c . "$D/$TAG.multdef" || true)
nl=$(grep -c 'multiple definition of' "$L" || true)
echo "  $nm distinct names over $nl diagnostic lines"

echo
echo "== which BACK ENDS those objects belong to"
# The object path carries the base: mt-<cpu>/x.o, insn-<x>-<cpu>.o,
# target-<x>-<cpu>.o.  Report back ends, never just lines -- 606 diagnostics
# once came from two back ends.
grep 'multiple definition of' "$L" \
  | grep -o 'mt-[a-z0-9_]*/' | sed 's|mt-||; s|/||' | sort | uniq -c | sort -rn
echo "  (blank above means no mt-<cpu>/ object appears; see the raw log)"

echo
echo "== undefined reference: DISTINCT NAMES (another agent's half; reported, not fixed)"
grep 'undefined reference to' "$L" \
  | sed "s/.*undefined reference to \`//; s/'.*//" | sort -u > "$D/$TAG.undef"
echo "  $(grep -c . "$D/$TAG.undef" || true) distinct names over $(grep -c 'undefined reference to' "$L" || true) lines"

echo
echo "== did cc1 link?"
if [ -x "$D/gcc/cc1" ]; then
  echo "  YES: $(ls -la "$D/gcc/cc1" | awk '{print $5}') bytes"
else
  echo "  NO"
fi
echo "== failing make targets (attribution: make's own lines, NEVER the nearest compile line)"
grep -c "\*\*\* \[" "$L" || true
