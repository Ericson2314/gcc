#!/bin/sh
# #173 -- the conversion must not change WHICH header any object opens, only
# how the include is spelled.  Compare the per-back-end header sets the two
# builds actually opened, object by object.
#
# Restricted to objects BOTH builds produced, because the two runs stop at
# different points and an object only one of them reached would score as a
# difference without being one.
set -e
S=$(cd "$(dirname "$0")" && pwd)
A=${1:?before build dir}
B=${2:?after build dir}
for d in "$A" "$B"; do
  [ -f "$d/make-top.err" ] || { echo "FATAL: $d never built"; exit 9; }
done
sh "$S/t173-deps.sh" "$A" | sort > /tmp/t173-dd-a.txt
sh "$S/t173-deps.sh" "$B" | sort > /tmp/t173-dd-b.txt
awk '{print $1}' /tmp/t173-dd-a.txt | sort -u > /tmp/t173-dd-oa.txt
awk '{print $1}' /tmp/t173-dd-b.txt | sort -u > /tmp/t173-dd-ob.txt
comm -12 /tmp/t173-dd-oa.txt /tmp/t173-dd-ob.txt > /tmp/t173-dd-common.txt
n=$(wc -l < /tmp/t173-dd-common.txt)
[ "$n" -gt 100 ] || { echo "FATAL: only $n objects in common -- too few to say anything"; exit 9; }
grep -Ff /tmp/t173-dd-common.txt /tmp/t173-dd-a.txt > /tmp/t173-dd-ac.txt
grep -Ff /tmp/t173-dd-common.txt /tmp/t173-dd-b.txt > /tmp/t173-dd-bc.txt
echo "objects in common: $n"
if diff -q /tmp/t173-dd-ac.txt /tmp/t173-dd-bc.txt > /dev/null; then
  echo "PASS: identical per-back-end header sets across $n objects"
else
  echo "DIFFERS:"
  diff /tmp/t173-dd-ac.txt /tmp/t173-dd-bc.txt | head -40
  exit 1
fi
