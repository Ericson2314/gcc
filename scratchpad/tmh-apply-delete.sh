#!/bin/sh
# Delete the vestigial `#include "tm.h"' lines: the files that compile
# identically without them (probe.sh) AND have no preprocessor conditional on
# any macro `#define'd anywhere under config/ (cond2.sh).
#
# Two exclusions are applied on top of the VESTIGIAL verdict:
#   * the three files cond2.sh REVOKED;
#   * config/i386/driver-i386.cc and config/aarch64/driver-aarch64.cc, which
#     are NEEDS anyway -- listed here only so the list below is the complete
#     statement of what is being touched.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc"
L=$W/wk/delete-list.txt
awk '$1=="VESTIGIAL"{print $3}' "$W/wk/probe-results.txt" \
  | grep -v -x -e config/avr/avr-devices.cc \
               -e config/i386/i386-jit.cc \
               -e config/mingw/msformat-c.cc > "$L"
n=$(wc -l < "$L")
[ "$n" = 26 ] || { echo "FATAL: delete list is $n, expected 26"; exit 9; }
while read -r f; do
  grep -q '^#include "tm.h"' "$f" || { echo "FATAL: $f has no plain tm.h include"; exit 9; }
  sed -i '/^#include "tm\.h"$/d' "$f"
  ! grep -q '^#include "tm.h"' "$f" || { echo "FATAL: $f still has it"; exit 9; }
done < "$L"
echo "deleted from $n files"
