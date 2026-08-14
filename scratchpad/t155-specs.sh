#!/bin/sh
# #155 -- run the per-target `target-specs' probe for the four configured bases.
#
# The cross binutils are not optional decoration.  #113b measured that without
# them configure falls back to the build machine's own `as' and writes a file
# that NAMES the target while DESCRIBING x86_64 -- two trees, two md5s, correct
# --host in each, 95 of 101 lines identical.  Every name- and path-based check
# passes on that, so "the specs file exists and mentions s390" is not evidence.
#
# usage: t155-specs.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-af064528c538fd406*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu
T3=powerpc64-linux-gnu
T4=s390x-linux-gnu
HDR1=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  -p pkgsCross.powernv.buildPackages.binutils \
  -p pkgsCross.s390x.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    for t in $T2 $T3 $T4; do
      command -v \$t-as || echo \"NOTE: no \$t-as; its specs will be DEFAULTS, not probes\"
    done
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T1 TOOLS_DIR_FOR_$T1=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
    for t in $T2 $T3 $T4; do
      cd $B && make configure-target-specs-\$t || true
    done
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS.  An earlier run of this machinery
# exited partway and left specs-<target> TRUNCATED at 39 lines instead of 101,
# and every guard passed because 39 lines is non-empty.  So: a line count to
# compare and a distinct md5 per target, never `test -s'.
echo
echo "== specs-config artefacts (a number and an md5 to compare, not 'exists')"
for t in $T1 $T2 $T3 $T4; do
  f="$B/lib/gcc/17.0.0/$t/specs-config"
  if [ -f "$f" ]; then
    echo "  $t: $(grep -c . "$f") lines  md5=$(md5sum < "$f" | cut -c1-12)"
  else
    echo "  $t: ABSENT ($f)"
  fi
done
tail -10 "$B/specs.err"
