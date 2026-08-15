#!/bin/sh
# agent-aa9d4bba0b6e950b3-check.sh -- run the s390x testsuite against one of
# the two build dirs and PRESERVE its artefacts under a run-specific name.
#
# THE PRESERVATION IS NOT OPTIONAL.  mtcheck.sh writes every run to
# `testsuite.<triple>/gcc/gcc.sum', so the BEFORE run's sum would be destroyed
# by the AFTER run and the destroyed file reads as a present one.  The `.rc'
# stamp says a run FINISHED; it does not say the file still belongs to it.
#
# GUARD 3c needs this target's own binutils by name or it REFUSES -- every
# board before the 15th fed s390x assembly to the host x86 `as', worth ~7,205
# results on this target alone.  MT_ALLOW_HOST_AS is deliberately NOT set.
#
# usage: agent-aa9d4bba0b6e950b3-check.sh <before|after>
set -eu
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
TOOLS=/tmp/tools-agent-aa9d4bba0b6e950b3
ARM=${1:?before|after}
case "$ARM" in
  before) D=/tmp/b-aa9d4bba0b6e950b3 ;;
  after)  D=/tmp/b-aa9d4bba0b6e950b3-after ;;
  *) echo "FATAL: arm must be before|after" >&2; exit 9 ;;
esac
T=s390x-ibm-linux-gnu
OUT=/tmp/board-agent-aa9d4bba0b6e950b3
mkdir -p "$OUT"

[ -d "$TOOLS/bin" ] || { echo "FATAL: no $TOOLS/bin (run taa-tools.sh)" >&2; exit 9; }
[ -x "$TOOLS/bin/$T-as" ] || { echo "FATAL: no $TOOLS/bin/$T-as" >&2; exit 9; }

A=$(grep -c MULTI_TARGET "$(cat "$D/MY-SRC")/gcc/Makefile.in")
echo "== arm=$ARM builddir=$D anchor=$A src=$(cat "$D/MY-SRC")"

# `MT_MAKEFLAGS' IS NOT OPTIONAL AND ITS ABSENCE IS EXPENSIVE.  mtcheck.sh
# passes it straight to `make check-gcc', and unset it means `-j1': the first
# BEFORE run here reached 15,145 of an expected 170,106 `.sum' lines in fifty
# minutes, i.e. roughly nine hours per arm and eighteen for the pair.  The
# boards on this branch were all taken under `-j' (PRINCIPLES notes ERRLIN
# scales with it, which is only true if it was used).  Nothing about the
# RESULTS changes -- ERRTCL is the number that means something and it is
# -j-independent -- only the wall clock.
MT_MAKEFLAGS="${MT_MAKEFLAGS:--j8}" \
MT_TOOLS_s390x_ibm_linux_gnu="$TOOLS/bin" \
MT_COMPILE_ONLY=1 \
WANT_ANCHOR=$A \
sh "$W/scratchpad/tb1-memcap.sh" 8388608 \
  sh "$W/scratchpad/mtcheck.sh" "$D" "$T"
rc=$?
echo "mtcheck rc=$rc"

# Copy BOTH artefacts before anything else can run.
S=$D/gcc/testsuite.$T/gcc
for f in gcc.sum gcc.log; do
  [ -f "$S/$f" ] || { echo "FATAL: no $S/$f" >&2; exit 9; }
  cp "$S/$f" "$OUT/$ARM-s390x.${f#gcc.}"
done
grep -q '=== gcc Summary' "$OUT/$ARM-s390x.sum" \
  || { echo "FATAL: $ARM sum is truncated -- refusing" >&2; exit 9; }
echo "$rc" > "$OUT/$ARM-s390x.rc"
echo "-- preserved $OUT/$ARM-s390x.{sum,log,rc}"
grep -E '^# of ' "$OUT/$ARM-s390x.sum"
