#!/bin/sh
# GENERALISE rs6k-targhook-sweep.sh FROM ONE BACK END TO ALL OF THEM.
#
# `targhooks.cc' is compiled ONCE.  Its `#ifdef <tm.h macro>' defaults are
# resolved against whatever tm.h that single translation unit sees -- i.e.
# against the PRIMARY.  So for every configured back end there are two failure
# directions, and only one of them is loud:
#
#   ICE      the primary does not define the macro, this base does.  The
#            #else arm runs: gcc_unreachable (), or a generic formula.
#   SILENT   the primary DOES define it and this base does not.  The base
#            gets the primary's answer with no diagnostic at all.
#
# The instrument is deliberately over-broad on the definer side (`define
# <MACRO>' anywhere under the back end's directory): it can only RAISE
# suspicion, never authorise a conclusion, so eagerness is the safe direction.
#
# It reads the macro list out of targhooks.cc rather than carrying one, and
# refuses to score if that read comes back empty.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
cd "$SRC" || exit 9

MACROS=$(sed -n 's/^#ifdef \([A-Z_][A-Z_0-9]*\)$/\1/p' gcc/targhooks.cc | sort -u)
[ -n "$MACROS" ] || { echo "FATAL: read no #ifdef macros from targhooks.cc"; exit 9; }
NM=$(echo "$MACROS" | wc -w)
echo "targhooks.cc #ifdef macros: $NM"

# back ends = cpu_type directories under gcc/config that contain a .md file.
BES=$(for d in gcc/config/*/; do
        b=$(basename "$d")
        ls "$d" | grep -q '\.md$' && echo "$b"
      done | sort)
[ -n "$BES" ] || { echo "FATAL: found no back-end directories"; exit 9; }
echo "back ends with a .md: $(echo "$BES" | wc -w)"
echo

# The two bases every existing build configures, i.e. the candidate primaries.
prim_def () {  # $1 = macro; 1 if i386 or aarch64 defines it
  if grep -rl "define $1" gcc/config/i386/ gcc/config/aarch64/ > /dev/null; then
    echo 1
  else
    echo 0
  fi
}

printf '%-40s %-6s %s\n' MACRO PRIM 'DEFINERS (back ends)'
for m in $MACROS; do
  p=$(prim_def "$m")
  defs=""
  for b in $BES; do
    if grep -rl "define $m" "gcc/config/$b/" > /dev/null; then
      defs="$defs $b"
    fi
  done
  printf '%-40s %-6s %s\n' "$m" "$p" "$(echo $defs)"
done

echo
echo "=== ICE RISK: base defines it, NEITHER i386 nor aarch64 does"
for m in $MACROS; do
  [ "$(prim_def "$m")" = 0 ] || continue
  for b in $BES; do
    grep -rl "define $m" "gcc/config/$b/" > /dev/null && echo "$b $m"
  done
done

echo
echo "=== SILENT RISK: i386/aarch64 define it, this base does NOT"
for m in $MACROS; do
  [ "$(prim_def "$m")" = 1 ] || continue
  for b in $BES; do
    grep -rl "define $m" "gcc/config/$b/" > /dev/null || echo "$b $m"
  done
done
