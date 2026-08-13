#!/bin/sh
# union-probe.sh -- THE MISSING SHAPE FOR MACROS CONVERTED BY THE genmodes
# UNION, and the arm that `MAX_BITSIZE_MODE_ANY_MODE' has never had.
#
# WHY A SIXTH SHAPE IS NEEDED RATHER THAN REUSING AN EXISTING ONE.  The four
# existing shapes all ask "do the two bases give different answers, and does
# the selected base get its own?".  For a UNION macro that question is wrong by
# construction: the whole design is that every translation unit sees ONE
# number, deliberately the same in both bases, because it sizes stack buffers
# and the guard protecting each buffer is written in terms of the same
# constant (genmodes.cc:1402-1434).  So:
#
#   * `macro-probe.sh's header arm compares base-A context with base-B context
#     and finds them EQUAL -- and scores that a PASS.  It is a
#     TARGET-NEUTRAL-AGREEMENT green, wrong-reason shape 2, and for
#     MAX_BITSIZE_MODE_ANY_MODE it is currently banked as one of only TWO
#     TRUSTED aarch64 passes on the whole board.
#   * `tab-probe.sh' would read the same 8192 out of the running cc1 for both
#     bases: same green, same wrong reason.
#   * `exist-probe.sh' has no thunk to read; there is no `mt_' function.
#
# THE PROPOSITION THAT IS ACTUALLY TRUE OF A UNION MACRO, and which this arm
# scores instead:
#
#   A. NON-VACUITY.  At least two configured back ends must give DIFFERENT
#      answers on their own.  If every base agrees, the union is doing nothing
#      and a green here is worthless -- this is the arm refusing to certify
#      itself.  Measured: i386 1024, aarch64 8192.
#   B. THE SHARED ANSWER IS THE MAXIMUM over the per-base answers, not any
#      single base's.  In particular it must NOT equal the primary's own
#      answer while some base is larger -- that is precisely the leak
#      (a 128-byte buffer where 1024 bytes are written, admitted by a guard
#      using the same wrong constant).
#   C. BOTH-SIDEDNESS.  The per-base answers are read from the per-base
#      generators, so the arm shows each base still computing its OWN number
#      while the shared header carries the union.  Showing only that the
#      shared header says 8192 cannot distinguish "the union works" from
#      "everyone now gets aarch64's answer for some other reason".
#
# It reads the GENERATORS, not the checked-in headers, because the generator is
# where the union is computed and `move-if-change' actively hides a generator
# that ran and changed nothing (PRINCIPLES section 4).

# THE SCORED POPULATION, exported on one line exactly as `tab-probe.sh' exports
# TAB_MACROS and `exist-probe.sh' exports EXIST_MACROS, and read by
# `macro-probe.sh' the same way.  A macro may move to CONVERTED_UNION only by
# appearing here, and appearing here obliges the board to say CONVERTED_UNION;
# both directions are checked there.
#
# `MAX_BITSIZE_MODE_ANY_INT' is deliberately NOT here.  It is examined and
# reported below, and it comes out 512 on both bases -- so the union
# proposition is vacuous for it and the arm refuses to score it.  Listing it
# would advertise coverage the arm declines to provide, which is the exact
# defect the EXIST_MACROS-vs-PREREG drift check exists to catch.
UNION_MACROS="MAX_BITSIZE_MODE_ANY_MODE"
UNION_EXAMINED="MAX_BITSIZE_MODE_ANY_MODE MAX_BITSIZE_MODE_ANY_INT"

set -u
B=${1:?build dir}
G=$B/gcc
[ -d "$G" ] || { echo "FATAL: $G is not a build dir"; exit 9; }
# Assert the build dir belongs to a current tree.  A build dir configured from
# a stale worktree passes every check below while measuring another compiler.
a=$(grep -c MULTI_TARGET "$G/Makefile" || true)
[ "$a" -ge 39 ] || { echo "FATAL: $G/Makefile anchor=$a, stale or foreign build dir"; exit 9; }

for f in build/genmodes build/genmodes-i386 build/genmodes-aarch64 modes-union.list; do
  [ -e "$G/$f" ] || { echo "FATAL: $G/$f missing; cannot measure"; exit 9; }
done

# MACRO=<name>  PER-BASE GENERATOR FLAGS: none; each per-base genmodes computes
# its own answer.  The union run needs -U/-A exactly as the Makefile gives it.
base_val () {  # $1 = generator, $2 = macro
  ( cd "$G" && ./"$1" -h 2>/dev/null ) \
    | awk -v m="$2" '$1=="#define" && $2==m {print $3; found=1}
                     END{ if (!found) print "ABSENT" }'
}
# FAULT INJECTION, because an unfired mitigation is indistinguishable from an
# absent one.  `INJECT=primary' makes the shared answer come from the PRIMARY's
# own generator instead of the union run -- which is not a hypothetical fault:
# genmodes.cc carried the union machinery since f7c4d1aed68 with NOTHING
# INVOKING IT, so every shared number was the primary's.  That is the state
# this arm must be able to call FAIL.
union_val () { # $1 = macro
  if [ "${INJECT:-}" = primary ]; then
    base_val build/genmodes-i386 "$1"; return
  fi
  mtb=$(cd "$G" && sed -n 's/^multi_target_base *= *//p' Makefile | head -1)
  [ -n "$mtb" ] || { echo "FATAL: multi_target_base empty"; exit 9; }
  ( cd "$G" && ./build/genmodes -U modes-union.list -A "$mtb" -h 2>/dev/null ) \
    | awk -v m="$1" '$1=="#define" && $2==m {print $3; found=1}
                     END{ if (!found) print "ABSENT" }'
}

rc=0
nscored=0
for M in $UNION_EXAMINED; do
  i=$(base_val build/genmodes-i386 "$M")
  a=$(base_val build/genmodes-aarch64 "$M")
  u=$(union_val "$M")
  case "$i$a$u" in *ABSENT*)
    echo "$M  REFUSING TO SCORE: i386=$i aarch64=$a union=$u (a generator did not emit it)"
    rc=1; continue;;
  esac
  # A. non-vacuity
  if [ "$i" = "$a" ]; then
    echo "$M  UNSCOREABLE: both bases answer $i, so the union proposition is vacuous"
    continue
  fi
  # B. maximum
  max=$i; [ "$a" -gt "$max" ] && max=$a
  if [ "$u" != "$max" ]; then
    echo "$M  FAIL: i386=$i aarch64=$a shared=$u, expected the maximum $max"
    rc=1
  else
    echo "$M  PASS: i386=$i aarch64=$a shared=$u = max, and the shared answer is NOT the primary's ($i)"
  fi
  case " $UNION_MACROS " in *" $M "*) nscored=$((nscored + 1)) ;; esac
done

# DRIFT, both directions: a name the board is told this arm covers must
# actually have been scored here, and a name scored here must be advertised.
# Advertising coverage the arm does not provide is how a board comes to quote a
# green nobody measured.
for n in $UNION_MACROS; do
  case " $UNION_EXAMINED " in
    *" $n "*) ;;
    *) echo "FATAL: $n is in UNION_MACROS but is never examined"; exit 9 ;;
  esac
done
[ "$nscored" -gt 0 ] || { echo "FATAL: nothing in UNION_MACROS was scored; refusing to report"; exit 9; }

# Negative control: the arm must be able to say FAIL.  Ask for the maximum of a
# macro genmodes does not emit; an instrument that scores that as a pass is
# scoring absence as agreement, which is the failure this whole board exists to
# prevent.
c=$(base_val build/genmodes-i386 MT_NO_SUCH_MODE_MACRO)
[ "$c" = ABSENT ] || { echo "FATAL: negative control read '$c', not ABSENT"; exit 9; }
echo "control: an absent macro reads ABSENT and is refused, not passed"
exit $rc
