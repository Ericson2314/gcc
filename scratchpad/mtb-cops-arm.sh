#!/bin/sh
# Is the `TARGET_CPU_CPP_BUILTINS' scope class (STATE.md's "733", cause B
# generalised) still present?
#
# Three arms, because under `make -k' "never attempted" and "passed" are the
# same silence and a zero from a name-matching instrument is a claim about the
# instrument:
#
#   1. the LOG:  how many diagnostics name the vocabulary.
#   2. the FILESYSTEM: does every back end's target-c-ops-<cpu>.o exist.
#   3. NON-VACUITY: the same greps must be able to see the strings at all,
#      so that a 0 cannot be confused with "read nothing".
#
# usage: mtb-cops-arm.sh <logfile> <builddir> <cpu-list-file>
set -u
LOG=${1:?log}; D=${2:?builddir}; BE=${3:?cpu list}
[ -s "$LOG" ] || { echo "FATAL: $LOG empty/missing"; exit 9; }
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc missing"; exit 9; }
[ -s "$BE" ] || { echo "FATAL: $BE empty/missing"; exit 9; }

echo "== arm 3 (run first): NON-VACUITY"
nc=$(grep -c 'target-c-ops' "$LOG")
ne=$(grep -c 'error:' "$LOG")
echo "   log mentions of target-c-ops : $nc"
echo "   log 'error:' lines total     : $ne"
[ "$nc" -gt 0 ] || { echo "FATAL: log never mentions target-c-ops -- cannot score"; exit 9; }
[ "$ne" -gt 0 ] || { echo "FATAL: log has no 'error:' at all -- a 0 below would be vacuous"; exit 9; }

echo "== arm 1: the vocabulary, by name"
for n in builtin_define builtin_assert builtin_define_std \
         builtin_define_with_int_value builtin_define_with_value \
         preprocessing_asm_p preprocessing_trad_p c_dialect_cxx c_dialect_objc \
         c_register_addr_space flag_iso; do
  c=$(grep 'error:' "$LOG" | grep -c "$n")
  printf '   %-32s %s\n' "$n" "$c"
done
echo "   any target-c-ops object failing per make:"
grep -E '^make(\[[0-9]+\])?: \*\*\* \[' "$LOG" | grep -c 'target-c-ops'

echo "== arm 2: FILESYSTEM -- every base's object must exist"
have=0; miss=0
for b in $(grep -v '^#' "$BE" | grep .); do
  if [ -e "$D/gcc/target-c-ops-$b.o" ]; then have=$((have+1)); else miss=$((miss+1)); echo "   MISSING target-c-ops-$b.o"; fi
done
echo "   present=$have missing=$miss"
