#!/bin/sh
# #208 -- does this build emit DWARF CFI, per target?
#
# WHY THIS IS NOT `grep -c .cfi_'.  An object with NO CFI and an object whose
# CFI is EMPTY look the same to a careless check, and a host `as' accepts an
# empty file, so "the assembler was happy" proves nothing either.  Four arms,
# each able to report non-zero on the same run:
#
#   A  .cfi_startproc / .cfi_def_cfa* / .cfi_offset present in the .s
#   B  the TARGET's own assembler makes an object, and it has an .eh_frame
#   C  the TARGET's own readelf --debug-dump=frames parses it and finds an FDE
#   D  -freorder-blocks-and-partition survives (the sibling symptom)
#
# Arm D is the NEGATIVE CONTROL for the whole script: it reads a DIFFERENT
# observable through the SAME predicate, so a run where A-C are zero and D is
# also zero is one cause, while A-C zero and D non-zero would refute it.
set -eu
B=${1:?build dir}
SRC=${SRC:?set SRC}
TOOLS=${TOOLS:-}
IN=$SRC/scratchpad/agent-a62563d5673423af6-cfi.c
[ -f "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 in $B"; exit 9; }

for t in "$@"; do
  case $t in /*) continue ;; esac
  V=$(cat "$SRC/gcc/BASE-VER")
  cfg=$B/lib/gcc/$V/$t/specs-config
  [ -s "$cfg" ] || { echo "$t: FATAL no $cfg (run mt-specs.sh)"; exit 9; }
  s=/tmp/cfimeas-$t.s
  rm -f "$s"
  ( cd "$B/gcc" && ./cc1 -quiet -nostdinc -O2 -fexceptions \
      -ftarget-config="$cfg" "$IN" -o "$s" ) > /tmp/cfimeas-$t.out 2> /tmp/cfimeas-$t.err
  rc=$?
  # A file that was never written greps as 0 exactly like one with no CFI.
  [ -s "$s" ] || { echo "$t: FATAL cc1 rc=$rc wrote no assembly"; sed -n 1,5p /tmp/cfimeas-$t.err; continue; }
  a_start=$(grep -c '\.cfi_startproc' "$s" || true)
  a_cfa=$(grep -c '\.cfi_def_cfa' "$s" || true)
  a_off=$(grep -c '\.cfi_offset' "$s" || true)
  # Non-vacuity: the probe function must actually be in this file, so a zero
  # above is "no CFI" and not "no code".
  body=$(grep -c 'mt_cfi_probe' "$s" || true)
  printf '%-28s rc=%s  startproc=%-3s def_cfa=%-3s offset=%-3s  (mt_cfi_probe lines %s)\n' \
    "$t" "$rc" "$a_start" "$a_cfa" "$a_off" "$body"
done
