#!/bin/sh
# #127 -- derive my own build-dir scripts from #126's, so I do not share /tmp/b126.
# REFUSES if the substitution left a `b126' or a `t126-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc mkq dbg; do
  [ -f "t126-$f.sh" ] || { echo "MISSING t126-$f.sh"; exit 9; }
  sed -e 's#/tmp/b126#/tmp/b127#g' -e 's#b126-inst#b127-inst#g' \
      -e 's#sc126-#sc127-#g' -e 's#t126-#t127-#g' "t126-$f.sh" > "t127-$f.sh"
  chmod +x "t127-$f.sh"
  if grep -q 'b126' "t127-$f.sh"; then echo "FAIL leftover b126 in t127-$f.sh"; exit 9; fi
  if grep -q 't126-' "t127-$f.sh"; then echo "FAIL leftover t126- in t127-$f.sh"; exit 9; fi
  echo "wrote t127-$f.sh ($(grep -c 'b127' "t127-$f.sh") b127 mentions)"
done
