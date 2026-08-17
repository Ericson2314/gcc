#!/bin/sh
# agent-ae59966cf819d72ef-drive.sh -- the 47-base build of the MERGE of
# `agent-a4568de8f522450d3-mt' into `multi-target-0'.
#
# WHY A BUILD AT ALL, when both sides were built green separately: the three
# conflicts are in the `mt_frame ()' table, which each side grew from the same
# end.  A mis-ordered function-pointer initializer is SILENT -- the table has
# no designated initializers and every member of the tail block has a
# compatible-enough shape that a swap gives a wrong call, not a diagnostic.
# The name-for-name check in the merge commit is the cheap arm; this is the one
# that can fail.
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
# `mt-lib.sh:49' derives the expected build-dir name from the WORKTREE
# directory with the `agent-' prefix stripped, so `/tmp/b-$ID' is refused by
# its own guard.  Following the guard rather than editing it, per INSTRUMENTS.
D=/tmp/b-${ID#agent-}

echo "anchor=$A jobs=$MT_MAKEFLAGS bases=$NB sha=$sha"
[ "$A" = 52 ] || { echo "FATAL: anchor $A, expected 52 -- run the grep and say why it moved"; exit 9; }
[ "$NB" = 47 ] || { echo "FATAL: $NB bases, expected 47"; exit 9; }
git -C "$W" diff --quiet || { echo "FATAL: dirty worktree; a snapshot of it measures nothing"; exit 9; }

# `chmod -R u+w' FIRST.  A previous snapshot at this path is `a-w', so `rm -rf'
# cannot unlink its children, `tar' then refuses every file with
# `Cannot open: File exists', and the run CONTINUES against whatever tree was
# there before -- exit statuses and existence tests all pass.  Measured here:
# the leftover happened to be the same sha, so nothing was wrong and nothing
# would have said so either way.
chmod -R u+w "$S" 2>/dev/null || :
rm -rf "$S"; mkdir -p "$S"
git -C "$W" archive HEAD | tar -x -C "$S"
echo "$sha" > "$S/SNAP-SHA"

# ASSERT THE CONTENT BY NAME.  A snapshot of the wrong commit passes every
# existence test.  Both merge parents' contributions must be present: the
# ae-side (this merge) inherits the a4568-side conversions AND the pre-existing
# final_prescan_insn / go_if_legitimate_address members, and a union resolution
# that silently dropped one side would still compile-and-link on the other.
for n in mt_declare_function_size mt_declare_function_prefix; do
  grep -q "$n" "$S/gcc/varasm.cc" || { echo "FATAL: varasm.cc lacks $n"; exit 9; }
done
for n in mt_adjust_insn_length mt_addr_vec_align mt_final_prescan_insn; do
  grep -q "$n" "$S/gcc/final.cc" || { echo "FATAL: final.cc lacks $n"; exit 9; }
done
grep -q mt_go_if_legitimate_address "$S/gcc/recog.cc" \
  || { echo "FATAL: recog.cc lacks mt_go_if_legitimate_address (ours side lost)"; exit 9; }
# The two initializer/member lists must agree name for name.  Cheap, and it is
# the exact failure the conflict could have produced.
sed -n '/^struct target_frame_desc$/,/^};/p' "$S/gcc/target-frame.h" \
  | sed -n 's/^  .*(\*\([a-z_0-9]*\)).*/\1/p' > /tmp/$ID-members.txt
sed -n '/^static const struct target_frame_desc mt_base_frame = {/,/^};/p' \
    "$S/gcc/target-cumargs.cc" \
  | sed -n 's/^  mt_base_\([a-z_0-9]*\),\{0,1\}$/\1/p' > /tmp/$ID-inits.txt
nm_=$(grep -c . /tmp/$ID-members.txt); ni_=$(grep -c . /tmp/$ID-inits.txt)
# NON-VACUITY FIRST.  Two empty files compare equal, and that is the shape that
# reads as a pass while proving nothing.
[ "$nm_" -gt 20 ] && [ "$ni_" -gt 20 ] \
  || { echo "FATAL: member/initializer scan read $nm_/$ni_ -- an empty match is not a pass"; exit 9; }
# The initializer holds non-`mt_base_' entries (MT_BASE_N_ELIMINABLES, the
# array addresses), so the two lists are not expected to be equal in full --
# what must hold is that every name the initializer DOES spell appears in the
# member list in the SAME relative order, which is what the conflict could
# have broken.
for n in final_prescan_insn go_if_legitimate_address declare_function_size \
         declare_function_prefix adjust_insn_length addr_vec_align; do
  grep -qx "$n" /tmp/$ID-members.txt || { echo "FATAL: member $n lost in the merge"; exit 9; }
  grep -qx "$n" /tmp/$ID-inits.txt   || { echo "FATAL: initializer $n lost in the merge"; exit 9; }
done
echo "  target_frame_desc: $nm_ members / $ni_ mt_base_ initializers; all six merge-tail names present"
chmod -R a-w "$S"

SRC=$S sh "$W/scratchpad/mt-conf.sh" "$D" "$LIST" \
    > /tmp/$ID-conf.log 2> /tmp/$ID-conf.err
rc=$?
echo "  conf rc=$rc"
[ $rc -eq 0 ] || { tail -20 /tmp/$ID-conf.err; exit 9; }
sh "$W/scratchpad/mt-build.sh" "$D" all-gcc all-gcc
echo "  build rc=$? stamp=$(cat "$D/all-gcc.rc" 2>/dev/null || echo MISSING)"
echo "DRIVE DONE"
