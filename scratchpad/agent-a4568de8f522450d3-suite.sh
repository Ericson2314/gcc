#!/bin/sh
# agent-a4568de8f522450d3-suite.sh -- run the testsuite for riscv64 and x86_64
# on ONE build dir, with each target's REAL cross assembler named explicitly.
#
# riscv64 is where the `.option pop' claim is; x86_64 is the control that
# should be inert -- and per the previous board that control is the strongest
# single piece of evidence available (197,834 results, zero transitions).
#
# s390x is deliberately NOT here: `HAVE_AS_MACHINE_MACHINEMODE' is unwritten
# in this build, so s390 defines neither converted macro and a suite run for
# it would be measuring the stacked cause, not this work.  aarch64 is not here
# either: its only stake is ADJUST_INSN_LENGTH, which is gated on
# `-mfix-cortex-a53-835769' and is a no-op by default.  Both are stated so the
# absences are choices on the record rather than gaps.
#
# MT_TOOLS_<triple> is REQUIRED by mtcheck.sh and that guard is not bypassed:
# without it the driver resolves `as' to the build dir's shim around the HOST
# assembler and every assemble-shaped test fails for a reason that is not the
# compiler.  MT_ALLOW_HOST_AS is never set here.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:-/tmp/tools-a4568de8f522450d3}

[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 in $B"; exit 9; }
[ -f "$B/all-gcc.rc" ] || { echo "FATAL: no .rc stamp in $B"; exit 9; }
[ "$(cat "$B/all-gcc.rc")" = 0 ] || { echo "FATAL: $B stamp is not 0"; exit 9; }
for t in riscv64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  [ -x "$TOOLS/bin/$t-as" ] || { echo "FATAL: no $TOOLS/bin/$t-as"; exit 9; }
  "$TOOLS/bin/$t-as" --version > /dev/null 2>&1 \
    || { echo "FATAL: $t-as does not EXECUTE"; exit 9; }
done
echo "build $B stamp 0, cc1 present, both cross assemblers execute"

A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
echo "anchor=$A (measured, not copied)"

MT_COMPILE_ONLY=1 \
WANT_ANCHOR=$A \
MT_MAKEFLAGS=${MT_MAKEFLAGS:--j6} \
MT_TOOLS_riscv64_unknown_linux_gnu="$TOOLS/bin" \
MT_TOOLS_x86_64_pc_linux_gnu="$TOOLS/bin" \
sh "$W/scratchpad/mtcheck.sh" "$B" \
   riscv64-unknown-linux-gnu x86_64-pc-linux-gnu
echo "SUITE DONE rc=$?"
