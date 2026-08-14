#!/bin/sh
# Run the per-target `target-specs' probe for EVERY configured target, each
# against ITS OWN cross assembler/linker and ITS OWN glibc headers.
#
# Derived from t175-specs.sh, which hardcodes two targets.  The tools and
# headers come from scratchpad/taa-tools.sh, which materialises them from
# nixpkgs and shims the s390x naming mismatch (nixpkgs says
# s390x-unknown-linux-gnu-as, config.sub says s390x-ibm-linux-gnu).
#
# WHY THE REAL CROSS TOOLS ARE NOT OPTIONAL: #113b measured that without them
# configure falls back to the build machine's own `as' and writes a file that
# NAMES the target while DESCRIBING x86_64 -- 95 of 101 lines identical, both
# md5s distinct, every name- and path-based check green.  So the md5s are
# printed here and must all differ.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?set B to the build dir}
TOOLS=${TOOLS:?set TOOLS to a taa-tools.sh output dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
TX=x86_64-pc-linux-gnu

cmds="cd $B/gcc && make multi-target-specs && cd $B"
# x86_64 is the build machine's own target: its tools are the native ones, and
# TOOLS_DIR_FOR_ is set explicitly rather than left to a PATH search for
# `x86_64-pc-linux-gnu-as', which does not exist under that name here.
cmds="$cmds && make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
  TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX"
for T in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  H=$(cat "$TOOLS/$T.hdr")
  [ -d "$H" ] || { echo "FATAL: no headers for $T ($H)"; exit 9; }
  cmds="$cmds && make configure-target-specs-$T \
    TOOLS_DIR_FOR_$T=$TOOLS/bin \
    TARGET_SPECS_FLAGS_FOR_$T=--with-native-system-header-dir=$H"
done

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    PATH=$TOOLS/bin:\$PATH; export PATH
    $cmds
  " > "$B/specs.out" 2> "$B/specs.err"
echo "rc=$?"
tail -15 "$B/specs.err"
VER=$(cat "$B/gcc/BASE-VER")
echo "-- specs-config per target (identity, not a statistic):"
for T in $TX aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    printf '  %-28s wc -l %s  grep -c . %s  md5 %s\n' "$T" \
      "$(wc -l < "$F")" "$(grep -c . "$F")" "$(md5sum < "$F" | cut -c1-12)"
  else
    printf '  %-28s ABSENT\n' "$T"
  fi
done
