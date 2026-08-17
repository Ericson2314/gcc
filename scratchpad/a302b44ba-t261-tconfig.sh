#!/bin/sh
# TASK 261.  IS `tconfig.h' TARGET-INDEPENDENT?  install-target-headers.sh:138
# says it is -- "byte-identical across triples" -- and ships it once per target
# on that basis.
#
# THE CLAIM IS TESTABLE AND THE TEST MUST BE ABLE TO CONFIRM IT.  gcc's rule
# (gcc/Makefile.in:3305) is
#
#     TARGET_CPU_DEFAULT="" HEADERS="$(xm_include_list)" \
#     DEFINES="USED_FOR_TARGET $(xm_defines)" mkconfig.sh tconfig.h
#
# and gcc/configure.ac:2041 sets `xm_file="auto-host.h ansidecl.h ${xm_file}"',
# where the INNER xm_file is assigned inside config.gcc's `case ${target}'.
# So the question is whether any target reaches a non-empty inner xm_file.
# config.gcc has exactly four such assignments (:1152 vms, :2247 djgpp, :2317
# and :2338 cygwin, :2357 mingw32) against the `xm_file=' default at :281.
#
# This reproduces gcc/configure.ac:2254's xm_include_list loop and runs
# mkconfig.sh for each triple, OUTSIDE any build directory, and diffs them all
# against the first.  A triple whose tconfig.h differs REFUTES the claim; all
# identical CONFIRMS it, and the ELF/Linux-only list is included on purpose so
# that a run showing no difference cannot be blamed on a thin sample.
#
# usage: a302b44ba-t261-tconfig.sh <gcc-srcdir> <outdir> <triple>...
set -eu
S=$(cd "${1:?gcc srcdir}" && pwd); O=${2:?outdir}; shift 2
[ $# -ge 2 ] || { echo "FATAL: name at least two triples"; exit 9; }
mkdir -p "$O"

for T in "$@"; do
  key=$(echo "$T" | sed 's/[^A-Za-z0-9_]/_/g')
  data=$(
    set +u
    target=$(sh "$S/../config.sub" "$T") || exit 1
    xm_file= xm_defines= cpu_type= tm_file= tm_p_file= tmake_file=
    extra_objs= extra_options= extra_headers= c_target_objs= cxx_target_objs=
    d_target_objs= rust_target_objs= jit_target_objs= fortran_target_objs=
    extra_gcc_objs= out_file= md_file= target_gtfiles= common_out_file=
    target_has_targetm_common= dwarf2= extra_modes= tm_defines=
    target_cpu_default= use_gcc_tgmath= use_gcc_stdint= TM_MULTILIB_CONFIG=
    . "$S/config.gcc" > /dev/null 2>&1 || exit 1
    # gcc/configure.ac:2041, then :2254's loop.
    inner=$xm_file
    xm_file="auto-host.h ansidecl.h ${xm_file}"
    incl=
    for f in $xm_file; do
      case $f in
        ansidecl.h | auto-host.h ) incl="$incl $f" ;;
        * ) incl="$incl config/$f" ;;
      esac
    done
    echo "INNER $inner"
    echo "INCL $incl"
    echo "DEF $xm_defines"
  ) || { echo "config.gcc FAILED for $T"; exit 9; }
  inner=$(echo "$data" | sed -n 's/^INNER //p')
  incl=$(echo "$data" | sed -n 's/^INCL //p')
  def=$(echo "$data" | sed -n 's/^DEF //p')
  d="$O/$key"; rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && TARGET_CPU_DEFAULT="" HEADERS="$incl" \
      DEFINES="USED_FOR_TARGET $def" sh "$S/mkconfig.sh" tconfig.h ) \
    || { echo "FATAL: mkconfig.sh failed for $T"; exit 9; }
  printf '%-28s inner xm_file=%-24s md5 %s\n' "$T" "${inner:-<empty>}" \
    "$(md5sum < "$d/tconfig.h" | cut -c1-16)"
done

# NON-VACUITY ON THE GENERATOR: if mkconfig.sh ignored HEADERS entirely, every
# file would match and the run would "confirm" the claim while proving nothing.
first=$(echo "$1" | sed 's/[^A-Za-z0-9_]/_/g')
grep -q 'auto-host\.h' "$O/$first/tconfig.h" || {
  echo "FATAL: $O/$first/tconfig.h does not mention auto-host.h, so HEADERS"
  echo "  did not reach mkconfig.sh and no comparison below means anything."
  exit 9; }

echo "-- diff against $1:"
base="$O/$first/tconfig.h"; ndiff=0
for T in "$@"; do
  key=$(echo "$T" | sed 's/[^A-Za-z0-9_]/_/g')
  if cmp -s "$base" "$O/$key/tconfig.h"; then
    printf '   %-28s identical\n' "$T"
  else
    printf '   %-28s DIFFERS:\n' "$T"; diff "$base" "$O/$key/tconfig.h" | sed 's/^/     /'
    ndiff=$((ndiff+1))
  fi
done
echo "-- $ndiff of $# differ from $1"
