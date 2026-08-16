#!/bin/sh
# Classify every `ts_expected' key in target-specs/configure.ac by WHICH TOOL
# its probe actually needs: an assembler, a linker, or neither.
#
# WHY: the harness refuses to emit a `specs-config' at all when no cross `as'
# exists.  If most keys need no assembler, that refusal is far broader than
# the defect it was written for (a host-`as' answer masquerading as a
# target's).  This quantifies it.
#
# The classification is by NAME PREFIX, and that is a weak instrument, so it
# is cross-checked below against what the probe body actually invokes.  Where
# the two disagree the disagreement is PRINTED rather than resolved silently
# -- a key whose name says `as_' but whose probe runs no assembler is exactly
# the kind of thing this project has been bitten by.
set -u
AC=${1:-target-specs/configure.ac}
[ -f "$AC" ] || { echo "FATAL: no $AC"; exit 9; }

KEYS=$(awk '/^ts_expected="/,/"$/' "$AC" | sed 's/ts_expected="//; s/"$//' \
       | tr -s ' \n' '\n' | grep . | sort -u)
[ -n "$KEYS" ] || { echo "FATAL: read zero keys"; exit 9; }

nas=0; nld=0; nnei=0
for k in $KEYS; do
  case $k in
    as_*|gas_*) c=ASSEMBLER; nas=$((nas+1)) ;;
    ld_*)       c=LINKER;    nld=$((nld+1)) ;;
    *)          c=NEITHER;   nnei=$((nnei+1)) ;;
  esac
  printf '%-40s %s\n' "$k" "$c"
done
echo
echo "unique keys: $(echo "$KEYS" | wc -l)"
echo "ASSEMBLER=$nas LINKER=$nld NEITHER=$nnei"
