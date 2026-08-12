#!/usr/bin/env bash
#
# THE PER-MACRO ARM.  One probe per leaked target macro, replacing the single
# unreachable "aarch64 asm is byte-identical to a reference" gate.
#
# WHAT IS MEASURED
#
#   A middle-end translation unit in the multi-target build sees the PRIMARY
#   base's `tm.h' -- literally, `-I.' in the build directory resolves `tm.h' to
#   the x86 one.  Every target macro it spells therefore carries the primary's
#   value no matter which base `-ftarget-config=' later selects.  For each
#   macro M and each configured base B this script asks one question:
#
#       does M, as seen by a middle-end TU, agree with M as seen by base B?
#
#   It does that by compiling the SAME probe source in three contexts inside
#   the real build directory:
#
#       mt        -I.                 what a middle-end TU actually sees
#       i386      -Ii386-inc  -I.     base i386's own headers
#       aarch64   -Iaarch64-inc -I.   base aarch64's own headers
#
#   PASS for (M,B) means mt agrees with B.  Today mt IS the i386 header set, so
#   every i386 arm passes and that is close to tautological -- it is the
#   positive control, and after any fix it becomes a real no-regression arm.
#   The aarch64 arms are the measurement, and they are expected to be red.
#
# WHY NOT A TEXT DIFF (this is the whole reason the script is shaped this way)
#
#   `N_REG_CLASSES' is `((int) LIM_REG_CLASSES)' on BOTH bases -- byte-identical
#   definition text -- and measures 34 on i386 and 20 on aarch64, because
#   LIM_REG_CLASSES is a back-end-generated enumerator, not a macro.  It is the
#   macro behind the aarch64.cc:14322 ICE and it appears in no text-diff list.
#   So values are probed, never definition text, wherever a value exists.
#
# THREE PROBE SHAPES, in order of strength.  Each macro gets the strongest one
# that applies, and the shape used is printed with the verdict.
#
#   INT  integer constant expression.  `char q[((V >> 8k) & 0xff) + 1]', eight
#        symbols, value read back with `nm -S'.  Exact, 64-bit, signed-safe.
#        No execution, no target assembler needed.
#
#   STR  string literal.  `char n[sizeof(S)]' for the length, then
#        `char c_k[S[k] + 1]' per byte.  Exact.  This is what catches
#        GLOBAL_ASM_OP: `\t.globl\t' vs `\t.global\t' ASSEMBLES IDENTICALLY, so
#        every check weaker than a byte comparison passes it.  This one does not.
#
#   EXP  fully preprocessed expansion.  For the 91 class-(c) macros there is no
#        value to compare: they expand to back-end CODE (`ix86_cc_mode (...)',
#        `regclass_map[...]', reads of the primary's option variables).  The
#        probe preprocesses a marked use of the macro -- supplying dummy
#        arguments for function-like ones -- and compares the resulting token
#        stream between contexts.
#
#        WHAT EXP CAN SEE: a differing callee, a differing global, a differing
#        option variable, a differing argument count, a differing constant that
#        survives to the token stream.
#
#        WHAT EXP CANNOT SEE, stated because a clean EXP result is worth much
#        less than a clean INT one:
#          * identical tokens with differing meaning -- exactly the
#            N_REG_CLASSES trap, one level down.  If an expansion bottoms out
#            in an ENUMERATOR or a variable whose definition differs per base,
#            EXP reports agreement.  INT/STR are tried first precisely so that
#            every macro that CAN be valued is valued; EXP only ever runs on
#            macros that no compiler can evaluate at translation time.
#          * behaviour.  Two identical token streams that call the same
#            function name still call whichever definition linked.
#          * whitespace and comment differences are normalised away
#            deliberately; only the token sequence is compared.
#
# WHAT NONE OF THE THREE CAN SEE, for the whole instrument:
#
#   * anything selected at RUN TIME inside cc1.  This measures the header and
#     preprocessor context a TU is compiled in.  A macro routed through
#     `targetm' is invisible here and is correctly so -- that is why the two
#     `targetm' hook initialisers are excluded rather than scored.
#   * a macro whose value is right at every use site but whose USE is wrong.
#   * the ~1049 identical-text non-integer macros that have never been
#     classified.  The probe set below is a LOWER BOUND on the population.
#     Do not read 138 as a ceiling.
#
# USAGE
#   scratchpad/macro-probe.sh [builddir]        default /tmp/b-objs
#   writes  $OUT/results.txt   one line per (base,macro), machine readable
#           $OUT/summary.txt   the counts
#   OUT defaults to /tmp/mtp-out.
#
#   gcc/testsuite/gcc.target/multi-target/macro-probe.exp turns results.txt
#   into one PASS/FAIL per macro, named by macro.

set -o pipefail

BUILD=${1:-/tmp/b-objs}
OUT=${OUT:-/tmp/mtp-out}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/.." && pwd)/gcc
MACROS=${MACROS:-$HERE/macro-probe-list.txt}

die () { echo "FATAL: $*" >&2; exit 9; }

# Tool guard.  A missing tool must never score as a clean zero: that already
# happened once on this project, `nm' was absent, "command not found" went into
# `grep -c', and both compilers scored 0 symbols -- in the direction that made
# the reference look correct.
for t in g++ nm awk sed sort comm grep; do
  command -v "$t" >/dev/null || die "missing tool: $t (are you inside the nix-shell?)"
done
[ -d "$BUILD/gcc" ] || die "no build dir $BUILD/gcc"
[ -f "$BUILD/gcc/tm.h" ] || die "no $BUILD/gcc/tm.h"
[ -s "$MACROS" ] || die "no macro list $MACROS"
mkdir -p "$OUT" || die "cannot create $OUT"

# Delete every artefact before every arm, so a stale file cannot be read as a
# fresh result.
rm -f "$OUT"/results.txt "$OUT"/summary.txt "$OUT"/val-*.txt "$OUT"/exp-*.txt \
      "$OUT"/dm-*.txt "$OUT"/err-*.txt

BASES="i386 aarch64"
CTXS="mt i386 aarch64"

ctx_inc () {                      # include flags that define the context
  case $1 in
    mt) echo "" ;;
    *)  echo "-I$1-inc" ;;
  esac
}

CPPFLAGS="-DIN_GCC -DHAVE_CONFIG_H -I. -I$SRC -I$SRC/../include \
 -I$SRC/../libcpp/include -I$SRC/../libcody -I$SRC/../libdecnumber \
 -I$SRC/../libdecnumber/bid -I../libdecnumber -I$SRC/../libbacktrace"

PRE='#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#include "hard-reg-set.h"'

########################################################################
# THE ANTI-FLOOR GATE.
#
# Converting a macro to a hook DELETES its arm here: the name vanishes from
# both bases' headers and the KIND probe scores absent/absent forever.  A
# scoreboard that punishes progress invites the obvious next move -- quietly
# editing this list -- which is the test-harness floor by a longer route.
#
# So a name may leave the header probe ONLY by being marked CONVERTED_GONE in
# macro-status.txt AND appearing in tab-probe.sh's TAB_MACROS.  Both halves are
# checked here, mechanically, before anything is probed.  Deleting a probe and
# converting a macro out from under one now fail loudly, by name.
########################################################################
STATUS=${STATUS:-$HERE/macro-status.txt}
TABSH=${TABSH:-$HERE/tab-probe.sh}
[ -s "$STATUS" ] || die "no macro status file $STATUS"
[ -s "$TABSH" ] || die "no $TABSH; a CONVERTED macro could not be covered"
TAB_COVERED=$(sed -n 's/^TAB_MACROS="\(.*\)"$/\1/p' "$TABSH")
[ -n "$TAB_COVERED" ] || die "could not read TAB_MACROS from $TABSH -- the \
coverage check would pass vacuously, which is worse than no check"

ALL=$(grep -v '^#' "$MACROS" | awk 'NF{print $1}' | sort -u)
for n in $ALL; do
  awk -v m="$n" '$1 !~ /^#/ && $1==m{f=1} END{exit !f}' "$STATUS" \
    || die "$n is probed but has no status in $STATUS"
done
RETIRED=""
# CONVERTED_CDATA -- A THIRD STATUS, AND THE REASON FOR IT IS A FALSE GREEN
# THAT WAS CAUGHT RATHER THAN BANKED.
#
# The rule above was written for arms that DISAPPEAR.  A (c-DATA) conversion
# does something the rule did not anticipate: it turns a failing arm GREEN, for
# entirely the wrong reason.  `defaults.h' redirects the macro to a per-config
# slot, so in BOTH bases' header contexts the name now expands to the same
# target-neutral text, and the EXP probe -- correctly, on its own terms --
# reports agreement.  Measured, on the first run after Stage 2:
#
#   before   aarch64 ASM_COMMENT_START STR  FAIL  mt=[23] ref=[2f2f]
#   after    aarch64 ASM_COMMENT_START EXP  PASS  mt=[(targetm_cdata.asm_...)]
#                                                 ref=[(targetm_cdata.asm_...)]
#
# Four aarch64 arms flipped FAIL -> PASS that way, taking the aarch64 column
# from 2 to 6.  Every one of those four passes says only "both headers agree
# that this macro is now a redirect" -- which is true, and is not what the arm
# was measuring.  Banking them would have been a floor built out of progress.
#
# So a (c-DATA) macro's header arm is RETIRED, exactly as a hook conversion's
# is, and its TAB arm is mandatory by the same mechanical check.  The three
# statuses now say three different things about one question -- does the header
# probe still measure this macro's VALUE? -- and the answer for CONVERTED_CDATA
# is no.
for n in $(awk '$1 !~ /^#/ && ($2=="CONVERTED_GONE" || $2=="CONVERTED_SUPPLY" || $2=="CONVERTED_CDATA") {print $1}' "$STATUS"); do
  case " $TAB_COVERED " in
    *" $n "*) ;;
    *) die "$n is marked CONVERTED in $STATUS but tab-probe.sh does not cover \
it.  A macro may only move UNCONVERTED -> CONVERTED together with its TAB arm; \
without one it would simply disappear from the score." ;;
  esac
done
for n in $(awk '$1 !~ /^#/ && ($2=="CONVERTED_GONE" || $2=="CONVERTED_CDATA") {print $1}' "$STATUS"); do RETIRED="$RETIRED $n"; done
echo "status: $(awk '$1 !~ /^#/ && $2=="UNCONVERTED"' "$STATUS" | wc -l) unconverted, \
$(awk '$1 !~ /^#/ && $2 ~ /^CONVERTED/' "$STATUS" | wc -l) converted (all covered by TAB); \
retiring from the header probe:${RETIRED:- none}"

NAMES=$(for n in $ALL; do
          case " $RETIRED " in *" $n "*) ;; *) echo "$n";; esac
        done)
NMACRO=$(echo "$NAMES" | wc -l)
[ "$NMACRO" -ge 100 ] || die "macro list has only $NMACRO entries; refusing to \
report a result from a nearly empty set"
echo "probing $NMACRO macros in $BUILD"

cd "$BUILD/gcc" || die "cd $BUILD/gcc"

########################################################################
# ARM 0 -- POSITIVE CONTROL, RUN FIRST.
#
# Probe a macro whose value is known and DIFFERS between the two bases, and one
# that is known to be identical, before probing anything unknown.  If the
# harness cannot reproduce FIRST_PSEUDO_REGISTER = 92/95 it is not measuring
# the two bases and every later number is worthless.
########################################################################
control () {
  local ctx inc v
  for ctx in $CTXS; do
    inc=$(ctx_inc $ctx)
    { echo "$PRE"
      echo "char cq[FIRST_PSEUDO_REGISTER];"
    } > "$OUT/ctl.cc"
    g++ -c -o "$OUT/ctl.o" "$OUT/ctl.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/err-ctl-$ctx.txt" 2>&1 \
      || { cat "$OUT/err-ctl-$ctx.txt"; die "control probe did not compile in $ctx"; }
    v=$(nm -S --defined-only "$OUT/ctl.o" | awk '$4=="cq"{print strtonum("0x" $2)}')
    [ -n "$v" ] || die "control: nm produced nothing for $ctx (tool present but silent)"
    echo "control $ctx FIRST_PSEUDO_REGISTER=$v"
    eval "CTL_$ctx=$v"
  done
  [ "$CTL_i386" = 92 ] || die "control: i386 FIRST_PSEUDO_REGISTER=$CTL_i386, expected 92"
  [ "$CTL_aarch64" = 95 ] || die "control: aarch64 FIRST_PSEUDO_REGISTER=$CTL_aarch64, expected 95"
  [ "$CTL_mt" = 92 ] || die "control: mt FIRST_PSEUDO_REGISTER=$CTL_mt, expected 92 (mt == primary)"
  echo "control: OK -- the three contexts are distinguishable and mt == i386"
}
control

########################################################################
# ARM 0b -- POSITIVE CONTROLS FOR THE STR AND EXP PHASES.
#
# Added 2026-08-11 after an audit.  Arm 0 controlled the INT phase only, and
# INT is the phase least likely to degrade silently.  The two weaker phases had
# NO control at all, and the gap was asymmetric in the dangerous direction:
#
#   * STR: 4 of 138 arms.  If the byte probe silently produced nothing, those
#     macros fall through to EXP or to KIND and still score FAIL, i.e. the
#     scoreboard is unchanged and the phase's death is invisible.
#   * EXP: 168 of the 276 arms -- the majority of the instrument -- and in the
#     recorded run it has ZERO passes.  A phase that never once reports
#     agreement has never demonstrated that it CAN.  If normalisation, marker
#     handling or the -dM parse degraded so that every expansion came out empty
#     or garbled, every EXP arm would still be red and the summary would look
#     exactly as it looks when the phase is healthy.  Red for the right reason
#     and red for no reason are indistinguishable without this control.
#
# So: one macro whose bytes are known and DIFFER (GLOBAL_ASM_OP, `.globl' vs
# `.global' -- the pair that assembles identically), one macro whose expansion
# is known and differs (REGNO_REG_CLASS), and one SYNTHETIC macro defined by
# this script identically in all three contexts, which EXP must report as
# AGREEING.  The synthetic one is the only evidence that a PASS is reachable.
########################################################################
CTLDEF='#define MTPCTL_AGREE(x) mtpctl_callee ((x), 42)'

str_exp_control () {
  local ctx inc agree rrc gao
  for ctx in $CTXS; do
    inc=$(ctx_inc $ctx)

    # --- STR control: GLOBAL_ASM_OP, byte exact, via the same sizeof/index
    #     shape the STR phase uses.  If this cannot be valued, STR is dead.
    { echo "$PRE"
      echo 'char ctl_len[sizeof (GLOBAL_ASM_OP)];'
      echo 'char ctl_b0[(GLOBAL_ASM_OP)[1] + 129];'
    } > "$OUT/ctlstr.cc"
    g++ -c -o "$OUT/ctlstr.o" "$OUT/ctlstr.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/err-ctlstr-$ctx.txt" 2>&1 \
      || { cat "$OUT/err-ctlstr-$ctx.txt"; die "STR control: GLOBAL_ASM_OP did not compile in $ctx -- the STR phase cannot work"; }
    gao=$(nm -S --defined-only "$OUT/ctlstr.o" | awk '$4=="ctl_len"{print strtonum("0x" $2)}')
    [ -n "$gao" ] || die "STR control: nm produced nothing for $ctx"
    echo "control-str $ctx sizeof(GLOBAL_ASM_OP)=$gao"
    eval "CTLS_$ctx=$gao"

    # --- EXP control: the synthetic agreeing macro and a known-differing one,
    #     through the SAME marker/normalise path as the real EXP phase.
    { echo "$PRE"; echo "$CTLDEF"
      echo 'MTPBEGIN 1 MTPMID MTPCTL_AGREE(zz) MTPEND'
      echo 'MTPBEGIN 2 MTPMID REGNO_REG_CLASS(zz) MTPEND'
    } > "$OUT/ctlexp.cc"
    g++ -E "$OUT/ctlexp.cc" $inc $CPPFLAGS -std=c++14 -w \
        > "$OUT/ctlexp-$ctx.i" 2> "$OUT/err-ctlexp-$ctx.txt" \
      || { cat "$OUT/err-ctlexp-$ctx.txt"; die "EXP control: preprocessing failed in $ctx"; }
    tr '\n' ' ' < "$OUT/ctlexp-$ctx.i" | sed 's/MTPBEGIN/\n/g' | grep MTPEND \
      | sed 's/MTPEND.*$//' \
      | awk -F'MTPMID' 'NF==2 { k=$1; b=$2;
            gsub(/[ \t]+/," ",k); gsub(/^ +| +$/,"",k);
            gsub(/[ \t]+/," ",b); gsub(/^ +| +$/,"",b); print k "|" b }' \
      > "$OUT/ctlexp-$ctx.txt"
    [ "$(wc -l < "$OUT/ctlexp-$ctx.txt")" = 2 ] \
      || die "EXP control: captured $(wc -l < "$OUT/ctlexp-$ctx.txt") of 2 expansions in $ctx"
    agree=$(awk -F'|' '$1==1{print $2}' "$OUT/ctlexp-$ctx.txt")
    rrc=$(awk -F'|' '$1==2{print $2}' "$OUT/ctlexp-$ctx.txt")
    # An expansion that is still the macro's own name is a non-expansion, and a
    # non-expansion compared with a non-expansion looks like agreement.
    case $agree in *MTPCTL_AGREE*) die "EXP control: MTPCTL_AGREE did not expand in $ctx";; esac
    case $rrc in *REGNO_REG_CLASS*) die "EXP control: REGNO_REG_CLASS did not expand in $ctx";; esac
    [ -n "$agree" ] || die "EXP control: empty expansion in $ctx"
    echo "control-exp $ctx agree=[$agree] rrc=[$rrc]"
    eval "CTLA_$ctx=\$agree"; eval "CTLR_$ctx=\$rrc"
  done

  # STR must be able to SEE a difference: .globl (8 chars + NUL) vs .global (9).
  [ "$CTLS_i386" = 9 ] || die "STR control: i386 sizeof(GLOBAL_ASM_OP)=$CTLS_i386, expected 9 (\\t.globl\\t)"
  [ "$CTLS_aarch64" = 10 ] || die "STR control: aarch64 sizeof(GLOBAL_ASM_OP)=$CTLS_aarch64, expected 10 (\\t.global\\t)"
  [ "$CTLS_i386" != "$CTLS_aarch64" ] || die "STR control: the two bases measured the same; STR cannot discriminate"

  # EXP must be able to report AGREEMENT (the direction never exercised by the
  # real macro set, which is 100% red under EXP) ...
  [ "$CTLA_mt" = "$CTLA_i386" ] && [ "$CTLA_mt" = "$CTLA_aarch64" ] \
    || die "EXP control: a macro defined IDENTICALLY in all three contexts was \
reported as differing (mt=[$CTLA_mt] i386=[$CTLA_i386] aarch64=[$CTLA_aarch64]). \
Every EXP FAIL in this run would be unattributable."
  # ... and to report DISAGREEMENT.
  [ "$CTLR_mt" != "$CTLR_aarch64" ] \
    || die "EXP control: REGNO_REG_CLASS is known to differ between the bases and \
EXP reported it identical; the phase cannot discriminate"
  [ "$CTLR_mt" = "$CTLR_i386" ] \
    || die "EXP control: mt and i386 disagree on REGNO_REG_CLASS, but mt IS the \
i386 header set; the contexts are not what they claim to be"
  echo "control: OK -- STR discriminates (9 vs 10 bytes); EXP reports agreement \
AND disagreement, so an EXP FAIL is a measurement and not a dead phase"
}
str_exp_control

########################################################################
# PHASE INT -- batch compile with drop-and-retry.
#
# One TU holding eight arrays per macro.  Macros that are not integral constant
# expressions make it fail; the compiler names them, they are dropped, retry.
# That converges in a handful of rounds and costs three compiles per round
# instead of 138.
########################################################################
int_phase () {
  local ctx=$1 inc round n k nbad
  inc=$(ctx_inc $ctx)
  echo "$NAMES" > "$OUT/cur-$ctx.txt"
  : > "$OUT/nonint-$ctx.txt"
  for round in 1 2 3 4 5 6 7 8 9 10; do
    { echo "$PRE"
      while read -r n; do
        for k in 0 1 2 3 4 5 6 7; do
          echo "char Q${k}_${n}[ ((( (long long)(${n}) ) >> ($k*8)) & 0xff) + 1 ];"
        done
      done < "$OUT/cur-$ctx.txt"
    } > "$OUT/int-$ctx.cc"
    if g++ -c -o "$OUT/int-$ctx.o" "$OUT/int-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-int-$ctx.txt" 2>&1; then
      nm -S --defined-only "$OUT/int-$ctx.o" \
        | awk '$4 ~ /^Q[0-7]_/ {print $4, $2}' > "$OUT/nm-int-$ctx.txt"
      [ -s "$OUT/nm-int-$ctx.txt" ] || die "INT $ctx: object compiled but nm found no probe symbols"
      awk '{ split($1,a,"_"); k=substr(a[1],2)+0;
             name=substr($1, index($1,"_")+1);
             b[name,k]=strtonum("0x" $2)-1; seen[name]=1 }
           END { for (m in seen) { v=0; for (k=7;k>=0;k--) v = v*256 + b[m,k];
                                   if (v >= 2^63) v -= 2^64;
                                   printf "%s %d\n", m, v } }' \
          "$OUT/nm-int-$ctx.txt" | sort > "$OUT/val-$ctx.txt"
      echo "INT $ctx: $(wc -l < "$OUT/val-$ctx.txt") macros valued at round $round"
      return 0
    fi
    grep -oE 'Q[0-7]_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-int-$ctx.txt" \
      | sed 's/^Q[0-7]_//' | sort -u > "$OUT/bad-$ctx.txt"
    nbad=$(wc -l < "$OUT/bad-$ctx.txt")
    if [ "$nbad" = 0 ]; then
      echo "INT $ctx: STUCK at round $round, no macro named in the errors:" >&2
      head -5 "$OUT/err-int-$ctx.txt" >&2
      die "INT $ctx: cannot converge"
    fi
    cat "$OUT/bad-$ctx.txt" >> "$OUT/nonint-$ctx.txt"
    grep -vxF -f "$OUT/bad-$ctx.txt" "$OUT/cur-$ctx.txt" > "$OUT/next-$ctx.txt"
    mv "$OUT/next-$ctx.txt" "$OUT/cur-$ctx.txt"
    [ -s "$OUT/cur-$ctx.txt" ] || { : > "$OUT/val-$ctx.txt"; return 0; }
  done
  die "INT $ctx: did not converge in 10 rounds"
}
for c in $CTXS; do int_phase $c; done

########################################################################
# PHASE STR -- string-literal macros, byte exact.
#
# Only tried on macros INT could not value.  Length first (`sizeof'), then one
# array per byte.  GLOBAL_ASM_OP and ASM_COMMENT_START are the point of this
# phase: they are emitted into the assembly file and `.globl' vs `.global'
# assembles identically.
########################################################################
str_phase () {
  local ctx=$1 inc round n k nbad len
  inc=$(ctx_inc $ctx)
  sort -u "$OUT/nonint-$ctx.txt" > "$OUT/scur-$ctx.txt"
  : > "$OUT/nonstr-$ctx.txt"
  : > "$OUT/str-$ctx.txt"
  [ -s "$OUT/scur-$ctx.txt" ] || return 0
  # round 1..n: length probe with drop-and-retry
  for round in 1 2 3 4 5 6 7 8 9 10; do
    { echo "$PRE"
      while read -r n; do echo "char L_${n}[ sizeof(${n}) ];"; done < "$OUT/scur-$ctx.txt"
    } > "$OUT/str-$ctx.cc"
    if g++ -c -o "$OUT/str-$ctx.o" "$OUT/str-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-str-$ctx.txt" 2>&1; then
      break
    fi
    grep -oE 'L_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-str-$ctx.txt" \
      | sed 's/^L_//' | sort -u > "$OUT/sbad-$ctx.txt"
    nbad=$(wc -l < "$OUT/sbad-$ctx.txt")
    if [ "$nbad" = 0 ]; then
      cp "$OUT/scur-$ctx.txt" "$OUT/nonstr-$ctx.txt"; : > "$OUT/scur-$ctx.txt"; break
    fi
    cat "$OUT/sbad-$ctx.txt" >> "$OUT/nonstr-$ctx.txt"
    grep -vxF -f "$OUT/sbad-$ctx.txt" "$OUT/scur-$ctx.txt" > "$OUT/snext-$ctx.txt"
    mv "$OUT/snext-$ctx.txt" "$OUT/scur-$ctx.txt"
    [ -s "$OUT/scur-$ctx.txt" ] || break
  done
  [ -s "$OUT/scur-$ctx.txt" ] || { sort -u "$OUT/nonstr-$ctx.txt" -o "$OUT/nonstr-$ctx.txt"; return 0; }
  # `sizeof' also succeeds for non-strings (ints already gone, but rtx/mode
  # macros can have a sizeof).  Byte probe filters them: indexing a non-array
  # will not compile, and such a macro then falls through to EXP.
  nm -S --defined-only "$OUT/str-$ctx.o" \
    | awk '$4 ~ /^L_/ {print substr($4,3), strtonum("0x" $2)}' | sort > "$OUT/len-$ctx.txt"
  for round in 1 2 3 4 5; do
    { echo "$PRE"
      while read -r n len; do
        k=0
        while [ $k -lt $((len - 1)) ]; do
          echo "char C${k}_${n}[ (${n})[$k] + 129 ];"
          k=$((k + 1))
        done
      done < "$OUT/len-$ctx.txt"
    } > "$OUT/strb-$ctx.cc"
    if g++ -c -o "$OUT/strb-$ctx.o" "$OUT/strb-$ctx.cc" $inc $CPPFLAGS \
         -std=c++14 -w -fmax-errors=0 > "$OUT/err-strb-$ctx.txt" 2>&1; then
      nm -S --defined-only "$OUT/strb-$ctx.o" \
        | awk '$4 ~ /^C[0-9]+_/ { split($4,a,"_"); k=substr(a[1],2)+0;
                                  name=substr($4, index($4,"_")+1);
                                  b[name,k]=strtonum("0x" $2)-129; seen[name]=1;
                                  if (k+1 > n[name]) n[name]=k+1 }
               END { for (m in seen) { s="";
                       for (k=0;k<n[m];k++) s = s sprintf("%02x", b[m,k]+0);
                       printf "%s %s\n", m, s } }' | sort > "$OUT/str-$ctx.txt"
      echo "STR $ctx: $(wc -l < "$OUT/str-$ctx.txt") macros valued as strings"
      break
    fi
    grep -oE 'C[0-9]+_[A-Za-z_][A-Za-z0-9_]*' "$OUT/err-strb-$ctx.txt" \
      | sed -E 's/^C[0-9]+_//' | sort -u > "$OUT/sbbad-$ctx.txt"
    nbad=$(wc -l < "$OUT/sbbad-$ctx.txt")
    [ "$nbad" = 0 ] && { cat "$OUT/len-$ctx.txt" | awk '{print $1}' >> "$OUT/nonstr-$ctx.txt"; : > "$OUT/len-$ctx.txt"; break; }
    cat "$OUT/sbbad-$ctx.txt" >> "$OUT/nonstr-$ctx.txt"
    grep -vwF -f "$OUT/sbbad-$ctx.txt" "$OUT/len-$ctx.txt" > "$OUT/lnext-$ctx.txt"
    mv "$OUT/lnext-$ctx.txt" "$OUT/len-$ctx.txt"
    [ -s "$OUT/len-$ctx.txt" ] || break
  done
  sort -u "$OUT/nonstr-$ctx.txt" -o "$OUT/nonstr-$ctx.txt"
}
for c in $CTXS; do str_phase $c; done

########################################################################
# PHASE EXP -- fully preprocessed expansion, for macros no compiler can value.
#
# Arity comes from the context's own `-dM' dump, so a macro that is object-like
# on one base and function-like on the other is reported as an ARITY
# disagreement rather than silently mis-probed.
########################################################################
exp_phase () {
  local ctx=$1 inc n
  inc=$(ctx_inc $ctx)
  echo "$PRE" > "$OUT/dm-$ctx.cc"
  g++ -E -dM "$OUT/dm-$ctx.cc" $inc $CPPFLAGS -std=c++14 -w \
      > "$OUT/dm-$ctx.txt" 2> "$OUT/err-dm-$ctx.txt" \
    || { cat "$OUT/err-dm-$ctx.txt"; die "EXP $ctx: -dM dump failed"; }
  [ "$(wc -l < "$OUT/dm-$ctx.txt")" -gt 5000 ] \
    || die "EXP $ctx: -dM dump has only $(wc -l < "$OUT/dm-$ctx.txt") lines; not a real dump"

  # arity: -1 undefined, 0 object-like, k>0 function-like with k parameters
  awk -v list="$OUT/allnames.txt" '
    BEGIN { while ((getline m < list) > 0) want[m]=1; }
    /^#define / {
      rest = substr($0, 9);
      if (match(rest, /^[A-Za-z_][A-Za-z0-9_]*\(/)) {
        name = substr(rest, 1, RLENGTH-1);
        if (!(name in want)) next;
        p = substr(rest, RLENGTH+1); cl = index(p, ")");
        args = substr(p, 1, cl-1);
        gsub(/[ \t]/, "", args);
        k = (args == "") ? 0 : split(args, tmp, ",");
        printf "%s %d F\n", name, k;
      } else {
        name = rest; sub(/[ \t].*$/, "", name);
        if (!(name in want)) next;
        printf "%s 0 O\n", name;
      }
    }' "$OUT/dm-$ctx.txt" | sort -u > "$OUT/arity-$ctx.txt"
  # An awk that fails still exits 0 through a pipe.  An empty arity table would
  # silently turn every EXP probe into "no data", which scores as a divergence
  # -- red for the wrong reason.  Refuse instead.
  [ -s "$OUT/arity-$ctx.txt" ] \
    || die "EXP $ctx: arity table is empty; the dump parse failed, no probe can be built"

  # The probe is keyed by a NUMBER, not by the macro's name.  Writing the name
  # into the marker line would be self-defeating: the preprocessor expands it,
  # and the key becomes the expansion.  That bug reads as "every macro
  # disagrees" and it was actually hit here before this comment existed.
  local idx=0
  { echo "$PRE"
    while read -r n; do
      local a kind args k
      idx=$((idx + 1))
      a=$(awk -v m="$n" '$1==m{print $2}' "$OUT/arity-$ctx.txt")
      kind=$(awk -v m="$n" '$1==m{print $3}' "$OUT/arity-$ctx.txt")
      [ -n "$a" ] || continue
      # A ZERO-PARAMETER function-like macro (SETUP_FRAME_ADDRESSES() is one)
      # still needs the parentheses: written bare it does not expand at all,
      # both contexts then yield the macro's own name, and the probe reports
      # agreement.  That is a false green and it was observed here.
      if [ "$kind" = F ]; then
        args=""; k=0
        while [ $k -lt "$a" ]; do
          [ -n "$args" ] && args="$args,"
          args="${args}mtpA$k"; k=$((k + 1))
        done
        echo "MTPBEGIN $idx MTPMID ${n}($args) MTPEND"
      else
        echo "MTPBEGIN $idx MTPMID $n MTPEND"
      fi
    done < "$OUT/expcur-$ctx.txt"
  } > "$OUT/exp-$ctx.cc"
  local want got
  want=$(wc -l < "$OUT/expcur-$ctx.txt")
  got=$(grep -c MTPBEGIN "$OUT/exp-$ctx.cc")
  [ "$got" = "$want" ] \
    || die "EXP $ctx: built $got probe uses for $want macros; a macro the phase \
was asked about has no probe, and a missing probe must not read as agreement"

  g++ -E "$OUT/exp-$ctx.cc" $inc $CPPFLAGS -std=c++14 -w \
      > "$OUT/exp-$ctx.i" 2> "$OUT/err-exp-$ctx.txt" \
    || { cat "$OUT/err-exp-$ctx.txt"; die "EXP $ctx: preprocessing failed"; }

  # One expansion per line; normalise whitespace so only the token sequence
  # is compared.  MTPBEGIN/MTPMID/MTPEND are not macros, so they survive.
  tr '\n' ' ' < "$OUT/exp-$ctx.i" \
    | sed 's/MTPBEGIN/\n/g' | grep MTPEND \
    | sed 's/MTPEND.*$//' \
    | awk -F'MTPMID' -v list="$OUT/expcur-$ctx.txt" '
        BEGIN { i=0; while ((getline m < list) > 0) name[++i]=m }
        NF==2 { key=$1; body=$2;
        gsub(/[ \t]+/, " ", key); gsub(/^ +| +$/, "", key);
        gsub(/[ \t]+/, " ", body); gsub(/^ +| +$/, "", body);
        if (key !~ /^[0-9]+$/) { print "BADKEY " key > "/dev/stderr"; bad=1; next }
        print name[key+0], body }
        END { if (bad) exit 3 }' | sort > "$OUT/exp-$ctx.txt" \
    || die "EXP $ctx: a probe key was not a plain integer -- the marker was macro-expanded"
  echo "EXP $ctx: $(wc -l < "$OUT/exp-$ctx.txt") expansions captured of $want asked"
  [ "$(wc -l < "$OUT/exp-$ctx.txt")" = "$want" ] \
    || die "EXP $ctx: captured $(wc -l < "$OUT/exp-$ctx.txt") of $want expansions"
}
echo "$NAMES" > "$OUT/allnames.txt"
for c in $CTXS; do
  # EXP gets exactly what INT and STR could not value.  Deriving that by
  # SUBTRACTING what was valued -- rather than by trusting the phases'
  # bookkeeping of what they rejected -- is deliberate: the rejection lists are
  # built from compiler diagnostics, and a diagnostic that does not name the
  # probe variable silently drops a macro out of every table, which then scores
  # as "absent on both sides" and reads like a divergence.  That happened.
  comm -23 <(sort -u "$OUT/nonint-$c.txt") <(awk '{print $1}' "$OUT/str-$c.txt" | sort -u) \
    > "$OUT/expcur-$c.txt"
  exp_phase $c
done

########################################################################
# SCORING
########################################################################
lookup () { awk -v m="$2" '$1==m { $1=""; sub(/^ /,""); print; found=1 }
                           END { if (!found) print "<absent>" }' "$1"; }

: > "$OUT/results.txt"
for b in $BASES; do
  while read -r n; do
    kind=""; mtv=""; refv=""
    if grep -q "^$n " "$OUT/val-mt.txt" && grep -q "^$n " "$OUT/val-$b.txt"; then
      kind=INT; mtv=$(lookup "$OUT/val-mt.txt" "$n"); refv=$(lookup "$OUT/val-$b.txt" "$n")
    elif grep -q "^$n " "$OUT/str-mt.txt" && grep -q "^$n " "$OUT/str-$b.txt"; then
      kind=STR; mtv=$(lookup "$OUT/str-mt.txt" "$n"); refv=$(lookup "$OUT/str-$b.txt" "$n")
    elif grep -q "^$n " "$OUT/exp-mt.txt" && grep -q "^$n " "$OUT/exp-$b.txt"; then
      kind=EXP; mtv=$(lookup "$OUT/exp-mt.txt" "$n"); refv=$(lookup "$OUT/exp-$b.txt" "$n")
    else
      # The two contexts did not even agree on what KIND of thing this is:
      # an integer here, a non-constant there.  That is a real divergence and
      # it is reported as one, never quietly skipped.
      kind=KIND
      mtv=$(grep -q "^$n " "$OUT/val-mt.txt" && echo int \
            || { grep -q "^$n " "$OUT/str-mt.txt" && echo string \
                 || { grep -q "^$n " "$OUT/exp-mt.txt" && echo nonconst || echo absent; }; })
      refv=$(grep -q "^$n " "$OUT/val-$b.txt" && echo int \
            || { grep -q "^$n " "$OUT/str-$b.txt" && echo string \
                 || { grep -q "^$n " "$OUT/exp-$b.txt" && echo nonconst || echo absent; }; })
    fi
    # An EXP result that is just the macro's own name means the macro did not
    # expand -- it is not evidence of agreement, it is evidence of no probe.
    if [ "$kind" = EXP ] && { [ "$mtv" = "$n" ] || [ "$refv" = "$n" ]; }; then
      kind=NOEXPAND
    fi
    if [ "$kind" = KIND ] || [ "$kind" = NOEXPAND ]; then v=FAIL
    elif [ "$mtv" = "$refv" ]; then v=PASS; else v=FAIL; fi
    echo "$b $n $kind $v mt=[$mtv] ref=[$refv]" >> "$OUT/results.txt"
  done <<< "$NAMES"
done

[ "$(wc -l < "$OUT/results.txt")" = "$((NMACRO * 2))" ] \
  || die "scoring produced $(wc -l < "$OUT/results.txt") lines, expected $((NMACRO * 2))"

{
  echo "macros probed: $NMACRO   bases: $BASES"
  for b in $BASES; do
    echo "$b: PASS $(awk -v b=$b '$1==b && $4=="PASS"' "$OUT/results.txt" | wc -l)  \
FAIL $(awk -v b=$b '$1==b && $4=="FAIL"' "$OUT/results.txt" | wc -l)"
  done
  echo "by probe shape:"
  awk '{print $3}' "$OUT/results.txt" | sort | uniq -c
  echo "aarch64 failures by shape:"
  awk '$1=="aarch64" && $4=="FAIL" {print $3}' "$OUT/results.txt" | sort | uniq -c
  echo "PASS for aarch64 (expected to be rare -- each needs a reason):"
  awk '$1=="aarch64" && $4=="PASS" {print "  " $2 " " $3}' "$OUT/results.txt"
  echo "FAIL for i386 (expected NONE -- mt is the i386 header set today):"
  awk '$1=="i386" && $4=="FAIL" {print "  " $2 " " $3}' "$OUT/results.txt"
} > "$OUT/summary.txt"
cat "$OUT/summary.txt"
echo "results: $OUT/results.txt"
