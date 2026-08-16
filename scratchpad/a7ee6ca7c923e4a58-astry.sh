#!/bin/sh
# Can nixpkgs produce a REAL cross assembler for an arbitrary target triple?
#
# taa-tools.sh uses `pkgsCross.<attr>', a hand-curated attribute set, and
# TAA-BOARD 4b concluded "nixpkgs has no binutils for visium or xtensa (0 of
# 27,157 attributes)".  That is a statement about the ATTRIBUTE SET, not about
# binutils.  An arbitrary triple can be requested directly via
# `crossSystem.config', which is the route this script measures.
#
# THE DISTINCTION THIS SCRIPT EXISTS TO KEEP (PRINCIPLES 4, and the brief's
# own instruction): "no cross as packaged" and "the compiler fails on every
# input" are different findings.  This script only ever answers the FIRST, and
# it separates the two ways of failing at it:
#
#   EVAL-FAIL   nixpkgs cannot even describe the triple (lib.systems)
#   BUILD-FAIL  it evaluates, binutils does not build/substitute for it
#   OK          an executable <prefix>-as exists, and `-as --version' RUNS
#
# `binutils-unwrapped', NOT `binutils'.  Measured: the WRAPPED cross binutils
# depends on the target libc, so `or1k-elf' BUILD-FAILs inside newlib -- which
# would have been recorded as "no assembler for or1k" when in fact the
# assembler builds fine.  A libc is not needed to assemble, and the brief's
# axis is explicitly the class that needs no libc.
#
# `OK' asserts the binary EXECUTES, not merely that a path exists: a dangling
# symlink or a wrong-arch binary is exactly the shape that silently falls back
# to the host `as' three layers away (taa-tools.sh's own naming trap).
set -u
NP="${NP:-$HOME/src/nixos-configuration/dep/nixpkgs}"
LIST=${1:?triple list file}
OUT=${2:?output dir}
[ -s "$LIST" ] || { echo "FATAL: $LIST empty/missing"; exit 9; }
[ -d "$NP" ] || { echo "FATAL: no nixpkgs at $NP"; exit 9; }
mkdir -p "$OUT/bin" "$OUT/log"

# PIN THE SUBSTITUTER.  Measured: the ambient config lists caches on
# `obsidian.webhop.org' that are unreachable here, and nix retries each 5 times
# at a 15s timeout -- PER DERIVATION.  The first run spent ~15 minutes on ONE
# target without compiling anything, which reads as "cross binutils are
# expensive to build" when it is entirely network dead time.
# taa-specs.sh already pins cache.nixos.org for the same reason.
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"

nok=0; nev=0; nbd=0
for t in $(grep -v '^#' "$LIST" | grep .); do
  log="$OUT/log/$t.log"
  drv=$(nix-instantiate $NIXOPT -I "nixpkgs=$NP" -E \
        "with import <nixpkgs> { crossSystem = { config = \"$t\"; }; }; buildPackages.binutils-unwrapped" \
        2> "$log")
  if [ -z "$drv" ]; then
    printf '%-26s EVAL-FAIL   %s\n' "$t" "$(grep -m1 -i 'error' "$log" | cut -c1-90)"
    nev=$((nev+1)); continue
  fi
  st=$(nix-build $NIXOPT --no-out-link "$drv" 2>> "$log")
  if [ -z "$st" ]; then
    printf '%-26s BUILD-FAIL  %s\n' "$t" "$(grep -m1 -i 'error' "$log" | cut -c1-90)"
    nbd=$((nbd+1)); continue
  fi
  # find the actual prefix nixpkgs used -- it need NOT equal $t (config.sub
  # canonicalisation), and assuming it does is taa-tools.sh's recorded trap.
  pfx=$(ls "$st/bin" 2>/dev/null | sed -n 's/-as$//p' | head -1)
  if [ -z "$pfx" ] || [ ! -x "$st/bin/$pfx-as" ]; then
    printf '%-26s BUILD-FAIL  built but no *-as in %s/bin\n' "$t" "$st"
    nbd=$((nbd+1)); continue
  fi
  # IT MUST RUN.  Existence is not execution.
  if ! "$st/bin/$pfx-as" --version > "$OUT/log/$t.ver" 2>&1; then
    printf '%-26s BUILD-FAIL  %s-as does not execute\n' "$t" "$pfx"
    nbd=$((nbd+1)); continue
  fi
  for tool in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -x "$st/bin/$pfx-$tool" ] || continue
    ln -sf "$st/bin/$pfx-$tool" "$OUT/bin/$t-$tool"
  done
  printf '%-26s OK          prefix=%-26s %s\n' "$t" "$pfx" \
    "$(head -1 "$OUT/log/$t.ver" | sed 's/.*) //')"
  nok=$((nok+1))
done
echo
echo "OK=$nok EVAL-FAIL=$nev BUILD-FAIL=$nbd"
