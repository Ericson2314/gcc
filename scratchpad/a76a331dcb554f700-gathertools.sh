#!/bin/sh
# a76a331dcb554f700 -- BUILD A TOOLS DIR OUT OF BINARIES THAT ACTUALLY RUN.
#
# THE DEFECT THIS EXISTS FOR, MEASURED.  The inherited
# /tmp/tools-a7d26223eefcfa725 has 45 `<triple>-as' and a board quoting
# "45 cross `as', canonical names, EVERY ONE EXECUTED".  Re-run today, EIGHT
# of them do not execute:
#
#   m68k microblaze mmix msp430 powerpc64 rx sh sparc64
#   error while loading shared libraries: libopcodes-2.46.so
#
# They were gathered BY COPY out of nix store paths; the binaries are
# dynamically linked against libopcodes/libbfd in their own store output, and
# a copy leaves that behind (and the store path has since been collected).
# "Every one executed" was true when taken and is not a property a copy keeps.
# So: SYMLINK, never copy, and re-assert execution at use time.
#
# Falls back across every inherited tools dir, taking the first entry that
# RUNS -- which is the only test that distinguishes the eight above from the
# thirty-seven.
set -u
OUT=${1:?output dir}
mkdir -p "$OUT"
srcs=$(ls -d /tmp/tools-* 2>/dev/null | grep -v "^$OUT\$")
got=0; miss=
for T in $(cat "${2:?file of triples}"); do
  found=
  for s in $srcs; do
    [ -x "$s/$T-as" ] || continue
    "$s/$T-as" --version 2>/dev/null | head -1 | grep -q "GNU assembler" || continue
    # A SYMLINK: the binary keeps its own RPATH and its store neighbours.
    ln -sf "$(readlink -f "$s/$T-as")" "$OUT/$T-as"
    found=$s
    break
  done
  if [ -n "$found" ]; then
    got=$((got+1))
  else
    miss="$miss $T"
  fi
done
echo "as that RUN: $got"
[ -z "$miss" ] || echo "still missing:$miss"
