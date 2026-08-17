#!/bin/sh
# TWO-SIDED CHECK on the COMPILER half of the dtprel fix -- the half the
# specs-config probe cannot prove.
#
# `as_dtprel_reloc 0' in the config file is only half an answer.  The other half
# is what cc1 DOES with it, and "stopped emitting" is not the same as "took the
# non-dtprel path": aarch64_output_dwarf_dtprel answers a 0 with sorry(), which
# is still a failed compile.  The fix routes the decision through
# target_dwarf_dtprel_p () in dwarf2out, so the thread-local variable simply
# gets no DWARF location -- the same path a target with no hook has always
# taken.
#
# So this runs libgcc/config/aarch64/heap-trampoline.c BOTH WAYS against the
# same installed compiler, flipping only the one key in specs-config:
#
#   as_dtprel_reloc 0  =>  compiles, debug sections present, NO dtprel in the .s
#   as_dtprel_reloc 1  =>  FAILS TO ASSEMBLE (this is the old hardcode, and the
#                          failure is the bug being reproduced on demand)
#
# If the `1' arm ever passes, the file is no longer exercising the relocation
# and the `0' arm proves nothing.
#
# usage: t252-ht-bothsided.sh <install prefix> <aarch64 -B dir> <target hdr dir>
set -u
S=$(cd "$(dirname "$0")/.." && pwd)
I=${1:?install prefix}
BDIR=${2:?aarch64 -B dir with an unprefixed as}
HD=${3:?target header dir (contains include/)}
V=$(cat "$S/gcc/BASE-VER")
T=aarch64-unknown-linux-gnu
CFG="$I/lib/gcc/$V/$T/specs-config"
CC="$I/bin/$T-gcc"
SRC="$S/libgcc/config/aarch64/heap-trampoline.c"
test -f "$CFG" || { echo "FATAL: no $CFG"; exit 9; }
test -x "$CC"  || { echo "FATAL: no $CC"; exit 9; }

FLAGS="-O2 -DIN_GCC -W -Wall -fPIC -g -DIN_LIBGCC2 -fbuilding-libgcc
  -fno-stack-protector -fexceptions -fvisibility=hidden -DHIDE_EXPORTS
  -B$BDIR/ -I$I/lib/gcc/$V/$T/include -isystem $HD/include
  -I$S/libgcc -I$S/gcc -I$S/include"

cp "$CFG" "$CFG.t252bak"
trap 'mv -f "$CFG.t252bak" "$CFG"' 0
rc=0
for v in 0 1; do
  sed -i "s/^as_dtprel_reloc .*/as_dtprel_reloc $v/" "$CFG"
  o=/tmp/t252-ht-$v.o; s=/tmp/t252-ht-$v.s
  rm -f "$o" "$s"
  # shellcheck disable=SC2086
  $CC $FLAGS -c "$SRC" -o "$o" > /tmp/t252-ht-$v.err 2>&1
  # shellcheck disable=SC2086
  $CC $FLAGS -S "$SRC" -o "$s" >> /tmp/t252-ht-$v.err 2>&1
  # NOT `grep -c ... || echo 0': grep -c PRINTS 0 and then EXITS 1, so the
  # fallback appends a second line and $n becomes "0\n0", which compares equal
  # to nothing and fails the arm that is working.
  n=$(grep -c dtprel "$s" 2>/dev/null); n=${n:-0}
  if [ -f "$o" ]; then obj=YES; else obj=NO; fi
  echo "as_dtprel_reloc $v: object=$obj  dtprel-in-asm=$n"
  case "$v:$obj" in
    0:YES) grep -q 'sorry\|error' /tmp/t252-ht-0.err && { echo "  FAIL: diagnostics on the 0 arm"; rc=1; }
           [ "$n" = 0 ] || { echo "  FAIL: 0 arm still emitted dtprel"; rc=1; } ;;
    0:NO)  echo "  FAIL: the fixed arm does not compile"; sed -n 1,5p /tmp/t252-ht-0.err; rc=1 ;;
    1:NO)  [ "$n" -gt 0 ] || { echo "  FAIL: 1 arm failed but emitted no dtprel -- wrong reason"; rc=1; } ;;
    1:YES) echo "  FAIL: the 1 arm compiled, so this file no longer exercises the bug"; rc=1 ;;
  esac
done
[ "$rc" = 0 ] && echo "PASS: 0 compiles with no dtprel, 1 reproduces the assembler failure"
exit "$rc"
