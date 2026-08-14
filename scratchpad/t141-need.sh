#!/bin/sh
# t141 arm 2: for each shared TU that reaches tm.h, WHAT does it need from it?
#
# "Includes tm.h" and "depends on target-specific content" are two claims.
# This is the instrument for the second.
#
# THE VOCABULARY is deliberately OVER-BROAD, per PRINCIPLES sec 4: every
# identifier `#define'd anywhere under gcc/config/, plus gcc/defaults.h.  An
# over-broad vocabulary can only REVOKE a deletion, never authorise one --
# which is the safe direction.  The recorded failure this avoids is the
# `-dM'-difference instrument that derived tm.h's macro set from ONE configured
# target and was blind to TARGET_OVERRIDES_FORMAT_INIT in config/mingw/.
#
# THE SHAPE CLASSIFICATION answers the question the plan turns on: a macro used
# as a value can become a runtime read; a macro on an `#if' line or in an array
# bound cannot.  Note PRINCIPLES: `#if FOO' on an UNDEFINED FOO silently
# evaluates FALSE, so a conditional use is the dangerous case, not the safe one.
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
WANT_ANCHOR=${WANT_ANCHOR:-47}
GOT=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$GOT" = "$WANT_ANCHOR" ] || { echo "FATAL: anchor $GOT != $WANT_ANCHOR" >&2; exit 9; }
cd "$SRC/gcc"

V=/tmp/t141-vocab.$$
VR=/tmp/t141-vocab-raw.$$
VS=/tmp/t141-vocab-shared.$$
# object-like and function-like #defines under config/, plus defaults.h
{ find config -name '*.h'; echo defaults.h; } | xargs grep -h '^[ \t]*#[ \t]*define[ \t]' \
  | sed 's/^[ \t]*#[ \t]*define[ \t]*//; s/[ \t(].*//' | grep '^[A-Za-z_][A-Za-z0-9_]*$' \
  | sort -u > $VR
NV=$(wc -l < $VR)
[ "$NV" -gt 1000 ] || { echo "FATAL: vocabulary only $NV names -- did not read config/" >&2; exit 8; }
echo "# raw vocabulary: $NV identifiers #defined under config/ or in defaults.h"

if [ "${REFINE:-1}" = 1 ]; then
  # REFINEMENT, and the reason for it: the raw set is 10845 names and includes
  # short lowercase back-end-local macros (`sp', `v1', `bool', `vector') that
  # no shared TU is depending on config/ for.  Two filters, each of which can
  # only SHRINK the set, so the refined figure is a LOWER bound and the raw one
  # an UPPER bound -- they are reported as such and never quoted as one number.
  #   (a) shape: ALL-CAPS, >= 4 chars -- the tm.h macro convention
  #   (b) authority: NOT also #defined in shared gcc/ code outside config/.
  #       If a shared header defines it too, the TU is not reaching config/
  #       for it, and scoring it would inflate the residue.
  #       defaults.h is EXCLUDED from this subtraction, and that exclusion is
  #       the whole point: defaults.h is where the shared FALLBACK for a
  #       per-target macro lives (JUMP_TABLES_IN_TEXT_SECTION shape).  Leaving
  #       it in subtracted exactly the population under study -- measured, the
  #       first draft of this filter did that and undercounted.
  find . -name '*.h' | grep -v '^\./config/' | grep -v '^\./testsuite/' \
    | grep -v '^\./defaults\.h$' \
    | xargs grep -h '^[ \t]*#[ \t]*define[ \t]' 2>/dev/null \
    | sed 's/^[ \t]*#[ \t]*define[ \t]*//; s/[ \t(].*//' | grep '^[A-Za-z_][A-Za-z0-9_]*$' \
    | sort -u > $VS
  grep -E '^[A-Z][A-Z0-9_]{3,}$' $VR | comm -23 - $VS > $V
  echo "# refined vocabulary: $(wc -l < $V) (ALL-CAPS >=4, not also defined in shared gcc/ headers)"
else
  cp $VR $V
fi

# TUs to examine: shared (non-config) TUs that reach tm.h
grep '^REACH' "$SRC/scratchpad/t141-census.txt" | cut -f2 | grep -v '^config/' > /tmp/t141-shared.$$
NS=$(wc -l < /tmp/t141-shared.$$)
echo "# shared TUs reaching tm.h: $NS"

awk -v VOCAB=$V '
BEGIN { while ((getline l < VOCAB) > 0) voc[l] = 1 }
FNR == 1 { file = FILENAME }
{
  line = $0
  # strip string literals and line comments so quoted text does not score
  gsub(/"[^"]*"/, "", line)
  sub(/\/\/.*$/, "", line)
  cond = (line ~ /^[ \t]*#[ \t]*(if|ifdef|ifndef|elif)/)
  n = split(line, w, /[^A-Za-z0-9_]+/)
  for (i = 1; i <= n; i++) {
    id = w[i]
    if (!(id in voc)) continue
    # ignore the defines/undefs the file makes ITSELF
    if (line ~ ("^[ \t]*#[ \t]*(define|undef)[ \t]+" id "([ \t(]|$)")) continue
    key = file SUBSEP id
    if (!(key in seen)) { seen[key] = 1; uses[file] = uses[file] " " id }
    if (cond) { ck = file SUBSEP id
                if (!(ck in cseen)) { cseen[ck] = 1; conds[file] = conds[file] " " id } }
    # array-bound shape: identifier inside [ ] on a declaration-looking line
    if (line ~ ("\\[[^]]*" id "[^]]*\\]")) { ak = file SUBSEP id
                if (!(ak in aseen)) { aseen[ak] = 1; arrs[file] = arrs[file] " " id } }
  }
}
END {
  for (f in uses) {
    nu = split(uses[f], a, " ")
    nc = split(conds[f], b, " ")
    na = split(arrs[f], c, " ")
    printf "%s\tuse=%d\tcond=%d\tarr=%d\t%s\tCOND:%s\tARR:%s\n", f, nu, nc, na, substr(uses[f],2), substr(conds[f],2), substr(arrs[f],2)
  }
}
' $(cat /tmp/t141-shared.$$) > "$SRC/scratchpad/t141-need.txt"

NR_=$(wc -l < "$SRC/scratchpad/t141-need.txt")
[ "$NR_" -gt 50 ] || { echo "FATAL: need-scan produced $NR_ rows -- vacuous" >&2; exit 8; }

echo "# TUs with at least one config-vocabulary identifier: $NR_ of $NS"
echo "# TUs with ZERO such identifier (candidate: include is pure noise): $((NS - NR_))"
echo "# --- TUs by number of distinct identifiers used:"
awk -F'\t' '{split($2,a,"="); n=a[2]; b = (n==1?"1":(n<=3?"2-3":(n<=10?"4-10":(n<=30?"11-30":"31+")))); c[b]++} END {for (k in c) print c[k], k}' "$SRC/scratchpad/t141-need.txt" | sort -k2
echo "# --- TUs using at least one identifier on an #if line (HARD RESIDUE):"
awk -F'\t' '{split($3,a,"="); if (a[2]>0) n++} END {print n+0}' "$SRC/scratchpad/t141-need.txt"
echo "# --- TUs using at least one identifier in an array bound (HARD RESIDUE):"
awk -F'\t' '{split($4,a,"="); if (a[2]>0) n++} END {print n+0}' "$SRC/scratchpad/t141-need.txt"
rm -f $V $VR $VS /tmp/t141-shared.$$
