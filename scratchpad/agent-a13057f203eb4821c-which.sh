#!/bin/sh
# Which BASES' own tm-<base>.h chain defines a named macro, and what does the
# shared chain say?  The macrocensus prints COUNTS; when the count is small the
# NAMES are the finding, and a count cannot be acted on.
#
# Must run inside scratchpad/eb-shell.sh: `cpp' is not on PATH outside it, and
# `cpp: command not found' yields an empty dump for every base, which this
# would otherwise report as "no base defines it" -- the null result wearing the
# answer's clothes.  Hence the tool assertion and the FUNCTION_BOUNDARY control.
# usage: MACRO=NAME agent-a13057f203eb4821c-which.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
M=${MACRO:?set MACRO}
command -v cpp > /dev/null 2>&1 || { echo "FATAL: no cpp -- run under eb-shell.sh"; exit 9; }
W=$(mktemp -d); trap 'rm -rf "$W"' 0
: > "$W/e.c"
INC="-I$D/gcc -I$SRC/gcc -I$SRC/gcc/config -I$SRC/include -I$D/gcc/include -DIN_GCC"
n=0; ctl=0
for h in "$D"/gcc/tm-*.h; do
  b=$(basename "$h" .h); b=${b#tm-}
  cpp -dM $INC -imacros "$h" "$W/e.c" > "$W/m" 2>/dev/null
  [ -s "$W/m" ] || { echo "UNREADABLE $b"; continue; }
  grep -q "^#define FUNCTION_BOUNDARY" "$W/m" && ctl=$((ctl + 1))
  v=$(sed -n "s/^#define $M //p" "$W/m")
  [ -n "$v" ] && { n=$((n + 1)); printf '  %-12s %s\n' "$b" "$v"; }
done
[ "$ctl" -ge 40 ] || { echo "REFUSE: control FUNCTION_BOUNDARY seen in only $ctl chains"; exit 9; }
cpp -dM $INC -imacros "$D/gcc/tm.h" "$W/e.c" > "$W/s" 2>/dev/null
sv=$(sed -n "s/^#define $M //p" "$W/s")
echo "$M: $n base chain(s) define it; SHARED says [${sv:-<undefined>}] (control ok: $ctl chains)"
