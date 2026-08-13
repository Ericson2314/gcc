#!/bin/sh
# Reconfigure gcc/ IN PLACE in an existing build dir, so the before/after arms
# are the same directory and differ only by the change under test.
#
# --recheck is mandatory: config.status re-uses cached substitutions, and
# gen-target-manifest.sh is RUN BY configure, so a plain config.status would
# re-emit the old manifest and the build would look unchanged for the wrong
# reason.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D configured from '$got', not $SRC"; exit 9; }
sh "$S/eb-shell.sh" "cd $D/gcc && ./config.status --recheck && ./config.status"
echo "RECONF-RC=$?"
