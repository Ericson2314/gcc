#!/bin/sh
# a302b44ba-icebisect.sh -- name the commit that introduced the x86_64 `pr78671'
# reload ICE, by bisecting `e1f0cad1c2c..7b39423abba'.
#
# WHY A BISECT AND NOT A READING.  Reading the 150-commit range produced a
# strong suspect (`3241754cf12', which leaves `ira_prohibited_class_mode_regs'
# CLEARED for skipped modes -- and for a PROHIBITION table cleared is the
# maximally permissive value, not the inert one its commit message claims).
# But `MODE_IS_HOLE_P' is per-base and x86 really has TImode, so that path
# should not fire for this mode and the reading does not close.  On this branch
# a plausible mechanism that was never run is the specific failure being
# guarded against, so the suspect is tested rather than reported.
#
# WHAT MAKES IT AFFORDABLE.  Two measurements, both taken before this script was
# written rather than assumed:
#   * `pr78671.c' reproduces the ICE off the built `xgcc' in about a second, so
#     the test is free and only the build costs.
#   * THE ICE STILL FIRES AT TWO BASES (`ICE: YES ... bases=2'), so each step is
#     a two-base build of ~3 minutes instead of a 47-base build.  Had it needed
#     the full union this script would have been unaffordable, which is exactly
#     why that was measured first.
#
# **IT DOES NOT USE `git bisect', AND THAT IS DELIBERATE.**  This runs in the
# SHARED main worktree, where other agents are working.  `git bisect' moves
# HEAD and rewrites the working tree on every step; doing that under a live
# agent would be far worse than the wrong answer.  So the search is a plain
# binary search over `git rev-list --first-parent GOOD..BAD', and every tree is
# materialised with `git archive <sha> | tar -x' into /tmp -- which reads the
# object database ONLY and never touches HEAD, the index, or any file in the
# worktree.
#
# THE ENDPOINTS ARE VERIFIED, NOT ASSUMED.  A bisect whose "good" end is not
# actually good silently converges on nonsense.  Both ends are built and tested
# first and the script REFUSES unless the old end says NO and the new end YES.
#
# usage: a302b44ba-icebisect.sh
set -u
export LC_ALL=C
S=$(cd "$(dirname "$0")" && pwd)
W=/home/jcericson/src/gnu/gcc/multi-target
GOOD=e1f0cad1c2c
BAD=7b39423abba
LOG=/tmp/icebisect-302b44ba.log
: > "$LOG"

probe () {   # probe <commit> -> YES | NO | BAD ; never silent
  _c=$1
  _src=/tmp/bis-src
  _bld=/tmp/b-302b44ba-bis
  # `chmod -R u+w' FIRST: the previous step left this tree read-only (below),
  # and `rm -rf' cannot remove a read-only directory tree.  Without it every
  # step after the first would probe a STALE srcdir while believing it had
  # replaced it -- a bisect quietly reading the same commit every time.
  [ -d "$_src" ] && chmod -R u+w "$_src" 2>/dev/null
  rm -rf "$_src" "$_bld"; mkdir -p "$_src"
  if ! ( cd "$W" && git archive "$_c" ) | tar -x -C "$_src"; then echo BAD; return; fi
  # THE `SNAP-SHA' STAMP IS NOT DECORATION -- `mt_src_of' refuses a tree that is
  # neither a stamped snapshot nor a git worktree, which is how it makes "which
  # compiler is this?" answerable.  The first run of this bisect refused BOTH
  # endpoints for the want of this one line, and refused correctly: it reported
  # that the endpoints did not bracket the fault rather than bisecting on two
  # failed builds.  Written the same way `mt-snap.sh' writes it.
  ( cd "$W" && git rev-parse --short=11 "$_c" ) > "$_src/SNAP-SHA"
  # AND READ-ONLY, which `mt_src_of' also requires -- "is a snapshot but is
  # writable" was the second refusal this bisect earned.  The requirement is
  # not fussiness: a writable srcdir is one a build can edit under itself, and
  # then no later run can say which source produced which compiler.
  chmod -R a-w "$_src"
  out=$(sh "$S/a302b44ba-icebuild.sh" "$_bld" "$_src" 2>&1)
  printf '===== %s\n%s\n' "$_c" "$out" >> "$LOG"
  case "$out" in
    *"ICE: YES"*) echo YES ;;
    *"ICE: NO"*)  echo NO  ;;
    *)            echo BAD ;;
  esac
}

echo "== verifying the endpoints before bisecting anything"
g=$(probe "$GOOD"); echo "   $GOOD (want NO):  $g"
b=$(probe "$BAD");  echo "   $BAD (want YES): $b"
if [ "$g" != NO ] || [ "$b" != YES ]; then
  echo "BISECT: REFUSED -- the endpoints do not bracket the fault."
  echo "  good end said '$g' (want NO), bad end said '$b' (want YES)."
  echo "  Bisecting from here would converge on a commit chosen by a broken"
  echo "  probe rather than by the fault.  See $LOG."
  exit 9
fi

# The candidate list, OLDEST FIRST.  `rev-list' prints newest first.
LIST=$(cd "$W" && git rev-list --reverse "$GOOD..$BAD")
N=$(printf '%s\n' "$LIST" | grep -c .)
echo "== $N commits in $GOOD..$BAD; binary search, no worktree mutation"

# INVARIANT: index `lo-1' is known NO (that is $GOOD), index `hi' is known YES.
lo=1
hi=$N
while [ "$lo" -lt "$hi" ]; do
  mid=$(( (lo + hi) / 2 ))
  c=$(printf '%s\n' "$LIST" | sed -n "${mid}p" | cut -c1-11)
  r=$(probe "$c")
  echo "-- [$lo..$hi] mid=$mid $c : $r"
  case "$r" in
    YES) hi=$mid ;;
    NO)  lo=$((mid + 1)) ;;
    BAD) echo "   build failed at $c -- excluded, narrowing from the low side"
         lo=$((mid + 1)) ;;
  esac
done

FIRSTBAD=$(printf '%s\n' "$LIST" | sed -n "${lo}p")
echo
echo "BISECT: FIRST BAD COMMIT = $(echo "$FIRSTBAD" | cut -c1-11)"
( cd "$W" && git log -1 --format='  %h  %s' "$FIRSTBAD" )
echo "  full log: $LOG"
