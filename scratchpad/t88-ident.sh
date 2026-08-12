#!/usr/bin/env bash
# Single-target regression bar for the optc-gen.awk change.
#
# In a single-target build `MT_OPTIONS_UNION_LIST' is empty, so no -v
# union_file reaches optc-gen.awk and the new code prints the four loops in the
# order they ran.  This runs the OLD script and the NEW one over the SAME
# optionlist with no union flags and requires byte identity -- which is the
# strongest available statement that nothing moved, and it is stronger than a
# line count: the loops now record into an array that DEDUPLICATES, and the old
# `static_var'/`SetByCombined' loops did not, so a duplicate record would show
# up here as a missing line rather than as nothing at all.
#
#   t88-ident.sh <builddir>/gcc <old-optc-gen.awk> <old-opt-stub.awk>
set -u -o pipefail
D=${1:?usage: t88-ident.sh <builddir>/gcc <old-optc-gen> <old-opt-stub>}
OLDC=${2:?}; OLDS=${3:?}
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/gcc
for f in "$D/optionlist" "$D/optionlist-vocab" "$OLDC" "$OLDS" \
         "$S/optc-gen.awk" "$S/opt-stub.awk"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done
command -v gawk >/dev/null || { echo "FATAL: no gawk"; exit 9; }
H="config.h system.h coretypes.h options.h tm.h"
rc=0

echo "=== optc-gen.awk, no -v union_file (the single-target path)"
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" -f "$OLDC" \
     -v header_name="$H" < "$D/optionlist" > /tmp/t88-old.cc 2> /tmp/t88-old.err
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" -f "$S/optc-gen.awk" \
     -v header_name="$H" < "$D/optionlist" > /tmp/t88-new.cc 2> /tmp/t88-new.err
for s in old new; do
  [ -s /tmp/t88-$s.err ] && { echo "FAIL: $s optc-gen wrote to stderr:"; cat /tmp/t88-$s.err; rc=1; }
  n=$(wc -l < /tmp/t88-$s.cc)
  [ "$n" -ge 1000 ] || { echo "FAIL: $s options.cc is only $n lines; nothing was compared"; rc=1; }
done
if cmp -s /tmp/t88-old.cc /tmp/t88-new.cc; then
  echo "  IDENTICAL ($(wc -l < /tmp/t88-new.cc) lines, md5 $(md5sum < /tmp/t88-new.cc | cut -c1-12))"
else
  echo "  DIFFER:"; diff /tmp/t88-old.cc /tmp/t88-new.cc | head -20; rc=1
fi

echo "=== opt-stub.awk on a vocabulary equal to the consumer's own list"
# A single-target build's optionlist-vocab IS its optionlist, so opt-stub.awk
# must emit nothing.  Zero from a script that never ran looks the same, so the
# run is first shown to work by giving it a vocabulary it CAN pad.
for v in old new; do
  s=$OLDS; [ $v = new ] && s=$S/opt-stub.awk
  gawk -f "$S/opt-functions.awk" -f "$s" -v vocab="$D/optionlist" \
       "$D/optionlist" "$D/optionlist" > /tmp/t88-stub-$v.txt 2> /tmp/t88-stub-$v.err
  n=$(wc -l < /tmp/t88-stub-$v.txt)
  echo "  $v: $n stub records (must be 0)"
  [ "$n" -eq 0 ] || rc=1
  [ -s /tmp/t88-stub-$v.err ] && { echo "  FAIL: $v wrote to stderr"; cat /tmp/t88-stub-$v.err; rc=1; }
done
# NON-VACUITY: the same invocation with a vocabulary that is a strict superset
# must emit something, or the zero above proves nothing about the script.
# $NV is another build dir's vocabulary -- NOT this one's.  This build's
# optionlist has already been padded up to its own vocabulary, so passing it
# back in yields zero for a reason that has nothing to do with the script.
# (No apostrophe in this message: it sits inside ${...:?} and ends the word.)
NV=${4:?usage needs a 4th arg -- a DIFFERENT build dir optionlist-vocab}
[ -s "$NV" ] || { echo "FATAL: missing or empty $NV"; exit 9; }
gawk -f "$S/opt-functions.awk" -f "$S/opt-stub.awk" -v vocab="$NV" \
     "$NV" "$D/optionlist" > /tmp/t88-stub-nv.txt 2> /tmp/t88-stub-nv.err
nv=$(wc -l < /tmp/t88-stub-nv.txt)
echo "  non-vacuity: a real vocabulary yields $nv stub records"
[ "$nv" -gt 0 ] || { echo "  FATAL: opt-stub.awk emits nothing even when it should; the zero above is meaningless"; rc=1; }
grep -q 'Target' /tmp/t88-stub-nv.txt && { echo "  FAIL: a stub still carries Target, so it declares a member"; rc=1; }

echo "OVERALL rc=$rc"
exit $rc
