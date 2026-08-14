#!/bin/sh
# t189-rootcost.sh -- SIZE THE ROOT, do not attempt it blind.
#
# `gcc/configure.ac' sources config.gcc once, for the legacy ${target}, and
# every per-back-end list it sets is therefore the primary's.  Four have been
# fixed one at a time (tmake_file, extra_objs, PASSES_EXTRA, extra_headers).
# The question the brief asks is whether that single pass can be made per base.
#
# This prints the two numbers that decide it:
#   A. how many of config.gcc's variables reach gcc/Makefile.in at all, and
#      which of those the per-target manifest already records;
#   B. for each variable NOT yet per target, how many times configure.ac reads
#      it AFTER the config.gcc line -- i.e. the shell logic that would have to
#      move, not just an AC_SUBST to redirect.  A variable read 0 times is a
#      pure pass-through: one `echo' in gen-target-manifest.sh and an
#      accumulator, the extra_headers shape.  A variable read many times has
#      configure logic built on it and is a real piece of work.
set -u
S=${1:?srcdir}/gcc
cd "$S" || exit 9
L=$(grep -n '^\. \${srcdir}/config\.gcc' configure.ac | head -1 | cut -d: -f1)
[ -n "$L" ] || { echo "FATAL: cannot find the config.gcc line"; exit 9; }
echo "config.gcc is sourced at configure.ac:$L"

grep -oE '^[[:space:]]*echo "[a-z_0-9]+ ' gen-target-manifest.sh \
  | sed 's/.*echo "//;s/ $//' | sort -u > /tmp/rc-mf.$$
grep -oE '@[a-zA-Z_][a-zA-Z0-9_]*@' Makefile.in | tr -d '@' | sort -u > /tmp/rc-sub.$$
grep -oE '^[	 ]*[a-zA-Z_][a-zA-Z0-9_]*=' config.gcc | tr -d ' \t=' | sort -u > /tmp/rc-cg.$$

echo
echo "state  reads-after-$L  variable  ->  substitution"
for v in $(cat /tmp/rc-cg.$$); do
  hit=$(grep -E "^${v}(_list|_file|_file_list|_include_list)?$" /tmp/rc-sub.$$ | tr '\n' ',' | sed 's/,$//')
  [ -z "$hit" ] && continue
  if grep -qx "$v" /tmp/rc-mf.$$; then st="PER-TARGET"; else st="ONCE      "; fi
  n=$(awk -v l="$L" 'NR>l' configure.ac | grep -cE "[$]\{?${v}[}\" ]")
  printf "%s  %3d  %s  ->  @%s@\n" "$st" "$n" "$v" "$hit"
done | sort -k1,1 -k2,2nr
rm -f /tmp/rc-mf.$$ /tmp/rc-sub.$$ /tmp/rc-cg.$$
