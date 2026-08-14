#!/bin/sh
# #190 -- THE EXECUTED arm for cc1plus: does the C-family selector actually
# RUN and pick the right back end, or is the object merely linked in?
#
# "Is a per-base variant built", "does a selector exist" and "does anything
# CALL the selector" are three arms (PRINCIPLES 4).  The nm arm answers the
# first two for cc1plus.  This one runs the compiler and reads what it
# predefines, which is the only arm that can see the third.
#
# TARGET_CPU_CPP_BUILTINS is the hook `<cpu>-c.o' supplies, so its output IS
# the measurement: `__x86_64__' comes from ix86_target_macros and `__aarch64__'
# from aarch64_cpu_cpp_builtins.  Before this series cc1plus contained only the
# former for every target.
#
# BOTH-SIDED AND CROSS-CHECKED AGAINST cc1: the same two probes are run
# through cc1, which was already correct, so a change in cc1plus that is
# really a change in the shared machinery cannot read as a C++ fix.
#
# The aarch64 specs-config here is the #113b FALLBACK (build machine's own
# as/ld under aarch64's name).  That is fine for THIS question and only this
# question: the predefined macros come from the back end, not from the
# assembler.  Nothing about assembler capabilities may be read from this run.
set -u
D=${1:?build dir}
V=17.0.0
G=$D/gcc
OUT=$D/t190-cxxrun
mkdir -p $OUT
src=$OUT/empty.cc
: > $src
csrc=$OUT/empty.c
: > $csrc
rc=0
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  c=$D/lib/gcc/$V/$t/specs-config
  [ -s "$c" ] || { echo "FATAL: no specs-config for $t"; exit 9; }
  for comp in cc1 cc1plus; do
    [ -x "$G/$comp" ] || { echo "  $comp: not built"; rc=1; continue; }
    in=$csrc; [ "$comp" = cc1plus ] && in=$src
    ( cd $G && ./$comp -quiet -nostdinc -E -dM -ftarget-config="$c" "$in" ) \
      > $OUT/$comp-$t.txt 2> $OUT/$comp-$t.err
    r=$?
    n=$(grep -c . $OUT/$comp-$t.txt)
    # Non-vacuity: an empty -dM dump greps 0 for everything, which reads as
    # "the macro is absent" -- the answer this arm is looking for.
    if [ $r != 0 ] || [ "$n" -lt 100 ]; then
      echo "  $comp [$t]: FATAL rc=$r, only $n macros dumped"
      sed -n 1,5p $OUT/$comp-$t.err; rc=9; continue
    fi
    x86=$(grep -c '^#define __x86_64__ ' $OUT/$comp-$t.txt)
    a64=$(grep -c '^#define __aarch64__ ' $OUT/$comp-$t.txt)
    printf '  %-8s [%s]  macros=%s  __x86_64__=%s  __aarch64__=%s\n' \
      "$comp" "$t" "$n" "$x86" "$a64"
  done
done
exit $rc
