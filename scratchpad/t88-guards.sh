#!/usr/bin/env bash
# The two guards that stand between "the halves disagree" and a silent wrong
# answer, each shown FIRING on a deliberately perturbed union list and then
# shown clean again on the real one.  A guard nobody has seen fire is not a
# guard: opth-gen.awk has one and it caught #88 by name; optc-gen.awk had none
# at all, which is why #104 happened twice in different build directories
# without anyone noticing.
#
# Nothing in the tree is edited.  Both guards read gcc-options-union.list, so
# a perturbed COPY exercises exactly the code path a stale or wrong list would.
#
#   t88-guards.sh <builddir>/gcc <base>
set -u -o pipefail
D=${1:?usage: t88-guards.sh <builddir>/gcc <base>}
B=${2:?usage: t88-guards.sh <builddir>/gcc <base>}
case $D in /*) ;; *) echo "FATAL: <builddir> must be absolute"; exit 9;; esac
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/gcc
U=$D/gcc-options-union.list
for f in "$U" "$D/optionlist" "$D/optionlist-$B"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done
command -v gawk >/dev/null || { echo "FATAL: no gawk"; exit 9; }
W=/tmp/t88-guards; rm -rf $W; mkdir -p $W
rc=0
H="config.h system.h coretypes.h options.h tm.h"

run_opth () {  # run_opth <unionlist> <outfile> <errfile>
  gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
       -v union_file="$1" -v union_base="$B" \
       -f "$S/opth-gen.awk" < "$D/optionlist" > "$2" 2> "$3"
  echo $?
}
run_optc () { # run_optc <unionlist> <outfile> <errfile>
  gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
       -v union_file="$1" -v union_base="$B" \
       -f "$S/optc-gen.awk" -v header_name="$H" > "$2" 2> "$3" < "$D/optionlist"
  echo $?
}

echo "=== control: the REAL union list must produce both files cleanly"
r=$(run_opth "$U" $W/ok.h $W/ok.h.err)
[ "$r" = 0 ] && [ ! -s $W/ok.h.err ] && [ -s $W/ok.h ] \
  && echo "  opth-gen rc=0, stderr empty, $(wc -l < $W/ok.h) lines" \
  || { echo "  FAIL opth-gen rc=$r"; cat $W/ok.h.err; rc=1; }
r=$(run_optc "$U" $W/ok.cc $W/ok.cc.err)
n=$(grep -c '#error optc-gen' $W/ok.cc || true)
[ "$r" = 0 ] && [ ! -s $W/ok.cc.err ] && [ "$n" -eq 0 ] \
  && echo "  optc-gen rc=0, stderr empty, 0 embedded #error, $(wc -l < $W/ok.cc) lines" \
  || { echo "  FAIL optc-gen rc=$r embedded_errors=$n"; cat $W/ok.cc.err; rc=1; }

echo
echo "=== GUARD 1 (opth-gen): one member declared twice, differently"
# Pick a real `S' member and append a SECOND declaration of it with the other
# type.  That is bit-for-bit the shape #88 had: rs6000 spells `mdebug=' Joined
# so its member is `const char *', a stub spelled it bare so the member was
# `int', and both records were in the one list.
VICTIM=$(awk -F'\t' '$1=="S"{print $2; exit}' "$U")
[ -n "$VICTIM" ] || { echo "  FATAL: no S member found in $U; the perturbation has no subject"; exit 9; }
echo "  victim member: $VICTIM"
cp "$U" $W/dup.list
awk -F'\t' -v v="$VICTIM" 'BEGIN{OFS="\t"}
  $1=="S" && $2==v && !done {
    t=$3; sub(/int x_/, "const char *x_", t); sub(/signed char x_/, "const char *x_", t)
    if (t==$3) { sub(/const char \*x_/, "int x_", t) }
    if (t==$3) { print "PERTURBATION-DID-NOT-APPLY" > "/dev/stderr"; exit 9 }
    print $1,$2,t; done=1
  }
  {print}' "$U" >> $W/dup.list 2>$W/dup.perturb.err
[ -s $W/dup.perturb.err ] && { echo "  FATAL: could not perturb:"; cat $W/dup.perturb.err; exit 9; }
[ "$(wc -l < $W/dup.list)" -gt "$(wc -l < $U)" ] || { echo "  FATAL: perturbed list is not larger; nothing was added"; exit 9; }
r=$(run_opth $W/dup.list $W/dup.h $W/dup.h.err)
if [ "$r" != 0 ] && grep -q "member $VICTIM declared twice, differently" $W/dup.h.err; then
  echo "  FIRED (rc=$r): $(grep 'declared twice' $W/dup.h.err)"
else
  echo "  FAIL: guard did not fire.  rc=$r stderr:"; cat $W/dup.h.err; rc=1
fi

echo
echo "=== GUARD 2 (optc-gen): the initializer has an element the struct lacks"
# Delete one member from the union list.  options.cc still has an initializer
# element for it, so the positional list would be one longer than the struct
# and every element after it would land on the wrong member -- #104 exactly.
# Before this change that produced no diagnostic at all.
VICTIM2=$(awk -F'\t' '$1=="O"{print $2; exit}' "$U")
[ -n "$VICTIM2" ] || { echo "  FATAL: no O member found"; exit 9; }
echo "  deleted member: $VICTIM2"
awk -F'\t' -v v="$VICTIM2" '!($1=="O" && $2==v)' "$U" > $W/miss.list
[ "$(wc -l < $W/miss.list)" -lt "$(wc -l < $U)" ] || { echo "  FATAL: nothing was deleted"; exit 9; }
r=$(run_optc $W/miss.list $W/miss.cc $W/miss.cc.err)
if grep -q "#error optc-gen.awk: .global_options_init. has an element for .$VICTIM2." $W/miss.cc; then
  echo "  FIRED: $(grep -m1 '#error optc-gen' $W/miss.cc | cut -c1-150)"
else
  echo "  FAIL: guard did not fire.  rc=$r; embedded errors:"; grep -m3 '#error' $W/miss.cc; rc=1
fi

echo
echo "=== restore: the real list still passes (the perturbations were copies)"
cmp -s "$U" $W/dup.list && { echo "  FATAL: the perturbed copy equals the original"; rc=1; }
r=$(run_opth "$U" $W/ok2.h $W/ok2.h.err)
cmp -s $W/ok.h $W/ok2.h && [ "$r" = 0 ] \
  && echo "  options.h regenerates byte-identically from the untouched list" \
  || { echo "  FAIL: the tree was disturbed"; rc=1; }

echo "OVERALL rc=$rc"
exit $rc
