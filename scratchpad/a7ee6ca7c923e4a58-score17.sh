#!/bin/sh
# STAGE 2 -- score every READY back end on the compile-only axis.
#
# THE SUBSET IS `gcc.c-torture/compile' AND NOTHING ELSE, AND THAT IS STATED
# HERE RATHER THAN IMPLIED BY THE NUMBERS.  A silent cap reads as "covered
# everything".
#
#   INCLUDED:  gcc.c-torture/compile/compile.exp
#              ~15,000 results per target on stock; every test is
#              compile-to-object with no libc, no linker, no execution and no
#              target runtime, so it is the ONE directory that means the same
#              thing on all 47 back ends.  On s390x it is already the largest
#              single debt directory (2,408) and stock fails ZERO there.
#
#   EXCLUDED:  gcc.dg (subset needs <stdlib.h>, which the bare-metal ELF
#              targets have no headers for), gcc.dg/vect, gcc.dg/torture,
#              gcc.dg/params, gcc.dg/tree-ssa, c-c++-common, gcc.misc-tests,
#              gcc.c-torture/execute, and every `gcc.target/<cpu>' directory.
#              `gcc.target' is excluded DELIBERATELY and it costs something
#              real -- it is where scan-assembler divergence lives, and it is
#              the one axis riscv64's residual showed up on -- but its `.exp'
#              name differs per back end and several of the 30 exotic targets
#              have almost nothing there, so including it would make the
#              across-target comparison inconsistent.  Breadth first.
#
# So the numbers this produces are a FLOOR on each back end's trouble, never a
# whole-suite figure, and they are comparable ACROSS back ends because every
# target ran the identical test list.
#
# usage: B=<builddir> TOOLS=<tools bin> score17.sh <triple>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the tools bin dir}
OUT=${OUT:?set OUT to an artefact dir}
[ $# -ge 1 ] || { echo "FATAL: name at least one target"; exit 9; }
mkdir -p "$OUT"

# GUARD 3c wants MT_TOOLS_<triple with dashes as underscores> per target.
# Absent, mtcheck REFUSES rather than assembling with the host tool.
for T in "$@"; do
  v=MT_TOOLS_$(printf '%s' "$T" | tr - _)
  [ -x "$TOOLS/$T-as" ] || { echo "FATAL: no $TOOLS/$T-as for $T"; exit 9; }
  eval "export $v=$TOOLS"
done

# `-j' MUST BE SET.  MT_MAKEFLAGS unset silently means -j1, and one agent's
# first run was heading for ~9 hours per arm on exactly that.
# WANT_ANCHOR is MEASURED off the srcdir this build dir names, never copied.
# mt-lib.sh asserts it EXACTLY, so a build dir configured from another tree
# fails here by name instead of producing a board for a different compiler.
SRC=$(cat "$B/MY-SRC")
WANT_ANCHOR=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$WANT_ANCHOR" -gt 0 ] || { echo "FATAL: anchor 0 -- $SRC is not a multi-target tree"; exit 9; }
export WANT_ANCHOR
echo "== anchor measured on $SRC: $WANT_ANCHOR"

export MT_MAKEFLAGS="${MT_MAKEFLAGS:--j6}"
export MT_COMPILE_ONLY=1
export MT_RUNTESTFLAGS="${MT_RUNTESTFLAGS:-compile.exp}"

echo "== subset: [$MT_RUNTESTFLAGS]  makeflags: [$MT_MAKEFLAGS]"
echo "== load at launch: $(uptime | sed 's/.*load average: //')"

rm -f "$OUT/score17.rc"
sh "$S/mtcheck.sh" "$B" "$@" > "$OUT/score17.log" 2>&1
rc=$?
echo "$rc" > "$OUT/score17.rc"
echo "== mtcheck rc=$rc"

# PRESERVE PER TARGET.  mtcheck makes TESTSUITEDIR per-target, but the sums are
# copied out anyway so a later run cannot quietly redefine what a number meant.
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
for T in "$@"; do
  for f in gcc.sum gcc.log; do
    src="$B/gcc/testsuite.$T/gcc/$f"
    [ -f "$src" ] && cp "$src" "$OUT/$T.$f"
  done
done
echo "== preserved: $(ls "$OUT" | grep -c 'gcc.sum') gcc.sum files"
echo "== load at finish: $(uptime | sed 's/.*load average: //')"
