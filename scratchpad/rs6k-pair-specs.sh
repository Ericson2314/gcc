#!/bin/sh
set -u
B=/tmp/b-a5fb19dec8368eaf6-pair
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T2=x86_64-pc-linux-gnu
HDR2=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
tail -5 "$B/specs.err"
