#!/bin/sh
# WHICH BACK ENDS LEAK MACROS THROUGH THE SHARED options.h, AND HOW MANY.
#
# The union options.h pulls in every back end's config/<cpu>/<cpu>-opts.h
# through the `I' records.  Those headers are back-end-private by convention
# and nothing enforces it, so any object-like macro one of them defines is
# defined for EVERY back end -- and the first definition wins, with only a
# `redefined' warning if another back end defines it too.
#
# config/loongarch/loongarch-opts.h defines TARGET_64BIT, TARGET_HARD_FLOAT,
# TARGET_DOUBLE_FLOAT and TARGET_TLS_DESC in terms of `la_target', a loongarch
# global.  Every other back end therefore sees loongarch's TARGET_64BIT, and
# uses of it that precede the back end's own #define expand to `la_target.…',
# which does not parse.
#
# This reports the whole distribution rather than the back end that happened
# to fail first.  A name is counted only if it is defined in MORE than one
# place under config/, or is one of the well-known target macros -- a
# <cpu>-opts.h macro that nobody else defines is not evidence of a clash.
#
# usage: mtN-optsleak.sh <gcc-srcdir> [manifest]
set -e
S=${1:?gcc srcdir}
[ -d "$S/config" ] || { echo "FATAL: $S/config is not a directory"; exit 9; }

tmp=${TMPDIR:-/tmp}/mtN-optsleak.$$
trap 'rm -f "$tmp".*' 0

# Every object-like macro defined by any config/*/*-opts.h.
for f in "$S"/config/*/*-opts.h; do
  cpu=$(basename "$(dirname "$f")")
  sed -n 's/^[ \t]*#[ \t]*define[ \t]\{1,\}\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' "$f" \
    | sort -u | sed "s|^|$cpu |"
done > "$tmp".defs
[ -s "$tmp".defs ] || { echo "FATAL: no macros read from any <cpu>-opts.h"; exit 9; }

echo "=== macros defined by a <cpu>-opts.h AND by some other back end's headers"
echo "    (these are the ones the shared options.h can answer for everybody)"
echo
while read -r cpu m; do
  # Where else is this name defined under config/, outside this back end?
  others=$(grep -rl "^[ 	]*#[ 	]*define[ 	]\{1,\}$m\b" "$S"/config/ \
           | sed "s|$S/config/||" | cut -d/ -f1 | sort -u | grep -v "^$cpu\$" | tr '\n' ' ')
  if [ -n "$others" ]; then
    printf '%-12s %-28s also defined by: %s\n' "$cpu" "$m" "$others"
  fi
done < "$tmp".defs

echo
echo "=== totals"
printf 'macros defined across all <cpu>-opts.h: %s\n' "$(wc -l < "$tmp".defs)"
printf 'back ends with a <cpu>-opts.h:          %s\n' \
  "$(awk '{print $1}' "$tmp".defs | sort -u | wc -l)"
