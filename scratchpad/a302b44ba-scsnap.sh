#!/bin/sh
# sc-snap.sh with ONE guard narrowed, and the reason is a shared-worktree fact,
# not a convenience.
#
# `sc-snap.sh' refuses when the worktree is dirty AT ALL:
#
#     ( cd "$SRC" && git diff --quiet && git diff --cached --quiet ) \
#       || FATAL "the grafted testsuite files would not be HEAD"
#
# The stated reason is exactly right and the check is wider than the reason.
# What the graft copies is TWO PATHS:
#
#     gcc/testsuite/lib/multi-target.exp      (copied verbatim)
#     gcc/testsuite/lib/gcc-dg.exp            (read, for the load_lib anchor)
#
# A modification anywhere ELSE cannot make those two differ from HEAD.
#
# WHY IT MATTERS HERE, MEASURED.  This worktree is SHARED and another agent was
# editing it while this row ran -- `Makefile.in', `Makefile.tpl' and
# `target-specs/configure.ac' were modified at 12:10:40, 12:10:45 and 12:12:00,
# concurrently with this task, carrying an `install-fixed-headers'/mkheaders
# rule and a `ts_asm_ok_f' probe helper that are somebody else's in-flight work.
# The wide guard turns another agent's unrelated edit into a refusal to build
# THIS row's control, and the two ways out of that are both worse than
# narrowing it: `git stash' would yank a concurrent agent's uncommitted work out
# from under them, and committing their changes would put my name on code I have
# not read.
#
# So the guard is kept, on the paths it is actually about, and it is kept
# EXACTLY -- `git diff --quiet' on both paths, index and worktree.  This is a
# narrowing, not a removal; if either graft path is dirty this still refuses.
#
# NOTE ON THE MULTI-TARGET SIDE: no narrowing was needed there.  `mt-snap.sh'
# runs `git archive HEAD', which reads the OBJECT DATABASE, not the worktree, so
# the multi-target snapshot for this row excludes the concurrent edits by
# construction.  Verified: the snapshot's anchor is 55, and 55 is HEAD's value.
#
# usage: a302b44ba-scsnap.sh <snapdir>
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?snapshot dir}

MB=$(cd "$SRC" && git merge-base HEAD upstream/master) || exit 9
[ -n "$MB" ] || { echo "FATAL: no merge-base with upstream/master"; exit 9; }

GRAFT_PATHS='gcc/testsuite/lib/multi-target.exp gcc/testsuite/lib/gcc-dg.exp'
for p in $GRAFT_PATHS; do
  [ -f "$SRC/$p" ] || { echo "FATAL: $SRC/$p does not exist; nothing to graft"; exit 9; }
done
( cd "$SRC" && git diff --quiet -- $GRAFT_PATHS && git diff --cached --quiet -- $GRAFT_PATHS ) \
  || { echo "FATAL: a graft path is dirty in $SRC; the grafted files would not be HEAD"; exit 9; }

# THE NARROWING NEEDS AN ARM THAT CAN FAIL, or it is a guard that was deleted
# and described as narrowed.  Run the same check against a path that IS dirty
# and require it to refuse.  If the tree happens to be entirely clean there is
# nothing to test with, and that is stated rather than passed over in silence.
_dirty=$(cd "$SRC" && git diff --name-only; cd "$SRC" && git diff --cached --name-only)
_dirty=$(printf '%s\n' "$_dirty" | grep -v -F -x -e gcc/testsuite/lib/multi-target.exp \
                                              -e gcc/testsuite/lib/gcc-dg.exp | head -1)
if [ -n "$_dirty" ]; then
  if ( cd "$SRC" && git diff --quiet -- "$_dirty" ); then
    echo "FATAL: self-test of the narrowed guard FAILED -- '$_dirty' is listed as"
    echo "  modified but 'git diff --quiet' on it says clean.  The guard cannot"
    echo "  refuse anything and must not be trusted."; exit 9
  fi
  echo "-- narrowed-guard self-test: refuses on '$_dirty' (a really-dirty path)  OK"
else
  echo "-- narrowed-guard self-test: NOT RUN, the worktree has no dirty path to"
  echo "   test with.  This run proves the graft paths are clean and does NOT"
  echo "   prove the guard can refuse."
fi

BRSHA=$(cd "$SRC" && git rev-parse HEAD)

if [ -d "$D" ]; then chmod -R u+w "$D"; fi
rm -rf "$D"; mkdir -p "$D"
( cd "$SRC" && git archive "$MB" ) | tar -x -C "$D"

n=$(grep -c MULTI_TARGET "$D/gcc/Makefile.in" || true)
[ "$n" = 0 ] || { echo "FATAL: snapshot has $n MULTI_TARGET hits in gcc/Makefile.in; it is NOT stock"; exit 9; }
if grep -q 'gcc_backends_arg' "$D/configure"; then
  echo "FATAL: $D/configure has gcc_backends_arg; it is the branch, not upstream"; exit 9
fi
[ ! -f "$D/gcc/multi-target-base.h" ] || { echo "FATAL: branch header present in stock snapshot"; exit 9; }
[ ! -f "$D/gcc/testsuite/lib/multi-target.exp" ] \
  || { echo "FATAL: upstream already has multi-target.exp?  refusing to graft blind"; exit 9; }

# ---- the graft, from HEAD's object database, not the worktree ----
# `git show HEAD:<path>' rather than `cp' from the worktree: this row's whole
# reason for existing is that the worktree may carry somebody else's edit, and
# the guard above proves these two paths are clean rather than making it safe to
# read them.  Reading from HEAD makes it true regardless.
( cd "$SRC" && git show "HEAD:gcc/testsuite/lib/multi-target.exp" ) \
  > "$D/gcc/testsuite/lib/multi-target.exp"
G="$D/gcc/testsuite/lib/gcc-dg.exp"
if grep -q '^load_lib multi-target.exp$' "$G"; then
  echo "FATAL: gcc-dg.exp already loads it"; exit 9
fi
grep -q '^load_lib dg-test-cleanup.exp$' "$G" \
  || { echo "FATAL: no 'load_lib dg-test-cleanup.exp' anchor line in $G"; exit 9; }
awk '{print} /^load_lib dg-test-cleanup\.exp$/ && !d {print "load_lib multi-target.exp"; d=1}' \
  "$G" > "$G.new" && mv "$G.new" "$G"

( cd "$SRC" && git show "HEAD:gcc/testsuite/lib/multi-target.exp" ) > "$D/.graft-ref"
cmp "$D/.graft-ref" "$D/gcc/testsuite/lib/multi-target.exp" \
  || { echo "FATAL: grafted multi-target.exp differs from HEAD's"; exit 9; }
rm -f "$D/.graft-ref"
[ "$(grep -c '^load_lib multi-target.exp$' "$G")" = 1 ] \
  || { echo "FATAL: load_lib line not inserted exactly once"; exit 9; }

echo "$MB" > "$D/STOCK-SHA"
echo "$BRSHA" > "$D/GRAFT-FROM-SHA"
chmod -R a-w "$D" 2>/dev/null || true
echo "stock snapshot $D"
echo "  upstream merge-base   $MB"
echo "  testsuite graft from  $BRSHA (multi-target.exp + one load_lib line), read from HEAD"
echo "  MULTI_TARGET anchor   $n  (must be 0 -- this is the control)"
