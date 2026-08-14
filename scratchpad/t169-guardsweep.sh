#!/bin/sh
# #169 -- THE CAUSE CLASS NO SYMBOL SWEEP CAN FIND.
#
# THE SHAPE.  A SHARED translation unit compiles a function, a declaration, a
# value or a code path OUT under `#if <per-base target macro>' -- read against
# the PRIMARY's tm.h chain -- while a per-base object needs it.  Four instances
# were each found by walking into a wall:
#
#   only_leaf_regs_used            final.cc:4150   #ifdef LEAF_REGISTERS
#   immed_double_const             emit-rtl.cc:695 #if TARGET_SUPPORTS_WIDE_INT == 0
#   merge_dllimport_decl_attributes                 (mcore)
#   AUTO_INC_DEC                   rtl.h:2876      defined (HAVE_PRE_INCREMENT) x8
#
# A SYMBOL SWEEP CANNOT FIND THESE BEFORE THEY FIRE, because the definition is
# not there to be found: `nm' has nothing to report about code the preprocessor
# deleted.  Nor can a build, for the silent half -- see below.
#
# THE TWO HALVES, and the second is the dangerous one:
#
#   LOUD   the guard deletes a DEFINITION something references.  Costs a back
#          end at link time.  Enumerable ahead of the link, which is the point.
#   SILENT the guard changes a VALUE or selects a different code path.  No
#          diagnostic ever exists.  Probably the larger half.
#
# TWO AXES OF DIVERGENCE, and an instrument that reads only the first is
# wrong about most of the population:
#
#   PRESENCE  some bases define the macro, others do not -> `#ifdef' differs
#             per base.  (HAVE_PRE_INCREMENT: 8 of 48, i386 not among them.)
#   VALUE     every base defines it -- usually because defaults.h, which is in
#             every chain, supplies a floor -- but the VALUES differ.  A
#             presence-only instrument scores these 48/48 and reports them
#             clean.  Measured: TARGET_DLLIMPORT_DECL_ATTRIBUTES is 48/48.
#
# AND A THIRD READING THAT MUST NOT BE SCORED AS A DEFECT: a macro this branch
# has already CONVERTED expands to `mt_foo ()' or `targetm_cdata.foo' and is
# therefore 48/48 with one identical value.  That is the fix, not the bug.
# LOAD_EXTEND_OP and MAX_STACK_ALIGNMENT both read that way now.  They are
# reported in their own column so that a converted macro cannot be re-filed as
# an open one -- and so that the reverse, a conversion regressing, is visible.
#
# usage: t169-guardsweep.sh <dumpdir> <srcdir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
O=${1:?dump dir (t169-dump.sh output)}
D_MK=${3:?build dir holding the generated multi-target-*.mk}
SRC=${2:?srcdir (the snapshot)}
O=$(cd "$O" && pwd); SRC=$(cd "$SRC" && pwd)
W=$O/sweep; mkdir -p "$W"

[ -s "$O/bases" ] || { echo "FATAL: $O/bases empty -- run t169-dump.sh"; exit 9; }
NBASE=$(grep -c . "$O/bases")
[ "$NBASE" -ge 40 ] || { echo "FATAL: only $NBASE bases dumped"; exit 9; }

# ---------------------------------------------------------------- population
# SHARED sources are everything under gcc/ that is NOT under config/ and not a
# testsuite.  That is the same population PRINCIPLES counts ("248 files outside
# config/ include tm.h", "625 shared TUs").  Per-base sources live under
# config/ and are compiled once per base that claims them, so a guard there is
# read against that base's own headers and is not this defect.
#
# "OUTSIDE config/" IS NOT THE SAME AS "SHARED", AND THE FIRST RUN OF THIS
# SWEEP GOT IT WRONG.  `gcc/target-regs.cc', `gcc/target-cumargs.cc',
# `gcc/target-regstack.cc' and their siblings sit at gcc/ and are compiled
# ONCE PER BASE, with `-I<base>-inc' and `-DMULTI_TARGET_SUPPLY_TU'.  A guard
# in one of those reads THAT base's headers and is correct by construction --
# it is the mechanism, not the defect.  Scoring them put
# `DATA_ALIGNMENT ... target-cumargs.cc:344' at the top of the LOUD table,
# which is exactly backwards: that line is the fix for DATA_ALIGNMENT.
#
# The authority is the generated makefile, not a filename pattern:
# `multi-target-md.mk' and `multi-target-common.mk' name every `$(srcdir)/X'
# that configure wrote a per-base rule for.  PRINCIPLES: ask what the build
# actually does, not what the directory layout suggests.
: > "$W/perbase"
for mk in "$D_MK"/multi-target-md.mk "$D_MK"/multi-target-common.mk; do
  [ -f "$mk" ] || continue
  grep -o '\$(srcdir)/[A-Za-z0-9/_.-]*\.cc' "$mk" | sed 's|\$(srcdir)/||' >> "$W/perbase"
done
sort -u "$W/perbase" -o "$W/perbase"
NP=$(grep -c . "$W/perbase")
[ "$NP" -gt 0 ] || { echo "FATAL: read no per-base sources from the generated"
                     echo "       makefiles; every supply-side TU would then be"
                     echo "       scored as a shared one, in the direction that"
                     echo "       reports the FIX as the defect"; exit 9; }
echo "per-base (supply-side) sources excluded: $NP"

find "$SRC/gcc" \( -name config -o -name testsuite \) -prune -o \
     \( -name '*.cc' -o -name '*.c' -o -name '*.h' \) -print | sort \
  | awk -v P="$W/perbase" -v S="$SRC/gcc/" '
      BEGIN { while ((getline l < P) > 0) if (l != "") p[S l] = 1 }
      !($0 in p)' > "$W/files"
NF=$(grep -c . "$W/files")
echo "shared sources: $NF files"
[ "$NF" -gt 500 ] || { echo "FATAL: only $NF shared sources -- find is not reading the tree"; exit 9; }

# ------------------------------------------------------------------- phase 1
# Every preprocessor conditional, with the brace depth it opened at and what
# the region contains.  Brace depth is the discriminator that separates LOUD
# from SILENT: a region opened at depth 0 in a .cc can delete a DEFINITION; a
# region opened inside a function body can only change control flow.
#
# `depth rises above 0 inside the region' is used rather than a regex for
# "looks like a function definition".  A `{' at file scope IS a body -- a
# function, an initialiser, a struct -- and no amount of return-type and
# attribute spelling can hide it, whereas the regex version misses
# `static const struct foo bar[] = {' and matches every `if (' in a macro.
awk '
  function flush(  k) {
    if (top < 1) return
    k = ident[top]
    if (k != "")
      printf "%s\t%d\t%d\t%d\t%d\t%d\t%s\n", file[top], line[top], d0[top],
             rose[top], hasdef[top], hassemi[top], k
  }
  FNR == 1 { f = FILENAME; depth = 0; top = 0; incomment = 0 }
  {
    l = $0
    # crude but symmetric literal/comment stripping: it can only LOSE braces,
    # and a lost brace makes a region look SILENT, so this instrument
    # under-reports LOUD rather than inventing it.
    gsub(/\\./, "", l)
    gsub(/"[^"]*"/, "", l)
    gsub(/'"'"'[^'"'"']*'"'"'/, "", l)
    sub(/\/\/.*/, "", l)
    gsub(/\/\*[^*]*\*\//, "", l)

    if (l ~ /^[ \t]*#[ \t]*(if|ifdef|ifndef)/) {
      c = l; sub(/^[ \t]*#[ \t]*(ifdef|ifndef|if)[ \t]*/, "", c)
      gsub(/defined[ \t]*\(?/, " ", c)
      ids = ""
      n = split(c, t, /[^A-Za-z_0-9]+/)
      for (i = 1; i <= n; i++)
        if (t[i] ~ /^[A-Za-z_][A-Za-z_0-9]*$/ && t[i] !~ /^[0-9]/) ids = ids " " t[i]
      top++
      file[top] = f; line[top] = FNR; d0[top] = depth
      rose[top] = 0; hasdef[top] = 0; hassemi[top] = 0
      sub(/^ /, "", ids); ident[top] = ids
      next
    }
    if (l ~ /^[ \t]*#[ \t]*(elif|else)/) { flush(); if (top>0) { line[top]=FNR; rose[top]=0; hasdef[top]=0; hassemi[top]=0; ident[top]="" } ; next }
    if (l ~ /^[ \t]*#[ \t]*endif/)       { flush(); if (top>0) top--; next }
    if (l ~ /^[ \t]*#[ \t]*define/ && top > 0) hasdef[top] = 1

    o = gsub(/\{/, "{", l); c2 = gsub(/\}/, "}", l)
    if (top > 0 && l ~ /;/) hassemi[top] = 1
    depth += o - c2
    if (depth < 0) depth = 0
    if (top > 0 && depth > d0[top]) rose[top] = 1
  }
' $(cat "$W/files") > "$W/sites.raw"

NS=$(grep -c . "$W/sites.raw" || true)
echo "conditional regions with at least one identifier: $NS"
[ "$NS" -gt 1000 ] || { echo "FATAL: only $NS regions -- the scanner read nothing"; exit 9; }

# ------------------------------------------------------------------- phase 2
# Per-macro answer, from the 48 real header chains.
awk -v BL="$O/bases" -v DIR="$O" '
  BEGIN {
    nb = 0
    while ((getline b < BL) > 0) if (b != "") { bases[++nb] = b }
    for (j = 1; j <= nb; j++) {
      fn = DIR "/" bases[j] ".m"
      while ((getline l < fn) > 0) {
        p = index(l, "\t"); if (p == 0) continue
        nm = substr(l, 1, p-1); vv = substr(l, p+1)
        def[nm, bases[j]] = 1; val[nm, bases[j]] = vv
        ndef[nm]++
      }
      close(fn)
    }
    print nb > "/dev/stderr"
  }
  { print }
' /dev/null 2>"$W/nbases" || true

# The per-macro table is built in one awk over the site list plus the dumps.
awk -v BL="$O/bases" -v DIR="$O" -v OUT="$W" '
  BEGIN {
    nb = 0
    while ((getline b < BL) > 0) if (b != "") bases[++nb] = b
    close(BL)
    for (j = 1; j <= nb; j++) {
      fn = DIR "/" bases[j] ".m"
      while ((getline l < fn) > 0) {
        p = index(l, "\t"); if (p == 0) continue
        nm = substr(l, 1, p-1)
        def[nm SUBSEP bases[j]] = 1
        val[nm SUBSEP bases[j]] = substr(l, p+1)
        ndef[nm]++
      }
      close(fn)
    }
  }
  {
    split($0, F, "\t")
    f = F[1]; ln = F[2]; dd = F[3]; rose = F[4]; hasdef = F[5]; hassemi = F[6]
    n = split(F[7], ids, / /)

    # classify the REGION once
    isheader = (f ~ /\.h$/)
    if (dd > 0)               cls = "SILENT-FLOW"
    else if (isheader && hasdef) cls = "SILENT-VALUE"
    else if (rose)            cls = "LOUD-DEF"
    else if (hasdef)          cls = "SILENT-VALUE"
    else if (hassemi)         cls = "LOUD-DECL"
    else                      cls = "SILENT-OTHER"

    for (i = 1; i <= n; i++) {
      m = ids[i]
      if (!(m in ndef)) continue          # not a target macro at all
      key = m
      sites[key]++
      cnt[key SUBSEP cls]++
      if (!(key SUBSEP cls SUBSEP f SUBSEP ln in seen)) {
        seen[key SUBSEP cls SUBSEP f SUBSEP ln] = 1
        where[key SUBSEP cls] = where[key SUBSEP cls] " " f ":" ln
      }
      macros[key] = 1
    }
  }
  END {
    # per-macro divergence, over the 48 real chains
    for (m in macros) {
      nv = 0; delete seenv
      converted = 0
      for (j = 1; j <= nb; j++) {
        b = bases[j]
        if (!((m SUBSEP b) in def)) continue
        v = val[m SUBSEP b]
        if (!(v in seenv)) { seenv[v] = 1; nv++ }
        if (v ~ /mt_[a-z_]*[ ]*\(/ || v ~ /targetm_cdata/) converted = 1
      }
      iv = ((m SUBSEP "i386") in def) ? val[m SUBSEP "i386"] : "<undefined>"
      av = ((m SUBSEP "aarch64") in def) ? val[m SUBSEP "aarch64"] : "<undefined>"
      # is the primary in the minority?
      same = 0
      for (j = 1; j <= nb; j++) {
        b = bases[j]
        bv = ((m SUBSEP b) in def) ? val[m SUBSEP b] : "<undefined>"
        if (bv == iv) same++
      }
      minority = (same * 2 <= nb) ? "MINORITY" : "majority"

      axis = "agree"
      if (ndef[m] < nb)      axis = "PRESENCE"
      else if (nv > 1)       axis = "VALUE"
      if (converted && nv == 1) axis = "CONVERTED"

      printf "%s\t%d\t%d\t%d\t%s\t%s\t%d\t%s\t%s\n",
             m, ndef[m], nv, same, axis, minority, sites[m], iv, av > (OUT "/macros.tsv")
      for (c in ck) delete ck[c]
      for (k in cnt) {
        split(k, K, SUBSEP)
        if (K[1] != m) continue
        printf "%s\t%s\t%d\t%s\n", m, K[2], cnt[k], where[k] > (OUT "/sites.tsv")
      }
    }
  }
' "$W/sites.raw"

NM=$(grep -c . "$W/macros.tsv" || true)
echo "target macros appearing in shared-source conditionals: $NM"
[ "$NM" -gt 20 ] || { echo "FATAL: only $NM macros matched -- the intersection is empty"; exit 9; }
echo "wrote $W/macros.tsv $W/sites.tsv"
