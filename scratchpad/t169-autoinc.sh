#!/bin/sh
# #169 / #162 -- AUTO_INC_DEC, measured over the 48 real header chains.
#
# rtl.h:2901 reads
#
#   #if (defined (HAVE_PRE_INCREMENT) || defined (HAVE_PRE_DECREMENT)  \
#        || defined (HAVE_POST_INCREMENT) || ... eight in all)
#   #define AUTO_INC_DEC 1
#   #else
#   #define AUTO_INC_DEC 0
#
# The eight come from `insn-flags-<base>.h', which genflags writes from that
# back end's `.md'.  rtl.h is SHARED, so it is preprocessed once, against the
# primary's chain.  This prints, per base, whether ANY of the eight is defined
# -- i.e. what AUTO_INC_DEC would be if that base's headers were the ones read.
#
# usage: t169-autoinc.sh <dumpdir>
set -u
O=${1:?dump dir}
[ -s "$O/bases" ] || { echo "FATAL: no $O/bases"; exit 9; }
FAM="HAVE_PRE_INCREMENT HAVE_PRE_DECREMENT HAVE_POST_INCREMENT HAVE_POST_DECREMENT
     HAVE_PRE_MODIFY_DISP HAVE_POST_MODIFY_DISP HAVE_PRE_MODIFY_REG HAVE_POST_MODIFY_REG"

Y=0; N=0; YES=""; NO=""
for b in $(cat "$O/bases"); do
  [ -s "$O/$b.m" ] || { echo "FATAL: $O/$b.m missing or empty"; exit 9; }
  hit=0
  for m in $FAM; do
    grep -q "^$m	" "$O/$b.m" && hit=1
  done
  if [ "$hit" = 1 ]; then Y=$((Y+1)); YES="$YES $b"; else N=$((N+1)); NO="$NO $b"; fi
done
[ $((Y+N)) -ge 40 ] || { echo "FATAL: scored only $((Y+N)) bases"; exit 9; }
echo "AUTO_INC_DEC would be 1 for $Y back ends, 0 for $N (of $((Y+N)))"
echo "  1:$YES"
echo "  0:$NO"
echo
echo "per-macro definer counts:"
for m in $FAM; do
  c=$(grep -l "^$m	" "$O"/*.m | grep -c . || true)
  i=no; grep -q "^$m	" "$O/i386.m" && i=yes
  a=no; grep -q "^$m	" "$O/aarch64.m" && a=yes
  printf '  %-24s definers=%-3s i386=%-4s aarch64=%s\n' "$m" "$c" "$i" "$a"
done
echo
echo "WHAT THE SHARED rtl.h ACTUALLY COMPUTES: the primary is i386, so"
echo "AUTO_INC_DEC is $(grep -lq . /dev/null; if [ -n "$(for m in $FAM; do grep -l "^$m	" "$O/i386.m"; done)" ]; then echo 1; else echo 0; fi) for EVERY configured back end."
