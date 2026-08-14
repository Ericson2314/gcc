#!/bin/sh
# Task #160: for each macro name given, say which layer currently defines it:
#   MTM             gcc/multi-target-macros.h -- the neutral conversion layer,
#                   reachable without tm.h once a header includes it;
#   defaults.h      still only on the tm.h tail;
#   NEITHER         supplied by the back end's own header chain alone.
# usage: t160-where.sh <name>...
set -e
G=$(cd "$(dirname "$0")/../gcc" && pwd)
for n in "$@"; do
  printf '%-40s' "$n"
  if grep -qE "^#[ 	]*define[ 	]+$n\b" "$G/multi-target-macros.h"; then echo MTM
  elif grep -qE "^#[ 	]*define[ 	]+$n\b" "$G/defaults.h"; then echo defaults.h
  else echo NEITHER; fi
done
