#!/bin/sh
# agent-a97cff7619d3cabd9-regmaker.sh -- SHARED code that walks to the UNION's
# `FIRST_PSEUDO_REGISTER' and then MAKES A REG out of the index.
#
# This is PRINCIPLES' prescribed grep ("grep for `< FIRST_PSEUDO_REGISTER' in
# shared code that then calls a `targetm' hook with the index") narrowed to the
# case that manufactures a register NUMBER the selected base does not have --
# the producer behind `in_hard_reg_set_p, at regs.h:312'.
#
# IT IS DELIBERATELY OVER-BROAD: a 30-line window after the loop head, any
# `gen_rtx_REG'/`gen_raw_REG'.  It can only nominate a site for reading, never
# authorise a conversion, so eagerness is the right bias (PRINCIPLES 4).
# `config/' is excluded: a back end's own TU has its own bound and is correct.
#
# usage: agent-a97cff7619d3cabd9-regmaker.sh <gccdir>
set -u
MTW=${MTW:-30}          # lines of window after the loop head
G=${1:?gcc source dir}
cd "$G" || exit 9
n=0
for f in *.cc; do
  awk -v F="$f" -v MTW="$MTW" '
    /< *FIRST_PSEUDO_REGISTER/ && !/MT_FIRST|MULTI_TARGET_UNION/ { line=NR; ctx=1; next }
    ctx && NR < line+MTW && /gen_rtx_REG|gen_raw_REG/ { printf "%s:%d loop -> %d: %s\n", F, line, NR, $0; ctx=0 }
    ctx && NR >= line+MTW { ctx=0 }
  ' "$f"
  n=$((n+1))
done
echo "-- scanned $n shared .cc files in $G"
[ "$n" -gt 100 ] || { echo "FATAL: only $n files scanned; the glob did not run"; exit 9; }
