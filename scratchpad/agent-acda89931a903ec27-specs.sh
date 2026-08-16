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

# THE PER-TARGET MAKES ARE SEPARATED BY `;', NOT BY `&&', AND THAT ONE
# CHARACTER WAS WORTH 24 TARGETS.
#
# This script used to `&&'-chain all 47 invocations into a single command.
# m68k fails in the middle -- its driver refuses `-mcpu=m68020' (#218) -- so
# every target after it in the list was NEVER ATTEMPTED, and the report below
# calls an unattempted target `SPECS-FAIL (has an as; target-specs produced
# nothing)'.  "Never attempted" and "failed" arriving as the same silence is
# PRINCIPLES' `-k' rule, failing in the direction that makes the branch look
# worse: it read OK=21 SPECS-FAIL=24 where the truth is 45 OK, 0 FAIL.
#
# THE BOARD THAT FOUND THIS DID NOT FIX IT.  `A7D26223EEFCFA725-BOARD.md' 6.1
# records the defect and the corrected figures, and left the script as it was
# -- so the next run reproduced OK=21 exactly, from a report that already
# explained why.  A defect that is written down and not repaired reads, to the
# next agent, as a defect that was repaired.  Same family as the `sweep.sh'
# citation.  Fixed here, and the per-target rc is now recorded so a real
# failure is still visible rather than being swallowed with the spurious ones.
#
# The setup steps keep `&&': if `make multi-target-specs' fails there is
# nothing to configure and continuing would produce 45 identical spurious
# failures.
cmds="cd $B/gcc && make multi-target-specs && cd $B"
have=0; skip=""
for T in $LIST; do
  if [ "$T" = "$TX" ]; then
    cmds="$cmds; make configure-target-specs-$TX TOOLS_DIR_FOR_$TX=\$nat \
      TARGET_SPECS_FLAGS_FOR_$TX=--with-native-system-header-dir=$HDRX \
      || echo \"MT-SPECS-RC $TX \$?\""
    have=$((have+1)); continue
  fi
  if [ ! -x "$TOOLS/$T-as" ]; then
    skip="$skip $T"; continue
  fi
  cmds="$cmds; make configure-target-specs-$T TOOLS_DIR_FOR_$T=$TOOLS \
    || echo \"MT-SPECS-RC $T \$?\""
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
# The per-target rcs, which the `&&' chain used to hide behind the first one.
# Printed even when empty, and labelled, so "no target failed" cannot be
# confused with "this arm did not run".
echo "-- per-target make failures (empty == none):"
grep '^MT-SPECS-RC ' "$B/specs.out" "$B/specs.err" 2>/dev/null | sed 's/^/  /' \
  || echo "  (none)"

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
