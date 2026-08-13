#!/bin/sh
# Convert the surviving config/ tm.h includes to BASE_HEADER (tm.h).
#
# Population: the 21 NEEDS files, plus the 3 that probe.sh scored VESTIGIAL and
# cond2.sh revoked, minus the two DRIVER objects.  The drivers are excluded
# because they are compiled ONCE, shared, with no -DMT_BASE and no
# -I<base>-inc (measured: `-o driver-i386.o' carries neither), so
# multi-target-base.h would #error on them.  That is a design question, not a
# mechanical conversion; see the report.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc"
L=$W/wk/base-list.txt
{ awk '$1=="NEEDS"{print $3}' "$W/wk/probe-results.txt"
  echo config/avr/avr-devices.cc
  echo config/i386/i386-jit.cc
  echo config/mingw/msformat-c.cc
} | grep -v -x -e config/i386/driver-i386.cc \
               -e config/aarch64/driver-aarch64.cc | sort > "$L"
n=$(wc -l < "$L")
[ "$n" = 22 ] || { echo "FATAL: base list is $n, expected 22"; exit 9; }

while read -r f; do
  grep -q '^#include "tm.h"' "$f" || { echo "FATAL: $f has no plain tm.h include"; exit 9; }
  awk '
    /^#include "tm\.h"$/ && !done {
      print "/* Compiled once per configured back end: name the back end'"'"'s own"
      print "   tm.h rather than relying on -I<base>-inc.  See multi-target-base.h.  */"
      print "#include \"multi-target-base.h\""
      print "#include BASE_HEADER (tm.h)"
      done = 1
      next
    }
    { print }
  ' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
  grep -q '^#include BASE_HEADER (tm.h)$' "$f" || { echo "FATAL: $f not converted"; exit 9; }
  ! grep -q '^#include "tm.h"' "$f" || { echo "FATAL: $f still has a plain include"; exit 9; }
done < "$L"
echo "converted $n files"
