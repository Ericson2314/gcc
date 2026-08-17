#!/bin/sh
# mt-fe-macros.sh -- WHICH target macros does each front end spell, restricted
# to the ones that could possibly differ between back ends?
#
# `mt-fe-surface.sh' gives a SIZE (how many vocabulary names a directory
# spells).  A size cannot be acted on.  This gives the NAMES, filtered to
# macros with more than one definer under `config/', which is the population a
# leak can live in -- a macro exactly one back end defines cannot make two
# back ends disagree, and a macro nobody defines is `defaults.h''s alone.
#
# IT IS A CANDIDATE LIST AND NOTHING MORE.  Feed it to
# `agent-a8f6f467d15197cd3-macrocensus.sh', which asks the real preprocessor
# over each base's real `tm-<base>.h' and returns VALUE-DIFF.  PRINCIPLES,
# twice over: counting the back ends that SPELL a macro undercounts it (four
# back ends reached `TARGET_PTRMEMFUNC_VBIT_LOCATION' through a `defaults.h'
# fallback no directory grep can see), and a textual body comparison answers
# "is this spelled the same" when the question is "does this MEAN the same".
# So a name here is a suspect, never a finding.
#
# usage: mt-fe-macros.sh <srcdir> <frontend-dir> [<frontend-dir> ...]
set -u
SRC=${1:?srcdir}; shift
SRC=$(cd "$SRC" && pwd)
[ $# -ge 1 ] || { echo "FATAL: name at least one front-end directory"; exit 9; }
cd "$SRC/gcc"
W=$(mktemp -d); trap 'rm -rf "$W"' 0

# name -> number of DISTINCT files under config/ that #define it.
grep -rhoE '^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z_0-9]*' --include='*.h' config/ 2>/dev/null \
  | awk '{print $NF}' > "$W/all"
grep -rE '^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z_0-9]*' --include='*.h' config/ 2>/dev/null \
  | sed 's/:[ \t]*#[ \t]*define[ \t]*/ /' | awk '{print $2, $1}' | sort -u \
  | awk '{c[$1]++} END {for (n in c) if (c[n] > 1) print n}' | sort > "$W/multi"
NM=$(wc -l < "$W/multi")
[ "$NM" -ge 500 ] || { echo "REFUSE: only $NM multiply-defined macros -- the scan read nothing"; exit 9; }
grep -qx BITS_PER_WORD "$W/multi" || { echo "REFUSE: control BITS_PER_WORD is not multiply defined"; exit 9; }
echo "multiply-defined target macros under config/: $NM  (control ok)"
echo

for d in "$@"; do
  [ -d "$d" ] || { echo "$d: NO SUCH DIRECTORY"; continue; }
  grep -rhoE '\b[A-Za-z_][A-Za-z_0-9]*\b' --include='*.cc' --include='*.c' --include='*.h' "$d" 2>/dev/null \
    | sort -u > "$W/ids"
  comm -12 "$W/ids" "$W/multi" > "$W/hit"
  n=$(wc -l < "$W/hit")
  echo "== $d  $n multiply-defined target macros spelled"
  tr '\n' ' ' < "$W/hit" | fold -s -w 74 | sed 's/^/   /'
  echo
done
