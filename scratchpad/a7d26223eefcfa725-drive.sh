#!/bin/sh
# Configure + build the 47-base tree for worktree agent-a7d26223eefcfa725.
#
# Snapshot AND build dir carry the full worktree id and the sha, per PRINCIPLES
# (a coordinator sweep with a substring guard deleted 207 dirs; and overwriting
# a snapshot a configured build dir points at silently measures the wrong
# commit, because a build dir re-reads its srcdir long after configure).
#
# WANT_ANCHOR is MEASURED here, not copied from the brief.  The brief says 52
# and the tree says 52, but the value has been 23/27/28/30/37/39/45/47/49/52
# at different tips and a wrong-but-plausible number is the dangerous case.
set -eu
ID=agent-a7d26223eefcfa725
HERE=$(cd "$(dirname "$0")" && pwd)
W=$(cd "$HERE/.." && pwd)
cd "$W"
SHA=$(git rev-parse --short HEAD)
SNAP=/tmp/snap-$ID-$SHA
# mt_assert_builddir strips the `agent-' prefix to derive the expected tag.
D=/tmp/b-a7d26223eefcfa725

A=$(grep -c MULTI_TARGET gcc/Makefile.in)
echo "MEASURED anchor=$A sha=$SHA"
export WANT_ANCHOR=$A

if [ ! -f "$SNAP/SNAP-SHA" ]; then
  rm -rf "$SNAP"; mkdir -p "$SNAP"
  git archive HEAD | tar -x -C "$SNAP"
  git rev-parse --short HEAD > "$SNAP/SNAP-SHA"
  chmod -R a-w "$SNAP"
fi
echo "snapshot $SNAP -> $(cat "$SNAP/SNAP-SHA")"

# 47 triples, straight from the committed back-end map, so the list and the
# scoring map cannot drift apart into two authorities for one fact.
TR=$(cut -d: -f2 "$HERE/agent-acda89931a903ec27-backends.txt" | paste -sd, -)
echo "$TR" > /tmp/trlist-$ID.txt
echo "triples: $(echo "$TR" | tr ',' '\n' | wc -l)"

SRC=$SNAP sh "$HERE/mt-conf.sh" "$D" "$TR"
sh "$HERE/mt-build.sh" "$D" all-gcc all-gcc
echo "DRIVE-DONE rc=$?"
