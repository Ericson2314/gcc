#!/bin/sh
# Census of cxx_target_objs vs c_target_objs over all 47 back ends, sourcing
# config.gcc once per triple exactly as gen-target-manifest.sh does.
#
# The question this answers is NOT "how many back ends set cxx_target_objs" --
# `grep' on config.gcc answers that and answers it for the 188 triples nobody
# configures.  It is "for a back end, is the set of objects that live under
# config/<cpu>/ the SAME for c_target_objs and cxx_target_objs".  If it is,
# then the per-base objects gen-multi-target-md.awk already builds for the C
# side (mt-<cpu>/<cpu>-c.o) are exactly the ones cc1plus needs, and the fix is
# a second LIST over the same objects rather than a second set of rules.  If it
# is not, the difference is a population needing its own rules.
#
# Prints, per back end: cpu, the own-side C list, the own-side C++ list, and
# SAME/DIFF.  Non-vacuity: refuses if it read no records at all.
S=$1
: ${S:?srcdir}
OUT=${2:?outfile}
: > $OUT
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
    # "own" = the object whose source is under config/<cpu_type>/.  Same test
    # the generator applies, approximated by name here because this script has
    # no tmake fragment parser; the generator's own test is authoritative and
    # this one only has to be right about the QUESTION (same or different).
    cown= ; xown=
    for o in $c_target_objs; do
      case $o in ${cpu_type}-*) cown="$cown $o" ;; esac
    done
    for o in $cxx_target_objs; do
      case $o in ${cpu_type}-*) xown="$xown $o" ;; esac
    done
    cown=`echo $cown | tr ' ' '\012' | sort -u | tr '\012' ' '`
    xown=`echo $xown | tr ' ' '\012' | sort -u | tr '\012' ' '`
    if test x"$cown" = x"$xown"; then v=SAME; else v=DIFF; fi
    echo "$v $cpu_type c=[$cown] cxx=[$xown] alltriple_cxx=[$cxx_target_objs]"
  ) >> $OUT
done
n=`grep -c . $OUT`
if test "$n" -lt 40; then
  echo "REFUSE: read only $n records; the census did not run" >&2
  exit 9
fi
echo "records $n"
echo "SAME `grep -c '^SAME' $OUT`  DIFF `grep -c '^DIFF' $OUT`"
grep '^DIFF' $OUT
echo "back ends with a NON-EMPTY own C++ object:"
grep -c 'cxx=\[[^]]' $OUT
