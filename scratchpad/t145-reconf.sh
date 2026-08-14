#!/bin/sh
# #145 -- re-run gcc/configure with --enable-backends=all.
#
# WHY THIS EXISTS.  Passing --enable-backends=all to the TOP LEVEL does not
# work: configure.ac:193 DERIVES `gcc_backends_arg' from --enable-targets and
# appends it AFTER the user's arguments, so the derived list wins and the
# hand-passed `all' is silently discarded.  gcc/config.log records both, at
# argv positions 8 and 20.  There is no diagnostic.
#
# So the 47-back-end build is reached by re-running gcc/configure with the
# recorded argv and the LAST --enable-backends replaced.  The artefact scored
# is the manifest stanza count, not the exit status.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${D:-/tmp/b-a88fe2f04579b6092}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "${WANT_ANCHOR:-47}" ] || { echo "FATAL: anchor=$n"; exit 9; }

rm -f "$D/gcc/config.cache"
sh "$S/eb-shell.sh" "cd $D/gcc && $(cat /tmp/argv2.txt) \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security'" \
  > "$D/reconf.out" 2> "$D/reconf.err"
st=$(grep -c '^target ' "$D/gcc/multi-target.manifest")
echo "manifest stanzas: $st"
[ "$st" -ge 40 ] || { echo "FATAL: only $st stanzas; not a multi-back-end build"; exit 9; }
echo OK
