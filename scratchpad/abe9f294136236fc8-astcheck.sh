#!/bin/sh
# Assert the ten scored triples' cross assemblers RUN, and say so by name.
#
# `OK' must mean the binary EXECUTED, never that a path exists: INSTRUMENTS.md
# records that a dangling symlink or a wrong-arch binary is exactly the shape
# that falls back to the host `as' three layers away, which is the defect
# GUARD 3c exists for (~10,000 results per target).  So this runs
# `--version' and requires the output to be non-empty, and it FAILS LOUDLY on
# a missing one rather than printing a shorter list.
#
# usage: abe9f294136236fc8-astcheck.sh <toolsbin> <triple>...
set -u
BIN=${1:?tools bin dir}; shift
[ $# -ge 1 ] || { echo "FATAL: name at least one triple"; exit 9; }
nok=0; nbad=0
for T in "$@"; do
  v=$("$BIN/$T-as" --version 2>/dev/null | head -1)
  if [ -n "$v" ]; then
    printf 'OK      %-32s %s\n' "$T" "$v"
    nok=$((nok+1))
  else
    printf 'MISSING %-32s (no runnable %s)\n' "$T" "$BIN/$T-as"
    nbad=$((nbad+1))
  fi
done
echo "-- $nok runnable, $nbad missing, of $#"
# THE NEGATIVE CONTROL, so a green here is known to be capable of red.  A
# triple nobody has ever packaged must report MISSING; if it reports OK the
# loop above is not testing what it claims to.
v=$("$BIN/nosuchcpu-unknown-elf-as" --version 2>/dev/null | head -1)
[ -z "$v" ] || { echo "FATAL: the control triple answered -- this check cannot fail"; exit 9; }
echo "-- negative control: nosuchcpu-unknown-elf-as MISSING, as it must be"
[ "$nbad" = 0 ] || exit 9
