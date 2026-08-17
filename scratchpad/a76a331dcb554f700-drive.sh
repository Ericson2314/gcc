#!/bin/sh
# a76a331dcb554f700 -- configure + build the 47-base tree from the snapshot.
# Run under `setsid nohup'.  MT_MAKEFLAGS unset silently means -j1, so it is
# asserted here rather than remembered.
set -eu
S=$(cd "$(dirname "$0")" && pwd)
SRC=${SRC:?set SRC to the snapshot}
D=${D:?set D to the build dir}
: "${MT_MAKEFLAGS:?MT_MAKEFLAGS unset means -j1 -- set it explicitly}"
export MT_MAKEFLAGS
A=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
echo "anchor=$A src=$SRC build=$D jobs=$MT_MAKEFLAGS"
SRC="$SRC" WANT_ANCHOR="$A" sh "$S/tb1-conf47.sh" "$D"
WANT_ANCHOR="$A" sh "$S/mt-build.sh" "$D" all-gcc all-gcc
echo "DRIVE-DONE rc=0"
