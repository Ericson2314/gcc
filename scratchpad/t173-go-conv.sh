#!/bin/sh
# #173 -- configure the AFTER build dir (280 sites converted) from the
# conversion snapshot, 47 back ends, same list as the baseline.
set -e
S=$(cd "$(dirname "$0")" && pwd)
export SRC=/tmp/snap-a7d1e0-conv
export WANT_ANCHOR=55
L=$(grep -v '^#' "$S/backends-47.txt" | grep -v '^$' | tr '\n' ',' | sed 's/,$//')
sh "$S/t173-conf.sh" /tmp/b-a7d1e0-conv "$L"
