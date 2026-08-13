#!/bin/sh
# #128 -- derive my own build-dir scripts from #127's, so I do not share /tmp/b127.
# REFUSES if the substitution left a `b127' or a `t127-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc mkq dbg fn; do
  [ -f "t127-$f.sh" ] || { echo "MISSING t127-$f.sh"; exit 9; }
  sed -e 's#/tmp/b127#/tmp/b128#g' -e 's#b127-inst#b128-inst#g' \
      -e 's#sc127-#sc128-#g' -e 's#t127-#t128-#g' "t127-$f.sh" > "t128-$f.sh"
  chmod +x "t128-$f.sh"
  if grep -q 'b127' "t128-$f.sh"; then echo "FAIL leftover b127 in t128-$f.sh"; exit 9; fi
  if grep -q 't127-' "t128-$f.sh"; then echo "FAIL leftover t127- in t128-$f.sh"; exit 9; fi
  echo "wrote t128-$f.sh ($(grep -c 'b128' "t128-$f.sh") b128 mentions)"
done
