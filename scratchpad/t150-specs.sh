#!/bin/sh
# #150 -- run the per-target `target-specs' probe for the configured targets.
#
# Derived from t130-specs.sh, with riscv64 added and its own binutils.
#
# The cross binutils are not optional decoration.  #113b measured that without
# them configure falls back to the build machine's own `as' and writes a file
# that NAMES the target while DESCRIBING x86_64 -- two trees, two md5s, correct
# --host in each, 95 of 101 lines identical.  Every name- and path-based check
# passes on that.
#
# Each target gets its OWN system header directory.  A single shared value
# would be one machine's answer served to every target, which is the shape
# this branch exists to delete.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
T3=riscv64-unknown-linux-gnu
HDR2=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR1=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  -p pkgsCross.riscv64.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    command -v $T1-as
    command -v $T3-as || echo 'NOTE: no $T3-as; riscv specs will be defaults'
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
    cd $B && make configure-target-specs-$T1 \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
    cd $B && make configure-target-specs-$T3 || true
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS.  PRINCIPLES section 4: an earlier
# run of this machinery exited partway and left specs-<target> TRUNCATED at 39
# lines instead of 101, and every guard passed because 39 lines is non-empty.
# So: count lines per target and print them, and never assert `test -s'.
echo
echo "== specs-config artefacts, by line count (a number to compare, not 'exists')"
for t in $T2 $T1 $T3; do
  f="$B/lib/gcc/17.0.0/$t/specs-config"
  if [ -f "$f" ]; then
    echo "  $t: $(grep -c . "$f") lines  md5=$(md5sum < "$f" | cut -c1-12)"
  else
    echo "  $t: ABSENT ($f)"
  fi
done
tail -15 "$B/specs.err"
