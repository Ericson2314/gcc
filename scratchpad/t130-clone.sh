#!/bin/sh
# #130 -- derive my own build-dir scripts from #129's, so I do not share /tmp/b129.
# REFUSES if the substitution left a `b129' or a `t129-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc mkq dbg fn syms family reconf-gcc; do
  [ -f "t129-$f.sh" ] || { echo "MISSING t129-$f.sh"; exit 9; }
  sed -e 's#/tmp/b129#/tmp/b130#g' -e 's#b129-inst#b130-inst#g' \
      -e 's#sc129-#sc130-#g' -e 's#t129-#t130-#g' "t129-$f.sh" > "t130-$f.sh"
  chmod +x "t130-$f.sh"
  if grep -q 'b129' "t130-$f.sh"; then echo "FAIL leftover b129 in t130-$f.sh"; exit 9; fi
  if grep -q 't129-' "t130-$f.sh"; then echo "FAIL leftover t129- in t130-$f.sh"; exit 9; fi
  echo "wrote t130-$f.sh ($(grep -c 'b130' "t130-$f.sh") b130 mentions)"
done
