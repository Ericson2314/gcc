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
sed -n 's/^@defmac \([A-Z_][A-Z_0-9]*\).*/\1/p;s/^@defmacx \([A-Z_][A-Z_0-9]*\).*/\1/p' \
  doc/tm.texi | sort -u > "$O/macros.all"
N=$(wc -l < "$O/macros.all")
[ "$N" -gt 100 ] || { echo "FATAL: only $N macros from tm.texi -- the extraction is wrong"; exit 9; }
echo "tm.texi documents $N target macros"

# 2. target-INDEPENDENT sources: gcc/*.cc and gcc/*.h, never config/
ls *.cc *.h > "$O/ti.files" 2>/dev/null
echo "target-independent files scanned: $(wc -l < "$O/ti.files")"

# 3. the primary chain, read from the BUILD's own tm.h rather than assumed
TMH=${TMH:-}
if [ -n "$TMH" ] && [ -f "$TMH" ]; then
  sed -n 's|^# *include "\(config/[^"]*\)"|\1|p' "$TMH" > "$O/chain"
  echo "primary chain from $TMH: $(wc -l < "$O/chain") headers"
else
  echo "NOTE: no TMH= given; primary chain taken as the i386 linux64 chain"
  printf 'config/i386/i386.h\nconfig/i386/att.h\nconfig/i386/unix.h\nconfig/i386/x86-64.h\nconfig/i386/gnu-user64.h\nconfig/i386/linux64.h\nconfig/elfos.h\nconfig/gnu-user.h\nconfig/linux.h\n' > "$O/chain"
fi

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
  # ALREADY CONVERTED?  multi-target-macros.h is this branch's own record of
  # which target macros it has moved to run time; a macro named there is
  # handled and must not be counted as a leak.  Subtracting it is what keeps
  # this an honest census rather than a scary number.
  if grep -qE "^#[[:space:]]*(undef|define)[[:space:]]+$m\b" multi-target-macros.h 2>/dev/null; then
    printf 'CONVERTED\t%s\t%s\t%s\n' "$d" "$u" "$m" >> "$O/report.conv"
    continue
  fi
  if [ "$p" = yes ]; then k=LEAK-PRIMARY; else k=DEAD-DEFAULT; fi
  printf '%s\t%s\t%s\t%s\n' "$k" "$d" "$u" "$m" >> "$O/report"
done < "$O/macros.all"
echo "already converted by multi-target-macros.h: $(wc -l < "$O/report.conv" 2>/dev/null || echo 0)"

echo
echo "== macros documented by tm.texi, SPELLED by target-independent code,"
echo "== and DEFINED by at least one back end.  kind / #backends / #ti-files / name"
sort -k1,1 -k2,2nr "$O/report" | awk -F'\t' '{printf "%-14s %3s backends  %3s files  %s\n",$1,$2,$3,$4}'
echo
echo "TOTAL leaking macros: $(wc -l < "$O/report")"
echo "  LEAK-PRIMARY (x86's answer served to all): $(grep -c '^LEAK-PRIMARY' "$O/report")"
echo "  DEAD-DEFAULT (fallback served to all):     $(grep -c '^DEAD-DEFAULT' "$O/report")"
echo
echo "NON-VACUITY: the two macros proven by measurement must appear above."
for m in ASM_OUTPUT_ALIGN HAVE_POST_MODIFY_DISP; do
  if grep -qw "$m" "$O/report"; then echo "  ok: $m present -- $(grep -w "$m" "$O/report")"
  else echo "  FATAL: $m ABSENT from the census, which is therefore not measuring what it claims"; fi
done
