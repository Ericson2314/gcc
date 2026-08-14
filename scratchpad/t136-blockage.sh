#!/bin/sh
# #136 -- THE MEASUREMENT.  Read the UNSPEC_VOLATILE NUMBER inside the
# `blockage' rtx that each base actually emits, from a compiled function.
#
# Not from `nm'.  A symbol-table arm scores DEFINITIONS and cannot see this
# defect at all: the bare `gen_blockage' the middle end calls resolves to the
# primary's un-namespaced insn-emit, which links perfectly and returns an rtx
# numbered for i386.  What tells you it is wrong is the number inside the rtx.
#
# UNSPECV_BLOCKAGE is 1 for i386 and 5 for aarch64.  The wanted numbers are
# read out of the build's own insn-constants-<base>.h rather than written
# here, so a change to either machine description moves the bar rather than
# silently invalidating it.
#
# -fstack-clash-protection is what makes explow.cc's blockage reachable from a
# five-line function.  Before the fix aarch64 does not merely emit the wrong
# number, it ICEs on it -- `unrecognizable insn' at the vregs pass, because
# aarch64's own recog matches blockage at 5 and was handed 1.
set -u
B=${1:?build dir}
case "$B" in
  */b-a5cf4*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
S=$(cd "$(dirname "$0")" && pwd)
CC1=$B/gcc/cc1
[ -x "$CC1" ] || { echo "FATAL: no $CC1"; exit 9; }
W=$B/t136-work
rm -rf "$W"; mkdir -p "$W"
rc_all=0

for t in x86_64-pc-linux-gnu:i386 aarch64-unknown-linux-gnu:aarch64; do
  tgt=${t%:*}; base=${t#*:}
  want=$(sed -n 's/^ *UNSPECV_BLOCKAGE = \([0-9]*\).*/\1/p' \
	   "$B/gcc/insn-constants-$base.h")
  [ -n "$want" ] || { echo "FATAL: no UNSPECV_BLOCKAGE in insn-constants-$base.h"; exit 9; }
  cfg=$B/lib/gcc/17.0.0/$tgt/specs-config
  [ -f "$cfg" ] || { echo "FATAL: $tgt has no specs-config"; exit 9; }

  cd "$W"
  "$CC1" -quiet -nostdinc -O2 -ftarget-config="$cfg" \
    -fstack-clash-protection -dumpbase "$base" -fdump-rtl-expand \
    "$S/t136-blockage.c" -o "$base.s" > "$base.out" 2> "$base.err"
  rc=$?
  d=$(ls "$W/$base".*expand 2>/dev/null | head -1)
  if [ -n "$d" ]; then
    src=$d
  else
    # No dump: the run ICEd before writing one.  The ICE prints the offending
    # rtx, which carries the same number, so read that instead of scoring the
    # missing file as an absent blockage.
    src=$base.err
  fi
  nums=$(grep -A2 'unspec_volatile' "$src" | tr -d ' \t' | tr '\n' ' ')
  echo "== $tgt (base $base)   cc1 rc=$rc   want UNSPECV_BLOCKAGE=$want"
  echo "   read from: $src"
  grep -o 'unspec_volatile \[' "$src" > /dev/null 2>&1 \
    || echo "   NO unspec_volatile ANYWHERE -- no blockage was emitted; this arm proves nothing"
  sed -n '/unspec_volatile/,/^ *\] /p' "$src" | sed 's/^/   | /' | head -12
  rc_all=$((rc_all + rc))
done
echo
echo "total cc1 rc sum: $rc_all  (0 = both compiled)"
