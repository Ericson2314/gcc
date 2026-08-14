#!/bin/sh
# #163 -- did the 55 `MD-COND' sites become RUN-TIME tests, or did they get
# folded away at build time?
#
# THIS IS THE ARM WHERE THE TWO FAILURE MODES LOOK ALIKE.  `HAVE_AS_TLS' is no
# longer defined by auto-host.h, so in a generator it comes from the
# `#if defined (GENERATOR_FILE)' block each back end now carries.  If that
# block gave 0 -- which is what the seven DEAD floors it replaced literally
# said -- gencondmd would evaluate `HAVE_AS_TLS && TARGET_ELF' to a constant
# false and DELETE every TLS insn.  The compiler would still build, still link
# and still compile every non-TLS program; the loss is invisible except here.
#
# So three arms, and the first two are about the artefact rather than the
# build:
#   1  the .md conditions survived into insn-conditions-<key>.md and are still
#      NON-CONSTANT (gencondmd writes -1 for "decide at run time")
#   2  the generated insn-*.cc that consume them reach targ_caps.as_tls
#   3  the count of surviving TLS conditions, per back end, printed -- so a
#      partial loss is visible rather than averaged away
#
# usage: tb1-mdcond.sh <builddir>
set -u
D=${1:?build dir}
case "$D" in
  */b-agent-aab545de8b02de843*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -f "$D/make-top.rc" ] || { echo "FATAL: $D/make-top.rc absent -- unstamped log"; exit 9; }
G="$D/gcc"

# ---- arm 0: NON-VACUITY ------------------------------------------------
n=$(ls "$G"/insn-conditions-*.md 2>/dev/null | wc -l)
[ "$n" -ge 2 ] || { echo "FATAL: only $n insn-conditions-*.md; nothing to score"; exit 9; }
echo "arm 0  $n insn-conditions-*.md present"

# auto-host.h must NOT define it any more -- if it does, every reading below
# is of the old build-time constant and means nothing.
if grep -q 'define HAVE_AS_TLS' "$G/auto-host.h"; then
  echo "FATAL: auto-host.h still defines HAVE_AS_TLS; this tree is pre-#163"
  exit 9
fi
echo "arm 0  auto-host.h does not define HAVE_AS_TLS"
echo

# ---- arm 1: the conditions survived, per back end ----------------------
#
# THIS ARM IS A PRESERVATION CHECK, NOT A BEFORE/AFTER DISCRIMINATOR, AND
# SAYING SO IS THE POINT.  gencondmd writes back the condition's SOURCE TEXT,
# not its expansion, so these files read the same before and after -- what
# would change is the LEADING NUMBER: `-1' means "not a compile-time constant,
# decide at run time", and a folded-away condition would read `0' and the
# pattern would be gone.  So a green here says the 55 sites survived the
# generator; arm 3 is what says they became a per-target read.
#
# `TARGET_TLS' is counted beside `HAVE_AS_TLS' because sparc's 37 .md sites
# spell the macro it is defined from.  Counting only the literal name would
# score sparc as having no TLS conditions at all -- a zero from a
# name-matching instrument (PRINCIPLES section 4).
echo "arm 1  TLS insn conditions surviving into insn-conditions-<key>.md:"
tot=0
nonconst=0
for f in "$G"/insn-conditions-*.md; do
  k=$(basename "$f" .md); k=${k#insn-conditions-}
  c=$(grep -cE 'HAVE_AS_TLS|TARGET_TLS' "$f" || true)
  [ "$c" = 0 ] && continue
  nc=$(grep -E 'HAVE_AS_TLS|TARGET_TLS' "$f" | grep -c '^ *(-1 ' || true)
  nonconst=$((nonconst + nc))
  printf '    %-34s %s conditions, %s non-constant\n' "$k" "$c" "$nc"
  tot=$((tot + c))
done
echo "    total $tot conditions, $nonconst non-constant"
[ "$tot" -gt 0 ] || { echo "FATAL: ZERO TLS conditions survived -- they were folded out at build time"; exit 9; }

# THE REFUSAL THAT USED TO BE HERE WAS `nonconst == tot', AND IT WAS THE WRONG
# TEST.  IT IS RECORDED RATHER THAN SWAPPED OUT, so the next reader can see why
# the obvious check does not work.
#
# It fired on this tree, reporting "10 conditions were folded to a constant" --
# and every one of the ten is correct:
#
#   6  (0 "TARGET_XCOFF && HAVE_AS_TLS")  and its 32/64-bit variants
#          folded by TARGET_XCOFF, a compile-time 0 in a powerpc64-linux tm.h.
#          Nothing to do with TLS, and it folded the same way before.
#   4  (1 "HAVE_AS_TLS")   alpha and frv, per back end and per triple
#          a BARE condition is a constant expression to gencondmd whatever
#          supplies the 1, so it folds to 1 -- pattern KEPT, merely decided at
#          build time.  Same as when auto-host.h supplied it.
#
# `0' and `1' mean opposite things -- deleted versus kept -- and counting them
# together scores a correct tree as a failure.  Worse, the obvious repair
# (lower the threshold to 92) is a test-harness floor: it expires the moment a
# back end gains or loses a pattern.
#
# ARM 1b IS THE EXACT TEST, and it is a strengthening rather than a relaxation:
# it asks the ROOT property directly.  If `HAVE_AS_TLS' is 1 inside gencondmd's
# own translation unit, then no condition anywhere can be folded to 0 BECAUSE
# OF IT, and every generator sees precisely what auto-host.h used to give.  If
# a back end's `#if defined (GENERATOR_FILE)' block were missing, misplaced or
# written 0, this fails by name -- which the count could not do.
echo
echo "arm 1b  HAVE_AS_TLS inside each gencondmd translation unit (must be 1):"
S=$(cd "$(dirname "$0")" && pwd)
LOG="$D/tb1-joined.log"
awk "{ gsub(/\t/, \" \"); if (buf != \"\") \$0 = buf \" \" \$0; if (sub(/\\\\$/, \"\")) { buf = \$0; next } buf = \"\"; print }" \
  "$D/make-top.out" > "$LOG"
bad=0; seen=0
for key in alpha_unknown_linux_gnu frv_unknown_elf mips64_unknown_elf \
           powerpc64_unknown_linux_gnu sparc64_unknown_linux_gnu \
           xtensa_unknown_elf; do
  o="build/gencondmd-$key.o"
  [ -f "$D/gcc/$o" ] || { printf '    %-32s NOT BUILT\n' "$key"; bad=$((bad+1)); continue; }
  cmd=$(grep -F -- " -o $o " "$LOG" | tail -1)
  [ -n "$cmd" ] || { printf '    %-32s no compile command\n' "$key"; bad=$((bad+1)); continue; }
  pp=$(printf '%s\n' "$cmd" | sed -e 's/ -c / /' -e 's/ -o [^ ]*//' \
         -e 's/ -MT [^ ]*//' -e 's/ -MF [^ ]*//' -e 's/ -MMD//' -e 's/ -MP//')
  { echo "cd $D/gcc"; printf '%s -E -dM\n' "$pp"; } > "$D/tb1-gc-pp.sh"
  out=$(sh "$S/eb-shell.sh" "sh $D/tb1-gc-pp.sh" 2>/dev/null || true)
  nmac=$(printf '%s\n' "$out" | grep -c '^#define ' || true)
  [ "$nmac" -ge 200 ] || { printf '    %-32s only %s macros -- did not preprocess\n' "$key" "$nmac"; bad=$((bad+1)); continue; }
  v=$(printf '%s\n' "$out" | awk '$1=="#define" && $2=="HAVE_AS_TLS" {print $3; f=1} END{if(!f) print "<ABSENT>"}')
  printf '    %-32s %s\n' "$key" "$v"
  seen=$((seen+1))
  [ "$v" = 1 ] || bad=$((bad+1))
done
[ "$seen" -ge 5 ] || { echo "FATAL: arm 1b read only $seen back ends"; exit 9; }
[ "$bad" = 0 ] || { echo "FATAL: $bad back ends do not give gencondmd HAVE_AS_TLS 1"; exit 9; }
echo "    all $seen give 1 -- what auto-host.h used to give; no condition can fold to 0 through it"

echo
# ---- arm 2: the text reached the C++ translation units -----------------
#
# GREP FOR `HAVE_AS_TLS', NOT FOR `targ_caps.as_tls'.  genrecog copies the
# condition STRING out of the .md; the macro is expanded by the C++
# preprocessor afterwards, so the generated source still spells the old name
# and a search for the new one reads zero -- which would look exactly like
# "the capability never reached the insn code".  Arm 3 is what reads the
# expansion.
echo "arm 2  generated per-base sources still carrying the condition text:"
hit=0
for f in "$G"/mt-*/insn-recog-*.cc "$G"/mt-*/insn-emit-*.cc; do
  [ -f "$f" ] || continue
  c=$(grep -c 'HAVE_AS_TLS' "$f" || true)
  [ "$c" = 0 ] && continue
  hit=$((hit + 1))
  printf '    %-56s %s\n' "$(basename "$(dirname "$f")")/$(basename "$f")" "$c"
done
echo "    $hit generated sources"
[ "$hit" -gt 0 ] || { echo "FATAL: no generated source carries the condition"; exit 9; }

echo
# ---- arm 3: what the macro expands to IN one of those TUs --------------
# Read off the object's own recipe with -E -dM, so ABSENT and 0 are
# distinguishable (PRINCIPLES section 4).
S=$(cd "$(dirname "$0")" && pwd)
LOG="$D/tb1-joined.log"
awk "{ gsub(/\t/, \" \"); if (buf != \"\") \$0 = buf \" \" \$0; if (sub(/\\\\$/, \"\")) { buf = \$0; next } buf = \"\"; print }" \
  "$D/make-top.out" > "$LOG"
obj=$(ls "$G"/insn-recog-rs6000-*.o 2>/dev/null | head -1)
[ -n "$obj" ] || obj=$(ls "$G"/insn-output-rs6000.o 2>/dev/null | head -1)
[ -n "$obj" ] || { echo "SKIP arm 3: no rs6000 insn object in this build"; exit 0; }
obj=$(basename "$obj")
cmd=$(grep -F -- " -o $obj " "$LOG" | tail -1)
[ -n "$cmd" ] || { echo "FATAL: no compile command for $obj"; exit 9; }
pp=$(printf '%s\n' "$cmd" | sed -e 's/ -c / /' -e 's/ -o [^ ]*//' \
       -e 's/ -MT [^ ]*//' -e 's/ -MF [^ ]*//' -e 's/ -MMD//' -e 's/ -MP//')
{ echo "cd $G"; printf '%s -E -dM\n' "$pp"; } > "$D/tb1-md-pp.sh"
out=$(sh "$S/eb-shell.sh" "sh $D/tb1-md-pp.sh" 2>/dev/null || true)
nm=$(printf '%s\n' "$out" | grep -c '^#define ' || true)
[ "$nm" -ge 500 ] || { echo "FATAL: arm 3 recovered $nm macros; it did not preprocess"; exit 9; }
v=$(printf '%s\n' "$out" | awk '$1=="#define" && $2=="HAVE_AS_TLS" {$1="";$2="";print substr($0,3); f=1} END{if(!f) print "<ABSENT>"}')
echo "arm 3  $obj ($nm macros):  HAVE_AS_TLS = $v"
case "$v" in
  *targ_caps.as_tls*) echo "       -> a RUN-TIME read; the insn conditions are decided per target" ;;
  *) echo "FATAL: HAVE_AS_TLS is [$v] in the compiler proper, not the capability"; exit 9 ;;
esac
