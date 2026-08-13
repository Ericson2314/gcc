#!/bin/sh
# #133 -- derive my own build-dir scripts from #132's, so I do not share /tmp/b132.
# REFUSES if the substitution left a `b132' or a `t132-' behind.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
if [ -e /tmp/b133 ]; then echo "REFUSE: /tmp/b133 already exists"; exit 9; fi
for f in conf build gccbuild state specs sc mkq dbg fn syms family reconf-gcc asm cfi-cause; do
  [ -f "t132-$f.sh" ] || { echo "MISSING t132-$f.sh"; exit 9; }
  sed -e 's#/tmp/b132#/tmp/b133#g' -e 's#b132-inst#b133-inst#g' \
      -e 's#sc132-#sc133-#g' -e 's#t132-#t133-#g' "t132-$f.sh" > "t133-$f.sh"
  chmod +x "t133-$f.sh"
  if grep -q 'b132' "t133-$f.sh"; then echo "FAIL leftover b132 in t133-$f.sh"; exit 9; fi
  if grep -q 't132-' "t133-$f.sh"; then echo "FAIL leftover t132- in t133-$f.sh"; exit 9; fi
  echo "wrote t133-$f.sh ($(grep -c 'b133' "t133-$f.sh") b133 mentions)"
done
