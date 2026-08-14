#!/bin/sh
# #165 -- IS `MULTI_TARGET_RENAME_NAMES' COMPLETE FOR N BASES?
# Copy of t157-rename-gap.sh with this worktree's build-dir assertion; see that
# file for the argument.  The one substantive addition is the STAMP CHECK:
# this sweep reads objects, and a build that was still running when the objects
# were read is a partial object set, which is a partial collision set -- and a
# SMALLER collision count reads exactly like success (PRINCIPLES 4).
#
# usage: t165-rename-gap.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-a6d52805fa9679fb1*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"

# THE STAMP.  Refuse to score objects from a build that has not returned.
[ -f "$B/make-cc1.rc" ] \
  || { echo "REFUSING TO SCORE: $B/make-cc1.rc absent -- the build has not returned"; exit 9; }
echo "arm 0a ok: build stamped rc=$(cat "$B/make-cc1.rc")"

bases=$(ls -d "$G"/mt-* 2>/dev/null | sed 's|.*/mt-||')
nb=$(printf '%s\n' "$bases" | grep -c . || true)
[ "$nb" -ge 2 ] || { echo "REFUSING TO SCORE: found $nb base dirs under $G"; exit 9; }
echo "arm 0b ok: $nb configured bases: $(printf '%s ' $bases)"

tot=0
for b in $bases; do
  sh "$S/eb-shell.sh" "cd $G && nm -C --defined-only mt-$b/*.o 2>/dev/null" \
    | awk '$2 ~ /^[TDBR]$/ { $1=""; $2=""; sub(/^  /,""); print }' \
    | sort -u > "$B/t165-syms-$b.txt"
  n=$(grep -c . "$B/t165-syms-$b.txt" || true)
  echo "  $b: $n global definitions"
  tot=$((tot + n))
done
[ "$tot" -gt 0 ] || { echo "REFUSING TO SCORE: nm read nothing (not in the shell?)"; exit 9; }

echo
echo "== names defined by MORE THAN ONE base (the collision set)"
cat "$B"/t165-syms-*.txt | sort | uniq -d > "$B/t165-collisions.txt"
nc=$(grep -c . "$B/t165-collisions.txt" || true)
echo "  $nc colliding names over $nb bases"
sed 's/^/    /' "$B/t165-collisions.txt"
echo
np=$(grep -c '^mt_probe_' "$B/t165-collisions.txt" || true)
echo "  of which $np are the deliberate MULTI_TARGET_REG_PROBES (mt_probe_*,"
echo "  compiled and never linked, so benign); REAL = $((nc - np))"
echo
echo "NOTE: ld reports only the subset whose archive members are both pulled"
echo "in.  This sweep is the authority; the linker is an UNDER-count of it."
