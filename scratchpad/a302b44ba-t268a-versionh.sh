#!/bin/sh
# #268 ARM A, THE FALSIFIABLE HALF -- AND IT FALSIFIES.
#
# Arm A (`8bbcd3ee5ae') removed `version.h' from the installed per-target header
# set on static grounds: "the only file under libgcc/ that includes version.h is
# libgcov-util.c, and that is compiled into the HOST tool gcov-tool
# (gcc/Makefile.in:5883,5891), not into libgcc".  BOTH HALVES OF THAT SENTENCE
# ARE TRUE.  The conclusion does not follow, because the include that matters is
# not under libgcc/ at all:
#
#     libgcc/libgcov.h:191   #include "gcov-io.h"
#     gcc/gcov-io.h:240      #include "version.h"
#
# and libgcc reaches gcc/ through `-I$(srcdir)/../gcc' in Makefile.in's
# INCLUDES.  Every _gcov_* object -- LIBGCOV_MERGE, LIBGCOV_PROFILER,
# LIBGCOV_INTERFACE, LIBGCOV_DRIVER (libgcc/Makefile.in:946,948,960,964) --
# includes libgcov.h and therefore opens version.h.
#
# `grep -rn version.h libgcc/' CANNOT SEE THIS.  It finds libgcov-util.c:34 and
# gthr-vxworks.h:312 and nothing else, which is exactly the evidence arm A had.
# The file libgcc actually opens it from lives in gcc/.  That is the shape of
# the miss and it is worth stating: scoping a dependency question by SOURCE
# DIRECTORY gets the wrong answer whenever one component compiles against
# another's headers -- which is the entire relationship between libgcc and gcc.
#
# METHOD: BUILD IT BOTH WAYS AND COMPARE ONE OBJECT.
#
# A single-TU `-fsyntax-only' probe was tried first and could NOT answer: it
# stops earlier, on `auto-target.h' (libgcc's own configure output) and then on
# `stdio.h' (the target sysroot), so neither arm ever reaches version.h and both
# fail identically.  That is a null result that looks like a measurement, so it
# is not used.  What works is the real standalone build, twice, differing ONLY
# in whether version.h is installed, compared on a SPECIFIC OBJECT rather than
# on the exit status -- because the build stops for an unrelated sysroot reason
# in both arms, and an exit status would report that instead.
#
# usage: LIBGCC_A=<builddir-without> LIBGCC_B=<builddir-with> \
#        a302b44ba-t268a-versionh.sh <logdir>
#
# Produce those two build dirs with scratchpad/a7b00-standalone-libgcc.sh
# against one install prefix, removing and restoring
#   <prefix>/lib/gcc/<ver>/<triple>/include/version.h
# between the runs and changing NOTHING else.
set -u
A=${LIBGCC_A:?build dir from the run WITHOUT version.h}
B=${LIBGCC_B:?build dir from the run WITH version.h}
LOGS=${1:?log dir}
OBJ=_gcov_merge_add.o

fail=0
say () { printf '  %-52s %s\n' "$1" "$2"; }

# THE OBJECT.  Present in one arm and absent in the other is the whole claim.
if [ -f "$B/$OBJ" ]; then say "WITH version.h:    $OBJ" "BUILT ($(wc -c < "$B/$OBJ") bytes)"
else say "WITH version.h:    $OBJ" "*** ABSENT"; fail=1; fi
if [ -f "$A/$OBJ" ]; then say "WITHOUT version.h: $OBJ" "*** BUILT -- claim not shown"; fail=1
else say "WITHOUT version.h: $OBJ" "absent, as predicted"; fi

# AND THE REASON MUST BE version.h, not some other breakage.  An object missing
# for an unrelated cause would satisfy the test above while proving nothing.
if grep -q "version\.h: No such file" "$LOGS/lg-without.log" 2>/dev/null; then
  say "WITHOUT: error names version.h" "yes"
  grep -m1 "version\.h: No such file" "$LOGS/lg-without.log" | sed 's/^/      /'
else
  say "WITHOUT: error names version.h" "*** NO -- the absence has another cause"; fail=1
fi
if grep -q "version\.h: No such file" "$LOGS/lg-with.log" 2>/dev/null; then
  say "WITH: error names version.h" "*** YES -- the arms are not distinguished"; fail=1
else
  say "WITH: error names version.h" "no, as it must not"
fi

# NON-VACUITY ON THE PAIR: the two builds must have differed only here, so BOTH
# must have got far enough to compile gcov objects at all.
for d in "$A" "$B"; do
  [ -f "$d/Makefile" ] || { echo "FATAL: $d never configured; the pair is not comparable"; exit 9; }
done

echo
if [ "$fail" = 0 ]; then
  echo "RESULT: version.h IS a libgcc input.  Arm A's removal is REFUTED."
  echo "        Chain: libgcc/libgcov.h:191 -> gcc/gcov-io.h:240 -> version.h"
  exit 1
fi
echo "RESULT: not established -- see the starred lines above."
exit 0
