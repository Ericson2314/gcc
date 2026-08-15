#!/bin/sh
# agent-aa9d4bba0b6e950b3-ccsyms.sh -- the OBJECT-level arm for the CC-mode
# leak.  Which selection function does each shared object actually bind?
#
# `nm' CAN see this one, and it is worth saying why, because PRINCIPLES records
# that the symbol instrument is blind to macros expanding to OPTION STATE.
# These three macros expand to FUNCTION CALLS (`ix86_cc_mode',
# `ix86_reverse_condition'), not to `global_options.x_*' members, so an
# undefined reference really is carried in the object.  That is the case `nm'
# is good for.
#
# THE NEGATIVE CONTROL IS THE POINT.  A run that prints "0 ix86_cc_mode" is
# indistinguishable from a run where `nm' is missing, the object is absent, or
# the pattern is wrong -- the shape PRINCIPLES calls a tool-not-found piped
# into `grep -c'.  So every object is scored for BOTH the i386 symbol and an
# s390 symbol that must NEVER appear in shared code, and the script refuses to
# report if it could not read the object at all.
#
# usage: agent-aa9d4bba0b6e950b3-ccsyms.sh <builddir>
set -eu
D=${1:?build dir}
G=$D/gcc
command -v nm > /dev/null || { echo "FATAL: no nm (run inside eb-shell.sh)" >&2; exit 9; }

I386='ix86_cc_mode|ix86_reverse_condition'
S390='s390_select_ccmode|s390_reverse_condition'
MT='mt_select_cc_mode|mt_reversible_cc_mode|mt_reverse_condition|mt_has_select_cc_mode'

printf '%-22s %6s %6s %6s   %s\n' OBJECT i386 s390 mt_ NOTE
for o in combine.o ccmp.o compare-elim.o jump.o; do
  f=$G/$o
  if [ ! -f "$f" ]; then printf '%-22s %s\n' "$o" "ABSENT -- refusing to score"; continue; fi
  u=$(nm -uC "$f") || { printf '%-22s %s\n' "$o" "nm FAILED"; continue; }
  # non-vacuity: an object with NO undefined symbols at all means nm read
  # nothing useful, and every count below would be a meaningless 0.
  n=$(printf '%s\n' "$u" | grep -c . || true)
  [ "$n" -gt 0 ] || { printf '%-22s %s\n' "$o" "no undefined symbols at all -- VACUOUS"; continue; }
  a=$(printf '%s\n' "$u" | grep -cE "$I386" || true)
  b=$(printf '%s\n' "$u" | grep -cE "$S390" || true)
  c=$(printf '%s\n' "$u" | grep -cE "$MT" || true)
  printf '%-22s %6s %6s %6s   %s undefined syms\n' "$o" "$a" "$b" "$c" "$n"
done
echo
echo "READING: before the fix the i386 column is non-zero and the other two are"
echo "0 -- shared code binds the PRIMARY's CC selection.  The s390 column is the"
echo "negative control and must be 0 in BOTH states: a per-base symbol must"
echo "never be reachable from shared code, before or after."
