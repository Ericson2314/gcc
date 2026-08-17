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
# THE FILE LIST WAS HARDCODED TO TWO FILES AND THE TREE HAS 61.  Measured at
# `b4efd6bb9e5': `git grep -l "scratchpad/[A-Za-z0-9]" -- gcc/' returns 61
# files -- `target-cdata.h', `target-frame.h', `multi-target-macros.h',
# `target-cumargs.cc', `config.gcc' and 30-odd back-end `.cc' files all cite
# scratchpad paths in their comments, and this checker examined NONE of them
# while reporting `CITE-CHECK PASSES'.
#
# That is this instrument's own defect wearing its own clothes.  It exists
# because `gcc/Makefile.in' cited a guard that did not exist; a citation in
# `target-cdata.h' reads as evidence in exactly the same way, and the
# conversion layer is where the citations that MATTER live -- they are the
# only record of which measurement authorised which conversion.  PRINCIPLES
# already records the sibling failure: the `DEVSHELL.md' rule was invisible to
# this script because it omitted the `scratchpad/' prefix.  One hardcoded list
# and one pattern, each blind to a different half.
#
# So the list is DERIVED now, not maintained.  A file added tomorrow that
# cites a scratchpad path is checked without editing this script -- which is
# the same argument `mt-lib.sh' makes about the per-worktree build-dir case,
# the line that forced 63 copies of `mt-conf.sh'.
#
# THIS CHECK IS CURRENTLY RED, ON PURPOSE, AND HERE IS THE QUEUE.  Widening
# the file list from 2 to 239 found FOUR build-tree citations of scratchpad
# files that DO NOT EXIST -- and `git log --all' says **none of the four was
# ever committed**, so each is a guard that was named and never written, which
# is precisely the defect this script exists for, three or four times over:
#
#   gcc/multi-target-select.cc   a `sweep.sh'          -- FIXED at b4efd6bb9e5,
#                                                         now cites mt-rename-sweep.sh
#   gcc/check-spec-refs.sh       ct-specrefs-cal.sh    -- OPEN
#   gcc/gen-multi-target-md.awk  pz-polyaware-selftest.sh -- OPEN
#   gcc/gen-target-manifest.sh   eh-census.sh          -- OPEN
#
# DO NOT MAKE THIS GREEN BY NARROWING IT.  PRINCIPLES section 2a: "deleting,
# relaxing, or narrowing a check that fails" is the first thing that looks
# like a fix and undoes the work.  The three OPEN rows are resolved by
# WRITING the guard, or by rewriting the comment to describe what was
# measured instead of citing a file that never was.  Each of those comments
# currently reads as evidence that a check ran.
#
# usage: mt-cite-check.sh [srcdir]   (default: the tree this script is in)
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=${1:-$(cd "$S/.." && pwd)}
FILES=$( cd "$SRC" && { git grep -l 'scratchpad/[A-Za-z0-9]' -- gcc scratchpad 2>/dev/null \
           || grep -rl 'scratchpad/[A-Za-z0-9]' gcc scratchpad 2>/dev/null; } | sort -u )
# The two that MUST be in it, asserted by name: a derived list that silently
# came back empty, or lost the file this script was written for, is the
# null-result-as-a-pass shape and it would still print a clean green below.
# `$FILES' is NEWLINE-separated, so the membership test below must compare
# against a SPACE-separated copy -- `case " $FILES " in *" x "*' matches
# nothing when the separator is a newline, and the first run of this guard
# refused a correct tree for that reason.
FILES_SP=$(echo "$FILES" | tr '\n' ' ')
for m in gcc/Makefile.in scratchpad/PRINCIPLES.md; do
  case " $FILES_SP " in
    *" $m "*) ;;
    *) echo "FATAL: derived file list does not contain $m -- the list is wrong,"
       echo "       and a wrong list still reports CITE-CHECK PASSES."; exit 9 ;;
  esac
done
NFILES=$(echo "$FILES" | grep -c .)
[ "$NFILES" -ge 2 ] || { echo "FATAL: derived $NFILES files to check"; exit 9; }
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
      # A CITATION MUST LOOK LIKE A FILENAME.  Widening the file list turned
      # up `scratchpad/sc-', `scratchpad/mt-', `scratchpad/t32-' and
      # `scratchpad/t145-' as "missing files" -- they are the pattern grabbing
      # a PREFIX out of running prose ("the `t145-' scripts"), not citations
      # of anything.  Requiring a dot-extension removes them.
      #
      # THIS IS A SHAPE TEST, NOT A NARROWING.  It cannot hide a real
      # citation: every artefact this project cites has an extension (.sh,
      # .md, .c, .cc, .txt, .awk, .py).  A bare prefix names no file, so
      # scoring it MISSING is a false alarm, and PRINCIPLES is explicit that
      # an instrument which only revokes should be too eager -- but a check
      # that cries wolf is a check somebody eventually narrows to green, which
      # is the expensive end state.
      case "$c" in *.*) ;; *) continue ;; esac
      if [ -e "$SRC/$c" ]; then
        echo "ok      $f -> $c"
      elif case "$f" in gcc/*) false ;; *) true ;; esac; then
        # ADVISORY, and the split is DELIBERATE and must never be dropped.
        #
        # THE AXIS IS `gcc/' vs `scratchpad/', AND THE FIRST DRAFT GOT IT
        # WRONG.  That draft split on `.md' vs not, reasoning that prose
        # quotes bad citations deliberately -- PRINCIPLES records that this
        # checker "cannot tell a QUOTATION of a bad citation from a citation",
        # and `INSTRUMENTS.md' and `STATE.md' name `sweep.sh' on purpose in
        # order to EXPLAIN the defect.  True, and the extension is not the
        # axis: `mt-rename-sweep.sh' and THIS SCRIPT'S OWN HEADER quote
        # `sweep.sh' in exactly the same explanatory way, and both are `.sh'.
        # `scratchpad/attic/' is retired instruments, where a dead citation is
        # the point.
        #
        # The defect this check exists for is a citation IN THE BUILD TREE:
        # `gcc/Makefile.in' naming a guard that never existed, believed for
        # months because a comment naming a check reads as evidence the check
        # ran.  That is a property of `gcc/', not of a file extension.  So a
        # miss under `gcc/' FAILS and a miss under `scratchpad/' is reported
        # with a count.
        #
        # THIS IS STILL STRICTLY MORE COVERAGE THAN BEFORE: the failing half
        # went from ONE file (`gcc/Makefile.in') to every file under `gcc/'
        # that cites anything, and it immediately re-found the original defect
        # in `gcc/multi-target-select.cc', which had cited `scratchpad/sweep.sh'
        # -- a file that never existed -- for as long as that comment stood.
        # The advisory count is printed unconditionally so it cannot quietly
        # go to zero unnoticed.
        echo "ADVISORY $f -> $c"
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
adv=$(grep -c '^ADVISORY' "$OUT" || true)
nsrc=$(echo "$FILES" | grep -vc '\.md$' || true)
echo "$seen citations examined across $NFILES files (list derived, not hardcoded)"
echo "  $nsrc non-prose files -- these FAIL the run; the old list had 1 of them"
echo "  $adv ADVISORY miss(es) in .md prose (quotations of bad citations are"
echo "     deliberate there and are counted, never silently dropped):"
grep '^ADVISORY' "$OUT" | sed 's/^/     /' || true
if [ "$bad" -gt 0 ]; then
  echo "CITE-CHECK FAILS: $bad cited scratchpad file(s) do not exist."
  echo "Either the file was retired without fixing its citation, or the"
  echo "citation names a check nobody ever wrote.  Both have happened here."
  exit 1
fi
echo "CITE-CHECK PASSES: every cited scratchpad path exists."
