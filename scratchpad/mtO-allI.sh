#!/bin/sh
# Every macro every `HeaderInclude' header contributes to the shared options.h.
# NOT just config/*/*-opts.h: the I records also name config/arm/aarch-common.h,
# config/csky/csky_opts.h and config/loongarch/loongarch-str.h, and a census
# keyed on the `-opts.h' spelling misses all three.
# usage: mtO-allI.sh <gcc-srcdir>
set -e
S=${1:?gcc srcdir}
here=$(dirname "$0")
hdrs=$(grep -A1 -h '^HeaderInclude' "$S"/config/*/*.opt | grep '^config/' | sort -u)
[ -n "$hdrs" ] || { echo "FATAL: no HeaderInclude records found"; exit 9; }
for h in $hdrs; do
  [ -f "$S/$h" ] || { echo "FATAL: $S/$h does not exist"; exit 9; }
  awk -v tag="$h" -f "$here/mtO-hdrmacros.awk" "$S/$h"
done
