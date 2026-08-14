#!/bin/sh
# #136 -- the MECHANISM arm, and it is not the defect arm.
#
# `nm' cannot see the wrong unspec_volatile number (see t136-blockage.sh); what
# it CAN see is who defines the bare names, which is what the change moves.
# Two questions, both answered by name:
#
#   1. does the singular insn-emit-*.o still define gen_blockage / gen_nop /
#      gen_speculation_barrier?  After the change it must not -- that
#      suppression is what leaves the forwarder a name to define.
#   2. does multi-target-select.o define them?  If neither does, the link would
#      have failed, so this is a cross-check rather than the finding.
#
# Also reports gen_movxf, which the change does NOT touch.
set -u
B=${1:?build dir}
case "$B" in
  */b-a5cf4*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
S=$(cd "$(dirname "$0")" && pwd)
# -C, and the pattern anchors on `NAME()' -- these symbols are C++-mangled
# (`_Z12gen_blockagev'), and a grep written against the C spelling matches
# NOTHING and reads exactly like "the name is already gone".
sh "$S/eb-shell.sh" "cd $B/gcc && \
  for n in gen_blockage gen_nop gen_speculation_barrier gen_movxf; do \
    echo \"== \$n\"; \
    nm -CA --defined-only insn-emit-[0-9]*.o multi-target-select.o \
       2>/dev/null | grep -E \" [TtWwDdRrBb] \$n\\(\" \
       || echo '   (defined by neither)'; \
  done"
