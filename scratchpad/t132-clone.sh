#!/bin/sh
# #132 -- derive my own build-dir scripts from #131's, so I do not share /tmp/b131.
# REFUSES if the substitution left a `b131' or a `t131-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
if [ -e /tmp/b132 ]; then echo "REFUSE: /tmp/b132 already exists"; exit 9; fi
for f in conf build gccbuild state specs sc mkq dbg fn syms family reconf-gcc asm cfi-cause; do
  [ -f "t131-$f.sh" ] || { echo "MISSING t131-$f.sh"; exit 9; }
  sed -e 's#/tmp/b131#/tmp/b132#g' -e 's#b131-inst#b132-inst#g' \
      -e 's#sc131-#sc132-#g' -e 's#t131-#t132-#g' "t131-$f.sh" > "t132-$f.sh"
  chmod +x "t132-$f.sh"
  if grep -q 'b131' "t132-$f.sh"; then echo "FAIL leftover b131 in t132-$f.sh"; exit 9; fi
  if grep -q 't131-' "t132-$f.sh"; then echo "FAIL leftover t131- in t132-$f.sh"; exit 9; fi
  echo "wrote t132-$f.sh ($(grep -c 'b132' "t132-$f.sh") b132 mentions)"
done
