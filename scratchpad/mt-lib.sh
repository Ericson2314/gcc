#!/bin/sh
# mt-lib.sh -- the guards every mt-*.sh shares.  Sourced, never run.
#
# WHY THIS FILE EXISTS AT ALL.  Six `t<NNN>-rename-gap.sh', 63 `*-conf.sh' and
# 54 `*-build.sh' are ONE script copied per task, and the thing that FORCED the
# copy was always the same two lines:
#
#     case "$D" in
#       */b-a7de5*) ;;                       <- this worktree's hash, hardcoded
#       *) echo "FATAL: ... not named for this worktree"; exit 9 ;;
#     esac
#
# The guard is right -- a harness must assert which tree it measures
# (PRINCIPLES 4) -- and hardcoding it makes the script unrunnable from the next
# worktree, so the next agent copies it under a new task number.  That is the
# proliferation's whole mechanism, and it produced the branch's own root bug in
# its own tooling: one name (`the rename sweep'), several authorities, no
# diagnostic.  It also produced four add/add merge conflicts in one day,
# because `t<NNN>-' numbers are handed out in neighbouring blocks and two
# unrelated agents pick the same filename.
#
# So the tag is DERIVED, not written down.  A worktree is
# `.../worktrees/agent-<hash>' and its build dirs are `.../b-<hash>...'; the
# tag is read from this file's own path.  The guard therefore still refuses
# another worktree's build dir -- it just does so in every worktree without
# being edited, and the file name carries no task number to collide on.
#
# THE FALLBACK IS DELIBERATELY A REFUSAL, NOT A PASS.  If the path does not
# look like a worktree, mt_assert_builddir fails by name rather than accepting
# any build dir: "cannot tell" must not read as "fine" (PRINCIPLES 4).

mt_die () { echo "FATAL: $*" >&2; exit 9; }

# CALL SITES MUST WRITE `x=$(mt_...) || exit 9'.
#
# Caught by testing the guard rather than reading it: `mt_die' runs `exit 9',
# but inside a command substitution that exits only the SUBSHELL, so the
# script sails on and prints a SECOND, more confusing FATAL from the next
# check.  A guard that reports and does not stop is the defect class this
# harness exists to remove.  `$(...)' propagates its status to the assignment,
# so `|| exit 9' is what actually stops it.  Every mt_* below that is used in a
# substitution is spelled that way at every call site; if you add one, do the
# same, and test it by pointing the script at a build dir that must be refused.

# MT_LIB_DIR is set by the caller to its own $(dirname $0).
mt_tag () {
  _wt=$(cd "$MT_LIB_DIR/.." && pwd)
  case "$(basename "$_wt")" in
    agent-*) echo "b-$(basename "$_wt" | sed 's/^agent-//')" ;;
    *) echo "" ;;
  esac
}

# Refuse a build dir belonging to another worktree.  Prefix match, because
# build dirs are named `b-<hash><suffix>' and the hash is truncated in places.
mt_assert_builddir () {
  _d=$1
  _t=$(mt_tag)
  [ -n "$_t" ] || mt_die "cannot derive a worktree tag from $MT_LIB_DIR --
  this is not a .../worktrees/agent-<hash>/scratchpad checkout.  REFUSING
  rather than accepting any build dir: 'cannot tell' is not 'fine'.
  Set MT_TAG= explicitly to override."
  case "$_d" in
    */"$_t"*) ;;
    *) mt_die "build dir $_d is not named for this worktree (expected */$_t*)" ;;
  esac
}
# An explicit override, for the one legitimate case: reading a build dir that
# an earlier task in another worktree produced.  Named so it is visible in the
# command line rather than buried in an edit.
[ -z "${MT_TAG:-}" ] || mt_tag () { echo "$MT_TAG"; }

# The CONTENT ANCHOR.  Exact, never `>=' -- a tree missing a landed change must
# fail here rather than silently measure a compiler that is not this one.
# The value moves in BOTH directions (49 today, and it went DOWN from 55);
# run `grep -c MULTI_TARGET gcc/Makefile.in' on the tree and pass what it says.
mt_assert_anchor () {
  _src=$1
  _n=$(grep -c MULTI_TARGET "$_src/gcc/Makefile.in" || true)
  [ "$_n" = "${WANT_ANCHOR:?set WANT_ANCHOR (grep -c MULTI_TARGET gcc/Makefile.in)}" ] \
    || mt_die "$_src anchor=$_n, expected exactly $WANT_ANCHOR"
  echo "$_n"
}

# "The sources did not change under the build", in the two forms the branch
# uses.  BOTH arms are kept: mtcheck.sh asserted `git diff --quiet' (live
# worktree) and t175-mtcheck.sh asserted SNAP-SHA + read-only (immutable
# snapshot), and each is wrong for the other's srcdir -- `git diff' on a
# `git archive' extraction has no repository and walks UP to whatever contains
# /tmp, turning the check into an error.  Dispatch on which kind it is, and
# refuse a srcdir that is neither.
mt_assert_src_frozen () {
  _src=$1
  if [ -f "$_src/SNAP-SHA" ]; then
    [ ! -w "$_src/gcc/Makefile.in" ] || mt_die "$_src is a snapshot but is writable"
    echo "snapshot $(cat "$_src/SNAP-SHA")"
  elif [ -d "$_src/.git" ] || [ -f "$_src/.git" ]; then
    ( cd "$_src" && git diff --quiet ) || mt_die "$_src is dirty"
    echo "worktree $( cd "$_src" && git rev-parse --short HEAD )"
  else
    mt_die "$_src is neither a snapshot (no SNAP-SHA) nor a git worktree"
  fi
}

# The build dir's OWN testimony about which tree configured it -- independent
# of anything the scripts say, which is the point (PRINCIPLES 4, the
# built-tree audit).
mt_assert_configured_from () {
  _d=$1; _src=$2
  [ -f "$_d/config.log" ] || mt_die "$_d has no config.log"
  grep -q "$_src/configure" "$_d/config.log" \
    || mt_die "$_d/config.log does not name $_src -- it was configured from another tree"
}

mt_src_of () {
  _d=$1
  [ -f "$_d/MY-SRC" ] || mt_die "$_d has no MY-SRC stamp (configure it with mt-conf.sh)"
  cat "$_d/MY-SRC"
}

# Refuse to score a build that has not RETURNED.  A log being written looks
# exactly like a log that finished, and the partial read is always the smaller,
# cleaner-looking number.
mt_assert_stamped () {
  [ -f "$1" ] || mt_die "$1 absent -- the run did not finish; refusing to score"
  echo "rc=$(cat "$1")"
}

mt_shell () { sh "$MT_LIB_DIR/eb-shell.sh" "$@"; }
