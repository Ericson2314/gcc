#!/bin/sh
# Census of `use_gcc_stdint' over EVERY triple in contrib/config-list.mk --
# the same list `--enable-backends=all' expands to -- sourcing config.gcc once
# per triple exactly as gen-target-manifest.sh does.
#
# THE QUESTION IS NOT "does it vary".  It plainly does: none / wrap / provide,
# and gcc/Makefile.in's stmp-int-hdrs writes ONE include/stdint.h from
# @use_gcc_stdint@, which is the primary triple's answer for everybody.  The
# question is WHAT IT IS A PROPERTY OF, because that decides where the fix can
# live:
#
#   - if it is constant across a back end's triples, it is a property of the
#     back end and include-<cpu>/ can hold it, exactly as #189's extra_headers
#     does;
#   - if it varies WITHIN one back end, no per-back-end directory can express
#     it, and the fact belongs to the deployed target rather than to the
#     compiler -- the specs-config / include-fixed category.
#
# Prints, per cpu_type, the set of values its triples ask for.  Non-vacuity:
# refuses if it read fewer than 100 triples.
S=$1
: ${S:?srcdir}
OUT=${2:?outfile}
LIST=`sed -n '/^LIST = /,/^ *$/p' $S/contrib/config-list.mk \
      | sed -e 's/^LIST = //' | tr -d '\134' | tr ' ' '\012' \
      | sed -e 's/OPT.*$//' | grep . | sort -u`
: > $OUT
for t in $LIST; do
  (
    cd $S/gcc
    srcdir=.
    target=`../config.sub $t 2>/dev/null` || exit 0
    test x"$target" = x && exit 0
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    cxx_target_objs= extra_gcc_objs= extra_parts= extra_modes=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2=
    use_gcc_stdint=
    TM_MULTILIB_CONFIG=
    . ./config.gcc > /dev/null 2>&1 || exit 0
    echo "$cpu_type ${use_gcc_stdint:-EMPTY} $t"
  ) >> $OUT
done
n=`grep -c . $OUT`
if test "$n" -lt 100; then
  echo "REFUSE: read only $n triples; the census did not run" >&2
  exit 9
fi
echo "triples $n"
echo "values over all triples:"
awk '{print $2}' $OUT | sort | uniq -c
echo
echo "per back end -- CONSTANT means every triple of that back end agrees:"
awk '{ v[$1] = v[$1] " " $2 }
     END { for (c in v) {
             n = split(v[c], a, " "); u = "";
             for (i = 1; i <= n; i++)
               if (index(" " u " ", " " a[i] " ") == 0) u = u " " a[i];
             m = split(u, b, " ");
             printf "%s %s [%s]\n", (m > 1 ? "VARIES " : "CONSTANT"), c, u;
           } }' $OUT | sort
echo
echo "back ends whose triples DISAGREE:"
awk '{ v[$1] = v[$1] " " $2 }
     END { for (c in v) {
             n = split(v[c], a, " "); u = "";
             for (i = 1; i <= n; i++)
               if (index(" " u " ", " " a[i] " ") == 0) u = u " " a[i];
             if (split(u, b, " ") > 1) k++;
           } print k+0 }' $OUT
