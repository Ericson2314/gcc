#!/bin/sh
# The guards fail BY NAME, and options.h is untouched by the C record.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-af7e06a12bc211827
B=/tmp/b-77t/gcc
O=/tmp/t77-g
rc=0
rm -rf $O; mkdir -p $O

echo "=== options.h is unaffected (the C record is consumed by optc-save-gen alone)"
if cmp -s /tmp/b-objs/gcc/options.h $B/options.h; then
  echo "  ok: options.h byte-identical to the build without this change ($(wc -l < $B/options.h) lines)"
else
  echo "  FAIL: options.h changed"; diff /tmp/b-objs/gcc/options.h $B/options.h | head -20; rc=1
fi

gen () {   # gen <list> <base> -> writes $O/out, $O/err, echoes rc
  awk -f $W/gcc/opt-functions.awk -f $W/gcc/opt-read.awk \
      -v union_file="$1" -v union_base="$2" \
      -f $W/gcc/optc-save-gen.awk \
      -v header_name="config.h system.h coretypes.h tm.h" \
      < $B/optionlist > $O/out 2> $O/err
  echo $?
}

echo
echo "=== POSITIVE CONTROL: the real list must succeed for BOTH bases"
for b in i386 aarch64; do
  r=$(gen $B/gcc-options-union.list $b)
  if [ "$r" = 0 ] && [ -s $O/out ]; then
    echo "  ok: base $b generated $(wc -l < $O/out) lines"
  else
    echo "  FAIL: base $b rc=$r"; cat $O/err; rc=1
  fi
done

echo
echo "=== a list with the C records stripped must FAIL BY NAME, not fall back"
grep -v '^C	' $B/gcc-options-union.list > $O/noC.list
echo "  stripped $(( $(wc -l < $B/gcc-options-union.list) - $(wc -l < $O/noC.list) )) C records"
r=$(gen $O/noC.list i386)
if [ "$r" = 0 ]; then
  echo "  FAIL: it succeeded -- the primary's own option set was silently used"; rc=1
elif grep -q "no \`C' records at all" $O/err; then
  echo "  ok: failed by name -- $(head -2 $O/err | tr '\n' ' ')"
else
  echo "  FAIL: it failed, but not with the C-record message:"; head -3 $O/err; rc=1
fi

echo
echo "=== a STALE list (one C record removed) must FAIL BY NAME"
victim=$(grep '^C	' $B/gcc-options-union.list | head -1 | cut -f2)
[ -n "$victim" ] || { echo "  FATAL: no C record to remove"; exit 9; }
grep -v "^C	$victim	" $B/gcc-options-union.list > $O/stale.list
cmp -s $O/stale.list $B/gcc-options-union.list && { echo "  FATAL: nothing was removed"; exit 9; }
r=$(gen $O/stale.list i386)
if [ "$r" = 0 ]; then
  echo "  FAIL: a stale list was accepted; option \`$victim' would vanish from the compare"; rc=1
elif grep -q "no \`C' record for it" $O/err; then
  echo "  ok: failed by name on \`$victim'"
else
  echo "  FAIL: wrong message:"; head -3 $O/err; rc=1
fi

echo
echo "=== opth-gen.awk must SKIP C records, not treat them as members"
awk -f $W/gcc/opt-functions.awk -f $W/gcc/opt-read.awk \
    -v union_file=$B/gcc-options-union.list -v union_base=i386 \
    -f $W/gcc/opth-gen.awk < $B/optionlist > $O/options.h 2> $O/oh.err
r=$?
if [ $r != 0 ]; then
  echo "  FAIL: opth-gen.awk rejected the list containing C records:"; head -3 $O/oh.err; rc=1
elif cmp -s $O/options.h $B/options.h; then
  echo "  ok: regenerated options.h is byte-identical to the built one"
else
  echo "  FAIL: options.h differs"; diff $B/options.h $O/options.h | head -10; rc=1
fi

echo
echo "GUARDS rc=$rc"
exit $rc
