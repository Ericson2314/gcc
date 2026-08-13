#!/bin/sh
# TASK #117 -- WHO ASKS THE PRIMARY'S insn-opinit.o?
#
# The primary's un-namespaced `insn-opinit.o' is in $(OBJS) (gcc/Makefile.in,
# the `insn-opinit.o' line).  It exports 8 bare symbols.  This script asks,
# for each, WHICH OTHER OBJECT IN THE LINK REFERENCES IT BARE -- i.e. which
# shared translation units are getting the primary's optab answer.
#
# INSTRUMENT NOTES, each paid for:
#
#   * `grep -q' is NOT used anywhere.  Under a pipeline it can exit 141
#     (SIGPIPE) on a MATCH, which scores a hit as a miss -- in the direction
#     that makes the primary look uninvolved.  Everything here counts lines.
#   * Matching is EXACT on the demangled name (`grep -x -F'), not substring.
#     Substring matching reports `selected_raw_optab_handler' as a reference to
#     `raw_optab_handler' and inflates the bare count from 1 to 40.  That is
#     the recorded `ix86_cfun_abi' lesson; both numbers are printed so the two
#     can never be confused again.
#   * `nm' is asserted present before anything is scored.  A missing tool piped
#     into a counter scores 0, in the flattering direction.
#
# Env: D = build dir (default /tmp/b117).
set -u
D=${D:-/tmp/b117}

command -v nm > /dev/null || { echo "FATAL: nm not on PATH (use the nix-shell)"; exit 9; }
[ -d "$D/gcc" ] || { echo "FATAL: no $D/gcc"; exit 9; }
cd "$D/gcc" || exit 9
[ -f insn-opinit.o ] || { echo "FATAL: no insn-opinit.o in $D/gcc"; exit 9; }

# Non-vacuity: the object list must be non-empty and must contain a TU we know
# talks to optabs, or every count below is a zero that means nothing.
nobj=$(ls *.o mt-*/*.o 2>/dev/null | wc -l)
[ "$nobj" -gt 100 ] || { echo "FATAL: only $nobj objects found; refusing to score"; exit 9; }
[ -f optabs-query.o ] || { echo "FATAL: no optabs-query.o; refusing to score"; exit 9; }

SYMS="code_to_optab_
convlib_def
normlib_def
optab_to_code_
init_all_optabs(target_optabs*)
raw_optab_handler(unsigned int)
swap_optab_enable(optab_tag, machine_mode, bool)
partial_vectors_supported_p()"

echo "=== bare symbols DEFINED by the primary's insn-opinit.o"
nm -C --defined-only insn-opinit.o | grep -v ' [rt] '

echo
echo "=== for each: objects with an EXACT bare undefined reference"
echo "    (exact = the leak; substring = the inflated number, printed to"
echo "     keep the two distinguishable)"
printf '%s\n' "$SYMS" | while IFS= read -r s; do
  [ -n "$s" ] || continue
  exact=""
  nexact=0
  for o in *.o mt-*/*.o; do
    [ "$o" = insn-opinit.o ] && continue
    [ -f "$o" ] || continue
    hit=$(nm -C -u "$o" 2>/dev/null | sed 's/^ *U //' | grep -c -x -F -- "$s")
    if [ "$hit" -gt 0 ]; then
      exact="$exact $o"
      nexact=$((nexact + 1))
    fi
  done
  # substring count, for contrast only
  base=$(printf '%s' "$s" | sed 's/(.*//')
  nsub=0
  for o in *.o mt-*/*.o; do
    [ "$o" = insn-opinit.o ] && continue
    [ -f "$o" ] || continue
    hit=$(nm -C -u "$o" 2>/dev/null | grep -c -F -- "$base")
    [ "$hit" -gt 0 ] && nsub=$((nsub + 1))
  done
  echo "EXACT=$nexact SUBSTR=$nsub  [$s]"
  [ -n "$exact" ] && echo "      ->$exact"
done

echo
echo "=== the funnel: who calls selected_raw_optab_handler"
n=0
for o in *.o mt-*/*.o; do
  [ -f "$o" ] || continue
  hit=$(nm -C -u "$o" 2>/dev/null | sed 's/^ *U //' \
        | grep -c -x -F -- "selected_raw_optab_handler(unsigned int)")
  [ "$hit" -gt 0 ] && n=$((n + 1))
done
echo "selected_raw_optab_handler referenced by $n objects"
[ "$n" -gt 0 ] || { echo "FATAL: the funnel has no callers; instrument or tree is wrong"; exit 9; }

echo
echo "=== NUM_OPTAB_PATTERNS, per base and shared"
grep -H 'define NUM_OPTAB_PATTERNS' insn-opinit.h insn-opinit-*.h

echo
echo "=== sizeof default_target_optabs as the SHARED objects see it"
nm -CS optabs-query.o | grep -F 'default_target_optabs'
