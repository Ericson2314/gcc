#!/bin/sh
# #150 -- IS THE OUTPUT RIGHT, not merely "where did it stop".
#
# PRINCIPLES section 4, in capitals: "WHERE DOES IT ICE IS NOT THE
# MEASUREMENT.  IS THE OUTPUT RIGHT IS."  A wall handed between agents as an
# aarch64 ICE turned out, at branch HEAD, to COMPILE and exit 0 while emitting
#
#     str  x19, [x7, -32]!
#
# with matching wrong CFI -- i386's STACK_POINTER_REGNUM and
# FRAME_POINTER_REGNUM (7 and 19) used as aarch64's.  The loud failure had
# become a quiet one, and an ICE-tracking harness would have recorded that as
# progress.  So a disappeared ICE is treated as SUSPICIOUS until the emitted
# assembly has been read by a real assembler for that target.
#
# usage: t150-asm.sh <builddir> <tag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?tag}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
A="$B/t150-$TAG-aarch64-unknown-linux-gnu.s"
X="$B/t150-$TAG-x86_64-pc-linux-gnu.s"

# ARM 0: the files must exist and be non-trivial.  Not `test -s': a truncated
# .s is non-empty.  Require a plausible instruction count.
for f in "$A" "$X"; do
  [ -f "$f" ] || { echo "FATAL: no $f -- run t150-ice.sh first"; exit 9; }
done
na=$(grep -c . "$A"); nx=$(grep -c . "$X")
echo "arm 0: aarch64 .s $na lines, x86_64 .s $nx lines"
[ "$na" -gt 100 ] || { echo "REFUSING TO SCORE: aarch64 .s is only $na lines"; exit 9; }

echo
echo "== arm 1: does the aarch64 output contain x86 registers or mnemonics?"
# A cheap, decisive discriminator.  If the primary's back end were still
# answering, i386 register names would appear.
bad=$(grep -cE '%[re](ax|bx|cx|dx|si|di|sp|bp)|\bpushq\b|\bmovq\b|\bleaq\b' "$A" || true)
echo "  x86 register/mnemonic hits in the aarch64 .s: $bad   (want 0)"
good=$(grep -cE '\b(x[0-9]+|w[0-9]+|sp)\b' "$A" || true)
echo "  aarch64 register hits: $good   (want many)"
[ "$good" -gt 20 ] || { echo "REFUSING TO SCORE: that is not aarch64 assembly"; exit 9; }

echo
echo "== arm 2: a REAL aarch64 assembler must accept it"
# PRINCIPLES: a genuine cross assembler is one nix-shell argument away; the
# fake-as shim and "the strict check refuses aarch64" are both avoidable.
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    aarch64-unknown-linux-gnu-as -o $B/t150-$TAG-aarch64.o $A
  " > "$B/t150-$TAG-as.out" 2> "$B/t150-$TAG-as.err"
rc=$?
echo "  aarch64-as rc=$rc"
if [ "$rc" = 0 ]; then
  echo "  object: $(ls -la "$B/t150-$TAG-aarch64.o" | awk '{print $5}') bytes"
  nix-shell -I "nixpkgs=$NP" \
    -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
    --substituters 'https://cache.nixos.org/' --run \
    "aarch64-unknown-linux-gnu-readelf -h $B/t150-$TAG-aarch64.o" 2>/dev/null \
    | grep -E 'Machine|Class' | sed 's/^/    /'
else
  head -10 "$B/t150-$TAG-as.err" | sed 's/^/    /'
fi
