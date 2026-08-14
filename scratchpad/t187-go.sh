#!/bin/sh
# #187 -- drive one arm end to end: configure 47 bases from the immutable
# snapshot, then build.  Snapshot is made separately (t176-snap.sh).
set -e
S=$(cd "$(dirname "$0")" && pwd)
export WANT_ANCHOR=${WANT_ANCHOR:?set WANT_ANCHOR}
SNAP=${SNAP:-/tmp/snap-agent-a85d505af66ec2223}
D=${D:-/tmp/b-agent-a85d505af66ec2223}
LIST=$(grep -v '^#' "$S/backends-47.txt" | grep -v '^$' | paste -sd, -)
[ "$(echo "$LIST" | tr ',' '\n' | wc -l)" = 47 ] \
  || { echo "FATAL: base list is not 47"; exit 9; }
SRC=$SNAP sh "$S/t187-conf.sh" "$D" "$LIST"
sh "$S/t187-topbuild.sh" "$D"
