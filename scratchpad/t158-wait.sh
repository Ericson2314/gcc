#!/bin/sh
# #158 -- wait for a t158-build.sh run against BUILDDIR to finish.
#
# Matches on the BUILD DIR, which is unique to this worktree, rather than on
# the make command line: an earlier version matched `cd <dir> && make' and
# returned INSTANTLY against a still-running build, because t158-build.sh
# passes make to eb-shell.sh as one argument and the pattern never appeared.
# The census then read a nonexistent log.  Its non-vacuity arm caught that; the
# pattern is fixed here so it does not have to.
#
# pgrep -f matches its own command line, so exclude this script by name.
D=${1:?build dir}
while pgrep -af "t158-build.sh $D" | grep -qv 't158-wait'; do sleep 20; done
echo "build finished for $D"
