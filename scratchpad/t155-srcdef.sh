#!/bin/sh
# #155 -- SOURCE-level definer census for a name, across gcc/config/.
#
# The authority for the collision set is `nm' over the built objects
# (t155-rename-gap.sh).  This is the complement: it says WHICH SOURCE spells
# the name and whether the definition is `static'.  That distinction is the
# whole difference between a collision and a non-collision -- two agents got
# `extract_base_offset_in_addr' wrong on exactly this point -- and it is not
# visible in nm output, which shows only what survived.
#
# It also answers the OTHER half of the decision rule: does any SHARED
# translation unit (outside gcc/config/) name the bare symbol?  If yes the
# middle end must choose and a rename only moves the failure; if no, a bare
# MULTI_TARGET_RENAME_NAMES entry is the whole fix.
#
# usage: t155-srcdef.sh <name> [name...]
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
[ -d "$G/config" ] || { echo "FATAL: $G/config missing"; exit 9; }

for n in "$@"; do
  echo "===== $n"
  # A definition at column 0 with the name first: the return type is on the
  # PREVIOUS line in GNU style, so print that line too to see `static'.
  echo "-- definitions under gcc/config/ (prev line shows storage class)"
  find "$G/config" -name '*.cc' -o -name '*.c' | sort | while read -r f; do
    awk -v F="$f" -v N="$n" '
      $0 ~ "^" N "[ \t]*\\(" || $0 ~ "^" N "[ \t]*\\[" || $0 ~ "^" N "[ \t]*=" {
        printf "   %s:%d  [%s] %s\n", F, NR, prev, $0 }
      { prev = $0 }' "$f"
  done
  echo "-- SHARED TUs (outside gcc/config/) that spell the bare name"
  grep -rlw "$n" "$G" --include='*.cc' --include='*.c' --include='*.h' 2>/dev/null \
    | grep -v "^$G/config/" | grep -v '/testsuite/' | sed "s|^$G/|   |"
done
