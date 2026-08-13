#!/bin/sh
# Every SHARED-code mention of the macros task #112 converts.  Arm D reports
# only #ifdef guards; a conversion has to find EVERY spelling, including value
# tests and any I did not expect.  config/ and testsuite/ are excluded because
# back-end code is on the supply side and keeps the real macros.
set -u
G=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/gcc
M='STATIC_CHAIN_REGNUM|STATIC_CHAIN_INCOMING_REGNUM|EMPTY_FIELD_BOUNDARY|STRUCTURE_SIZE_BOUNDARY|DWARF_ALT_FRAME_RETURN_COLUMN|INIT_ARRAY_SECTION_ASM_OP'
echo "=== SHARED code (the sites that must be rewritten) ==="
grep -rnE "$M" "$G" \
  | grep -v "^$G/config/" | grep -v "^$G/testsuite/" | grep -v '^Binary'
echo
echo "=== count by macro, shared only ==="
for m in STATIC_CHAIN_REGNUM STATIC_CHAIN_INCOMING_REGNUM EMPTY_FIELD_BOUNDARY \
         STRUCTURE_SIZE_BOUNDARY DWARF_ALT_FRAME_RETURN_COLUMN INIT_ARRAY_SECTION_ASM_OP; do
  n=$(grep -rn "\b$m\b" "$G" | grep -v "^$G/config/" | grep -v "^$G/testsuite/" | grep -c .)
  printf '  %-32s %s\n' "$m" "$n"
done
