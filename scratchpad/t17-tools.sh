#!/bin/sh
# Task #17: WHICH ld/nm/strip does collect2 look for, per target?
#
# Instrument: collect2 -debug turns on file-find's tracing, which prints one
# `Looking for 'NAME'' line per candidate.  That is the question being asked --
# the NAME collect2 searches for -- rather than which file happens to exist on
# this host, so the answer does not depend on any cross binutils being
# installed.  BLIND SPOT: it says nothing about the order the prefixes are
# searched in, only about the names.
#
# Usage: t17-tools.sh <builddir> <label>
set -u
B=$1; L=$2
TMP=$(mktemp -d)
: > "$TMP/empty.o"
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  cfg="$B/gcc/specs-$t-config"
  [ -f "$cfg" ] || { echo "FATAL: no $cfg"; exit 9; }
  names=$("$B/gcc/collect2" -debug -ftarget-config="$cfg" "$TMP/empty.o" 2>&1 \
          | sed -n "s/^Looking for '\(.*\)'$/\1/p" | sort -u | tr '\n' ' ')
  echo "$L  $t"
  echo "    names searched: $names"
done
rm -rf "$TMP"
