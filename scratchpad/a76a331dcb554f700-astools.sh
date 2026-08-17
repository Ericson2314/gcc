#!/bin/sh
# a76a331dcb554f700 -- assert every cross `as' in a tools dir EXECUTES.
#
# `OK' must mean the binary RAN, not that a path exists: a dangling symlink or
# a wrong-arch binary is exactly the shape that falls back on the host `as'
# three layers away (INSTRUMENTS.md, GUARD 3c).  It also reports the md5 count,
# because the previous sweep's 45 `readelf' turned out to be ONE multi-arch
# binary under 45 names -- "45 tools" was not 45 pieces of evidence.
set -u
T=${1:?tools dir}
n=0; bad=0
for a in "$T"/*-as; do
  [ -e "$a" ] || continue
  n=$((n+1))
  v=$("$a" --version 2>&1 | head -1)
  case "$v" in
    *"GNU assembler"*) printf '%-34s OK   %s\n' "$(basename "$a")" "$v" ;;
    *) printf '%-34s FAIL %s\n' "$(basename "$a")" "$v"; bad=$((bad+1)) ;;
  esac
done
echo
echo "as: $n present, $bad did not run"
m=$(md5sum "$T"/*-as 2>/dev/null | awk '{print $1}' | sort -u | wc -l)
echo "distinct md5 among the $n: $m"
[ "$n" -gt 0 ] || { echo "FATAL: no *-as in $T"; exit 9; }
[ "$bad" = 0 ] || exit 9
