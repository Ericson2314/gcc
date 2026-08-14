#!/bin/sh
# #157 -- run the per-target `target-specs' probe for a FOUR-base build:
# x86_64, aarch64, powerpc64le and s390x.
#
# REAL CROSS BINUTILS FOR ALL FOUR.  Makefile.tpl's rule refuses to fall back
# on the build machine's own `as' (it exits 1 by name), which is the #113b
# finding turned into a guard: without the cross toolchain configure writes a
# file that NAMES the target while DESCRIBING x86_64, and 95 of 101 lines are
# identical.  nixpkgs has both new ones:
#     pkgsCross.powernv.buildPackages.binutils -> powerpc64le-...-as
#     pkgsCross.s390x.buildPackages.binutils   -> s390x-unknown-linux-gnu-as
#
# NOTE THE PREFIX MISMATCH, and why TOOLS_DIR_FOR_ is passed rather than left
# to PATH: config.sub canonicalises the s390x triple to `s390x-ibm-linux-gnu',
# so `command -v s390x-ibm-linux-gnu-as' finds nothing even with the right
# binutils on PATH.  The knob exists for exactly this; using it is not a
# workaround for a missing toolchain, it is naming the one that is there.
#
# System header dirs are deliberately NOT passed for the two new targets: the
# success arm compiles with -nostdinc, so no system header is read, and
# inventing a header dir per target here would be a fact about a deployed
# machine this build has no claim to.  Said out loud rather than left to be
# noticed.
set -u
B=${1:?build dir}
case "$B" in
  */b-af23dd9b01f75c197*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu
T3=powerpc64le-unknown-linux-gnu
T4=s390x-ibm-linux-gnu
HDR1=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR2=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  -p pkgsCross.powernv.buildPackages.binutils \
  -p pkgsCross.s390x.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    ppc=\$(dirname \$(command -v powerpc64le-unknown-linux-gnu-as))
    s390=\$(dirname \$(command -v s390x-unknown-linux-gnu-as))
    a64=\$(dirname \$(command -v $T2-as))
    echo \"native \$nat\"; echo \"ppc \$ppc\"; echo \"s390 \$s390\"; echo \"a64 \$a64\"
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T1 TOOLS_DIR_FOR_$T1=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$a64 \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T3 TOOLS_DIR_FOR_$T3=\$ppc
    cd $B && make configure-target-specs-$T4 TOOLS_DIR_FOR_$T4=\$s390
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS, AND NOT `test -s' EITHER: a run of
# this machinery once left specs-<target> truncated at 39 lines instead of
# 101, and every non-emptiness guard passed.  Line counts and md5s, printed to
# be compared -- and DISTINCT md5s across targets are the thing to read, since
# identical ones are the shape a fallen-back-to-native probe produces.
echo
echo "== specs-config artefacts"
for t in $T1 $T2 $T3 $T4; do
  f="$B/lib/gcc/17.0.0/$t/specs-config"
  if [ -f "$f" ]; then
    echo "  $t: $(grep -c . "$f") lines  md5=$(md5sum < "$f" | cut -c1-12)"
  else
    echo "  $t: ABSENT ($f)"
  fi
done
tail -15 "$B/specs.err"
