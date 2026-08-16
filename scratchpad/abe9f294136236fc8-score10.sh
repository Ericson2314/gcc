#!/bin/sh
# Score the ten scorable back ends on `gcc.c-torture/compile', for ONE build
# dir, detached-safe.  PRE and POST are two invocations of this file against
# two different build dirs; nothing here knows which is which, deliberately.
#
# THE SUBSET IS `gcc.c-torture/compile' AND NOTHING ELSE, stated here rather
# than implied by the numbers -- it is `a7ee6ca7c923e4a58-score17.sh''s
# subset unchanged, so PRE, POST and the board's own rows are comparable.
# Every test compiles to an object with no libc, no linker and no execution,
# so it means the same thing on all ten.  These numbers are a FLOOR on each
# back end's trouble, never a whole-suite figure.
#
# usage: B=<builddir> TOOLS=<tools bin> OUT=<artefact dir> score10.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the tools BIN dir}
OUT=${OUT:?set OUT to an artefact dir}

TARGETS="x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu \
s390x-ibm-linux-gnu alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi \
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf"

# ARM 0: THE TOOLS MUST RUN, BY NAME, BEFORE ANYTHING IS SCORED.  A missing
# cross `as' is not a smaller number, it is `target-specs' silently probing
# the host assembler, which #113b measured at ~10,000 results per target.
sh "$S/abe9f294136236fc8-astcheck.sh" "$TOOLS" $TARGETS || exit 9

# ARM 1: THE COMPILER MUST BE THE ONE INTENDED.  `all-gcc.rc' is written only
# after `make' returns, so a truncated build fails here rather than producing
# a smaller board -- PRINCIPLES' "a log being written looks exactly like a log
# that finished".
[ -f "$B/all-gcc.rc" ] || { echo "FATAL: no $B/all-gcc.rc -- build unfinished"; exit 9; }
[ "$(cat "$B/all-gcc.rc")" = 0 ] || { echo "FATAL: $B all-gcc.rc != 0"; exit 9; }
SRC=$(cat "$B/MY-SRC")
echo "== build $B  srcdir $SRC  sha $(cat "$SRC/SNAP-SHA" 2>/dev/null || echo '?')"
echo "== anchor $(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")"

mkdir -p "$OUT"
OUT=$OUT TOOLS=$TOOLS B=$B sh "$S/a7ee6ca7c923e4a58-score17.sh" $TARGETS
echo "== score10 rc=$?"

# THE ONE-LINE CENSUS, because a back end that dies on its FIRST input
# contributes no FAIL rows and is invisible to a `.sum'-based ranking --
# indistinguishable from one never attempted and from one that passed
# everything.  Cheap, and it is the specific trap this task was warned about.
[ -x "$S/a7ee6ca7c923e4a58-onelinecensus.sh" ] && \
  sh "$S/a7ee6ca7c923e4a58-onelinecensus.sh" "$B" > "$OUT/onelinecensus.txt" 2>&1
echo "== census -> $OUT/onelinecensus.txt"

# THE ROW THIS TASK IS ABOUT, per target, by name.  Printed here so that a
# zero is always accompanied by the counts that make it meaningful, and never
# stands alone as "clean".
echo
printf '%-30s %8s %8s %8s\n' TARGET extract_insn FAILrows PASSrows
for T in $TARGETS; do
  f="$OUT/$T.gcc.sum"
  if [ -f "$f" ]; then
    printf '%-30s %8s %8s %8s\n' "$T" \
      "$(grep -c 'extract_insn, at recog.cc:2892' "$f")" \
      "$(grep -c '^FAIL:' "$f")" "$(grep -c '^PASS:' "$f")"
  else
    printf '%-30s %8s\n' "$T" "NO-SUM"
  fi
done
