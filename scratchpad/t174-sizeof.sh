#!/bin/sh
# #174 -- READ `sizeof (struct target_expmed)' OUT OF A REAL COMPILE, once
# against the SHARED insn-modes.h and once against arm's.
#
# This is the cause-isolating instrument for the layout witness.  The witness
# itself only fires inside a linked `cc1' (reginfo.cc:238), which costs an
# hour; this costs a second and reads the same number, because the disagreement
# is entirely a function of which insn-modes.h the TU saw.
#
# The size is printed BY THE COMPILER, via an incomplete template
# specialisation -- `error: invalid use of incomplete type struct S<514168>'.
# A `static_assert' would only say "failed" and a count of nothing.
#
# The arm context is made by shadowing insn-modes.h with a directory of
# symlinks, which is what `arm-inc/' is; doing it here means this arm works in
# a build dir where the full per-base header trees have not been generated yet.
#
# The COMPILE happens in <builddir>, which must be far enough along to have
# config.h and the gtype/insn headers.  The insn-modes.h under test comes from
# <modesdir> (default <builddir>/gcc), so the before and after trees can be
# compared with EVERYTHING ELSE HELD FIXED -- which is what makes this an
# isolation of the cause rather than a comparison of two builds.
#
# usage: t174-sizeof.sh <builddir> [modesdir] [label]
set -u
D=${1:?build dir}
[ -f "$D/MY-SRC" ] || { echo "FATAL: $D has no MY-SRC"; exit 9; }
SRC=$(cat "$D/MY-SRC")
G=$D/gcc
M=${2:-$G}
LBL=${3:-$M}
for f in "$M/insn-modes.h" "$M/insn-modes-arm.h" "$M/insn-modes-inline-arm.h" \
         "$M/insn-modes-inline.h"; do
  [ -f "$f" ] || { echo "FATAL: missing $f"; exit 9; }
done

P=$D/t174-arm-inc
rm -rf "$P"; mkdir -p "$P"
ln -s "$M/insn-modes-arm.h" "$P/insn-modes.h"
ln -s "$M/insn-modes-inline-arm.h" "$P/insn-modes-inline.h"
Q=$D/t174-shared-inc
rm -rf "$Q"; mkdir -p "$Q"
ln -s "$M/insn-modes.h" "$Q/insn-modes.h"
ln -s "$M/insn-modes-inline.h" "$Q/insn-modes-inline.h"

cat > "$D/t174-probe.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "rtl.h"
#include "expmed.h"
template<unsigned long N> struct MT174;
MT174<sizeof (struct target_expmed)> mt174_probe;
MT174<(unsigned long) NUM_MODE_INT> mt174_num_mode_int;
EOF

INC="-I. -I$SRC/gcc -I$SRC/gcc/. -I$SRC/gcc/../include -I$SRC/gcc/../libcpp/include \
 -I$SRC/gcc/../libcody -I$SRC/gcc/../libdecnumber -I$SRC/gcc/../libdecnumber/bid \
 -I../libdecnumber -I$SRC/gcc/../libbacktrace"

run () {   # $1 = label, $2 = extra -I
  sh "$(dirname "$0")/eb-shell.sh" \
    "cd $G && g++ -fsyntax-only -DIN_GCC -DHAVE_CONFIG_H -fno-exceptions -fno-rtti \
       $2 $INC $D/t174-probe.cc" > "$D/t174-$1.out" 2> "$D/t174-$1.err"
  n=$(sed -n 's/.*MT174<\([0-9]*\)>.*/\1/p' "$D/t174-$1.err" | sed -n 1p)
  m=$(sed -n 's/.*MT174<\([0-9]*\)>.*/\1/p' "$D/t174-$1.err" | sed -n 2p)
  # NON-VACUITY: an unreadable error text scores as empty, which reads as
  # agreement -- the answer this arm exists to disprove.
  [ -n "$n" ] && [ -n "$m" ] || {
    echo "  $1: FATAL could not read the sizes; first errors:"
    sed -n 1,8p "$D/t174-$1.err" | sed 's/^/    /'; exit 9; }
  echo "  $1: sizeof (struct target_expmed) = $n   NUM_MODE_INT = $m"
}

echo "== compiled in $D (srcdir $SRC); insn-modes.h from $LBL"
run shared "-I$Q"
run arm "-I$P"
