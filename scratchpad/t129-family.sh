#!/bin/sh
# #129 -- JOB 2.  For every generated per-base family still carried
# un-namespaced in $(OBJS), score THREE SEPARATE ARMS:
#
#   (a) is a per-base variant BUILT?
#   (b) does a SELECTOR exist?
#   (c) does anything CALL the selector?
#
# (b) and (c) are deliberately not merged: `targetm_asm_ops' was pinned to the
# primary while `target_asm_ops_for ()' had no caller anywhere, and the table
# arm was green.
#
# Non-vacuity floor on nm FIRST -- nm is not on PATH outside the nix-shell and
# a tool-not-found piped into grep -c scores 0 towards "clean".
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b129}

probe () {  # $1 = symbol regexp, $2 = nm mode (u|d)
  if [ "$2" = u ]; then
    sh "$S/eb-shell.sh" "cd $B/gcc && nm -C -u --print-file-name *.o | grep -E ' U ($1)(\\(|\$)' | cut -d: -f1 | sort -u | tr '\n' ' '"
  else
    sh "$S/eb-shell.sh" "cd $B/gcc && nm -C --defined-only --print-file-name *.o | grep -E ' [TDBRVW] ($1)(\\(|\$)' | cut -d: -f1 | sort -u | tr '\n' ' '"
  fi
}

FLOOR=$(sh "$S/eb-shell.sh" "cd $B/gcc && nm -C --defined-only *.o | wc -l")
echo "nm floor: $FLOOR defined symbols"
case "$FLOOR" in ''|*[!0-9]*) echo "FATAL: nm floor not a number"; exit 9;; esac
[ "$FLOOR" -ge 10000 ] || { echo "FATAL: nm floor $FLOOR implausible; refusing to score"; exit 9; }

for fam in attrtab automata dfatab latencytab opinit preds emit; do
  echo
  echo "########## insn-$fam ##########"
  printf '(a) per-base objects built : '
  ls "$B"/gcc/insn-$fam-*.o 2>/dev/null | sed 's#.*/##' | tr '\n' ' '; echo
  printf '    shared (primary) object: '
  ls "$B"/gcc/insn-$fam.o "$B"/gcc/insn-$fam-[0-9].o 2>/dev/null | sed 's#.*/##' | tr '\n' ' '; echo
done

echo
echo "########## (b)/(c) THE SELECTION ARMS ##########"
echo
echo "-- opinit: selector functions DEFINED (b):"
printf '   '; probe 'selected_raw_optab_handler|selected_init_all_optabs|selected_swap_optab_enable|selected_partial_vectors_supported_p' d
echo
echo "-- opinit: who BINDS the selector (c):"
printf '   '; probe 'selected_raw_optab_handler|selected_init_all_optabs|selected_swap_optab_enable|selected_partial_vectors_supported_p' u
echo
echo "-- opinit: who still binds the BARE (primary) names:"
printf '   '; probe 'raw_optab_handler|init_all_optabs|swap_optab_enable|partial_vectors_supported_p' u
echo

echo "-- preds: who binds the mt_ forwarders (c):"
printf '   '; probe 'mt_lookup_constraint|mt_reg_class_for_constraint|mt_insn_constraint_len' u
echo
echo "-- preds: who still binds the BARE (primary) names:"
printf '   '; probe 'lookup_constraint_1|reg_class_for_constraint_1' u
echo

echo "-- emit: the six bare names the primary answers for everyone:"
for n in gen_blockage gen_nop gen_speculation_barrier add_clobbers added_clobbers_hard_reg_p gen_movxf; do
  printf '   %-30s defined: ' "$n"; probe "$n" d
  printf '\n       %-26s bound by: ' ''; probe "$n" u
  echo
done

echo
echo "-- attrtab/automata/dfatab/latencytab: is there ANY selector? --"
echo "   grep of the hand-written selection sources for the entry points:"
grep -c -E 'get_attr_enabled|get_attr_length|insn_default_length|internal_dfa_insn_code|insn_default_latency|state_transition|num_delay_slots|bypass_p|maximal_insn_latency|dfa_start' \
  "$S/../gcc/multi-target-select.cc" "$S/../gcc/target-cumargs.cc" \
  "$S/../gcc/target-cumargs-select.cc" "$S/../gcc/target-insn.h" 2>&1

echo
echo "-- who binds the BARE attribute entry points (the leak):"
for n in get_attr_enabled get_attr_preferred_for_size get_attr_preferred_for_speed \
         insn_default_length insn_min_length insn_current_length num_delay_slots \
         const_num_delay_slots eligible_for_delay internal_dfa_insn_code \
         insn_default_latency bypass_p insn_latency maximal_insn_latency \
         state_transition state_size state_reset dfa_start dfa_finish \
         min_issue_delay state_dead_lock_p min_insn_conflict_delay \
         print_reservation insn_has_dfa_reservation_p dfa_clean_insn_cache \
         dfa_clear_single_insn_cache init_sched_attrs; do
  printf '   %-30s ' "$n"; probe "$n" u; echo
done

echo
echo "-- NUM_INSN_CODES: the shared BOUND vs each base's INDEX space --"
grep -h 'NUM_INSN_CODES' "$B/gcc/insn-codes.h" "$B/gcc/insn-codes-i386.h" \
     "$B/gcc/insn-codes-aarch64.h" | sed 's/^/     /'
echo "   insn_data_tab sizes (bytes):"
sh "$S/eb-shell.sh" "cd $B/gcc && nm -CS --defined-only insn-output-i386.o insn-output-aarch64.o | grep insn_data_tab" | sed 's/^/     /'

echo
echo "-- HAVE_ATTR_* the shared insn-attr.h publishes vs each base's --"
for m in length enabled preferred_for_size preferred_for_speed; do
  printf '   %-22s shared=%s i386=%s aarch64=%s\n' "HAVE_ATTR_$m" \
    "$(grep -E "^#define HAVE_ATTR_$m " "$B/gcc/insn-attr.h" | head -1 | awk '{print $3}')" \
    "$(grep -E "^#define HAVE_ATTR_$m " "$B/gcc/insn-attr-i386.h" | head -1 | awk '{print $3}')" \
    "$(grep -E "^#define HAVE_ATTR_$m " "$B/gcc/insn-attr-aarch64.h" | head -1 | awk '{print $3}')"
done
