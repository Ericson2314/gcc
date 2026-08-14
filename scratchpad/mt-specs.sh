#!/bin/sh
# mt-specs.sh -- run the per-target `target-specs' probe for each configured
# target, with that target's REAL cross assembler and linker on PATH.
#
# THE SURVIVOR OF 40 `*-specs.sh'.
#
# THE CROSS BINUTILS ARE NOT OPTIONAL DECORATION.  #113b measured that without
# them configure falls back to the BUILD machine's own `as' and writes a file
# that NAMES aarch64 while DESCRIBING x86_64 -- two trees, two md5s, correct
# --host in each, and 95 of 101 lines identical.  Every name- and path-based
# check passes on that.  So the probe runs against the real toolchain and the
# files are diffed BY BODY afterwards.
#
# EACH TARGET GETS ITS OWN SYSTEM HEADER DIRECTORY, on purpose.  A single
# shared value would be one machine's answer served to every target, which is
# the shape this branch exists to delete.
#
# target-specs runs AFTER gcc is built, as its own configure -- it is not a
# build-time prerequisite (standing ruling).
#
# usage: mt-specs.sh <builddir>
#   MT_TARGETS  space-separated triples (default: the two-base pair)
#   MT_HDR_<triple-with-dashes-as-underscores>  that target's header dir
set -u
MT_LIB_DIR=$(cd "$(dirname "$0")" && pwd)
. "$MT_LIB_DIR/mt-lib.sh"

B=${1:?build dir}
mt_assert_builddir "$B"
SRC=$(mt_src_of "$B") || exit 9
mt_assert_configured_from "$B" "$SRC"

NP="$HOME/src/nixos-configuration/dep/nixpkgs"
T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
HDR2=${MT_HDR_X86:-/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include}
HDR1=${MT_HDR_AARCH64:-/nix/store/2xzifm4c0h9d0yv91az0v1c0bxd14h23-glibc-aarch64-unknown-linux-gnu-2.42-67-dev/include}

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
rc=$?
echo "$rc" > "$B/specs.rc"
echo "rc=$rc"
tail -25 "$B/specs.err"

# NON-VACUITY.  "The probe ran" and "the probe SKIPped every target" are the
# same rc=0.  Refuse to report a success that produced no spec file, and quote
# each by the command that measured it -- `wc -l' and `grep -c .' of one file
# have disagreed by 8 (blank lines) and been reported as a disagreement
# between trees.
V=$(cat "$SRC/gcc/BASE-VER")
got=0
for T in ${MT_TARGETS:-$T2 $T1}; do
  c="$B/lib/gcc/$V/$T/specs-config"
  if [ -s "$c" ]; then
    got=$((got+1))
    echo "specs-config $T: wc -l $(wc -l < "$c")  grep -c . $(grep -c . "$c")  md5 $(md5sum < "$c" | cut -c1-12)"
  else
    echo "specs-config $T: ABSENT at $c -- target-specs SKIPped it (is $T-as on PATH?)"
  fi
done
[ "$got" -gt 0 ] || mt_die "no specs-config was produced for ANY target; rc=$rc proved nothing"
