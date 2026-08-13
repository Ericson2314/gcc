#!/bin/sh
# #125 -- derive my own build-dir scripts from #124's, so I do not share /tmp/b124.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
cd "$S"
for f in conf build gccbuild state specs sc guards; do
  [ -f "t124-$f.sh" ] || { echo "MISSING t124-$f.sh"; exit 9; }
  sed -e 's#/tmp/b124#/tmp/b125#g' -e 's#b124-inst#b125-inst#g' \
      -e 's#t124-#t125-#g' "t124-$f.sh" > "t125-$f.sh"
  chmod +x "t125-$f.sh"
  # assert the substitution actually happened where it mattered
  if grep -q 'b124' "t125-$f.sh"; then echo "FAIL leftover b124 in t125-$f.sh"; exit 9; fi
  echo "wrote t125-$f.sh ($(grep -c 'b125' "t125-$f.sh") b125 mentions)"
done
