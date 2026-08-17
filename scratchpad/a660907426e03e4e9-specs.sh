#!/bin/sh
# taa-specs.sh restricted to the two targets this task needs -- x86_64 (the
# codegen bar) and arm (the row being added) -- and with the arm entry added.
#
# The md5s are printed and must DIFFER: #113b measured that without real cross
# tools configure falls back to the build machine's own `as' and writes a file
# that NAMES the target while DESCRIBING x86_64, with every name- and path-based
# check green.  The line count is the stable part (232/224); the md5 is a
# function of the probing toolchain's paths and is NOT a bar.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to the tools dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
TX=x86_64-pc-linux-gnu
TA=arm-unknown-linux-gnueabihf

HA=$(cat "$TOOLS/$TA.hdr") || exit 9
[ -d "$HA" ] || { echo "FATAL: no arm headers $HA"; exit 9; }
[ -x "$TOOLS/bin/$TA-as" ] || { echo "FATAL: no $TOOLS/bin/$TA-as"; exit 9; }

cmds="cd $B/gcc && make multi-target-specs && cd $B"
cmds="$cmds && make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
  TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX"
cmds="$cmds && make configure-target-specs-$TA TOOLS_DIR_FOR_$TA=$TOOLS/bin \
  TARGET_SPECS_FLAGS_FOR_$TA=--with-native-system-header-dir=$HA"

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    PATH=$TOOLS/bin:\$PATH; export PATH
    $cmds
  " > "$B/specs.out" 2> "$B/specs.err"
rc=$?
echo "specs rc=$rc"
tail -15 "$B/specs.err"
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
echo "-- specs-config per target (identity, not a statistic):"
n=0
for T in $TX $TA; do
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
a=$(md5sum < "$B/lib/gcc/$VER/$TX/specs-config")
b=$(md5sum < "$B/lib/gcc/$VER/$TA/specs-config")
[ "$a" != "$b" ] || { echo "FATAL: x86_64 and arm specs-config are IDENTICAL -- the arm probe fell back to the host tools"; exit 9; }
echo "-- md5s differ: the arm probe used its own toolchain"
