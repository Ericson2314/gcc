#!/bin/sh
# #137 -- WHICH OF THE `UNCONVERTED' MACROS ARE ALREADY CONVERTED THROUGH A
# CHANNEL THE COMPLETENESS GATE CANNOT SEE.
#
# `macro-probe.sh' derives the converted set from `defaults.h''s redirect block
# plus a hand-declared `CONVERTED_NO_REDIRECT' list.  That covers exactly two
# channels.  It is blind to at least two more, and this script names them:
#
#   GEN  the genmodes UNION.  `MAX_BITSIZE_MODE_ANY_MODE' is computed as the
#        maximum over every configured back end and written into the ONE shared
#        `insn-modes.h'.  There is no `#undef' in defaults.h and no `mt_'
#        thunk, so the gate scores it UNCONVERTED -- and the board has said so
#        while the conversion was landed and working.
#   MT   an `mt_*' thunk in `target-frame.h'/`target-cumargs.cc' without a
#        defaults.h redirect.
#
# THIS IS THE BRANCH'S OWN ROOT PATTERN AIMED AT THE INSTRUMENT, for the second
# time: `macro-status.txt' already records that an absent macro was counted in
# no column at all.  The same defect in the other direction -- a CONVERTED
# macro counted as unconverted -- sends agents to convert what is already
# converted, which is exactly what the `CONVERTED_NOARM' status was invented to
# stop.
#
# It reports a SUSPICION, not a verdict: a hit means "this name is spelled by
# multi-target machinery", which must then be confirmed against the built
# artefact (for the mode union: the value in the build dir's insn-modes.h).
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)/gcc
[ "$(grep -c MULTI_TARGET "$SRC/Makefile.in")" -ge 39 ] || { echo "FATAL: wrong tree"; exit 9; }
LIST=${1:-$S/t137-unconverted.txt}
[ -s "$LIST" ] || { echo "FATAL: no list"; exit 9; }

# Positive control: a macro KNOWN to be redirected in defaults.h must show
# def>0, or the grep is dead and every 0 below is the instrument, not the code.
c=$(grep -c 'PUSH_ARGS_REVERSED' "$SRC/defaults.h")
[ "$c" -gt 0 ] || { echo "FATAL: control PUSH_ARGS_REVERSED absent from defaults.h"; exit 9; }

while read -r m; do
  [ -n "$m" ] || continue
  d=$(grep -cw "$m" "$SRC/defaults.h")
  g=$(grep -cw "$m" "$SRC/genmodes.cc")
  t=$(cat "$SRC/target-frame.h" "$SRC/target-cumargs.cc" 2>/dev/null | grep -cw "$m")
  [ "$d" = 0 ] && [ "$g" = 0 ] && [ "$t" = 0 ] && continue
  printf '%-34s defaults.h=%-3s genmodes=%-3s target-frame/cumargs=%s\n' "$m" "$d" "$g" "$t"
done < "$LIST"
