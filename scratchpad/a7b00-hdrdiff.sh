#!/bin/sh
# ACCEPTANCE ARM 3: two targets on DIFFERENT back ends must have DIFFERENT
# installed headers.  Identical means the primary leaked into the install.
#
# The md5 of `tm.h' alone is not enough evidence and would have passed a broken
# install: the installed `tm.h' is a one-line shim naming a per-triple header,
# so it differs whenever the TRIPLES differ, even if both shims pointed at the
# same back end's chain.  So the shim is followed and the file it names is
# compared too, and the back-end config header each chain reaches is printed.
set -u
I=${1:?install lib/gcc/<version> dir}
A=${2:?target A}
B=${3:?target B}
bad=0
for f in tm.h options.h insn-modes.h insn-constants.h tconfig.h auto-host.h version.h; do
  fa=$I/$A/include/$f; fb=$I/$B/include/$f
  [ -f "$fa" ] || { echo "$f: MISSING for $A"; bad=$((bad+1)); continue; }
  [ -f "$fb" ] || { echo "$f: MISSING for $B"; bad=$((bad+1)); continue; }
  ma=$(md5sum < "$fa" | cut -c1-12); mb=$(md5sum < "$fb" | cut -c1-12)
  if [ "$ma" = "$mb" ]; then echo "$f: IDENTICAL $ma"
  else echo "$f: DIFFER  $A=$ma  $B=$mb"; fi
done
echo
for t in $A $B; do
  s=$(sed -n 's/^#include "\(.*\)"/\1/p' "$I/$t/include/tm.h" | head -1)
  echo "$t: tm.h -> $s"
  echo "  back-end config headers it names:"
  grep -o 'config/[a-z0-9_]*/[a-z0-9_.-]*' "$I/$t/include/$s" | sort -u | sed 's/^/    /'
done
# THE ARM THAT CAN FAIL: the two chains must not name the same back-end dir.
da=$(grep -o 'config/[a-z0-9_]*/' "$I/$A/include/$(sed -n 's/^#include "\(.*\)"/\1/p' "$I/$A/include/tm.h"|head -1)" | sort -u | tr '\n' ' ')
db=$(grep -o 'config/[a-z0-9_]*/' "$I/$B/include/$(sed -n 's/^#include "\(.*\)"/\1/p' "$I/$B/include/tm.h"|head -1)" | sort -u | tr '\n' ' ')
echo
echo "$A back-end dirs: $da"
echo "$B back-end dirs: $db"
if [ "$da" = "$db" ]; then
  echo "FATAL: both targets' tm.h reach the SAME back end -- the primary leaked."
  exit 1
fi
echo "OK: the two installed tm.h chains reach different back ends."
[ "$bad" = 0 ] || { echo "FATAL: $bad missing file(s)"; exit 1; }
