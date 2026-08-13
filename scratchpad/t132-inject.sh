#!/bin/sh
# #132 -- INJECTION ARM.  Removes ONLY the defaults.h redirect of
# ACCUMULATE_OUTGOING_ARGS, so shared code goes back to reading i386.h:1647
# out of the selected base's `machine_function'.  Everything else -- the
# struct member, the two per-base thunks, the selector -- stays, so this is
# the redirect and nothing else.
#
# `sed'/`awk' and NOT python3: python3 is not in the dev shell and an
# injection written in it does NOTHING while every downstream reading is of
# the UNMODIFIED compiler (PRINCIPLES).  And the state is ASSERTED in both
# directions rather than the exit status being trusted.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
F=$G/defaults.h
MODE=${1:?usage: t132-inject.sh off|on}

case $MODE in
  off)
    [ -f "$S/t132-defaults.h.orig" ] && { echo "REFUSE: a saved original already exists"; exit 9; }
    cp "$F" "$S/t132-defaults.h.orig"
    sed -e 's|^#undef ACCUMULATE_OUTGOING_ARGS$|/* T132-INJECTED-OFF: #undef ACCUMULATE_OUTGOING_ARGS */|' \
        -e 's|^#define ACCUMULATE_OUTGOING_ARGS (mt_accumulate_outgoing_args ())$|/* T132-INJECTED-OFF: redirect removed */|' \
        "$S/t132-defaults.h.orig" > "$F"
    ;;
  on)
    [ -f "$S/t132-defaults.h.orig" ] || { echo "REFUSE: no saved original"; exit 9; }
    cp "$S/t132-defaults.h.orig" "$F"
    rm -f "$S/t132-defaults.h.orig"
    ;;
  *) echo "usage: t132-inject.sh off|on"; exit 9;;
esac

# ASSERT THE STATE, both halves, both directions.
u=$(grep -c '^#undef ACCUMULATE_OUTGOING_ARGS$' "$F")
d=$(grep -c '^#define ACCUMULATE_OUTGOING_ARGS (mt_accumulate_outgoing_args ())$' "$F")
m=$(grep -c 'T132-INJECTED-OFF' "$F")
echo "mode=$MODE  #undef=$u  #define=$d  markers=$m"
case $MODE in
  off) [ "$u" = 0 ] && [ "$d" = 0 ] && [ "$m" = 2 ] || { echo "FAIL: injection did not produce the intended state"; exit 9; } ;;
  on)  [ "$u" = 1 ] && [ "$d" = 1 ] && [ "$m" = 0 ] || { echo "FAIL: restore did not produce the intended state"; exit 9; } ;;
esac
echo "state OK"
