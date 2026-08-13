#!/bin/sh
# #139 -- COST OF THE "COMPILE THE CONSUMING TUs PER BASE" ROUTE.
#
# `target-cumargs.cc' is already compiled once per back end, so the mechanism
# exists and needs no design.  The question is what it costs to extend it to
# the 50 shared files that spell UNITS_PER_WORD: the answer is object text,
# multiplied by the number of configured back ends, plus every one of those
# files losing the property that it is compiled ONCE for all targets.
#
# Measured from a real build dir rather than estimated, because the files in
# question are among the largest in the compiler and a guess would be wrong by
# a factor.
#
# usage: t139-dupcost.sh <builddir> <macro>
set -u
SRC=$(cd "$(dirname "$0")/.." && pwd)
B=${1:?builddir}; M=${2:-UNITS_PER_WORD}
[ -d "$B/gcc" ] || { echo "FATAL: no gcc dir in $B"; exit 9; }

cd "$SRC" || exit 9
FILES=$(grep -rln "\\b$M\\b" gcc --include='*.cc' \
        | grep -v '^gcc/config/' | grep -v testsuite | grep -v '^gcc/ada/' \
        | sed 's|^gcc/||')
n=0; tot=0; miss=0
echo "object text of every shared .cc spelling $M, from $B:"
for f in $FILES; do
  o=$B/gcc/$(echo "$f" | sed 's|\.cc$|.o|')
  if [ -f "$o" ]; then
    s=$(wc -c < "$o")
    n=$((n+1)); tot=$((tot+s))
    echo "  $s  $f"
  else
    miss=$((miss+1))
    echo "  (not built) $f"
  fi
done | sort -rn -k1 | head -25
# recompute (the loop above ran in a subshell of the pipe)
n=0; tot=0; miss=0
for f in $FILES; do
  o=$B/gcc/$(echo "$f" | sed 's|\.cc$|.o|')
  if [ -f "$o" ]; then n=$((n+1)); tot=$((tot + $(wc -c < "$o"))); else miss=$((miss+1)); fi
done
[ "$n" -ge 10 ] || { echo "FATAL: only $n objects found -- wrong build dir?"; exit 9; }
echo "$M: $n objects built, $miss not built, total $tot bytes"
echo "  per EXTRA back end this route adds ~$tot bytes of object text"
echo "  (a 48-back-end build would add ~$((tot * 47)) bytes over the shared single copy)"
