#!/bin/sh
# #132 ARM D -- the GENERAL form of the bug: any TYPE declared in a back end's
# tm.h chain and NAMED by shared code is one name with N layouts.
# `cfun->machine' is the instance we know; this arm asks whether there are more.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"
T=/tmp/t132-types
mkdir -p $T

for base in i386 aarch64; do
  h=config/$base/$base.h
  awk '
    /^(typedef[ \t]+)?(struct|union|enum)[ \t]+[A-Za-z_][A-Za-z_0-9]*/ {
      for (i=1;i<=NF;i++) if ($i=="struct"||$i=="union"||$i=="enum") { n=$(i+1); gsub(/[^A-Za-z_0-9]/,"",n); if (n!="") print n; break }
    }' "$h" | sort -u > $T/$base.txt
  echo "$base: $(wc -l < $T/$base.txt) type names declared in $h"
done
echo
echo "== D1. names declared in BOTH bases' headers (one name, two layouts) =="
comm -12 $T/i386.txt $T/aarch64.txt | sed 's/^/   /'
echo
echo "== D2. of ALL such names, which are SPELLED outside config/ (shared code) =="
cat $T/i386.txt $T/aarch64.txt | sort -u > $T/all.txt
if [ ! -s $T/all.txt ]; then echo "FATAL: zero type names derived"; exit 9; fi
while read -r n; do
  hits=$(grep -rlw "$n" . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc --exclude-dir=po \
          --exclude=ChangeLog\* --exclude=FSFChangeLog\* | sort | tr '\n' ' ')
  [ -n "$hits" ] && printf '   %-28s %s\n' "$n" "$hits"
done < $T/all.txt
echo
echo "== D3. does the SHARED code actually DEREFERENCE any of them? =="
grep -rn 'cfun->machine->' . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc \
   --exclude=ChangeLog\* --exclude=FSFChangeLog\* | sed 's/^/   /'
