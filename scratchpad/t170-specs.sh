#!/bin/sh
# #170 -- run the per-target `target-specs' probe for EVERY one of the eleven
# configured back ends, each against ITS OWN REAL ASSEMBLER.
#
# Adapted from t160-specs.sh, which probed two targets.  The substantive change
# is that the tool directory is per target and comes from t170-tools.sh, whose
# arm has already proved each `as' emits objects of that target's ELF machine.
#
# THE FOUR TARGETS WITH NO CROSS BINUTILS ARE RUN TOO, AND THEY ARE EXPECTED TO
# FAIL.  sparc64-linux, ia64-elf, visium-elf and xtensa-elf have no toolchain
# anywhere in this nixpkgs (measured: zero attributes out of 27157 match
# sparc/ia64/visium/xtensa, against aarch64=1 and riscv=2 as the non-vacuity
# control).  The Makefile rule refuses them by name rather than falling back to
# the build machine's `as' -- that refusal IS the result for those four, and it
# is recorded here rather than skipped, so the table can say UNKNOWN with a
# cause instead of leaving a blank.
#
# usage: t170-specs.sh <build dir> <tool root>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
ROOT=${2:?tool root}
case "$B" in
  */b-a697b5bfd5294f5e8*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
HDRX=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

# COLUMN 2 -- the CANONICAL triple.  Every per-target make rule, spec
# directory and specs-config path is named after the canonicalised triple, not
# after what --enable-targets was given; keying this on column 1 produced
# "No rule to make target 'configure-target-specs-arm-eabi'" for eight of the
# eleven.  See the header of t170-bases11.txt.
TRIPLES=$(grep -v '^#' "$S/t170-bases11.txt" | awk 'NF{print $2}')

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
: > "$B/specs-all.out"
for t in $TRIPLES; do
  d="$ROOT/$t"
  if [ -d "$d" ]; then
    tools="TOOLS_DIR_FOR_$t=$d"
  else
    tools=""            # let the Makefile's own refusal fire, and record it
  fi
  extra=""
  [ "$t" = x86_64-pc-linux-gnu ] && extra="--with-native-system-header-dir=$HDRX"
  echo "=== $t  tools=${d}" >> "$B/specs-all.out"
  sh "$S/eb-shell.sh" "cd $B && make configure-target-specs-$t $tools \
     TARGET_SPECS_FLAGS_FOR_$t='$extra'" \
     >> "$B/specs-all.out" 2>> "$B/specs-all.out"
  echo "--- rc=$? for $t" >> "$B/specs-all.out"
done

# CHECK THE ARTEFACT, NOT THE EXIT STATUS.  An earlier run of this machinery
# exited partway and left specs-<target> truncated at 39 lines instead of 101,
# and every `test -s' guard passed because 39 lines is non-empty.  So the line
# count and md5 are printed for comparison against the recorded two-base bar
# (230 lines / grep -c . 222 / md5 a6c4c68bdf33 for x86_64).
echo
echo "== specs-config per target"
for t in $TRIPLES; do
  f=$(ls "$B"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  if [ -n "$f" ] && [ -f "$f" ]; then
    echo "  $t: wc -l $(wc -l < "$f")  grep -c . $(grep -c . "$f")  md5 $(md5sum < "$f" | cut -c1-12)  $f"
  else
    echo "  $t: ABSENT -- no specs-config"
  fi
done
