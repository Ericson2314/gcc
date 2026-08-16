#!/bin/sh
# For every emitted `specs-config' key, WHERE DOES ITS VALUE COME FROM?
#
# This is the "whose answer is it" question of PRINCIPLES 2a applied to the
# capability set.  The emission lines look uniform:
#
#     as_tls        `ts_bool "$ts_as_tls"`          <- triple case logic
#     gas_shf_merge `ts_bool "$gcc_cv_as_shf_merge"` <- a real assembler probe
#
# and the difference is invisible in the output file, which is the whole
# problem: a pinned set and a probed set must not be confusable, and today
# even a PROBED set silently mixes two provenances.
#
# gcc_cv_* is autoconf's cache-variable convention and is what an actual
# gcc_GAS_CHECK_FEATURE-style probe writes.  ts_* is this configure's own
# variable, set from `case $target' logic.  Neither prefix is a guarantee, so
# both populations are printed by name for reading, not just counted.
set -u
AC=${1:-target-specs/configure.ac}
[ -f "$AC" ] || { echo "FATAL: no $AC"; exit 9; }

# emission lines: `<key> `ts_bool "$<var>"`' or `<key> "$<var>"'
# Only real emission lines: a KEY that is in ts_expected, at column 1,
# followed by a value expansion.  The first draft matched any line starting
# with a lowercase word, which swept in shell `if' and the word `expected'
# from prose -- 195 "emission lines" for 122 keys.  A count larger than the
# key inventory is the tell, and it is why the inventory is loaded first.
KEYLIST=$(awk '/^ts_expected="/,/"$/' "$AC" | sed 's/ts_expected="//; s/"$//' \
          | tr -s ' \n' '\n' | grep . | sort -u)
EM=$(for k in $KEYLIST; do
       grep -nE "^$k +" "$AC" | grep -E '\$(gcc_cv|ts)_[a-z0-9_]+'
     done)
[ -n "$EM" ] || { echo "FATAL: read zero emission lines"; exit 9; }

nprobe=0; nts=0
echo "=== fed by gcc_cv_* (an autoconf probe ran a tool) ==="
echo "$EM" | grep 'gcc_cv_' | sed 's/:.*//;s/^/line /' > /dev/null
for l in $(echo "$EM" | grep -o '^[0-9]*:[a-z0-9_]*' | tr '\n' ' '); do :; done
echo "$EM" | while IFS= read -r line; do
  key=$(echo "$line" | sed 's/^[0-9]*://' | awk '{print $1}')
  case $line in
    *gcc_cv_*) printf '  %-40s PROBED\n' "$key" ;;
  esac
done
echo "=== fed by ts_* (set from case \$target in this script) ==="
echo "$EM" | while IFS= read -r line; do
  key=$(echo "$line" | sed 's/^[0-9]*://' | awk '{print $1}')
  case $line in
    *gcc_cv_*) ;;
    *) printf '  %-40s TRIPLE-DERIVED\n' "$key" ;;
  esac
done
nprobe=$(echo "$EM" | grep -c 'gcc_cv_')
ntot=$(echo "$EM" | grep -c .)
echo
echo "emission lines: $ntot   PROBED(gcc_cv_*)=$nprobe   TRIPLE-DERIVED=$((ntot-nprobe))"
