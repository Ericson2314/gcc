#!/bin/sh
# agent-a95a42fd940ce4d8e-savearea.sh -- THE DECISIVE MEASUREMENT for
# `extract_insn, at recog.cc:2892' on alpha, arc, arm, avr, mips64 and or1k.
#
# THE HYPOTHESIS, STATED BEFORE MEASURING SO THE RESULT CAN REFUTE IT.
# `defaults.h:1493's `#ifndef STACK_SAVEAREA_MODE' is DEAD, because
# `config/i386/i386.h:2011' has already defined the name in every shared
# translation unit.  i386's answer for `SAVE_NONLOCAL' is
# `TARGET_64BIT ? TImode : DImode', i.e. **TImode**, so all 47 back ends build
# the nonlocal-goto stack save area as a 16-byte TImode object.  40 back ends
# define no such macro and should get `defaults.h's `Pmode'; six others
# (rs6000 OImode-ish, s390 OImode, ia64, nvptx, sparc, aarch64 CDImode) have
# their own answers.  `builtins.cc:1203' then builds `(mem:TI ...)' and
# `explow.cc:1256' does `emit_insn (gen_move_insn (stack_pointer_rtx, sa))' --
# a TImode load into a Pmode stack pointer, which no back end's `.md' declares.
#
# WHY THIS IS THE SAME DEFECT AS `EPILOGUE_USES' AND `REGMODE_NATURAL_SIZE'.
# All three are an `#ifndef' in shared code that can never be taken because the
# primary defines the name first.  PRINCIPLES records the shape twice; this is
# the third instance, and it is the one `multi-target-macros.h:768' ALREADY
# CLAIMS IS HANDLED -- "`STACK_SAVEAREA_MODE' above expands to `Pmode' for a
# base that defines no such macro, and is defined EARLIER in this file".  There
# is no `#undef' or `#define' for it anywhere in that file.  A written
# invariant is not a checked one.
#
# TWO ARMS, AND THE SECOND IS THE ONE THAT CANNOT BE EXPLAINED AWAY.
#
#   ARM A  ICE/no-ICE on the two shared testcases.  Necessary but weak: a back
#          end can fail to ICE because it happens to HAVE a TImode move, not
#          because it got the right mode.
#
#   ARM B  THE SAVE-AREA ARRAY SIZE, read from the GIMPLE dump.
#          `tree-nested.cc:791' sizes the nonlocal-goto field as
#          `GET_MODE_SIZE (STACK_SAVEAREA_MODE (SAVE_NONLOCAL)) / GET_MODE_SIZE
#          (Pmode) + 1'.  With the leak that numerator is 16 for EVERY back
#          end.  So the array length is a direct, quantitative readout of WHOSE
#          answer the macro gave, and it is visible on the back ends that do
#          NOT ICE as well as on the six that do.  That is what makes it
#          both-sided: a fix must move arm B on all 47 while moving arm A on
#          exactly the six.
#
# A back end that dies before emitting anything contributes no ICE and no dump
# and is INVISIBLE to both arms -- exactly like one that passed.  So every
# target's rc and dump presence are printed, and a target with no dump is
# reported as NO-DUMP rather than folded into "did not ICE".
set -u
D=${D:-/tmp/b-a95a42fd940ce4d8e}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/savearea}
SRC=$(cat "$D/MY-SRC")
V=$(cat "$SRC/gcc/BASE-VER")
T=${T:-/tmp/tools-agent-a95a42fd940ce4d8e/bin}
mkdir -p "$O"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }

# The six carrying the site, then the four that do not -- the control side.
SIX="alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf"
CTL="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu
riscv64-unknown-linux-gnu s390x-ibm-linux-gnu"
IN=${IN:-$SRC/gcc/testsuite/gcc.c-torture/compile/pr21728.c}
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
echo "cc1=$D/gcc/cc1   in=$IN"
echo

printf '%-30s %-4s %-5s %-9s %s\n' TARGET SIDE rc SAVEAREA NOTE
run_one () {
  t=$1; side=$2
  c="$D/lib/gcc/$V/$t/specs-config"
  if [ ! -s "$c" ]; then
    printf '%-30s %-4s %-5s %-9s %s\n' "$t" "$side" - - "NO-SPECS-CONFIG (not scorable)"
    return
  fi
  w="$O/$t"; rm -rf "$w"; mkdir -p "$w"
  # THE INPUT IS COPIED IN, and that is not tidiness.  cc1 writes dump files
  # BESIDE THE INPUT, and the srcdir is an immutable read-only snapshot, so
  # naming the snapshot path directly makes every target fail with
  # `could not open dump file ... Permission denied' -- rc=1, no ICE, no dump,
  # on ALL TEN targets.  That reads as "nobody reproduces the bug", i.e. a
  # clean result, and it is the instrument failing identically everywhere.
  # Measured, by hitting it.
  cp "$IN" "$w/in.c"
  ( cd "$w" && "$D/gcc/cc1" -quiet -nostdinc -O1 -ftarget-config="$c" \
      -fdump-tree-nested -fdump-rtl-expand in.c -o out.s ) \
      > "$w/out" 2> "$w/err"
  rc=$?
  # NON-VACUITY, per target: a run that produced neither an object nor a dump
  # nor an ICE did not measure this back end at all.
  grep -q 'could not open dump file' "$w/err" && \
    { printf '%-30s %-4s %-5s %-9s %s\n' "$t" "$side" "$rc" INSTR-FAIL \
      "dump file not writable -- NOT a result"; return; }
  # ARM B: the nonlocal-goto save-area array length, from the tree-nested dump.
  # Read as the array TYPE printed for the goto save field.  Absent => NO-DUMP,
  # never 0: an unwritten dump and a zero-length array are different findings.
  dmp=$(ls "$w"/*.nested 2>/dev/null | head -1)
  if [ -n "$dmp" ]; then
    sz=$(sed -n 's/.*nl_goto_save\[\([0-9]*\)\].*/\1/p' "$dmp" | head -1)
    [ -n "$sz" ] && sz=$((sz+1)) || sz=$(grep -o 'FRAME[^;]*\[[0-9]*\]' "$dmp" | head -1)
    [ -n "$sz" ] || sz=NO-FIELD
  else
    sz=NO-DUMP
  fi
  note=$(grep -m1 'internal compiler error' "$w/err" | sed 's/.*internal compiler error: //')
  [ -n "$note" ] || note="(no ICE)"
  printf '%-30s %-4s %-5s %-9s %s\n' "$t" "$side" "$rc" "$sz" "$note"
}
for t in $SIX; do run_one "$t" SIX; done
for t in $CTL; do run_one "$t" CTL; done
echo
echo "== the leaked value, for reference"
echo "i386 STACK_SAVEAREA_MODE(SAVE_NONLOCAL) = TARGET_64BIT ? TImode : DImode  -> TImode, 16 bytes"
echo "defaults.h:1494 would give Pmode for the 40 back ends defining nothing"
echo
echo "dumps and stderr under $O/<target>/"
