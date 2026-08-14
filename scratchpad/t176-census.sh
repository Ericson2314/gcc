#!/bin/sh
# #176 -- split the acceptance grep's 163 hits into REAL preprocessor
# directives and PROSE.
#
# The acceptance criterion is a plain `git grep', so a `tm.h' quoted inside a
# comment counts against it exactly as a live include does.  They are not the
# same work: a prose hit is reworded, a directive must be converted or deleted.
# `multi-target-base.h' was already recorded as this shape (PRINCIPLES sec 1);
# measuring rather than assuming is what found two more.
#
# A directive is a line whose FIRST non-blank characters are `#include'.
# Anything else matching the acceptance grep is prose.
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"
EX1=':(exclude)gcc/ChangeLog*'
EX2=':(exclude)gcc/*/ChangeLog*'

git grep -n '#include *"tm.h"' gcc "$EX1" "$EX2" > /tmp/t176-all.txt
git grep -n '^[ \t]*#[ \t]*include[ \t]*"tm\.h"' gcc "$EX1" "$EX2" > /tmp/t176-real.txt
grep -vxFf /tmp/t176-real.txt /tmp/t176-all.txt > /tmp/t176-prose.txt || true

echo "acceptance grep total : $(wc -l < /tmp/t176-all.txt)"
echo "  real directives     : $(wc -l < /tmp/t176-real.txt)"
echo "  prose only          : $(wc -l < /tmp/t176-prose.txt)"
echo
echo "prose hits by file:"
awk -F: '{print $1}' /tmp/t176-prose.txt | sort | uniq -c | sort -rn
echo
echo "real directives by population:"
awk -F: '{print $1}' /tmp/t176-real.txt | sed \
  -e 's|^gcc/config/.*|CONFIG (per-base glue)|' \
  -e 's|^gcc/testsuite/.*|TESTSUITE (plugin sources)|' \
  -e 's|^gcc/algol68/.*|ALGOL68|' \
  -e 's|^gcc/.*|SHARED|' | sort | uniq -c | sort -rn
