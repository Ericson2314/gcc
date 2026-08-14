#!/bin/sh
# Task #160 -- run the per-target `target-specs' probe for the two configured
# targets.  Adapted from t150-specs.sh; the cross binutils are not optional
# decoration (#113b: without them configure falls back to the build machine's
# own `as' and writes a file that NAMES the target while DESCRIBING x86_64,
# with 95 of 101 lines identical, and every name- and path-based check passes).
#
# usage: t160-specs.sh <build dir>
set -u
B=${1:?build dir}
case "$B" in
  */b-a51d424a65fb6e21d*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
HDR2=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR1=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    command -v $T1-as
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T1 \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS: an earlier run of this machinery
# exited partway and left specs-<target> TRUNCATED at 39 lines instead of 101,
# and every guard passed because 39 lines is non-empty.  So print a line count
# to compare against the recorded bar; never `test -s'.
echo
echo "== specs-config artefacts, by line count"
for t in $T2 $T1; do
  f="$B/lib/gcc/17.0.0/$t/specs-config"
  if [ -f "$f" ]; then
    echo "  $t: $(grep -c . "$f") lines  md5=$(md5sum < "$f" | cut -c1-12)"
  else
    echo "  $t: ABSENT ($f)"
  fi
done
tail -8 "$B/specs.err"
