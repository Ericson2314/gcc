#!/bin/sh
# #128 -- WHICH constraint vocabulary does SHARED code link against?
#
# The claim under test: `recog.o' (shared) binds the GLOBAL, un-namespaced
# `lookup_constraint_1' / `reg_class_for_constraint_1', which are defined by
# `insn-preds.o' -- the PRIMARY's copy -- while each back end's own copies live
# in namespace `insn_<base>' inside insn-preds-<base>.o.
#
# NON-VACUITY: every object must exist and `nm' must produce output for it,
# because a missing file piped into grep scores 0 in the direction that makes
# the reference look right (PRINCIPLES section 5).
set -u
B=${B:-/tmp/b128}
cd "$B/gcc" || exit 9
rc=0
for o in recog.o insn-preds.o insn-preds-i386.o insn-preds-aarch64.o; do
  if [ ! -f "$o" ]; then echo "FATAL missing $o"; exit 9; fi
  n=$(nm -C "$o" | wc -l)
  if [ "$n" -lt 5 ]; then echo "FATAL nm produced $n lines for $o"; exit 9; fi
  echo "== $o  ($n symbols)"
  echo "  DEFINED:"
  nm -C --defined-only "$o" | grep -E 'reg_class_for_constraint_1|lookup_constraint_1|constraint_satisfied_p_array|lookup_constraint_array' | sed 's/^/    /'
  echo "  UNDEFINED:"
  nm -uC "$o" | grep -E 'reg_class_for_constraint_1|lookup_constraint_1|constraint_satisfied_p_array|lookup_constraint_array' | sed 's/^/    /'
done
exit $rc
