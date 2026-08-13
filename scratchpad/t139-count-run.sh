#!/bin/sh
# #139 -- run the counting cc1 over the corpus and aggregate the per-file
# evaluation counts for `UNITS_PER_WORD' and `Pmode'.
#
# NON-VACUITY, fatal: both macros must be seen at least once, from at least
# two distinct files.  A run where the counters read zero is indistinguishable
# from "the injection did nothing", which is the null result this project
# keeps mistaking for a measurement -- so zero is a failure here, never a
# finding of "cold".
#
# usage: t139-count-run.sh <builddir> <corpus> <cfg> <outfile>
set -u
B=${1:?builddir}; CORPUS=${2:?corpus}; CFG=${3:?cfg}; O=${4:?outfile}
[ -x "$B/gcc/cc1" ] || { echo "FATAL: no cc1 at $B/gcc/cc1"; exit 9; }
[ -s "$CFG" ] || { echo "FATAL: config missing: $CFG"; exit 9; }
: > "$O" || exit 9

nin=0
for f in "$CORPUS"/*.i; do
  nin=$((nin+1))
  "$B/gcc/cc1" -quiet -nostdinc -std=gnu17 -O2 -ftarget-config="$CFG" \
    "$f" -o /dev/null 2>> "$O" > /dev/null
done
[ "$nin" -ge 8 ] || { echo "FATAL: only $nin inputs"; exit 9; }

for tag in UNITS_PER_WORD Pmode; do
  tot=$(awk -v t="$tag" '$2==t && $3=="total" {s+=$4} END {print s+0}' "$O")
  nf=$(awk -v t="$tag" '$2==t && $3!="total" {print $4}' "$O" | sort -u | wc -l)
  ovf=$(awk -v t="$tag" '$2==t && $3=="total" {s+=$8} END {print s+0}' "$O")
  echo "=== $tag: $tot evaluations over $nin TUs, $nf distinct source files, table overflow $ovf"
  [ "$tot" -gt 0 ] || { echo "FATAL: $tag counted zero -- injection or run is broken"; exit 9; }
  [ "$nf" -ge 2 ] || { echo "FATAL: $tag seen from $nf files -- implausible"; exit 9; }
  [ "$ovf" -eq 0 ] || echo "WARNING: counter table overflowed; per-file list is incomplete"
  awk -v t="$tag" '$2==t && $3!="total" {n[$4]+=$3} END {for (f in n) printf "%12d  %s\n", n[f], f}' "$O" \
    | sort -rn | head -20
  echo "--- share carried by the top files:"
  awk -v t="$tag" '$2==t && $3!="total" {n[$4]+=$3; s+=$3}
       END {i=0; for (f in n) v[++i]=n[f];
            m=i; for(a=1;a<m;a++) for(b=a+1;b<=m;b++) if(v[b]>v[a]){x=v[a];v[a]=v[b];v[b]=x}
            c=0; for(a=1;a<=m && a<=5;a++) c+=v[a];
            printf "    top 5 of %d files = %.1f%% of %d evaluations\n", m, 100*c/s, s;
            c=0; for(a=1;a<=m && a<=10;a++) c+=v[a];
            printf "    top 10 of %d files = %.1f%%\n", m, 100*c/s}' "$O"
done
