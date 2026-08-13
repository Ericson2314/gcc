#!/bin/sh
# stock-compare against genuine upstream, for the dir named in $1.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
MT=${1:?build dir}
export MT
export IN="$SRC/scratchpad/big.c"
export OUT=${2:-/tmp/rs6k-stockcmp}
exec bash "$S/stock-compare.sh"
