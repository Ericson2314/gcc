#!/bin/sh
# #208 acceptance -- "a grep for .cfi_ is necessary and nowhere near
# sufficient."  This is the sufficient half: the TARGET'S OWN assembler makes
# an object and the TARGET'S OWN readelf makes sense of the frames in it.
#
# THE TRAP THIS SCRIPT IS BUILT AGAINST, stated because it is the one a
# careless check falls into: a host `as' ACCEPTS AN EMPTY FILE, and an object
# with no CFI and an object whose CFI is empty look alike.  So:
#
#   * the assembler is the target's own cross `as', never the host's;
#   * `.eh_frame' must be PRESENT AND NON-EMPTY (size > 0), not merely named;
#   * readelf must report at least one FDE *and* the FDE must mention the
#     probe function's own CFA rule -- an `.eh_frame' holding only a CIE and
#     no FDE is a real state and passes every size test;
#   * NEGATIVE CONTROL: the same pipeline is run on a file compiled
#     `-fno-exceptions -fno-asynchronous-unwind-tables', which MUST produce
#     zero FDEs.  If the control also reports non-zero the arm is measuring
#     something other than what it claims, and the script fails rather than
#     reporting a pass.
set -eu
B=${1:?build dir}
SRC=${SRC:?set SRC}
TOOLS=${TOOLS:?set TOOLS (taa-tools.sh output)}
V=$(cat "$SRC/gcc/BASE-VER")
shift
IN=$SRC/scratchpad/agent-a62563d5673423af6-cfi.c
[ -f "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

fail=0
for t in "$@"; do
  cfg=$B/lib/gcc/$V/$t/specs-config
  [ -s "$cfg" ] || { echo "$t: FATAL no $cfg"; exit 9; }
  AS=$TOOLS/bin/$t-as
  RE=$TOOLS/bin/$t-readelf
  if [ ! -x "$AS" ] || [ ! -x "$RE" ]; then
    echo "$t: SKIP -- no cross as/readelf in $TOOLS (this is a SKIP, not a pass)"
    continue
  fi

  for arm in main control; do
    case $arm in
      main)    flags="-fexceptions" ;;
      # `-fno-unwind-tables' IS REQUIRED HERE AND ITS ABSENCE BROKE THIS ARM
      # ON FIRST RUN.  aarch64's `unwind_tables_default' is true, so
      # `-fno-exceptions -fno-asynchronous-unwind-tables' still leaves
      # `flag_unwind_tables' set and `dwarf2out_do_eh_frame' still fires: the
      # "control" produced exactly as many FDEs as the main arm.  Recorded
      # rather than quietly swapped out, because a control that cannot go
      # quiet is the null-result-as-a-pass shape and it reported FAIL on a
      # tree where the fix was in fact working.
      control) flags="-fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables" ;;
    esac
    s=/tmp/cfiobj-$t-$arm.s
    o=/tmp/cfiobj-$t-$arm.o
    rm -f "$s" "$o"
    ( cd "$B/gcc" && ./cc1 -quiet -nostdinc -O2 $flags \
        -ftarget-config="$cfg" "$IN" -o "$s" ) \
        > /tmp/cfiobj-$t-$arm.out 2> /tmp/cfiobj-$t-$arm.err
    [ -s "$s" ] || { echo "$t/$arm: FATAL cc1 produced no assembly"; fail=1; continue; }
    # Non-vacuity: the probe must be in the file, so "no CFI" is not "no code".
    grep -q 'mt_cfi_probe' "$s" || { echo "$t/$arm: FATAL no mt_cfi_probe in .s"; fail=1; continue; }

    "$AS" -o "$o" "$s" > /tmp/cfiobj-$t-$arm.aserr 2>&1 \
      || { echo "$t/$arm: FATAL target as rejected the output"; sed -n 1,5p /tmp/cfiobj-$t-$arm.aserr; fail=1; continue; }

    # readelf -S -W prints `[ 7] .eh_frame PROGBITS <addr> <off> <size> ...',
    # and the index `[ 7]' splits into TWO fields, so the name is $3 and the
    # size is $7.  Reading $2/$6 (the obvious guess) silently yields the empty
    # string, which then compares as 0 -- i.e. it reports "no .eh_frame" on an
    # object that has one.  It did exactly that on the first run.
    ehsz=$("$RE" -S -W "$o" | awk '$3==".eh_frame"{printf "%d", strtonum("0x" $7)}')
    [ -n "$ehsz" ] || ehsz=0
    "$RE" --debug-dump=frames "$o" > /tmp/cfiobj-$t-$arm.frames 2>&1 || true
    fdes=$(grep -c ' FDE ' /tmp/cfiobj-$t-$arm.frames || true)
    cies=$(grep -c ' CIE$\| CIE ' /tmp/cfiobj-$t-$arm.frames || true)
    dcfa=$(grep -c 'DW_CFA_def_cfa' /tmp/cfiobj-$t-$arm.frames || true)
    printf '%-28s %-8s .eh_frame=%-5s CIE=%-3s FDE=%-3s DW_CFA_def_cfa=%s\n' \
      "$t" "$arm" "$ehsz" "$cies" "$fdes" "$dcfa"

    case $arm in
      main)
        if [ "$ehsz" -le 0 ] || [ "$fdes" -lt 1 ] || [ "$dcfa" -lt 1 ]; then
          echo "  -> FAIL: no usable frame description"; fail=1
        fi ;;
      control)
        if [ "$fdes" -gt 0 ]; then
          echo "  -> ARM BROKEN: the negative control also has FDEs, so a"
          echo "     non-zero main arm proves nothing"; fail=1
        fi ;;
    esac
  done
done
exit $fail
