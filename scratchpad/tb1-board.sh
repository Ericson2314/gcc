#!/bin/sh
# THE BOUNDED BOARD: `gcc.target/<dir>' only, per target, on ONE build dir.
#
# WHY BOUNDED.  The full per-target suite is ~50 minutes per target here and
# this host was carrying another agent's `-fsanitize' build at load 20 while
# this ran; a four-target before/after pair would be eight of those.  The
# `gcc.target/<dir>' subset is the one the user's own ruling picks out -- a
# `scan-assembler' test needs no libgcc, no linker, no execution and no
# assembler, it compiles to `.s' and greps the text -- and it is where "did
# this back end emit its own instructions" actually lives.
#
# It is a SUBSET and is reported as one.  It is not the TAA-BOARD and must not
# be diffed against it.
#
# usage: WANT_ANCHOR=<n> sh tb1-board.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  case $T in
    x86_64-*)  E=i386.exp ;;
    aarch64-*) E=aarch64.exp ;;
    riscv64-*) E=riscv.exp ;;
    s390x-*)   E=s390.exp ;;
  esac
  echo "======== $B :: $T :: $E"
  MT_COMPILE_ONLY=1 MT_MAKEFLAGS=-j4 \
  MT_SCORER="$S/tb1-mtscore.sh" \
  MT_RUNTESTFLAGS="$E" \
    sh "$S/tb1-mtcheck.sh" "$B" "$T" 2>&1 | tail -25
done
