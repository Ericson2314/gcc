#!/bin/sh
# The FIVE back ends still with no assembler that are ordinary binutils
# targets.  gcn and nvptx are deliberately absent: they use LLVM's assembler
# and `ptxas', so for them "no GNU cross as" is NOT-APPLICABLE, a third verdict
# distinct from "not probed" and from "conservative default".
#
# Keyed on the CANONICAL triple -- the left column is what
# `grep '^MT_TARGET_SUBDIRS' <builddir>/Makefile' prints and what the specs
# rule looks for.  A tool installed under a short spelling satisfies no rule
# and falls back to the host assembler silently.
#
# TWO DIFFERENCES FROM `agent-aa44b9d995bd1c452-astry3.sh', both deliberate:
#
#  1. **COPY, NEVER SYMLINK.**  astry3 does `ln -sf` into a store path built
#     with `--no-out-link', i.e. a path with no GC root.  An inherited tools
#     dir has already been found to be entirely dangling symlinks for exactly
#     this reason -- and `ls` shows the names happily.  A copy cannot be
#     collected out from under a six-hour run.
#  2. **EXECUTE-ASSERT AFTER INSTALL**, at the final name, not only at the
#     store path.  The install is what the harness will use.
#
# A CANDIDATE MUST BE THE SAME TARGET, NOT A NEIGHBOUR.  No row below changes
# endianness, word size or ABI (astry2 once offered `powerpc64le-*' as a
# respelling of `powerpc64-*' -- the other endianness under a big-endian name).
# Where I was unsure the row is simply absent, which reports STILL-EVAL-FAIL:
# an honest gap beats a wrong assembler wearing the right name.
set -u
NP="${NP:-$HOME/src/nixos-configuration/dep/nixpkgs}"
OUT=${1:?output dir}
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
[ -d "$NP" ] || { echo "FATAL: no nixpkgs at $NP"; exit 9; }
mkdir -p "$OUT" "$OUT/log4"

CAND="
powerpc64-unknown-linux-gnu:powerpc64-unknown-linux-gnu powerpc64-none-elf
sparc64-unknown-linux-gnu:sparc64-unknown-linux-gnu sparc64-none-elf
m68k-unknown-elf:m68k-none-elf m68k-unknown-linux-gnu
msp430-unknown-elf:msp430-none-elf msp430-unknown-none
mmix-knuth-mmixware:mmix-unknown-none mmix-none-elf
"

nfix=0; nstill=0; nskip=0
OIFS=$IFS; IFS='
'
for row in $CAND; do
  IFS=$OIFS
  orig=${row%%:*}; cands=${row#*:}
  if [ -x "$OUT/$orig-as" ]; then
    printf '%-30s ALREADY\n' "$orig"; nskip=$((nskip + 1))
    IFS='
'
    continue
  fi
  got=
  for c in $(echo "$cands" | tr ' ' '\n' | grep .); do
    log="$OUT/log4/$orig-$c.log"
    drv=$(nix-instantiate $NIXOPT -I "nixpkgs=$NP" -E \
          "with import <nixpkgs> { crossSystem = { config = \"$c\"; }; }; buildPackages.binutils-unwrapped" \
          2> "$log")
    [ -n "$drv" ] || continue
    st=$(nix-build $NIXOPT --no-out-link "$drv" 2>> "$log")
    [ -n "$st" ] || continue
    pfx=$(ls "$st/bin" 2>/dev/null | sed -n 's/-as$//p' | head -1)
    [ -n "$pfx" ] && [ -x "$st/bin/$pfx-as" ] || continue
    "$st/bin/$pfx-as" --version > "$OUT/log4/$orig.ver" 2>&1 || continue
    for t in as ld nm ar ranlib objdump objcopy strip readelf size strings; do
      [ -x "$st/bin/$pfx-$t" ] && cp -f "$st/bin/$pfx-$t" "$OUT/$orig-$t"
    done
    # EXECUTE-ASSERT AT THE INSTALLED NAME -- the one the harness will run.
    "$OUT/$orig-as" --version 2>&1 | grep -q 'GNU assembler' || continue
    got=$c; break
  done
  if [ -n "$got" ]; then
    printf '%-30s OK-VIA-RESPELL  %-30s %s\n' "$orig" "$got" \
      "$(head -1 "$OUT/log4/$orig.ver" | sed 's/.*) //')"
    nfix=$((nfix + 1))
  else
    printf '%-30s STILL-EVAL-FAIL\n' "$orig"; nstill=$((nstill + 1))
  fi
  IFS='
'
done
IFS=$OIFS
echo
echo "OK-VIA-RESPELL=$nfix STILL-EVAL-FAIL=$nstill ALREADY=$nskip"
