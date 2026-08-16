#!/bin/sh
# agent-a4568de8f522450d3-drive2.sh -- the THIRD 47-base tree: both halves of
# the function-decoration bracket.
#
# A SEPARATE FILE, NOT AN EDIT TO -drive.sh, because that script was executing
# when this was written.  PRINCIPLES: `sh' reads a script by BYTE OFFSET, so
# inserting lines above the current position can make a running shell resume
# mid-statement and execute a fragment that never existed in any version of the
# file -- and the file on disk afterwards reads correctly, so there is no
# artefact to inspect.
#
# THE THREE TREES.  The board's own method: "each cause as its own 47-base tree
# so the movement attributes".  Three rather than four because the host is at
# load 48 with two other agents building, and a fourth tree buys only the split
# between the last two causes -- which affect disjoint back ends (s390 / the 13
# ADJUST_INSN_LENGTH definers) and so are separable by inspection anyway.
#
#   pre    4387bf9ce42  multi-target-0 tip
#   post3  <HEAD>       all three conversions
#
# ONE post tree, not three, AND THE ATTRIBUTION IS NOT LOST -- the three causes
# land on DISJOINT targets, so the four scored targets separate them without
# separate trees:
#
#   riscv64  ASM_DECLARE_FUNCTION_SIZE only  (riscv defines no other of the 3)
#   s390x    SIZE + PREFIX, which are the two halves of ONE bracket and are
#            inert apart -- s390's pop is guarded on the same condition as its
#            push, so the pop alone emits nothing
#   aarch64  ADJUST_INSN_LENGTH only  (aarch64 does not override the other two)
#   x86_64   none of the three        <- the control
#
# The intermediate `post' tree (fe9cbaf5163, SIZE alone) was built and FAILED:
# epiphany's ASM_DECLARE_FUNCTION_SIZE calls `lookup_attribute' and
# target-cumargs.cc did not include attribs.h.  rc=2, one `error:', no cc1 --
# the conversion mechanism failing by name, which is what it is for.  It is not
# rebuilt because the target split above makes it redundant.
set -u
ID=agent-a4568de8f522450d3
W=$(cd "$(dirname "$0")/.." && pwd)
A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j6}
LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep -v '^$' | paste -sd,)

sha=3d961951ccc
tag=post3
S=/tmp/snap-$ID-$sha
D=/tmp/b-${ID#agent-}-$tag

echo "anchor=$A jobs=$MT_MAKEFLAGS bases=$(echo "$LIST" | tr ',' '\n' | wc -l)"
[ -f "$S/SNAP-SHA" ] || { echo "FATAL: no snapshot $S"; exit 9; }
# ASSERT THE CONTENT, BY NAME, NOT THAT THE SNAPSHOT EXISTS.  Both halves must
# be in this tree; a snapshot of the wrong commit passes every existence test.
grep -q mt_declare_function_size   "$S/gcc/varasm.cc" || { echo "FATAL: snapshot lacks the POP half";  exit 9; }
grep -q mt_declare_function_prefix "$S/gcc/varasm.cc" || { echo "FATAL: snapshot lacks the PUSH half"; exit 9; }
grep -q mt_adjust_insn_length      "$S/gcc/final.cc"  || { echo "FATAL: snapshot lacks ADJUST_INSN_LENGTH"; exit 9; }
# ANCHORED AT LINE START, AND THE UNANCHORED VERSION WAS A FALSE RED.  It was
# `grep -q "#ifdef ADJUST_INSN_LENGTH"', which matched the string inside the
# CONVERSION'S OWN COMMENT at final.cc:404 ("This was `#ifdef
# ADJUST_INSN_LENGTH', i.e. ...") and refused a correct snapshot.  Same
# "a scan cannot tell a mention from a use" failure this task diagnosed in the
# census's DESCRIPTOR bucket, committed here by the person who diagnosed it.
# A false RED costs what a false green costs: the remedy it invites is
# reverting a correct change.
grep -qE '^[[:space:]]*#[[:space:]]*ifdef[[:space:]]+ADJUST_INSN_LENGTH' "$S/gcc/final.cc" \
  && { echo "FATAL: snapshot still has a raw #ifdef ADJUST_INSN_LENGTH"; exit 9; }
echo "=== $tag src=$S build=$D  (all three conversions present)"

SRC=$S sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST" \
    > /tmp/b-${ID#agent-}-$tag-conf.log 2> /tmp/b-${ID#agent-}-$tag-conf.err
rc=$?
echo "  conf rc=$rc"
[ $rc -eq 0 ] || { tail -20 /tmp/b-${ID#agent-}-$tag-conf.err; exit 9; }
sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "  build rc=$? stamp=$(cat "$D/all-gcc.rc" 2>/dev/null || echo MISSING)"
echo "DRIVE2 DONE"
