#!/bin/sh
# a76a331dcb554f700 -- resolve the six conflicts left by -remerge.sh.
#
# EVERY ONE OF THE SIX WAS INSPECTED AND `theirs' IS A STRICT SUPERSET OF
# `ours' in all of them: the two sides added the SAME `ASM_DECLARE_FUNCTION_
# SIZE' / `ADJUST_INSN_LENGTH' / `ADDR_VEC_ALIGN' block at the same point, and
# `theirs' additionally carries the `ASM_OUTPUT_ADDR_VEC_ELT' family.  So this
# takes `theirs' inside each conflict -- which is what the original merge did.
#
# THE ORIGINAL MERGE'S ERROR WAS NOT THE CHOICE INSIDE THE CONFLICTS; IT WAS
# TAKING `theirs' FOR THE WHOLE FILE, which discarded `ours'' NON-conflicting
# additions -- the entire `EH_RETURN_HANDLER_RTX' / `EH_RETURN_STACKADJ_RTX' /
# `TRAMPOLINE_SECTION' conversion, 28 lines of it in target-frame.h alone.
# Their consumers were not conflicted and survived, so the tip does not build.
# That distinction is the whole finding, hence a script rather than an edit.
#
# ARM: refuses unless the resolved files carry the three names back, so a
# resolution that "worked" and restored nothing cannot be mistaken for success.
set -eu
W=$(cd "$(dirname "$0")/.." && pwd)
D=/tmp/mrg-a76a331dcb554f700
for n in target-frame.h target-cumargs.cc target-cumargs-select.cc; do
  awk '
    /^<<<<<<< / { state = "ours"; next }
    /^\|\|\|\|\|\|\| / { state = "base"; next }
    /^=======$/ { if (state != "") { state = "theirs"; next } }
    /^>>>>>>> / { state = ""; next }
    state == "ours" || state == "base" { next }
    { print }
  ' "$D/$n.merged" > "$D/$n.resolved"
  grep -q '^<<<<<<<\|^>>>>>>>' "$D/$n.resolved" && { echo "FATAL: markers left in $n"; exit 9; }
  cp "$D/$n.resolved" "$W/gcc/$n"
  echo "$n resolved -> gcc/$n"
done

for sym in EH_RETURN_HANDLER_RTX EH_RETURN_STACKADJ_RTX TRAMPOLINE_SECTION; do
  n=$(grep -c "$sym" "$W/gcc/target-frame.h" || true)
  [ "$n" -gt 0 ] || { echo "FATAL: $sym still absent from target-frame.h; the restore did nothing"; exit 9; }
  echo "restored: $sym ($n mentions in target-frame.h)"
done
for fn in mt_has_eh_return_stackadj_rtx mt_eh_return_stackadj_rtx \
          mt_eh_return_handler_rtx mt_has_trampoline_section mt_trampoline_section; do
  grep -q "^$fn (" "$W/gcc/target-cumargs-select.cc" \
    || { echo "FATAL: $fn has no definition in target-cumargs-select.cc"; exit 9; }
  echo "defined: $fn"
done
echo "RESOLVE-OK"
