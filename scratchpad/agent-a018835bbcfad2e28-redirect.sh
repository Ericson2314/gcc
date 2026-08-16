#!/bin/sh
# agent-a018835bbcfad2e28-redirect.sh -- did the HAVE_* redirect actually
# reach the objects that read those macros?
#
# THE FAILURE THIS EXISTS FOR.  `multi-target-macros.h' arrives from the tail
# of `tm.h'.  A shared translation unit that reaches `rtl.h' WITHOUT `tm.h'
# first gets `rtl.h:3024-3055's `#ifndef HAVE_PRE_INCREMENT / #define 0'
# fallback instead of the redirect -- and the result is a compiler that builds,
# links, runs, and has auto-increment addressing switched off exactly as before.
# There is no undefined symbol and no diagnostic; the only observable is the
# absence of a CALL.
#
# So the test is the presence of `mt_have_autoinc' as an undefined symbol in
# each object that reads the eight.  `nm -u' and not `nm': the definition lives
# in target-cumargs-select.o and would satisfy a plain `nm' grep from the wrong
# side (PRINCIPLES: "an undefined symbol names the macro that DRAGGED IT IN").
#
# ARM 2 IS THE NON-VACUITY ARM and it is the load-bearing one: an object that
# does not read the macros at all must NOT show the symbol.  Without it a
# script that greps the whole build dir reports success for a redirect that
# reached nothing in particular.
#
# usage: [B=<builddir>] redirect.sh
set -u
B=${B:-/tmp/b-a018835bbcfad2e28}
[ -d "$B/gcc" ] || { echo "FATAL: no $B/gcc"; exit 9; }
W=$(cd "$(dirname "$0")/.." && pwd)

# `nm' is absent outside the nix dev shell, and a tool-not-found piped into
# `grep -c' scores 0 -- in the direction that looks clean.
command -v nm > /dev/null || { echo "FATAL: no nm on PATH; run under eb-shell.sh"; exit 9; }

# WHICH SYMBOL EACH OBJECT SHOULD CALL, AND THEY ARE NOT ALL THE SAME ONE.
#
# The first version asked for `mt_have_autoinc' in all four and reported
# `FAIL tree-ssa-loop-ivopts.o -- got rtl.h's fallback'.  It had not: ivopts
# does not spell the eight `HAVE_*' names at all, it spells the eight `USE_*'
# wrappers, and once those were redirected too it calls `mt_use_autoinc'.  The
# object was correct and the guard was asserting the shape of a half-finished
# change -- a false RED from the guard written to prevent a false green.
#
# So the expectation is per object, taken from what each file actually spells
# (-eight.sh counts the HAVE_* reads; USE_* reads are separate):
#   auto-inc-dec.cc  HAVE_* only
#   cse.cc           HAVE_* only
#   expr.cc          BOTH -- gcc_assert (HAVE_POST_INCREMENT) and the
#                    USE_{LOAD,STORE}_* pair at expr.cc:1299-1303
#   ivopts           USE_* only
WANT="auto-inc-dec.o:mt_have_autoinc cse.o:mt_have_autoinc
      expr.o:mt_have_autoinc expr.o:mt_use_autoinc
      tree-ssa-loop-ivopts.o:mt_use_autoinc"
# Objects that read none of the eight: the negative control.
NOT="tree-vect-generic.o gimple-fold.o"

rc=0
echo "-- ARM 1: every reader must CALL the selector it actually spells"
for pair in $WANT; do
  o=${pair%%:*}; sym=${pair##*:}
  p=$B/gcc/$o
  if [ ! -f "$p" ]; then echo "   FATAL: $o not built"; rc=9; continue; fi
  if nm -u "$p" 2>/dev/null | grep -q "$sym"; then
    echo "   ok   $o -> $sym"
  else
    echo "   FAIL $o does not call $sym, so it got rtl.h's"
    echo "        '#define HAVE_PRE_INCREMENT 0' / USE_* fallback"
    rc=1
  fi
done

echo "-- ARM 2 (non-vacuity): a non-reader must NOT call either"
seen=0
for o in $NOT; do
  p=$B/gcc/$o
  [ -f "$p" ] || continue
  seen=$((seen+1))
  if nm -u "$p" 2>/dev/null | grep -qE 'mt_have_autoinc|mt_use_autoinc'; then
    echo "   FAIL $o -- calls one, so ARM 1 proves nothing about placement"
    rc=1
  else
    echo "   ok   $o calls neither"
  fi
done
[ "$seen" -gt 0 ] || { echo "   FATAL: no control object present; ARM 1 is unfalsified"; rc=9; }

echo "REDIRECT rc=$rc"
exit $rc
