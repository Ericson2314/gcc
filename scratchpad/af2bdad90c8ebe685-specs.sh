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
# THE DIRECT ARM, AND THE FIRST VERSION OF IT WAS WRONG -- MEASURED.  It
# grepped the specs-config for the i686 binutils STORE PATH.  There is no
# store path in the file at all: specs-config records CAPABILITIES
# (`as_ix86_hle 1'), not tool locations, so the arm failed against a probe
# that had in fact used the right assembler.
#
# Nor do the capabilities discriminate on this row, which is the same weakness
# the tools script and sc-check.sh guard S4 record: the host assembler is an
# x86 assembler, so a fallback would report the SAME `as_ix86_*' answers.
# (Against aarch64 they differ completely -- as_ix86_* 1 vs 0 and
# as_aarch64_mabi 0 vs 1 -- which is what the md5 arm above is really seeing.)
#
# What does discriminate is the probe's own config.log, which records the
# assembler it resolved BY NAME.  A fallback records a bare `as'.
CL="$B/$TI/target-specs/config.log"
[ -f "$CL" ] || { echo "FATAL: no $CL -- the i686 probe left no configure log"; exit 9; }
sawas=$(sed -n 's/^gcc_cv_as=//p' "$CL" | head -1)
[ "$sawas" = "$TI-as" ] \
  || { echo "FATAL: the i686 probe resolved gcc_cv_as='$sawas', not $TI-as"; exit 9; }
echo "-- the i686 probe resolved gcc_cv_as=$sawas (not a bare \`as')"
grep -q '^as_ix86_hle 1$' "$FI" \
  || { echo "FATAL: $FI reports no ix86 assembler capabilities at all"; exit 9; }
