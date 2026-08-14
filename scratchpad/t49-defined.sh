#!/bin/sh
# #49 -- exactness arm for t49-caps.sh.
#
# t49-caps.sh GRANTS a finding ("this name is undefined, so its #if is silently
# false"), so per PRINCIPLES section 4 it must be EXACT, not over-broad: an
# instrument that can only revoke may be too eager, one that can grant may not.
# config.in is not the only place a HAVE_* name can be #defined -- a target
# header under config/ can define one too.  This arm asks, for every name
# t49-caps.sh accused, whether ANY #define for it exists anywhere in the tree.
#
# A name with a #define somewhere is NOT silently false and must be struck from
# the population.
#
# usage: t49-defined.sh <gcc-srcdir> <names-file>
set -e
G=$(cd "${1:?gcc srcdir}" && pwd)
NAMES=${2:?file of HAVE_* names, one per line}
[ -s "$NAMES" ] || { echo "FATAL: $NAMES is empty; refusing to score"; exit 9; }

# NON-VACUITY: prove the grep can find a #define at all before trusting its
# zeroes.  MULTI_TARGET_RENAME_NAMES-style controls: pick a name we know is
# defined in this tree.
ctl=$(grep -rlE '^[[:space:]]*#[[:space:]]*define[[:space:]]+GCC_TARGET_CAPS_H\b' \
        --include='*.h' "$G" | head -1)
[ -n "$ctl" ] || { echo "FATAL: control #define not found; the grep is broken, not the tree"; exit 9; }
echo "non-vacuity control: GCC_TARGET_CAPS_H defined in $ctl"
echo

ndef=0; nsil=0
while read -r n; do
  [ -n "$n" ] || continue
  d=$(grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$n\b" \
        --include='*.h' --include='*.cc' --include='*.c' --include='*.in' "$G" \
        | sed "s|^$G/||" | tr '\n' ' ')
  if [ -n "$d" ]; then
    ndef=$((ndef+1)); printf 'DEFINED  %-46s %s\n' "$n" "$d"
  else
    nsil=$((nsil+1)); printf 'SILENT   %-46s (no #define anywhere)\n' "$n"
  fi
done < "$NAMES"
echo
echo "== DEFINED somewhere: $ndef   SILENTLY FALSE: $nsil"
