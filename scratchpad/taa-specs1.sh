#!/bin/sh
# One target's target-specs probe.  Separate from taa-specs.sh because the
# aggregate stops at the first failure and riscv64's post-check ICEs (see
# TAA-BOARD.md); the remaining targets must still be probed.
set -u
B=${B:?build dir}; TOOLS=${TOOLS:?tools dir}; T=${1:?target}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
H=$(cat "$TOOLS/$T.hdr")
[ -d "$H" ] || { echo "FATAL: no headers for $T"; exit 9; }
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    PATH=$TOOLS/bin:\$PATH; export PATH
    cd $B && make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS/bin \
      TARGET_SPECS_FLAGS_FOR_$T=--with-native-system-header-dir=$H
  " > "$B/specs-$T.out" 2> "$B/specs-$T.err"
echo "rc=$?"
tail -20 "$B/specs-$T.err"
F="$B/lib/gcc/17.0.0/$T/specs-config"
if [ -f "$F" ]; then
  printf '%-28s wc -l %s  grep -c . %s  md5 %s\n' "$T" "$(wc -l < "$F")" \
    "$(grep -c . "$F")" "$(md5sum < "$F" | cut -c1-12)"
else
  echo "$T: specs-config ABSENT"
fi
