#!/bin/sh
# t189-dryrun.sh -- gen-multi-target-md.awk's extra_headers arm, without a build.
#
# Feeds a synthetic manifest holding TWO back ends that CLAIM THE SAME HEADER
# BASENAME (aarch64 and arm both install arm_neon.h) plus a second aarch64
# record adding a header the first record does not have, and asserts:
#
#   1. each back end gets its own MT_EXTRA_HEADERS_<cpu>, with $(srcdir)/config
#      /<ITS OWN cpu>/ prefixed -- the half configure.ac gets wrong, since it
#      prepends the ONE legacy target's cpu_type to everybody's files;
#   2. the colliding basename appears once per back end and the two entries are
#      DIFFERENT PATHS, i.e. they are not sharing a directory;
#   3. extra_headers is unioned over EVERY record for a back end, not taken
#      from the first -- config.gcc really does add headers per triple;
#   4. include-<cpu>/s-hdrs rules and MT_HEADER_BASES exist for both;
#   5. THE NEGATIVE CONTROL: a manifest with no extra_headers key at all is
#      REFUSED by name.  Without this arm the whole check passes vacuously on a
#      generator that emits nothing, which is the failure shape this branch has
#      recorded 26 times.
set -u
S=$(cd "$(dirname "$0")/.." && pwd)
A=$S/gcc/gen-multi-target-md.awk
[ -f "$A" ] || { echo "FATAL: no $A"; exit 9; }
W=${TMPDIR:-/tmp}/t189.$$
mkdir -p "$W" || exit 9
rc=0
say() { echo "$1 $2"; [ "$1" = FAIL ] && rc=1; return 0; }

mkrec() {   # cpu, target, headers, tgmath
  cat <<EOF
target $2
cpu_type $1
common_out_file $1/$1-common.cc
md_file $1/$1.md
out_file $1/$1.cc
extra_objs
c_target_objs $1-c.o
extra_gcc_objs
extra_modes $1/$1-modes.def
extra_options
extra_headers $3
use_gcc_tgmath $4
tm_p_file $1/$1-protos.h
tm_include_list options.h
tm_defines
tmake_file $1/t-$1
tmake_file_present

EOF
}

{ mkrec aarch64 aarch64-unknown-linux-gnu "arm_neon.h arm_sve.h" no
  mkrec aarch64 aarch64-none-elf          "arm_neon.h arm_acle.h" yes
  mkrec arm     arm-none-eabi             "arm_neon.h mmintrin.h" no
} > "$W/m.txt"

awk -f "$A" "$W/m.txt" > "$W/out.mk" 2> "$W/err.txt"
arc=$?
[ $arc -eq 0 ] || { echo "FATAL: generator exited $arc"; cat "$W/err.txt"; exit 9; }
[ -s "$W/out.mk" ] || { echo "FATAL: empty fragment"; exit 9; }

grep -q '^MT_EXTRA_HEADERS_aarch64 =' "$W/out.mk" \
  && say PASS "1a MT_EXTRA_HEADERS_aarch64 emitted" \
  || say FAIL "1a MT_EXTRA_HEADERS_aarch64 missing"
grep -q '^MT_EXTRA_HEADERS_arm =' "$W/out.mk" \
  && say PASS "1b MT_EXTRA_HEADERS_arm emitted" \
  || say FAIL "1b MT_EXTRA_HEADERS_arm missing"

# Each back end's files are under ITS OWN config/<cpu>/ directory.
al=$(grep '^MT_EXTRA_HEADERS_aarch64 =' "$W/out.mk")
rl=$(grep '^MT_EXTRA_HEADERS_arm =' "$W/out.mk")
case $al in
  *'config/aarch64/arm_neon.h'*) say PASS "2a aarch64 arm_neon.h from config/aarch64" ;;
  *) say FAIL "2a aarch64 list is [$al]" ;;
esac
case $rl in
  *'config/arm/arm_neon.h'*) say PASS "2b arm arm_neon.h from config/arm" ;;
  *) say FAIL "2b arm list is [$rl]" ;;
esac
# ... and NOT under each other's.  This is the assertion that would have caught
# configure.ac's ${cpu_type}, which is the primary's for every back end.
case $al in *'config/arm/'*) say FAIL "2c aarch64 list names config/arm" ;;
            *) say PASS "2c aarch64 list names no other back end" ;; esac
case $rl in *'config/aarch64/'*) say FAIL "2d arm list names config/aarch64" ;;
            *) say PASS "2d arm list names no other back end" ;; esac

# Unioned over both aarch64 records, not taken from the first.
case $al in *arm_acle.h*) say PASS "3a second record's header unioned in" ;;
            *) say FAIL "3a arm_acle.h lost (first record only)" ;; esac
case $al in *arm_sve.h*) say PASS "3b first record's header kept" ;;
            *) say FAIL "3b arm_sve.h lost" ;; esac
# use_gcc_tgmath is per record too, and yes on the second aarch64 one.
case $al in *ginclude/tgmath.h*) say PASS "3c tgmath.h from use_gcc_tgmath=yes" ;;
            *) say FAIL "3c tgmath.h absent" ;; esac
case $rl in *tgmath.h*) say FAIL "3d arm got tgmath.h it did not ask for" ;;
            *) say PASS "3d arm has no tgmath.h" ;; esac
# No duplicates: arm_neon.h is in two aarch64 records.
n=$(echo "$al" | tr ' ' '\012' | grep -c 'config/aarch64/arm_neon.h$')
[ "$n" = 1 ] && say PASS "3e arm_neon.h appears once, not twice" \
             || say FAIL "3e arm_neon.h appears $n times"

grep -q '^include-aarch64/s-hdrs:' "$W/out.mk" \
  && say PASS "4a include-aarch64/s-hdrs rule" || say FAIL "4a no aarch64 stamp rule"
grep -q '^include-arm/s-hdrs:' "$W/out.mk" \
  && say PASS "4b include-arm/s-hdrs rule" || say FAIL "4b no arm stamp rule"
b=$(grep '^MT_HEADER_BASES =' "$W/out.mk")
case $b in *aarch64*arm*|*arm*aarch64*) say PASS "4c MT_HEADER_BASES [$b]" ;;
           *) say FAIL "4c MT_HEADER_BASES [$b]" ;; esac

# 5 -- THE NEGATIVE CONTROL.  Same manifest with the extra_headers lines gone:
# the generator must refuse BY NAME, not emit an empty header set.  An empty
# include-<cpu> tree is indistinguishable from a back end that legitimately has
# no intrinsics, which is why this cannot be allowed to pass quietly.
grep -v '^extra_headers' "$W/m.txt" | grep -v '^use_gcc_tgmath' > "$W/m0.txt"
awk -f "$A" "$W/m0.txt" > "$W/out0.mk" 2> "$W/err0.txt"
nrc=$?
if [ $nrc -eq 0 ]; then
  say FAIL "5 negative control: generator accepted a manifest with no extra_headers"
elif grep -q 'extra_headers' "$W/err0.txt"; then
  say PASS "5 negative control refuses by name (rc=$nrc)"
else
  say FAIL "5 negative control exited $nrc but says nothing about extra_headers"
fi

echo "== t189-dryrun rc=$rc  ($W)"
exit $rc
