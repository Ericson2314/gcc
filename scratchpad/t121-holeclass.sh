#!/bin/sh
# #121 -- THE FINDING TABLE: for each base, how many modes are HOLES (present in
# the shared numbering because another configured back end defines them, absent
# from this base) and what CLASS this base's own mode_class table gives them.
#
# The class is the whole point.  A hole gets precision 0, size 0 and nunits 0 --
# an answer that is wrong in a way that shows -- but genmodes.cc:1619 sets
# `m->cl = c', so the hole KEEPS THE SHARED NUMBERING'S CLASS.  Every predicate
# in machmode.h is written on GET_MODE_CLASS alone:
#
#   SCALAR_INT_MODE_P (M)   GET_MODE_CLASS (M) == MODE_INT || == MODE_PARTIAL_INT
#   VECTOR_MODE_P (M)       GET_MODE_CLASS (M) == MODE_VECTOR_*
#
# so target-independent code that walks `0 .. NUM_MACHINE_MODES' by raw index --
# rather than through FOR_EACH_MODE*, which stays dense over the base's own
# modes and never enters a hole -- accepts a foreign mode as a usable scalar
# integer or vector of width ZERO.  The counts below are the size of that
# exposure, per base, per class.
#
# Read from the generated artefacts, not re-derived: the hole tag is genmodes'
# own (`<unknown>:0' in the per-base enum, versus the .def file and line for a
# real mode), and the class is the row of this base's own mode_class table
# found by its `/* <mode> */' tag rather than by counting commas.
set -u
D=${1:-/tmp/b-abeb4d62}

any=0
for f in "$D"/gcc/mt-*/insn-modes-*.cc; do
  test -f "$f" || continue
  b=$(basename "$f" .cc); b=${b#insn-modes-}
  h="$D/gcc/insn-modes-$b.h"
  test -f "$h" || { echo "FATAL: no $h to read hole tags from"; exit 9; }
  any=$((any + 1))

  # Hole names, from the per-base enum.  Mode names contain `_' (CC_NZC), so
  # the character class must say so -- an earlier version of this script used
  # [A-Za-z0-9] and silently emitted the raw enum line for eight aarch64 CC
  # modes instead of their names.
  # LC_ALL=C throughout: `join' silently DROPS rows whose inputs disagree about
  # collation, and mode names contain `_', which sorts differently under a
  # non-C locale.  Measured: the first version of this script lost 1 hole in
  # i386, 1 in aarch64 and 3 in riscv that way, and reported the reduced number
  # as the answer -- an undercount in the direction that makes the exposure
  # look smaller.  `join' does warn, but only on stderr and not per row.
  sed -n 's/^  E_\([A-Za-z0-9_]*\)mode,.*<unknown>:0.*/\1/p' "$h" \
    | LC_ALL=C sort -u > "/tmp/t121-holes-$b.txt"

  # The mode_class table only, by name, so the class can be attributed.
  awk '/^const unsigned char mode_class_tab/ { on = 1; next }
       on && /^};/ { on = 0 }
       on && match($0, /\/\* [A-Za-z0-9_]+ \*\//) {
         cls = $1; sub(/,$/, "", cls)
         nm = substr($0, RSTART + 3, RLENGTH - 6)
         print nm, cls
       }' "$f" | LC_ALL=C sort > "/tmp/t121-class-$b.txt"

  nh=$(wc -l < "/tmp/t121-holes-$b.txt")
  [ "$nh" -gt 0 ] || { echo "FATAL: $b scored 0 holes -- refusing to report that as 'no holes'"; exit 9; }

  echo "=== $b: $nh holes"
  join "/tmp/t121-holes-$b.txt" "/tmp/t121-class-$b.txt" \
    > "/tmp/t121-holeclass-$b.txt"
  nj=$(wc -l < "/tmp/t121-holeclass-$b.txt")
  # Every hole must find its class row.  A shortfall means `join' dropped rows,
  # which silently UNDERSTATES the exposure -- so it is fatal, not a warning.
  [ "$nj" = "$nh" ] || { echo "FATAL: only $nj of $nh $b holes found a mode_class row"; exit 9; }
  awk '{ c[$2]++ } END { for (k in c) printf "  %-24s %d\n", k, c[k] }' \
    "/tmp/t121-holeclass-$b.txt" | sort -k2 -nr

  # The two classes that shared code's raw-index walks actually test on.
  si=$(awk '$2 == "MODE_INT" || $2 == "MODE_PARTIAL_INT"' "/tmp/t121-holeclass-$b.txt" | wc -l)
  vp=$(awk '$2 ~ /^MODE_VECTOR_/' "/tmp/t121-holeclass-$b.txt" | wc -l)
  echo "  -> SCALAR_INT_MODE_P is TRUE for $si modes this base does not have"
  echo "  -> VECTOR_MODE_P     is TRUE for $vp modes this base does not have"
done

[ "$any" -gt 0 ] || { echo "FATAL: read no per-base mode tables at all"; exit 9; }
