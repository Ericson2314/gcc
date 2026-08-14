#!/bin/sh
# #150 -- WHO DEFINES THE BARE `add_clobbers'?
#
# The consumers do not change: combine.o, recog.o, gcse.o and
# rtl-ssa/changes.o call the BARE name before and after, so an `nm -uC' arm on
# them reads identically in both states and proves nothing.  What changes is
# which object DEFINES it.  So this scores definitions, not references.
#
# PRINCIPLES section 7: `awk '$0 ~ f'' on a demangled C++ name matches nothing,
# because the `()' is an empty regex group.  Everything here uses fixed-string
# matching (`grep -F') for that reason.
#
# usage: t150-syms.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad0e44242408b7fde*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"

# NON-VACUITY FIRST.  `nm' is not on PATH outside the nix-shell, and
# tool-not-found piped into `grep -c' scores 0 -- in the direction that makes
# the answer look right (PRINCIPLES section 5).  So: prove nm ran and read
# something before scoring anything.
all=$(sh "$S/eb-shell.sh" \
  "cd $G && nm -C --defined-only insn-emit-*.o multi-target-select.o 2>/dev/null")
n=$(printf '%s\n' "$all" | grep -c .)
[ "$n" -gt 100 ] || {
  echo "REFUSING TO SCORE: nm read $n lines over insn-emit-*.o -- that is not"
  echo "a populated link.  (Missing nm, or the objects were never built.)"
  exit 9
}
echo "arm 0 ok: nm read $n defined symbols"
echo

echo "== every definition of add_clobbers / added_clobbers_hard_reg_p, by object"
sh "$S/eb-shell.sh" "cd $G && for o in insn-emit-*.o multi-target-select.o; do
     nm -C --defined-only \$o 2>/dev/null \
       | grep -F -e 'add_clobbers(rtx_def*, int)' \
                 -e 'added_clobbers_hard_reg_p(int)' \
       | grep -v '\.cold' \
       | sed \"s|^|  \$o  |\"; done" | sort

echo
echo "== the discriminator: is there a BARE (un-namespaced) definition left?"
bare=$(sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only insn-emit-*.o 2>/dev/null" \
       | grep -F -e 'add_clobbers(rtx_def*, int)' \
                 -e 'added_clobbers_hard_reg_p(int)' \
       | grep -v '\.cold' | grep -v 'insn_' | grep -c . || true)
echo "  bare definitions in insn-emit-*.o : $bare   (want 0 after the fix, 2 before)"
fwd=$(sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only multi-target-select.o 2>/dev/null" \
      | grep -F -e 'add_clobbers(rtx_def*, int)' \
                -e 'added_clobbers_hard_reg_p(int)' \
      | grep -v 'insn_' | grep -c . || true)
echo "  forwarders in multi-target-select.o: $fwd   (want 2 after the fix, 0 before)"
