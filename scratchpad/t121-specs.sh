#!/bin/sh
# #121 -- run the per-target target-specs probe for all THREE configured
# targets, each against its own REAL assembler and linker.
#
# The cross binutils are not optional decoration.  #113b measured that without
# them configure falls back to the build machine's own `as' and writes a file
# that NAMES the target while DESCRIBING x86_64 -- correct --host in each, and
# 95 of 101 lines identical.  Every name- and path-based check passes on that.
#
# Each target gets its OWN system header directory.  A single shared value
# would be one machine's answer served to three targets, which is the shape
# this branch exists to delete.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b-abeb4d62}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"

T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu
T3=riscv64-unknown-linux-gnu

HDR1=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR2=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  -p pkgsCross.riscv64.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    command -v $T2-as
    command -v $T3-as
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T1 TOOLS_DIR_FOR_$T1=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
    cd $B && make configure-target-specs-$T2 \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T3
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
tail -25 "$B/specs.err"
