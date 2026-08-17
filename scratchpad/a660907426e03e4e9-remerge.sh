#!/bin/sh
# REPAIR THE MERGE THAT DROPPED A SIDE.
#
# `803794e7c6b' ("Merge commit 'ea67506378f' into multi-target-0") resolved
# three files by TAKING ONE SIDE WHOLE.  `05ea5c4a6db' had the accessor halves
# of eight converted macros; `ea67506378f' did not; the merge kept
# `ea67506378f''s file.  The CALL SITES came back later, so the tip has
#
#     gcc/except.cc:2265   if (mt_has_eh_return_stackadj_rtx ())
#
# and no declaration of that function anywhere.  `make all-gcc' dies on the
# first one it reaches (`c-cppbuiltin.o'), so the tip does not build for ANY
# base set -- this is not an arm-specific finding.
#
# The repair is a three-way merge, not a checkout: the tip's version of these
# files carries the OTHER side's genuine work (the `ASM_OUTPUT_ADDR_VEC_ELT'
# family, seven new externs), which a `git checkout 05ea5c4a6db -- <file>'
# would delete.  Base = the merge base of the two sides, exactly what the
# merge should have used.
#
#   base  e1f0cad1c2c   merge-base(05ea5c4a6db, ea67506378f)
#   ours  HEAD          the tip, with ea67506378f's work
#   thei  05ea5c4a6db   the side whose accessors were dropped
set -eu
BASE=e1f0cad1c2c
THEIRS=05ea5c4a6db
T=$(mktemp -d)
trap 'rm -rf "$T"' 0
rc=0
for f in gcc/target-frame.h gcc/target-cumargs-select.cc gcc/target-cumargs.cc; do
  git show "$BASE:$f"   > "$T/base"
  git show "$THEIRS:$f" > "$T/theirs"
  cp "$f" "$T/ours"
  if git merge-file -L ours -L base -L "$THEIRS" "$T/ours" "$T/base" "$T/theirs"; then
    echo "  $f: merged clean"
  else
    n=$(grep -c '^<<<<<<<' "$T/ours" || true)
    echo "  $f: $n CONFLICT(S) -- resolve by hand"
    rc=1
  fi
  cp "$T/ours" "$f"
done
exit $rc
