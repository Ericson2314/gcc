#!/bin/sh
# a446b256f0b8bb99c-modenum.sh -- is machine_mode NUMBERING per base?
#
# `target-cdata.h:166' defers `CASE_VECTOR_MODE' (and `Pmode', and
# `STACK_SIZE_MODE') on the ground that "mode NUMBERING is per base", so a mode
# would be "a number transported into a vocabulary where it means something
# else".  That is the stated blocker on converting CASE_VECTOR_MODE, so it is
# worth measuring rather than believing in either direction.
#
# The two per-base `insn-modes.h' files DO differ (different md5s), which is
# what makes the claim plausible.  This asks the narrower question the deferral
# actually turns on: do the ENUMERATORS of `enum machine_mode' appear in the
# same order with the same values?  The per-base DATA (sizes, precisions,
# formats) is expected and required to differ -- that is the union design.
#
# NEGATIVE CONTROL IS MANDATORY.  A comparison of two extractions that both
# came out empty is IDENTICAL output to a pass, which is this project's
# commonest false green.  So: assert both lists are non-empty and contain a
# mode known to exist, and then show the instrument CAN report a difference by
# perturbing one list.
set -eu
D=${1:?build dir}/gcc
# NOTE: `<base>-inc/insn-modes.h' is a ONE-LINE SHIM (`#include
# "insn-modes-<base>.h"'), so pointing this at the shim reads an empty
# enumerator list -- which the non-vacuity guard below caught on the first run,
# doing exactly the job it was written for.  Read the real file.
A=$D/insn-modes-i386.h
B=$D/insn-modes-aarch64.h
for f in "$A" "$B"; do
  [ -f "$f" ] || { echo "FATAL: $f missing"; exit 9; }
done

# The enumerator list, in order, as `<ordinal> <name>'.
extract () {
  sed -n '/^enum machine_mode$/,/^};/p' "$1" \
    | grep -oE '^  E_[A-Za-z0-9_]+' | tr -d ' ' | cat -n
}

extract "$A" > /tmp/mn-i386.$$
extract "$B" > /tmp/mn-aarch64.$$

na=$(wc -l < /tmp/mn-i386.$$); nb=$(wc -l < /tmp/mn-aarch64.$$)
echo "enumerators: i386 $na, aarch64 $nb"

# Non-vacuity: refuse to score an empty read.
[ "$na" -gt 50 ] && [ "$nb" -gt 50 ] \
  || { echo "FATAL: extraction is empty or implausibly short -- not scoring"; exit 9; }
grep -q 'E_DImode$' /tmp/mn-i386.$$ \
  || { echo "FATAL: i386 list has no E_DImode -- extraction is wrong"; exit 9; }

echo "--- E_DImode / E_SImode ordinals, both bases:"
for m in E_SImode E_DImode E_VOIDmode; do
  ia=$(grep -w "$m" /tmp/mn-i386.$$ | awk '{print $1}')
  ib=$(grep -w "$m" /tmp/mn-aarch64.$$ | awk '{print $1}')
  printf '  %-12s i386=%-6s aarch64=%-6s %s\n' "$m" "${ia:--}" "${ib:--}" \
    "$([ "$ia" = "$ib" ] && echo same || echo DIFFER)"
done

if diff -q /tmp/mn-i386.$$ /tmp/mn-aarch64.$$ >/dev/null; then
  echo "RESULT: mode numbering is SHARED -- enumerator lists identical"
  verdict=shared
else
  echo "RESULT: mode numbering DIFFERS between bases:"
  diff /tmp/mn-i386.$$ /tmp/mn-aarch64.$$ | head -20
  verdict=perbase
fi

# NEGATIVE CONTROL: the comparison must be able to say DIFFER.
sed '1s/E_/E_XX/' /tmp/mn-i386.$$ > /tmp/mn-ctl.$$
if diff -q /tmp/mn-i386.$$ /tmp/mn-ctl.$$ >/dev/null; then
  echo "FATAL: negative control did not fire -- comparison is vacuous"; exit 9
else
  echo "negative control: fired (a perturbed list is reported as different)"
fi

# And confirm the files really are NOT identical overall, so a `shared' verdict
# is not just "these two files are the same file".
if cmp -s "$A" "$B"; then
  echo "FATAL: the two insn-modes.h are byte-identical -- verdict is vacuous"; exit 9
else
  echo "control: the two insn-modes.h DO differ overall (per-base data), as designed"
fi
rm -f /tmp/mn-i386.$$ /tmp/mn-aarch64.$$ /tmp/mn-ctl.$$
echo "verdict=$verdict"
