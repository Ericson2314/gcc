#!/bin/sh
# #121 -- run cc1's selftests ONCE PER BASE and report what each base fails on.
#
# This is the arm the whole task exists for.  `gcc/Makefile.in' already has the
# plumbing (SELFTEST_TARGET_CONFIG, GCC_FOR_SELFTESTS, selftest-driver.sh), but
# nothing has ever produced a `specs-<target>-config' in a build dir, so every
# `make all-gcc' on this branch has run the selftests with NO target selected.
# Here the config is passed to cc1 directly, so the tests run FOR A TARGET.
#
# THE PREDICTION UNDER TEST, stated before running so the result can refute it:
#
#   `test_scalar_ops' (simplify-rtx.cc:9376) walks 0 .. NUM_MACHINE_MODES by
#   RAW INDEX and tests everything SCALAR_INT_MODE_P.  A mode the SELECTED base
#   does not define is a hole with precision 0 -- but it keeps the shared
#   numbering's CLASS, so it is scalar-int here.  So each base must fail on a
#   mode IT LACKS, and the failing mode must differ between bases:
#
#     i386 selected     -> CI                       (its only MODE_INT hole)
#     aarch64 selected  -> P2QI / P2HI / POI        (i386's partial int modes)
#     riscv selected    -> CI / XI / P2QI / P2HI / POI
#
#   The competing account on record (STATE.md section 4b) is that CImode is
#   aarch64's 768-bit mode and constant folding bails out above
#   MAX_BITSIZE_MODE_ANY_INT.  That story predicts the failure follows CImode
#   -- so it predicts aarch64 fails on CI too, and that the width is too LARGE.
#   The aarch64 run is therefore the discriminator, and a CI failure under
#   aarch64 refutes THIS script's prediction, not that one.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b-abeb4d62}
CC1=$B/gcc/cc1

test -x "$CC1" || { echo "FATAL: no $CC1"; exit 9; }

# The selftests abort at the FIRST failing assertion (selftest-rtl.cc:57 calls
# abort()), so each run names ONE mode.  That is a property of the harness and
# is reported as such rather than being read as "one failure per base".
run_one () {
  t=$1
  cfg=$(ls "$B"/gcc/specs-"$t"-config "$B"/target-specs-"$t"/specs-config 2>/dev/null | head -1)
  if test -z "$cfg"; then
    echo "=== $t: NO CONFIG FOUND -- skipping, and this is a SKIP not a pass"
    return
  fi
  echo "=== $t   (config $cfg)"
  "$CC1" -ftarget-config="$cfg" -nostdinc /dev/null -S -o /dev/null \
    -fself-test="$SRC/gcc/testsuite/selftests" > "/tmp/t121-st-$t.out" 2>&1
  rc=$?
  echo "  rc=$rc"
  # Name the failing assertion and the mode, not just the count.
  grep -E "FAIL:|expected:|actual:|internal compiler error|:[0-9]+: [a-z_]+:" \
    "/tmp/t121-st-$t.out" | head -12 | sed 's/^/  /'
  if [ "$rc" = 0 ]; then
    echo "  PASSED -- but check it tested something: a run that selected no"
    echo "  target also exits 0 having exercised nothing."
  fi
}

for t in "$@"; do run_one "$t"; done
