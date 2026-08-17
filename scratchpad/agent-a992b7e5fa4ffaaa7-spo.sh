#!/bin/sh
# STACK_POINTER_OFFSET on s390x: outgoing stack arguments land 160 bytes too
# low, in the callee's register save area.
#
# BOTH-SIDED AGAINST GENUINE UPSTREAM.  The control is the stock s390x build
# dir that the board's debt is scored against, so this is not "multi-target
# looks odd to me" -- it is a diff against the compiler the project defines as
# correct.  Showing the multi-target side alone would not distinguish "wrong"
# from "a different but valid schedule".
#
# THE BOARD CANNOT SEE THIS.  Every arm is compile-only, so a function that
# passes garbage in arguments 6..10 still compiles, still assembles, and still
# produces a well-formed ELF object with the right machine.  It is exactly the
# class PRINCIPLES names: "an assembler validates syntax for a machine, not
# that the compiler meant that machine".
#
# usage: agent-a992b7e5fa4ffaaa7-spo.sh <mt-builddir> <stock-s390x-builddir>
set -u
B=${1:-/tmp/b-a992b7e5fa4ffaaa7}
S=${2:-/tmp/b-stock-agent-a3464debf6893de84-s390x}
T=s390x-ibm-linux-gnu
SRC=$(cd "$(dirname "$0")" && pwd)/agent-a992b7e5fa4ffaaa7-spo.c
[ -f "$SRC" ] || { echo "FATAL: no $SRC"; exit 9; }
for f in "$B/gcc/xgcc" "$S/gcc/xgcc"; do
  [ -x "$f" ] || { echo "FATAL: no $f"; exit 9; }
done

"$B/gcc/xgcc" -B"$B/asdir-$T/" -B"$B/gcc/" \
  -ftarget-config="$B/lib/gcc/17.0.0/$T/specs-config" \
  -S -O2 "$SRC" -o /tmp/spo-mt.s 2> /tmp/spo-mt.err || { echo "FATAL: mt compile failed"; cat /tmp/spo-mt.err; exit 9; }
"$S/gcc/xgcc" -B"$S/gcc/" -S -O2 "$SRC" -o /tmp/spo-stock.s 2> /tmp/spo-stock.err \
  || { echo "FATAL: stock compile failed"; cat /tmp/spo-stock.err; exit 9; }

echo "-- outgoing-argument stores, STOCK (correct):"
grep -E '^\s+stg\s+%r[0-9]+,[0-9]+\(%r15\)' /tmp/spo-stock.s | sort
echo "-- outgoing-argument stores, MULTI-TARGET:"
grep -E '^\s+stg\s+%r[0-9]+,[0-9]+\(%r15\)' /tmp/spo-mt.s | sort

# NON-VACUITY: if either side produced no such store the grep is measuring
# nothing and a "no difference" reading would be a false green.
ns=$(grep -cE '^\s+stg\s+%r[0-9]+,[0-9]+\(%r15\)' /tmp/spo-stock.s || true)
nm=$(grep -cE '^\s+stg\s+%r[0-9]+,[0-9]+\(%r15\)' /tmp/spo-mt.s || true)
[ "$ns" -ge 5 ] && [ "$nm" -ge 5 ] \
  || { echo "FATAL: stock $ns / mt $nm argument stores -- the arm read nothing. REFUSING."; exit 9; }

echo
echo "-- the whole-body diff (stock -> multi-target):"
grep -v '^[[:space:]]*\.' /tmp/spo-stock.s > /tmp/spo-stock.body
grep -v '^[[:space:]]*\.' /tmp/spo-mt.s    > /tmp/spo-mt.body
if diff -u /tmp/spo-stock.body /tmp/spo-mt.body > /tmp/spo.diff; then
  echo "IDENTICAL -- the leak is closed (or this compiler is not the one under test)."
else
  sed -n '1,40p' /tmp/spo.diff
  echo
  echo "EXPECTED WHILE THE LEAK IS OPEN: stock stores at 160/168/176/184/192(%r15),"
  echo "multi-target at 0/8/16/24/32 -- exactly STACK_POINTER_OFFSET=160 too low,"
  echo "into the register save area the callee's own 'stmg %r6,%r15,48(%r15)'"
  echo "prologue then overwrites."
fi
