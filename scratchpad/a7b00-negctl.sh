#!/bin/sh
# ACCEPTANCE ARM 2, THE NEGATIVE CONTROL.  Move the installed per-target header
# directory away and rebuild: it must FAIL, BY NAME.  If it still succeeds,
# something else is satisfying the include and this task's change is not doing
# the work.
#
# TWO STAGES, because they can fail independently and only one of them is what
# the arm is about:
#   1. CONFIGURE must refuse -- libgcc/configure checks $incdir/tm.h exists.
#   2. With the directory restored but ONE header removed, the BUILD must fail
#      naming that header.  Stage 1 alone would pass even if -I were pointing
#      somewhere harmless, because it never compiles anything.
set -u
I=${1:?installed per-target include dir}
D=${2:?a configured standalone libgcc build dir}
PFX=${3:?install prefix}; T=${4:?triple}; TOOLS=${5:?tools bin}
SRCDIR=$(cd "$(dirname "$0")/../libgcc" && pwd)
export PATH="$PFX/bin:$TOOLS:$PATH"

[ -d "$I" ] || { echo "FATAL: $I is not there to begin with"; exit 9; }
SAVE=$I.saved-by-negctl
rm -rf "$SAVE"; mv "$I" "$SAVE"
restore () { rm -rf "$I"; mv "$SAVE" "$I"; }
trap 'restore' EXIT INT TERM

echo "=== stage 1: whole directory gone; configure must refuse"
N=$D-neg
rm -rf "$N"; mkdir -p "$N"
( cd "$N" && "$SRCDIR/configure" --host="$T" \
    --build="$(sh "$SRCDIR/../config.guess")" --prefix="$PFX" \
    CC="$T-gcc" AR="$T-ar" RANLIB="$T-ranlib" NM="$T-nm" \
    CFLAGS="${NEG_CFLAGS:--O2}" ) > "$N/conf.out" 2> "$N/conf.err"
rc=$?
echo "configure rc=$rc  (must be non-zero)"
if [ "$rc" = 0 ]; then
  echo "FAIL: configure succeeded with no per-target headers installed."
  exit 1
fi
echo "--- it said:"
grep -A6 -m1 'error:' "$N/conf.out" "$N/conf.err" | sed 's/^/    /' | head -12

echo
echo "=== stage 2: directory back, ONE header removed; the BUILD must name it"
restore; trap - EXIT INT TERM
[ -f "$I/tm.h" ] || { echo "FATAL: restore failed"; exit 9; }
mv "$I/insn-modes.h" "$I/.insn-modes.h.hidden"
back2 () { mv "$I/.insn-modes.h.hidden" "$I/insn-modes.h"; }
trap 'back2' EXIT INT TERM
( cd "$D" && make -j8 ${MT_MAKEVARS:-} _muldi3.o ) > "$D/neg2.out" 2> "$D/neg2.err"
rc2=$?
echo "make rc=$rc2  (must be non-zero)"
grep -m3 -E 'insn-modes\.h|No such file' "$D/neg2.err" | sed 's/^/    /'
back2; trap - EXIT INT TERM
if [ "$rc2" = 0 ]; then
  echo "FAIL: the object built with insn-modes.h removed from the installed"
  echo "  directory, so it is being satisfied from somewhere else."
  exit 1
fi
grep -q 'insn-modes\.h' "$D/neg2.err" || {
  echo "FAIL: the build failed but did NOT name insn-modes.h."; exit 1; }
echo
echo "PASS: both stages failed, and stage 2 failed BY NAME."
