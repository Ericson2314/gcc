#!/bin/sh
# WHAT IS ACTUALLY IN EVERY config/<cpu>/<cpu>-opts.h, SPLIT INTO THE TWO
# POPULATIONS THAT THE SHARED options.h CONFLATES.
#
#   TYPES   -- enum/struct/typedef declarations.  The shared options.h needs
#              these, because with a union layout it declares EVERY back end's
#              `struct gcc_options' members, and their types live here.
#   MACROS  -- object-like #defines.  Nobody outside that back end needs them,
#              and because the header is pulled into the shared options.h they
#              are defined for every back end, first definition winning.
#
# A macro is only a *collision* if some other back end also defines the name.
# But a macro that collides with nothing today is still a leak: it is in
# scope for 47 back ends that never asked for it.  Both are reported.
#
# usage: mtO-optsmacro.sh <gcc-srcdir>
set -e
S=${1:?gcc srcdir}
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

n=0
for f in "$S"/config/*/*-opts.h; do n=$((n+1)); done
[ "$n" -gt 0 ] || { echo "FATAL: no <cpu>-opts.h found"; exit 9; }
echo "config/*/*-opts.h files: $n"
echo

printf '%-14s %6s %6s %6s %6s\n' backend macros enums structs typedefs
for f in "$S"/config/*/*-opts.h; do
  cpu=$(basename "$(dirname "$f")")
  m=$(sed -n 's/^[ 	]*#[ 	]*define[ 	]\{1,\}\([A-Za-z_][A-Za-z_0-9]*\)\([^(A-Za-z_0-9]\|$\).*/\1/p' "$f" | sort -u | wc -l)
  e=$(grep -c '^[ 	]*enum[ 	]' "$f" || true)
  st=$(grep -c '^[ 	]*struct[ 	]' "$f" || true)
  td=$(grep -c '^[ 	]*typedef[ 	]' "$f" || true)
  printf '%-14s %6s %6s %6s %6s\n' "$cpu" "$m" "$e" "$st" "$td"
done
