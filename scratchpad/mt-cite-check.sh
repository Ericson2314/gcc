#!/bin/sh
# mt-cite-check.sh -- every `scratchpad/<file>' cited in gcc/Makefile.in and
# PRINCIPLES.md must EXIST.
#
# WHY.  gcc/Makefile.in's MULTI_TARGET_RENAME_NAMES comment named
# `scratchpad/sweep.sh' as the authority for its own invariant, and that file
# DID NOT EXIST -- a guard naming a guard that never ran, believed for months
# because a comment naming a check reads as evidence the check ran.  It has
# happened twice.  The check costs one line and this is it.
#
# It cannot say a cited file is the RIGHT one -- only that it is there.  That
# is deliberate: this arm can only revoke a citation, never bless one, so it is
# made over-broad (PRINCIPLES 4: "when an instrument can only take away, make
# it too eager; when it can grant, make it exact").
#
# usage: mt-cite-check.sh [srcdir]   (default: the tree this script is in)
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$(cd "$S/.." && pwd)}
FILES="gcc/Makefile.in scratchpad/PRINCIPLES.md"
# Scratch goes to a temp file, NOT into scratchpad/: several harnesses assert
# `git diff --quiet' on the srcdir, and a check that dirties the tree it checks
# makes every one of them fail for a reason that has nothing to do with them.
OUT=$(mktemp); trap 'rm -f "$OUT"' EXIT

bad=0; seen=0
for f in $FILES; do
  [ -f "$SRC/$f" ] || { echo "FATAL: no $SRC/$f"; exit 9; }
  # Citations appear in prose, so strip trailing punctuation and quoting.
  grep -o "scratchpad/[A-Za-z0-9_][A-Za-z0-9_.-]*" "$SRC/$f" \
    | sed "s/[.,;:'\`]*$//" | sort -u \
  | while IFS= read -r c; do
      case "$c" in */) continue ;; esac
      if [ -e "$SRC/$c" ]; then
        echo "ok      $f -> $c"
      else
        echo "MISSING $f -> $c"
      fi
    done
done > "$OUT"
seen=$(grep -c . "$OUT" || true)
bad=$(grep -c '^MISSING' "$OUT" || true)

# NON-VACUITY.  Zero citations examined would print no MISSING lines and read
# as a clean pass; that is the "absent artefact vs absent mechanism" shape.
[ "$seen" -gt 0 ] || { echo "FATAL: examined 0 citations -- this proved NOTHING"; exit 9; }
grep '^MISSING' "$OUT" || true
echo "$seen citations examined in: $FILES"
if [ "$bad" -gt 0 ]; then
  echo "CITE-CHECK FAILS: $bad cited scratchpad file(s) do not exist."
  echo "Either the file was retired without fixing its citation, or the"
  echo "citation names a check nobody ever wrote.  Both have happened here."
  exit 1
fi
echo "CITE-CHECK PASSES: every cited scratchpad path exists."
