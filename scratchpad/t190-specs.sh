#!/bin/sh
# #190 -- run the per-target `target-specs' probe for x86_64 only (the ICE and
# the recorded codegen bar are both x86_64).  Adapted from t160-specs.sh.
# usage: t164-specs.sh <build dir>
set -u
B=${1:?build dir}
case "$B" in
  */b-agent-a4232acf7c31decf4*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
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
# Check the ARTEFACT, not the exit status: a truncated specs-config is
# non-empty and every `test -s' passes on it.  Recorded two-base bar for
# x86_64 is wc -l 230 / grep -c . 222 / md5 a6c4c68bdf33.
f="$B/lib/gcc/17.0.0/$T2/specs-config"
if [ -f "$f" ]; then
  echo "  $T2: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5 $(md5sum < "$f" | cut -c1-12)"
else
  echo "  $T2: ABSENT ($f)"
fi
tail -5 "$B/specs.err"
