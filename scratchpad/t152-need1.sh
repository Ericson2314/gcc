#!/bin/sh
# Task #152 Phase 1 -- the RAW, deliberately OVER-BROAD need scan, re-run per
# candidate file at anchor 48.
#
# Vocabulary: every identifier `#define'd anywhere under `gcc/config/', plus
# `gcc/defaults.h' AND `gcc/multi-target-macros.h' (the latter is new -- the
# conversion layer moved there, and leaving it out would shrink the vocabulary
# by exactly the 65 converted names, i.e. would GRANT deletions it should
# revoke).
#
# Over-broad on purpose: such an instrument can only REVOKE a deletion, never
# authorise one, which is the safe direction (PRINCIPLES sec 4).  The refined
# variant in t141-need.sh was measured GRANTING a wrong deletion twice and is
# deliberately not used here.
#
# usage: t152-need1.sh <file> [file...]     (paths relative to gcc/)
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
WANT=${WANT_ANCHOR:-48}
GOT=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$GOT" = "$WANT" ] || { echo "FATAL: anchor $GOT != $WANT"; exit 9; }
cd "$SRC/gcc"

V=$(mktemp)
{ find config -name '*.h'; echo defaults.h; echo multi-target-macros.h; } \
  | xargs grep -h '^[ \t]*#[ \t]*define[ \t]' \
  | sed 's/^[ \t]*#[ \t]*define[ \t]*//; s/[ \t(].*//' \
  | grep '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u > $V
NV=$(wc -l < $V)
[ "$NV" -gt 1000 ] || { echo "FATAL: vocabulary only $NV names -- did not read config/"; exit 8; }
# Non-vacuity: the vocabulary must contain names from the conversion layer,
# or the scan is measuring the wrong file set and every candidate scores zero
# for the wrong reason.
for n in POINTER_SIZE FIRST_PSEUDO_REGISTER BITS_PER_WORD; do
  grep -qx "$n" $V || { echo "FATAL: vocabulary lacks $n"; exit 8; }
done
echo "# raw vocabulary: $NV identifiers"

rc=0
for f in "$@"; do
  [ -f "$f" ] || { echo "FATAL: no such file: $f"; exit 9; }
  hits=$(awk -v VOCAB=$V '
    BEGIN { while ((getline l < VOCAB) > 0) voc[l] = 1 }
    { line = $0
      gsub(/"[^"]*"/, "", line); sub(/\/\/.*$/, "", line)
      if (line ~ /^[ \t]*#[ \t]*(define|undef|include)/) next
      n = split(line, w, /[^A-Za-z0-9_]+/)
      for (i = 1; i <= n; i++) if (w[i] in voc) print FNR ": " w[i] " \t" $0
    }' "$f")
  if [ -n "$hits" ]; then
    echo "REVOKE  $f"; printf '%s\n' "$hits" | sed 's/^/    /'; rc=1
  else
    echo "CLEAR   $f  (0 of $NV vocabulary names)"
  fi
done
rm -f $V
exit $rc
