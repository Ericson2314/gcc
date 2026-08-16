#!/bin/sh
# agent-a018835bbcfad2e28-leakcensus.sh -- WHICH target macros does
# target-independent code read from the PRIMARY base's tm.h?
#
# THE DEFECT THIS ENUMERATES.  The shared `tm.h' that every target-INDEPENDENT
# translation unit (varasm.cc, final.cc, expr.cc, ...) is compiled against
# includes exactly one back end's header chain -- i386's:
#
#     # include "config/i386/i386.h"   # include "config/i386/att.h"
#     # include "config/i386/x86-64.h" # include "config/i386/linux64.h"
#
# So every target macro spelled in target-independent code has ONE value for
# all 47 bases, and it is x86's.  There are two failure modes and they look
# nothing alike:
#
#   LEAK-PRIMARY  i386 defines it.  Every other base silently gets x86's
#                 answer.  Measured instance: ASM_OUTPUT_ALIGN is i386/att.h's
#                 `\t.align %d' with `1 << LOG', so riscv64 -- whose own macro
#                 is `\t.align\t%d' with LOG -- emits a BYTE COUNT where its
#                 assembler reads a LOG.
#
#   DEAD-DEFAULT  i386 does NOT define it, so the `#ifndef' fallback in rtl.h /
#                 defaults.h is live for everybody, including the 25 back ends
#                 that do define it.  Measured instance: every
#                 HAVE_{PRE,POST}_{INCREMENT,DECREMENT,MODIFY_DISP} reads 0, so
#                 `auto-inc-dec' finds no addressing form on ANY base.
#
# The second is the worse one to find by eye: nothing is wrong in any file, the
# pass runs, the dump is produced, and it is simply empty.
#
# THE MACRO LIST IS tm.texi's, NOT A GREP FOR CAPITALS.  `@defmac' is GCC's own
# statement of what a target macro is, so the census cannot be accused of
# having chosen its own population.  Names are word-anchored (PRINCIPLES: a
# sweep anchored loosely scored zero for twelve of fourteen entry points).
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a018835bbcfad2e28}/leak
mkdir -p "$O"
cd "$W/gcc"

# 1. the authority: every documented target macro
# THE CHARACTER CLASS WAS UPPERCASE-ONLY AND IT TRUNCATED THREE NAMES RATHER
# THAN SKIPPING THEM, WHICH IS THE DANGEROUS DIRECTION.
#
# `[A-Z_][A-Z_0-9]*' stops at the first lowercase letter, so it did not decline
# to match `@defmac Pmode' -- it matched `P'.  Five of tm.texi's @defmac names
# contain lowercase, and the old pattern turned three of them into short
# identifiers that are word-matched all over shared code:
#
#     @defmac Pmode                    ->  P            (80 "uses" in gcc/*.cc)
#     @defmac INVOKE__main             ->  INVOKE__
#     @defmac __builtin_saveregs  etc  ->  __
#
# So the census population contained three garbage names AND WAS MISSING
# `Pmode' -- the macro PRINCIPLES names first among the leaks this whole
# instrument exists to enumerate ("Pmode, ELIMINABLE_REGS, INIT_EXPANDERS,
# ACCUMULATE_OUTGOING_ARGS were each a file reading that list and not knowing
# it"), and the one behind riscv64 emitting 32-bit code in an ELF64 object.
# A census that cannot see its own headline example.
#
# Both halves are the same one-character bug and neither is visible in the
# total: `P' is spelled everywhere so it always classified into SOME bucket,
# and the non-vacuity arm asks only that its four named macros be classified.
sed -n 's/^@defmacx* \([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  doc/tm.texi | sort -u > "$O/macros.all"
# The three truncations must be GONE and the five real names PRESENT.  Stated
# as an arm rather than trusted, because the failure is silent in the total.
for bad in P __ INVOKE__; do
  grep -qx "$bad" "$O/macros.all" \
    && { echo "FATAL: truncated name '$bad' still in the macro list"; exit 9; }
done
for good in Pmode INVOKE__main __builtin_saveregs; do
  grep -qx "$good" "$O/macros.all" \
    || { echo "FATAL: '$good' missing from the macro list"; exit 9; }
done
N=$(wc -l < "$O/macros.all")
[ "$N" -gt 100 ] || { echo "FATAL: only $N macros from tm.texi -- the extraction is wrong"; exit 9; }
echo "tm.texi documents $N target macros"

# 2. target-INDEPENDENT sources: gcc/*.cc and gcc/*.h, never config/
ls *.cc *.h > "$O/ti.files" 2>/dev/null
echo "target-independent files scanned: $(wc -l < "$O/ti.files")"

# 3. the primary chain, read from the BUILD's own tm.h.
#
# TMH IS REQUIRED, AND THAT IS A FIX.  This step used to fall back to a
# hand-written nine-header list when no TMH was given, announced with a NOTE
# and then used exactly as if it were the real thing.  The list is INCOMPLETE:
# `config.gcc:1396' puts `glibc-stdint.h' in every `*-*-linux*' target's
# tm_file, and the fallback does not name it.  Measured on `4387bf9ce42':
#
#   with the fallback chain      LEAK-PRIMARY  88   DEAD-DEFAULT 208
#   with the build's real tm.h   LEAK-PRIMARY 119   DEAD-DEFAULT 177
#
# The 31 are exactly `glibc-stdint.h's `INT8_TYPE' .. `UINTPTR_TYPE' plus
# `SIG_ATOMIC_TYPE'.  They are LEAK-PRIMARY -- glibc's answers, served to all
# 47 back ends through `c-family/c-common.cc's `__INT32_TYPE__' and friends --
# and the fallback chain reported every one of them as DEAD-DEFAULT, i.e. as a
# DIFFERENT KIND OF DEFECT in a bucket the census describes as the harder half
# to find.  A wrong classification, not a missing row, so the total stayed 296
# and nothing looked amiss.
#
# That is this project's standing shape: a default that is not the answer,
# quietly substituted, reported in the same voice as a measurement.  So there
# is no default any more -- a census run without a real `tm.h' now fails BY
# NAME rather than producing a plausible wrong split.
TMH=${TMH:-}
[ -n "$TMH" ] || {
  echo "FATAL: set TMH=<builddir>/gcc/tm.h -- the primary chain must be read"
  echo "  from a real build, never assumed.  See the comment above this check:"
  echo "  the old hardcoded chain omitted glibc-stdint.h and misclassified 31"
  echo "  macros from LEAK-PRIMARY to DEAD-DEFAULT with no change in the total."
  exit 9
}
[ -f "$TMH" ] || { echo "FATAL: TMH=$TMH does not exist"; exit 9; }
sed -n 's|^# *include "\(config/[^"]*\)"|\1|p' "$TMH" > "$O/chain"
NC=$(wc -l < "$O/chain")
echo "primary chain from $TMH: $NC headers"
# NON-VACUITY ON THE CHAIN ITSELF.  An empty or truncated tm.h yields an empty
# chain, every macro then scores `p=no', and the census reports 100%
# DEAD-DEFAULT -- a clean-looking run with every row wrong in the same
# direction.  `test -s' would pass on it; a header count will not.
[ "$NC" -ge 5 ] || { echo "FATAL: only $NC headers in the chain; tm.h is truncated or not a tm.h"; exit 9; }

printf '%s\n' "$(cat "$O/chain")" | sed 's|^|./|' > "$O/chain.paths"

: > "$O/report"
while read -r m; do
  # used by target-independent code?  word-anchored.
  u=$(grep -lw "$m" $(cat "$O/ti.files") 2>/dev/null | wc -l)
  [ "$u" -gt 0 ] || continue
  # how many back ends DEFINE it?
  d=$(grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" config/ 2>/dev/null \
      | sed 's|^config/\([^/]*\)/.*|\1|' | sort -u | wc -l)
  [ "$d" -gt 0 ] || continue
  # does the PRIMARY chain define it?
  p=no
  for h in $(cat "$O/chain"); do
    [ -f "$h" ] || continue
    grep -qE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" "$h" && { p=yes; break; }
  done
  # ALREADY CONVERTED?  AND THERE IS NOT ONE AUTHORITY FOR THAT, WHICH IS THE
  # BRANCH'S OWN ROOT PATTERN BITING THIS SCRIPT.
  #
  # The first version subtracted only `multi-target-macros.h', on the reasoning
  # that it is "this branch's own record of which target macros it has moved to
  # run time".  It is one of several.  `REG_ALLOC_ORDER' (38 back ends) and
  # `ADJUST_REG_ALLOC_ORDER' were both reported as LEAK-PRIMARY here and both
  # are fully converted -- in `target-regs.h', which owns the register
  # vocabulary and says so in its header.  A macro converted through a
  # `target-*.h' descriptor never appears in `multi-target-macros.h' at all,
  # because its call sites were REWRITTEN rather than redirected; that is a
  # documented and deliberate choice for exactly the macros whose use sites are
  # `#ifdef' pairs.
  #
  # So the conversion record is spread over every `target-*.h', and a census
  # keyed on one of them inflates its own headline.  One name, several
  # authorities, no diagnostic -- the pattern this project keeps re-finding,
  # here in an instrument written to find it.
  # Two buckets, with different confidence, kept apart rather than merged:
  #
  #   REDIRECT    an `#undef X' / `#define X ...' pair in multi-target-macros.h.
  #               Unambiguous.
  #   DESCRIPTOR  the name appears in one of the `target-*.h' conversion
  #               headers.  Weaker -- those headers also DISCUSS macros they
  #               have not converted -- so it is reported separately and the
  #               leak count is given both with and without it.
  if grep -qE "^#[[:space:]]*(undef|define)[[:space:]]+$m\b" multi-target-macros.h 2>/dev/null; then
    printf 'REDIRECT\t%s\t%s\t%s\n' "$d" "$u" "$m" >> "$O/report.conv"
    continue
  fi
  if grep -qw "$m" target-*.h 2>/dev/null; then
    printf 'DESCRIPTOR\t%s\t%s\t%s\n' "$d" "$u" "$m" >> "$O/report.conv"
    continue
  fi
  if [ "$p" = yes ]; then k=LEAK-PRIMARY; else k=DEAD-DEFAULT; fi
  printf '%s\t%s\t%s\t%s\n' "$k" "$d" "$u" "$m" >> "$O/report"
done < "$O/macros.all"
echo "already handled: REDIRECT $(grep -c '^REDIRECT' "$O/report.conv" 2>/dev/null || echo 0), DESCRIPTOR $(grep -c '^DESCRIPTOR' "$O/report.conv" 2>/dev/null || echo 0)"

echo
echo "== macros documented by tm.texi, SPELLED by target-independent code,"
echo "== and DEFINED by at least one back end.  kind / #backends / #ti-files / name"
sort -k1,1 -k2,2nr "$O/report" | awk -F'\t' '{printf "%-14s %3s backends  %3s files  %s\n",$1,$2,$3,$4}'
echo
echo "TOTAL leaking macros: $(wc -l < "$O/report")"
echo "  LEAK-PRIMARY (x86's answer served to all): $(grep -c '^LEAK-PRIMARY' "$O/report")"
echo "  DEAD-DEFAULT (fallback served to all):     $(grep -c '^DEAD-DEFAULT' "$O/report")"
echo
# NON-VACUITY.  The arm used to be "these two must appear as LEAKS", which was
# true when written and became false the moment they were converted -- the
# script then printed FATAL about a tree that had been FIXED.  That is the same
# defect-as-pass-condition shape `-align.sh' had, in the instrument written to
# audit it.
#
# The invariant that does not expire is that the PIPELINE SEES them: each named
# macro must be classified into SOME bucket.  A macro that falls out of both is
# one the extraction, the use-scan or the back-end scan dropped, which is the
# failure this arm exists to catch.
echo "NON-VACUITY: each proven macro must be CLASSIFIED, as leak or as handled."
# INT32_TYPE is here because it is the macro that caught the chain bug: it must
# land in SOME bucket, and WHICH bucket is a function of whether the chain the
# census read is the real one.  Deliberately not asserted to be a leak -- that
# is the defect-as-pass-condition shape this arm was rewritten to avoid.
for m in ASM_OUTPUT_ALIGN HAVE_POST_MODIFY_DISP PROMOTE_MODE REG_ALLOC_ORDER \
         INT32_TYPE ASM_DECLARE_FUNCTION_SIZE; do
  r=$(grep -w "$m" "$O/report" "$O/report.conv" 2>/dev/null | head -1)
  if [ -n "$r" ]; then echo "  ok: $m -- $r"
  else echo "  FATAL: $m is in NEITHER bucket; the census dropped it"; fi
done
