#!/bin/sh
# agent-a4568de8f522450d3-undoc.sh -- the THIRD leak population: target macros
# that `doc/tm.texi' does not document, so the leak census cannot see them.
#
# WHY THIS EXISTS.  `-leakcensus.sh' takes its population from tm.texi's own
# `@defmac' list, deliberately: "so the census cannot be accused of having
# chosen its own population".  That is a real property and it is why its figure
# is quotable.  It also means an UNDOCUMENTED target macro is invisible to it,
# and no number of re-runs will ever produce such a row.
#
# Measured instance, and the reason this script exists rather than a note:
# `ASM_OUTPUT_FUNCTION_PREFIX' is spelled at `varasm.cc:2192' under `#ifdef',
# is defined by exactly one back end (s390) and NOT by i386 -- so the condition
# was false for all 47 bases, s390's `.machine push' / `.machinemode zarch'
# never appeared, and that is the whole of s390x's recorded residual (board
# item #4).  It is not in tm.texi.  It was found by following the missing
# assembler directive backwards, not by any instrument here.
#
# THE POPULATION: an identifier that
#   - is spelled in SHARED code (compiled once, against the primary's tm.h),
#   - is `#define'd by at least one back end under gcc/config/,
#   - is NOT in tm.texi's @defmac list,
#   - and is NOT already converted (REDIRECT or DESCRIPTOR).
#
# WHAT THIS CANNOT DO.  It cannot tell a leak from a coincidence: a name may be
# `#define'd under config/ for reasons unrelated to the shared spelling.  So it
# RANKS and never concludes, and the `#ifdef'-vs-expression split is printed
# because it is the split that decides the SHAPE of any conversion (PRINCIPLES:
# a name on an `#if' line cannot become a runtime value).
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
O=${O:-/tmp/w-a4568de8f522450d3}/undoc
CONV=${CONV:?set CONV to the leakcensus report.conv}
ALL=${ALL:?set ALL to the leakcensus macros.all}
mkdir -p "$O"
cd "$W/gcc"

[ -f "$CONV" ] || { echo "FATAL: no $CONV"; exit 9; }
[ -f "$ALL" ]  || { echo "FATAL: no $ALL";  exit 9; }
grep -qx Pmode "$ALL" || {
  echo "FATAL: $ALL has no 'Pmode' -- it is from the OLD uppercase-only"
  echo "       extraction, which truncated it to 'P'.  Re-run leakcensus."
  exit 9; }

# 1. every identifier `#define'd by a back end, with how many back ends do it.
grep -rhE '^[[:space:]]*#[[:space:]]*define[[:space:]]+[A-Za-z_][A-Za-z_0-9]*' \
     config/ 2>/dev/null \
  | sed -n 's/^[[:space:]]*#[[:space:]]*define[[:space:]]\+\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  | sort -u > "$O/defined.names"
echo "identifiers #defined anywhere under config/: $(wc -l < "$O/defined.names")"

# 2. minus everything the census already knows about.
cut -f4 "$CONV" | sort -u > "$O/known"
sort -u "$ALL" >> "$O/known"
sort -u "$O/known" -o "$O/known"
comm -23 "$O/defined.names" "$O/known" > "$O/candidates"
echo "  minus tm.texi-documented and already-converted: $(wc -l < "$O/candidates")"

# 3. shared code only -- same exclusions -descaudit.sh justifies at length.
ls *.cc *.h 2>/dev/null \
  | grep -v '^target-.*\.h$' | grep -v '^target-.*\.cc$' \
  | grep -v '^defaults\.h$' | grep -v '^multi-target-' > "$O/shared.files"

: > "$O/hits"
while read -r m; do
  # An `#ifdef'/`#if defined' mention is the interesting one: it is where a
  # leaked ABSENCE hides, and it is the shape that cannot become a runtime
  # value.  Require the name to look like a target macro (upper-case-ish) to
  # keep the noise down; ASM_OUTPUT_FUNCTION_PREFIX passes that filter.
  case "$m" in [A-Z]*) ;; *) continue ;; esac
  g=$(grep -nE "^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef|elif).*\<$m\>" \
        $(cat "$O/shared.files") 2>/dev/null)
  [ -n "$g" ] || continue
  # how many back ends define it, and does the PRIMARY?
  d=$(grep -rlE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" config/ 2>/dev/null \
      | sed 's|^config/\([^/]*\)/.*|\1|' | sort -u | wc -l)
  n=$(printf '%s\n' "$g" | wc -l)
  printf '%s\t%s\t%s\n' "$d" "$n" "$m" >> "$O/hits"
done < "$O/candidates"

echo
echo "== UNDOCUMENTED names on an #if line in shared code, #define'd under config/"
echo "== backends / #if-sites / name"
sort -k1,1nr -k2,2nr "$O/hits" | awk -F'\t' '{printf "  %3s backends  %3s sites  %s\n",$1,$2,$3}'
echo
echo "TOTAL: $(wc -l < "$O/hits") -- a population the leak census cannot see."

# NON-VACUITY, AND IT IS AN ARM ON THE SCANNER, NOT ON THE TREE.
#
# THE ANCHOR HAS ALREADY EXPIRED ONCE, WHICH IS THE POINT OF THIS COMMENT.  It
# was ASM_OUTPUT_FUNCTION_PREFIX -- the macro this script was written to
# demonstrate -- and the arm went quiet the moment that macro was converted, in
# the same session.  It reported "NOT a pass, treat the total as unverified"
# rather than a green, which is the behaviour wanted; but an anchor that is
# also a conversion target is a control with an expiry date, exactly like the
# `macro-probe-run.sh' control PRINCIPLES records dying unnoticed for a day.
#
# So the anchor is now ADDR_VEC_ALIGN, chosen because it is NOT being
# converted: 12 back ends define it (aarch64 0, sh/pa/nds32 2, vax/csky 0,
# arm and arc computed), `final.cc:485' carries an `#ifndef' fallback to
# `final_addr_vec_align', and it is absent from tm.texi.  If you convert IT,
# move this arm again -- do not delete it.
echo
echo "NON-VACUITY (an arm on the scanner):"
if grep -qw ADDR_VEC_ALIGN "$O/hits" 2>/dev/null; then
  echo "  ok: ADDR_VEC_ALIGN found -- a known undocumented member of this set"
else
  echo "  FATAL: the scanner cannot see ADDR_VEC_ALIGN, which is undocumented,"
  echo "         defined by 12 back ends and spelled at final.cc:2479 under"
  echo "         #ifdef.  Every total above is void.  If you have just"
  echo "         CONVERTED it, re-point this arm rather than deleting it."
  exit 9
fi
