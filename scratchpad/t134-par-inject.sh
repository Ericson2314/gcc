#!/bin/sh
# #134 -- INJECTION ARM for `PUSH_ARGS_REVERSED'.  Removes ONLY the defaults.h
# redirect, so shared code falls back to the definition defaults.h itself made
# a thousand lines above -- which is i386.h:1658's `1' for every target.  That
# is exactly the pre-#134 state.  The struct field, both per-base thunks and
# the selector all stay, so this is the redirect and nothing else.
#
# `sed' and NOT python3 (not in the dev shell; an injection written in it does
# nothing while every downstream reading is of the UNMODIFIED compiler).
#
# The assertions match the `#undef' and the `#define' LINES, not the symbol
# name: #133 recorded that an assertion on a symbol name also matches the
# PROSE about the symbol, and these files are mostly prose.  Here the comment
# above the redirect names `mt_push_args_reversed' twice.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
F=$G/defaults.h
MODE=${1:?usage: t134-par-inject.sh off|on}

case $MODE in
  off)
    [ -f "$S/t134-par-defaults.h.orig" ] && { echo "REFUSE: a saved original already exists"; exit 9; }
    cp "$F" "$S/t134-par-defaults.h.orig"
    sed -e 's|^#undef PUSH_ARGS_REVERSED$|/* T134-PAR-INJECTED-OFF: #undef removed */|' \
        -e 's|^#define PUSH_ARGS_REVERSED (mt_push_args_reversed ())$|/* T134-PAR-INJECTED-OFF: redirect removed */|' \
        "$S/t134-par-defaults.h.orig" > "$F"
    ;;
  on)
    [ -f "$S/t134-par-defaults.h.orig" ] || { echo "REFUSE: no saved original"; exit 9; }
    cp "$S/t134-par-defaults.h.orig" "$F"
    rm -f "$S/t134-par-defaults.h.orig"
    ;;
  *) echo "usage: t134-par-inject.sh off|on"; exit 9;;
esac

# ASSERT THE STATE, both halves, both directions.  Note the `#undef' count is
# taken over the WHOLE file: defaults.h has two `#ifndef PUSH_ARGS_REVERSED'
# guards of its own at :915 and :926 and neither is an `#undef', so a nonzero
# count here can only be the redirect.
u=$(grep -c '^#undef PUSH_ARGS_REVERSED$' "$F")
d=$(grep -c '^#define PUSH_ARGS_REVERSED (mt_push_args_reversed ())$' "$F")
m=$(grep -c 'T134-PAR-INJECTED-OFF' "$F")
echo "mode=$MODE  #undef=$u  #define=$d  markers=$m"
case $MODE in
  off) [ "$u" = 0 ] && [ "$d" = 0 ] && [ "$m" = 2 ] || { echo "FAIL: injection did not produce the intended state"; exit 9; } ;;
  on)  [ "$u" = 1 ] && [ "$d" = 1 ] && [ "$m" = 0 ] || { echo "FAIL: restore did not produce the intended state"; exit 9; } ;;
esac
echo "state OK"
