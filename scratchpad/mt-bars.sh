#!/bin/sh
# mt-bars.sh -- the x86_64 -O2 codegen bar on scratchpad/big.c.
#
# THE SURVIVOR OF 14 `*-bars.sh'.  This is the branch's strongest regression
# detector: after 688b3afe25d it reads 12369 bytes / md5 378fc33c1e70 at 2, 3,
# 4 and 11 bases, BYTE FOR BYTE, so it is no longer base-count dependent and
# may be quoted at any base count.
#
# QUOTE EVERY BAR WITH THE COMMAND THAT PRODUCED IT.  Three times in one day a
# "disagreement" was one quantity read two ways (`wc -l' 230 vs `grep -c .'
# 222 on the same file).  Both commands are printed for the specs-config, and
# THE INPUT PATH IS PRINTED BESIDE EVERY BYTE COUNT -- `-S' emits a `.file'
# directive, so a byte count with no input named is partly evidence about a
# filename.
#
# usage: WANT_ANCHOR=<n> mt-bars.sh <builddir> [tag]
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

D=${1:?build dir}
TAG=${2:-bars}
mt_assert_builddir "$D"
SRC=$(mt_src_of "$D") || exit 9
mt_assert_configured_from "$D" "$SRC"
n=$(mt_assert_anchor "$SRC") || exit 9
V=$(cat "$SRC/gcc/BASE-VER")
OUT="$D/$TAG"; mkdir -p "$OUT"

t=${MT_BAR_TARGET:-x86_64-pc-linux-gnu}
c="$D/lib/gcc/$V/$t/specs-config"
[ -s "$c" ] || mt_die "no specs-config for $t at $c (run mt-specs.sh)"
echo "specs-config $t: wc -l $(wc -l < "$c")  grep -c . $(grep -c . "$c")  md5 $(md5sum < "$c" | cut -c1-12)"

IN=${MT_BAR_INPUT:-$SRC/scratchpad/big.c}
[ -s "$IN" ] || mt_die "input missing: $IN"
[ -x "$D/gcc/cc1" ] || mt_die "no $D/gcc/cc1"
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
    "$IN" -o "$OUT/x86-big.s" ) > "$OUT/x86-big.out" 2> "$OUT/x86-big.err"
r=$?
if [ "$r" != 0 ] || [ ! -s "$OUT/x86-big.s" ]; then
  echo "x86-big [$t] in=$IN : FAIL rc=$r  (anchor=$n)"
  sed -n 1,12p "$OUT/x86-big.err"
  exit 1
fi
echo "x86-big [$t] in=$IN : $(wc -c < "$OUT/x86-big.s") bytes  md5 $(md5sum < "$OUT/x86-big.s" | cut -c1-12)  (anchor=$n)"
echo "recorded bar: 12369 bytes  md5 378fc33c1e70"

# ---- THE `-g' ARM.  ADDED BECAUSE ITS ABSENCE COST 7,018 TEST RESULTS. ------
#
# A 6,784-ICE regression on the PRIMARY target passed every standing bar this
# branch has -- the codegen bar above was byte-identical through all of it
# (12369 / 378fc33c1e70) and so were both specs-config files -- because
# `big.c' is compiled WITHOUT `-g'.
#
# `cselib' is reached through the `vartrack' RTL pass, which only runs with
# debug info, so 5,699 of those 6,784 were on `-ON -g' variants and NOTHING
# the project measured ever passed `-g' to a compiler.  The bars covered
# codegen and did not cover debug info at all.
#
# This arm costs ONE extra cc1 invocation.  It is a SEPARATE arm rather than
# `-g' added to the existing one, because the existing byte count and md5 are
# a recorded regression detector with history behind them and must not move.
#
# It asserts rc=0 and a non-empty `.s', NOT a byte count: the point is that
# the compiler survives the debug path at all.  A recorded md5 would be a
# second thing to maintain for a much weaker signal -- and the failure this
# arm exists to catch is an ICE, which no byte count is needed to see.
( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -g -ftarget-config="$c" \
    "$IN" -o "$OUT/x86-big-g.s" ) > "$OUT/x86-big-g.out" 2> "$OUT/x86-big-g.err"
rg=$?
if [ "$rg" != 0 ] || [ ! -s "$OUT/x86-big-g.s" ]; then
  echo "x86-big-g [$t] in=$IN : FAIL rc=$rg  -- the DEBUG path is broken."
  echo "  This is the arm that was missing when the cselib.cc:2650 regression"
  echo "  landed: the -O2 bar above stayed byte-identical throughout."
  sed -n 1,12p "$OUT/x86-big-g.err"
  exit 1
fi
echo "x86-big-g [$t] in=$IN -O2 -g : rc=0  $(wc -c < "$OUT/x86-big-g.s") bytes  md5 $(md5sum < "$OUT/x86-big-g.s" | cut -c1-12)"

# NON-VACUITY: the -g arm must actually have compiled the debug path, not
# merely exited 0 on a file with no debug info in it.  "It ran" and "it
# emitted debug info" are two claims and only the second is the one being
# made.  `.debug_info' is emitted by the same DWARF machinery vartrack feeds.
if grep -q '\.debug_info\|\.section[[:space:]]*\.debug' "$OUT/x86-big-g.s"; then
  echo "  non-vacuity OK: the -g output contains debug sections"
else
  echo "  FATAL: -g output has NO debug sections -- this arm proves nothing."
  exit 1
fi
