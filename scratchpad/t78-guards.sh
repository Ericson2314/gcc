#!/bin/sh
# #78 GUARDS -- the arms that must be able to FAIL, run against lto-wrapper
# directly so that nothing else in the link can supply the answer.
#
# Arm 1 is the one that used to be green for the wrong reason: a link that
# succeeds proves the target was selected only if a link with the target
# REMOVED fails, and fails by name.  Arms 2-4 supply that.
#
# lto-wrapper is invoked with COLLECT_GCC and COLLECT_GCC_OPTIONS set by hand
# and one real LTO object, which is exactly the shape collect2 and the linker
# plugin produce.  No argv -ftarget-config= in any arm: the whole point is what
# happens when only the environment carries it, which is every real route.
set -u
D=${D:-/tmp/b78}
T=${T:-x86_64-pc-linux-gnu}
WORK=${WORK:-/tmp/t78}
G=$D/gcc
CFG=$G/specs-$T-config
LW=$G/lto-wrapper

[ -x "$LW" ] || { echo "FATAL: no $LW"; exit 9; }
[ -s "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }
[ -s "$WORK/a.o" ] || { echo "FATAL: no LTO object $WORK/a.o -- run t78-run.sh first"; exit 9; }
grep -q '^target ' "$CFG" || { echo "FATAL: $CFG has no 'target' line; the arms below would all be vacuous"; exit 9; }

# A config naming a triple this compiler was NOT configured for.  Built from
# the real one so that only the target line differs -- otherwise a failure
# could be about any of the other 118 keys.
sed 's/^target .*/target powerpc64le-unknown-linux-gnu/' "$CFG" > "$WORK/bogus-config"
grep -q '^target powerpc64le' "$WORK/bogus-config" \
  || { echo "FATAL: could not build the bogus config; arm 3 would be vacuous"; exit 9; }

export COLLECT_GCC="$G/$T-gcc"
rc=0

arm () {  # arm <n> <description> <expected-substring> <COLLECT_GCC_OPTIONS>
  n=$1; desc=$2; want=$3; opts=$4
  COLLECT_GCC_OPTIONS="$opts" "$LW" "$WORK/a.o" > "$WORK/g$n.out" 2> "$WORK/g$n.err"
  r=$?
  if grep -q -- "$want" "$WORK/g$n.err"; then
    echo "arm $n PASS  rc=$r  $desc"
    echo "        saw: $(grep -m1 -o -- "$want" "$WORK/g$n.err")"
  else
    echo "arm $n FAIL  rc=$r  $desc"
    echo "        wanted: $want"
    echo "        stderr: $(head -2 "$WORK/g$n.err" | tr '\n' ' ')"
    rc=1
  fi
}

echo "--- arm 1: the environment carries a REAL config.  The assertion is"
echo "    AFFIRMATIVE, not an absence: lto-wrapper must decode the whole option"
echo "    set and get as far as SPAWNING lto1.  Asserting only that the"
echo "    'before a target was selected' message is missing would also pass if"
echo "    lto-wrapper had died earlier for some unrelated reason."
COLLECT_GCC_OPTIONS="'-ftarget-config=$CFG' '-flto'" "$LW" "$WORK/a.o" \
  > "$WORK/g1.out" 2> "$WORK/g1.err"
r=$?
if grep -q 'before a target was selected' "$WORK/g1.err"; then
  echo "arm 1 FAIL  rc=$r  the target was NOT selected from the environment"
  head -2 "$WORK/g1.err" | sed 's/^/        /'
  rc=1
elif grep -q "lto1" "$WORK/g1.err" || [ -s "$WORK/g1.out" ]; then
  # Run outside the build directory there is no lto1 on PATH, so reaching the
  # spawn is exactly as far as this arm can get -- and it is past every option
  # decode, which is the thing being measured.
  echo "arm 1 PASS  rc=$r  decoded the full option set and reached lto1"
  echo "        saw: $(grep -m1 'lto1' "$WORK/g1.err")"
else
  echo "arm 1 FAIL  rc=$r  did not reach lto1 and gave no ltrans output"
  head -3 "$WORK/g1.err" | sed 's/^/        /'
  rc=1
fi

echo
echo "--- arms 2-4: each REMOVES or CORRUPTS the one thing arm 1 relies on."
echo "    If any of these also passes silently, arm 1 proves nothing."
arm 2 "no -ftarget-config= anywhere"          "before a target was selected" "'-flto'"
arm 3 "config names an unconfigured triple"   "is not one of the targets"    "'-ftarget-config=$WORK/bogus-config' '-flto'"
arm 4 "config path does not exist"            "no target could be read from it" "'-ftarget-config=$WORK/no-such-config' '-flto'"

echo
echo "OVERALL rc=$rc"
exit $rc
