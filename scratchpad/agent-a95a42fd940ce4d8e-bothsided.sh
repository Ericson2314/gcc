#!/bin/sh
# agent-a95a42fd940ce4d8e-bothsided.sh -- THE BOTH-SIDED ARM.
#
# "Showing target A gets A's answer proves nothing unless you also show target
# B still gets B's.  One-sided evidence cannot distinguish `fixed' from
# `everyone now gets the same new answer'."
#
# The mode of the nonlocal-goto save-area MEM is read out of the expand dump
# for all ten targets, PRE and POST, and compared against WHAT THAT BACK END'S
# OWN HEADER SAYS.  A fix that merely swapped i386's TImode for a different
# single value would show up here as ten identical modes; a correct one shows
# ten targets each matching its own header, INCLUDING x86_64 CHANGING -- its
# own answer is TImode and shared code was giving it DImode, so a POST run
# where x86_64 is unchanged would mean the redirect is not reaching it.
#
# EXPECTED OWN ANSWERS, from the headers, for SAVE_NONLOCAL:
#   i386     TImode   (TARGET_64BIT ? TImode : DImode), 64-bit here
#   aarch64  CDImode  aarch64.h:1469
#   s390     OImode   s390.h:328
#   the rest Pmode    defaults.h:1494 -- DI for alpha/riscv64, SI for
#                     arc/arm/or1k/mips64, HI for avr
set -u
PRE=${PRE:-/tmp/b-a95a42fd940ce4d8e}
POST=${POST:-/tmp/b-a95a42fd940ce4d8e-post}
O=${O:-/tmp/w-agent-a95a42fd940ce4d8e/bothsided}
mkdir -p "$O"
TARGETS="alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf x86_64-pc-linux-gnu
aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu"
want () {
  case $1 in
    x86_64*)  echo TI ;;   aarch64*) echo CDI ;;  s390x*) echo OI ;;
    avr*)     echo HI ;;
    alpha*|riscv64*) echo DI ;;
    *)        echo SI ;;
  esac
}
# The save-area MEM is the SOURCE of the set whose destination is the stack
# pointer.  Found by that relation, not by position: insn numbers differ per
# back end and a fixed offset would silently read a different insn.
mode_of () { # builddir target -> mode of the MEM loaded into sp, or a reason
  d=$1; t=$2
  [ -x "$d/gcc/cc1" ] || { echo NO-CC1; return; }
  S=$(cat "$d/MY-SRC"); V=$(cat "$S/gcc/BASE-VER")
  c="$d/lib/gcc/$V/$t/specs-config"; [ -s "$c" ] || { echo NO-SPECS; return; }
  w="$O/$(basename "$d")-$t"; rm -rf "$w"; mkdir -p "$w"
  cp "$S/gcc/testsuite/gcc.c-torture/compile/pr21728.c" "$w/in.c"
  ( cd "$w" && "$d/gcc/cc1" -quiet -nostdinc -O1 -ftarget-config="$c" \
      -fdump-rtl-expand in.c -o out.s ) > "$w/out" 2> "$w/err"
  f=$(ls "$w"/*.expand 2>/dev/null | head -1)
  [ -n "$f" ] || { echo NO-DUMP; return; }
  m=$(tr '\n' ' ' < "$f" \
      | grep -oE '\(set \(reg/f:[A-Z]+ [0-9]+ [^)]*\) *\(mem:[A-Z]+' \
      | grep -oE 'mem:[A-Z]+' | sed 's/mem://' | tail -1)
  [ -n "$m" ] || m=NO-SP-LOAD
  echo "$m"
}
printf '%-28s %-6s %-8s %-8s %s\n' TARGET OWN PRE POST VERDICT
nok=0; nbad=0
for t in $TARGETS; do
  wnt=$(want "$t"); a=$(mode_of "$PRE" "$t"); b=$(mode_of "$POST" "$t")
  if [ "$b" = "$wnt" ]; then v="ok -- its own answer"; nok=$((nok+1))
  else v="MISMATCH (wanted $wnt)"; nbad=$((nbad+1)); fi
  [ "$a" = "$b" ] && v="$v  [UNCHANGED]"
  printf '%-28s %-6s %-8s %-8s %s\n' "$t" "$wnt" "$a" "$b" "$v"
done
echo
echo "POST matching the back end's own answer: $nok of 10   mismatches: $nbad"
# NON-VACUITY 1: if every POST mode is identical, the redirect has replaced one
# shared answer with another shared answer -- the exact failure this arm exists
# to catch, and it would look like a fix on the six.
u=$(for t in $TARGETS; do mode_of "$POST" "$t"; done | sort -u | wc -l)
echo "distinct POST modes across the ten targets: $u"
[ "$u" -gt 1 ] || { echo "FATAL: one mode for all ten -- still a single authority"; exit 9; }
# NON-VACUITY 2: the PRE side must show the defect, or this compares nothing.
p=$(for t in $TARGETS; do mode_of "$PRE" "$t"; done | sort -u | wc -l)
echo "distinct PRE modes across the ten targets: $p  (2 expected: TI and DI)"
