#!/bin/sh
# #176 -- for a TU that STILL reaches `tm.h' after its own include is cut,
# name the header that pulls it in.  `cpp -H' indents each opened header by
# its depth, so the line immediately above `tm.h' at one less dot is the
# includer.
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
D=$W/b-a7cee-before
SRC=$W/snap-before
A=$D/t176-route; mkdir -p "$A"
R=$(sh "$S/eb-shell.sh" "cd $D/gcc && make -n cfgexpand.o" | grep -m1 -- '-o cfgexpand\.o')
FLAGS=$(printf '%s\n' "$R" | sed -e 's/ -o cfgexpand\.o.*//' -e 's/^[^ ]* //')
CXX=$(printf '%s\n' "$R" | awk '{print $1}')
for f in "$@"; do
  n=$(echo "$f" | tr '/' '_')
  sed 's|^[ \t]*#[ \t]*include[ \t]*"tm\.h".*$|/* AMPUTATED */|' "$SRC/gcc/$f" > "$A/$n.cc"
  sh "$S/eb-shell.sh" \
    "cd $D/gcc && $CXX $FLAGS -I$(dirname "$SRC/gcc/$f") -H -E -o /dev/null $A/$n.cc" \
    > /dev/null 2> "$A/$n.H" || true
  echo "--- $f"
  awk '/(^|\/)tm\.h$/ && /^\.+ /{
         d = length($1);                     # depth of this tm.h
         for (i = NR - 1; i >= 1 && i > NR - 4000; i--)
           if (length(dep[i]) == d - 1) { print "    included by: " line[i]; break }
         print "    tm.h opened: " $0; exit }
       { dep[NR] = $1; line[NR] = $0 }' "$A/$n.H"
done
