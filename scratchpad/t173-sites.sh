#!/bin/sh
# #173 -- every plain `#include "<stem>.h"' SITE under gcc/config, per stem,
# split into the Kind B files (compiled once, no base -- BASE_HEADER is wrong
# for them) and everything else.
#
# This is the population that `-I<base>-inc' is actually serving.  The tm.h
# figure in the brief (47) is one stem of sixteen.
set -e
cd "$(dirname "$0")/.."
B='gcc/config/i386/driver-i386.cc gcc/config/aarch64/driver-aarch64.cc
gcc/config/arm/driver-arm.cc gcc/config/alpha/driver-alpha.cc
gcc/config/darwin-driver.cc gcc/config/vxworks-driver.cc
gcc/config/sol2-c.cc gcc/config/vms/vms-c.cc gcc/config/arm/arm-d.cc
gcc/config/mips/mips-d.cc gcc/config/rs6000/rs6000-d.cc
gcc/config/s390/s390-d.cc gcc/config/sparc/sparc-d.cc
gcc/config/freebsd-d.cc gcc/config/avr/gen-avr-mmcu-specs.cc
gcc/config/i386/i386.h gcc/config/aarch64/aarch64.h gcc/config/arm/arm.h
gcc/config/loongarch/loongarch-evolution.h'
# The last four are HEADERS.  A back end .h is read both per base and from the
# shared tm.h chain (which includes config/i386/i386.h), so it cannot name a
# base; converting them gave 96 `MT_BASE is not defined'.
echo "$B" | tr ' ' '\n' | grep . | sort > /tmp/t173-kindb.txt

tot=0
printf '%-20s %8s %8s\n' stem convert kindB
for s in tm tm_p tm-preds tm-constrs options insn-constants insn-attr \
	 insn-attr-common insn-codes insn-config insn-flags insn-modes \
	 insn-modes-inline insn-opinit insn-recog insn-target-def; do
  git grep -l "^#include \"$s\.h\"" -- gcc/config | sort > /tmp/t173-s.txt
  nb=$(comm -12 /tmp/t173-s.txt /tmp/t173-kindb.txt | wc -l)
  nc=$(comm -23 /tmp/t173-s.txt /tmp/t173-kindb.txt | wc -l)
  tot=$((tot + nc))
  [ "$nc" = 0 ] && [ "$nb" = 0 ] && continue
  printf '%-20s %8s %8s\n' "$s" "$nc" "$nb"
done
echo "TOTAL files to convert (with duplicates across stems): $tot"
