#!/bin/sh
# a76a331dcb554f700 -- compile `target-asm-ops.cc' for EVERY base with
# `-fsyntax-only', against an existing build dir.
#
# WHY: enabling this TU for mmix started the "one missing declaration per
# 47-base build" series that `target-cumargs.cc' already paid four times
# (epiphany/attribs.h, attribs.h/stringpool.h, msp430/recog.h, mips/varasm.h).
# `-syncheck.sh' exists for exactly that and cost a build apiece before it did.
# This is the same instrument for the other supply-side TU: all the missing
# declarations of a change turn up in ONE run of a few seconds.
#
# THE NEGATIVE CONTROL IS NOT OPTIONAL.  `-syncheck.sh' once reported 22 of 22
# bases `ok' while every compile died with `g++: command not found', because
# "no error: line" scored a pass.  So this appends an undeclared identifier to
# a copy of the file and REQUIRES the compiler to name it; if it does not,
# every `ok' above is void and the script exits 9.
set -u
B=${B:?build dir}
SRC=$(cat "$B/MY-SRC")
# THE FILE UNDER TEST DEFAULTS TO THE BUILD DIR'S OWN SRCDIR, and TASRC
# overrides it.  Without that the script re-checks the snapshot the build was
# taken from and reports the OLD file as still failing -- an instrument that
# cannot see the edit it was written to check.
TASRC=${TASRC:-$SRC/gcc/target-asm-ops.cc}
CXX=${CXX:-g++}
tmp=/tmp/asmopscheck-a76a331dcb554f700
rm -rf $tmp; mkdir -p $tmp

inc="-I$B/gcc -I$SRC/gcc -I$SRC/gcc/config -I$SRC/include -I$SRC/libcpp/include \
     -I$B/gcc/build -I$SRC/gcc/../include"
common="-fsyntax-only -std=c++17 -DIN_GCC -DHAVE_CONFIG_H $inc"

bases=$(ls "$B/gcc" | sed -n 's/^tm-\(.*\)\.h$/\1/p' | sort -u)
n=0; bad=0
for base in $bases; do
  [ -f "$B/gcc/tm_p-$base.h" ] || continue
  n=$((n+1))
  if $CXX $common -DTM_H_FILE="\"tm-$base.h\"" -DTM_P_H_FILE="\"tm_p-$base.h\"" \
       -DTARGETM_ASM_OPS_SYMBOL=targetm_asm_ops_$base -DMULTI_TARGET_SUPPLY_TU=1 \
       "$TASRC" > $tmp/$base.err 2>&1; then
    printf '%-14s ok\n' "$base"
  else
    printf '%-14s FAIL  %s\n' "$base" "$(grep -m1 'error:' $tmp/$base.err | cut -c1-120)"
    bad=$((bad+1))
  fi
done
echo
echo "bases checked=$n fail=$bad"

# ---- NEGATIVE CONTROL ------------------------------------------------------
b=$(echo "$bases" | head -1)
cp "$TASRC" $tmp/ctl.cc
chmod u+w $tmp/ctl.cc     # the srcdir is an immutable snapshot; cp keeps its mode
printf '\nint mt_control_undeclared = a76a331_no_such_identifier;\n' >> $tmp/ctl.cc
$CXX $common -DTM_H_FILE="\"tm-$b.h\"" -DTM_P_H_FILE="\"tm_p-$b.h\"" \
  -DTARGETM_ASM_OPS_SYMBOL=targetm_asm_ops_$b -DMULTI_TARGET_SUPPLY_TU=1 \
  $tmp/ctl.cc > $tmp/ctl.err 2>&1
if grep -q 'a76a331_no_such_identifier' $tmp/ctl.err; then
  echo "negative control OK: the compiler named the undeclared identifier"
else
  echo "FATAL: the negative control did NOT fire; every 'ok' above is void"
  head -3 $tmp/ctl.err
  exit 9
fi
[ "$bad" = 0 ] || exit 1
