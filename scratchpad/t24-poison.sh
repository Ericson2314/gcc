#!/bin/sh
# Task #24, THE ARM THAT MATTERS: does the compiler actually FIND a header that
# exists only in <prefix>/include -- the host's own directory -- when compiling
# for each target?
#
# `cc1 -v' is not enough on its own: it prints only directories that exist, and
# on this host none of the built-in ones do, so both arms print an empty list
# and prove nothing.  This asks the question the search path exists to answer.
#
# Usage: t24-poison.sh <builddir> [label]
# Exit status is ignored on purpose; read the per-target verdicts.
set -u
B=$1
L=${2:-$B}
TMP=$(mktemp -d)
printf '#include <t24poison.h>\nint f (void) { return T24_POISON_HOST_HEADER; }\n' > "$TMP/e.c"
[ -f /tmp/include/t24poison.h ] || {
  echo "FATAL: /tmp/include/t24poison.h missing -- a test for a header that"
  echo "is not there cannot distinguish 'not found' from 'nothing to find'"
  exit 9
}
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  cfg="$B/gcc/specs-$t-config"
  [ -f "$cfg" ] || { echo "FATAL: no $cfg"; exit 9; }
  if "$B/gcc/cc1" -quiet -ftarget-config="$cfg" -fsyntax-only "$TMP/e.c" \
       > "$TMP/o" 2> "$TMP/e"; then
    echo "$L  $t: FOUND /tmp/include/t24poison.h  <-- host header reached"
  else
    echo "$L  $t: not found ($(head -1 "$TMP/e"))"
  fi
done
rm -rf "$TMP"
