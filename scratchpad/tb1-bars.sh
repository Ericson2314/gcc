#!/bin/sh
# The recorded bars, measured on THIS four-base build, with the command that
# produced each (PRINCIPLES: quote the artefact and the command, never a bare
# byte count).  x86_64 -O2 big.c is the branch's strongest regression detector
# and is documented as no longer base-count dependent; this is the four-base
# reading of it.
set -u
B=${B:?build dir}
S=$(cd "$(dirname "$0")" && pwd)
VER=17.0.0
W=$B/bars; rm -rf "$W"; mkdir -p "$W"
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  C="$B/lib/gcc/$VER/$T/specs-config"
  printf '%-28s specs-config wc -l %s md5 %s\n' "$T" "$(wc -l < "$C")" \
    "$(md5sum < "$C" | cut -c1-12)"
  if "$B/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$C" "$S/big.c" \
       -o "$W/$T.s" > "$W/$T.out" 2> "$W/$T.err"; then
    printf '  big.c -O2 -> %s bytes  md5 %s\n' "$(wc -c < "$W/$T.s")" \
      "$(md5sum < "$W/$T.s" | cut -c1-12)"
  else
    printf '  big.c -O2 -> FAILED rc=%s: %s\n' "$?" "$(head -2 "$W/$T.err" | tr '\n' ' ')"
  fi
done
