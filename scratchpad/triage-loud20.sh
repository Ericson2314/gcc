#!/bin/sh
# #169's LOUD queue (20 macros, censused at anchor 50). Has any been converted since?
# CONVERTED here = the name appears on a redirect line in this branch's conversion
# layer (defaults.h tail / multi-target-macros.h) or is fed by targetm_cdata / mt_*().
# Deliberately over-broad: it can only mark something as needing a second look,
# never authorise closing an entry.
set -u
cd "$(dirname "$0")/../gcc" || exit 1
LAYER="defaults.h multi-target-macros.h multi-target-base.h"
for m in STACK_REGS OPTIMIZE_MODE_SWITCHING INSN_SCHEDULING EXTRA_SPECS \
         EH_RETURN_DATA_REGNO ASSEMBLER_DIALECT TARGET_FORMAT_TYPES \
         COLLECT_RUN_DSYMUTIL ASM_OUTPUT_ALIGNED_BSS AS_NEEDS_DASH_FOR_PIPED_INPUT \
         ELF_ASCII_ESCAPES TARGET_SUPPORTS_WIDE_INT HAVE_blockage LEAF_REGISTERS \
         USE_SELECT_SECTION_FOR_FUNCTIONS HAVE_window_save; do
  hit=$(grep -hnE "define[[:space:]]+${m}\b" $LAYER 2>/dev/null | head -1)
  if [ -n "$hit" ]; then
    case "$hit" in
      *mt_*|*targetm_cdata*|*targetm\.*) echo "CONVERTED  $m  <- $hit" ;;
      *) echo "IN-LAYER   $m  <- $hit" ;;
    esac
  else
    echo "unconverted $m"
  fi
done
