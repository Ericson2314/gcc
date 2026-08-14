#!/bin/sh
# #163 -- configure the 47-back-end build for this task, from an immutable
# snapshot.  A wrapper so the (very long) triple list is read from the file
# that owns it rather than pasted onto a command line.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
SRC=${SRC:?set SRC}
LIST=$(grep -v '^#' "$S/backends-47.txt" | grep -v '^$' | paste -sd, -)
n=$(printf '%s' "$LIST" | tr ',' '\n' | grep -c .)
[ "$n" = 47 ] || { echo "FATAL: read $n triples, expected 47"; exit 9; }
echo "list: $n triples"
SRC="$SRC" WANT_ANCHOR="${WANT_ANCHOR:?}" sh "$S/tb1-conf.sh" "$D" "$LIST"
