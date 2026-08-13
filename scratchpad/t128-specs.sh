#!/bin/sh
# #119 -- run the per-target target-specs probe for both configured targets,
# with a REAL aarch64 assembler and linker on PATH.
#
# The aarch64 binutils are not optional decoration.  #113b measured that
# without them configure falls back to the build machine's own `as' and writes
# a file that NAMES aarch64 while DESCRIBING x86_64 -- two trees, two md5s,
# correct --host in each, and 95 of 101 lines identical.  Every name- and
# path-based check passes on that.  So the probe is run against the real
# toolchain and the two files are diffed by BODY afterwards.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b128}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
# Each target's OWN system headers.  Two different directories on purpose: a
# single shared value would be one machine's answer served to both targets,
# which is the shape this branch exists to delete.
HDR2=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR1=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    command -v $T1-as
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T1 \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
tail -25 "$B/specs.err"
