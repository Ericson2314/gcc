#!/bin/sh
# agent-ae59966cf819d72ef-drive-post.sh -- the POST 47-base tree: the
# case-vector ELEMENT conversion.
#
# A SEPARATE FILE rather than an edit to `-drive.sh', because that script may
# still be executing.  PRINCIPLES: `sh' reads a script by BYTE OFFSET, so
# inserting lines above the running position can make the shell resume
# mid-statement and run a fragment that never existed in any version of the
# file -- and the file reads correctly afterwards, so there is no artefact.
#
#   PRE   9adf8ca6ae6   the merge, built green:  rc=0, 0 error:, cc1 links,
#                       stderr 4761, cc1 231,167,704 bytes
#   POST  <HEAD>        + ASM_OUTPUT_ADDR_VEC_ELT / ASM_OUTPUT_ADDR_DIFF_ELT
#                         and the tree-switch-conversion.h closure
set -u
ID=agent-ae59966cf819d72ef
W=$(cd "$(dirname "$0")/.." && pwd)
A=$(grep -c MULTI_TARGET "$W/gcc/Makefile.in")
export WANT_ANCHOR=$A
export MT_MAKEFLAGS=${MT_MAKEFLAGS:--j6}
LIST=$(grep -v '^#' "$W/scratchpad/backends-47.txt" | grep -v '^$' | paste -sd,)
NB=$(echo "$LIST" | tr ',' '\n' | grep -c .)

sha=$(git -C "$W" rev-parse --short HEAD)
S=/tmp/snap-$ID-$sha
D=/tmp/b-${ID#agent-}-post

echo "anchor=$A jobs=$MT_MAKEFLAGS bases=$NB sha=$sha"
[ "$A" = 52 ] || { echo "FATAL: anchor $A, expected 52"; exit 9; }
[ "$NB" = 47 ] || { echo "FATAL: $NB bases"; exit 9; }
git -C "$W" diff --quiet || { echo "FATAL: dirty worktree"; exit 9; }

chmod -R u+w "$S" 2>/dev/null || :
rm -rf "$S"; mkdir -p "$S"
git -C "$W" archive HEAD | tar -x -C "$S"
echo "$sha" > "$S/SNAP-SHA"

# ASSERT THE CONVERSION IS IN THE SNAPSHOT, BY NAME AND ON BOTH SIDES.  A
# snapshot of the wrong commit passes every existence test, and the two halves
# of this change land in different files -- the emitter in final.cc, the
# closure in tree-switch-conversion.h.  A snapshot with one and not the other
# is a state no commit has and it would build.
grep -q mt_output_addr_vec_elt  "$S/gcc/final.cc" || { echo "FATAL: final.cc lacks the VEC emitter";  exit 9; }
grep -q mt_output_addr_diff_elt "$S/gcc/final.cc" || { echo "FATAL: final.cc lacks the DIFF emitter"; exit 9; }
grep -q mt_has_output_addr_diff_elt "$S/gcc/tree-switch-conversion.h" \
  || { echo "FATAL: tree-switch-conversion.h lacks the closure"; exit 9; }
# ANCHORED AT LINE START.  The unanchored form matches the conversion's OWN
# comment, which quotes the macro it replaced -- the false RED the previous
# agent recorded writing into its own guard, two commits after diagnosing the
# same "a scan cannot tell a mention from a use" defect in the census.
grep -qE '^[[:space:]]*#[[:space:]]*ifdef[[:space:]]+ASM_OUTPUT_ADDR_VEC_ELT' "$S/gcc/final.cc" \
  && { echo "FATAL: snapshot still has a raw #ifdef ASM_OUTPUT_ADDR_VEC_ELT in final.cc"; exit 9; }
grep -qE '^[[:space:]]*#[[:space:]]*ifndef[[:space:]]+ASM_OUTPUT_ADDR_DIFF_ELT' "$S/gcc/tree-switch-conversion.h" \
  && { echo "FATAL: snapshot still has the raw #ifndef closure"; exit 9; }
echo "  snapshot content asserted: emitter (both halves) + closure present, raw guards gone"
chmod -R a-w "$S"

SRC=$S sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST" \
    > /tmp/$ID-post-conf.log 2> /tmp/$ID-post-conf.err
rc=$?
echo "  conf rc=$rc"
[ $rc -eq 0 ] || { tail -20 /tmp/$ID-post-conf.err; exit 9; }
sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "  build rc=$? stamp=$(cat "$D/all-gcc.rc" 2>/dev/null || echo MISSING)"
echo "DRIVE-POST DONE"
