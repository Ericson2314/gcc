#!/bin/sh
# #49 -- THE COMPILE ARM, done surgically because a full patched 48-back-end
# build is contended to uselessness (load average 51, five concurrent -j8
# makes from other agents on this host).
#
# The both-sided preprocessing arm (t49-verify.sh) proves what the MACROS
# become.  It does not prove that `rs6000.cc' still COMPILES once the guards
# are taken -- and this change turns on code that has never been compiled in
# this tree: `TARGET_CMODEL' becomes `rs6000_current_cmodel' and `DOT_SYMBOLS'
# becomes `dot_symbols', both previously unreachable.
#
# So: take the BASELINE build dir, which already has every rs6000 generated
# header and a known-good `mt-rs6000/rs6000.o'; apply the two prologue blocks
# to its `tm-rs6000.h' exactly as mkconfig.sh now emits them; recompile that
# one object with the build's OWN command line, lifted from its log; and
# require BOTH that it compiles AND that the object CHANGES.
#
# A compile that succeeds and produces a byte-identical object would mean the
# change is inert and the whole finding is wrong.
#
# The original header and object are saved and restored, so the baseline stays
# usable as a baseline.
#
# usage: t49-compile.sh <baseline-builddir>
set -u
B=${1:?baseline build dir}
case "$B" in
  */b-ad1798a2b26398cc6*) ;;
  *) echo "FATAL: $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(grep -m1 -o '/tmp/snap-[a-z0-9]*' "$B/config.log")
H="$G/tm-rs6000.h"
O="$G/mt-rs6000/rs6000.o"
[ -f "$H" ] || { echo "FATAL: $H missing"; exit 9; }
[ -f "$O" ] || { echo "FATAL: $O missing -- the baseline never built it, so there is nothing to compare"; exit 9; }

# Non-vacuity: the baseline must NOT already have the fix, or the two sides
# are not distinct.
if grep -q HAVE_LD_LARGE_TOC "$H"; then
  echo "FATAL: baseline tm-rs6000.h already defines HAVE_LD_LARGE_TOC; not a baseline"; exit 9
fi
echo "baseline srcdir $SRC; object $(wc -c < "$O") bytes"

cp "$H" "$H.t49-orig"; cp "$O" "$O.t49-orig"
restore () { mv -f "$H.t49-orig" "$H"; mv -f "$O.t49-orig" "$O"; echo "(baseline restored)"; }

# Insert the two blocks where mkconfig.sh puts them: ahead of the target
# headers, i.e. before the `#ifdef IN_GCC' line.
awk '/^#ifdef IN_GCC$/ && !done {
       print "#ifndef HAVE_LD_LARGE_TOC";  print "# define HAVE_LD_LARGE_TOC 1";  print "#endif";
       print "#ifndef HAVE_LD_NO_DOT_SYMS"; print "# define HAVE_LD_NO_DOT_SYMS 1"; print "#endif";
       done=1 } { print }' "$H.t49-orig" > "$H"
# TWO lines per block -- the `#ifndef' and the `# define'.  Asserting 1 here
# was wrong and the guard refused a CORRECT injection, which is the right
# direction for an assert to fail in.
n=$(grep -c 'HAVE_LD_LARGE_TOC' "$H")
[ "$n" = 2 ] || { echo "FATAL: injection produced $n HAVE_LD_LARGE_TOC lines, expected 2"; restore; exit 9; }
m=$(grep -c 'HAVE_LD_NO_DOT_SYMS' "$H")
[ "$m" = 2 ] || { echo "FATAL: injection produced $m HAVE_LD_NO_DOT_SYMS lines, expected 2"; restore; exit 9; }
echo "injected the two prologue blocks ahead of #ifdef IN_GCC"

# TAKE THE WHOLE LINE.  A `grep -o' with a trailing `[^ ]*' stopped at `-MMD'
# and dropped the source file, giving `g++: fatal error: no input files' --
# which reads as "the change does not build" and is really "the harness built
# a truncated command".  Exactly the shape PRINCIPLES warns about: the failure
# named a real tool and a plausible cause.
CMD=$(grep -m1 '\-o mt-rs6000/rs6000\.o' "$B/b48.out")
[ -n "$CMD" ] || { echo "FATAL: could not lift the compile command from b48.out"; restore; exit 9; }
case "$CMD" in
  *rs6000.cc) ;;
  *) echo "FATAL: lifted command does not end in rs6000.cc; it is truncated:"; echo "  ...$(echo "$CMD" | tail -c 60)"; restore; exit 9 ;;
esac
rm -f "$O"
sh "$S/eb-shell.sh" "cd $G && $CMD" > "$B/t49-compile.out" 2> "$B/t49-compile.err"
rc=$?
echo "recompile rc=$rc"
if [ "$rc" != 0 ]; then
  echo "COMPILE FAILED -- the change does not build.  First errors:"
  grep -m5 'error:' "$B/t49-compile.err"
  restore; exit 1
fi
[ -f "$O" ] || { echo "FATAL: rc=0 but no object produced"; restore; exit 9; }
echo "new object $(wc -c < "$O") bytes"
if cmp -s "$O" "$O.t49-orig"; then
  echo "== MUST-MOVE FAILED: object byte-identical.  The change is INERT."
  restore; exit 1
else
  echo "== MUST-MOVE PASS: object differs ($(wc -c < "$O.t49-orig") -> $(wc -c < "$O") bytes)"
fi
echo "== warnings introduced:"
grep -c 'warning:' "$B/t49-compile.err" || true
restore
