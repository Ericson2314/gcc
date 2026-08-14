#!/bin/sh
# t32-census.sh -- task #32: compiled-once TUs whose behaviour is decided by a
# target macro.  Re-measurement; the briefed 146 files / 498 macros / 925 sites
# are not in STATE.md and could not be reproduced from any script in the tree.
#
# THREE POPULATIONS, EACH MEASURED RATHER THAN LISTED.
#
# 1. VOCABULARY.  Not "names #defined under config/" (over-broad: it grants,
#    and PRINCIPLES section 4 says a granting instrument must be exact) and not
#    tm.texi's @defmac list (misses everything undocumented).  It is the union,
#    over all 48 back ends, of what `cpp -dM' reports through that back end's
#    REAL tm-<base>.h chain, minus a baseline dump with no -imacros so host and
#    compiler builtins drop out.  This is what the compiler actually reads.
#
# 2. DIVERGENCE.  A macro is LEAKY only if the 48 bases do not all agree:
#    either the bodies differ, or some bases define it and others do not.  A
#    macro all 48 define identically is IDENTITY -- converting it changes
#    nothing and proves nothing, so it is reported separately and NOT counted.
#    This also, for free, drops every macro this branch has ALREADY converted:
#    a defaults.h redirect to targetm_cdata is the same text in all 48 dumps.
#
# 3. SITES.  Occurrences in TUs compiled ONCE -- everything under gcc/ that is
#    not config/ (per-base or per-base glue), not testsuite/, and not a
#    generator (gen*.cc run on the build machine and are already per-base).
#
# CLASSIFIED BY POSITION OF USE, which is the axis PRINCIPLES gives and the
# axis that decides the shape of the fix:
#   IFDEF  -- #ifdef / #ifndef / defined(X): asks whether the macro EXISTS.
#   IF     -- #if / #elif arithmetic: needs an integer constant expression.
#   BOUND  -- inside [] in a declaration: needs a constant expression AND
#             decides an object's layout, so it is the target_expmed shape.
#   CASE   -- a case label: constant expression.
#   EXPR   -- everything else: ordinary run-time context.
# Only EXPR is unconditionally convertible to a targetm/target-cdata read.
#
# usage: t32-census.sh <dumpdir> <snapshot-srcdir> <outdir>
set -u
DUMP=${1:?dump dir}; SRC=${2:?snapshot srcdir}; O=${3:?out dir}
mkdir -p "$O"
command -v cpp >/dev/null || { echo "FATAL: cpp not on PATH (dev shell?)"; exit 9; }

B=$(grep -c . "$DUMP/bases.txt" 2>/dev/null || echo 0)
[ "$B" -ge 40 ] || { echo "FATAL: only $B bases dumped"; exit 9; }

# --- baseline: host + compiler builtins, to be subtracted.
echo > "$O/e.c"
cpp -dM -DIN_GCC "$O/e.c" > "$O/baseline.m" 2> "$O/baseline.err"
BL=$(grep -c . "$O/baseline.m")
[ "$BL" -gt 100 ] || { echo "FATAL: baseline dump has $BL macros"; exit 9; }

# --- 1. vocabulary, and 2. divergence, in one pass.
# Key each macro to the SET of distinct bodies across the bases that define it,
# plus how many bases define it at all.
for b in $(cat "$DUMP/bases.txt"); do
  sed -n 's/^#define \([A-Za-z_][A-Za-z_0-9]*\)\((\| \)/\1\t/p' "$DUMP/$b.m" \
    | sed 's/\t.*//' > "$O/$b.names"
  sed -n 's/^#define //p' "$DUMP/$b.m" \
    | sed 's/^\([A-Za-z_][A-Za-z_0-9]*\)\((\)/\1\t\2/; s/^\([A-Za-z_][A-Za-z_0-9]*\) /\1\t/' \
    > "$O/$b.body"
done
sed -n 's/^#define \([A-Za-z_][A-Za-z_0-9]*\).*/\1/p' "$O/baseline.m" | sort -u > "$O/baseline.names"

awk -v NB="$B" '
  FILENAME ~ /baseline.names$/ { host[$0]=1; next }
  {
    split(FILENAME, p, "/"); f=p[length(p)]; sub(/\.body$/, "", f)
    i=index($0, "\t"); if (i==0) next
    n=substr($0,1,i-1); body=substr($0,i+1)
    if (n in host) next
    if (!( (n SUBSEP body) in seen)) { seen[n SUBSEP body]=1; nbody[n]++ }
    ndef[n]++
  }
  END {
    for (n in ndef) {
      if (nbody[n]==1 && ndef[n]==NB) k="IDENTITY"
      else if (nbody[n]>1) k="DIVERGENT-VALUE"
      else k="DIVERGENT-PRESENCE"
      printf "%s\t%s\t%d\t%d\n", k, n, ndef[n], nbody[n]
    }
  }' "$O"/baseline.names "$O"/*.body | sort -k2,2 > "$O/vocab.txt"

NV=$(grep -c . "$O/vocab.txt")
[ "$NV" -gt 500 ] || { echo "FATAL: vocabulary is $NV macros -- too small to be real"; exit 9; }
# A SECOND, INDEPENDENT CONDITION, because divergence across the 48 dumps
# alone is not enough.  Measured: gcn's tm.h chain drags in gcc/system.h, so
# ATTRIBUTE_UNUSED, FOR_EACH_VEC_ELT, ggc_strdup and ~90 other GENERIC macros
# are "defined by 1 of 48 bases" and score DIVERGENT-PRESENCE.  They were the
# four largest site counts in the first run (ATTRIBUTE_UNUSED alone 1512),
# i.e. the pollution was bigger than the signal.
#
# So a macro counts only if it is ALSO `#define'd somewhere under gcc/config/
# -- the thing that makes it a TARGET macro rather than a macro that happens
# to be visible.  This condition GRANTS, so per PRINCIPLES section 4 it is
# exact: it reads the definitions, it does not infer them from a name shape.
grep -rhoE '^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z_0-9]*' "$SRC/gcc/config/" \
  | awk '{print $NF}' | sort -u > "$O/cfgdefs.txt"
NC=$(grep -c . "$O/cfgdefs.txt")
[ "$NC" -gt 1000 ] || { echo "FATAL: only $NC #defines under config/"; exit 9; }

awk -F'\t' '$1!="IDENTITY"{print $2}' "$O/vocab.txt" | sort -u > "$O/leaky.all.txt"
comm -12 "$O/leaky.all.txt" "$O/cfgdefs.txt" > "$O/leaky.txt"
NL=$(grep -c . "$O/leaky.txt")
[ "$NL" -gt 0 ] || { echo "FATAL: no divergent macro at all -- dumps are not per-base"; exit 9; }

echo "== vocabulary (48 bases, host builtins subtracted)"
awk -F'\t' '{c[$1]++} END {for (k in c) printf "  %-20s %d\n", k, c[k]}' "$O/vocab.txt"
echo "  total                $NV"
echo "  LEAKY (non-identity)       $(grep -c . "$O/leaky.all.txt")"
echo "  LEAKY and defined under config/ $NL"

# --- 3. sites in compiled-once TUs.
( cd "$SRC/gcc" && find . -name '*.cc' \
    ! -path './config/*' ! -path './testsuite/*' ! -name 'gen*.cc' \
    ! -path './*/testsuite/*' | sed 's|^\./||' | sort ) > "$O/shared-tus.txt"
NT=$(grep -c . "$O/shared-tus.txt")
[ "$NT" -gt 100 ] || { echo "FATAL: only $NT shared TUs found"; exit 9; }
echo "  compiled-once TUs    $NT"

# One grep over the whole population for the whole leaky set, then classify
# each hit by the POSITION it appears in.
( cd "$SRC/gcc" && grep -n -w -H -F -f "$O/leaky.txt" $(cat "$O/shared-tus.txt") ) \
  > "$O/hits.raw" 2>"$O/hits.err"
NH=$(grep -c . "$O/hits.raw")
# NON-VACUITY: refuse to score if the grep read nothing.
[ "$NH" -gt 0 ] || { echo "FATAL: grep found no site at all -- refusing to score"; exit 9; }

# A THIRD condition, applied only to VALUE uses, and it is what separates a
# real site from an identifier that merely shares a target macro's spelling.
#
# Measured: `SIGNED' and `UNSIGNED' scored 323 and 279 sites.  Neither is a
# target macro at those sites -- they are the generic `signop' enumerators in
# gimple-fold.cc and pointer-query.cc.  They entered the vocabulary because
# `config/arc/arc.h:626' defines a FUNCTION-LIKE `SIGNED(X,V)', which no
# shared TU can see.  Together they were 8% of the census.
#
# The discriminator is exact and needs no heuristic: a shared TU is compiled
# against the PRIMARY's tm.h, so if it uses a name in an EXPRESSION or an
# array BOUND and that name is not defined in the primary's dump, the name is
# not a macro there at all -- it is an enumerator, a variable or a function,
# and the code would not compile otherwise.
#
# It is deliberately NOT applied to #ifdef/#if, because "the primary does not
# define it" is precisely the leak in those positions: the shared conditional
# then evaluates by the primary's silence, for every back end.
D=$(dirname "$DUMP")
[ -s "$DUMP/i386.m" ] || { echo "FATAL: no primary dump to filter against"; exit 9; }
cut -f1 "$O/i386.body" | sort -u > "$O/primary.names"
[ "$(grep -c . "$O/primary.names")" -gt 1000 ] || { echo "FATAL: primary name set too small"; exit 9; }

awk -F: -v L="$O/leaky.txt" -v P="$O/primary.names" '
  BEGIN { while ((getline n < L) > 0) if (n != "") leak[n]=1
          while ((getline n < P) > 0) if (n != "") prim[n]=1 }
  {
    file=$1; line=$2
    txt=$0; sub("^[^:]*:[^:]*:", "", txt)
    # strip // comments and string literals so a macro NAMED in prose or in a
    # diagnostic string is not scored as a use.
    gsub(/"[^"]*"/, "\"\"", txt)
    sub(/\/\/.*/, "", txt)
    t=txt; sub(/^[ \t]+/, "", t)
    kind="EXPR"
    if (t ~ /^#[ \t]*(ifdef|ifndef)[ \t]/) kind="IFDEF"
    else if (t ~ /^#[ \t]*(if|elif)[ \t]/) kind="IF"
    else if (t ~ /^#[ \t]*(define|undef|include|pragma|error|warning)/) kind="PP-OTHER"
    else if (t ~ /^case[ \t(]/) kind="CASE"
    else if (t ~ /\[[^]]*\][ \t]*(=|;|\[)/) kind="BOUND"
    nm=""
    s=txt
    while (match(s, /[A-Za-z_][A-Za-z_0-9]*/)) {
      w=substr(s, RSTART, RLENGTH)
      if (w in leak) { nm=w; break }
      s=substr(s, RSTART+RLENGTH)
    }
    if (nm=="") next
    if (kind=="IF" && txt ~ /defined[ \t]*\(?[ \t]*[A-Za-z_]/) kind="IFDEF"
    if ((kind=="EXPR" || kind=="BOUND" || kind=="CASE") && !(nm in prim)) {
      printf "%s\t%s\t%s\t%s\n", "NOT-A-MACRO-HERE", nm, file, line > "/dev/stderr"
      next
    }
    printf "%s\t%s\t%s\t%s\n", kind, nm, file, line
  }' "$O/hits.raw" 2> "$O/rejected.txt" | sort > "$O/sites.txt"
echo "  rejected as NOT-A-MACRO-HERE: $(grep -c . "$O/rejected.txt") sites, $(cut -f2 "$O/rejected.txt" | sort -u | grep -c .) names"

NS=$(grep -c . "$O/sites.txt")
[ "$NS" -gt 0 ] || { echo "FATAL: classified 0 sites from $NH grep hits"; exit 9; }

echo
echo "== sites in compiled-once TUs, by POSITION OF USE"
awk -F'\t' '{c[$1]++} END {for (k in c) printf "  %-10s %d\n", k, c[k]}' "$O/sites.txt" | sort -k2 -rn
echo "  ---------------"
echo "  sites      $NS"
echo "  macros     $(cut -f2 "$O/sites.txt" | sort -u | grep -c .)"
echo "  files      $(cut -f3 "$O/sites.txt" | sort -u | grep -c .)"
