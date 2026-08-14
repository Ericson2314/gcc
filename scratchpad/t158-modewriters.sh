#!/bin/sh
# #158 -- SWEEP THE FAMILY: who writes a mode table from hand-written source?
#
# genmodes.cc's own comment (the CONST_MODE_* block, emit_insn_modes_h) states
#
#   "The middle end never writes a mode table -- there is not one assignment to
#    one of them outside this generator -- and neither does any hand-written
#    back-end source."
#
# A written invariant is not evidence anyone ran it (PRINCIPLES section 4).
# This runs it.
#
# The sweep is over the SOURCE, not the build output: ~186 targets are never
# built, so a diagnostic-driven sweep would fix exactly the copies some
# configured triple compiles and leave identical siblings (PRINCIPLES section 4
# rule 6).
#
# It is deliberately OVER-BROAD.  It can only nominate a writer, never clear
# one, so its output is an UPPER bound; each hit is meant to be read.
#
# usage: t158-modewriters.sh <srcdir>
set -e
SRC=${1:?srcdir}
G="$SRC/gcc"
[ -d "$G/config" ] || { echo "FATAL: no $G/config"; exit 9; }

# The accessor macros that expand to a mode-table lvalue.  GET_MODE_IBIT and
# GET_MODE_FBIT are `mode_ibit[MODE]' / `mode_fbit[MODE]' verbatim, and tree.h
# reaches them through TYPE_IBIT / TYPE_FBIT, which is why a grep for
# `mode_ibit' alone finds nothing in any back end.
PAT='TYPE_IBIT *(\(|\[)|TYPE_FBIT *(\(|\[)|GET_MODE_IBIT|GET_MODE_FBIT|mode_ibit *\[|mode_fbit *\[|mode_size *\[|mode_precision *\[|mode_nunits *\[|mode_base_align *\[|mode_unit_size *\[|mode_mask_array *\['

echo "=== every hit, anywhere under gcc/ except the generator itself ==="
hits=$(grep -rInE "$PAT" "$G" \
        --include='*.cc' --include='*.c' --include='*.h' \
        | grep -v '/genmodes\.cc:' | grep -v '/machmode\.h:' || true)
[ -n "$hits" ] || { echo "FATAL: the sweep read NOTHING; an all-empty read is"; \
                    echo "indistinguishable from the invariant holding"; exit 9; }
echo "$hits" | sed "s|$G/||"

echo
echo "=== of those, the ones that are an ASSIGNMENT (a WRITE) ==="
echo "$hits" | grep -E "($PAT)[^;]*\) *=[^=]" | sed "s|$G/||" || echo "  (none matched the write pattern)"
