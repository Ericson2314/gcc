#!/bin/sh
# Task #160 -- the FOUR-VOCABULARY need scan.  Supersedes t152-need1.sh, which
# is kept unmodified so the two readings can be compared: a blind instrument
# reporting the old number on a corrected tree is evidence about the
# instrument, not about the work (PRINCIPLES sec 4).
#
# For each file, prints one line
#
#     <verdict>  <file>  v1=<n> v2=<n> v3=<n> v4=<n>   [first hit per vocabulary]
#
# with these verdicts, which are NOT a ranking but four different remedies:
#
#   CLEAR        no vocabulary hit.  The `tm.h' include is deletable as far as
#                THIS FILE'S OWN TEXT goes.  Still an UPPER BOUND: it says
#                nothing about the headers the file includes (see t160-hdr.sh).
#   OPTIONS-ONLY hit by the options.h vocabulary and by nothing else.  The
#                `tm.h' include is deletable IF an explicit `#include
#                "options.h"' replaces it -- 108 files in this tree already do
#                exactly that, so it is the existing idiom and not an invention.
#   REVOKE       hit by v1 (back-end chain), v3 (mkconfig top half) or v4
#                (insn-flags / insn-constants).  No local remedy: these need
#                the conversion layer.
#
# usage: t160-need2.sh <vocabdir> <file>...     (files relative to gcc/)
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
V=${1:?vocab dir}
shift
WANT=${WANT_ANCHOR:-48}
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "$WANT" ] \
  || { echo "FATAL: anchor != $WANT"; exit 9; }
for f in v1-config v2-options v3-tophalf v4-insn; do
  [ -s "$V/$f.txt" ] || { echo "FATAL: $V/$f.txt missing or empty"; exit 9; }
done
cd "$SRC/gcc"

for f in "$@"; do
  [ -f "$f" ] || { echo "FATAL: no such file: $f"; exit 9; }
done

# One awk pass per file over four vocabularies.  String literals and // are
# stripped; #define/#undef/#include lines are skipped, exactly as the scan
# this replaces did, so the two are comparable on v1.
printf '%s\n' "$@" | awk -v V="$V" '
  BEGIN {
    split("v1-config v2-options v3-tophalf v4-insn", vf, " ")
    for (k = 1; k <= 4; k++)
      while ((getline l < (V "/" vf[k] ".txt")) > 0) voc[k, l] = 1
    nv = 0
    for (k = 1; k <= 4; k++) { }
  }
  {
    f = $0
    for (k = 1; k <= 4; k++) { c[k] = 0; first[k] = "" }
    while ((getline line < f) > 0) {
      raw = line
      gsub(/"[^"]*"/, "", line); sub(/\/\/.*$/, "", line)
      if (line ~ /^[ \t]*#[ \t]*(define|undef|include)/) continue
      n = split(line, w, /[^A-Za-z0-9_]+/)
      for (i = 1; i <= n; i++)
        for (k = 1; k <= 4; k++)
          if ((k, w[i]) in voc) {
            c[k]++
            if (first[k] == "") first[k] = w[i]
          }
    }
    close(f)
    hard = c[1] + c[3] + c[4]
    if (hard == 0 && c[2] == 0)      v = "CLEAR"
    else if (hard == 0)              v = "OPTIONS-ONLY"
    else                             v = "REVOKE"
    printf "%-13s %-46s v1=%d v2=%d v3=%d v4=%d  %s %s %s %s\n", v, f,
           c[1], c[2], c[3], c[4], first[1], first[2], first[3], first[4]
  }'
