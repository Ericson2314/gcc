#!/bin/sh
# #121 -- census of MODE HOLES per base, and of the holes that shared code will
# nonetheless accept as scalar integer modes.
#
# A "hole" is a mode present in the SHARED mode numbering because some OTHER
# configured back end defines it, and absent from THIS base.  genmodes.cc
# already tags them in the generated per-base enum: a hole's comment is
# `<unknown>:0' where a real mode names the .def file and line that created it.
# That tag is the ground truth and is read here rather than re-derived.
#
# The second column is the finding.  A hole gets precision 0 and size 0, but it
# KEEPS THE SHARED NUMBERING'S CLASS (genmodes.cc:1619 `m->cl = c'), so
# SCALAR_INT_MODE_P is TRUE for a mode this base does not have.  Every such mode
# is one that target-independent code walking `0 .. NUM_MACHINE_MODES' will pick
# up and treat as a usable integer mode of width zero.
set -u
D=${1:-/tmp/b-abeb4d62}
G=$D/gcc

test -f "$G/insn-modes.h" || { echo "FATAL: no $G/insn-modes.h"; exit 9; }

for h in "$G"/insn-modes-*.h; do
  # `insn-modes-inline.h' and `insn-modes-inline-<base>.h' are not per-base
  # mode tables and must not be scored as a base with zero holes -- a zero
  # there reads exactly like "this base has no holes", which is the claim
  # under test.
  case $h in *insn-modes-inline*) continue;; esac
  b=$(basename "$h" .h); b=${b#insn-modes-}
  tot=$(grep -c '^  E_.*mode,' "$h")
  hol=$(grep -c '<unknown>:0' "$h")
  # The hole names, so a failure can be reported BY MODE NAME rather than by
  # a count (PRINCIPLES section 4: a check that cannot say WHICH thing
  # disagrees is most of a check).
  grep '<unknown>:0' "$h" | sed 's/^  E_\([A-Za-z0-9]*\)mode,.*/\1/' \
    | sort > "/tmp/t121-holes-$b.txt"
  echo "$b: $tot modes in the shared numbering, $hol are holes -> /tmp/t121-holes-$b.txt"
done

# Non-vacuity: if every file scored zero holes the loop above looks identical to
# "there are no holes", which is the reading this census exists to refute.
n=$(cat /tmp/t121-holes-*.txt 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "FATAL: scored 0 holes in every base -- refusing to report that as 'no holes'"; exit 9; }
echo "total hole slots across bases: $n"
