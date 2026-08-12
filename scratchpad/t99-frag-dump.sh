#!/bin/sh
# Dump, for every --enable-backends=all target: cpu_type, tmake_file(present),
# extra_objs, c_target_objs, out_file
srcdir=$1
LIST=`sed -n '/^LIST = /,/^ *$/p' ${srcdir}/../contrib/config-list.mk \
  | sed -e 's/^LIST = //' | tr -d '\134' | tr ' ' '\012' | sed -e 's/OPT.*$//' \
  | grep . | sort -u | tr '\012' ' '`
for t in $LIST; do
  tc=`${srcdir}/../config.sub $t 2>/dev/null`
  test -n "$tc" || continue
  (
    target=$tc
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2= extra_modes=
    TM_MULTILIB_CONFIG=
    . ${srcdir}/config.gcc >/dev/null 2>&1 || exit 0
    test x"${out_file}" = x && out_file=${cpu_type}/${cpu_type}.cc
    p=
    for f in ${tmake_file}; do
      test -f ${srcdir}/config/${f} && p="$p $f"
    done
    echo "${tc}|${cpu_type}|${p}|${extra_objs}|${c_target_objs}|${out_file}"
  )
done
