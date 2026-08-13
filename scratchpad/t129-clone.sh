#!/bin/sh
# #129 -- derive my own build-dir scripts from #128's, so I do not share /tmp/b128.
# REFUSES if the substitution left a `b128' or a `t128-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc mkq dbg fn; do
  [ -f "t128-$f.sh" ] || { echo "MISSING t128-$f.sh"; exit 9; }
  sed -e 's#/tmp/b128#/tmp/b129#g' -e 's#b128-inst#b129-inst#g' \
      -e 's#sc128-#sc129-#g' -e 's#t128-#t129-#g' "t128-$f.sh" > "t129-$f.sh"
  chmod +x "t129-$f.sh"
  if grep -q 'b128' "t129-$f.sh"; then echo "FAIL leftover b128 in t129-$f.sh"; exit 9; fi
  if grep -q 't128-' "t129-$f.sh"; then echo "FAIL leftover t128- in t129-$f.sh"; exit 9; fi
  echo "wrote t129-$f.sh ($(grep -c 'b129' "t129-$f.sh") b129 mentions)"
done
