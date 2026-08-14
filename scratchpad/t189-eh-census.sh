#!/bin/sh
# Census of extra_headers over all 47 back ends, sourcing config.gcc once per
# triple exactly as gen-target-manifest.sh does.  Prints "<cpu> <file>" lines.
S=$1
: ${S:?srcdir}
for t in `grep -v '^#' $S/scratchpad/backends-47.txt | grep .`; do
  (
    cd $S/gcc
    srcdir=.
    target=`../config.sub $t`
    tm_defines= cpu_type= target_cpu_default=
    tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs=
    cxx_target_objs= d_target_objs= fortran_target_objs= rust_target_objs=
    extra_gcc_objs= extra_parts= extra_modes=
    out_file= md_file= target_gtfiles=
    common_out_file= target_has_targetm_common= dwarf2=
    TM_MULTILIB_CONFIG=
    . ./config.gcc > /dev/null 2>&1 || exit 0
    for f in $extra_headers; do echo "$cpu_type $f"; done
  )
done > $2
