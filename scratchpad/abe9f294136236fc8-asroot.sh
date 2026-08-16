#!/bin/sh
# Build real cross assemblers for a list of triples AND KEEP THEM.
#
# WHY THIS EXISTS RATHER THAN `a7ee6ca7c923e4a58-astry.sh'.  That script
# builds with `nix-build --no-out-link' and symlinks `$OUT/bin/<triple>-as'
# straight into `/nix/store'.  With no gc root, the store paths are collected,
# and what is left is a directory full of DANGLING SYMLINKS -- which is the
# exact shape INSTRUMENTS.md warns about for `OK':
#
#     `OK' asserts the binary RUNS, not that a path exists: a dangling symlink
#     or a wrong-arch binary is exactly the shape that falls back to the host
#     `as' three layers away, which is the defect GUARD 3c exists for
#     (~10,000 results per target).
#
# Measured live, this task: all 39 assemblers in `/tmp/tools-a7ee6ca7c923e4a58
# /bin' had been collected between the board being taken and this task
# starting.  `ls' shows 39 files, `ls -l' shows 39 plausible store paths, and
# every one is gone.  The board itself is unaffected -- it ran while they
# existed -- but any later run reusing that directory would have had
# `target-specs' probe a missing `as'.
#
# So: `--out-link' into `$OUT/gcroots/<triple>', which IS a gc root, and then
# symlink through it.  The cost is one extra indirection and the benefit is
# that the set survives a `nix-collect-garbage'.
#
# usage: abe9f294136236fc8-asroot.sh <triple-list-file> <outdir>
set -u
NP="${NP:-$HOME/src/nixos-configuration/dep/nixpkgs}"
LIST=${1:?triple list file}
OUT=${2:?output dir}
[ -s "$LIST" ] || { echo "FATAL: $LIST empty/missing"; exit 9; }
[ -d "$NP" ] || { echo "FATAL: no nixpkgs at $NP"; exit 9; }
mkdir -p "$OUT/bin" "$OUT/log" "$OUT/gcroots"

# PIN THE SUBSTITUTER -- see astry.sh: the ambient config lists caches that are
# unreachable here and nix retries each 5x at 15s PER DERIVATION.
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"

nok=0; nev=0; nbd=0
for t in $(grep -v '^#' "$LIST" | grep .); do
  log="$OUT/log/$t.log"
  drv=$(nix-instantiate $NIXOPT -I "nixpkgs=$NP" -E \
        "with import <nixpkgs> { crossSystem = { config = \"$t\"; }; }; buildPackages.binutils-unwrapped" \
        2> "$log")
  if [ -z "$drv" ]; then
    printf '%-30s EVAL-FAIL   %s\n' "$t" "$(grep -m1 -i 'error' "$log" | cut -c1-80)"
    nev=$((nev+1)); continue
  fi
  # THE GC ROOT IS THE POINT OF THIS SCRIPT.
  st=$(nix-build $NIXOPT --out-link "$OUT/gcroots/$t" "$drv" 2>> "$log")
  if [ -z "$st" ] || [ ! -d "$OUT/gcroots/$t" ]; then
    printf '%-30s BUILD-FAIL  %s\n' "$t" "$(grep -m1 -i 'error' "$log" | cut -c1-80)"
    nbd=$((nbd+1)); continue
  fi
  # The prefix nixpkgs used need NOT equal $t (config.sub canonicalisation);
  # assuming it does is taa-tools.sh's recorded trap.
  pfx=$(ls "$OUT/gcroots/$t/bin" | sed -n 's/-as$//p' | head -1)
  if [ -z "$pfx" ] || [ ! -x "$OUT/gcroots/$t/bin/$pfx-as" ]; then
    printf '%-30s BUILD-FAIL  built but no *-as in gcroots/%s/bin\n' "$t" "$t"
    nbd=$((nbd+1)); continue
  fi
  if ! "$OUT/gcroots/$t/bin/$pfx-as" --version > "$OUT/log/$t.ver" 2>&1; then
    printf '%-30s BUILD-FAIL  %s-as does not execute\n' "$t" "$pfx"
    nbd=$((nbd+1)); continue
  fi
  for tool in as ld nm ar ranlib objdump objcopy strip readelf; do
    [ -x "$OUT/gcroots/$t/bin/$pfx-$tool" ] || continue
    ln -sf "$OUT/gcroots/$t/bin/$pfx-$tool" "$OUT/bin/$t-$tool"
  done
  printf '%-30s OK          prefix=%-28s %s\n' "$t" "$pfx" \
    "$(head -1 "$OUT/log/$t.ver" | sed 's/.*) //')"
  nok=$((nok+1))
done
echo
echo "OK=$nok EVAL-FAIL=$nev BUILD-FAIL=$nbd"
