#!/bin/sh
# a76a331dcb554f700 -- REDO THE THREE-WAY MERGE THAT `803794e7c6b' RESOLVED BY
# TAKING ONE SIDE WHOLE.
#
# That merge's own message lists the three conflicted files; the resolution
# kept `ea67506378f''s copy of each, which deleted ~470 lines of
# `target-frame.h' that had come from `05ea5c4a6db' -- among them the whole
# `EH_RETURN_HANDLER_RTX' / `EH_RETURN_STACKADJ_RTX' / `TRAMPOLINE_SECTION'
# conversion.  The CONSUMERS of those (except.cc, df-scan.cc,
# c-family/c-cppbuiltin.cc, varasm.cc, multi-target-macros.h's `#undef') were
# not conflicted and so survived, and the tip therefore DOES NOT BUILD:
#
#   c-cppbuiltin.cc:1638: error: `mt_has_eh_return_stackadj_rtx' was not
#                                declared in this scope
#
# This re-runs the merge the machine's way, per file, and leaves conflict
# markers where it genuinely cannot decide, rather than picking a side.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
D=/tmp/mrg-a76a331dcb554f700
OURS=05ea5c4a6db
THEIRS=ea67506378f
BASE=$(cd "$W" && git merge-base $OURS $THEIRS)
echo "base=$BASE ours=$OURS theirs=$THEIRS"
rm -rf "$D"; mkdir -p "$D"
cd "$W"
for f in gcc/target-frame.h gcc/target-cumargs.cc gcc/target-cumargs-select.cc; do
  n=$(basename "$f")
  git show "$BASE:$f"   > "$D/$n.base"
  git show "$OURS:$f"   > "$D/$n.ours"
  git show "$THEIRS:$f" > "$D/$n.theirs"
  cp "$D/$n.ours" "$D/$n.merged"
  if git merge-file -L ours -L base -L theirs \
       "$D/$n.merged" "$D/$n.base" "$D/$n.theirs"; then
    echo "$n: CLEAN"
  else
    echo "$n: CONFLICTS $(grep -c '^<<<<<<<' "$D/$n.merged")"
  fi
done
