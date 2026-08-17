#!/bin/sh
# Source gcc/config.gcc for an arbitrary triple, OUTSIDE any build directory,
# and print the four values the top-level rule currently awks out of
# `gcc/multi-target.manifest', plus the three `mkconfig.sh' inputs.
# usage: a302b44ba-t249-derive.sh <gcc-srcdir> <triple>
set -eu
S=${1:?gcc srcdir}; T=${2:?triple}
target=`sh "$S/../config.sub" "$T"`
set +u
tm_defines= cpu_type= target_cpu_default=
tm_file= tm_p_file= tmake_file=
extra_objs= extra_options= extra_headers= c_target_objs=
cxx_target_objs= d_target_objs= rust_target_objs= jit_target_objs=
fortran_target_objs= extra_gcc_objs=
out_file= md_file= target_gtfiles=
common_out_file= target_has_targetm_common= dwarf2= extra_modes=
use_gcc_tgmath= use_gcc_stdint= TM_MULTILIB_CONFIG=
target_option_defaults= target_decimal_float= target_decimal_bid_format=
. "$S/config.gcc" > /dev/null
test x"${tm_file}" = x && tm_file=${cpu_type}/${cpu_type}.h
incl="options.h insn-constants.h"
for f in ${tm_file}; do
  case $f in
    ./*) incl="$incl `echo $f | sed 's|^\./||'`" ;;
    defaults.h) incl="$incl $f" ;;
    *) incl="$incl config/$f" ;;
  esac
done
tfp=
for tf in ${tmake_file}; do
  test -f "$S/config/$tf" && tfp="$tfp $tf"
done
echo "canon_target ${target}"
echo "cpu_type ${cpu_type}"
echo "option_defaults ${target_option_defaults}"
echo "decimal_float ${target_decimal_float}"
echo "decimal_bid_format ${target_decimal_bid_format}"
echo "tmake_file_present ${tfp}"
echo "target_cpu_default ${target_cpu_default}"
echo "tm_defines ${tm_defines}"
echo "tm_include_list ${incl}"
