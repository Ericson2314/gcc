#!/bin/sh
# mt-native-tools.sh -- a `<triple>-<tool>' directory for the target that IS
# this host, so `mtcheck.sh' GUARD 3c can be satisfied without inventing
# anything.
#
# GUARD 3c refuses to run unless `MT_TOOLS_<triple>' names that target's own
# binutils, because `<builddir>/gcc/as' is a shim around the HOST assembler and
# feeding s390x assembly to it produced ~10,000 failures per target that are
# not compiler defects.  For `x86_64-pc-linux-gnu' on an x86_64 host the host
# assembler IS the target's assembler -- so the guard is satisfiable exactly,
# not relaxed.  `taa-tools.sh' builds real cross binutils for the other
# targets; this is the one case where none need building, and it must be a
# SEPARATE script rather than a fallback inside the prober, for the same
# structural reason PRINCIPLES gives for the pinned-vs-probed spec modes: a
# conservative-default branch inside the guard would be the same silent wrong
# answer with better manners.
#
# NON-VACUITY: the linked `as' is required to ASSEMBLE a real function and the
# resulting object is required to name the right machine.  A dangling symlink
# and a wrong-arch binary both pass `test -x'.
#
# usage: mt-native-tools.sh <outdir> [triple]     default x86_64-pc-linux-gnu
set -eu
OUT=${1:?output dir}
T=${2:-x86_64-pc-linux-gnu}
mkdir -p "$OUT/bin"
n=0
for t in as ld nm ar ranlib objcopy objdump strip readelf; do
  p=$(command -v "$t" 2>/dev/null || true)
  [ -n "$p" ] || continue
  ln -sf "$p" "$OUT/bin/$T-$t"
  n=$((n + 1))
done
[ -x "$OUT/bin/$T-as" ] || { echo "FATAL: no host \`as' to link as $T-as"; exit 9; }
[ -x "$OUT/bin/$T-readelf" ] || { echo "FATAL: no host \`readelf'"; exit 9; }

# ARM: it must actually assemble, and the object must name the machine.
W=$(mktemp -d); trap 'rm -rf "$W"' 0
printf '\t.text\n\t.globl mt_probe\nmt_probe:\n\tret\n' > "$W/p.s"
"$OUT/bin/$T-as" -o "$W/p.o" "$W/p.s" 2> "$W/err" \
  || { echo "FATAL: $T-as rejected a trivial input:"; sed -n 1,3p "$W/err"; exit 9; }
mach=$("$OUT/bin/$T-readelf" -h "$W/p.o" | sed -n 's/.*Machine: *//p')
[ -n "$mach" ] || { echo "FATAL: $T-readelf named no machine"; exit 9; }
echo "$OUT/bin: $n tools for $T; assembles into: $mach"
echo "MT_TOOLS_$(printf '%s' "$T" | tr - _)=$OUT/bin"
