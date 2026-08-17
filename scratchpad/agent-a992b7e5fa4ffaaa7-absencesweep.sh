#!/bin/sh
# absencesweep.sh -- THE THIRD CLASS, and the one nothing swept.
#
# A bare `#ifdef <NAME>' (or `#if defined') in a SHARED translation unit, where
# `<NAME>' is `#define'd by some back end and **NOT by i386**.  The primary's
# silence makes the conditional FALSE for all 47, so the guarded code never
# runs for anybody -- including the back ends that asked for it.
#
# NOTHING LEAKS A VALUE HERE, which is why a dump of the running `cc1' shows
# nothing wrong and why the existing instruments miss it: what is missing is a
# CALL THAT NEVER HAPPENS.  `d1ae5fb5969' found `FINAL_PRESCAN_INSN',
# `DELAY_SLOTS' and `GO_IF_LEGITIMATE_ADDRESS' this way BY HAND; this session
# found `TRAMPOLINE_SECTION' by compiling a nested function and diffing against
# stock.  Both routes are luck.  The class is mechanically enumerable.
#
# HOW IT DIFFERS FROM `floorsweep.sh', which is the sibling instrument:
#
#   floor-dead      #ifndef floor in defaults.h, primary DEFINES the name
#                   -> floor is dead, everyone gets the primary's body
#   floor-fires     #ifndef floor in defaults.h, primary SILENT
#                   -> dissenters read the floor
#   leaked absence  bare #ifdef in shared code, primary SILENT      <- HERE
#                   -> the guarded code runs for NOBODY
#
# The three are disjoint by construction and need different fixes, so they are
# not merged into one list.
#
# DELIBERATELY OVER-BROAD (PRINCIPLES 4: an instrument that can only take away
# should be too eager).  It emits CANDIDATES.  A name may be legitimately
# unused, already converted, or guarded for a reason.  The discriminator is
# the same as the floor sweep's: read what the compiler emits, both-sided
# against stock.
#
# CONTROLS.  It refuses unless it re-finds the four known members, because a
# sweep that reports a short clean list is indistinguishable from a broken one.
#
# usage: absencesweep.sh <srcdir>
set -eu
export LC_ALL=C
SRC=${1:?srcdir}
G="$SRC/gcc"
[ -d "$G/config" ] || { echo "FATAL: no $G/config"; exit 9; }

TD=$(mktemp -d) || exit 9
trap 'rm -rf "$TD"' 0

# 1. names i386 defines.  These are excluded: if the primary defines it the
#    conditional is TRUE and the bug is a different one (floor-dead).
grep -rh '^[ \t]*#[ \t]*define[ \t]\+[A-Za-z_][A-Za-z_0-9]*' "$G/config/i386" 2>/dev/null \
  | sed -n 's/^[ \t]*#[ \t]*define[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' \
  | sort -u > "$TD/i386"
[ "$(grep -c . "$TD/i386")" -gt 100 ] \
  || { echo "FATAL: only $(grep -c . "$TD/i386") i386 defines -- the sed did not match. REFUSING."; exit 9; }

# 2. names ANY back end defines.
grep -rh '^[ \t]*#[ \t]*define[ \t]\+[A-Za-z_][A-Za-z_0-9]*' "$G/config" 2>/dev/null \
  | sed -n 's/^[ \t]*#[ \t]*define[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' \
  | sort -u > "$TD/anybe"

# 3. back-end names the primary does NOT define.
comm -13 "$TD/i386" "$TD/anybe" > "$TD/nonprimary"

# 4. names a SHARED .cc/.h tests with #ifdef / #if defined.
#    Shared = gcc/*.cc and gcc/*.h -- NOT config/, NOT the generators' output.
#    `-w' matters: `#ifdef PRINT_OPERAND' must not match PRINT_OPERAND_ADDRESS.
: > "$TD/tested"
for f in "$G"/*.cc "$G"/*.h "$G"/c/*.cc "$G"/c-family/*.cc; do
  [ -f "$f" ] || continue
  sed -n -e 's/^[ \t]*#[ \t]*ifdef[ \t]\+\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' \
         -e 's/^[ \t]*#[ \t]*if[ \t]\+defined[ \t]*(\?[ \t]*\([A-Za-z_][A-Za-z_0-9]*\).*$/\1/p' \
         "$f"
done | sort -u > "$TD/tested"
[ "$(grep -c . "$TD/tested")" -gt 50 ] \
  || { echo "FATAL: only $(grep -c . "$TD/tested") tested names -- REFUSING."; exit 9; }

comm -12 "$TD/nonprimary" "$TD/tested" > "$TD/class"
echo "back-end names the primary does NOT define: $(grep -c . "$TD/nonprimary")"
echo "names a shared TU tests with #ifdef:        $(grep -c . "$TD/tested")"
echo "THE LEAKED-ABSENCE CLASS:                   $(grep -c . "$TD/class")"
echo

# CONTROL.  Four known members must reappear.  A sweep that cannot re-find the
# defects it was built from is broken, and its short list would read as clean.
miss=""
for k in FINAL_PRESCAN_INSN DELAY_SLOTS GO_IF_LEGITIMATE_ADDRESS TRAMPOLINE_SECTION; do
  grep -qx "$k" "$TD/class" || miss="$miss $k"
done
if [ -n "$miss" ]; then
  echo "FATAL: known members missing from the class:$miss"
  echo "  (DELAY_SLOTS is expected to be absent -- it is a 0/1 VALUE tested with"
  echo "   'if', not '#ifdef', which is the detection gap d1ae5fb5969 records."
  echo "   If it is the ONLY one missing that is correct; anything else is a bug.)"
  case "$miss" in
    " DELAY_SLOTS") echo "  -> only DELAY_SLOTS: EXPECTED, continuing." ;;
    *) exit 9 ;;
  esac
else
  echo "CONTROL ok: all four known members are in the class"
fi
echo

printf '%-40s %-9s %s\n' NAME DEFINERS 'SHARED TUs THAT TEST IT'
while read -r n; do
  [ -n "$n" ] || continue
  nd=$(grep -rlw --include='*.h' "^[ \t]*#[ \t]*define[ \t]\+$n\b" "$G/config" 2>/dev/null | wc -l)
  users=$(grep -lw -e "#ifdef $n" -e "defined ($n)" -e "defined($n)" \
            "$G"/*.cc "$G"/*.h 2>/dev/null | xargs -r -n1 basename | tr '\n' ' ')
  printf '%-40s %-9s %s\n' "$n" "$nd" "$users"
done < "$TD/class"

echo
echo "CANDIDATES, not verdicts.  Discriminate each by compiling a program that"
echo "reaches the guarded code and diffing against the stock compiler for that"
echo "target -- which is how TRAMPOLINE_SECTION was found and is the only arm"
echo "that distinguishes 'never runs' from 'correctly does nothing here'."
