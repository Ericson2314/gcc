#!/bin/sh
# Task #152 -- POSITIVE INSTRUMENT for the defaults.h/tm.h severance.
#
# "It still compiles" is not evidence a macro reached its users: `#if FOO' on
# an undefined FOO silently evaluates FALSE.  So this reads the macros'
# EXPANSIONS out of the REAL compile recipe with `-E -dM', in four arms, one of
# which is a negative control that MUST fail.
#
# The amputation is done with a POISONED INCLUDE GUARD on the command line /
# in the probe source rather than by editing files, so the snapshot srcdir
# stays immutable and every arm uses the identical recipe.
#
#   ARM A  both routes present (the tree as committed).  POINTER_SIZE must be
#          `(mt_pointer_size ())'.  This is the BEFORE state.
#
#   ARM B  the `tm.h' tail route AMPUTATED -- GCC_MULTI_TARGET_MACROS_H is
#          pre-defined across `#include "tm.h"' so defaults.h's include is a
#          no-op, then un-defined so only backend.h's new source-level include
#          can supply the layer.  Same expansions required.  THIS IS THE ARM
#          THAT PROVES THE SEVERANCE: before this commit no such route existed
#          and it could not have passed.
#
#   ARM C  NEGATIVE CONTROL: both routes amputated.  POINTER_SIZE must NOT be
#          the mt_ form.  If C passes, A and B prove nothing.
#
#   ARM D  TERMINAL STATE: no `tm.h' anywhere in the TU, `multi-target-macros.h'
#          included directly after `coretypes.h'.  Proves the header is
#          includable on its own, which is what Phase 5 will need.
#
# usage: t152-probe.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
SRC=/tmp/snap-a2ee9df2
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = 48 ] \
  || { echo "FATAL: snapshot anchor is not 48"; exit 9; }

W=$D/t152-probe
rm -rf "$W"; mkdir -p "$W"

cat > "$W/A.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
EOF

cat > "$W/B.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
/* Poison the guard so defaults.h's include -- the tm.h tail -- does nothing. */
#define GCC_MULTI_TARGET_MACROS_H
#include "tm.h"
#undef GCC_MULTI_TARGET_MACROS_H
/* Only backend.h's own source-level include can supply the layer now. */
#include "backend.h"
EOF

cat > "$W/C.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
/* Poison and never re-arm: BOTH routes dead.  This arm must fail. */
#define GCC_MULTI_TARGET_MACROS_H
#include "tm.h"
#include "backend.h"
EOF

cat > "$W/D.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "multi-target-macros.h"
EOF

RECIPE=$(sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" \
	 | grep -m1 -- '-o cfgexpand\.o')
[ -n "$RECIPE" ] || { echo "FATAL: no recipe for cfgexpand.o"; exit 9; }
FLAGS=$(printf '%s\n' "$RECIPE" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXXBIN=$(printf '%s\n' "$RECIPE" | awk '{print $1}')
echo "recipe: $CXXBIN $FLAGS"

fail=0
run_arm () {                            # $1 = arm, $2 = expectation word
  out=$W/dM-$1.txt
  sh "$S/eb-shell.sh" "cd $D/gcc && $CXXBIN $FLAGS -E -dM -o $out $W/$1.cc" \
    > "$W/log-$1.out" 2> "$W/log-$1.err" \
    || { echo "  arm $1: COMPILE FAILED"; sed -n '1,20p' "$W/log-$1.err"; fail=1; return; }
  # Non-vacuity: an empty -dM dump reads exactly like "macro absent".
  n=$(wc -l < "$out")
  [ "$n" -gt 1000 ] || { echo "FATAL: arm $1 dumped only $n macros -- read nothing"; exit 9; }
  ps=$(grep -m1 '^#define POINTER_SIZE ' "$out" || echo '#define POINTER_SIZE <UNDEFINED>')
  bw=$(grep -m1 '^#define BITS_PER_WORD ' "$out" || echo '#define BITS_PER_WORD <UNDEFINED>')
  fp=$(grep -m1 '^#define FIRST_PSEUDO_REGISTER ' "$out" || echo '#define FIRST_PSEUDO_REGISTER <UNDEFINED>')
  printf '  arm %s (%s macros)\n    %s\n    %s\n    %s\n' "$1" "$n" "$ps" "$bw" "$fp"
  case "$ps" in
    *'mt_pointer_size'*) got=converted ;;
    *) got=raw ;;
  esac
  if [ "$got" = "$2" ]; then echo "    => $got, as required"
  else echo "    => $got, but arm $1 requires $2  ** FAIL **"; fail=1; fi
}

echo "ARM A -- both routes present"
run_arm A converted
echo "ARM B -- tm.h tail amputated; only backend.h's include remains"
run_arm B converted
echo "ARM C -- NEGATIVE CONTROL: both routes amputated"
run_arm C raw
echo "ARM D -- TERMINAL STATE: no tm.h in the TU at all"
run_arm D converted

echo
if [ "$fail" = 0 ]; then echo "t152-probe: ALL ARMS AS REQUIRED (C failed, which is the control firing)"
else echo "t152-probe: FAILURES ABOVE"; fi
exit $fail
