#!/bin/sh
# Task #107: SHOW THE GUARDS FIRING.  A guard nobody has seen fire is not a
# guard (PRINCIPLES 4).
#
# Four arms, each a DIRECT g++ compile rather than a `make'.  That is not a
# shortcut, it is required: the union bound in multi-target-reg-widths.h is
# DERIVED from the same probe compile as the thing it bounds, so growing a back
# end's CUMULATIVE_ARGS under `make' regenerates the bound to match and the
# assertion correctly does not fire.  Compiling by hand is how the two are held
# apart -- and the state it reproduces is a real one: a build directory whose
# generated header and whose back-end objects came from different builds.
#
#   0  CONTROL      unperturbed aarch64 target-cumargs.cc            must PASS
#   1  BOUND-SIZE   union bound shrunk below aarch64's 184           must FAIL
#                   naming "gen-reg-widths.sh did not see this base"
#   2  BASE-GROWS   aarch64 CUMULATIVE_ARGS grown by 256 bytes,      must FAIL
#                   bound untouched                                  same name
#   3  ALIGN        union alignment raised to 16 in a SHARED TU      must FAIL
#                   naming the incoming_args::info alignment
#
# Arm 3 is on the other side of the same fence: arms 1-2 are the per-back-end
# assertion in target-cumargs.cc, arm 3 is the shared-code one in
# mt-cumulative-args.h that emit-rtl.h carries.  Both sides, per the brief.
#
# EVERY WAY OF PASSING VACUOUSLY IS A FAILURE.  A compile that fails for some
# OTHER reason is not the guard firing, so each failing arm must also print the
# expected phrase; and the control must genuinely succeed, or arms 1-3 prove
# only that the file does not compile at all.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b107}
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a14027402aa930aca
W=/tmp/t107-guards
rm -rf "$W"; mkdir -p "$W/fake"

[ -f "$D/gcc/multi-target-reg-widths.h" ] || {
  echo "FATAL: no $D/gcc/multi-target-reg-widths.h -- build first"; exit 9; }
grep -q 'MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE' \
  "$D/gcc/multi-target-reg-widths.h" || {
  echo "FATAL: the generated widths header has no CUMULATIVE_ARGS bound;"
  echo "       gen-reg-widths.sh did not emit it and every arm below is vacuous"
  exit 9; }
echo "--- the measured bound, as generated:"
grep 'CUMULATIVE_ARGS' "$D/gcc/multi-target-reg-widths.h" | sed 's/^/    /'

INC="-Iaarch64-inc -I. -I$SRC/gcc -I$SRC/include -I$SRC/libcpp/include \
-I$SRC/libdecnumber -I../libdecnumber -I$SRC/libbacktrace"
CXX="g++ -c -fsyntax-only -DIN_GCC -DHAVE_CONFIG_H -fno-exceptions -fno-rtti \
-DMULTI_TARGET_OPTION_TABLES -DMULTI_TARGET_TARGETM_BASE=aarch64 \
-Dtargetm=targetm_aarch64 -Dms_va_list_type_node=ms_va_list_type_node_aarch64 \
-Dlinux_libc_has_function=linux_libc_has_function_aarch64 \
-Dlinux_libm_function_max_error=linux_libm_function_max_error_aarch64 \
-Dlinux_fortify_source_default_level=linux_fortify_source_default_level_aarch64 \
-DTARGETM_CUMARGS_SYMBOL=targetm_cumargs_aarch64"

run () {   # run <extra-I> <source>
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake gmp.dev mpfr.dev libmpc \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && $CXX $1 $INC $2" > "$W/out" 2>&1
  echo $?
}

rc=0
arm () {   # arm <n> <label> <extra-I> <source> <expect|PASS>
  n=$1; label=$2; extra=$3; src=$4; want=$5
  st=$(run "$extra" "$src")
  if [ "$want" = PASS ]; then
    if [ "$st" = 0 ]; then echo "ARM $n $label: PASS (compiled, rc=0)"
    else echo "ARM $n $label: FAILED -- control did not compile (rc=$st); every"
         echo "      other arm is vacuous until this one is green"
         sed 's/^/      /' "$W/out" | head -15; rc=1; fi
    return
  fi
  if [ "$st" = 0 ]; then
    echo "ARM $n $label: FAILED -- perturbed source compiled CLEANLY (rc=0)."
    echo "      The guard did not fire.  An injection that does not fire is a"
    echo "      finding, not a pass."
    rc=1; return
  fi
  if grep -q "$want" "$W/out"; then
    echo "ARM $n $label: PASS -- failed by name (rc=$st)"
    grep -m2 -F "$want" "$W/out" | cut -c1-160 | sed 's/^/      /'
  else
    echo "ARM $n $label: FAILED -- it did fail (rc=$st) but NOT with the"
    echo "      expected text, so this is some other error:"
    grep -m5 'error' "$W/out" | cut -c1-160 | sed 's/^/      /'
    rc=1
  fi
}

arm 0 CONTROL "" "$SRC/gcc/target-cumargs.cc" PASS

# Arm 1: the bound, shrunk.  A quoted #include searches the includer's own
# directory first and then the -I list IN ORDER, and target-cumargs.cc lives in
# srcdir -- which has no copy -- so a -I ahead of `-I.' wins over the build
# root's real one.
sed 's/^#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE .*/#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_SIZE 96/' \
  "$D/gcc/multi-target-reg-widths.h" > "$W/fake/multi-target-reg-widths.h"
grep -q 'CUMULATIVE_ARGS_SIZE 96' "$W/fake/multi-target-reg-widths.h" || {
  echo "FATAL: arm 1 perturbation did not apply; the arm would be vacuous"; exit 9; }
arm 1 BOUND-SIZE "-I$W/fake" "$SRC/gcc/target-cumargs.cc" \
  "gen-reg-widths.sh did not see this base"

# Arm 2: the BASE grows and the bound does not.  aarch64.h is edited in place
# and restored; the trap `git stash' sets is not relevant here because nothing
# is rebuilt by make.
rm -rf "$W/fake"; mkdir -p "$W/fake"
AH=$SRC/gcc/config/aarch64/aarch64.h
cp "$AH" "$W/aarch64.h.orig"
sed -i 's/^} CUMULATIVE_ARGS;/  char mt_deliberate_bloat[256];\n} CUMULATIVE_ARGS;/' "$AH"
if grep -q mt_deliberate_bloat "$AH"; then
  arm 2 BASE-GROWS "" "$SRC/gcc/target-cumargs.cc" \
    "gen-reg-widths.sh did not see this base"
else
  echo "ARM 2 BASE-GROWS: FAILED -- the perturbation did not apply to $AH"; rc=1
fi
cp "$W/aarch64.h.orig" "$AH"
if cmp -s "$W/aarch64.h.orig" "$AH"; then echo "      aarch64.h restored"
else echo "      FATAL: aarch64.h NOT restored"; rc=1; fi

# Arm 3: the SHARED-code half.  A three-line translation unit that includes
# emit-rtl.h the way the middle end does, compiled for the primary, with the
# union alignment raised past what the primary's CUMULATIVE_ARGS provides.
mkdir -p "$W/fake"
sed 's/^#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN .*/#define MULTI_TARGET_UNION_CUMULATIVE_ARGS_ALIGN 16/' \
  "$D/gcc/multi-target-reg-widths.h" > "$W/fake/multi-target-reg-widths.h"
grep -q 'CUMULATIVE_ARGS_ALIGN 16' "$W/fake/multi-target-reg-widths.h" || {
  echo "FATAL: arm 3 perturbation did not apply; the arm would be vacuous"; exit 9; }
cat > "$W/shared-tu.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "backend.h"
#include "rtl.h"
#include "tree.h"
#include "emit-rtl.h"
EOF
# No -DMULTI_TARGET_TARGETM_BASE and no renames: this arm is a MIDDLE-END
# translation unit, which is the side of the fence it is testing.
CXX="g++ -c -fsyntax-only -DIN_GCC -DHAVE_CONFIG_H -fno-exceptions -fno-rtti \
-DMULTI_TARGET_OPTION_TABLES"
INC="-I. -I$SRC/gcc -I$SRC/include -I$SRC/libcpp/include \
-I$SRC/libdecnumber -I../libdecnumber -I$SRC/libbacktrace"
arm 3 ALIGN "-I$W/fake" "$W/shared-tu.cc" \
  "not good enough for it"

echo "t107-guards rc=$rc"
exit $rc
