#!/bin/sh
# agent-ae59966cf819d72ef-pair.sh -- REPORT THE TWO POPULATIONS TOGETHER.
#
# The leak census (`-leakcensus.sh') takes its population from `tm.texi's
# `@defmac' list.  That is what makes its figure quotable -- it cannot be
# accused of choosing its own population -- and it is exactly what makes an
# UNDOCUMENTED target macro invisible to it.  Four of the last five macros
# converted on this branch came from that blind spot.
#
# `t32-values.tsv' is the other instrument and it is defined the opposite way:
# by VALUE DIVERGENCE across back ends, with no reference to the documentation.
# So the two disagree in both directions and neither alone is the answer.
#
# This prints the join.  It concludes nothing on its own -- a name in the
# `#32'-only column is a candidate, not a leak -- which is why the ranked
# columns beside it are the definer counts, not a verdict.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
L=${L:?set L to the leakcensus output dir, e.g. /tmp/w-<id>/leak}
O=${O:-/tmp/w-agent-ae59966cf819d72ef}/pair
mkdir -p "$O"

[ -f "$L/macros.all" ] || { echo "FATAL: no $L/macros.all -- run the census first"; exit 9; }
grep -qx Pmode "$L/macros.all" || {
  echo "FATAL: macros.all has no 'Pmode' -- it is from the OLD uppercase-only"
  echo "       extraction that truncated it to 'P'.  Re-run the census."; exit 9; }

cut -f2 "$W/scratchpad/t32-values.tsv" | sort -u > "$O/t32"
sort -u "$L/macros.all" > "$O/texi"
nt=$(grep -c . "$O/t32"); np=$(grep -c . "$O/texi")
[ "$nt" -gt 100 ] && [ "$np" -gt 100 ] \
  || { echo "FATAL: read $nt / $np names -- an empty side joins to nothing and prints as a clean result"; exit 9; }

comm -12 "$O/t32" "$O/texi" > "$O/both"
comm -23 "$O/t32" "$O/texi" > "$O/t32only"
comm -13 "$O/t32" "$O/texi" > "$O/texionly"

cat <<PAIREOF

  #32 (value divergence across back ends)   $nt macros
  tm.texi @defmac (the census's authority)   $np macros

  in BOTH -- the double count                 $(grep -c . "$O/both")
  #32 ONLY -- census-INVISIBLE by construction $(grep -c . "$O/t32only")
  census ONLY -- no measured value divergence  $(grep -c . "$O/texionly")

PAIREOF

# THE CONTROL, AND IT IS A NEGATIVE ONE.  `ASM_OUTPUT_FUNCTION_PREFIX' is
# undocumented AND must be ABSENT from #32's column: it is defined by exactly
# one back end, so a VALUE-divergence instrument cannot see it either.  If it
# ever appears here, the join is matching on something looser than a name.
if grep -qx ASM_OUTPUT_FUNCTION_PREFIX "$O/t32only"; then
  echo "  FATAL: ASM_OUTPUT_FUNCTION_PREFIX is in the #32-only column.  It has"
  echo "         ONE definer, so a value-divergence census cannot see it; its"
  echo "         presence means this join is not matching whole names."
  exit 9
fi
echo "  control ok: ASM_OUTPUT_FUNCTION_PREFIX (one definer) is in NEITHER"
echo "              population -- so the two together are still not complete."
echo

echo "  the five ranked undocumented macros, and where they land:"
for m in ADDR_VEC_ALIGN ADJUST_INSN_LENGTH ASM_OUTPUT_EXTERNAL_LIBCALL \
         ASM_OUTPUT_ADDR_VEC ASM_OUTPUT_ADDR_DIFF_VEC ; do
  if grep -qx "$m" "$O/t32only"; then w="#32 only (census-invisible)"
  elif grep -qx "$m" "$O/both"; then w="BOTH"
  elif grep -qx "$m" "$O/texionly"; then w="census only"
  else w="NEITHER"; fi
  printf '    %-30s %s\n' "$m" "$w"
done
echo
echo "  and the pair converted in this task, which ARE documented:"
for m in ASM_OUTPUT_ADDR_VEC_ELT ASM_OUTPUT_ADDR_DIFF_ELT ; do
  if grep -qx "$m" "$O/t32only"; then w="#32 only"
  elif grep -qx "$m" "$O/both"; then w="BOTH"
  elif grep -qx "$m" "$O/texionly"; then w="census only"
  else w="NEITHER"; fi
  printf '    %-30s %s\n' "$m" "$w"
done
