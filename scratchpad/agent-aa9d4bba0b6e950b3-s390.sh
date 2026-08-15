#!/bin/sh
# agent-aa9d4bba0b6e950b3-s390.sh -- compile one file for s390x with a build
# dir's cc1 and report what happened.
#
# WHAT THIS PRINTS AND WHY.  Not "did it ICE": PRINCIPLES records that "where
# does it ICE" is not the measurement and "is the output right" is, and that a
# disappeared ICE has twice turned out to be silent wrong code.  So this prints
# rc, the ICE line if any, AND the size of the emitted assembly, so a wall that
# "moves" can be told from a wall that went quiet.
#
# usage: [MT_TARGET=<triple>] agent-aa9d4bba0b6e950b3-s390.sh <builddir> <file> [flags...]
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}; shift
IN=${1:?input file}; shift
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
T=${MT_TARGET:-s390x-ibm-linux-gnu}
C="$D/lib/gcc/$V/$T/specs-config"
[ -s "$C" ] || mt_die "no specs-config for $T at $C"
[ -x "$D/gcc/cc1" ] || mt_die "no $D/gcc/cc1"
[ -s "$IN" ] || mt_die "no input $IN"

O=${MT_OUT:-/tmp/mt-s390-$$.s}
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -ftarget-config="$C" "$@" "$IN" -o "$O" ) \
  > /tmp/mt-s390-$$.out 2> /tmp/mt-s390-$$.err
rc=$?
echo "target=$T rc=$rc flags=$* in=$IN"
if grep -q 'internal compiler error' /tmp/mt-s390-$$.err; then
  echo "  ICE: $(grep -m1 'internal compiler error' /tmp/mt-s390-$$.err | sed 's/^.*internal/internal/')"
else
  echo "  ICE: none"
fi
if [ -s "$O" ]; then
  echo "  emitted: $(wc -c < "$O") bytes, $(grep -c . "$O") non-blank lines"
else
  echo "  emitted: NOTHING"
fi
head -20 /tmp/mt-s390-$$.err
rm -f /tmp/mt-s390-$$.out /tmp/mt-s390-$$.err
[ -n "${MT_KEEP:-}" ] || rm -f "$O"
exit $rc
