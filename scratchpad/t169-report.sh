#!/bin/sh
# #169 -- score the sweep BY CAUSE, and by BACK ENDS, not by line count.
#
# PRINCIPLES section 1: "a count is not a population, and 606 diagnostics once
# came from two back ends."  So the unit reported here is
#
#     (macro, guard class, HOW MANY OF THE 48 BACK ENDS GET AN ANSWER THAT IS
#      NOT THEIR OWN)
#
# The last column is `nb - same', where `same' is the number of bases whose
# value for the macro is byte-identical to i386's -- i386 because the shared
# `tm.h' IS i386's header chain (PRINCIPLES section 1), so i386's answer is
# what every shared TU actually reads.  A macro with nb-same = 0 costs nothing
# even if it is guarded in fifty places; a macro with nb-same = 47 is wrong for
# every back end but the primary.
#
# usage: t169-report.sh <dumpdir>
set -u
O=${1:?dump dir}
W=$O/sweep
[ -s "$W/macros.tsv" ] || { echo "FATAL: no macros.tsv"; exit 9; }
[ -s "$W/sites.tsv" ] || { echo "FATAL: no sites.tsv"; exit 9; }
NB=$(grep -c . "$O/bases")
SRC=${2:?srcdir}

# ---------------------------------------------------------------- exclusions
# A MACRO THE SHARED SOURCES DEFINE THEMSELVES IS NOT DECIDED BY tm.h.
# `cpp -dM' over a base's `tm-<base>.h' reports everything that chain defines,
# and some chains reach `system.h' and pick up `GCC_VERSION' -- which the
# shared TU would get anyway, from its own `#include "system.h"'.  Attributing
# those to the primary's chain invents a defect: GCC_VERSION scored "47 of 48
# back ends served a foreign answer" purely because exactly one base's chain
# (gcn) happened to define it and the other 47 did not.
#
# `defaults.h' and `multi-target-macros.h' are DELIBERATELY NOT EXCLUDED.
# PRINCIPLES: "defaults.h has zero source-level includers -- its only route
# into any TU is the tail mkconfig.sh appends to tm.h."  They are part of the
# tm.h channel, not an independent one, so a macro they define is decided by
# tm.h after all.
#
# `$SRC/include' AND `$SRC/libcpp/include' ARE IN SCOPE and were not at first.
# `GCC_VERSION' lives in `include/ansidecl.h', outside gcc/ entirely, and
# survived a gcc/-only scan -- reappearing in the LOUD table with "47 of 48
# back ends", which is the shape of a real defect and was pure instrument
# error.  Anything a shared TU can reach without tm.h belongs here.
find "$SRC/gcc" "$SRC/include" "$SRC/libcpp/include" \
     \( -name config -o -name testsuite \) -prune -o \
     \( -name '*.h' -o -name '*.cc' -o -name '*.c' \) -print \
  | grep -v '/defaults\.h$' | grep -v '/multi-target-macros\.h$' \
  | xargs grep -h '^[ \t]*#[ \t]*define[ \t]' \
  | sed -n 's/^[ \t]*#[ \t]*define[ \t]*\([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' \
  | sort -u > "$W/shared-defs"
NX=$(grep -c . "$W/shared-defs")
[ "$NX" -gt 1000 ] || { echo "FATAL: only $NX shared #defines read"; exit 9; }
echo "excluding $NX identifiers the shared sources define themselves"
echo "(defaults.h and multi-target-macros.h deliberately NOT excluded: they are"
echo " the tail of tm.h, not an independent channel)"
awk -F'\t' -v X="$W/shared-defs" '
  BEGIN { while ((getline l < X) > 0) s[l] = 1 }
  !($1 in s)' "$W/macros.tsv" > "$W/macros.kept.tsv"
NK=$(grep -c . "$W/macros.kept.tsv")
echo "target macros in shared-source conditionals: $(grep -c . "$W/macros.tsv") raw, $NK after exclusion"
[ "$NK" -gt 20 ] || { echo "FATAL: only $NK macros survive"; exit 9; }
echo

# macros.tsv: macro ndef nval same axis minority sites i386val aarch64val
# sites.tsv : macro class count " file:line ..."
awk -F'\t' -v NB="$NB" -v M="$W/macros.kept.tsv" '
  BEGIN {
    while ((getline l < M) > 0) {
      split(l, A, "\t")
      axis[A[1]] = A[5]; same[A[1]] = A[4]; ndef[A[1]] = A[2]; nval[A[1]] = A[3]
      iv[A[1]] = A[8]; av[A[1]] = A[9]
    }
    close(M)
  }
  {
    m = $1; c = $2; n = $3
    if (!(m in axis)) next
    if (axis[m] == "CONVERTED" || axis[m] == "agree") { conv[c] += n; next }
    wrong = NB - same[m]
    if (wrong <= 0) { noloss[c] += n; next }
    key = c
    sites[key] += n
    macros[key SUBSEP m] = wrong
    if (wrong > worst[key]) { worst[key] = wrong }
    tot[key SUBSEP "be"] += 0
    rec[m SUBSEP c] = wrong
  }
  END {
    split("LOUD-DEF LOUD-DECL SILENT-VALUE SILENT-FLOW SILENT-OTHER", ORDER, / /)
    print "CLASS            macros  sites  worst-case back ends served a foreign answer"
    for (i = 1; i <= 5; i++) {
      c = ORDER[i]; nm = 0
      for (k in macros) { split(k, K, SUBSEP); if (K[1] == c) nm++ }
      printf "%-15s %6d %6d  %d of %d\n", c, nm, sites[c]+0, worst[c]+0, NB
    }
    nl = 0; ns = 0; sl = 0; ss = 0
    for (k in macros) {
      split(k, K, SUBSEP)
      if (K[1] ~ /^LOUD/) { nl++; sl += 0 } else ns++
    }
    printf "\nLOUD   %d macros\nSILENT %d macros   -- the silent half is %.1fx the loud one\n",
           nl, ns, ns / (nl ? nl : 1)
    print ""
    print "excluded as already CONVERTED or unanimous:"
    for (i = 1; i <= 5; i++) { c = ORDER[i]; printf "  %-14s %d sites\n", c, conv[c]+0 }
  }
' "$W/sites.tsv"

echo
echo "=== HOW MANY BACK ENDS, not how many lines.  For each macro, how many of"
echo "=== the $NB bases get an answer that is not their own, bucketed."
awk -F'\t' -v NB="$NB" '
  $5 != "CONVERTED" && $5 != "agree" {
    w = NB - $4; if (w <= 0) next
    if (w >= 40) b = "40-47"; else if (w >= 20) b = "20-39"
    else if (w >= 10) b = "10-19"; else if (w >= 2) b = "2-9"; else b = "1"
    n[b]++; tot++
    if ($6 == "MINORITY") mino++
  }
  END {
    split("40-47 20-39 10-19 2-9 1", ORDER, / /)
    for (i = 1; i <= 5; i++) printf "  %-6s %4d macros\n", ORDER[i], n[ORDER[i]]+0
    printf "  total %4d macros, of which %d have the PRIMARY in the MINORITY\n", tot, mino+0
  }
' "$W/macros.kept.tsv"

echo
echo "=== LOUD half, worst first.  The guard deletes a definition or a"
echo "=== declaration a per-base object may reference: a link or compile"
echo "=== failure, enumerable BEFORE the link, which is the point."
awk -F'\t' -v NB="$NB" -v M="$W/macros.kept.tsv" '
  BEGIN { while ((getline l < M) > 0) { split(l, A, "\t");
            axis[A[1]]=A[5]; same[A[1]]=A[4]; ndef[A[1]]=A[2] } close(M) }
  $2 ~ /^LOUD/ {
    m=$1; if (!(m in axis)) next
    if (axis[m]=="CONVERTED"||axis[m]=="agree") next
    w = NB - same[m]; if (w <= 0) next
    printf "%3d %-34s %-10s ndef=%-3s%s\n", w, m, $2, ndef[m], $4
  }
' "$W/sites.tsv" | sort -rn | head -40

echo
echo "=== SILENT half, worst first.  No diagnostic exists for any of these."
awk -F'\t' -v NB="$NB" -v M="$W/macros.kept.tsv" '
  BEGIN { while ((getline l < M) > 0) { split(l, A, "\t");
            axis[A[1]]=A[5]; same[A[1]]=A[4]; ndef[A[1]]=A[2] } close(M) }
  $2 ~ /^SILENT/ {
    m=$1; if (!(m in axis)) next
    if (axis[m]=="CONVERTED"||axis[m]=="agree") next
    w = NB - same[m]; if (w <= 0) next
    printf "%3d %-34s %-12s x%-3s %s\n", w, m, $2, $3, substr($4,1,90)
  }
' "$W/sites.tsv" | sort -rn | head -40
