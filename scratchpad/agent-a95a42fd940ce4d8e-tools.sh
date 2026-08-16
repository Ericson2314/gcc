#!/bin/sh
# agent-a95a42fd940ce4d8e-tools.sh -- materialise MY OWN tools dir for the six
# back ends carrying `extract_insn at recog.cc:2892', by copying from the
# already-built cross binutils rather than rebuilding them.
#
# WHY A COPY AND NOT A REFERENCE.  PRINCIPLES records the exact defect of a
# harness hardcoding another worktree's tools dir: that dir can be cleaned
# under you, and a MISSING cross assembler falls back to the host `as' three
# layers away with no diagnostic (~10,000 results per target).  So the source
# dir is named ONCE, here, and every tool is asserted to EXECUTE -- `OK'
# asserts the binary runs, not that a path exists, because a dangling symlink
# and a wrong-arch binary are both exactly the shape that falls back silently.
#
# The spellings are CANONICAL (`arc-unknown-elf32', not `arc-elf32').  An
# earlier script installed tools under short triples no build rule looks for,
# which is indistinguishable from absent.
set -eu
SRCBIN=${SRCBIN:-/tmp/tools-a7ee6ca7c923e4a58/bin}
OUT=${OUT:-/tmp/tools-agent-a95a42fd940ce4d8e}
TRIPLES="alpha-unknown-linux-gnu arc-unknown-elf32 arm-unknown-eabi
avr-unknown-elf mips64-unknown-elf or1k-unknown-elf
x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu
s390x-ibm-linux-gnu"
[ -d "$SRCBIN" ] || { echo "FATAL: no $SRCBIN"; exit 9; }
mkdir -p "$OUT/bin"
n=0; bad=0
for t in $TRIPLES; do
  for tool in as ld ar ranlib objcopy objdump readelf nm size strings; do
    s="$SRCBIN/$t-$tool"
    [ -e "$s" ] || continue
    cp -L "$s" "$OUT/bin/$t-$tool" 2>/dev/null || continue
    chmod +x "$OUT/bin/$t-$tool"
  done
  # ARM 1: the assembler must EXECUTE.  Not exist -- execute.
  if "$OUT/bin/$t-as" --version > /dev/null 2>&1; then
    n=$((n+1)); echo "OK   $t-as $("$OUT/bin/$t-as" --version 2>&1 | head -1 | sed 's/.*) //')"
  else
    bad=$((bad+1)); echo "DEAD $t-as -- does not run"
  fi
done
echo "tools that RUN: $n   dead: $bad   in $OUT/bin"
# NON-VACUITY: a run that copied nothing must not read like a run that copied
# everything.  Ten triples are named above; fewer than ten live assemblers is a
# hard stop, because the fallback is the HOST `as' and it is silent.
[ "$n" = 10 ] || { echo "FATAL: expected 10 live assemblers, got $n"; exit 9; }
# ARM 2: NEGATIVE CONTROL on the assertion itself.  A name no triple uses must
# NOT run; if this also reports OK the test above proves nothing.
if "$OUT/bin/nosuch-triple-as" --version > /dev/null 2>&1; then
  echo "FATAL: negative control RAN -- the executability test is vacuous"; exit 9
fi
echo "negative control: nosuch-triple-as correctly does not run"
