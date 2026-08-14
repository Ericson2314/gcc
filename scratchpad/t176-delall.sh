#!/bin/sh
# #176 -- apply t176-delete.sh to a named result list from the sweep.
set -e
S=$(cd "$(dirname "$0")" && pwd)
W=/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad
L=${1:?list file under the work dir, e.g. del.txt}
exec sh "$S/t176-delete.sh" $(cat "$W/$L")
