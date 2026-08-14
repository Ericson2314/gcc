#!/bin/sh
# Task #160 -- BUILD THE FOUR VOCABULARIES `tm.h' ACTUALLY CARRIES.
#
# `gcc/mkconfig.sh' assembles tm.h out of five things, and the need-scan this
# branch has been using (`t152-need1.sh') covers exactly ONE of them: the back
# end's header chain.  Measured consequence, already paid for: `main.cc' and
# `c-family/cppspec.cc' scored CLEAR against that vocabulary and were revoked
# by the build, on `flag_checking' and on `OPT_x' / `OPT_o' -- names the
# `config/' vocabulary does not contain and never could.
#
# In a build dir, `gcc/tm.h' reads (lines 1-66 at anchor 48):
#
#     1-38   the TOP HALF: LIBC_*, DEFAULT_LIBC, ANDROID_DEFAULT,
#            HEAP_TRAMPOLINES_INIT, TARGET_HAS_IFUNC, HAVE_LD_*
#     40     #include "options.h"
#     41     #include "insn-constants.h"
#     42-57  the back end's header chain
#     60     #include "insn-flags.h"          (!GENERATOR_FILE && !USED_FOR_TARGET)
#     63     #include "insn-modes.h"          (!GENERATOR_FILE)
#     65     #include "defaults.h"
#
# THE ROUTE TEST, WHICH IS WHAT DECIDES WHETHER A CHANNEL NEEDS A VOCABULARY:
# a channel matters only if tm.h is its ONLY way into a shared translation
# unit.  Measured on this tree:
#
#   options.h        108 source-level includers, and `tree.h' is one of them
#                    -> a second route EXISTS, but not for every TU.  Needs a
#                       vocabulary, and files revoked ONLY by it are deletable
#                       with an explicit `#include "options.h"' added.
#   insn-constants.h only `genenums.cc' includes it by name -> tm.h ONLY.
#                       Needs a vocabulary.
#   insn-flags.h     no source-level includer at all          -> tm.h ONLY.
#                       Needs a vocabulary.
#   insn-modes.h     `coretypes.h:553' includes it through INSN_MODES_H, and
#                    coretypes.h precedes tm.h in every shared TU
#                    -> NEEDS NO VOCABULARY.  This is the one of the four the
#                       brief left open, and the answer is no.
#
# Every vocabulary here is deliberately OVER-BROAD: such an instrument can only
# REVOKE a deletion, never authorise one (PRINCIPLES sec 4).  The refined
# variant was measured GRANTING a wrong deletion twice and is not used.
#
# STATED BLIND SPOT: the options.h and insn-flags.h vocabularies are built from
# the BUILT headers of the two configured bases plus every `.opt' and `.md'
# derived name a source scan can see; a name that only some unconfigured
# target's options generate is not in them.  So this instrument is over-broad
# with respect to the configured pair and merely broad with respect to the
# other 46 back ends.
#
# usage: t160-vocab.sh <builddir> <outdir>
set -e
SRC=$(cd "$(dirname "$0")/.." && pwd)
D=${1:?build dir}
O=${2:?output dir}
WANT=${WANT_ANCHOR:-48}
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "$WANT" ] \
  || { echo "FATAL: worktree anchor != $WANT"; exit 9; }
[ -f "$D/gcc/tm.h" ] || { echo "FATAL: $D/gcc/tm.h absent -- no build to read"; exit 9; }
mkdir -p "$O"

# Names #define'd in a file.
defs () { grep -h '^[ 	]*#[ 	]*define[ 	]' "$@" 2>/dev/null \
          | sed 's/^[ 	]*#[ 	]*define[ 	]*//; s/[ 	(].*//'; }
# The NAME DECLARED by an extern/struct/enum/typedef line -- the last
# identifier before the declarator's `(', `[', `;' or `='.  Taking every token
# on the line instead (the first draft did) puts `void', `int', `const', `enum'
# and `rtx' into the vocabulary, which then revokes every file in the tree for
# the wrong reason: the scan stops discriminating and reads as "nothing is
# deletable", the shape PRINCIPLES warns is indistinguishable from a result.
decls () { grep -hE '^(extern|struct|enum|union|typedef)\b' "$@" 2>/dev/null \
           | sed 's/GTY *(([^)]*))//g' \
           | sed 's/[[(=;].*//' \
           | awk '{ if (NF > 1) print $NF }' \
           | grep -oE '[A-Za-z_][A-Za-z0-9_]*$'; }

# ---- V1: the back end's header chain (the vocabulary that already existed).
{ ( cd "$SRC/gcc" && find config -name '*.h' | xargs grep -h '^[ 	]*#[ 	]*define[ 	]' ) \
    | sed 's/^[ 	]*#[ 	]*define[ 	]*//; s/[ 	(].*//'
  defs "$SRC/gcc/defaults.h" "$SRC/gcc/multi-target-macros.h"
} | grep '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u > "$O/v1-config.txt"

# ---- V2: options.h.  The accessor macros ARE #defines
# (`#define flag_checking global_options.x_flag_checking'), which is the main
# channel; OPT_/CL_ enumerators are taken by token because they live in an
# enum body, not in a #define.
{ defs "$D"/gcc/options.h "$D"/gcc/options-*.h
  decls "$D"/gcc/options.h "$D"/gcc/options-*.h
  cat "$D"/gcc/options.h "$D"/gcc/options-*.h | tr -c 'A-Za-z0-9_' '\n' \
    | grep -E '^(OPT_|CL_|MASK_|OPTION_MASK_)[A-Za-z0-9_]*$'
} | grep '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u > "$O/v2-options.txt"

# ---- V3: the mkconfig.sh top half, read from the BUILT tm.h rather than
# reimplemented -- lines before the `#ifdef IN_GCC' -- plus every tm_defines
# name config.gcc can set, so the set is not narrowed to this pair's targets.
{ sed -n '1,/^#ifdef IN_GCC/p' "$D/gcc/tm.h" \
    | sed -n 's/^[ 	]*#[ 	]*\(define\|ifndef\)[ 	]*//p' | sed 's/[ 	(].*//'
  grep -h 'tm_defines=' "$SRC/gcc/config.gcc" | tr -c 'A-Za-z0-9_' '\n'
  echo TARGET_CPU_DEFAULT
} | grep -E '^[A-Z][A-Z0-9_]{3,}$' | sort -u > "$O/v3-tophalf.txt"

# ---- V4: insn-flags.h and insn-constants.h, whose ONLY route is tm.h.
{ defs "$D"/gcc/insn-flags*.h "$D"/gcc/insn-constants*.h
  decls "$D"/gcc/insn-flags*.h
} | grep '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u > "$O/v4-insn.txt"

for v in v1-config v2-options v3-tophalf v4-insn; do
  n=$(wc -l < "$O/$v.txt")
  printf '%-14s %6s names\n' "$v" "$n"
  [ "$n" -gt 20 ] || { echo "FATAL: $v is only $n names -- it read nothing"; exit 8; }
done
# Non-vacuity, by name and by vocabulary: each must contain the name that
# REVOKED a real deletion, or it is not the vocabulary it claims to be.
grep -qx POINTER_SIZE   "$O/v1-config.txt"  || { echo "FATAL: v1 lacks POINTER_SIZE"; exit 8; }
grep -qx flag_checking  "$O/v2-options.txt" || { echo "FATAL: v2 lacks flag_checking"; exit 8; }
grep -qx OPT_x          "$O/v2-options.txt" || { echo "FATAL: v2 lacks OPT_x"; exit 8; }
grep -qx DEFAULT_LIBC   "$O/v3-tophalf.txt" || { echo "FATAL: v3 lacks DEFAULT_LIBC"; exit 8; }
grep -qx HAVE_LD_PIE    "$O/v3-tophalf.txt" || { echo "FATAL: v3 lacks HAVE_LD_PIE"; exit 8; }
grep -qx GCC_INSN_FLAGS_H "$O/v4-insn.txt"  || { echo "FATAL: v4 lacks GCC_INSN_FLAGS_H"; exit 8; }
echo "vocabularies OK in $O"
