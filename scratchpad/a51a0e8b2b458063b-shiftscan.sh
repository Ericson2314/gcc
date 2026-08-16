#!/bin/sh
# Report, per build dir: base count and the maximum AARCH64_APPROX_MODE shift.
for d in /tmp/b-*/; do
  h="$d/gcc/insn-modes.h"
  [ -f "$h" ] || continue
  nb=$(ls "$d"/gcc/insn-modes-inline-*.h 2>/dev/null | wc -l)
  ord=$(sed -n '/^enum machine_mode$/,/^};/p' "$h" | grep -o '^  E_[A-Za-z0-9_]*mode' | sed 's/  E_//' | cat -n)
  get () { printf '%s\n' "$ord" | awk -v n="$1" '$2==n {print $1-1; exit}'; }
  nm () { grep -m1 "  $1 = E_" "$h" | sed 's/.* = E_//; s/,.*//'; }
  mnf=$(get "$(nm MIN_MODE_FLOAT)"); mxf=$(get "$(nm MAX_MODE_FLOAT)")
  mnv=$(get "$(nm MIN_MODE_VECTOR_FLOAT)"); mxv=$(get "$(nm MAX_MODE_VECTOR_FLOAT)")
  [ -n "$mnf" ] && [ -n "$mxv" ] || { echo "$d bases=$nb  UNPARSED"; continue; }
  nf=$((mxf - mnf + 1))
  maxshift=$((mxv - mnv + nf))
  echo "$d bases=$nb float=$nf vecfloat=$((mxv-mnv+1)) MAXSHIFT=$maxshift"
done
