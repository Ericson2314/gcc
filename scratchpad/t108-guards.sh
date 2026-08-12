#!/bin/sh
# Task #108: SHOW THE GUARDS FIRING.  A guard nobody has seen fire is not a
# guard (PRINCIPLES 4), and the specific false green this branch keeps
# producing is a MECHANISM THAT IS PRESENT BUT INERT (PRINCIPLES 4, rule 2 --
# a complete mode union sat unused for weeks).  So the arms below are not
# about the values being right; they are about the REDIRECT being live on the
# shared side and absent on the per-back-end side, which is the only thing
# that distinguishes this change from a no-op.
#
#   0  CONTROL       unperturbed aarch64 target-cumargs.cc          must PASS
#   1  SHARED-CALL   STACK_BOUNDARY in a MIDDLE-END TU is a CALL    must FAIL
#                    naming mt_stack_boundary
#   2  BASE-EXEMPT   STACK_BOUNDARY in aarch64's OWN TU is still    must PASS
#                    a constant, and equals 128
#   3  NON-VACUITY   the same assertion against 64                  must FAIL
#                    naming "static assertion failed"
#
# Arm 3 exists because arm 2 passing proves nothing on its own: an assertion
# that is never evaluated also does not fail.  Arms 1 and 2 are the two sides
# of the same fence -- if BOTH passed, the redirect would be reaching the back
# ends too, which is the bug defaults.h's guard block exists to prevent.
#
# COMPILED BY HAND, NOT THROUGH `make', for the reason t107-guards.sh gives:
# these are statements about what a translation unit sees, and `make' would
# rebuild the world around each perturbation.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b108}
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a7d5fb84bdd2264ac
W=/tmp/t108-guards
rm -rf "$W"; mkdir -p "$W"

[ -f "$D/gcc/multi-target-reg-widths.h" ] || {
  echo "FATAL: no $D/gcc/multi-target-reg-widths.h -- build first"; exit 9; }
grep -q 'mt_stack_boundary' "$SRC/gcc/defaults.h" || {
  echo "FATAL: defaults.h has no STACK_BOUNDARY redirect; every arm is vacuous"
  exit 9; }

INCC="-I. -I$SRC/gcc -I$SRC/include -I$SRC/libcpp/include \
-I$SRC/libdecnumber -I../libdecnumber -I$SRC/libbacktrace"

BASECXX="g++ -c -fsyntax-only -DIN_GCC -DHAVE_CONFIG_H -fno-exceptions \
-fno-rtti -DMULTI_TARGET_OPTION_TABLES"

# The per-back-end incantation, byte-for-byte the one t107-guards.sh used.
A64="-Iaarch64-inc -DMULTI_TARGET_TARGETM_BASE=aarch64 \
-Dtargetm=targetm_aarch64 -Dms_va_list_type_node=ms_va_list_type_node_aarch64 \
-Dlinux_libc_has_function=linux_libc_has_function_aarch64 \
-Dlinux_libm_function_max_error=linux_libm_function_max_error_aarch64 \
-Dlinux_fortify_source_default_level=linux_fortify_source_default_level_aarch64 \
-DTARGETM_CUMARGS_SYMBOL=targetm_cumargs_aarch64"

run () {   # run <extra flags> <source>
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake gmp.dev mpfr.dev libmpc \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && $BASECXX $1 $INCC $2" > "$W/out" 2>&1
  echo $?
}

rc=0
arm () {   # arm <n> <label> <flags> <src> <expect|PASS>
  n=$1; label=$2; flags=$3; src=$4; want=$5
  st=$(run "$flags" "$src")
  if [ "$want" = PASS ]; then
    if [ "$st" = 0 ]; then echo "ARM $n $label: PASS (compiled, rc=0)"
    else echo "ARM $n $label: FAILED -- expected a clean compile, got rc=$st;"
         echo "      arms that expect failure are vacuous until this is green"
         grep -m6 'error' "$W/out" | cut -c1-160 | sed 's/^/      /'; rc=1; fi
    return
  fi
  if [ "$st" = 0 ]; then
    echo "ARM $n $label: FAILED -- it compiled CLEANLY (rc=0).  The guard did"
    echo "      not fire.  An injection that does not fire is a finding."
    rc=1; return
  fi
  if grep -q "$want" "$W/out"; then
    echo "ARM $n $label: PASS -- failed by name (rc=$st)"
    grep -m2 -F "$want" "$W/out" | cut -c1-160 | sed 's/^/      /'
  else
    echo "ARM $n $label: FAILED -- it failed (rc=$st) but not with the expected"
    echo "      text, so this is some OTHER error:"
    grep -m6 'error' "$W/out" | cut -c1-160 | sed 's/^/      /'
    rc=1
  fi
}

arm 0 CONTROL "$A64" "$SRC/gcc/target-cumargs.cc" PASS

# Arm 1: a MIDDLE-END translation unit.  No MULTI_TARGET_TARGETM_BASE and no
# renames -- that is the whole point, it is the side of the fence that must be
# redirected.  If STACK_BOUNDARY were still i386's constant expression this
# would compile, which is exactly the inert-mechanism false green.
cat > "$W/shared-tu.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
static_assert (STACK_BOUNDARY == 128, "unreachable: see t108-guards.sh arm 1");
EOF
arm 1 SHARED-CALL "" "$W/shared-tu.cc" "mt_stack_boundary"

# Arm 2: aarch64's OWN translation unit must still see the real macro, and it
# must be aarch64's 128 rather than i386's expression.
cat > "$W/base-tu.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
static_assert (STACK_BOUNDARY == 128,
	       "aarch64 STACK_BOUNDARY is not 128 in its own TU");
EOF
arm 2 BASE-EXEMPT "$A64" "$W/base-tu.cc" PASS

# Arm 3: prove arm 2 was evaluated at all.
cat > "$W/base-tu-bad.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
static_assert (STACK_BOUNDARY == 64, "deliberate: arm 2 must not be vacuous");
EOF
arm 3 NON-VACUITY "$A64" "$W/base-tu-bad.cc" "static assertion failed"

echo "t108-guards rc=$rc"
exit $rc
