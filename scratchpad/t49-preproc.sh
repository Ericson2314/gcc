#!/bin/sh
# #49 -- the BOTH-SIDED arm, read out of each back end's REAL header chain in a
# 48-back-end build dir, not from the source text.
#
# PRINCIPLES section 4: "ask what the compiler actually reads, not what the
# directory layout suggests it reads."  So this preprocesses `tm-<base>.h' with
# `cpp -dM' and asks, for each ALWAYS-ON capability:
#
#   (a) is the HAVE_* macro DEFINED in that base's chain?   -> the #ifdef is taken
#   (b) does it expand to a targ_caps read?                 -> the value is runtime
#
# (a) AND (b) together are the defect: the guard is unconditionally taken, so
# the runtime value in (b) is never consulted.  Either one alone is fine.
#
# The GUARDED SYMBOL is then read back to show the always-on branch actually
# won -- a check that says only "the macro is defined" would not distinguish
# "guard taken" from "guard absent".
#
# usage: t49-preproc.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad1798a2b26398cc6*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
[ -d "$G" ] || { echo "FATAL: $G missing"; exit 9; }

# The srcdir this build was configured from -- read from the build's own
# testimony (config.log), never assumed from $0's location.
SRCG=$(grep -m1 -o '/tmp/snap-[a-z0-9]*' "$B/config.log")/gcc
[ -d "$SRCG" ] || { echo "FATAL: srcdir $SRCG from config.log does not exist"; exit 9; }
echo "srcdir (from $B/config.log): $SRCG"
: > "$B/t49-preproc.err"

nb=$(ls "$G"/tm-*.h 2>/dev/null | grep -c . || true)
[ "$nb" -ge 3 ] || { echo "REFUSING TO SCORE: only $nb per-base tm headers; #49 needs MORE THAN TWO back ends"; exit 9; }
echo "arm 0 (non-vacuity): $nb per-base tm-<base>.h chains in $G"
echo

# base:HAVE_NAME:GUARDED_SYMBOL -- the symbol the #ifdef branch defines, so the
# reading can show the branch was taken rather than merely that the macro exists.
SITES="
rs6000:HAVE_LD_LARGE_TOC:SET_CMODEL
rs6000:HAVE_LD_NO_DOT_SYMS:DOT_SYMBOLS
alpha:HAVE_LD_PIE:LINK_EH_SPEC
avr:HAVE_LD_AVR_AVRXMEGA2_FLMAP:.
i386:HAVE_LD_LARGE_TOC:SET_CMODEL
aarch64:HAVE_LD_LARGE_TOC:SET_CMODEL
"

printf '%-9s %-38s %-8s %-26s %s\n' BASE CAPABILITY DEFINED? EXPANSION 'GUARDED SYMBOL'
scored=0
for s in $SITES; do
  base=$(echo "$s" | cut -d: -f1)
  name=$(echo "$s" | cut -d: -f2)
  sym=$(echo "$s"  | cut -d: -f3)
  h="$G/tm-$base.h"
  [ -f "$h" ] || { printf '%-9s %-38s %s\n' "$base" "$name" "(no tm-$base.h -- back end not configured)"; continue; }
  # -I$SRCG is required: tm-<base>.h ends with `#include "defaults.h"', which
  # lives in the SOURCE tree.  Never 2>/dev/null (PRINCIPLES section 5) -- the
  # first draft did, and turned "cpp cannot find defaults.h" into an empty read.
  dm=$(sh "$S/eb-shell.sh" "cd $G && echo '#include \"tm-$base.h\"' | cpp -dM -I. -I$SRCG -x c++ - 2>>$B/t49-preproc.err" || true)
  [ -n "$dm" ] || { echo "FATAL: cpp produced nothing for $base; refusing to score (an empty read looks exactly like a clean one)"; exit 9; }
  scored=$((scored+1))
  exp=$(printf '%s\n' "$dm" | sed -n "s/^#define $name //p" | head -1)
  if [ -z "$exp" ]; then def=NO; exp='(undefined)'; else def=YES; fi
  gs=$(printf '%s\n' "$dm" | sed -n "s/^#define $sym\b//p" | head -1 | cut -c1-40)
  [ -n "$gs" ] || gs='(absent)'
  printf '%-9s %-38s %-8s %-26s %s\n' "$base" "$name" "$def" "$(echo "$exp" | cut -c1-26)" "$gs"
done
echo
[ "$scored" -gt 0 ] || { echo "FATAL: scored nothing"; exit 9; }
echo "== chains actually preprocessed: $scored"
