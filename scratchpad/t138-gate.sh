#!/bin/sh
# #138 -- did moving reg-stack.cc out of the shared pile actually change WHO
# GETS THE PASS?
#
# Two arms, and neither is a byte count:
#
#   A. the `stack' pass DUMP EXISTS for x86_64 and DOES NOT for aarch64.
#      A gated-off pass writes no dump file, so the presence of
#      `<file>.<n>r.stack' is the gate's own testimony.  Before this change
#      the gate was `#ifdef STACK_REGS -> return true' answered by the
#      PRIMARY, so it was true for aarch64 too and the dump existed there.
#
#   B. x86_64 x87 CODEGEN IS STILL PRODUCED.  Arm A alone cannot tell "the
#      pass is now correctly gated" from "the pass no longer runs anywhere",
#      and the second is the far more likely way to get a green here: a null
#      `targetm_regstack' gates false, quietly, on every target.  So a
#      `long double' function must still come out with x87 stack registers
#      (%st) and hard-register numbering.
#
# $1 = build dir.  Both compilers come from the SAME build dir, which is the
# only way the two arms are comparable.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
G=$B/gcc
D=$B/t138-gate; rm -rf "$D"; mkdir -p "$D" || exit 9

[ "$(grep -c MULTI_TARGET "$G/Makefile")" -ge 39 ] || {
  echo "FATAL: $G is not a current multi-target build dir"; exit 9; }

cat > "$D/ld.c" <<'EOF'
long double f (long double a, long double b) { return a * b + a; }
EOF
cat > "$D/i.c" <<'EOF'
int g (int a) { return a + 1; }
EOF

rc=0
# `cd $G' and `./<driver>', not an absolute path from elsewhere: the driver
# finds cc1 relative to its own argv[0] directory, and invoking it as
# `$G/x86_64-...-gcc' from another cwd fails with
# `cannot execute cc1: posix_spawn: No such file or directory'.  Measured --
# the first run of this script hit exactly that, and every arm reported FAIL,
# which is what the ARM A vacuity guard is for: a harness that cannot compile
# anything must not be readable as "the pass is correctly gated off".
# -dumpdir puts the pass dumps in $D rather than in the build tree.
run () { # $1 driver, $2 src, $3 tag
  sh "$S/eb-shell.sh" \
     "cd $G && ./$1 -O2 -S -fdump-rtl-stack -dumpdir $D/ -o $D/$3.s $2" \
     > "$D/$3.out" 2> "$D/$3.err"
  echo $?
}

# --- arm A: who gets the pass -------------------------------------------
r1=$(run x86_64-pc-linux-gnu-gcc "$D/ld.c" x86ld)
r2=$(run aarch64-unknown-linux-gnu-gcc "$D/ld.c" a64ld)
echo "x86_64 long double rc=$r1   aarch64 long double rc=$r2"

x86dump=$(ls "$D"/*.stack 2>/dev/null | grep -c 'x86ld' || true)
a64dump=$(ls "$D"/*.stack 2>/dev/null | grep -c 'a64ld' || true)
ls "$D"/*.stack 2>/dev/null || echo "(no .stack dumps at all)"

# NON-VACUITY.  If NOTHING produced a dump the two counts are both 0 and the
# arm reads green for the wrong reason -- "correctly gated off" and "the pass
# is dead everywhere" are the same picture.  Refuse to score that.
if [ "$x86dump" -eq 0 ]; then
  echo "ARM A: FATAL-VACUOUS: x86_64 produced no 'stack' dump either."
  echo "  Either the pass is now off for EVERY target (a null targetm_regstack"
  echo "  gates false quietly) or -fdump-rtl-stack did not run at all."
  rc=9
elif [ "$a64dump" -ne 0 ]; then
  echo "ARM A: FAIL: aarch64 still runs the '*stack_regs' pass."
  rc=1
else
  echo "ARM A: PASS: x86_64 runs '*stack_regs', aarch64 does not."
fi

# --- arm B: x87 codegen on x86_64 -----------------------------------------
# NOT A COUNT.  The first draft of this arm asserted `at least 3 lines
# mentioning %st' and FAILED on correct output, which has exactly two -- a
# threshold calibrated on a number nobody had measured, the defect PRINCIPLES
# names.  It asserts on the CONTENT instead, by name: `%st(1)' is
# stack-RELATIVE numbering, which is the thing the `stack' pass produces and
# which cannot appear in output the pass did not touch.
missing=
for tok in 'fldt' 'fmul' 'faddp' '%st(1)'; do
  grep -qF -- "$tok" "$D/x86ld.s" || missing="$missing $tok"
done
if [ -n "$missing" ]; then
  echo "ARM B: FAIL: x86_64 long double output lacks:$missing"
  cat "$D/x86ld.s"
  rc=1
else
  echo "ARM B: PASS: x86_64 emits x87 with stack-relative numbering (fldt/fmul/faddp/%st(1))."
fi

# --- arm C: aarch64 still compiles, and to aarch64 -------------------------
r3=$(run aarch64-unknown-linux-gnu-gcc "$D/i.c" a64i)
if [ "$r3" != 0 ]; then
  echo "ARM C: FAIL: aarch64 int g(int) rc=$r3"; sed -n 1,20p "$D/a64i.err"; rc=1
# `grep -qF' on the operand text, NOT `add[ \t]*w0': `\t' inside an ERE bracket
# is the two characters backslash and t, so that pattern never matches a real
# tab -- and the arm reported FAIL on correct aarch64 output.  Same defect the
# #137 DEF column had.
elif grep -qF -- 'add	w0, w0, 1' "$D/a64i.s"; then
  echo "ARM C: PASS: aarch64 emitted 'add w0, w0, 1'."
else
  echo "ARM C: FAIL: aarch64 output is not what aarch64 should emit:"; cat "$D/a64i.s"; rc=1
fi

echo "OVERALL rc=$rc"
exit $rc
