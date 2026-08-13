#!/bin/sh
# rs6000 grind -- run the per-target target-specs probe.  Modelled on
# t135-specs.sh; the aarch64/ppc binutils are not decoration (see #113b: with
# the wrong `as' the file NAMES one target and DESCRIBES another and every
# name-based check passes).
set -u
B=/tmp/b-a5fb19dec8368eaf6
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T2=x86_64-pc-linux-gnu
T3=powerpc64le-unknown-linux-gnu
HDR2=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.powernv.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    command -v powerpc64le-unknown-linux-gnu-as || echo 'NO ppc64le as under that triple name'
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T3 || echo 'ppc64le specs FAILED'
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
tail -25 "$B/specs.err"
