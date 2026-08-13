#!/bin/sh
# #131 -- derive my own build-dir scripts from #130's, so I do not share /tmp/b130.
# REFUSES if the substitution left a `b130' or a `t130-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
if [ -e /tmp/b131 ]; then echo "REFUSE: /tmp/b131 already exists"; exit 9; fi
for f in conf build gccbuild state specs sc mkq dbg fn syms family reconf-gcc cause; do
  [ -f "t130-$f.sh" ] || { echo "MISSING t130-$f.sh"; exit 9; }
  sed -e 's#/tmp/b130#/tmp/b131#g' -e 's#b130-inst#b131-inst#g' \
      -e 's#sc130-#sc131-#g' -e 's#t130-#t131-#g' "t130-$f.sh" > "t131-$f.sh"
  chmod +x "t131-$f.sh"
  if grep -q 'b130' "t131-$f.sh"; then echo "FAIL leftover b130 in t131-$f.sh"; exit 9; fi
  if grep -q 't130-' "t131-$f.sh"; then echo "FAIL leftover t130- in t131-$f.sh"; exit 9; fi
  echo "wrote t131-$f.sh ($(grep -c 'b131' "t131-$f.sh") b131 mentions)"
done
