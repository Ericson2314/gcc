#!/bin/sh
# For each helper named by a `TARGET_CPU_CPP_BUILTINS' body, report every
# header under gcc/config/ that declares it, so that a GUARDED declaration
# (the `rs6000_gnu_attr' shape: `#ifdef TREE_CODE') is visible as such.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
cd "$SRC/gcc"
for n in "$@"; do
  printf '%s\n' "== $n"
  grep -rn "$n" config --include='*.h' || echo "   (no header declares it)"
done
