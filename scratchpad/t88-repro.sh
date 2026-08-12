#!/usr/bin/env bash
# BEFORE/AFTER on one configured build directory, run side by side so the only
# variable is which opt-stub.awk built the placeholder records.
#
# The pipeline reproduced here is the one gen-target-manifest.sh writes into
# multi-target-common.mk:
#     optionlist-<base>.own  = opt-gather over that back end .opt files
#     optionlist-<base>.stub = opt-stub.awk padding it up to optionlist-vocab
#     gcc-options-<base>.part= opth-gen.awk -v list_mode=1 over the two
#     gcc-options-union.list = the parts, concatenated
# and then opth-gen.awk reading that union back.
#
#   t88-repro.sh <builddir>/gcc <base-a> <base-b> <old-opt-stub.awk>
set -u -o pipefail
D=${1:?}; BA=${2:?}; BB=${3:?}; OLDS=${4:?}
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/gcc
case $D in /*) ;; *) echo "FATAL: builddir must be absolute"; exit 9;; esac
for f in "$D/optionlist-vocab" "$D/optionlist-$BA" "$D/optionlist-$BB"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done
W=/tmp/t88-repro; rm -rf $W; mkdir -p $W
rc=0

# The make rule deletes optionlist-<base>.own, so recover it: a placeholder
# written by the current opt-stub.awk is exactly a record whose entire flag
# word is `Undocumented' -- or `Undocumented Ignore' when the enumerator had to
# be given up to a name clash -- and no real .opt record carries either.  BOTH
# spellings have to be listed: stripping only the first left 8 of i386 152
# placeholders behind in the recovered `own' list.  Asserted, not assumed -- if
# the padding were spelled differently again this would strip nothing and both
# sides below would silently be the same list.
US=$(printf '\034')
for b in $BA $BB; do
  awk -F"$US" '$2!="Undocumented" && $2!="Undocumented Ignore"' "$D/optionlist-$b" > $W/$b.own
  n=$(( $(wc -l < "$D/optionlist-$b") - $(wc -l < $W/$b.own) ))
  echo "  recovered optionlist-$b.own: $(wc -l < $W/$b.own) records ($n placeholders stripped)"
  [ "$n" -gt 0 ] || { echo "FATAL: no placeholders found in optionlist-$b; the recovery is not doing anything"; exit 9; }
done

build_side () { # build_side <label> <stubscript>
  local L=$1 ST=$2 b
  for b in $BA $BB; do
    gawk -f "$S/opt-functions.awk" -f "$ST" -v vocab="$D/optionlist-vocab" \
         "$D/optionlist-vocab" $W/$b.own > $W/$L-$b.stub 2> $W/$L-$b.stub.err
    [ -s $W/$L-$b.stub.err ] && { echo "  FATAL: $L/$b stub stderr:"; cat $W/$L-$b.stub.err; exit 9; }
    # A silently empty stub file would make every difference below vanish.
    [ -s $W/$L-$b.stub ] || { echo "  FATAL: $L/$b produced NO stub records; this side proves nothing"; exit 9; }
    LC_ALL=C sort <(cat $W/$b.own $W/$L-$b.stub) > $W/$L-$b.list
    gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" -v list_mode=1 -v union_base=$b \
         -f "$S/opth-gen.awk" < $W/$L-$b.list > $W/$L-$b.part 2> $W/$L-$b.part.err
    [ -s $W/$L-$b.part ] || { echo "  FATAL: $L/$b part is empty"; exit 9; }
  done
  cat $W/$L-$BA.part $W/$L-$BB.part > $W/$L.union
  echo "  $L: $(wc -l < $W/$L-$BA.stub) + $(wc -l < $W/$L-$BB.stub) stub records, union $(wc -l < $W/$L.union) lines"
}

echo "=== BEFORE (opt-stub.awk at HEAD)"
build_side before "$OLDS"
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
     -v union_file=$W/before.union -v union_base=$BA -f "$S/opth-gen.awk" \
     < $W/before-$BA.list > $W/before.h 2> $W/before.h.err
r=$?
if [ $r -ne 0 ]; then
  echo "  options.h FAILS, rc=$r: $(cat $W/before.h.err)"
else
  echo "  options.h succeeds (rc=0) -- this pair does not exhibit the bug"; rc=1
fi

echo "=== AFTER (opt-stub.awk in the worktree)"
build_side after "$S/opt-stub.awk"
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
     -v union_file=$W/after.union -v union_base=$BA -f "$S/opth-gen.awk" \
     < $W/after-$BA.list > $W/after.h 2> $W/after.h.err
r=$?
if [ $r -eq 0 ] && [ ! -s $W/after.h.err ] && [ "$(wc -l < $W/after.h)" -gt 1000 ]; then
  echo "  options.h succeeds, rc=0, stderr empty, $(wc -l < $W/after.h) lines"
else
  echo "  FAIL rc=$r:"; cat $W/after.h.err; rc=1
fi
# BOTH SIDED: the same union must also serve the OTHER back end, and the two
# headers must have the SAME struct body -- that is the point of the union.
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
     -v union_file=$W/after.union -v union_base=$BB -f "$S/opth-gen.awk" \
     < $W/after-$BB.list > $W/after-b.h 2> $W/after-b.h.err
r=$?
[ $r -eq 0 ] && [ ! -s $W/after-b.h.err ] \
  && echo "  options-$BB.h succeeds, rc=0, stderr empty, $(wc -l < $W/after-b.h) lines" \
  || { echo "  FAIL ($BB) rc=$r:"; cat $W/after-b.h.err; rc=1; }
for f in $W/after.h $W/after-b.h; do
  sed -n '/^struct gcc_options$/,/^};/p' $f > $f.body
  [ "$(wc -l < $f.body)" -gt 500 ] || { echo "  FATAL: no struct body extracted from $f"; exit 9; }
done
cmp -s $W/after.h.body $W/after-b.h.body \
  && echo "  the two headers agree on the struct BODY, not merely its size ($(wc -l < $W/after.h.body) lines)" \
  || { echo "  FAIL: the two headers disagree:"; diff $W/after.h.body $W/after-b.h.body | head -10; rc=1; }
echo "OVERALL rc=$rc"
exit $rc
