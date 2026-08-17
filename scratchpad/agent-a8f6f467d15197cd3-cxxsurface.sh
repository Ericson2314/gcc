#!/bin/sh
# agent-a8f6f467d15197cd3-cxxsurface.sh -- DERIVE (not enumerate by hand) the
# per-target macro surface of a front-end directory.
#
# WHY THIS IS NOT agent-a260445cf27ba480a-cxxmacros.sh.  That script takes a
# HAND-WRITTEN list of 15 macros and reports each one's definer count.  It
# cannot find a macro nobody thought of, and the top of its ranking is exactly
# the set its author was already working on.  This one computes the
# INTERSECTION of two derived sets:
#
#   V  = every identifier `#define'd anywhere under gcc/config/ or in
#        gcc/defaults.h                     -- the target-macro vocabulary
#   U  = every identifier a front-end directory SPELLS, outside its own
#        `#define'/`#undef' lines
#
# and ranks V n U by how many distinct config/ files define it.  A name with
# ONE definer is a back end talking to itself; a name with MANY is a question
# the front end asks and the PRIMARY answers for all 47 back ends.
#
# THE UNDERCOUNT THE LAST TASK PAID FOR IS NOT FIXED HERE, DELIBERATELY.
# Counting the back ends that SPELL a macro undercounts its population:
# four back ends reached `ptrmemfunc_vbit_in_delta' through defaults.h's
# FUNCTION_BOUNDARY fallback, so the true population was 8 where a spelling
# census said 5.  Only the real preprocessor over each base's own tm-<base>.h
# can settle that (agent-ad6a5c1d2539f5e18-vbitcensus.sh does exactly that for
# one macro).  So the DEFINERS column here is a LOWER BOUND on divergence and
# is labelled as one; it is a RANKING instrument, and the ranking is the
# deliverable.  Never quote its number as a population.
#
# Blind spots, stated:
#  * word-matching, so a macro spelled only in a comment counts as a use;
#  * it cannot see a macro reached through another macro (the `mode_ibit'
#    shape) nor one reached through a header the front end includes;
#  * `defaults.h' is treated as one definer file like any other.
# All three are in the over-broad direction: this instrument can only ADD
# suspects, never clear one, per PRINCIPLES ("when an instrument can only take
# away, make it too eager; when it can grant, make it exact").
set -eu
S=${1:?srcdir}
DIR=${2:?front-end dir under gcc/, e.g. cp}
S=$(cd "$S" && pwd)
cd "$S/gcc"
[ -d "$DIR" ] || { echo "REFUSE: no such directory gcc/$DIR"; exit 9; }

T=$(mktemp -d)
trap 'rm -rf "$T"' 0

# ---- V: the target-macro vocabulary -------------------------------------
# `#  define X' as well as `#define X'; the name may be followed by `(' .
grep -rhE '^[[:space:]]*#[[:space:]]*define[[:space:]]+[A-Za-z_][A-Za-z_0-9]*' \
     config/ defaults.h 2>/dev/null \
  | sed -E 's/^[[:space:]]*#[[:space:]]*define[[:space:]]+([A-Za-z_][A-Za-z_0-9]*).*/\1/' \
  | sort -u > "$T/vocab"
NV=$(wc -l < "$T/vocab")
[ "$NV" -ge 5000 ] || { echo "REFUSE: vocabulary is $NV names, expected thousands"; exit 9; }

# ---- U: identifiers the front end spells --------------------------------
# Drop its OWN #define/#undef lines so a front-end-private macro cannot score.
find "$DIR" -name '*.cc' -o -name '*.h' -o -name '*.c' > "$T/files"
NF=$(wc -l < "$T/files")
[ "$NF" -ge 1 ] || { echo "REFUSE: no sources in gcc/$DIR"; exit 9; }
grep -hvE '^[[:space:]]*#[[:space:]]*(define|undef)[[:space:]]' $(cat "$T/files") \
  | grep -ohE '\<[A-Za-z_][A-Za-z_0-9]*\>' | sort -u > "$T/used"

comm -12 "$T/vocab" "$T/used" > "$T/hits"

# ---- CONTROLS -----------------------------------------------------------
# Positive: a name every reader of this vocabulary must find.  Negative: a
# name that must be in neither set.  An empty intersection and a broken pipe
# look identical, which is the failure this refuses to make.
grep -qx BITS_PER_WORD "$T/vocab" || { echo "REFUSE: BITS_PER_WORD absent from vocabulary"; exit 9; }
grep -qx MT_NO_SUCH_MACRO_XYZ "$T/vocab" && { echo "REFUSE: negative control in vocabulary"; exit 9; }
NH=$(wc -l < "$T/hits")
[ "$NH" -ge 1 ] || { echo "REFUSE: gcc/$DIR intersects the vocabulary in 0 names"; exit 9; }
echo "dir=gcc/$DIR files=$NF vocab=$NV intersect=$NH   controls ok"
echo

# ---- rank ---------------------------------------------------------------
printf '%-40s %8s %8s  %s\n' MACRO 'definers' "$DIR/uses" 'definer files (first 5)'
for m in $(cat "$T/hits"); do
  grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\>" config/ defaults.h 2>/dev/null \
    | sort -u > "$T/d"
  d=$(wc -l < "$T/d")
  # only names with a real divergence are interesting; 1 definer is a back end
  # talking to itself.  MIN_DEFINERS is overridable so the full list can be
  # dumped without editing the script.
  [ "$d" -ge "${MIN_DEFINERS:-2}" ] || continue
  u=$(grep -rwc -- "$m" $(cat "$T/files") 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
  who=$(sed 's|^config/||' "$T/d" | head -5 | tr '\n' ' ')
  printf '%-40s %8s %8s  %s\n' "$m" "$d" "$u" "$who"
done | sort -k2,2nr -k3,3nr
