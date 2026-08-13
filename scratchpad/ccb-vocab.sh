#!/bin/sh
# Extract the textual body of every `#define TARGET_CPU_CPP_BUILTINS' under
# gcc/config/ and report the identifiers each one names, per back end.
#
# This is a SOURCE sweep, deliberately independent of the build: a
# diagnostic-driven sweep only sees the copies some configured triple
# compiles (PRINCIPLES section 4 rule 6).  It is also deliberately
# over-broad -- it cannot authorise anything, only point at names to check.
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "${n:-0}" = "${WANT_ANCHOR:-45}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
cd "$SRC/gcc/config"
files=$(grep -rl 'define TARGET_CPU_CPP_BUILTINS' . | sort)
[ -n "$files" ] || { echo "FATAL: no definitions found"; exit 9; }
for f in $files; do
  awk -v F="$f" '
    /define[ \t]+TARGET_CPU_CPP_BUILTINS/ { inb = 1 }
    inb { print F "\t" $0; if ($0 !~ /\\[ \t]*$/) inb = 0 }
  ' "$f"
done
