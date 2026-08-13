#!/bin/sh
# THE FAILURE MODE A COMPILE CANNOT SEE.
#
# `#if FOO' and `#ifdef FOO' do not error when FOO is undefined -- they
# silently evaluate to false.  So a file that uses a tm.h macro ONLY inside a
# preprocessor conditional compiles cleanly with the include removed, scores
# VESTIGIAL, and has had its behaviour silently changed.  config/i386/i386-jit.cc
# (`#if TARGET_64BIT_DEFAULT') and config/mingw/msformat-c.cc
# (`#ifdef TARGET_OVERRIDES_FORMAT_INIT') are exactly that shape.
#
# So the compile verdict is not sufficient on its own.  Second instrument:
#
#   TMSET  = the macros tm.h contributes, by difference: -dM with the include
#            minus -dM without it.  Derived, not listed by hand.
#   COND   = every identifier appearing in a #if/#ifdef/#ifndef/#elif line of
#            a VESTIGIAL file.
#
# Any file with COND n TMSET non-empty is REVOKED from VESTIGIAL.  A file with
# an empty intersection has no conditional path that tm.h can move.
#
# Non-vacuity: TMSET must be large and must contain a name known to come from
# tm.h and not from anywhere else.  An empty TMSET would clear every file.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to YOUR OWN build dir -- never /tmp/b<task number>, which collides by construction}
tmpl () {
  grep -m1 -- "$1" "$W/wk/build.out" \
    | sed -e 's/ -o [^ ]*\.o / /' -e 's/ -MT [^ ]*//' -e 's/ -MMD -MP//' \
          -e 's/ -MF [^ ]*//' -e 's| /home[^ ]*\.cc$||'
}
CMD=$(tmpl '\-o mt-i386/linux\.o ')
cd "$D/gcc" || exit 9

cat > "$W/wk/u1.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
EOF
sed '/tm\.h/d' "$W/wk/u1.cc" > "$W/wk/u0.cc"
$CMD -E -dM "$W/wk/u1.cc" -o - 2> "$W/wk/u1.err" | awk '{print $2}' | sed 's/(.*//' | sort -u > "$W/wk/m1.txt"
$CMD -E -dM "$W/wk/u0.cc" -o - 2> "$W/wk/u0.err" | awk '{print $2}' | sed 's/(.*//' | sort -u > "$W/wk/m0.txt"
comm -23 "$W/wk/m1.txt" "$W/wk/m0.txt" > "$W/wk/tmset.txt"

n=$(wc -l < "$W/wk/tmset.txt")
echo "TMSET = $n macros contributed by tm.h"
[ "$n" -ge 200 ] || { echo "FATAL: TMSET is only $n -- the difference did not work"; exit 9; }
for probe in TARGET_64BIT_DEFAULT STACK_BOUNDARY; do
  grep -qx "$probe" "$W/wk/tmset.txt" \
    || { echo "FATAL: TMSET lacks $probe -- not measuring tm.h"; exit 9; }
done
grep -qx HAVE_STDLIB_H "$W/wk/tmset.txt" \
  && { echo "FATAL: TMSET contains a config.h macro -- the two runs differ by more than tm.h"; exit 9; }
echo "TMSET controls OK"
echo

awk '$1=="VESTIGIAL"{print $3}' "$W/wk/probe-results.txt" | while read -r f; do
  grep -E '^[ 	]*#[ 	]*(if|ifdef|ifndef|elif)' "$W/gcc/$f" \
    | grep -oE '[A-Za-z_][A-Za-z0-9_]*' | sort -u > "$W/wk/cond.txt"
  hit=$(comm -12 "$W/wk/cond.txt" "$W/wk/tmset.txt" | tr '\n' ' ')
  if [ -n "$hit" ]; then
    printf 'REVOKED  %-34s conditional on tm.h macro: %s\n' "$f" "$hit"
  else
    printf 'CLEAR    %s\n' "$f"
  fi
done
