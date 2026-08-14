#!/bin/sh
# #157 -- the x86_64 spec probe alone, for the i386 + aarch64 + riscv build.
#
# ONE TARGET ON PURPOSE.  The question this build exists to answer is whether
# i386 can select ITSELF once a second back end that defines `registered_function'
# is configured (#155), so the only spec file needed is x86_64's, and it is the
# one target whose real `as' is the build machine's own.
set -u
B=${1:?build dir}
case "$B" in
  */b-af23dd9b01f75c197*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T=x86_64-pc-linux-gnu
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T TOOLS_DIR_FOR_$T=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T=--with-native-system-header-dir=$HDR
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
f="$B/lib/gcc/17.0.0/$T/specs-config"
if [ -f "$f" ]; then
  echo "  $T: $(wc -l < "$f") lines (wc -l) / $(grep -c . "$f") non-blank  md5=$(md5sum < "$f" | cut -c1-12)"
else
  echo "  $T: ABSENT ($f)"; tail -10 "$B/specs.err"
fi
