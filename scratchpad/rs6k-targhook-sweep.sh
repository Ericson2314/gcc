#!/bin/sh
# WHICH `targhooks.cc' DEFAULTS ARE `#ifdef <tm.h macro>' -- and therefore
# answered ONCE, by the primary's tm.h, for every back end in the binary.
#
# The failure mode is not a wrong answer, it is `gcc_unreachable ()' when the
# primary does not define the macro and the selected base does -- an ICE with
# no mention of the base.  It is also the reverse: the primary defining it and
# the selected base not, which gives the primary's answer silently.
#
# Deliberately over-broad on the definer side (`define <MACRO>' anywhere under
# a back end's directory), because this instrument can only RAISE suspicion.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
cd "$SRC" || exit 9

MACROS=$(sed -n 's/^#ifdef \([A-Z_][A-Z_0-9]*\)$/\1/p' gcc/targhooks.cc | sort -u)
[ -n "$MACROS" ] || { echo "FATAL: read no #ifdef macros from targhooks.cc"; exit 9; }
echo "macros: $(echo "$MACROS" | wc -w)"
printf '%-36s %-8s %-8s %-8s\n' MACRO i386 aarch64 rs6000
for m in $MACROS; do
  a=$(grep -rl "define $m" gcc/config/i386/ | wc -l)
  b=$(grep -rl "define $m" gcc/config/aarch64/ | wc -l)
  c=$(grep -rl "define $m" gcc/config/rs6000/ | wc -l)
  printf '%-36s %-8s %-8s %-8s\n' "$m" "$a" "$b" "$c"
done
