#!/bin/sh
# Re-shim astry's cross tools under the CANONICAL triple names.
#
# THE TRAP, REPRODUCED RATHER THAN AVOIDED.  taa-tools.sh's header records it:
# nixpkgs names the tools after the triple you asked for, `target-specs' looks
# them up by the name `config.sub' canonicalises to, and the two differ --
# `alpha-linux-gnu' vs `alpha-unknown-linux-gnu', `s390x-unknown-linux-gnu' vs
# `s390x-ibm-linux-gnu'.  I passed the ORIGINAL spelling and target-specs
# reported "cannot find alpha-unknown-linux-gnu-as" for 42 of 43 targets, which
# reads as "no cross assembler exists" when the assembler was sitting in the
# tools dir under its other name.  The symptom surfaces three layers from the
# cause, exactly as that header warns.
#
# A shim here is a RENAME OF A REAL CROSS TOOL, never a link to the host's.
# usage: SRC=<srcdir> canonshim.sh <astry outdir>
set -u
SRC=${SRC:?set SRC to a gcc srcdir (for config.sub)}
OUT=${1:?astry output dir}
[ -d "$OUT/bin" ] || { echo "FATAL: no $OUT/bin"; exit 9; }
[ -x "$SRC/config.sub" ] || { echo "FATAL: no $SRC/config.sub"; exit 9; }

n=0; same=0
for f in "$OUT"/bin/*-as; do
  [ -e "$f" ] || continue
  b=$(basename "$f"); orig=${b%-as}
  canon=$(sh "$SRC/config.sub" "$orig" 2>/dev/null)
  [ -n "$canon" ] || { echo "WARN: config.sub refused $orig"; continue; }
  if [ "$canon" = "$orig" ]; then same=$((same+1)); continue; fi
  for t in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -e "$OUT/bin/$orig-$t" ] || continue
    ln -sf "$(readlink -f "$OUT/bin/$orig-$t")" "$OUT/bin/$canon-$t"
  done
  # ASSERT THE SHIM RUNS.  A dangling link is the shape that silently falls
  # back to the host `as' with no diagnostic.
  if "$OUT/bin/$canon-as" --version > /dev/null 2>&1; then
    printf '  %-26s -> %s\n' "$orig" "$canon"; n=$((n+1))
  else
    echo "FATAL: shim $canon-as does not execute"; exit 9
  fi
done
echo "-- $n renamed, $same already canonical"
