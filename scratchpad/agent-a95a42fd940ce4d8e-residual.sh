#!/bin/sh
# agent-a95a42fd940ce4d8e-residual.sh -- the FOUR tests that are NOT shared,
# and whether they are the same cause.
#
# 54 of the 71 rows are `pr21728.c' (all six back ends) and `20050122-2.c'
# (five).  The rest are alpha-only (`pr82337.c', `complex-6.c',
# `20011029-1.c' = 15 rows) and avr-only (`string-large-1.c' = 2 rows).
#
# THE POINT IS TO REFUSE TO ASSUME THEY SHARE A ROOT.  A cause carried by many
# back ends is usually one name with several authorities; a cause carried by
# ONE back end usually is not, and folding them together is how a residual gets
# reported as fixed.  Each is run per back end and its unrecognizable insn is
# printed, so `same insn shape' is a reading rather than an inference.
#
# Runs against whichever build dir D names, so it can be pointed at the PRE
# tree and the POST tree and the two outputs compared by name.
set -u
D=${D:-/tmp/b-a95a42fd940ce4d8e}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/residual-$(basename "$D")}
SRC=$(cat "$D/MY-SRC"); V=$(cat "$SRC/gcc/BASE-VER")
mkdir -p "$O"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }
echo "cc1=$D/gcc/cc1"
echo
run () {
  t=$1; f=$2; opt=$3
  c="$D/lib/gcc/$V/$t/specs-config"
  [ -s "$c" ] || { printf '%-26s %-24s %-4s %s\n' "$t" "$f" "$opt" NO-SPECS; return; }
  i="$SRC/gcc/testsuite/gcc.c-torture/compile/$f"
  [ -s "$i" ] || { printf '%-26s %-24s %-4s %s\n' "$t" "$f" "$opt" NO-INPUT; return; }
  w="$O/$t-$f-$opt"; rm -rf "$w"; mkdir -p "$w"; cp "$i" "$w/in.c"
  ( cd "$w" && "$D/gcc/cc1" -quiet -nostdinc $opt -ftarget-config="$c" \
      in.c -o out.s ) > "$w/out" 2> "$w/err"
  rc=$?
  if grep -q 'recog.cc:2892' "$w/err"; then
    ins=$(sed -n '/unrecognizable insn/,/during RTL/p' "$w/err" \
          | grep -m1 -oE '\(set \(reg[^)]*\)' )
    src=$(sed -n '/unrecognizable insn/,/during RTL/p' "$w/err" \
          | grep -m1 -oE '\(mem:[A-Z]+|\(unspec[^ ]*|\(const[^ ]*')
    printf '%-26s %-24s %-4s ICE  %s <- %s\n' "$t" "$f" "$opt" "$ins" "$src"
  elif grep -q 'internal compiler error' "$w/err"; then
    printf '%-26s %-24s %-4s OTHER-ICE %s\n' "$t" "$f" "$opt" \
      "$(grep -m1 -o 'internal compiler error: .*' "$w/err" | cut -c26-)"
  else
    printf '%-26s %-24s %-4s rc=%s %s\n' "$t" "$f" "$opt" "$rc" \
      "$( [ "$rc" = 0 ] && echo OK || echo NON-ICE-FAIL)"
  fi
}
printf '%-26s %-24s %-4s %s\n' TARGET TEST OPT RESULT
# the two shared ones, as the reference shape
for t in alpha-unknown-linux-gnu avr-unknown-elf; do
  run "$t" pr21728.c -O1
done
# the residual
for o in -O0 -O1 -O2; do
  run alpha-unknown-linux-gnu pr82337.c    "$o"
  run alpha-unknown-linux-gnu complex-6.c  "$o"
  run alpha-unknown-linux-gnu 20011029-1.c "$o"
  run avr-unknown-elf         string-large-1.c "$o"
done
