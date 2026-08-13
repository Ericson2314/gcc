#!/bin/sh
# #139 -- INJECT DYNAMIC COUNTERS for `Pmode' and `UNITS_PER_WORD'.
#
# The brief asks whether the 267 `UNITS_PER_WORD' sites are uniformly hot,
# and says to FIND OUT rather than assume.  A static count cannot answer it:
# a site in `fold-const.cc' and a site in `lower-subreg.cc' are one line each
# and differ by orders of magnitude at run time.  So this builds a cc1 that
# counts, per source file, how many times each macro is EVALUATED during a
# real compilation.  Timing of this build is meaningless and is not used.
#
# THE COUNTER GOES INSIDE THE EXISTING SHARED-CONSUMER GUARD in defaults.h
# (`#if defined (MULTI_TARGET_TARGETM_BASE) || ... #else'), which is where the
# `Pmode' redirect already lives.  A back end's own TU, a generator, or a C
# consumer such as libgcc must keep the real macros -- an unguarded redefine
# breaks aarch64's own TU, where `TARGET_64BIT' does not exist.
#
# `UNITS_PER_WORD' is redefined to i386's expression `(TARGET_64BIT ? 8 : 4)'.
# That is NOT a new leak introduced by the measurement: it is EXACTLY what a
# shared TU already sees today, because the macro is unconverted and i386's
# tm.h supplies it.  The counting build is therefore value-identical to HEAD,
# and that is asserted afterwards by comparing its .s output with HEAD's.
#
# usage: t139-count-inject.sh <srcdir>
set -e
SRC=${1:?srcdir}
D=$SRC/gcc
[ -f "$D/defaults.h" ] || { echo "FATAL: no gcc/defaults.h under $SRC"; exit 9; }

# --- 1. the counter implementation, appended to the shared select TU --------
# `mt_pmode' already lives here and this file is linked once into cc1, so the
# counters are single instances without touching the Makefile.
cat >> "$D/target-cumargs-select.cc" <<'EOF'

/* ------------------------------------------------------------------------
   t139 MEASUREMENT ONLY.  Per-source-file evaluation counts for the macros
   under costing.  Lookup is by POINTER identity of __FILE__, which is one
   literal per translation unit and therefore O(1)-ish; names are merged by
   string only when the table is printed, so the hot path stays a compare and
   an increment.  Printed from a destructor so no call site has to be added.  */
struct mt_cnt_ent { const char *file; unsigned long n; };
#define MT_CNT_MAX 512
static struct mt_cnt_ent mt_cnt_upw[MT_CNT_MAX];
static struct mt_cnt_ent mt_cnt_pmode[MT_CNT_MAX];
static int mt_cnt_upw_n, mt_cnt_pmode_n;
static unsigned long mt_cnt_upw_overflow, mt_cnt_pmode_overflow;

static void
mt_cnt_bump (struct mt_cnt_ent *t, int *n, unsigned long *ovf, const char *f)
{
  for (int i = 0; i < *n; i++)
    if (t[i].file == f)
      {
	t[i].n++;
	return;
      }
  if (*n >= MT_CNT_MAX)
    {
      (*ovf)++;
      return;
    }
  t[*n].file = f;
  t[*n].n = 1;
  (*n)++;
}

void mt_upw_hit (const char *f)   { mt_cnt_bump (mt_cnt_upw, &mt_cnt_upw_n,
						 &mt_cnt_upw_overflow, f); }
void mt_pmode_hit (const char *f) { mt_cnt_bump (mt_cnt_pmode, &mt_cnt_pmode_n,
						 &mt_cnt_pmode_overflow, f); }

static void
mt_cnt_dump_one (const char *tag, struct mt_cnt_ent *t, int n, unsigned long ovf)
{
  unsigned long tot = 0;
  for (int i = 0; i < n; i++)
    tot += t[i].n;
  fprintf (stderr, "T139COUNT %s total %lu files %d overflow %lu\n",
	   tag, tot, n, ovf);
  for (int i = 0; i < n; i++)
    fprintf (stderr, "T139COUNT %s %lu %s\n", tag, t[i].n, t[i].file);
}

static void __attribute__ ((destructor))
mt_cnt_dump (void)
{
  mt_cnt_dump_one ("UNITS_PER_WORD", mt_cnt_upw, mt_cnt_upw_n,
		   mt_cnt_upw_overflow);
  mt_cnt_dump_one ("Pmode", mt_cnt_pmode, mt_cnt_pmode_n,
		   mt_cnt_pmode_overflow);
}
EOF

# --- 2. the redirects, appended INSIDE the shared-consumer guard ------------
# The guard's `#else' arm ends at the `#endif' that closes the block opened at
# the `#if defined (MULTI_TARGET_TARGETM_BASE)' line.  Rather than guess at
# line numbers, the redirect is inserted immediately after the `Pmode' one,
# which is known to be inside it.
awk '
  /^#define Pmode \(mt_pmode \(\)\)$/ {
    print "#define Pmode (mt_pmode_hit (__FILE__), mt_pmode ())";
    print "";
    print "/* t139 MEASUREMENT ONLY -- count UNITS_PER_WORD evaluations per file.";
    print "   The value is i386'\''s own expression, which is what a shared TU";
    print "   already sees today; nothing about the answer changes.  */";
    print "extern void mt_upw_hit (const char *);";
    print "extern void mt_pmode_hit (const char *);";
    print "#undef UNITS_PER_WORD";
    print "#define UNITS_PER_WORD (mt_upw_hit (__FILE__), (TARGET_64BIT ? 8 : 4))";
    seen = 1;
    next;
  }
  { print }
  END { if (!seen) { print "T139: FATAL: Pmode redirect not found" > "/dev/stderr"; exit 9 } }
' "$D/defaults.h" > "$D/defaults.h.t139" || exit 9
mv "$D/defaults.h.t139" "$D/defaults.h"

# --- 3. ASSERT THE INJECTION PRODUCED THE STATE INTENDED --------------------
# An injection that silently does nothing reads exactly like a macro that is
# never evaluated -- the null result this project keeps confusing for success.
grep -q 'mt_pmode_hit (__FILE__), mt_pmode ()' "$D/defaults.h" \
  || { echo "FATAL: Pmode counter not injected"; exit 9; }
grep -q 'mt_upw_hit (__FILE__), (TARGET_64BIT ? 8 : 4)' "$D/defaults.h" \
  || { echo "FATAL: UNITS_PER_WORD counter not injected"; exit 9; }
grep -q 'T139COUNT' "$D/target-cumargs-select.cc" \
  || { echo "FATAL: counter implementation not appended"; exit 9; }
grep -c 'mt_pmode ())' "$D/defaults.h" | grep -qx 1 \
  || { echo "FATAL: more than one Pmode redirect line survives"; exit 9; }
echo "injection OK in $SRC"
