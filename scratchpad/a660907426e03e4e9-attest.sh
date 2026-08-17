#!/bin/sh
# THE DISCRIMINATOR FOR `TYPE_OPERAND_FMT': does each target's OWN assembler
# accept the primary's `@object'?
#
# The header sweep (`-dissent.sh') says aarch64 asks for `%object' too -- and
# aarch64 IS one of the four previously scored targets, on which this defect
# was never reported.  Two explanations, and they are not the same finding:
#
#   (a) aarch64's assembler REJECTS `@object' as well, and the defect somehow
#       did not reach that board;
#   (b) aarch64's assembler ACCEPTS `@object', so the defect has been LIVE on
#       a scored target the whole time and produced no failure -- silent, and
#       visible only from a target whose assembler is stricter.
#
# (b) would be the stronger form of this task's thesis: not "the four lacked a
# property" but "the four could not COMPLAIN".  Settle it by assembling the
# offending directive with each target's real cross `as'.
#
# The `%object' control is not a formality: an assembler that rejected BOTH
# would mean the fragment is malformed for some other reason and neither
# column means anything.
set -eu
A=/tmp/a660907426e03e4e9-at.s
B=/tmp/a660907426e03e4e9-pct.s
printf '\t.data\n\t.type\tx, @object\n\t.size\tx, 4\nx:\n\t.zero\t4\n' > "$A"
printf '\t.data\n\t.type\tx, %%object\n\t.size\tx, 4\nx:\n\t.zero\t4\n' > "$B"
try () {  # $1 = as, $2 = file
  if "$1" -o /tmp/a660907426e03e4e9-at.o "$2" 2> /tmp/a660907426e03e4e9-at.err; then
    echo ACCEPTS
  else
    printf 'REJECTS: %s\n' "$(sed -n '2p;$p' /tmp/a660907426e03e4e9-at.err | head -1 | sed 's/^.*Error: //')"
  fi
}
printf '%-30s %-10s %s\n' TARGET '@object' '%object (control)'
T4=/tmp/tools-agent-ab1900d5279ba137f/bin
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu x86_64-pc-linux-gnu; do
  [ -x "$T4/$t-as" ] || { printf '%-30s NO ASSEMBLER -- NOT MEASURED\n' "$t"; continue; }
  printf '%-30s %-10s %s\n' "$t" "$(try "$T4/$t-as" "$A")" "$(try "$T4/$t-as" "$B")"
done
TA=/tmp/tools-agent-a660907426e03e4e9/bin/arm-unknown-linux-gnueabihf-as
printf '%-30s %-10s %s\n' arm-unknown-linux-gnueabihf "$(try "$TA" "$A")" "$(try "$TA" "$B")"
