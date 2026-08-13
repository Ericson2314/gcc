#!/bin/sh
# #132 ARM A -- WHICH primary-header macros that read `cfun->machine' are
# spelled OUTSIDE config/, i.e. in code compiled once against i386's
# declaration of `struct machine_function'.
#
# NON-VACUITY: the enumeration of macro names is derived from the headers, not
# typed from memory, and the script REFUSES if that derivation comes up empty.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"

echo "== A0. every line in config/*/*.h reaching cfun->machine =="
grep -rn 'cfun->machine' config/ | grep '\.h:' | sed 's#^#  #'
echo

echo "== A1. macro names DEFINED in i386.h whose body mentions cfun->machine =="
# a #define whose body (continued lines included) mentions cfun->machine
awk '
  /^#[ \t]*define[ \t]/ { name=$2; sub(/\(.*/,"",name); body=$0; cont=(/\\$/);
                          if (!cont) { if (index(body,"cfun->machine")) print name; next }
                          buf=body; next }
  { if (cont) { buf=buf $0; if (!/\\$/) { cont=0; if (index(buf,"cfun->machine")) print name } } }
' config/i386/i386.h | sort -u > /tmp/t132-names.txt
NM=$(wc -l < /tmp/t132-names.txt)
if [ "$NM" -eq 0 ]; then echo "FATAL: derivation produced ZERO macro names"; exit 9; fi
echo "  derived $NM names:"; sed 's/^/    /' /tmp/t132-names.txt
echo

echo "== A2. for each, where it is SPELLED outside config/ =="
while read -r m; do
  hits=$(grep -rlw "$m" --exclude-dir=config --exclude-dir=testsuite --exclude-dir=po --exclude-dir=doc . | sort | tr '\n' ' ')
  if [ -z "$hits" ]; then
    printf '  %-42s CLEAN (no shared speller)\n' "$m"
  else
    printf '  %-42s SHARED: %s\n' "$m" "$hits"
  fi
done < /tmp/t132-names.txt
echo

echo "== A3. control: a macro known to be spelled in shared code must show SHARED =="
grep -rlw STACK_BOUNDARY --exclude-dir=config --exclude-dir=testsuite . | head -3 | sed 's/^/  /'
