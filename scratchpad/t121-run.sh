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
  # cc1 is invoked DIRECTLY rather than through the driver, for two reasons.
  # It is the shortest path to "this cc1, this target config"; and the riscv
  # DRIVER currently segfaults (rc=139) reading its own generated `specs' file,
  # so going through it would make riscv unmeasurable for a reason that has
  # nothing to do with the selftests.  That segfault is a separate finding and
  # is recorded as one -- it is not worked around silently here.
  cfg=$(ls "$B"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if test -z "$cfg"; then
    echo "=== $t: NO CONFIG FOUND -- skipping, and this is a SKIP not a pass"
    return
  fi
  echo "=== $t   (config $cfg)"
  # NO `-S' here.  `gcc/Makefile.in's SELFTEST_FLAGS passes -S because it goes
  # through the DRIVER; cc1 rejects it ("valid for the driver but not for C")
  # and exits 1 having run no selftest at all.  That failure looks like a
  # selftest failure in the exit status and is not one -- worth stating,
  # because rc=1 from this script has to mean "a selftest failed".
  "$CC1" -ftarget-config="$cfg" -quiet -nostdinc /dev/null -o /dev/null \
    -fself-test="$SRC/gcc/testsuite/selftests" > "/tmp/t121-st-$t.out" 2>&1
  rc=$?
  echo "  rc=$rc"
  # Name the failing assertion and the mode, not just the count.
  grep -E "FAIL:|expected:|actual:|internal compiler error|:[0-9]+: [a-z_]+:" \
    "/tmp/t121-st-$t.out" | head -12 | sed 's/^/  /'
  # NON-VACUITY, and it is not optional.  A cc1 that selected no target also
  # exits 0 from -fself-test, having exercised nothing -- which is the false
  # green this whole task exists to remove.  The runner's dtor prints
  # "-fself-test: N pass(es)", so a green must show N, and N must be large.
  # The counts also DIFFER between bases (measured: aarch64 7677790, riscv
  # 8439208), which is itself evidence that each base is walking its own modes
  # rather than some shared vacuous set.
  passes=$(sed -n 's/.*-fself-test: \([0-9]*\) pass(es).*/\1/p' "/tmp/t121-st-$t.out")
  if [ "$rc" = 0 ]; then
    if [ -z "$passes" ]; then
      echo "  rc=0 BUT NO PASS COUNT WAS PRINTED -- this is NOT a pass."
      echo "  The selftests did not run.  Refusing to score it green."
    elif [ "$passes" -lt 1000000 ]; then
      echo "  rc=0 with only $passes passes -- suspiciously few; the suite"
      echo "  normally reports millions.  Treat as a partial run, not a pass."
    else
      echo "  PASSED: $passes assertions"
    fi
  fi
}

for t in "$@"; do run_one "$t"; done
