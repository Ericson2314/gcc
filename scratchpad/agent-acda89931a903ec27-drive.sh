#!/bin/sh
# Configure + build the 47-base tree for this worktree, then stamp.
# Build dir and snapshot are both named for the FULL worktree id AND the sha,
# per PRINCIPLES (a guard matching worktree-id substrings deleted 207 dirs).
set -eu
ID=agent-acda89931a903ec27
SHA=fe6a8ffd02b
SNAP=/tmp/snap-$ID-$SHA
# `mt_assert_builddir' derives the expected tag by STRIPPING the `agent-'
# prefix, so the dir must be `b-acda89931a903ec27', not `b-agent-...'.  The
# guard fired correctly and the run simply never started -- and an unstarted
# build looks exactly like a slow one from outside, which is why the progress
# monitor reads `conf.rc' rather than elapsed time.
D=/tmp/b-acda89931a903ec27
HERE=$(cd "$(dirname "$0")" && pwd)

SRC=$SNAP WANT_ANCHOR=52 sh "$HERE/mt-conf.sh" "$D" "$(cat /tmp/trlist-$ID.txt)"
sh "$HERE/mt-build.sh" "$D" all-gcc all-gcc
echo "DRIVE-DONE rc=$?"
