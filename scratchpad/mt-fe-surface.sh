#!/bin/sh
# mt-fe-surface.sh -- THE PER-FRONT-END TARGET-MACRO SURFACE, for every front
# end in the tree rather than for `cp/' alone.
#
# WHAT IT EXTENDS AND WHY, rather than a rewrite (INSTRUMENTS.md: extend an
# `mt-*.sh' or add one with a descriptive name; do not fork):
#
#   * `agent-a260445cf27ba480a-cxxmacros.sh' asks, for a HAND-WRITTEN list of
#     15 macros, how many files under `config/' define each.  Its subject is
#     hardcoded to `cp/'.  Here the directory is a parameter and the macro
#     list is DERIVED from the tree (every `#define' in a header under
#     `config/', plus `defaults.h'), which is the same 11,178-name vocabulary
#     `agent-a8f6f467d15197cd3-fecensus.sh' used.  A hand list can only find
#     macros somebody already suspected; the C++ defect was found because
#     somebody happened to list `TARGET_PTRMEMFUNC_VBIT_LOCATION'.
#   * `agent-a8f6f467d15197cd3-fecensus.sh' produced the FRONTENDS census's
#     table (files / TM-CHANNEL / surface).  It is a source-level count.  This
#     adds the arm that census explicitly does not have: **how many of the
#     front end's OBJECTS actually opened `tm.h'**, read from the build's own
#     `.deps/*.Po', i.e. what the compiler did rather than what the source
#     spells.  PRINCIPLES measured that `git grep '"tm.h"'' undercounts the
#     real population by 7.6x (59 spellings against 451 objects), so a
#     source-only answer is the wrong instrument for "who reads the primary".
#
# THE THREE COLUMNS, and what each is NOT:
#
#   SPELLS-TM   files in the directory whose own text reaches `tm.h' -- the
#               quoted include, `MT_HEADER (tm.h)' and `BASE_HEADER (tm.h)',
#               because a grep for the quoted string cannot see the other two.
#               An UPPER bound on nothing and a LOWER bound on the channel:
#               a front end can spell zero and still read `tm.h' through a
#               shared header, which is exactly what `cp/' does.
#   SURFACE     how many names from the target-macro vocabulary the directory
#               spells.  Deliberately over-broad (word match, comments count,
#               `defaults.h' fallbacks count as definers) so it can only ever
#               ADD suspects -- PRINCIPLES: "when an instrument can only take
#               away, make it too eager; when it can grant, make it exact."
#   OBJS-TM     objects of that front end whose `.Po' names the build root's
#               `tm.h' -- i.e. the PRIMARY's chain.  This is the number that
#               says how far a leak reaches.  Requires a BUILT build dir; it
#               prints `-' and says so when the objects are absent, because
#               "the front end was never built" and "the front end opens
#               nothing" are the same empty count and must not read alike.
#
# usage: mt-fe-surface.sh <srcdir> [builddir]
set -u
SRC=${1:?srcdir}
SRC=$(cd "$SRC" && pwd)
D=${2:-}
cd "$SRC/gcc"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0

# ---- the target-macro vocabulary ---------------------------------------
# Every name `#define'd in a header under config/, plus defaults.h.  Same
# construction as the fecensus; kept here so this script does not depend on
# another script having been run.
{ grep -rhoE '^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z_0-9]*' \
    --include='*.h' config/ defaults.h 2>/dev/null; } \
  | awk '{print $NF}' | sort -u > "$WORK/vocab"
NV=$(wc -l < "$WORK/vocab")
# NON-VACUITY, before anything is scored.  An empty vocabulary scores every
# front end as surface 0, which reads as "no front end touches target macros"
# -- the null result wearing a clean bill of health.
[ "$NV" -ge 5000 ] || { echo "REFUSE: vocabulary is $NV names, expected thousands"; exit 9; }
grep -qx 'BITS_PER_WORD' "$WORK/vocab" || { echo "REFUSE: vocabulary lacks BITS_PER_WORD"; exit 9; }
grep -qx 'MT_NO_SUCH_MACRO_XYZ' "$WORK/vocab" && { echo "REFUSE: negative control present"; exit 9; }
echo "vocabulary: $NV names (control BITS_PER_WORD present, negative absent)"

# ---- the front ends, DERIVED, never a written list ----------------------
# The task brief and the previous census disagree about how many there are
# (nine vs the fourteen `config-lang.in' declare), so neither is trusted:
# the tree is asked.
DIRS=$(ls config-lang.in */config-lang.in 2>/dev/null | sed 's|/config-lang.in||' | grep -v '^config-lang.in$' | sort)
ND=$(echo "$DIRS" | wc -w)
[ "$ND" -ge 10 ] || { echo "REFUSE: found only $ND config-lang.in directories"; exit 9; }
# c-family/ and analyzer/ are not --enable-languages values and have no
# config-lang.in, but they are compiled in EVERY configuration, so they are
# the maximum-exposure case and are scored alongside.
DIRS="$DIRS c-family analyzer"
echo "front ends: $ND with config-lang.in, plus c-family and analyzer (always built)"
echo

if [ -n "$D" ] && [ -d "$D/gcc" ]; then
  # Every .Po in the build, once.  `tm.h' at the build ROOT is the primary's
  # chain; `<base>-inc/tm.h' is a base naming itself and is NOT a leak, so
  # the two are counted separately rather than summed.
  find "$D/gcc" -name '*.Po' -print > "$WORK/po" 2>/dev/null || true
  NPO=$(wc -l < "$WORK/po")
  echo "build dir: $D  ($NPO .Po dependency records)"
  [ "$NPO" -gt 0 ] || echo "  NOTE: no .Po records -- OBJS columns will read '-' (NOT 'zero')"
else
  : > "$WORK/po"; NPO=0
  echo "no build dir given: OBJS columns read '-' meaning UNMEASURED, not zero"
fi
echo

printf '%-12s %6s %9s %8s %9s %9s\n' DIR files SPELLS-TM SURFACE OBJS-BUILT OBJS-TM
for d in $DIRS; do
  [ -d "$d" ] || continue
  nf=$(find "$d" -name '*.cc' -o -name '*.c' -o -name '*.h' | wc -l)
  # the three spellings of the channel, in one pass
  ntm=$(grep -rlE '#[ \t]*include[ \t]+("tm\.h"|MT_HEADER[ \t]*\([ \t]*tm\.h[ \t]*\)|BASE_HEADER[ \t]*\([ \t]*tm\.h[ \t]*\))' \
          --include='*.cc' --include='*.c' --include='*.h' "$d" 2>/dev/null | wc -l)
  # surface: intersect the directory's identifiers with the vocabulary
  grep -rhoE '\b[A-Za-z_][A-Za-z_0-9]*\b' --include='*.cc' --include='*.c' --include='*.h' "$d" 2>/dev/null \
    | sort -u > "$WORK/ids"
  ns=$(comm -12 "$WORK/ids" "$WORK/vocab" | wc -l)
  if [ "$NPO" -gt 0 ]; then
    # objects of this front end: .Po under a path naming the directory
    grep "/$d/" "$WORK/po" > "$WORK/po.$$" || true
    no=$(wc -l < "$WORK/po.$$")
    if [ "$no" = 0 ]; then
      nt='-'; no='-'
    else
      nt=$(xargs grep -l "^$D/gcc/tm\.h\|[ :]$D/gcc/tm\.h" < "$WORK/po.$$" 2>/dev/null | wc -l)
    fi
  else
    no='-'; nt='-'
  fi
  printf '%-12s %6s %9s %8s %9s %9s\n' "$d" "$nf" "$ntm" "$ns" "$no" "$nt"
done
echo
echo "SPELLS-TM 0 does NOT mean the front end is clear: cp/ spells it in ONE"
echo "header (cp-tree.h) and 39 of 42 cp/*.o open the primary's chain through it."
echo "OBJS-TM '-' means UNMEASURED (front end not built, or no build dir given)."
