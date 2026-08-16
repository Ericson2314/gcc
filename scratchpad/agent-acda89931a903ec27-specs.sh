#!/bin/sh
# Run `target-specs' for EVERY target that has a VERIFIED cross assembler.
#
# Generalises taa-specs.sh, which hardcodes four targets and requires a glibc
# header dir per target.  Most of the 45 back ends here are bare-metal `*-elf'
# with no libc at all, and they need none: a `scan-assembler' test compiles to
# `.s' and greps text -- no libc, no libgcc, no linker, no execution.  So the
# `--with-native-system-header-dir' flag is passed ONLY where a header dir is
# actually known, and its absence is recorded rather than defaulted.
#
# REFUSAL IS THE POINT.  A target with no verified `<triple>-as' in $TOOLS is
# SKIPPED BY NAME and never falls through to the host assembler.  #113b
# measured what the fallback costs: a spec file that NAMES the target while
# DESCRIBING x86_64, 95 of 101 lines identical, every name- and path-based
# check green.  The three verdicts are kept distinct in the output:
#
#   NO-CROSS-AS      no verified assembler for this triple  (nvptx, gcn)
#   SPECS-FAIL       target-specs ran and failed            (a real finding)
#   OK               specs-config written, identity printed
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:?build dir}
TOOLS=${TOOLS:?verified tools bin dir}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include
TX=x86_64-pc-linux-gnu

TARGETS=${TARGETS:?comma or newline separated triples}
LIST=$(echo "$TARGETS" | tr ',' '\n' | grep .)

cmds="cd $B/gcc && make multi-target-specs && cd $B"
have=0; skip=""
for T in $LIST; do
  if [ "$T" = "$TX" ]; then
    cmds="$cmds && make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
      TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX"
    have=$((have+1)); continue
  fi
  if [ ! -x "$TOOLS/$T-as" ]; then
    skip="$skip $T"; continue
  fi
  cmds="$cmds && make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS"
  have=$((have+1))
done

echo "== targets with a verified cross as: $have"
[ -n "$skip" ] && echo "== NO-CROSS-AS (skipped by name, never defaulted):$skip"
[ "$have" -gt 0 ] || { echo "FATAL: no target has an assembler; refusing"; exit 9; }

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
  --substituters 'https://cache.nixos.org/' --run "
    set -e
    nat=\$(dirname \$(command -v as))
    echo \"native binutils: \$nat\"
    PATH=$TOOLS:\$PATH; export PATH
    $cmds
  " > "$B/specs.out" 2> "$B/specs.err"
rc=$?
echo "target-specs rc=$rc"
[ "$rc" = 0 ] || tail -20 "$B/specs.err"

VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }

# Identity, not a statistic: PRINCIPLES records `wc -l 230' vs `grep -c . 222'
# being the same file counted two ways, twice, each time "reconciled" by a
# story nobody checked.  md5 settles it.
echo "-- specs-config per target:"
nok=0; nbad=0
for T in $LIST; do
  F="$B/lib/gcc/$VER/$T/specs-config"
  if [ -f "$F" ]; then
    printf '  %-30s wc -l %-5s grep -c . %-5s md5 %s\n' "$T" \
      "$(wc -l < "$F")" "$(grep -c . "$F")" "$(md5sum < "$F" | cut -c1-12)"
    nok=$((nok+1))
  elif [ -x "$TOOLS/$T-as" ] || [ "$T" = "$TX" ]; then
    printf '  %-30s SPECS-FAIL (has an as; target-specs produced nothing)\n' "$T"
    nbad=$((nbad+1))
  else
    printf '  %-30s NO-CROSS-AS\n' "$T"
  fi
done
echo "specs OK=$nok SPECS-FAIL=$nbad"
