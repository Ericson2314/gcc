#!/bin/sh
# #173 -- configure the BASELINE 47-back-end build dir from the base snapshot.
set -e
S=$(cd "$(dirname "$0")" && pwd)
export SRC=/tmp/snap-a7d1e0-base
export WANT_ANCHOR=55
L=$(grep -v '^#' "$S/backends-47.txt" | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
sh "$S/t173-conf.sh" /tmp/b-a7d1e0-base "$L"
