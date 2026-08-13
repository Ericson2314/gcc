#!/bin/sh
# ONE NAME, A MACRO IN ONE BACK END AND AN OPTION Var() IN ANOTHER.
#
# The sibling of mtN-varvstype.sh, which compares option Var() names against
# enum/struct/class TYPE names.  This compares them against the MACROS that a
# HeaderInclude header contributes to the shared options.h.  The failure looks
# identical from the log and is a different population:
#
#   config/csky/csky.opt:93    Target Var(TARGET_DOUBLE_FLOAT) Init(-1)
#   config/loongarch/...opts.h #define TARGET_DOUBLE_FLOAT (la_target.isa.fpu ...)
#
# The union options.h declares `extern int TARGET_DOUBLE_FLOAT;' for csky and
# has already included loongarch's header, so the declaration is macro-expanded
# and the whole compiler stops: 974 diagnostics, all of them this one line.
#
# Scoping the macros out of the OTHER back ends' headers fixes 47 of the 48.
# It cannot fix loongarch's own, where the macro is legitimately in scope and
# the collision is real -- that one needs the name qualified, exactly as
# recip_mask, asm_dialect and stringop_strategy were.
#
# usage: mtO-varvsmacro.sh <gcc-srcdir> <leaks.txt>
set -e
S=${1:?gcc srcdir}
L=${2:?leaks list}
[ -s "$L" ] || { echo "FATAL: $L is empty"; exit 9; }

tmp=${TMPDIR:-/tmp}/mtO-varvsmacro.$$
trap 'rm -f "$tmp".*' 0

# Every Var() name in every .opt, with the back end that spells it.
for f in "$S"/config/*/*.opt "$S"/*.opt; do
  [ -f "$f" ] || continue
  d=$(basename "$(dirname "$f")")
  sed -n 's/.*[Vv]ar(\([A-Za-z_][A-Za-z_0-9]*\)).*/\1/p' "$f" | sort -u | sed "s|^|$d |"
done > "$tmp".vars
[ -s "$tmp".vars ] || { echo "FATAL: no Var() names read from any .opt"; exit 9; }
echo "Var() names read: $(wc -l < "$tmp".vars)"
echo

n=0
# Both leak lists are accepted: mtO-optsmacro2.sh writes <cpu> <kind> <name>
# and mtO-allI.sh writes <header> <name>.  The macro name is the LAST field in
# both.  Reading a fixed field count instead scored every allI.txt line as an
# empty macro name and printed `collisions: 0' -- a zero from the instrument,
# not from the code, which is the failure PRINCIPLES section 7 names.
awk -F'\t' 'NF>=2 { print $1 "\t" $NF }' "$L" > "$tmp".leaks
[ -s "$tmp".leaks ] || { echo "FATAL: no usable records in $L"; exit 9; }
while IFS='	' read -r cpu m; do
  hit=$(awk -v m="$m" '$2 == m { print $1 }' "$tmp".vars | sort -u | tr '\n' ' ')
  [ -n "$hit" ] || continue
  n=$((n+1))
  printf 'MACRO %-12s %-24s is an option Var() in: %s\n' "$cpu" "$m" "$hit"
done < "$tmp".leaks
echo
echo "collisions: $n"
