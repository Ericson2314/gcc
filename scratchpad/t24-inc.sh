#!/bin/sh
# Task #24 evidence: print cc1's system include search list, per target.
#
# Usage: t24-inc.sh <builddir> [extra cc1 args...]
# Environment: CFGDIR overrides where the specs-<target>-config files are read
# from (default <builddir>/gcc), so the AFTER cc1 can be driven with the
# BEFORE tree's config files and with edited copies.
#
# BOTH TARGETS, ALWAYS.  Showing one target's search list proves nothing about
# whether the entry is per-target: a value that is wrong for everybody and a
# value that is right for one look identical in a single column.
set -u
B=$1; shift
CFGDIR=${CFGDIR:-$B/gcc}
TMP=$(mktemp -d)
echo 'int x;' > "$TMP/e.c"
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  cfg="$CFGDIR/specs-$t-config"
  if [ ! -f "$cfg" ]; then
    echo "FATAL: no $cfg -- an absent config file is not an empty search list"
    exit 9
  fi
  echo "=== $B  target=$t"
  "$B/gcc/cc1" -quiet -v -ftarget-config="$cfg" "$@" "$TMP/e.c" -o "$TMP/e.s" \
    2>&1 | sed -n '/#include <\.\.\.>/,/End of search/p'
done
rm -rf "$TMP"
