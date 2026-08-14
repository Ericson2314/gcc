#!/bin/sh
# a446b256f0b8bb99c-dwarf-authority.sh -- which target macros does dwarf2cfi.cc
# read, and for each: does i386 define it, does aarch64, does defaults.h supply
# a floor, and has this branch converted it?
#
# The shape being hunted is the branch's own root bug in the CFI layer:
#   (a) BOTH bases define it, values differ, shared code gets i386's; or
#   (b) i386 does NOT define it, so defaults.h's `#ifndef' floor becomes the
#       value EVERYONE gets -- a leaked ABSENCE, which is what
#       CASE_VECTOR_PC_RELATIVE was.
#
# Prints one row per macro so the reader can see WHICH macro disagrees;
# a summed count would find the same thing and tell nobody where to look.
set -eu
G=${1:?gcc srcdir}
cd "$G"

names=$(grep -ohE '\b[A-Z][A-Z0-9_]{4,}\b' dwarf2cfi.cc | sort -u)

# Non-vacuity: the scan must find a macro it is known to read.
echo "$names" | grep -qx 'INCOMING_FRAME_SP_OFFSET' \
  || { echo "FATAL: name scan did not find INCOMING_FRAME_SP_OFFSET"; exit 9; }

printf '%-34s %-6s %-8s %-9s %s\n' MACRO i386 aarch64 defaults.h converted
for n in $names; do
  i=$(grep -lE "^[ 	]*#[ 	]*define[ 	]+$n\b" config/i386/*.h 2>/dev/null | head -1)
  a=$(grep -lE "^[ 	]*#[ 	]*define[ 	]+$n\b" config/aarch64/*.h 2>/dev/null | head -1)
  d=$(grep -cE "^[ 	]*#[ 	]*define[ 	]+$n\b" defaults.h 2>/dev/null || true)
  c=$(grep -cE "^[ 	]*#[ 	]*define[ 	]+$n\b" multi-target-macros.h 2>/dev/null || true)
  # Only interesting if some back end or defaults.h defines it at all.
  [ -n "$i$a" ] || [ "$d" != 0 ] || continue
  printf '%-34s %-6s %-8s %-9s %s\n' "$n" \
    "$([ -n "$i" ] && echo yes || echo NO)" \
    "$([ -n "$a" ] && echo yes || echo NO)" \
    "$([ "$d" != 0 ] && echo floor || echo -)" \
    "$([ "$c" != 0 ] && echo CONVERTED || echo '** NOT **')"
done
