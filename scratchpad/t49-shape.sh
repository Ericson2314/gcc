#!/bin/sh
# #49 -- classify each always-true site by SHAPE, because two shapes look
# identical to a name-matching grep and only one is a defect.
#
#   DEAD-FLOOR   #ifndef X / #define X 0 / #endif
#                defaults.h already defines X as (targ_caps....), so the #ifndef
#                is FALSE and the floor never fires.  The consuming code below
#                it reads the runtime value correctly.  Dead code, not a bug --
#                the same shape PRINCIPLES records for final.cc:101 and
#                JUMP_TABLES_IN_TEXT_SECTION.
#
#   ALWAYS-ON    #ifdef X ... [#else ...] #endif  guarding real code
#                The macro IS defined, so the guard is unconditionally taken and
#                the runtime value is NEVER CONSULTED.  target-specs probes the
#                capability, writes it into the target-config file, and nothing
#                reads it: mechanism present, never invoked.  This is the defect.
#
# usage: t49-shape.sh <gcc-srcdir> <file:NAME> ...
set -e
G=$(cd "${1:?gcc srcdir}" && pwd)
shift
[ $# -gt 0 ] || { echo "FATAL: no sites given; refusing to score"; exit 9; }
nfloor=0; non=0
for s in "$@"; do
  f=${s%%:*}; n=${s##*:}
  [ -f "$G/$f" ] || { echo "FATAL: $G/$f does not exist"; exit 9; }
  ln=$(grep -nE "^[[:space:]]*#[[:space:]]*(ifdef|ifndef)[[:space:]]+$n\b" "$G/$f" | head -1 | cut -d: -f1)
  [ -n "$ln" ] || { echo "FATAL: no #ifdef/#ifndef $n in $f; the site list is stale"; exit 9; }
  kw=$(sed -n "${ln}p" "$G/$f" | grep -oE 'ifn?def')
  nxt=$(sed -n "$((ln+1))p" "$G/$f")
  if [ "$kw" = ifndef ] && echo "$nxt" | grep -qE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$n\b"; then
    verdict=DEAD-FLOOR; nfloor=$((nfloor+1))
  else
    verdict=ALWAYS-ON; non=$((non+1))
  fi
  printf '%-12s %-44s %s:%s\n' "$verdict" "$n" "$f" "$ln"
done
echo
echo "== ALWAYS-ON (runtime capability never consulted): $non"
echo "== DEAD-FLOOR (benign, floor never fires):         $nfloor"
