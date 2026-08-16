#!/bin/sh
# Build `as' for whichever triples still lack one.  Gas only -- readelf comes
# from agent-acda89931a903ec27-readelf.sh, which explains why one readelf
# serves every target and why the ASSEMBLER may not be shared that way.
SRC=${SRC:?binutils source}
OUT=${OUT:?output bin dir}
LIST=${LIST:?triples}
HERE=$(dirname "$0")
for t in $LIST; do
  [ -x "$OUT/$t-as" ] && { echo "$t ALREADY"; continue; }
  SRC="$SRC" sh "$HERE/agent-acda89931a903ec27-gasbuild.sh" "$t" "$OUT" 2>&1 | head -2
done
echo "=== as total: $(ls "$OUT" | grep -c -- '-as$')"
