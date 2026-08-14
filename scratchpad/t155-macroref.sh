#!/bin/sh
# #155 -- SEARCH FOR THE ACCESSOR, NOT ONLY THE NAME.
#
# t155-classify.sh asks whether a SHARED translation unit spells the bare
# symbol.  That question is necessary and NOT sufficient, and the link proved
# it: `constant_address_p' and `legitimate_pic_operand_p' both scored "no
# shared TU names the bare symbol" and both produced undefined references from
# shared objects the moment they were renamed.
#
# The reason is that shared code reaches them through an UPPERCASE MACRO:
#
#   config/i386/i386.h:1853  #define CONSTANT_ADDRESS_P(X)  constant_address_p (X)
#   config/i386/i386.h:1870  #define LEGITIMATE_PIC_OPERAND_P(X) legitimate_pic_operand_p (X)
#
# and the shared TU spells CONSTANT_ADDRESS_P, which no grep for
# `constant_address_p' will ever find.  This is PRINCIPLES' own rule -- "a
# symbol's name does not tell you which macro pulled it in", and "search for
# the ACCESSOR, not only the name" -- met from the other direction.
#
# So, for each candidate: find every macro under gcc/config/ whose BODY calls
# the name, then ask whether any shared TU spells that macro.  If one does, a
# rename converts a silent wrong answer into a link failure, and the name needs
# the macro CONVERTED rather than renamed.
#
# Deliberately over-broad: it can only REVOKE a rename, never authorise one, so
# a false positive costs a second look and a false negative costs a build.
#
# usage: t155-macroref.sh <name>...
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
[ -d "$G/config" ] || { echo "FATAL: $G/config missing"; exit 9; }

# Non-vacuity: this must be able to FIND a macro at all.  A broken search reads
# as "no name is macro-mediated", which is the reassuring answer.
ctl=$(grep -rl "define CONSTANT_ADDRESS_P" "$G/config" | head -1)
[ -n "$ctl" ] || { echo "REFUSING TO SCORE: control macro not found"; exit 9; }
echo "arm 0 ok: control CONSTANT_ADDRESS_P found in ${ctl#"$G/"}"

for n in "$@"; do
  # Macros under config/ whose body mentions the name.  A macro definition may
  # continue over backslash-continued lines, so take the definition line plus
  # the two following.
  macs=$(grep -rhA2 "^#[ \t]*define[ \t][A-Z_][A-Z0-9_]*" "$G/config" \
         | grep -B2 "[^A-Za-z0-9_]$n[ \t]*(" \
         | grep -o "^#[ \t]*define[ \t][A-Z_][A-Z0-9_]*" \
         | awk '{print $NF}' | sort -u)
  [ -n "$macs" ] || { echo "clean     $n   (no config/ macro calls it)"; continue; }
  bad=""
  for m in $macs; do
    u=$(grep -rlw "$m" "$G" --include='*.cc' --include='*.c' 2>/dev/null \
        | grep -v "^$G/config/" | grep -v '/testsuite/' | grep -v "^$G/gen")
    [ -n "$u" ] && bad="$bad $m"
  done
  if [ -n "$bad" ]; then
    echo "REVOKE    $n   reached by shared TUs through:$bad"
  else
    echo "ok        $n   macros [$(echo $macs | tr '\n' ' ')] are config-only"
  fi
done

# WHAT THIS SCRIPT IS STILL BLIND TO, AND IT IS THE INTERESTING PART.
#
# It asks whether SOME macro under config/ calls the name and whether SOME
# shared TU spells that macro.  It does NOT ask whether the macro DEFINITION
# the shared TU actually sees is the one that calls the name -- and shared TUs
# see exactly one, out of the PRIMARY's tm.h.  Hence the over-broad hits:
#
#   print_operand      PRINT_OPERAND appears in final.cc:3775 -- in a COMMENT.
#   output_ascii       varasm.cc really does use ASM_OUTPUT_ASCII, but elfos.h
#                      defines it to default_elf_asm_output_ascii; only pdp11
#                      and rs6000 define it to call output_ascii.
#   symbol_mentioned_p arm.h's LEGITIMATE_PIC_OPERAND_P calls it; i386.h's does
#                      not.  With i386 supplying tm.h, nothing reaches it.
#
# SO THE SAFETY OF A RENAME IS CURRENTLY A FUNCTION OF WHICH BACK END SUPPLIES
# THE SHARED tm.h.  That is not a defect in this script; it is the branch's
# central bug showing through.  `constant_address_p' and
# `legitimate_pic_operand_p' are unsafe because I386's macros call them, and
# `symbol_mentioned_p' is safe only because i386's do not.  Configure arm as
# the tm.h supplier and the safe/unsafe sets change.
#
# Consequence to carry: this list must be re-derived, not inherited, whenever
# the tm.h supplier changes -- and it stops being primary-dependent only when
# the macros are converted, which is the same task as deleting the shared tm.h.
