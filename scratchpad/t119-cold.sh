#!/bin/sh
# #119 -- a COLD two-backend all-gcc from an empty directory, with this task's
# edits in.  Separate from /tmp/b119, which is incremental by now.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=/tmp/b119c PFX=/tmp/b119c-inst
export B PFX
sh "$S/t119-conf.sh" || exit 1
TAG=coldgcc B=$B sh "$S/t119-build.sh" all-gcc
