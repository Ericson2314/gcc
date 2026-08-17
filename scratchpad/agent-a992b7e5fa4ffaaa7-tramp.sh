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

echo
echo "EXPECTED WHILE THE LEAKS ARE OPEN:"
echo "  STOCK         (no .section -- .text)      .align 3"
echo "  MULTI-TARGET  .section .rodata            .align 2"
