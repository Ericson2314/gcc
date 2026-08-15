#!/bin/sh
# agent-a97cff7619d3cabd9-vregno.sh -- is the VIRTUAL REGISTER NUMBERING one
# number, or two?
#
# THE QUESTION THIS ASKS, STATED OUT LOUD, because a check that answers a
# different question than the one being settled is this branch's dominant
# false green: `does LAST_VIRTUAL_REGISTER have the SAME VALUE in a SHARED
# translation unit and in a BACK END'S OWN translation unit?'  Not "does it
# compile", not "did the ICE go away" -- both of those are downstream and both
# can be green for other reasons.
#
# It is NON-VACUOUS BY CONSTRUCTION: it reads TWO numbers and compares them, so
# it cannot report a pass without having read both.  On the UNFIXED tree it
# must print DIFFER (677+5 vs 92+5); on the fixed tree, EQUAL.  Run it on both
# and require both answers -- an instrument that has only ever printed one of
# its two outcomes has not been shown to be able to print the other.
#
# HOW THE VALUE IS READ.  `LAST_VIRTUAL_REGISTER' is a preprocessor-evaluable
# integer in both contexts (a literal 92 from i386.h on one side, the generated
# MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER on the other), so the probe declares
# `char mt_probe_lvr[LAST_VIRTUAL_REGISTER]' and the SIZE of that symbol is the
# value.  `nm --print-size' is the reader.  A `#pragma message' would print the
# token sequence rather than the number, which is useful and is printed too --
# it names the AUTHORITY on each side.
#
# usage: agent-a97cff7619d3cabd9-vregno.sh <builddir>
set -u
D=${1:?build dir}
case "$D" in */b-a97cff7619d3cabd9*) ;; *) echo "FATAL: not this worktree's build dir"; exit 9 ;; esac
LOG="$D/all-gcc.log"
[ -s "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }
W="$D/vregno"; rm -rf "$W"; mkdir -p "$W"

cat > "$W/probe.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
#include "rtl.h"
#define MT_STR(x) #x
#define MT_XSTR(x) MT_STR(x)
#pragma message ("MT_PROBE_TOKENS LAST_VIRTUAL_REGISTER=" MT_XSTR(LAST_VIRTUAL_REGISTER))
char mt_probe_lvr[LAST_VIRTUAL_REGISTER];
char mt_probe_fpr[FIRST_PSEUDO_REGISTER];
EOF

# The two real compile commands, taken from the build's OWN log rather than
# reconstructed -- a reconstructed command line is a third authority.
for arm in shared:recog.o base:mt-i386/i386-expand.o; do
  tag=${arm%%:*}; obj=${arm#*:}
  cmd=$(grep -F -- " -o $obj " "$LOG" | tail -1)
  [ -n "$cmd" ] || { echo "FATAL: no compile command for $obj in $LOG"; exit 9; }
  # replace the -o target and the source file; keep every -D/-I untouched.
  new=$(printf '%s\n' "$cmd" \
        | sed -e "s#-o $obj #-o $W/$tag.o #" \
              -e "s#-MT [^ ]* ##" -e "s#-MMD -MP -MF [^ ]* ##" \
              -e "s#[^ ]*\.cc\$#$W/probe.cc#")
  case "$new" in *"$W/probe.cc") ;; *) echo "FATAL: source substitution failed for $tag"; exit 9 ;; esac
  ( cd "$D/gcc" && eval "$new" ) > "$W/$tag.out" 2> "$W/$tag.err" || {
      echo "FATAL: probe compile failed for $tag"; sed -n 1,20p "$W/$tag.err"; exit 9; }
  grep -h 'MT_PROBE_TOKENS' "$W/$tag.err" | sed "s/^/  $tag tokens: /"
  v=$(nm --print-size "$W/$tag.o" | awk '$NF=="mt_probe_lvr" {print strtonum("0x" $2)}')
  f=$(nm --print-size "$W/$tag.o" | awk '$NF=="mt_probe_fpr" {print strtonum("0x" $2)}')
  [ -n "$v" ] || { echo "FATAL: could not read mt_probe_lvr size for $tag"; exit 9; }
  echo "$tag FIRST_PSEUDO_REGISTER=$f LAST_VIRTUAL_REGISTER=$v"
  eval "V_$tag=$v"
done

echo "----"
if [ "$V_shared" = "$V_base" ]; then
  echo "VERDICT: EQUAL  ($V_shared) -- one numbering"
else
  echo "VERDICT: DIFFER (shared $V_shared vs i386 $V_base) -- TWO AUTHORITIES"
fi
