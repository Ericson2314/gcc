#!/bin/sh
# Immutable snapshot + configure + build, for the four-target board at tip.
# Named for the FULL worktree id (PRINCIPLES: a coordinator sweep with a
# substring guard deleted 207 dirs and protected nothing).
set -eu
ID=agent-a01e6c604f26604a7
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/$ID
cd "$W"

A=$(grep -c MULTI_TARGET gcc/Makefile.in)
echo "anchor measured on the tree about to be built: $A"
[ "$A" = 52 ] || { echo "FATAL: anchor $A, refusing"; exit 9; }
export WANT_ANCHOR=$A

# A previous snapshot is chmod a-w, so `rm -rf' fails on every file and the
# script would go on to `tar -x' over a stale tree.  Restore write first.
[ -d "/tmp/snap-$ID" ] && chmod -R u+w "/tmp/snap-$ID"
rm -rf "/tmp/snap-$ID"
mkdir -p "/tmp/snap-$ID"
git archive HEAD | tar -x -C "/tmp/snap-$ID"
git rev-parse --short HEAD > "/tmp/snap-$ID/SNAP-SHA"
chmod -R a-w "/tmp/snap-$ID"
echo "snapshot at $(cat "/tmp/snap-$ID/SNAP-SHA")"

# the 47 triples, comma separated, comments stripped
LIST=$(grep -v '^#' scratchpad/backends-47.txt | grep -v '^$' | paste -sd,)
echo "$LIST" | tr , '\n' | wc -l
# The build dir carries the worktree HASH (mt-lib.sh derives `b-<hash>' by
# stripping the `agent-' prefix); the snapshot carries the full id.  Both are
# unique to this worktree, which is what the naming rule is for.
SRC="/tmp/snap-$ID" sh scratchpad/mt-conf.sh /tmp/b-a01e6c604f26604a7 "$LIST"
