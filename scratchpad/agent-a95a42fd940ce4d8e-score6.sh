#!/bin/sh
# agent-a95a42fd940ce4d8e-score6.sh -- score gcc.c-torture/compile on the six
# back ends carrying `extract_insn, at recog.cc:2892', and PRESERVE each
# target's artefacts under a run-specific name.
#
# THE PRESERVATION IS NOT OPTIONAL.  mtcheck.sh writes every run to
# testsuite.<triple>/gcc/gcc.sum, and a later run of the SAME triple in the
# same build dir overwrites it.  The `.rc' stamp says a run FINISHED; it does
# not say the file on disk still belongs to it.  Both artefacts are copied to
# $OUT/<triple>.sum/.log before the next target starts, and mt-namediff.sh is
# pointed at the copies.
#
# EVERY TARGET GETS ITS OWN CROSS BINUTILS BY NAME.  Without MT_TOOLS_<triple>
# the driver resolves `as' to the build dir's shim around the HOST assembler
# and mtcheck.sh refuses -- correctly, and that refusal is not relaxed here.
#
# usage: B=<builddir> OUT=<dir> agent-a95a42fd940ce4d8e-score6.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
OUT=${OUT:?set OUT to an output dir}
T=${T:-/tmp/tools-agent-a95a42fd940ce4d8e/bin}
mkdir -p "$OUT"
SIX="alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf"
for t in $SIX; do
  [ -x "$T/$t-as" ] || { echo "FATAL: no $T/$t-as"; exit 9; }
done
# One `as' directory per target, because `-B<dir>/' makes the driver look for a
# bare `as' and the tools are named `<triple>-as'.
for t in $SIX; do
  mkdir -p "$OUT/tools/$t"
  for tool in as ld ar ranlib objcopy objdump readelf nm; do
    [ -e "$T/$t-$tool" ] && ln -sf "$T/$t-$tool" "$OUT/tools/$t/$tool"
  done
done
for t in $SIX; do
  v=MT_TOOLS_$(printf '%s' "$t" | tr - _)
  eval "export $v=$OUT/tools/$t"
done
export MT_COMPILE_ONLY=1
export MT_RUNTESTFLAGS="${MT_RUNTESTFLAGS:-compile.exp}"
for t in $SIX; do
  echo "=== $t  $(date -u +%H:%M:%S)"
  # Refuse to inherit a previous run's stamp: fixboard.sh/baseboard.sh remove
  # it before relaunching for exactly this reason.
  rm -f "$B/gcc/check-$t.rc"
  sh "$S/mtcheck.sh" "$B" "$t" > "$OUT/$t.run" 2>&1
  rc=$?
  s="$B/gcc/testsuite.$t/gcc/gcc.sum"
  l="$B/gcc/testsuite.$t/gcc/gcc.log"
  if [ -r "$s" ]; then cp "$s" "$OUT/$t.sum"; else echo "NO-SUM $t"; fi
  if [ -r "$l" ]; then cp "$l" "$OUT/$t.log"; else echo "NO-LOG $t"; fi
  n=$(grep -c 'recog.cc:2892' "$OUT/$t.log" 2>/dev/null || echo 0)
  r=$(grep -c "^FAIL.*recog.cc:2892" "$OUT/$t.log" 2>/dev/null || echo 0)
  echo "    mtcheck rc=$rc   log lines naming the site=$n   FAIL rows=$r"
done
echo "artefacts under $OUT/<triple>.sum / .log"
