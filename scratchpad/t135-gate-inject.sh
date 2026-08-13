#!/bin/sh
# #135 -- inject the PRE-CONVERSION state of `combine-stack-adj.cc''s gate and
# put it back, in the SAME build dir, so the before/after is one comparison
# and not two builds.
#
# The pre-#135 source is `#ifndef PUSH_ROUNDING' around the early return, and
# with i386 as the primary that preprocesses to NOTHING.  So the faithful
# injection is to make the condition unconditionally false -- which is what
# the primary's answer did to every target.
#
# $1 = off | on.  The STATE IS ASSERTED IN BOTH DIRECTIONS, against the LINE
# and not against the symbol name: #133 recorded that a name assertion also
# matches the PROSE about the symbol, and this file is full of prose about it.
# `python3' is NOT in the dev shell; this is sed.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
F=$SRC/gcc/combine-stack-adj.cc
# NO `/*' IN EITHER SED PATTERN.  The first version of this script marked the
# injected line with a trailing `/* INJECTED */' comment; `\/*' in a sed
# REGEX means "zero or more slashes", so the injection applied cleanly and the
# RESTORE then failed to match its own marker.  The refusal caught it -- but
# only because the restore asserts its result; a restore written to assert
# nothing would have left the injected state in the tree and every later
# reading would have been of the pre-#135 compiler.
ON='  if (!mt_has_push_rounding () \&\& ACCUMULATE_OUTGOING_ARGS)'
OFF='  if (false \&\& ACCUMULATE_OUTGOING_ARGS) \/\/ INJECTED pre-135'
ONP='if (!mt_has_push_rounding () && ACCUMULATE_OUTGOING_ARGS)'
OFFP='if (false && ACCUMULATE_OUTGOING_ARGS) // INJECTED pre-135'

has () { grep -c -F -- "$1" "$F"; }

case ${1:-} in
  off)
    [ "$(has "$ONP")" = 1 ] || { echo "FATAL: converted line not found exactly once (found $(has "$ONP")); refusing"; exit 9; }
    sed -i "s/$ON/$OFF/" "$F"
    [ "$(has "$OFFP")" = 1 ] && [ "$(has "$ONP")" = 0 ] \
      || { echo "FATAL: injection did not produce the intended state"; exit 9; }
    echo "injected OFF (pre-#135): gate condition is now unconditionally false"
    ;;
  on)
    [ "$(has "$OFFP")" = 1 ] || { echo "FATAL: injected line not found exactly once (found $(has "$OFFP")); refusing"; exit 9; }
    sed -i "s/$OFF/$ON/" "$F"
    [ "$(has "$ONP")" = 1 ] && [ "$(has "$OFFP")" = 0 ] \
      || { echo "FATAL: restore did not produce the intended state"; exit 9; }
    echo "restored ON (#135)"
    ;;
  *) echo "usage: $0 off|on"; exit 2;;
esac
