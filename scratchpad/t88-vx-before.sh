#!/usr/bin/env bash
# #104 reproduced from the artefacts of a WORKING build dir, so that the
# before-state is measured rather than remembered.
#
# The seven records in /tmp/b88vx/gcc/optionlist whose whole flag word is
# `Undocumented' are the placeholders this change produces; removing them
# recovers the un-padded shared optionlist byte for byte.  Feeding that to the
# opt-stub.awk and optc-gen.awk AT HEAD rebuilds the exact options.cc the
# vxworks configuration had, and the layout check is then run against the
# SAME options.h both times -- the header is not a variable here, because the
# union list comes from optionlist-i386, which has no placeholders at all.
#
#   t88-vx-before.sh <builddir>/gcc <base> <old-opt-stub.awk> <old-optc-gen.awk>
set -u -o pipefail
D=${1:?}; B=${2:?}; OLDS=${3:?}; OLDC=${4:?}
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/gcc
P=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7a5ddfb0cff64e03/scratchpad/t88-prefix.sh
case $D in /*) ;; *) echo "FATAL: builddir must be absolute"; exit 9;; esac
for f in "$D/optionlist" "$D/optionlist-vocab" "$D/gcc-options-union.list" \
         "$D/options.h" "$OLDS" "$OLDC" "$P"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done
W=/tmp/t88-vxbefore; rm -rf $W; mkdir -p $W
H="config.h system.h coretypes.h options.h tm.h"
rc=0

# US = the character opt-gather.awk uses as its field separator.
US=$(printf '\034')
awk -F"$US" '$2!="Undocumented"' "$D/optionlist" > $W/own
nstub=$(( $(wc -l < "$D/optionlist") - $(wc -l < $W/own) ))
echo "stripped $nstub placeholder records; own list is $(wc -l < $W/own) records"
[ "$nstub" -gt 0 ] || { echo "FATAL: nothing was stripped, so there is no before-state to build"; exit 9; }

gawk -f "$S/opt-functions.awk" -f "$OLDS" -v vocab="$D/optionlist-vocab" \
     "$D/optionlist-vocab" $W/own > $W/old.stub 2> $W/old.stub.err
[ -s $W/old.stub.err ] && { echo "FATAL: old opt-stub stderr:"; cat $W/old.stub.err; exit 9; }
echo "opt-stub.awk at HEAD emits $(wc -l < $W/old.stub) records; sample:"
head -3 $W/old.stub | cat -v | sed 's/^/    /'
[ "$(wc -l < $W/old.stub)" -eq "$nstub" ] || { echo "FATAL: HEAD emitted a different number of placeholders ($(wc -l < $W/old.stub)) than were stripped ($nstub); the reconstruction is not faithful"; exit 9; }
LC_ALL=C sort <(cat $W/own $W/old.stub) > $W/old.list

mkdir -p $W/before
cp "$D/options.h" $W/before/options.h
gawk -f "$S/opt-functions.awk" -f "$S/opt-read.awk" \
     -v union_file="$D/gcc-options-union.list" -v union_base="$B" \
     -f "$OLDC" -v header_name="$H" < $W/old.list > $W/before/options.cc 2> $W/before/err
[ -s $W/before/err ] && { echo "FATAL: old optc-gen stderr:"; cat $W/before/err; exit 9; }

echo
echo "=== the layout check against the BEFORE options.cc (must FAIL)"
if bash "$P" $W/before; then
  echo "  FAIL: the before-state passed, so this run demonstrates nothing"; rc=1
else
  echo "  as required: the guard rejects the pre-change options.cc"
fi
echo
echo "=== the layout check against the AFTER options.cc (must PASS)"
bash "$P" "$D" || { echo "  FAIL"; rc=1; }
echo "OVERALL rc=$rc"
exit $rc
