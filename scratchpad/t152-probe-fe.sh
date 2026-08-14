#!/bin/sh
# Task #152 -- the two channel headers this build does NOT compile.
#
# The build is --enable-languages=c,lto, so `cp/cp-tree.h' and
# `m2/gm2-gcc/gcc-consolidation.h' were never compiled by it.  Silence about
# them would be the "absent artefact vs absent mechanism" trap, so they are
# preprocessed explicitly here, with the same three-arm shape as t152-probe.sh:
# a poisoned include guard amputates the tm.h tail, and a control amputates
# both routes and must come out RAW.
#
# usage: t152-probe-fe.sh <builddir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
SRC=/tmp/snap-a2ee9df2
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }

W=$D/t152-probe-fe
rm -rf "$W"; mkdir -p "$W"

RECIPE=$(sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" | grep -m1 -- '-o cfgexpand\.o')
[ -n "$RECIPE" ] || { echo "FATAL: no recipe"; exit 9; }
FLAGS=$(printf '%s\n' "$RECIPE" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXXBIN=$(printf '%s\n' "$RECIPE" | awk '{print $1}')

fail=0
gen () {   # $1 tag, $2 header, $3 poison(yes/no), $4 rearm(yes/no), $5 extra -I
  f=$W/$1.cc
  : > "$f"
  echo '#include "config.h"'    >> "$f"
  echo '#include "system.h"'    >> "$f"
  echo '#include "coretypes.h"' >> "$f"
  if [ "$3" = yes ]; then
    echo '#define GCC_MULTI_TARGET_MACROS_H' >> "$f"
    echo '#include "tm.h"'                   >> "$f"
    [ "$4" = yes ] && echo '#undef GCC_MULTI_TARGET_MACROS_H' >> "$f"
  fi
  echo "#include \"$2\"" >> "$f"
}
run () {   # $1 tag, $2 expectation, $3 extra flags
  out=$W/dM-$1.txt
  sh "$S/eb-shell.sh" "cd $D/gcc && $CXXBIN $FLAGS $3 -E -dM -o $out $W/$1.cc" \
    > "$W/log-$1.out" 2> "$W/log-$1.err" \
    || { echo "  $1: PREPROCESS FAILED"; sed -n '1,15p' "$W/log-$1.err"; fail=1; return; }
  n=$(wc -l < "$out")
  [ "$n" -gt 1000 ] || { echo "FATAL: $1 dumped only $n macros"; exit 9; }
  ps=$(grep -m1 '^#define POINTER_SIZE ' "$out" || echo '#define POINTER_SIZE <UNDEFINED>')
  case "$ps" in *mt_pointer_size*) got=converted ;; *) got=raw ;; esac
  printf '  %-22s (%s macros)  %s\n' "$1" "$n" "$ps"
  if [ "$got" = "$2" ]; then echo "      => $got, as required"
  else echo "      => $got, but requires $2  ** FAIL **"; fail=1; fi
}

CPI="-I$SRC/gcc/cp -I$SRC/gcc/c-family"
M2I="-I$SRC/gcc/m2 -I$SRC/gcc/m2/gm2-gcc -Im2 -I$SRC/gcc/c-family"

gen cp-A       cp/cp-tree.h no  no
gen cp-B       cp/cp-tree.h yes yes
gen cp-C       cp/cp-tree.h yes no
run cp-A converted "$CPI"
run cp-B converted "$CPI"
run cp-C raw       "$CPI"

gen m2-A       m2/gm2-gcc/gcc-consolidation.h no  no
gen m2-B       m2/gm2-gcc/gcc-consolidation.h yes yes
gen m2-C       m2/gm2-gcc/gcc-consolidation.h yes no
run m2-A converted "$M2I"
run m2-B converted "$M2I"
run m2-C raw       "$M2I"

echo
[ "$fail" = 0 ] && echo "t152-probe-fe: ALL ARMS AS REQUIRED" || echo "t152-probe-fe: FAILURES ABOVE"
exit $fail
