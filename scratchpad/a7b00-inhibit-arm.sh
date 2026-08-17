#!/bin/sh
# ACCEPTANCE ARM 4 (#226's inhibit_libc guard), MEASURED IN BOTH DIRECTIONS.
#
# `-Dinhibit_libc' removes libc-dependent code from libgcc WITH NO CHANGE TO ANY
# INSTALLED FILE NAME, so a crippled libgcc and a good one are told apart only
# by their symbol tables.  This prints both builds side by side; the control is
# what makes the positive result mean anything.
#
# THREE OF THE BRIEF'S FOUR NAMED SYMBOLS ARE WRONG FOR THIS TARGET AND ARE
# REPORTED AS SUCH RATHER THAN QUIETLY DROPPED:
#   * `__splitstack_*' is i386-only.  generic-morestack.c is pulled in by
#     config/i386/t-stack, no aarch64 tmake fragment has it, so 0 here is
#     CORRECT and is not evidence about libc either way.  Counting it as a
#     failure would condemn a good library; counting it as a pass on a target
#     that has it would be worse.
#   * `dl_iterate_phdr' is the OLD spelling of the FDE-via-program-headers
#     path.  On glibc 2.35+ unwind-dw2-fde-dip.c uses `_dl_find_object', so the
#     path is present under a different name.  Both are counted.
# usage: a7b00-inhibit-arm.sh <libc build dir> <no-libc build dir> <nm>
set -u
A=${1:?with-libc build}; B=${2:?inhibit_libc build}; NM=${3:?nm}

count () { # $1 dir, $2 archive, $3 pattern
  [ -f "$1/$2" ] || { echo -; return; }
  "$NM" "$1/$2" 2>/dev/null | grep -c -- "$3"
}

printf '%-34s %-12s %-12s\n' 'symbol / archive' 'with libc' 'inhibit_libc'
for row in \
  '_dl_find_object|libgcc_eh.a|_dl_find_object' \
  'dl_iterate_phdr|libgcc_eh.a|dl_iterate_phdr' \
  '__gcov_*|libgcov.a|__gcov_' \
  '__splitstack_*|libgcc.a|__splitstack_' \
  'malloc (libc use at all)|libgcc_eh.a|U malloc' \
  ; do
  name=`echo "$row" | cut -d'|' -f1`
  ar=`echo "$row" | cut -d'|' -f2`
  pat=`echo "$row" | cut -d'|' -f3`
  printf '%-34s %-12s %-12s\n' "$name ($ar)" "`count $A $ar \"$pat\"`" "`count $B $ar \"$pat\"`"
done
echo
echo "archive sizes (bytes):"
for ar in libgcc.a libgcc_eh.a libgcov.a; do
  sa=`[ -f "$A/$ar" ] && wc -c < "$A/$ar" || echo -`
  sb=`[ -f "$B/$ar" ] && wc -c < "$B/$ar" || echo -`
  printf '  %-14s with libc %-10s inhibit_libc %-10s\n' "$ar" "$sa" "$sb"
done
echo
echo "FILE NAMES INSTALLED -- the point of the arm: identical lists mean the"
echo "difference is invisible to any check that looks at names."
la=`ls "$A"/*.a "$A"/crt*.o 2>/dev/null | xargs -n1 basename | sort | tr '\n' ' '`
lb=`ls "$B"/*.a "$B"/crt*.o 2>/dev/null | xargs -n1 basename | sort | tr '\n' ' '`
echo "  with libc   : $la"
echo "  inhibit_libc: $lb"
if [ "$la" = "$lb" ]; then echo "  -> IDENTICAL, as expected."; else echo "  -> they differ."; fi
