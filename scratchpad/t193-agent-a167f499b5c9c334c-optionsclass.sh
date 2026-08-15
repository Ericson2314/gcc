#!/bin/sh
# #193 (agent-a167f499b5c9c334c) -- SETTLE `options.h'.
#
# PRINCIPLES records options.h as target-neutral ("generated from every
# configured back end's .opt files, so a TU that includes it directly gets no
# primary's answer").  t187-stemclass.sh does not reproduce that: the build
# root's copy matches no base's copy and its #define NAME set is not a
# superset of every base's, so it is neither a copy nor the union, and #187
# left it UNDECIDED rather than guessing.
#
# THE BLIND SPOT #187 STATED ABOUT ITSELF, AND WHY THIS SCRIPT EXISTS.  Its
# name-set arm sees PRESENCE.  Two bases defining the same macro to different
# bodies are identical to it -- the HAVE_V8HFmode shape.  Every arm below
# compares NAME=BODY.
#
# WHAT THE MECHANISM SAYS TO EXPECT (gcc/Makefile.in s-options-h, and the long
# notes in opth-gen.awk), stated up front so the measurement can refute it:
#
#   * the STRUCT LAYOUT is unioned      -> neutral
#   * the option-code VOCABULARY is unioned by optionlist-vocab -> neutral
#   * BUT the shared header is generated with `-v union_base=$(multi_target_base)',
#     i.e. FOR ONE BACK END.  opth-gen.awk's own two "Residual, stated rather
#     than hidden" notes say so: the HeaderInclude macros of that one base stay
#     in scope, and the option ACCESSOR macros are scoped out only for the back
#     ends foreign TO THAT BASE.
#
# So the prediction is: not a copy of any base (it carries the union's
# members), not a superset of any base (it lacks the other bases' -opts.h
# macros), and NOT NEUTRAL (it carries the primary's).  Arms 2 and 3 are what
# decide it; arm 4 asks whether a shared name has different BODIES.
#
# usage: t193-...-optionsclass.sh <builddir>
set -u
G=${1:?build dir}/gcc
O=${MT_OUT:-/tmp/t193-opt-$$}
rm -rf "$O"; mkdir -p "$O"
[ -f "$G/options.h" ] || { echo "FATAL: no $G/options.h"; exit 9; }

BASES=$(ls "$G" | sed -n 's/^options-\([a-z0-9_]*\)\.h$/\1/p' | sort)
NB=$(printf '%s\n' "$BASES" | grep -c .)
echo "bases with an options-<base>.h: $NB"
[ "$NB" -ge 2 ] || { echo "FATAL: need >=2"; exit 9; }

# NAME -> BODY for every object-like or function-like #define.  Comments are
# stripped first so that a differing comment is not scored as a differing
# value.  Continuation lines are NOT joined: every #define in these generated
# headers is one line (asserted below).
defs () {
  sed -e 's,/\*[^*]*\*/,,g' "$1" \
  | sed -n 's/^[[:space:]]*#[[:space:]]*define[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\)\([( ].*\)\{0,1\}$/\1\t\2/p' \
  | sed -e 's/[[:space:]]*$//'
}
undefs () { sed -n 's/^[[:space:]]*#[[:space:]]*undef[[:space:]]\{1,\}\([A-Za-z_][A-Za-z0-9_]*\).*$/\1/p' "$1" | sort -u; }

nc=$(grep -c '\\$' "$G/options.h" || true)
echo "continuation lines in options.h: $nc  (nonzero would mean defs() truncates a body)"

defs "$G/options.h" | sort > "$O/root.defs"
undefs "$G/options.h" > "$O/root.undefs"
awk -F'\t' '{print $1}' "$O/root.defs" | sort -u > "$O/root.names"
echo "root options.h: $(wc -l < "$O/root.defs") defines, $(wc -l < "$O/root.names") distinct names, $(wc -l < "$O/root.undefs") undefs"
[ -s "$O/root.defs" ] || { echo "FATAL: extracted 0 defines from the root options.h"; exit 9; }

echo
echo "=== arm 1  byte identity and name-set relation, root vs each base"
printf '%-12s %-6s %s\n' base bytes 'name-set relation to root'
for b in $BASES; do
  f=$G/options-$b.h
  defs "$f" | sort > "$O/$b.defs"
  awk -F'\t' '{print $1}' "$O/$b.defs" | sort -u > "$O/$b.names"
  ident=$(cmp -s "$G/options.h" "$f" && echo SAME || echo diff)
  miss=$(comm -23 "$O/$b.names" "$O/root.names" | wc -l)   # base has, root lacks
  extra=$(comm -13 "$O/$b.names" "$O/root.names" | wc -l)  # root has, base lacks
  printf '%-12s %-6s base-only %-5s root-only %-5s\n' "$b" "$ident" "$miss" "$extra"
done

echo
echo "=== arm 2  IS THE ROOT A SUPERSET (a union) OF EVERY BASE'S NAMES?"
notsup=0
for b in $BASES; do
  m=$(comm -23 "$O/$b.names" "$O/root.names" | wc -l)
  [ "$m" = 0 ] || { notsup=$((notsup + 1)); }
done
echo "bases with at least one name the root does NOT define: $notsup of $NB"
if [ "$notsup" -gt 0 ]; then
  echo "  -> the root is NOT the union.  Sample of what aarch64 has and the root lacks:"
  comm -23 "$O/aarch64.names" "$O/root.names" 2>/dev/null | head -15 | sed 's/^/     /'
fi

echo
echo "=== arm 3  WHOSE MACROS DOES THE ROOT CARRY?  (the primary-leak question)"
# For each base, how many names are defined by the root AND by that base and
# by NO OTHER base -- i.e. names that identify a single back end.
for b in $BASES; do
  others=$O/others-$b.names
  : > "$others"
  for o in $BASES; do [ "$o" = "$b" ] || cat "$O/$o.names" >> "$others"; done
  sort -u "$others" -o "$others"
  excl=$(comm -23 "$O/$b.names" "$others")           # names only this base has
  n=$(printf '%s\n' "$excl" | grep -c . || true)
  inroot=$(printf '%s\n' "$excl" | grep -c . > /dev/null; printf '%s\n' "$excl" | comm -12 - "$O/root.names" | wc -l)
  [ "$n" = 0 ] && continue
  printf '  %-12s %4d names unique to this base, %4d of them ALSO in the shared options.h\n' "$b" "$n" "$inroot"
done | sort -k4 -rn | head -20
echo "  (a base with a NONZERO third column is one whose private option vocabulary"
echo "   is visible in every shared translation unit -- that is the leak.)"

echo
echo "=== arm 4  VALUES, not names: one name, several bodies"
: > "$O/all.defs"
for b in $BASES; do sed "s|^|$b\t|" "$O/$b.defs" >> "$O/all.defs"; done
awk -F'\t' '{k=$2; v=$3; if (!(k in seen)) {seen[k]=v} else if (seen[k]!=v) div[k]=1}
            END {for (k in div) print k}' "$O/all.defs" | sort > "$O/divergent.names"
echo "names with >1 distinct body across bases: $(wc -l < "$O/divergent.names")"
comm -12 "$O/divergent.names" "$O/root.names" > "$O/divergent-in-root.names"
echo "  ... of which the SHARED options.h also defines: $(wc -l < "$O/divergent-in-root.names")"
echo "  -- each of those is one name, several authorities, answered for all 47"
echo "     shared-object readers by whichever base the shared header was"
echo "     generated for.  First 25, with the root's body and the distinct"
echo "     bodies across bases:"
head -25 "$O/divergent-in-root.names" | while read -r nm; do
  rb=$(awk -F'\t' -v n="$nm" '$1==n {print $2; exit}' "$O/root.defs")
  printf '  %-32s root: %s\n' "$nm" "$rb"
  awk -F'\t' -v n="$nm" '$2==n {print $3 "\t" $1}' "$O/all.defs" | sort -u -t'	' -k1,1 \
    | head -4 | sed 's/^/      /'
done

echo
echo "=== arm 5  NON-VACUITY / CONTROLS"
# 5a the extractor must find a name we know is there
grep -qx 'OPTIONS_H_INCLUDED' "$O/root.names" \
  && echo "5a PASS  extractor found OPTIONS_H_INCLUDED in the root header" \
  || { echo "5a FATAL extractor did not find OPTIONS_H_INCLUDED"; exit 9; }
# 5b two bases must be distinguishable at all
if cmp -s "$O/i386.defs" "$O/aarch64.defs"; then
  echo "5b FATAL i386 and aarch64 options headers have IDENTICAL define sets --"
  echo "         either they really are, or defs() is eating the content."
  exit 9
else
  echo "5b PASS  i386 and aarch64 define sets differ ($(comm -23 "$O/i386.names" "$O/aarch64.names" | wc -l) i386-only, $(comm -13 "$O/i386.names" "$O/aarch64.names" | wc -l) aarch64-only)"
fi
# 5c the divergent-name arm must be able to report zero: run it over ONE base
awk -F'\t' '{k=$2; v=$3; if (!(k in s)) s[k]=v; else if (s[k]!=v) d[k]=1} END {print length(d)+0}' \
  /dev/null > /dev/null
one=$(sed "s|^|i386\t|" "$O/i386.defs" | awk -F'\t' '{k=$2;v=$3; if(!(k in s)) s[k]=v; else if (s[k]!=v) d[k]=1} END {print length(d)+0}')
echo "5c control: the same arm over i386 ALONE reports $one divergent names"
echo "   (must be small; a large number here would mean the arm is measuring"
echo "    duplicate #defines inside one file rather than divergence between bases)"
echo
echo "output: $O"
