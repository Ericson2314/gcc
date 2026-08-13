#!/bin/sh
# Re-run config.status at the top level and in gcc/ after a Makefile.in edit.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b119}
sh "$S/eb-shell.sh" "cd $B && ./config.status Makefile && cd gcc && ./config.status Makefile"
echo "rc=$?"
