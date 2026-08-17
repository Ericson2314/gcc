#!/bin/sh
# The per-target `target-specs' probe for the i686 row, in the shape
# `a660907426e03e4e9-specs.sh' uses for arm.
#
# TWO TARGETS ARE PROBED, NOT ONE, AND THE SECOND IS THE ARM THAT CAN FAIL.
# 113b measured that without real cross tools configure falls back to the
# build machine's own `as' and writes a file that NAMES the target while
# DESCRIBING the host, with every name- and path-based check green.  The arm
# row caught that by requiring the two specs-configs to DIFFER.
#
# ON THIS ROW THAT ARM IS WEAKER AND THE WEAKNESS IS THE POINT: the host
# assembler is an x86 assembler, so an i686 probe that fell back to it would
# still produce a plausible file.  So this script keeps the differ-arm (against
# aarch64, whose fallback file would be visibly the host's) AND adds a direct
# arm: the i686 specs-config must NAME the i686 cross binutils store path.  A
# fallback names the nix gcc-wrapper's bin instead, which is a different
# string, so the arm has a failing direction.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the i686 tools dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
TI=i686-unknown-linux-gnu
TQ=aarch64-unknown-linux-gnu
HDRQ=${HDRQ:-/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include}

HI=$(cat "$TOOLS/$TI.hdr") || exit 9
[ -d "$HI" ] || { echo "FATAL: no i686 headers $HI"; exit 9; }
[ -x "$TOOLS/bin/$TI-as" ] || { echo "FATAL: no $TOOLS/bin/$TI-as"; exit 9; }
[ -d "$HDRQ" ] || { echo "FATAL: no aarch64 headers $HDRQ"; exit 9; }

cmds="cd $B/gcc && make multi-target-specs && cd $B"
cmds="$cmds && make configure-target-specs-$TI TOOLS_DIR_FOR_$TI=$TOOLS/bin \
  TARGET_SPECS_FLAGS_FOR_$TI=--with-native-system-header-dir=$HI"
cmds="$cmds && make configure-target-specs-$TQ \
  TARGET_SPECS_FLAGS_FOR_$TQ=--with-native-system-header-dir=$HDRQ"

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    command -v $TQ-as
    PATH=$TOOLS/bin:\$PATH; export PATH
    command -v $TI-as
    $cmds
  " > "$B/specs.out" 2> "$B/specs.err"
rc=$?
echo "specs rc=$rc"
tail -15 "$B/specs.err"
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
echo "-- specs-config per target (identity, not a statistic):"
n=0
for T in $TI $TQ; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    n=$((n+1))
    printf '  %-34s wc -l %s  grep -c . %s  md5 %s\n' "$T" \
      "$(wc -l < "$F")" "$(grep -c . "$F")" "$(md5sum < "$F" | cut -c1-12)"
  else
    printf '  %-34s ABSENT\n' "$T"
  fi
done
[ "$n" = 2 ] || { echo "FATAL: only $n of 2 specs-configs written"; exit 9; }
FI="$B/lib/gcc/$VER/$TI/specs-config"
a=$(md5sum < "$FI")
b=$(md5sum < "$B/lib/gcc/$VER/$TQ/specs-config")
[ "$a" != "$b" ] || { echo "FATAL: i686 and aarch64 specs-config are IDENTICAL -- a probe fell back to the host tools"; exit 9; }
echo "-- md5s differ"
BU=$(readlink -f "$TOOLS/bin/$TI-as")
BUD=$(dirname "$BU")
grep -q "$BUD" "$FI" \
  || { echo "FATAL: $FI does not name $BUD -- the i686 probe did not use the i686 binutils";
       grep -n 'as\b\|_as=' "$FI" | head -10; exit 9; }
echo "-- the i686 specs-config names the i686 binutils: $BUD"
