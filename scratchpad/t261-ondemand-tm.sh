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
  # THIS PROTOTYPE IS INCOMPLETE ON PURPOSE NO LONGER -- it WAS incomplete, and
  # the incompleteness is the whole of the "output differed in three lines"
  # result this script originally reported.  config.gcc is not the last word:
  # gcc/configure.ac appends three headers AFTER it returns, and none is probed.
  #   :1818  tm_file="${tm_file} initfini-array.h"   (unconditional)
  #   :1821  tm_file="$tm_file tm-dwarf2.h"          (if config.gcc said dwarf2=yes)
  #   :2035  tm_file="${tm_file} defaults.h"         (unconditional)
  # It also defaults tmake_file at :1814 to <cpu>/t-<cpu>, which this script does
  # not use but the real derivation in target-specs/configure.ac does: omitting
  # THAT made pdp11-aout -- whose config.gcc arm sets no tmake_file -- come out
  # "unsupported" with gcc/config/pdp11/t-pdp11 sitting right there.
  tm_file="\${tm_file} initfini-array.h"
  test x"\${dwarf2}" = xyes && tm_file="\${tm_file} tm-dwarf2.h"
  tm_file="\${tm_file} defaults.h"
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

# THE PER-BASE REWRITE, WHICH IS NOT PART OF tm_include_list AND IS EASY TO MISS.
# `mkconfig.sh:207' says "the caller states the base, exactly as it already
# rewrites options.h and insn-constants.h to the <base> names before calling
# us" -- and the caller that does it is gen-target-manifest.sh:490, applying
# this sed on the way to emitting the rule at :692.  The manifest's
# `tm_include_list' line is the PRE-rewrite form, so anything that reads the
# manifest (or reproduces it, as this script does) has the plain names and must
# rewrite them itself.  Without this the output differs from the build tree's
# in exactly two lines -- `options.h' and `insn-constants.h' -- which reads as
# a trivial cosmetic delta and is not: the plain names are the PRIMARY back
# end's in any build directory that has them.
inc=`echo "$inc" | sed -e "s|^options\.h|options-${cpu}.h|" \
                       -e "s|insn-constants\.h|insn-constants-${cpu}.h|"`

# TARGET_CPU_DEFAULT IS DELIBERATELY EMPTY, AND `$tcd' IS NOT PASSED.  The two
# generators in the tree disagree on this, and the disagreement is intentional:
#
#   gen-target-manifest.sh:693   per-BASE  tm-<cpu>.h : TARGET_CPU_DEFAULT="${gcc_mt_tcd}"
#   gen-multi-target-md.awk:1153 per-TRIPLE tm-<key>.h: TARGET_CPU_DEFAULT=""   (hardcoded)
#
# This script reproduces the PER-TRIPLE one, so it must empty it too.  Measured:
# config.gcc gives armv6l-unknown-linux-gnueabihf target_cpu_default="\"arm10e\"",
# and the build tree's tm-armv6l_unknown_linux_gnueabihf.h has no
# TARGET_CPU_DEFAULT line at all.  Passing it produced one extra #define and was
# the ONLY remaining difference from the build tree's file.
#
# It is not lost: `arm10e' reaches the compiler as the `cpu=arm10e' pair in
# config.gcc's target_option_defaults, which becomes `-mcpu=arm10e' in the
# `*option_defaults' spec.  Compiling it into a per-triple header as well would
# be a per-triple fact frozen at build time -- the thing this branch removes --
# AND a second authority for one answer.
#
# ($tcd is left computed above rather than deleted, so that a reader can see
# what is being dropped and why.  Note it does not survive a naive
# command-substitution round trip: the backslashes in "\"arm10e\"" come back
# literal, which is a second reason not to route it through a script like this.)
cd "$O"
TARGET_CPU_DEFAULT="" HEADERS="$inc" DEFINES="$def" INSN_BASE="$cpu" \
  sh "$S/mkconfig.sh" "tm-$key.h"
echo "wrote $O/tm-$key.h"
