#!/bin/sh
# #129 -- WHICH insn-attribute / insn-codes authority shared code links.
#
# Non-vacuity floor on nm's own output FIRST: nm is not on PATH outside the
# nix-shell, and a tool-not-found piped into grep -c scores 0 in exactly the
# direction that makes the reference look correct.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b132}
O=$B/t132-syms.txt

sh "$S/eb-shell.sh" "cd $B/gcc && nm -C --defined-only *.o" > "$O" 2> "$O.err"
n=$(wc -l < "$O")
echo "nm defined-only lines: $n"
if [ "$n" -lt 10000 ]; then
  echo "FATAL: nm output implausibly small ($n); refusing to score."
  head -3 "$O.err"; exit 9
fi
[ -s "$O.err" ] && { echo "FATAL: nm wrote stderr:"; head -3 "$O.err"; exit 9; }

echo
echo "=== DEFINITIONS of the attribute entry points, by object ==="
for f in get_attr_enabled get_attr_preferred_for_size get_attr_preferred_for_speed \
         insn_default_length insn_min_length insn_current_length \
         num_delay_slots internal_dfa_insn_code insn_default_latency \
         bypass_p insn_latency maximal_insn_latency state_transition dfa_start; do
  sh "$S/eb-shell.sh" \
    "cd $B/gcc && nm -C --defined-only --print-file-name *.o | grep -E ' [TDBRVW] (insn_[a-z0-9_]+::)?$f(\\(|\$)'" \
    > "$B/t132-def-$f.txt" 2> /dev/null
  printf '%-32s' "$f"
  awk '{printf "%s[%s] ", $1, $3}' "$B/t132-def-$f.txt"
  echo
done

echo
echo "=== WHO REFERENCES the un-namespaced (primary) names ==="
for f in get_attr_enabled get_attr_preferred_for_size insn_default_length \
         num_delay_slots internal_dfa_insn_code insn_default_latency; do
  printf '%-32s' "$f"
  sh "$S/eb-shell.sh" \
    "cd $B/gcc && nm -C -u --print-file-name *.o | grep -E ' U $f(\\(|\$)' | cut -d: -f1 | sort -u | tr '\n' ' '" \
    2> /dev/null
  echo
done

echo
echo "=== NUM_INSN_CODES, the shared bound ==="
grep -h 'NUM_INSN_CODES' "$B/gcc/insn-codes.h" "$B/gcc/insn-codes-i386.h" \
     "$B/gcc/insn-codes-aarch64.h" | sed 's/^/  /'
