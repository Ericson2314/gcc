#!/bin/sh
# RESPELL PASS KEYED ON THE **CANONICAL** TRIPLE.
#
# a7ee6ca7c923e4a58-astry2.sh does the same job but keys on the SHORT triple
# spellings of `backends-47.txt' (`sh-elf', `mips64-elf', `avr-elf'), so it
# installs `$OUT/bin/sh-elf-as'.  The build's specs rule looks for
# `$(1)-as' where $(1) is a member of MT_TARGET_SUBDIRS -- i.e. the
# config.sub-CANONICAL spelling, `sh-unknown-elf'.  A tools dir populated by
# astry2 therefore satisfies no rule at all, and the failure is the quiet
# direction: the rule reports "cannot find `sh-unknown-elf-as'" while an
# executable sh assembler sits in the same directory under another name.
# One name, several authorities -- in the tooling, again.
#
# So the left-hand column here is exactly what `grep '^MT_TARGET_SUBDIRS'
# <builddir>/Makefile' prints, and nothing else.  The right-hand column is
# spellings of THE SAME TARGET that nixpkgs' lib.systems can parse.
#
# `binutils-unwrapped', never `binutils': the wrapped cross depends on the
# target libc, so `or1k' fails inside newlib and gets recorded as "no
# assembler" when the assembler builds perfectly.  Assembling needs no libc.
#
# A CANDIDATE MUST BE THE SAME TARGET, NOT A NEIGHBOUR.  astry2 records that
# `powerpc64le-*' was once offered as a respelling of `powerpc64-*' -- the
# other ENDIANNESS, installed under a big-endian name.  Nothing below changes
# endianness, word size or ABI; where I was unsure the row is simply absent,
# which reports as STILL-EVAL-FAIL and is an honest gap rather than a wrong
# assembler wearing the right name.
set -u
NP="${NP:-$HOME/src/nixos-configuration/dep/nixpkgs}"
OUT=${1:?output dir}
NIXOPT="--substituters https://cache.nixos.org/ --option connect-timeout 5"
[ -d "$NP" ] || { echo "FATAL: no nixpkgs at $NP"; exit 9; }
mkdir -p "$OUT/bin" "$OUT/log3"

CAND="
microblaze-xilinx-elf:microblaze-none-elf microblaze-unknown-none-elf
rx-unknown-elf:rx-none-elf rx-unknown-elf
sh-unknown-elf:sh4-elf sh4-unknown-linux-gnu
arm-unknown-eabi:arm-none-eabi armv7a-none-eabi
avr-unknown-elf:avr-unknown-none avr-none
mips64-unknown-elf:mips64-unknown-linux-gnuabi64
or1k-unknown-elf:or1k-none-elf or1k-unknown-elf
s390x-ibm-linux-gnu:s390x-unknown-linux-gnu
"

nfix=0; nstill=0; nskip=0
OIFS=$IFS; IFS='
'
for row in $CAND; do
  IFS=$OIFS
  orig=${row%%:*}; cands=${row#*:}
  if [ -x "$OUT/bin/$orig-as" ]; then
    printf '%-26s ALREADY\n' "$orig"; nskip=$((nskip + 1))
    IFS='
'
    continue
  fi
  got=
  for c in $(echo "$cands" | tr ' ' '\n' | grep .); do
    log="$OUT/log3/$orig-$c.log"
    drv=$(nix-instantiate $NIXOPT -I "nixpkgs=$NP" -E \
          "with import <nixpkgs> { crossSystem = { config = \"$c\"; }; }; buildPackages.binutils-unwrapped" \
          2> "$log")
    [ -n "$drv" ] || continue
    st=$(nix-build $NIXOPT --no-out-link "$drv" 2>> "$log")
    [ -n "$st" ] || continue
    pfx=$(ls "$st/bin" 2>/dev/null | sed -n 's/-as$//p' | head -1)
    [ -n "$pfx" ] && [ -x "$st/bin/$pfx-as" ] || continue
    # EXISTENCE IS NOT EXECUTION.
    "$st/bin/$pfx-as" --version > "$OUT/log3/$orig.ver" 2>&1 || continue
    for t in as ld nm ar ranlib objdump objcopy strip readelf; do
      [ -x "$st/bin/$pfx-$t" ] || continue
      ln -sf "$st/bin/$pfx-$t" "$OUT/bin/$orig-$t"
    done
    got=$c; break
  done
  if [ -n "$got" ]; then
    printf '%-26s OK-VIA-RESPELL  %-34s %s\n' "$orig" "$got" \
      "$(head -1 "$OUT/log3/$orig.ver" | sed 's/.*) //')"
    nfix=$((nfix + 1))
  else
    printf '%-26s STILL-EVAL-FAIL\n' "$orig"; nstill=$((nstill + 1))
  fi
  IFS='
'
done
IFS=$OIFS
echo
echo "OK-VIA-RESPELL=$nfix STILL-EVAL-FAIL=$nstill ALREADY=$nskip"
