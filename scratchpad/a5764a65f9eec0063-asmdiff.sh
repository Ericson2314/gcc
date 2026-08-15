#!/bin/sh
# a5764a65f9eec0063 -- both-sided assembly diff for one ACLE test.
#
# The sme2/acle-asm residual is 100% `check-function-bodies', i.e. the
# compiler COMPILES and emits WRONG CODE.  So the instrument has to be a diff
# of the emitted assembly against the stock cross, not a compile-or-not check.
#
# NON-VACUITY: both sides must produce a non-empty .s AND rc=0.  A cc1 that
# died produces an empty/absent .s, and `diff' against an absent file reports
# a difference -- which reads exactly like the wrong-code finding we are
# hunting.  Both are asserted by name before anything is compared.
#
# usage: sh a5764a65f9eec0063-asmdiff.sh <suite/relpath.c> [extra cc1 flags...]
set -u

SNAP=${SNAP:-/tmp/snap-agent-a5764a65f9eec0063}
MTD=${MTD:-/tmp/b-a57163422943aaa57-lra}
STD=${STD:-/tmp/b-stock-agent-a3464debf6893de84-aarch64}
W=${W:-/tmp/w-a5764a65f9eec0063}
MEMCAP=$(cd "$(dirname "$0")" && pwd)/tb1-memcap.sh

REL=${1:?relative test path under gcc/testsuite/}
shift
T=$SNAP/gcc/testsuite/$REL
[ -f "$T" ] || { echo "FATAL: no such test $T"; exit 9; }
TDIR=$(dirname "$T")
NAME=$(basename "$REL" .c)

mkdir -p "$W"
CFG=$MTD/lib/gcc/17.0.0/aarch64-unknown-linux-gnu/specs-config
[ -f "$CFG" ] || { echo "FATAL: no specs-config at $CFG"; exit 9; }

# The suite's own option set, from the .sum FAIL line, plus the include dirs
# the .exp adds.  -march comes from the test headers' pragmas.
OPTS="-std=c23 -O2 -fno-schedule-insns -fno-schedule-insns2 -DCHECK_ASM -DTEST_FULL"
INCS="-I$TDIR -I$SNAP/gcc/testsuite/gcc.target/aarch64/sme/acle-asm -I$SNAP/gcc/testsuite/gcc.target/aarch64/sve/acle/asm"

run () { # $1 = tag, $2 = xgcc, $3.. = flags
  tag=$1; cc=$2; shift 2
  sh "$MEMCAP" 8000000 "$cc" "$@" $OPTS $INCS "$@" -S "$T" -o "$W/$tag-$NAME.s" \
     > "$W/$tag-$NAME.out" 2> "$W/$tag-$NAME.err"
  echo $? > "$W/$tag-$NAME.rc"
}

sh "$MEMCAP" 8000000 "$MTD/gcc/xgcc" -B"$MTD/gcc/" -ftarget-config="$CFG" \
   $OPTS $INCS "$@" -S "$T" -o "$W/mt-$NAME.s" \
   > "$W/mt-$NAME.out" 2> "$W/mt-$NAME.err"
echo $? > "$W/mt-$NAME.rc"

sh "$MEMCAP" 8000000 "$STD/gcc/xgcc" -B"$STD/gcc/" \
   $OPTS $INCS "$@" -S "$T" -o "$W/st-$NAME.s" \
   > "$W/st-$NAME.out" 2> "$W/st-$NAME.err"
echo $? > "$W/st-$NAME.rc"

fail=0
for s in mt st; do
  rc=$(cat "$W/$s-$NAME.rc")
  if [ "$rc" != 0 ]; then
    echo "FATAL($s): cc1 rc=$rc -- this is a COMPILE failure, not a codegen diff"
    sed -n '1,15p' "$W/$s-$NAME.err"
    fail=1
  elif [ ! -s "$W/$s-$NAME.s" ]; then
    echo "FATAL($s): .s absent or empty despite rc=0"
    fail=1
  fi
done
[ "$fail" = 0 ] || exit 9

echo "== both sides rc=0, non-empty: mt $(wc -l < "$W/mt-$NAME.s") lines, st $(wc -l < "$W/st-$NAME.s") lines"
echo "== diff (stock < , multi-target > ):"
diff "$W/st-$NAME.s" "$W/mt-$NAME.s" && echo "IDENTICAL"
