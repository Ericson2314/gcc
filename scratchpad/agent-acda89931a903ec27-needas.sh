#!/bin/sh
# Which of the 45 triples still lack a built `<triple>-as'.
OUT=${OUT:?tools dir}
LIST=${LIST:?triples}
for t in $LIST; do
  [ -x "$OUT/$t-as" ] || echo "$t"
done
