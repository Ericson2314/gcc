#!/bin/sh
# TASK 261 MEASUREMENT.  Produce a triple's `tm-<key>.h' from SOURCE ONLY --
# gcc/config.gcc plus gcc/mkconfig.sh -- for a triple that was NOT configured
# when gcc was built.  If this works, the per-triple half of
# install-target-headers has no reason to be shipped by gcc's `install'.
#
# usage: t261-ondemand-tm.sh <srcdir/gcc> <triple> <outdir>
set -eu
S=${1:?gcc srcdir}; T=${2:?triple}; O=${3:?outdir}
mkdir -p "$O"
key=`echo "$T" | sed 's/[^A-Za-z0-9_]/_/g'`

data=`
  set +u
  target=\`sh "$S/../config.sub" "$T"\`
  tm_defines= cpu_type= target_cpu_default=
  tm_file= tm_p_file= tmake_file=
  extra_objs= extra_options= extra_headers= c_target_objs=
  cxx_target_objs= d_target_objs= rust_target_objs= jit_target_objs=
  fortran_target_objs= extra_gcc_objs=
  out_file= md_file= target_gtfiles=
  common_out_file= target_has_targetm_common= dwarf2= extra_modes=
  use_gcc_tgmath= use_gcc_stdint= TM_MULTILIB_CONFIG=
  . "$S/config.gcc" > /dev/null || exit 1
  test x"\${tm_file}" = x && tm_file=\${cpu_type}/\${cpu_type}.h
  incl="options.h insn-constants.h"
  for f in \${tm_file}; do
    case \$f in
      ./*) incl="\$incl \`echo \$f | sed 's|^\./||'\`" ;;
      defaults.h) incl="\$incl \$f" ;;
      *) incl="\$incl config/\$f" ;;
    esac
  done
  echo "CPU \${cpu_type}"
  echo "TCD \${target_cpu_default}"
  echo "INC \$incl"
  echo "DEF \${tm_defines}"
` || { echo "config.gcc FAILED for $T"; exit 1; }

cpu=`echo "$data" | sed -n 's/^CPU //p'`
tcd=`echo "$data" | sed -n 's/^TCD //p'`
inc=`echo "$data" | sed -n 's/^INC //p'`
def=`echo "$data" | sed -n 's/^DEF //p'`
test -n "$cpu" || { echo "no cpu_type for $T"; exit 1; }
echo "cpu_type: $cpu"

cd "$O"
TARGET_CPU_DEFAULT="$tcd" HEADERS="$inc" DEFINES="$def" INSN_BASE="$cpu" \
  sh "$S/mkconfig.sh" "tm-$key.h"
echo "wrote $O/tm-$key.h"
