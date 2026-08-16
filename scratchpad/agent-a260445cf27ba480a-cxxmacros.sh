#!/bin/sh
# agent-a260445cf27ba480a-cxxmacros.sh -- the C++ front end's own per-target
# macro surface, and who answers it.
#
# 39 of 42 `cp/*.o' open the SHARED `tm.h', which is i386's whole header chain
# under a target-neutral name (PRINCIPLES: "the i386 tm.h wearing a name that
# does not say so").  `cp/cp-tree.h:24' is one of the four shared headers that
# carry the channel.  So every `tm.h' macro `cp/' spells is answered by the
# primary for all 47 back ends.
#
# This lists the macros `cp/' actually spells and counts their DEFINERS under
# config/ -- deliberately over-broad, in the direction that can only add
# suspects, per PRINCIPLES: "when an instrument can only take away, make it too
# eager; when it can grant, make it exact."  A macro with more than one definer
# is one whose answer differs between back ends and which cp/ reads from i386.
#
# It is a SOURCE-level census and says nothing about whether a given read is
# reached at run time.  Blind spots, stated: it cannot see macros reached
# through another macro (the `mode_ibit' shape), it word-matches so a macro
# spelled only inside a comment counts, and `defaults.h' fallbacks are counted
# as a definer like any other.
set -eu
S=${1:?srcdir}
S=$(cd "$S" && pwd)
cd "$S/gcc"

MACROS='TARGET_PTRMEMFUNC_VBIT_LOCATION TARGET_VTABLE_USES_DESCRIPTORS
TARGET_VTABLE_ENTRY_ALIGN TARGET_VTABLE_DATA_ENTRY_DISTANCE POINTER_SIZE
MAX_FIXED_MODE_SIZE BITS_PER_WORD UNITS_PER_WORD BIGGEST_ALIGNMENT
MALLOC_ABI_ALIGNMENT STACK_BOUNDARY FUNCTION_BOUNDARY MAX_OFILE_ALIGNMENT
TARGET_64BIT WCHAR_TYPE'

# NON-VACUITY: a control that MUST have many definers and one that must have
# none.  An all-zero column is what a broken grep looks like.
ctl=$(grep -rlw --include='*.h' -e "define BITS_PER_WORD" config/ | wc -l)
[ "$ctl" -ge 3 ] || { echo "REFUSE: control BITS_PER_WORD has $ctl definers under config/" >&2; exit 9; }
neg=$(grep -rlw --include='*.h' -e "define MT_NO_SUCH_MACRO_XYZ" config/ | wc -l)
[ "$neg" = 0 ] || { echo "REFUSE: negative control matched $neg" >&2; exit 9; }
echo "controls ok: BITS_PER_WORD $ctl definers, negative 0"
echo

printf '%-38s %6s %6s  %s\n' MACRO 'cp/uses' definers 'definers under config/ (first 6)'
for m in $MACROS; do
  u=$(grep -rw --include='*.cc' --include='*.h' -e "$m" cp/ | grep -cv 'define ' || true)
  d=$(grep -rlw --include='*.h' -e "define $m" config/ | wc -l)
  who=$(grep -rlw --include='*.h' -e "define $m" config/ | sed 's|config/||' | head -6 | tr '\n' ' ')
  printf '%-38s %6s %6s  %s\n' "$m" "$u" "$d" "$who"
done
