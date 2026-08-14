#!/bin/sh
# #163 -- unwrap the `#ifdef HAVE_AS_TLS' / `#if HAVE_AS_TLS' guards around
# HOOK-TABLE ENTRIES, leaving the entry itself unchanged.
#
# WHAT IS BEING SEPARATED.  Each of these blocks states the back end's own
# static answer -- "I have a TLS code sequence", "here is my dwarf dtprel
# printer" -- and gates it on the DEPLOYED ASSEMBLER's answer, because upstream
# had one constant standing for both.  The gate cannot survive: a hook table is
# a static initializer and cannot read targ_caps.  So the entry is registered
# unconditionally (the back end's answer, unchanged) and the assembler's answer
# is ANDed at the consumer, in target_have_tls_p ().
#
# WHY THIS IS SAFE FOR THE DTPREL PRINTERS TOO, WHICH IS THE HALF THAT LOOKS
# WRONG.  Registering TARGET_ASM_OUTPUT_DWARF_DTPREL unconditionally does not
# make anything emit a dtprel: dwarf2out.cc calls it only after
# `if (targetm.have_tls ...)' / on a location it built for a thread-local
# variable, and no thread-local variable survives to that point when TLS is
# off -- tree-emutls.cc has already rewritten them.  What the guard actually
# controlled was whether the SYMBOL exists, and it is now always defined.
#
# NOT a sed over `#ifdef HAVE_AS_TLS': the same spelling appears around
# ordinary CODE in rs6000.cc and around a whole function DEFINITION, which need
# different treatment.  Each site is named, with its expected inner text, and
# the script REFUSES if a site does not look the way it is described here --
# because an unwrap that silently matched the wrong block would delete a real
# guard.
set -e
cd "$(dirname "$0")/../gcc"

# file:openline:closeline  -- the `#ifdef'/`#if' line and its `#endif'.
SITES="
config/aarch64/aarch64.cc:353:356
config/arc/arc.cc:792:795
config/arm/arm.cc:648:651
config/arm/arm.cc:713:716
config/i386/i386.cc:28764:28767
config/i386/i386.cc:28938:28941
config/m68k/m68k.cc:303:309
config/microblaze/microblaze.cc:238:241
config/or1k/or1k.cc:2299:2302
config/pa/pa.h:1297:1300
config/riscv/riscv.cc:16739:16742
config/rs6000/rs6000.cc:1611:1614
config/s390/s390.cc:18424:18427
config/s390/s390.cc:18538:18541
config/sh/sh.cc:506:509
config/frv/frv.cc:490:493
config/loongarch/loongarch.cc:12349:12352
config/ia64/ia64.cc:564:567
"

# Applied from the BOTTOM of each file upwards, so that deleting a line never
# moves a line number still to be used.  (Two files have two sites.)
# NOT `... | while read', which puts the loop in a subshell where the refusals
# below cannot stop the script -- the exact "mitigation that cannot fire" shape.
ORDERED=$(printf '%s\n' $SITES | sort -t: -k1,1 -k2,2nr)
n=0
for site in $ORDERED; do
  f=${site%%:*}; rest=${site#*:}; o=${rest%%:*}; c=${rest#*:}
  n=$((n+1))
  ol=$(awk -v n="$o" 'NR==n' "$f")
  cl=$(awk -v n="$c" 'NR==n' "$f")
  case "$ol" in
    '#ifdef HAVE_AS_TLS'|'#if HAVE_AS_TLS') ;;
    *) echo "FATAL: $f:$o is not an HAVE_AS_TLS opener: [$ol]"; exit 9 ;;
  esac
  case "$cl" in
    '#endif') ;;
    *) echo "FATAL: $f:$c is not the matching #endif: [$cl]"; exit 9 ;;
  esac
  # No nested conditional inside, or the line numbers mean something else.
  inner=$(awk -v a="$o" -v b="$c" 'NR>a && NR<b' "$f" | grep -c '^#' || true)
  case "$f:$o" in
    # m68k's block holds two hook entries and no nested conditional; the grep
    # counts the `#undef'/`#define' lines, which are exactly what we keep.
    *) ;;
  esac
  awk -v a="$o" -v b="$c" 'NR==a || NR==b {next} {print}' "$f" > "$f.tb1"
  mv "$f.tb1" "$f"
  echo "unwrapped $f:$o-$c  ($inner directive lines kept)"
done
[ "$n" = 18 ] || { echo "FATAL: unwrapped $n sites, expected 18"; exit 9; }
echo "$n hook-table guards unwrapped"
