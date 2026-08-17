#!/bin/sh
# agent-a8f6f467d15197cd3-macrocensus.sh -- for EACH named macro, what does
# every back end's own header chain say, and what does SHARED code get?
#
# This is agent-ad6a5c1d2539f5e18-vbitcensus.sh generalised from one macro to
# a list, and it exists because of the correction that census produced: THE
# BRIEF SAID FIVE BACK ENDS AND IT WAS EIGHT.  Counting the back ends that
# SPELL a macro undercounts it -- four reached `ptrmemfunc_vbit_in_delta'
# through `defaults.h''s FUNCTION_BOUNDARY fallback, which no directory grep
# can see.  So this asks the real preprocessor over each base's real
# `tm-<base>.h', never a grep, and prints:
#
#   DISTINCT  how many different values the 47 bases give.  1 means the macro
#             does not diverge and the leak is harmless TODAY (say so; do not
#             call it converted).  >1 is a real divergence.
#   SHARED    what the shared `tm.h' -- i.e. the PRIMARY's chain -- gives.
#             This is the value every shared TU actually reads.
#   WRONG-FOR how many of the 47 bases disagree with SHARED.  This is the
#             population, and it is the number to rank on.
#
# `cpp -dM' PRINTS THE BODY, NOT THE VALUE, AND THE FIRST VERSION OF THIS
# SCRIPT RANKED ON THE BODY.  That over-counts, and not by a little.  On the
# first run it scored `CHAR_TYPE_SIZE' as wrong for 4 back ends because the
# shared body is `BITS_PER_UNIT' and bfin/bpf/frv/visium spell `8' -- the same
# number written two ways -- and `LONG_LONG_TYPE_SIZE' as wrong for 9 because
# nine 32-bit back ends spell `(BITS_PER_WORD * 2)' where the primary spells
# `64'.  Neither is a divergence.  A textual comparison of macro BODIES
# answers "is this spelled the same", and the question is "does this MEAN the
# same" -- PRINCIPLES: state the question your check asks and compare it to
# the question you need answered.
#
# So each macro is now EXPANDED (a second `cpp' pass over a probe file, which
# resolves nested macros) and, where the expansion is pure integer
# arithmetic, EVALUATED.  Three columns result and they are deliberately not
# collapsed: TEXT-DIFF (bodies differ), VALUE-DIFF (values differ, computed
# only where both sides reduce to a number), and UNRESOLVED (the expansion
# names option state or a function -- `TARGET_64BIT', `GET_MODE_BITSIZE' --
# so no static answer exists and the count says so instead of guessing).
#
# WHY IT PREPROCESSES A `.c' AND WHAT THAT BUYS.  `multi-target-macros.h''s
# redirect block is skipped when `__cplusplus' is undefined, so a `.c' probe
# reads the SUPPLY side -- what each base's headers SAY -- regardless of what
# the branch has already converted.  That is what makes the WRONG-FOR column
# meaningful for a macro that is already redirected: it says how big the
# defect WAS, which is how you check a conversion did something.  A converted
# macro's WRONG-FOR does not drop to 0 here and must not be expected to.
#
# NULL-RESULT ARM.  "cpp produced nothing" and "the macro is absent" are the
# same empty grep.  A base whose dump is empty is UNREADABLE, counted, and
# makes the run exit nonzero.  A macro no base defines at all is reported as
# NOWHERE rather than silently scoring DISTINCT=0, because an unreadable name
# and an undefined one are the two readings that must not look alike.
#
# usage: [MACROS='A B C'] agent-a8f6f467d15197cd3-macrocensus.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
D=${1:?build dir}
[ -d "$D/gcc" ] || { echo "FATAL: $D/gcc missing"; exit 9; }

MACROS=${MACROS:-'TARGET_VTABLE_ENTRY_ALIGN POINTER_SIZE MAX_FIXED_MODE_SIZE
MALLOC_ABI_ALIGNMENT PCC_BITFIELD_TYPE_MATTERS BYTES_BIG_ENDIAN
STRICT_ALIGNMENT WORDS_BIG_ENDIAN BITS_PER_WORD DATA_ABI_ALIGNMENT
INT_TYPE_SIZE SHORT_TYPE_SIZE LONG_TYPE_SIZE LONG_LONG_TYPE_SIZE
WCHAR_TYPE_SIZE CHAR_TYPE_SIZE BOOL_TYPE_SIZE'}

BASES=""
for d in "$SRC"/gcc/config/*/; do
  b=$(basename "$d")
  ls "$d" | grep -q '\.md$' || continue
  [ -f "$D/gcc/tm-$b.h" ] && BASES="$BASES $b"
done
BASES=$(echo $BASES | tr ' ' '\n' | sort)
NB=$(echo $BASES | wc -w)
[ "$NB" -ge 40 ] || { echo "FATAL: found only $NB tm-<base>.h in $D/gcc"; exit 9; }

# ASSERT THE TOOL BEFORE SCORING ANYTHING.  `cpp' is NOT on PATH outside the
# nix dev shell (PRINCIPLES section 5), and `cpp: command not found' piped
# into the `sed' below yields an empty dump for every base -- which this
# script would then report as 47 UNREADABLE bases.  That is loud and it is
# still the wrong diagnosis: the bases are fine and the shell is wrong.  Run
# it through scratchpad/eb-shell.sh.
command -v cpp > /dev/null 2>&1 \
  || { echo "FATAL: no \`cpp' on PATH -- run this inside scratchpad/eb-shell.sh,"; \
       echo "       not from a bare shell.  The bases are readable; the shell is not."; exit 9; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' 0
: > "$WORK/e.c"
INC="-I$D/gcc -I$SRC/gcc -I$SRC/gcc/config -I$SRC/include -I$D/gcc/include -DIN_GCC"

# ---- dump every base once, plus the SHARED tm.h -------------------------
nunread=0
for b in $BASES; do
  cpp -dM $INC -imacros "$D/gcc/tm-$b.h" "$WORK/e.c" > "$WORK/m.$b" 2>"$WORK/err.$b"
  [ -s "$WORK/m.$b" ] || { echo "UNREADABLE base $b:"; sed -n 1,3p "$WORK/err.$b" | sed 's/^/    /'; nunread=$((nunread+1)); }
done
cpp -dM $INC -imacros "$D/gcc/tm.h" "$WORK/e.c" > "$WORK/m.SHARED" 2>"$WORK/err.SHARED"
[ -s "$WORK/m.SHARED" ] || { echo "FATAL: shared tm.h unreadable"; sed -n 1,5p "$WORK/err.SHARED"; exit 9; }

# CONTROL, run BEFORE anything is scored: a macro known to diverge and a
# macro known not to exist.  An all-DISTINCT=1 table and a broken -imacros
# produce the same output, and that is the failure this refuses to make.
cd=$(for b in $BASES; do sed -n 's/^#define FUNCTION_BOUNDARY //p' "$WORK/m.$b"; done | sort -u | wc -l)
[ "$cd" -ge 2 ] || { echo "FATAL: control FUNCTION_BOUNDARY has $cd distinct values over $NB bases"; exit 9; }
cn=$(for b in $BASES; do sed -n 's/^#define MT_NO_SUCH_MACRO_XYZ //p' "$WORK/m.$b"; done | sort -u | wc -l)
[ "$cn" = 0 ] || { echo "FATAL: negative control present"; exit 9; }
echo "bases=$NB unreadable=$nunread   controls ok: FUNCTION_BOUNDARY $cd distinct, negative 0"
echo

# ---- EXPAND every macro in every base, in ONE cpp pass per base ---------
# A probe file naming each macro on its own line, tagged so the expansion can
# be found again.  `cpp' without `-dM' expands nested macros, which is what
# turns `BITS_PER_UNIT' into `8' and `(BITS_PER_WORD * 2)' into `(8 * 4 * 2)'.
# THE TAG MUST NOT BE THE MACRO'S OWN NAME.  The first draft emitted
#     MTPROBE POINTER_SIZE : POINTER_SIZE
# and `cpp' expanded BOTH occurrences, so the label vanished, every `sed'
# lookup missed, and the table came back `NOWHERE' for all seventeen macros
# -- which reads exactly like "nothing diverges".  Recorded rather than
# quietly fixed: it is the null-result-as-a-pass shape arriving inside the
# instrument written to avoid it, and it got past the SHARED non-emptiness
# control because the file was full of correctly-expanded lines with no
# labels on them.  The tag is now an INDEX, which no header can define.
: > "$WORK/probe.c"
: > "$WORK/index"
i=0
for m in $MACROS; do
  i=$((i + 1))
  printf '%s\t%s\n' "$i" "$m" >> "$WORK/index"
  printf '#ifdef %s\nMTPROBE %s : %s\n#endif\n' "$m" "$i" "$m" >> "$WORK/probe.c"
done
for b in $BASES SHARED; do
  h="$D/gcc/tm-$b.h"; [ "$b" = SHARED ] && h="$D/gcc/tm.h"
  cpp -P $INC -imacros "$h" "$WORK/probe.c" 2>/dev/null \
    | tr -s ' ' | grep '^MTPROBE ' > "$WORK/x.$b" || true
done
# CONTROL ON THE EXPANDER ITSELF: it must have expanded something.  An empty
# probe output and a macro that is genuinely absent everywhere read the same.
grep -q . "$WORK/x.SHARED" || { echo "FATAL: expansion pass produced nothing for SHARED"; exit 9; }
# AND THE CROSS-CHECK THAT WOULD HAVE CAUGHT THE VANISHED TAG.  The `-dM' pass
# and the expansion pass must agree on HOW MANY of the listed macros the
# shared chain defines.  When the label was being expanded away they read 17
# and 0, and only the second was believed.  Two instruments, one fact.
ndm=0
for m in $MACROS; do
  grep -q "^#define $m\([ (]\)" "$WORK/m.SHARED" && ndm=$((ndm + 1))
done
nex=$(grep -c '^MTPROBE ' "$WORK/x.SHARED" || true)
[ "$ndm" = "$nex" ] || {
  echo "FATAL: -dM says the shared chain defines $ndm of the listed macros,"
  echo "       the expansion pass recovered $nex.  The two passes disagree, so"
  echo "       neither is trusted.  (A vanished probe label reads as 'NOWHERE'"
  echo "       for every macro, i.e. as 'nothing diverges'.)"
  exit 9; }
echo "expansion pass ok: -dM and expansion agree, $ndm of $(echo $MACROS | wc -w) macros defined in the shared chain"

# eval_expr: echo a number if the token string is pure integer arithmetic,
# nothing otherwise.  Deliberately strict -- an identifier, a function call or
# a `?:' on option state yields NOTHING and the caller reports UNRESOLVED
# rather than inventing a value.
eval_expr () {
  case "$1" in
    *[A-Za-z_]*) return ;;                 # any identifier left -> not static
  esac
  case "$1" in
    *[!0-9\ \(\)+*/-]*) return ;;          # only integers and + - * / ( )
  esac
  echo "$1" | awk '{ print "BEGIN{print (" $0 ")}" }' | awk -f /dev/stdin 2>/dev/null
}

printf '%-30s %6s %6s %10s %10s  %s\n' MACRO DEFS TEXTS TEXT-DIFF VALUE-DIFF 'SHARED expansion'
idx=0
for m in $MACROS; do
  idx=$((idx + 1))
  : > "$WORK/vals"
  ndef=0
  for b in $BASES; do
    v=$(sed -n "s/^MTPROBE $idx : //p" "$WORK/x.$b")
    [ -n "$v" ] && { ndef=$((ndef+1)); printf '%s\t%s\n' "$b" "$v" >> "$WORK/vals"; }
  done
  sv=$(sed -n "s/^MTPROBE $idx : //p" "$WORK/x.SHARED")
  if [ "$ndef" = 0 ]; then
    printf '%-30s %6s %6s %10s %10s  %s\n' "$m" 0 - - - '(NOWHERE: no base defines it)'
    continue
  fi
  if [ -z "$sv" ]; then
    printf '%-30s %6s %6s %10s %10s  %s\n' "$m" "$ndef" - - - \
      '(SHARED does not define it: shared code reads NOTHING)'
    continue
  fi
  texts=$(cut -f2 "$WORK/vals" | sort -u | wc -l)
  tdiff=$(awk -F'\t' -v s="$sv" '$2 != s' "$WORK/vals" | wc -l)
  sval=$(eval_expr "$sv")
  vdiff=0; unres=0
  : > "$WORK/vdlist"
  while IFS="	" read -r b v; do
    [ "$v" = "$sv" ] && continue
    bv=$(eval_expr "$v")
    if [ -z "$sval" ] || [ -z "$bv" ]; then
      unres=$((unres + 1))
    elif [ "$bv" != "$sval" ]; then
      vdiff=$((vdiff + 1)); printf '%-12s %s\n' "$b" "$bv" >> "$WORK/vdlist"
    fi
  done < "$WORK/vals"
  vd="$vdiff/$ndef"
  [ "$unres" -gt 0 ] && vd="$vd+${unres}?"
  printf '%-30s %6s %6s %10s %10s  %s\n' "$m" "$ndef" "$texts" "$tdiff/$ndef" "$vd" \
    "$(echo "$sv" | cut -c1-40)$([ -n "$sval" ] && echo "  = $sval")"
  if [ "$vdiff" -gt 0 ] && [ "$vdiff" -le 12 ]; then
    sed 's/^/      /' "$WORK/vdlist"
  fi
done
echo
echo "TEXT-DIFF ranks on macro BODIES and OVER-counts (same number, two spellings)."
echo "VALUE-DIFF is the real population where both sides reduce to an integer."
echo "The '+N?' suffix is UNRESOLVED: the expansion names option state or a"
echo "function, so no static answer exists -- those are NOT scored either way."
[ "$nunread" = 0 ] || { echo "EXIT 9: $nunread base(s) unreadable -- figures above are incomplete"; exit 9; }
