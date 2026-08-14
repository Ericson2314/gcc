#!/bin/sh
# usage: res-make.sh <tag>   -- incremental `make -k -j8 all-gcc' in this
# task's build dir, capturing stdout/stderr to <builddir>/<tag>.{out,err}.
# Build dir is named for this worktree per PRINCIPLES section 5.
set -e
S=$(cd "$(dirname "$0")" && pwd)
D=/tmp/b-af73bc3169a097677
TAG=${1:?tag}
# The build dir must have been configured from THIS tree (PRINCIPLES s5).
# NOTE: gcc/Makefile does not exist until the first make, so it is NOT the
# guard here; config.log is written by configure and is the right instrument.
[ -f "$D/config.log" ] || { echo "FATAL: $D/config.log missing"; exit 9; }
SRC=$(cd "$S/.." && pwd)
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D was not configured from $SRC"; exit 9; }
# `set +e' AROUND THE MAKE, AND THIS IS NOT A STYLE CHOICE.  Under `-k' a
# non-zero rc is the EXPECTED outcome -- the whole point is to keep going past
# failures and count them -- so `set -e' aborts the script on the normal case,
# before the stamp below is written.  It did exactly that: the run exited 2,
# no stamp appeared, and the log looked like a build that was still going.
set +e
rm -f "$D/$TAG.rc"
sh "$S/eb-shell.sh" "cd $D && make -k -j8 all-gcc" > "$D/$TAG.out" 2> "$D/$TAG.err"
rc=$?
set -e
# THE COMPLETION STAMP, AND WHY IT EXISTS.  Both of this task's first two
# builds were SCORED WHILE STILL RUNNING: the log existed, was non-empty, and
# contained `error:' lines, so every existence/non-emptiness check passed --
# and the counts read from them were lower bounds at two different, unknown
# points in two different builds.  That is PRINCIPLES section 4 exactly:
# "non-empty" and "exists" are the shape that passes on the truncated
# artefact.  A score is only meaningful against a log whose build FINISHED,
# so the finish is recorded IN the log's own directory, keyed to the tag, and
# res-score.sh refuses without it.
echo "$rc" > "$D/$TAG.rc"
echo "rc=$rc tag=$TAG"
