#!/bin/sh
# `$(tm_file_list)' was REMOVED from GTFILES and replaced by the per-base union
# plus two named entries.  The danger in that trade is losing a file silently:
# gengtype not reading a header does not fail, it just stops knowing about the
# types in it -- which is the very failure this whole change is about
# (aarch64's `machine_function' was invisible, not overwritten).
#
# So this asserts the SUPERSET property directly: every file the old singular
# chain named must still appear in gtyp-input.list.  The old chain is read out
# of the build dir's own generated Makefile (`tm_file_list='), which is an
# independent record of it, not a list retyped here.
#
# It also asserts the thing the change was FOR -- that a non-primary back end's
# own header is now present -- so a run that loses nothing but also gains
# nothing cannot pass.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b-a2c4f72addc68d136-pair}
L=$B/gcc/gtyp-input.list
M=$B/gcc/Makefile
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$B/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $B configured from '$got', not $SRC"; exit 9; }
[ -s "$L" ] || { echo "FATAL: no gtyp-input.list at $L"; exit 9; }
[ -s "$M" ] || { echo "FATAL: no Makefile at $M"; exit 9; }

# The old chain, with $(srcdir) expanded the way make would.
old=$(sed -n 's/^tm_file_list=//p' "$M" | tr ' ' '\n' | grep . \
      | sed "s|\$(srcdir)|$SRC/gcc|")
[ -n "$old" ] || { echo "FATAL: could not read tm_file_list from $M"; exit 9; }
echo "old tm_file_list entries: $(echo "$old" | wc -l)"
echo "gtyp-input.list entries : $(grep -c . "$L")"

miss=0
for f in $old; do
  if grep -Fxq "$f" "$L"; then :; else echo "LOST: $f"; miss=$((miss+1)); fi
done

# Non-vacuity, both halves.  A back end that is NOT the primary must have its
# own tm.h header in the list now, and no file under config/ may appear twice
# -- the duplicate is what gengtype refused by name on the first attempt
# (`config/i386/i386.h specified more than once for language (all)').
#
# Duplicates are counted over config/ ONLY, and that restriction is a finding
# rather than a convenience: the list legitimately repeats every front-end file
# once per language, because gengtype scopes what follows a `[c]' / `[lto]'
# marker to that language.  53 such repeats exist and are none of this change's
# business.  A blanket uniq -d scores them as failures and would have had this
# arm reporting red for a reason unrelated to what it tests.
gain=$(grep -c 'config/aarch64/aarch64\.h$' "$L")
dup=$(grep '/config/' "$L" | sort | uniq -d | grep -c . || true)
echo "aarch64/aarch64.h present     : $gain (want 1)"
echo "duplicated config/ files      : $dup (want 0)"
[ "$miss" = 0 ] && [ "$gain" = 1 ] && [ "$dup" = 0 ] \
  && echo "GTFILES: OK (superset kept, aarch64 header gained, no config/ dups)" \
  || { echo "GTFILES: FAIL missing=$miss gain=$gain dup=$dup"; exit 1; }
