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

# The three target-independent readers, measured by -eight.sh, plus the two
# that reach the eight through rtl.h's USE_{LOAD,STORE}_* wrappers.
WANT="auto-inc-dec.o expr.o cse.o tree-ssa-loop-ivopts.o"
# Objects that read none of the eight: the negative control.
NOT="tree-vect-generic.o gimple-fold.o"

rc=0
echo "-- ARM 1: every reader must CALL mt_have_autoinc"
for o in $WANT; do
  p=$B/gcc/$o
  if [ ! -f "$p" ]; then echo "   FATAL: $o not built"; rc=9; continue; fi
  if nm -u "$p" 2>/dev/null | grep -q 'mt_have_autoinc'; then
    echo "   ok   $o"
  else
    echo "   FAIL $o -- reads the eight but does not call mt_have_autoinc,"
    echo "        so it got rtl.h's '#define HAVE_PRE_INCREMENT 0' fallback"
    rc=1
  fi
done

echo "-- ARM 2 (non-vacuity): a non-reader must NOT call it"
seen=0
for o in $NOT; do
  p=$B/gcc/$o
  [ -f "$p" ] || continue
  seen=$((seen+1))
  if nm -u "$p" 2>/dev/null | grep -q 'mt_have_autoinc'; then
    echo "   FAIL $o -- calls it, so ARM 1 proves nothing about placement"
    rc=1
  else
    echo "   ok   $o does not call it"
  fi
done
[ "$seen" -gt 0 ] || { echo "   FATAL: no control object present; ARM 1 is unfalsified"; rc=9; }

echo "REDIRECT rc=$rc"
exit $rc
