#!/bin/sh
# agent-ae59966cf819d72ef-suite.sh -- the testsuite for aarch64 and x86_64 on
# ONE build dir, each target's REAL cross assembler named explicitly.
#
# aarch64 IS THE TARGET, AND IT IS THE PREVIOUS BOARD'S HAND-OVER ITEM 1
# ARRIVING TWICE OVER.  That board converted `ADDR_VEC_ALIGN' (aarch64
# `.align 3' -> `.align 0') and recorded plainly that aarch64 was changed by
# construction and had NO suite run.  This task then changed aarch64's jump
# table CONTENTS as well -- `.quad .L15-.L4' -> `.word (.L15 - .Lrtx4) / 4',
# `.rodata' 96 -> 48 bytes on a twelve-entry table -- which is wrong code, not
# a different spelling.  Both changes land on the same artefact and neither has
# a suite number.
#
# x86_64 is the control and must be inert: it defines neither `ADDR_VEC_ALIGN'
# nor a case-vector element macro of its own beyond the one it always used, and
# its codegen is byte-identical across this change (md5 e153a7bc5904 both
# sides).  Per the previous board that control is the strongest single piece of
# evidence available.
#
# riscv64 is NOT here and the absence is a choice on the record: its `.s' DID
# change (`.quad' -> `.word'), but this build's riscv cannot assemble AT ALL --
# `the architecture string of -march and elf architecture attributes cannot be
# empty', the known empty `.attribute arch, ""' defect -- so every
# assemble-shaped test fails on both sides for a reason that is not this
# change.  s390x is not here either: byte-identical codegen, nothing to score.
#
# MT_TOOLS_<triple> is REQUIRED by mtcheck.sh and that guard is not bypassed;
# without it the driver resolves `as' to the build dir's shim around the HOST
# assembler and every assemble-shaped test fails for a reason that is not the
# compiler.  MT_ALLOW_HOST_AS is never set here.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:-/tmp/tools-agent-ae59966cf819d72ef}

[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 in $B"; exit 9; }
[ -f "$B/all-gcc.rc" ] || { echo "FATAL: no .rc stamp in $B"; exit 9; }
[ "$(cat "$B/all-gcc.rc")" = 0 ] || { echo "FATAL: $B stamp is not 0"; exit 9; }
for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  [ -x "$TOOLS/bin/$t-as" ] || { echo "FATAL: no $TOOLS/bin/$t-as"; exit 9; }
  "$TOOLS/bin/$t-as" --version > /dev/null 2>&1 \
    || { echo "FATAL: $t-as does not EXECUTE"; exit 9; }
done
echo "build $B stamp 0, cc1 present, both cross assemblers execute"

A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
echo "anchor=$A (measured, not copied)"

# A DEFECT IN `mtcheck.sh', WORKED AROUND HERE RATHER THAN FIXED THERE, AND THE
# REASON IS A STANDING RULE.
#
# `mtcheck.sh:384' emits `DEJAGNU='${DEJAGNU:-}'' into the command it runs and
# then `export DEJAGNU' unconditionally.  For `TOOL=gcc' nothing ever sets it,
# so DEJAGNU is exported as the EMPTY STRING -- and to dejagnu 1.6.3 an empty
# DEJAGNU is not the same as an unset one:
#
#   unset  ->  WARNING: Couldn't find the global config file.   (run proceeds)
#   empty  ->  ERROR:   global config file  not found.          (runtest ABORTS)
#
# Note the two spaces in the ERROR: that is the empty filename printed.  The
# run then produces a zero-byte `gcc.sum' and `make check-gcc' still exits 0 --
# `mtcheck.sh's own banner guard is what refuses it, correctly, by name.  The
# `WARNING' form is what the previous board's riscv64/x86_64 run got, which is
# why that run scored 322,005 lines and this one scored nothing; the DEJAGNU
# export arrived with `32dbd04da25', after that board was taken.
#
# NOT FIXED IN `mtcheck.sh' BECAUSE ANOTHER AGENT'S RUN IS EXECUTING IT.
# `pgrep -af mtcheck' shows two live invocations against
# `/tmp/b-a992b7e5fa4ffaaa7'.  PRINCIPLES: `sh' reads a script by BYTE OFFSET,
# so inserting lines above a running interpreter's position can make it resume
# mid-statement and execute a fragment that never existed in any version of the
# file -- and `mtcheck.sh' invokes its scorer after the last target, hours
# later, so the exposure lasts the whole run.
#
# Supplying a NON-EMPTY DEJAGNU from out here needs no edit at all, because
# `${DEJAGNU:-}' passes a set value straight through.  The file is empty of
# directives on purpose: it exists so runtest FINDS a global config, and it
# asserts nothing about the board, leaving the "assuming the local machine"
# warning exactly as the previous board's run had it.
DJG=${DJG:-/tmp/dejagnu-global-agent-ae59966cf819d72ef.exp}
printf '# Intentionally empty; see agent-ae59966cf819d72ef-suite.sh.\n' > "$DJG"
[ -s "$DJG" ] || { echo "FATAL: could not write $DJG"; exit 9; }
export DEJAGNU="$DJG"
echo "DEJAGNU=$DEJAGNU (non-empty; an EMPTY DEJAGNU aborts runtest -- see the comment)"

MT_COMPILE_ONLY=1 \
WANT_ANCHOR=$A \
MT_MAKEFLAGS=${MT_MAKEFLAGS:--j6} \
MT_TOOLS_aarch64_unknown_linux_gnu="$TOOLS/bin" \
MT_TOOLS_x86_64_pc_linux_gnu="$TOOLS/bin" \
sh "$W/scratchpad/mtcheck.sh" "$B" \
   aarch64-unknown-linux-gnu x86_64-pc-linux-gnu
echo "SUITE DONE rc=$?"
