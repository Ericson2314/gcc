#!/bin/sh
# WHICH `OPT_*' ORDINALS DOES A PER-BASE `options-tables.cc' NAME THAT ITS OWN
# `options-<base>.h' DOES NOT SPELL?
#
# `enum opt_code' is UNIONED, so every base's header carries every ordinal --
# EXCEPT that opth-gen.awk comments the enumerator out when the option is an
# Alias (or Ignore) IN THAT BASE:
#
#     options.h:19257         OPT_march_ = 2434,
#     options-nvptx.h:18324   /* OPT_march_ = 2434, */
#
# because nvptx's own `march=' is `Alias(misa=)' while eight other back ends
# declare it as a real Joined option.  One name, several authorities.
# `optc-gen.awk' emits `back_chain' from the UNION's prefix relation, so the
# foreign rows `-march=1.0' .. `-march=help' name `OPT_march_' in every base's
# table -- and only the base that suppressed it fails.
#
# THIS SWEEPS THE FAMILY rather than the instance: every base, every OPT_ name
# its tables file references, against that base's own enum.
#
# NON-VACUITY: it refuses to score if it read no tables files, or if a tables
# file yielded no OPT_ references at all -- an empty read is indistinguishable
# from a clean result otherwise.
#
# usage: res-optref.sh [builddir]
set -e
D=${1:-/tmp/b-af73bc3169a097677}
G=$D/gcc
nb=0; nbad=0
# The union enum -- every ordinal that exists at all.  The shared options.h is
# generated over every configured back end, so it spells the ones the per-base
# headers comment out.
ALLORD=$(sed -n 's/^ *\/\* *\(OPT_[A-Za-z0-9_]*\) =.*/\1/p;s/^ *\(OPT_[A-Za-z0-9_]*\) =.*/\1/p;s/^  \(OPT_SPECIAL_[A-Za-z0-9_]*\).*/\1/p' "$G/options.h" | sort -u)
[ -n "$ALLORD" ] || { echo "FATAL: read no ordinals from $G/options.h"; exit 9; }
echo "union ordinals: $(echo "$ALLORD" | wc -l)"
for f in "$G"/mt-*/options-tables.cc; do
  [ -f "$f" ] || continue
  b=$(basename "$(dirname "$f")" | sed 's/^mt-//')
  h=$G/options-$b.h
  [ -f "$h" ] || { echo "FATAL: no $h"; exit 9; }
  nb=$((nb + 1))
  # Restrict to names that are genuinely `enum opt_code' ordinals.  Without
  # this the sweep also reports back-end EnumValue macros that merely start
  # with `OPT_' -- msp430's OPT_SPACE, s390's OPT_HTM/OPT_VX, pru's
  # OPT_LOOP/OPT_MUL/OPT_FILLZERO, riscv's OPT_NO_FUSION -- which are not
  # ordinals at all and are defined by those back ends' own headers.  Measured:
  # without the filter this says 5 bases, of which 4 are that false family.
  refs=$(grep -o 'OPT_[A-Za-z0-9_]*' "$f" | sort -u | grep -xF "$ALLORD" || true)
  [ -n "$refs" ] || { echo "FATAL: $f references no OPT_ at all"; exit 9; }
  # Enumerators this base actually spells: uncommented `  OPT_x = N,' lines,
  # plus the OPT_SPECIAL_* and N_OPTS tail.
  have=$(sed -n 's/^  \(OPT_[A-Za-z0-9_]*\) =.*/\1/p;s/^  \(OPT_SPECIAL_[A-Za-z0-9_]*\).*/\1/p' "$h" | sort -u)
  [ -n "$have" ] || { echo "FATAL: $h declares no enumerator at all"; exit 9; }
  miss=$(echo "$refs" | grep -vxF "$have" || true)
  if [ -n "$miss" ]; then
    nbad=$((nbad + 1))
    echo "$b: $(echo "$miss" | tr '\n' ' ')"
  fi
done
[ "$nb" -gt 0 ] || { echo "FATAL: no mt-*/options-tables.cc read at all"; exit 9; }
echo "bases read: $nb; bases naming an unspelled ordinal: $nbad"
