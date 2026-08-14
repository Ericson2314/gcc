#!/bin/sh
# #171 -- run `target-specs' for a TWO-base build (x86_64 + aarch64), with a
# REAL aarch64 cross assembler and linker.  Derived from t157-specs.sh.
#
# The real binutils is not a convenience: without `aarch64-...-as' on PATH the
# rule SKIPs, no specs-<target>-config is written, and cc1 then fails with
# `common target hook option_init_struct was used before a target was
# selected' -- a diagnostic pointing nowhere near the cause.  With it the
# per-target config is PROBED rather than defaulted, which is what makes a
# two-target comparison both-sided.
set -u
B=${1:?build dir}
case "$B" in
  */b-a78a*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=x86_64-pc-linux-gnu
T2=aarch64-unknown-linux-gnu
HDR1=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
HDR2=/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gdb gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  -p pkgsCross.aarch64-multiplatform.buildPackages.binutils \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    a64=\$(dirname \$(command -v $T2-as))
    echo \"native \$nat\"; echo \"a64 \$a64\"
    cd $B/gcc && make multi-target-specs
    cd $B && make configure-target-specs-$T1 TOOLS_DIR_FOR_$T1=\$nat \\
      TARGET_SPECS_FLAGS_FOR_$T1=--with-native-system-header-dir=$HDR1
    cd $B && make configure-target-specs-$T2 TOOLS_DIR_FOR_$T2=\$a64 \\
      TARGET_SPECS_FLAGS_FOR_$T2=--with-native-system-header-dir=$HDR2
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"

# CHECK THE ARTEFACT, NOT THE EXIT STATUS, AND NOT `test -s' EITHER: this
# machinery once left specs-<target> truncated at 39 lines instead of 101 and
# every non-emptiness guard passed.  Both counts AND the md5, because 230 and
# 222 are the same file counted two ways (wc -l vs grep -c .) and that
# "disagreement" has been reconciled with a story twice.  DISTINCT md5s across
# targets are the thing to read: identical ones are the shape a probe that
# silently fell back to the build machine's tools produces.
echo
echo "== specs-config artefacts"
for t in $T1 $T2; do
  f="$B/lib/gcc/17.0.0/$t/specs-config"
  if [ -f "$f" ]; then
    echo "  $t: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5=$(md5sum < "$f" | cut -c1-12)"
  else
    echo "  $t: ABSENT ($f)"
  fi
done
tail -5 "$B/specs.err"
