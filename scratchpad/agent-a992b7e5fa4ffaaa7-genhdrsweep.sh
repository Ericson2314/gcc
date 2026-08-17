#!/bin/sh
# genhdrsweep.sh -- THE FOURTH CLASS: a GENERATED per-base header whose SHARED
# copy is the primary's, consumed by shared code.
#
# WHY NEITHER OF THE OTHER TWO SWEEPS CAN SEE IT.  `floorsweep.sh' and
# `absencesweep.sh' both enumerate definers by grepping `gcc/config/', i.e. the
# SOURCE tree.  These names are not in the source tree at all -- `genattr-common'
# writes `DELAY_SLOTS' and `INSN_SCHEDULING' into `insn-attr-common-<base>.h',
# and the build root's `insn-attr-common.h' is the PRIMARY's copy.  That is
# PRINCIPLES rule 1 ("grep the generated artefact, never `ls'") applied to the
# definer side, and it is why the DFA-absent defect and `DELAY_SLOTS' were each
# found by hand after ICEing eleven and twelve back ends respectively.
#
# It is also the shape PRINCIPLES already records for `insn-modes.h' (five
# names, avr/msp430 `PSI') and `options.h' (36 names with the primary's body,
# the widest of them `TARGET_64BIT'), each measured separately and by hand.
# One instrument covers the whole family.
#
# THE COMPARISON IS BODY-LEVEL, NOT NAME-LEVEL, because the interesting cases
# are names present in BOTH with DIFFERENT bodies -- `DELAY_SLOTS 0' against
# `DELAY_SLOTS 1'.  A name-set diff scores those as identical, which is exactly
# how they survived.
#
# Comments are stripped: `genmodes'/`genattr' stamp the base name into a
# comment header, so every file differs trivially and a raw diff reports 47
# differences that mean nothing.
#
# usage: genhdrsweep.sh <builddir> [<base> ...]     default bases: the 4 scored
set -eu
export LC_ALL=C
B=${1:?builddir}
shift || true
if [ $# -gt 0 ]; then BASES="$*"; else BASES="i386 aarch64 riscv s390"; fi
G="$B/gcc"
[ -d "$G" ] || { echo "FATAL: no $G"; exit 9; }

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

# `#define NAME body' -> `NAME<TAB>body', comments stripped.
defs () {
  sed -e 's://.*::' -e 's:/\*.*\*/::' "$1" \
  | sed -n 's/^[ \t]*#[ \t]*define[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\)[ \t]*\(.*\)$/\1\t\2/p' \
  | sed 's/[ \t]*$//' | sort -u
}

nfound=0
for shared in "$G"/insn-attr-common.h "$G"/insn-config.h "$G"/insn-flags.h \
              "$G"/insn-modes.h "$G"/insn-constants.h "$G"/options.h; do
  [ -f "$shared" ] || continue
  stem=$(basename "$shared" .h)
  defs "$shared" > "$TD/shared"
  # NON-VACUITY: a header we cannot parse reads as "agrees with everyone".
  n=$(grep -c . "$TD/shared" || true)
  [ "$n" -gt 0 ] || { echo "FATAL: no #defines parsed from $shared -- REFUSING."; exit 9; }
  echo "=============================================================="
  echo "== $stem.h   ($n defines in the SHARED copy)"
  echo "=============================================================="
  for base in $BASES; do
    pb="$G/$stem-$base.h"
    [ -f "$pb" ] || { printf '   %-10s (no per-base header)\n' "$base"; continue; }
    defs "$pb" > "$TD/pb"
    # names in both, bodies differing -- the class.
    join -t"$(printf '\t')" -j1 -o 0,1.2,2.2 \
      <(cut -f1 "$TD/shared" | sort -u | join -t"$(printf '\t')" - "$TD/shared") \
      <(cut -f1 "$TD/pb"     | sort -u | join -t"$(printf '\t')" - "$TD/pb") \
      2>/dev/null | awk -F'\t' '$2 != $3' > "$TD/diff-$base" || true
    d=$(grep -c . "$TD/diff-$base" || true)
    printf '   %-10s %s name(s) present in both with DIFFERENT bodies\n' "$base" "$d"
    if [ "$d" -gt 0 ]; then
      nfound=$((nfound + d))
      awk -F'\t' '{ printf "        %-34s shared[%s]  %s[%s]\n", $1, $2, "'"$base"'", $3 }' \
        "$TD/diff-$base" | head -25
    fi
  done
done

echo
echo "TOTAL name/body divergences across the scanned families: $nfound"
echo
echo "CONTROL: DELAY_SLOTS and INSN_SCHEDULING are the KNOWN members of this"
echo "class (12 and 14 back ends).  If a scan of insn-attr-common.h over a base"
echo "set including one of those back ends reports ZERO, this instrument is"
echo "broken -- run it with e.g. 'mips sh sparc' to see it fire."
