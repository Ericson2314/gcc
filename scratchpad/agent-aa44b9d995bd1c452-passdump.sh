#!/bin/sh
# WHICH TARGET PASSES ARE IN THE TREE, AND ON, FOR A GIVEN TARGET.
#
# `-fdump-passes' is the instrument PRINCIPLES names for this: it distinguishes
# a pass being ABSENT from the pass list from a pass being present and OFF,
# which a generated file cannot.  That distinction is the whole question here --
# the defect is a pass PRESENT and ON for a back end that does not own it.
#
# Run against PRE and POST for the same target and the same input.  A pass
# owned by another back end must be gone from the ON column in POST.
#
# Non-vacuity: `-fdump-passes' must produce SOME output, and the target's own
# name must appear in the pass list somewhere, or the script exits 9.  An empty
# dump and "no foreign passes are on" are otherwise the same text.
set -u
B=${1:?build dir}
T=${2:?target triple}
IN=${3:?input .c}
FLAGS=${4:--O2}
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
CFG="$B/lib/gcc/$VER/$T/specs-config"
[ -f "$CFG" ] || { echo "FATAL: no specs-config for $T in $B"; exit 9; }

D=$(mktemp -d)
"$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" $FLAGS -fdump-passes \
    -S -o /dev/null "$IN" > "$D/out" 2>&1
n=$(grep -c '_mt_' "$D/out" || true)
if [ "$(wc -c < "$D/out")" -lt 100 ]; then
  echo "FATAL: -fdump-passes produced almost nothing for $T:"; cat "$D/out"
  rm -rf "$D"; exit 9
fi
echo "== $B  $T  $FLAGS   ($n target-pass lines)"
grep '_mt_' "$D/out" | sed 's/^ *//' | sort -u
rm -rf "$D"
[ "$n" -gt 0 ] || { echo "FATAL: not one '_mt_' pass in the dump -- the"; \
  echo "  per-back-end pass machinery is absent, so 'no foreign pass is on'"; \
  echo "  would be vacuous."; exit 9; }
