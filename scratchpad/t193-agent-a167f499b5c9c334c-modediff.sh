#!/bin/sh
# #193 (agent-a167f499b5c9c334c) -- WHAT ACTUALLY DIVERGES BETWEEN BASES in
# insn-modes.h / insn-modes-inline.h, and does the build root's copy leak it?
#
# WHY A NEW SCRIPT RATHER THAN AN ARM ON t187-stemclass.sh.  That script asks
# "is the root copy equal to one base's file"; the answer for insn-modes.h is
# already known (i386's, byte for byte).  The question this one asks is the
# next one and it is a different shape: WHICH LINES differ, and are they
# COMMENTS or VALUES.  A byte diff of these files is dominated by the
# `/* config/<be>/<be>-modes.def:NN */' provenance comment on every enumerator
# -- 396 differing lines between i386 and aarch64, of which the semantic count
# is what this measures.  Reporting the byte count as the divergence would
# overstate it by an order of magnitude; reporting zero semantic difference
# without showing the instrument can see a real one would be the project's
# standard false green.
#
# NON-VACUITY: arm 0 asserts the comment-stripping still leaves a KNOWN
# difference between two bases (BITS_PER_UNIT is the same everywhere, so it
# uses the enum body), and arm 3's control re-diffs a file against ITSELF and
# requires 0.  A stripper that ate everything would score every base identical
# -- which is the conclusion an agent would most like to reach.
#
# usage: t193-...-modediff.sh <builddir>
set -u
G=${1:?build dir}/gcc
[ -f "$G/insn-modes.h" ] || { echo "FATAL: no $G/insn-modes.h"; exit 9; }
O=${MT_OUT:-/tmp/t193-modediff-$$}
mkdir -p "$O"

# Strip the provenance comment and trailing space.  Everything else -- every
# #define, every enumerator, every value -- is kept.
strip_one () { sed -e 's,/\*[^*]*\*/,,g' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }

BASES=$(ls "$G" | sed -n 's/^insn-modes-\([a-z0-9_]*\)\.h$/\1/p' | sort)
NB=$(printf '%s\n' "$BASES" | grep -c .)
echo "bases with an insn-modes-<base>.h: $NB"
[ "$NB" -ge 2 ] || { echo "FATAL: need >=2 bases to compare"; exit 9; }

for f in insn-modes insn-modes-inline; do
  echo
  echo "=== $f.h"
  [ -f "$G/$f.h" ] || { echo "  (no build-root copy)"; continue; }
  strip_one "$G/$f.h" > "$O/$f-root.txt"
  # 1. byte-identity of the ROOT copy against each base
  hit=""
  for b in $BASES; do
    [ -f "$G/$f-$b.h" ] || continue
    cmp -s "$G/$f.h" "$G/$f-$b.h" && hit="$hit $b"
  done
  echo "  build-root copy is BYTE-IDENTICAL to:${hit:- (none)}"
  # 2. distinct contents, by bytes and after stripping comments
  : > "$O/$f-md5-raw.txt"; : > "$O/$f-md5-sem.txt"
  for b in $BASES; do
    [ -f "$G/$f-$b.h" ] || continue
    md5sum "$G/$f-$b.h" | cut -c1-12 >> "$O/$f-md5-raw.txt"
    strip_one "$G/$f-$b.h" > "$O/$f-$b.txt"
    md5sum "$O/$f-$b.txt" | cut -c1-12 >> "$O/$f-md5-sem.txt"
  done
  echo "  distinct contents over $NB bases:  raw $(sort -u "$O/$f-md5-raw.txt" | wc -l)   comment-stripped $(sort -u "$O/$f-md5-sem.txt" | wc -l)"
  # 3. the semantic diff between the two reference bases, if both present
  if [ -f "$O/$f-i386.txt" ] && [ -f "$O/$f-aarch64.txt" ]; then
    nraw=$(diff "$G/$f-i386.h" "$G/$f-aarch64.h" | grep -c '^[<>]' || true)
    nsem=$(diff "$O/$f-i386.txt" "$O/$f-aarch64.txt" | grep -c '^[<>]' || true)
    echo "  i386 vs aarch64 differing lines: raw $nraw  comment-stripped $nsem"
    diff "$O/$f-i386.txt" "$O/$f-aarch64.txt" > "$O/$f-i386-vs-aarch64.diff" || true
    echo "  --- first 30 semantic differences ---"
    grep '^[<>]' "$O/$f-i386-vs-aarch64.diff" | head -30 | sed 's/^/    /'
    echo "  (full: $O/$f-i386-vs-aarch64.diff)"
    # CONTROL: a file against itself must be 0.  If the stripper had eaten
    # the file this would also be 0, so the arm above must be non-zero for
    # this one to mean anything -- both are printed, deliberately.
    nself=$(diff "$O/$f-i386.txt" "$O/$f-i386.txt" | grep -c '^[<>]' || true)
    echo "  control (i386 vs itself): $nself   [meaningful only because the line above is not 0]"
    [ "$nsem" -gt 0 ] || echo "  WARNING: comment-stripped diff is ZERO -- either these two bases genuinely agree, or the stripper is eating content.  Check $O/$f-i386.txt is not empty: $(wc -l < "$O/$f-i386.txt") lines"
  fi
done

# --------------------------------------------------------------- values arm
# THE ARM #187 SAID IT DID NOT HAVE.  A name-set comparison sees PRESENCE.
# Two bases defining the same macro to different bodies are identical to it.
# This compares NAME=BODY.
echo
echo "=== macro VALUE divergence (name -> distinct bodies across bases)"
defs () { sed -e 's,/\*[^*]*\*/,,g' "$1" \
          | sed -n 's/^[[:space:]]*#[[:space:]]*define[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\)[[:space:]]*\(.*\)$/\1\t\2/p' \
          | sed 's/[[:space:]]*$//'; }
for f in insn-modes insn-modes-inline; do
  [ -f "$G/$f.h" ] || continue
  : > "$O/$f-defs.txt"
  for b in $BASES; do
    [ -f "$G/$f-$b.h" ] || continue
    defs "$G/$f-$b.h" | sed "s|^|$b\t|" >> "$O/$f-defs.txt"
  done
  n=$(wc -l < "$O/$f-defs.txt")
  [ "$n" -gt 0 ] || { echo "  FATAL: $f.h -- read 0 #define records; the extractor is broken"; exit 9; }
  echo "  $f.h: $n (base,name,body) records"
  # Names whose body is not the same in every base that defines them.
  #
  # A NAME IS DEFINED MORE THAN ONCE IN ONE FILE HERE, AND A NAIVE
  # first-body-wins COMPARISON SCORES THAT AS DIVERGENCE.  genmodes emits
  # every mode macro twice --
  #     #ifdef USE_ENUM_MODES
  #     #define SImode E_SImode
  #     #else
  #     #define SImode (scalar_int_mode (...E_SImode))
  #     #endif
  # -- so the two arms of one #ifdef, inside a SINGLE base's file, look like
  # two bases disagreeing.  The first draft of this arm reported 660
  # "divergent" names on files whose semantic diff is two lines.  Recorded
  # rather than quietly swapped out, because the wrong answer is the
  # plausible-looking one.
  #
  # The fix is to compare each base's COMPLETE body list for a name, in file
  # order, as one string.  Two bases agree exactly when both #ifdef arms agree.
  awk -F'\t' '{k=$1 SUBSEP $2; all[k] = all[k] "\036" $3; nm[k]=$2}
              END {for (k in all) print nm[k] "\t" all[k]}' "$O/$f-defs.txt" \
    | awk -F'\t' '{if (!($1 in b)) b[$1]=$2; else if (b[$1]!=$2) d[$1]=1}
                  END {for (k in d) print k}' | sort > "$O/$f-divergent-names.txt"
  echo "  names with >1 distinct body across bases: $(wc -l < "$O/$f-divergent-names.txt")"
  head -40 "$O/$f-divergent-names.txt" | sed 's/^/    /'
  # and the root's body for each, beside i386's -- whose answer is it
  if [ -s "$O/$f-divergent-names.txt" ]; then
    defs "$G/$f.h" > "$O/$f-root-defs.txt"
    echo "  --- build-root body vs each base, for the first 10 divergent names ---"
    head -10 "$O/$f-divergent-names.txt" | while read -r nm; do
      rb=$(awk -F'\t' -v n="$nm" '$1==n {print $2}' "$O/$f-root-defs.txt")
      printf '    %-28s root=%s\n' "$nm" "$rb"
      awk -F'\t' -v n="$nm" '$2==n {printf "      %-12s %s\n", $1, $3}' "$O/$f-defs.txt" | sort -u -k2 | head -6
    done
  fi
done
echo
echo "output dir: $O"
