#!/bin/sh
# SECOND PASS: re-probe the EVAL-FAIL targets under triple spellings nixpkgs
# can actually parse.
#
# WHY THIS PASS EXISTS.  `crossSystem.config' goes through `lib.systems.parse',
# whose CPU table has 50 entries.  A first-pass EVAL-FAIL therefore means one
# of TWO completely different things, and pass 1 cannot tell them apart:
#
#   (a) nixpkgs does not know this CPU at all          -- a real packaging gap
#   (b) nixpkgs knows the CPU under ANOTHER SPELLING   -- my triple was wrong
#
# (b) is not hypothetical and it is not rare: `powerpc64' IS in the CPU table
# while `powerpc64-linux-gnu' EVAL-FAILs, and `sh4' is in the table while gcc's
# back end is spelled `sh'.  Recording (b) as "no cross assembler for this back
# end" would be the same class of confident-wrong number as the
# `alpha-linux-gnu-as' / `alpha-unknown-linux-gnu-as' mismatch: an absence
# reported as a measurement.
#
# So each candidate below is a DIFFERENT SPELLING OF THE SAME TARGET, never a
# different target.  `sh4-elf' for gcc's `sh' is the one that deserves a second
# look -- sh4 is a real member of the sh family and its assembler is the sh
# assembler, but if a run ever depends on the distinction, say so.
#
# The verdict vocabulary is pass 1's, unchanged, plus the spelling that worked.
#
# A CANDIDATE MUST NEVER BE A DIFFERENT TARGET WEARING THE SAME BACK END'S
# NAME, AND THIS LIST BROKE THAT RULE.  `powerpc64-linux-gnu' used to offer
# `powerpc64le-unknown-linux-gnu' as its second spelling.  That is not a
# respelling, it is the OTHER ENDIANNESS -- so a run that fell through to it
# installed a LITTLE-endian `as' under a BIG-endian name, which is this
# project's root bug (one name, several authorities, no diagnostic) inside the
# tooling that exists to prevent it.  The recorded rs6000 recovery failure was
# this line.
#
# The real cause was never `lib.systems' at all.  `powerpc64-unknown-linux-gnu'
# fails with
#     error: The "gnu" ABI is ambiguous on big-endian 64-bit PowerPC.
#            Use "gnuabielfv2" or "gnuabielfv1" instead.
# which is a DIFFERENT error from `Unknown CPU type', and pass 1 collapsed both
# into one `EVAL-FAIL' verdict.  `powerpc64-unknown-linux-gnuabielfv2'
# evaluates, builds, and gives ELF64 / big endian / PowerPC64 -- verified with
# `agent-acda89931a903ec27-asverify.sh'.  Collapsing two distinct errors into
# one verdict is what hid the largest testsuite directory in the tree for a
# whole sweep.
set -u
NP="${NP:-$HOME/src/nixos-configuration/dep/nixpkgs}"
OUT=${1:?output dir}
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
[ -d "$OUT/bin" ] || { echo "FATAL: run astry.sh first ($OUT/bin absent)"; exit 9; }
mkdir -p "$OUT/log2"

# original-triple <TAB> candidate spellings, in preference order.
# Only targets whose gcc cpu_type has a plausible nixpkgs counterpart appear.
CAND="
arc-elf32:arc-none-elf arc-elf
arm-eabi:arm-none-eabi armv7a-none-eabi armv7l-unknown-linux-gnueabihf
powerpc64-linux-gnu:powerpc64-unknown-linux-gnuabielfv2 powerpc64-unknown-linux-gnuabielfv1
sh-elf:sh4-elf sh4-unknown-linux-gnu
mips64-elf:mips64-unknown-linux-gnuabi64 mips64el-unknown-linux-gnuabi64
sparc64-linux:sparc64-unknown-linux-gnu
vax-linux-gnu:vax-unknown-linux-gnu
msp430-elf:msp430-none-elf msp430-unknown-elf
mmix-knuth-mmixware:mmix-unknown-elf
or1k-elf:or1k-none-elf or1k-unknown-elf
avr-elf:avr-unknown-none avr-none
pdp11-aout:pdp11-unknown-aout
alpha-linux-gnu:alpha-unknown-linux-gnu
"

# SPLIT ON LINES, NOT WHITESPACE.  The first version wrote `for row in $CAND',
# which word-splits on spaces, so every CANDIDATE spelling became its own
# `orig' row: the output contained lines like
# `armv7a-none-eabi OK-VIA-RESPELL armv7a-none-eabi' -- a target respelling
# itself.  The recoveries were real but the ATTRIBUTION was not, and a table
# built from it would have credited spellings to the wrong back ends.
nfix=0; nstill=0
OIFS=$IFS; IFS='
'
for row in $CAND; do
  IFS=$OIFS
  orig=${row%%:*}; cands=${row#*:}
  # skip anything pass 1 already got
  [ -x "$OUT/bin/$orig-as" ] && continue
  got=
  for c in $(echo "$cands" | tr ' ' '\n' | grep .); do
    log="$OUT/log2/$orig-$c.log"
    drv=$(nix-instantiate $NIXOPT -I "nixpkgs=$NP" -E \
          "with import <nixpkgs> { crossSystem = { config = \"$c\"; }; }; buildPackages.binutils-unwrapped" \
          2> "$log")
    [ -n "$drv" ] || continue
    st=$(nix-build $NIXOPT --no-out-link "$drv" 2>> "$log")
    [ -n "$st" ] || continue
    pfx=$(ls "$st/bin" 2>/dev/null | sed -n 's/-as$//p' | head -1)
    [ -n "$pfx" ] && [ -x "$st/bin/$pfx-as" ] || continue
    "$st/bin/$pfx-as" --version > /dev/null 2>&1 || continue
    for t in as ld nm ar ranlib objdump objcopy strip readelf; do
      [ -x "$st/bin/$pfx-$t" ] || continue
      ln -sf "$st/bin/$pfx-$t" "$OUT/bin/$orig-$t"
    done
    got=$c; break
  done
  if [ -n "$got" ]; then
    printf '%-26s OK-VIA-RESPELL  %s\n' "$orig" "$got"; nfix=$((nfix+1))
  else
    printf '%-26s STILL-EVAL-FAIL (no spelling nixpkgs accepts)\n' "$orig"
    nstill=$((nstill+1))
  fi
  IFS='
'
done
IFS=$OIFS
echo
echo "recovered-by-respelling=$nfix still-unavailable=$nstill"
