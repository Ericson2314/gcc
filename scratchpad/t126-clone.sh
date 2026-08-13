#!/bin/sh
# #126 -- derive my own build-dir scripts from #125's, so I do not share /tmp/b125.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc mkq; do
  [ -f "t125-$f.sh" ] || { echo "MISSING t125-$f.sh"; exit 9; }
  sed -e 's#/tmp/b125#/tmp/b126#g' -e 's#b125-inst#b126-inst#g' \
      -e 's#t125-#t126-#g' "t125-$f.sh" > "t126-$f.sh"
  chmod +x "t126-$f.sh"
  if grep -q 'b125' "t126-$f.sh"; then echo "FAIL leftover b125 in t126-$f.sh"; exit 9; fi
  echo "wrote t126-$f.sh ($(grep -c 'b126' "t126-$f.sh") b126 mentions)"
done
