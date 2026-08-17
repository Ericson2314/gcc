#!/bin/sh
# aarch64 trampolines: THREE leaks on one four-line function, measured against
# the stock aarch64 compiler the board's debt is scored against.
#
#   TRAMPOLINE_SECTION       aarch64 `text_section', i386 SILENT, so
#                            varasm.cc:3065's `#ifdef' never fires and the
#                            trampoline is emitted into `.rodata' -- a
#                            NON-EXECUTABLE section.
#   TRAMPOLINE_ALIGNMENT     aarch64 64 (`.align 3'), shared gets i386's
#                            FUNCTION_ALIGNMENT (`.align 2') -- under-aligned.
#   ASM_OUTPUT_MAX_SKIP_ALIGN  the spurious `.p2align 3' A018 filed as item 3,
#                            still live at tip.
#
# BOTH-SIDED, because "multi-target emits X" is not a finding unless stock
# emits something else -- a different but valid schedule looks identical to a
# bug from one side.
#
# usage: agent-a992b7e5fa4ffaaa7-tramp.sh <mt-builddir> <stock-aarch64-builddir>
set -u
B=${1:-/tmp/b-a992b7e5fa4ffaaa7}
S=${2:-/tmp/b-stock-agent-a3464debf6893de84-aarch64}
T=aarch64-unknown-linux-gnu
SRC=$(cd "$(dirname "$0")" && pwd)/agent-a992b7e5fa4ffaaa7-tramp.c
[ -f "$SRC" ] || { echo "FATAL: no $SRC"; exit 9; }

"$B/gcc/xgcc" -B"$B/asdir-$T/" -B"$B/gcc/" \
  -ftarget-config="$B/lib/gcc/17.0.0/$T/specs-config" \
  -S -O2 "$SRC" -o /tmp/tr-mt.s 2> /tmp/tr-mt.err || { echo FATAL mt; cat /tmp/tr-mt.err; exit 9; }
"$S/gcc/xgcc" -B"$S/gcc/" -S -O2 "$SRC" -o /tmp/tr-st.s 2> /tmp/tr-st.err \
  || { echo FATAL stock; cat /tmp/tr-st.err; exit 9; }

# NON-VACUITY: no trampoline, nothing to say.  A "no difference" reading on a
# file with no .LTRAMP in it would be a false green.
for f in /tmp/tr-mt.s /tmp/tr-st.s; do
  grep -q 'LTRAMP' "$f" || { echo "FATAL: no trampoline in $f -- the arm read nothing. REFUSING."; exit 9; }
done

echo "-- the section the trampoline lands in:"
for f in /tmp/tr-st.s /tmp/tr-mt.s; do
  case $f in *st.s) tag=STOCK ;; *) tag="MULTI-TARGET" ;; esac
  sec=$(awk '/LTRAMP/{print s; exit} /^\t\.section|^\t\.text/{s=$0}' "$f")
  printf '   %-14s %s\n' "$tag" "${sec:-<none: stayed in .text>}"
done

echo "-- the alignment immediately before .LTRAMP0:"
for f in /tmp/tr-st.s /tmp/tr-mt.s; do
  case $f in *st.s) tag=STOCK ;; *) tag="MULTI-TARGET" ;; esac
  printf '   %-14s %s\n' "$tag" "$(grep -B1 '^\.LTRAMP0:' "$f" | head -1)"
done


# VERDICT.  This script used to end by PRINTING the expected broken values and
# leaving the reader to compare them by eye, which is a paragraph rather than a
# check: it exits 0 whether the leak is open or closed, so a harness calling it
# cannot tell.  It now compares the two sides and says which.
#
# For reference, what it looked like while the leaks were open:
#   STOCK         (no .section -- .text)      .align 3
#   MULTI-TARGET  .section .rodata            .align 2
sec_of () { awk '/LTRAMP/{print s; exit} /^\t\.section|^\t\.text/{s=$0}' "$1"; }
aln_of () { grep -B1 '^\.LTRAMP0:' "$1" | head -1; }
rc=0; named=0
[ "$(sec_of /tmp/tr-st.s)" = "$(sec_of /tmp/tr-mt.s)" ] \
  && echo "PASS: TRAMPOLINE_SECTION matches genuine stock" \
  || { echo "FAIL: TRAMPOLINE_SECTION differs from stock"; rc=1; named=1; }
[ "$(aln_of /tmp/tr-st.s)" = "$(aln_of /tmp/tr-mt.s)" ] \
  && echo "PASS: TRAMPOLINE_ALIGNMENT matches genuine stock" \
  || { echo "FAIL: TRAMPOLINE_ALIGNMENT differs from stock"; rc=1; named=1; }

# And the whole body, so a third divergence on this construct cannot hide
# behind the two arms that were written for the two known ones.
grep -v '^[[:space:]]*\.file\|^[[:space:]]*\.ident' /tmp/tr-st.s > /tmp/tr-st.body
grep -v '^[[:space:]]*\.file\|^[[:space:]]*\.ident' /tmp/tr-mt.s > /tmp/tr-mt.body
n=$(grep -c . /tmp/tr-st.body)
[ "$n" -ge 10 ] || { echo "FATAL: stock body is $n lines -- the arm read nothing"; exit 9; }
if diff -u /tmp/tr-st.body /tmp/tr-mt.body > /tmp/tr.diff; then
  echo
  echo "WHOLE FILE IDENTICAL to genuine stock over $n lines."
else
  echo
  echo "-- residual whole-file diff vs stock ($n lines on the stock side):"
  sed -n '1,30p' /tmp/tr.diff
  rc=1
  if [ "$named" = 0 ]; then
    echo
    echo "READ THE EXIT CODE CAREFULLY.  Both NAMED arms PASS -- the two leaks"
    echo "this reproducer was written for are closed.  The nonzero rc is the"
    echo "WIDER arm, added afterwards so a third divergence on this construct"
    echo "cannot hide behind two arms written for two known ones.  As of"
    echo "95d90a64818 it shows a spurious '.p2align 3'"
    echo "(ASM_OUTPUT_MAX_SKIP_ALIGN -- 7 definers incl. i386, so the shared"
    echo "#ifdef is true for everyone; A992B7E5FA4FFAAA7-TRAMPOLINE.md item 3,"
    echo "still open) and a 16-byte frame-size difference.  Neither is what"
    echo "this script's two arms measure."
  fi
fi
exit "$rc"
