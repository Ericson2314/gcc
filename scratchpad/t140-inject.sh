#!/bin/sh
# #140 -- THE ACCEPTANCE ARM.  A green build is not evidence here: it was
# green before.  What has to be shown is that the WRONG answers, which used to
# compile silently against another target's headers, are now fatal errors that
# name a path.
#
# The object under test is target-cumargs-i386.o: one shared source compiled
# once per back end, so it is the population the change is for, and it names
# four per-base headers (tm.h, tm_p.h, insn-config.h, insn-attr.h).
#
# Injections are made by OVERRIDING the make variable from the command line --
# a command-line variable beats a target-specific assignment -- so no file is
# edited and nothing has to be restored by hand.  Each arm asserts it produced
# the state it intended: the object is removed first and its absence checked,
# because "make did nothing" and "make failed" are otherwise the same picture.
#
# usage: t140-inject.sh [builddir]
set -o pipefail
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:-/tmp/b140}
OBJ=target-cumargs-i386.o
rc=0

got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] \
  || { echo "FATAL: $D was configured from '$got', not $SRC"; exit 9; }
echo "build dir $D configured from $SRC"

# The generated artefact must actually carry what this task added, asserted by
# NAME AND VALUE and run FIRST -- a generator that runs, exits 0 and changes
# nothing is this project's sharpest false green, and move-if-change hides it.
for f in i386-inc/mt-inc-witness.h i386-inc/mt-inc-tag-i386.h \
	 aarch64-inc/mt-inc-witness.h aarch64-inc/mt-inc-tag-aarch64.h; do
  [ -f "$D/gcc/$f" ] || { echo "FATAL: $D/gcc/$f was never generated"; exit 9; }
done
grep -q 'mt-inc-tag-i386\.h' "$D/gcc/i386-inc/mt-inc-witness.h" \
  || { echo "FATAL: i386-inc/mt-inc-witness.h does not name its own tag"; exit 9; }
grep -q 'mt-inc-tag-aarch64\.h' "$D/gcc/aarch64-inc/mt-inc-witness.h" \
  || { echo "FATAL: aarch64-inc/mt-inc-witness.h does not name its own tag"; exit 9; }
[ -f "$D/gcc/i386-inc/mt-inc-tag-aarch64.h" ] \
  && { echo "FATAL: i386-inc holds aarch64's tag; the tags are not distinct"; exit 9; }
echo "witness pair present and distinct per base"

# One arm.  $1 = label, $2 = expected outcome (ok|fail), $3 = text that must
# appear in a failing arm's output, $4... = make overrides.
arm () {
  label=$1; want=$2; needle=$3; shift 3
  rm -f "$D/gcc/$OBJ"
  [ -e "$D/gcc/$OBJ" ] && { echo "$label: FATAL: could not remove $OBJ"; rc=9; return; }
  out=$(sh "$S/eb-shell.sh" "cd $D/gcc && make $OBJ $*" 2>&1)
  got=$?
  if [ "$want" = ok ]; then
    if [ "$got" = 0 ] && [ -f "$D/gcc/$OBJ" ]; then
      echo "$label: PASS (rc=0, $OBJ rebuilt)"
    else
      echo "$label: FAIL: rc=$got, object present=$([ -f "$D/gcc/$OBJ" ] && echo y || echo n)"
      echo "$out" | tail -20
      rc=1
    fi
  else
    if [ "$got" = 0 ]; then
      echo "$label: FAIL: the injection COMPILED.  That is the silent wrong"
      echo "$label:       answer this change exists to remove."
      rc=1
    elif echo "$out" | grep -q "$needle"; then
      echo "$label: PASS (fatal, and names it)"
      echo "$out" | grep -m1 "$needle" | sed 's/^/    /'
    else
      echo "$label: FAIL: it failed, but NOT by naming '$needle' --"
      echo "$label:       a failure for another reason is not this check firing."
      echo "$out" | tail -20
      rc=1
    fi
  fi
}

arm "ARM 0  control, unmodified            " ok ""
# The needle here is the #error, not a path.  Measured: with MT_BASE undefined
# the FIRST diagnostic is multi-target-base.h's own `#error', which names the
# flag; the path failure that follows (MT_BASE/mt-inc-tag-i386.h) is the
# witness, reached before tm.h.  Naming the flag is the better diagnostic and
# is what the arm should require -- but it had to be measured, not predicted:
# this arm was first written against `MT_BASE/tm.h' and reported FAIL on
# correct behaviour.
arm "ARM 1  MT_BASE undefined              " fail 'MT_BASE is not defined' \
    MULTI_TARGET_BASE_DEF=
arm "ARM 2  MT_BASE names the other base   " fail 'aarch64-inc/mt-inc-tag-i386.h' \
    MULTI_TARGET_BASE_DEF=-DMT_BASE=aarch64-inc
arm "ARM 3  -I<base>-inc removed           " fail 'mt-inc-witness.h' MULTI_TARGET_INC=
arm "ARM 4  -I names the other back end    " fail 'i386-inc/mt-inc-tag-aarch64.h' \
    MULTI_TARGET_INC=-Iaarch64-inc
arm "ARM 5  restored                       " ok ""

echo "OVERALL rc=$rc"
exit $rc
