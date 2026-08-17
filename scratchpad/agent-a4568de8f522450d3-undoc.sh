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

# THE ANCHOR HAS NOW EXPIRED TWICE, AND THE SECOND TIME WAS PREDICTED IN
# WRITING BY THE COMMENT ABOVE.  ASM_OUTPUT_FUNCTION_PREFIX went first;
# ADDR_VEC_ALIGN was chosen "because it is NOT being converted" and was
# converted in the next commit of the same branch.  It refused with FATAL
# rather than going quiet, which is the wanted behaviour and is the third time
# this project has paid for a control whose subject is also its work queue.
#
# So the arm is now TWO arms, and only one of them can expire.
#
# ARM A -- THE MECHANISM, AND IT CANNOT EXPIRE.  `HOST_BIT_BUCKET' is
# undocumented and is a HOST fact (`/dev/null''s spelling), not a target one,
# so it is not on anybody's conversion queue and never will be.  It proves
# both halves of the pipeline ran: the `config/' `#define' scan AND the shared
# spelling scan, since a name reaches `hits' only by appearing in both.
#
# ARM B -- THE POPULATION, WHICH IS ALLOWED TO EXPIRE, LOUDLY.  A list of
# multi-back-end undocumented macros, of which at least one must survive.  Each
# conversion removes one; when the last goes this refuses by name and the
# remedy is to TOP THE LIST UP from the ranked output above, not to delete it.
# Naming several rather than one is the whole difference: a single-name anchor
# expires on its first conversion, and this branch converts roughly one of
# these a session.
if grep -qw HOST_BIT_BUCKET "$O/hits" 2>/dev/null; then
  echo "  ok  ARM A (mechanism): HOST_BIT_BUCKET found -- both halves of the"
  echo "      scan ran, and this anchor is a HOST macro so it cannot expire."
else
  echo "  FATAL ARM A: the scanner cannot see HOST_BIT_BUCKET, which is"
  echo "         undocumented and spelled in shared code.  Both halves of the"
  echo "         scan are suspect and every total above is void.  This anchor"
  echo "         is NOT a conversion target, so a failure here is a defect in"
  echo "         the scanner, not a stale list."
  exit 9
fi

UNDOC_ANCHORS="ASM_OUTPUT_ADDR_VEC ASM_OUTPUT_ADDR_DIFF_VEC \
ASM_OUTPUT_EXTERNAL_LIBCALL ASM_OUTPUT_CASE_END FRAME_BEGIN_LABEL"
found=""; gone=""
for a in $UNDOC_ANCHORS; do
  if grep -qw "$a" "$O/hits" 2>/dev/null; then found="$found $a"; else gone="$gone $a"; fi
done
if [ -n "$found" ]; then
  echo "  ok  ARM B (population): still present:$found"
  [ -n "$gone" ] && echo "      converted or gone since this list was written:$gone"
else
  echo "  FATAL ARM B: none of$UNDOC_ANCHORS"
  echo "         remains in the population.  That is not a failure of the scan"
  echo "         -- it means every macro this list named has been converted."
  echo "         TOP THE LIST UP from the ranked output above; do not delete"
  echo "         this arm and do not lower it to one name."
  exit 9
fi
