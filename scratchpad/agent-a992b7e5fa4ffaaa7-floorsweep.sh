#!/bin/sh
# floorsweep.sh -- the class `TARGET_HAS_FMV_TARGET_ATTRIBUTE' belongs to:
# a `#ifndef' FLOOR in `defaults.h' whose name SOME BACK END defines.
#
# WHY THIS CLASS, AND WHY IT IS NOT THE ONE THE EXISTING SWEEPS COVER.
#
# This branch's recorded floor defect (`EPILOGUE_USES', `REGMODE_NATURAL_SIZE',
# `JUMP_TABLES_IN_TEXT_SECTION') is: **the primary defines the name**, so
# `defaults.h''s `#ifndef' is DEAD and every shared consumer gets i386's body.
#
# `TARGET_HAS_FMV_TARGET_ATTRIBUTE' is the INVERSE and it is a live wrong-code
# bug worth 256 results on aarch64: **i386 defines nothing**, so the floor
# FIRES, and the floor's value is correct for the 46 back ends that say nothing
# and WRONG for the one that dissents.  aarch64 wants 0 and reads 1.
#
# So "i386 does not define it" is not the absence of a leak; it is the
# precondition for this variant.  Both variants have the same enumerable
# generator -- a floor whose name any back end defines -- and this script emits
# the whole set, split by which variant each member is in, because the two need
# different fixes and different evidence.
#
# WHY AN `#ifdef'-SHAPED SWEEP CANNOT SEE THE SECOND VARIANT.  Its consumers
# are runtime `if's and `&&' operands on a 0/1 VALUED macro (nineteen sites for
# the FMV one), exactly as `d1ae5fb5969' records for `DELAY_SLOTS'.  A scan for
# `#ifdef <name>' scores every one of them clean.  This script keys on the
# DEFINITION side instead, where the fact is visible.
#
# IT IS DELIBERATELY OVER-BROAD, per PRINCIPLES 4: "when an instrument can only
# take away, make it too eager".  It can only ever ADD a candidate to a review
# queue, never authorise a deletion, so a false positive costs a reading and a
# false negative costs a wrong-code bug.  It does NOT decide whether a member
# is a real leak -- a name may be genuinely target-neutral, or already
# converted to cdata elsewhere -- and it says so per row rather than implying a
# verdict.
#
# usage: floorsweep.sh <srcdir>
set -eu
export LC_ALL=C
SRC=${1:?srcdir (a snapshot or worktree gcc/ parent)}
D="$SRC/gcc/defaults.h"
[ -f "$D" ] || { echo "FATAL: no $D"; exit 9; }
CFG="$SRC/gcc/config"
[ -d "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

# 1. every name `defaults.h' floors with `#ifndef'.
sed -n 's/^#ifndef[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' "$D" | sort -u > "$TD/floors"
NFLOOR=$(grep -c . "$TD/floors" || true)

# NON-VACUITY.  An empty floor list and a clean sweep are the same output
# through a counting pipe (PRINCIPLES 4), so refuse rather than report zero.
[ "$NFLOOR" -gt 20 ] || { echo "FATAL: only $NFLOOR floors found in $D -- the sed did not match. REFUSING."; exit 9; }

# 2. every name any back end `#define's, with its definers.
#    Word-anchored: `grep "define PRINT_OPERAND"' also matches
#    `PRINT_OPERAND_ADDRESS', which took one macro 19 definers -> 14.
grep -rhn '^[ \t]*#[ \t]*define[ \t]\+[A-Za-z_][A-Za-z_0-9]*' "$CFG" 2>/dev/null \
  | sed -n 's/^[0-9]*:[ \t]*#[ \t]*define[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' \
  | sort -u > "$TD/defined"

# 3. the intersection is the class.
comm -12 "$TD/floors" "$TD/defined" > "$TD/class"
NCLASS=$(grep -c . "$TD/class" || true)

echo "defaults.h floors: $NFLOOR"
echo "names defined anywhere under config/: $(grep -c . "$TD/defined")"
echo "THE CLASS (floored AND defined by some back end): $NCLASS"
echo

# CONTROL, so a silent regression in the pipeline is visible: the known member
# must be present.  If this row is absent the sweep is broken, not clean.
if grep -qx 'TARGET_HAS_FMV_TARGET_ATTRIBUTE' "$TD/class"; then
  echo "CONTROL ok: TARGET_HAS_FMV_TARGET_ATTRIBUTE is in the class"
else
  echo "FATAL: the known member TARGET_HAS_FMV_TARGET_ATTRIBUTE is NOT in the class."
  echo "  The sweep is broken; a clean result here would be a false green."
  exit 9
fi
echo

printf '%-44s %-7s %-9s %s\n' NAME DEFINERS I386? VARIANT
while read -r n; do
  [ -n "$n" ] || continue
  defs=$(grep -rlw --include='*.h' "^[ \t]*#[ \t]*define[ \t]\+$n\b" "$CFG" 2>/dev/null \
         | sed "s|^$CFG/||" | sort || true)
  ndef=$(printf '%s\n' "$defs" | grep -c . || true)
  if printf '%s\n' "$defs" | grep -q '^i386/'; then
    i386=yes
    # The primary defines it => the floor is DEAD => every shared consumer
    # reads i386's body.  The recorded variant.
    var="FLOOR-DEAD (primary answers for all)"
  else
    i386=no
    # The primary is silent => the floor FIRES => the dissenting back ends read
    # the floor's value.  The FMV variant.
    var="FLOOR-FIRES (dissenters read the floor)"
  fi
  printf '%-44s %-7s %-9s %s\n' "$n" "$ndef" "$i386" "$var"
done < "$TD/class"

echo
echo "NOTE: membership is a CANDIDATE, not a verdict.  A name may be genuinely"
echo "target-neutral, or already converted to cdata with the floor left inert."
echo "Each row needs the both-sided header read (-DIN_GCC, shared tm.h vs"
echo "<base>-inc/tm.h) before it is called a leak -- WITHOUT -DIN_GCC the whole"
echo "back-end chain is skipped and every arm reads the floor, which refutes"
echo "every finding at once."
