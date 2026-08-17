#!/usr/bin/env bash
#
# TAB -- THE FOURTH PROBE SHAPE, for macros that have been CONVERTED to a hook.
#
# WHY IT HAS TO EXIST AT ALL
#
#   macro-probe.sh measures the header and preprocessor context a middle-end TU
#   is compiled in.  That is the right question for an UNCONVERTED macro and it
#   is structurally blind to runtime `targetm' dispatch -- which is exactly what
#   a converted macro becomes.  Left alone, converting a macro DELETES its arm:
#   the name vanishes from both bases' headers, the KIND probe scores
#   absent/absent, and that arm fails forever.  A scoreboard that punishes
#   progress invites the obvious next move -- editing the probe list -- which is
#   the test-harness floor by a longer route.  So:
#
#     A macro may move UNCONVERTED -> CONVERTED only TOGETHER WITH its TAB arm.
#     A macro that vanishes from the headers with no TAB arm scores FAIL, not
#     "absent".  scratchpad/macro-status.txt carries the status; macro-probe.sh
#     refuses to skip a CONVERTED name unless this script covers it.
#
# WHAT IT MEASURES, AND HOW IT DIFFERS FROM THE DESIGN AS WRITTEN
#
#   CLASS-C-DESIGN.md 5 proposed resolving each base's hook slot STATICALLY,
#   from the relocations in the linked cc1.  Two problems, both found by
#   building it:
#
#     * a POD slot (GLOBAL_ASM_OP is a string, not a function) has no callee to
#       resolve, and the design already noted it would need a runtime dump;
#     * cc1 here is a non-PIE EXEC, so the pointers are plain stored words --
#       but reading them out of the file image is archaeology over a link, and
#       it silently answers nothing if the layout assumption is wrong.
#
#   This reads the slot INSTEAD OF reconstructing it: a plugin loaded into the
#   real linked cc1 binds to `targetm_<base>' by name (cc1 is linked -rdynamic;
#   verified below, not assumed) and prints the pointer the slot actually
#   holds.  Turning that pointer into a symbol NAME is done outside, with `nm'
#   over the same binary, so nothing depends on dladdr being able to see static
#   symbols -- it cannot.
#
#   Three criteria per (base, macro), all three required:
#
#     1. COMPLETENESS.  The macro is not spelled by target-independent code
#        outside the small glue allowlist.  Present elsewhere = not converted,
#        and that is the arm that stops a half-done conversion reading as done.
#     2. DISPATCH.  Base B's slot resolves to a symbol that belongs to B.
#        For a string slot, to B's own bytes -- checked against what the header
#        probe measured for B, not against this script's own expectation.
#     3. DISCRIMINATION.  Without this, (2) proves nothing.  A slot known to be
#        SHARED must come out equal for the two bases, and a slot known to
#        DIFFER must come out different AND attributed to each base.  An
#        instrument that has only ever reported one of the two answers has not
#        been shown to be able to report the other -- the EXP lesson.
#
# USAGE
#   scratchpad/tab-probe-run.sh [builddir]     default /tmp/b-objs
#   OUT defaults to /tmp/tab-out, MTP to /tmp/mtp-before (a macro-probe.sh run,
#   used as the independent source of truth for the string slots).

set -o pipefail

BUILD=${1:-/tmp/b-objs}
OUT=${OUT:-/tmp/tab-out}
MTP=${MTP:-/tmp/mtp-before}
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/.." && pwd)/gcc

die () { echo "FATAL: $*" >&2; exit 9; }

for t in g++ nm objdump grep awk sed sort; do
  command -v "$t" >/dev/null || die "missing tool: $t (are you inside the nix-shell?)"
done
[ -d "$BUILD/gcc" ] || die "no build dir $BUILD/gcc"
[ -x "$BUILD/gcc/cc1" ] || die "no cc1 at $BUILD/gcc/cc1"
[ -f "$HERE/tab-plugin.cc" ] || die "no $HERE/tab-plugin.cc"
mkdir -p "$OUT" || die "cannot create $OUT"
rm -f "$OUT"/slots.txt "$OUT"/nm.txt "$OUT"/results.txt "$OUT"/summary.txt

BASES="i386 aarch64"
# The macros this script covers.  macro-probe.sh cross-checks this list, so a
# name cannot be dropped from the header probe without appearing here.
# ONE LINE, deliberately, however long it gets.  macro-probe.sh's anti-floor
# check reads this line with `sed -n 's/^TAB_MACROS="\(.*\)"$/\1/p'', and a
# backslash continuation makes that read return nothing.  It fails loudly when
# it does -- it did, on the first run after Stage 1 was added, which is the
# check working -- but the failure names the parse, not the cause, so: keep it
# on one line rather than teaching the reader about continuations.  A more
# forgiving reader is a reader with more ways to return the empty set.
TAB_MACROS="LIBCALL_VALUE ASM_OUTPUT_EXTERNAL GLOBAL_ASM_OP BASE_REG_CLASS INDEX_REG_CLASS REGNO_OK_FOR_BASE_P REGNO_OK_FOR_INDEX_P ASM_COMMENT_START WCHAR_TYPE SIZE_TYPE PTRDIFF_TYPE BYTES_BIG_ENDIAN WORDS_BIG_ENDIAN FLOAT_WORDS_BIG_ENDIAN REG_WORDS_BIG_ENDIAN STRICT_ALIGNMENT SHIFT_COUNT_TRUNCATED JUMP_TABLES_IN_TEXT_SECTION BITS_PER_WORD LONG_TYPE_SIZE PARM_BOUNDARY ATTRIBUTE_ALIGNED_VALUE MALLOC_ABI_ALIGNMENT TRAMPOLINE_SIZE DWARF_CIE_DATA_ALIGNMENT STACK_CHECK_FIXED_FRAME_SIZE STACK_CHECK_MAX_FRAME_SIZE MAX_FIXED_MODE_SIZE DWARF_FRAME_RETURN_COLUMN FIRST_PSEUDO_REGISTER N_REG_CLASSES REGNO_REG_CLASS"

# How many slot lines the plugin writes per base.  Named rather than spelled as
# a literal, because getting it wrong in the direction of TOO FEW is a silent
# pass: the length assertion below would accept a dump missing the very arms
# this run was added to score.
SLOTS_PER_BASE=37

# Which symbol names count as belonging to which base.
own_i386='^(ix86_|i386_|x86_)'
own_aarch64='^(aarch64_|arm_)'

########################################################################
# 0.  The binding this whole instrument rests on.  If targetm_<base> is not
#     dynamically visible the plugin cannot bind to it, and the failure would
#     arrive as a link error whose cause is three steps away.
########################################################################
# Never pipe nm into `grep -q': grep -q exits on the first hit, nm dies of
# SIGPIPE, and with `set -o pipefail' the SUCCESSFUL case reports failure.
# That cost a debugging round here.  Nor `2>/dev/null': a tool that failed for
# an unrelated reason must not be read as "symbol absent".
nm -D --defined-only "$BUILD/gcc/cc1" > "$OUT/dynsyms.txt" 2> "$OUT/nm-D.err" \
  || { cat "$OUT/nm-D.err"; die "nm -D failed on cc1"; }
[ -s "$OUT/nm-D.err" ] && { cat "$OUT/nm-D.err"; die "nm -D wrote to stderr"; }
[ "$(wc -l < "$OUT/dynsyms.txt")" -gt 1000 ] \
  || die "cc1 has only $(wc -l < "$OUT/dynsyms.txt") dynamic symbols; not a \
real -rdynamic link, and an absent symbol below would be uninformative"
for b in $BASES; do
  grep -q " targetm_$b\$" "$OUT/dynsyms.txt" \
    || die "targetm_$b is not in cc1's dynamic symbol table; cc1 is not linked \
-rdynamic, so no plugin can read the per-base tables and TAB cannot run"
done
echo "ok: targetm_i386 and targetm_aarch64 are dynamically bindable"

########################################################################
# 1.  COMPLETENESS -- is the macro really out of target-independent code?
########################################################################
# The glue that is ALLOWED to spell a converted macro: the per-back-end
# wrappers that SUPPLY the hook, and documentation.  Everything else in
# gcc/*.cc and gcc/*.h is target-independent code and must not spell it.
GLUE='^(target-addr\.h|target-addr\.cc|target-cdata\.h|target-cdata\.cc|target-def\.h|target-asm-ops\.h|target-asm-ops\.cc|targhooks\.cc|targhooks\.h|defaults\.h)$'

# THE (c-DATA) MACROS NEED A DIFFERENT COMPLETENESS CRITERION, AND SAYING SO IS
# NOT A WEAKENING.
#
# For a macro converted to a HOOK, "target-independent code must not spell it"
# is the right question: the name is supposed to disappear.  For a (c-DATA)
# macro it is the WRONG question and would be red forever, because the whole
# design is that the NAME SURVIVES and its EXPANSION changes -- `UNITS_PER_WORD'
# stays spelled at 1494 sites and becomes a load from a per-config slot.  1494
# permanent FAILs is a scoreboard that has stopped measuring, which is the
# floor by another route.
#
# So for these the completeness question becomes: IS THE REDIRECT ACTUALLY IN
# defaults.h?  That is the thing that can silently regress -- delete the
# `#undef'/`#define' pair and every use goes straight back to the primary's
# tm.h with no diagnostic anywhere.  It carries its own control below.
CDATA_MACROS="ASM_COMMENT_START WCHAR_TYPE SIZE_TYPE PTRDIFF_TYPE"

is_cdata () { case " $CDATA_MACROS " in *" $1 "*) return 0;; esac; return 1; }

# The NUMERIC (c-DATA) macros, and the value each base must produce.
#
# THESE ARE NOT READ BACK OUT OF THE MECHANISM.  They are a hand derivation
# from i386.h and aarch64.h, written down in scratchpad/PREREGISTER-cdata-num.md
# BEFORE the plugin was taught to dump these slots and before any of them had
# been observed -- because unlike the four string macros there is no outside
# oracle for them.  The header probe cannot see them (they are class (c)
# exactly because they are not constant expressions in their own base's header
# context), and upstream cc1 does not expose PARM_BOUNDARY the way it exposes
# __SIZE_TYPE__.
#
# If a verdict below disagrees with this table, the fix is to re-read the back
# end's header, NOT to edit this line.  Editing it to match the measurement
# would convert eighteen independent checks into eighteen restatements of what
# the mechanism already said.
#
# Format: <macro>:<i386 value>:<aarch64 value>
CDATA_NUM="\
BYTES_BIG_ENDIAN:0:0 \
WORDS_BIG_ENDIAN:0:0 \
FLOAT_WORDS_BIG_ENDIAN:0:0 \
REG_WORDS_BIG_ENDIAN:0:0 \
STRICT_ALIGNMENT:0:0 \
SHIFT_COUNT_TRUNCATED:0:0 \
JUMP_TABLES_IN_TEXT_SECTION:0:0 \
BITS_PER_WORD:64:64 \
LONG_TYPE_SIZE:64:64 \
PARM_BOUNDARY:64:64 \
ATTRIBUTE_ALIGNED_VALUE:128:128 \
MALLOC_ABI_ALIGNMENT:64:128 \
TRAMPOLINE_SIZE:28:40 \
DWARF_CIE_DATA_ALIGNMENT:-8:-8 \
STACK_CHECK_FIXED_FRAME_SIZE:32:32 \
STACK_CHECK_MAX_FRAME_SIZE:4088:4088 \
MAX_FIXED_MODE_SIZE:128:128 \
DWARF_FRAME_RETURN_COLUMN:16:30"

# The three whose two bases must DISAGREE.  Fifteen of the eighteen agree
# between i386 and aarch64 in this configuration, and an agreeing slot is
# equally consistent with a working mechanism and with one pinned to the
# primary -- which is precisely how `targetm_asm_ops' stayed green while
# choosing nothing.  These three are the only lines that can tell those two
# worlds apart, so they are asserted separately and by name, before the
# per-macro verdicts are issued.
CDATA_NUM_DISCRIM="MALLOC_ABI_ALIGNMENT TRAMPOLINE_SIZE DWARF_FRAME_RETURN_COLUMN"

# Macros whose value is a read of the BASE'S OWN OPTION VARIABLES rather than
# arithmetic on literals: aarch64's `BYTES_BIG_ENDIAN' is `(TARGET_BIG_END !=
# 0)' and its `SHIFT_COUNT_TRUNCATED' is `(!TARGET_SIMD)'.
#
# THE PLUGIN CANNOT MEASURE THESE FOR THE UNSELECTED BASE, and this is not a
# defect that a category should be invented to hide.  It calls both bases'
# refresh functions inside ONE cc1 run so that both columns come out of one
# measurement; only the selected base has been through its own
# `target_option_override', so the other base's option variables hold the
# selected base's bits.  Measured here: aarch64's four endianness slots come
# back 1 and `SHIFT_COUNT_TRUNCATED' comes back 1, under an i386 selection,
# because aarch64's flag words are being read out of storage i386 filled.
#
# So these arms stay FAIL.  They are genuinely unverified, and a FAIL is the
# correct verdict for unverified -- the alternative, a third status that
# excuses them, is the test-harness floor with a plausible name.  The real fix
# is a second plugin run under `-ftarget-config=<aarch64>', which is blocked
# today because aarch64 cc1 ICEs before any plugin callback fires (STATE.md).
# The FAIL message says so, so that nobody spends a second afternoon on it.
CDATA_NUM_OPTSTATE="BYTES_BIG_ENDIAN WORDS_BIG_ENDIAN FLOAT_WORDS_BIG_ENDIAN \
REG_WORDS_BIG_ENDIAN SHIFT_COUNT_TRUNCATED STRICT_ALIGNMENT"

# THE REGISTER-VOCABULARY MACROS (macro-status.txt: CONVERTED_REGS).
#
# Retired from the header probe on 2026-08-12 because their aarch64 arms went
# green in ecad6abf6ae for the wrong reason: FIRST_PSEUDO_REGISTER and
# N_REG_CLASSES became the compile-time UNION width -- one number in every
# consumer translation unit, by design, because it is the layout of the four
# shared structures -- and REGNO_REG_CLASS became a call through targetm_regs.
# All three agree across the three header contexts now, and that agreement is
# a fact about the redirect, not about aarch64 getting aarch64's answer.
#
# The per-base answer moved to the registry inside the linked cc1, which is
# what the plugin reads.  Scored against an INDEPENDENT measurement of each
# base's own headers (section 4c), never against the registry's own numbers.
REGS_MACROS="FIRST_PSEUDO_REGISTER N_REG_CLASSES REGNO_REG_CLASS"
is_regs () { case " $REGS_MACROS " in *" $1 "*) return 0;; esac; return 1; }

# THE REDIRECTS MOVED OUT OF `defaults.h' INTO `multi-target-macros.h' AND
# THESE TWO HELPERS DID NOT FOLLOW.  Both of them grepped `$SRC/defaults.h',
# which today carries ZERO `(targetm_cdata.' redirects and zero
# `MULTI_TARGET_UNION_' ones -- all 24 cdata redirects and all three register
# ones live in `multi-target-macros.h', which `defaults.h:1932' includes.
#
# So both helpers answered NO for every macro, and this script DIED at its own
# controls (`control: ASM_COMMENT_START is redirected ... and the check says
# it is not') before probing anything.  That is the control doing exactly its
# job -- the same shape as `macro-probe-run.sh' exiting rc=9 before probing
# anything, which PRINCIPLES records, except that this one refuses loudly on
# the FIRST run rather than after a day of propagated figures.
#
# Repaired here rather than described: a finding written up with the code left
# alone is rediscovered at full price by the next agent.  The file is named
# rather than "either file", because "cannot tell which authority answered" is
# this branch's own root bug and a two-file `grep' would reintroduce it.
MTMACROS='multi-target-macros.h'

# Is macro $1 redirected to the register vocabulary?  Two different redirects,
# matched separately and exactly, because they mean different things and a
# check that accepted either would be satisfied by the wrong one: the two
# COUNTS become the compile-time union width, and REGNO_REG_CLASS becomes a
# run-time call.
reg_redirected () {
  case $1 in
    FIRST_PSEUDO_REGISTER|N_REG_CLASSES)
      grep -qE "^#define $1 MULTI_TARGET_UNION_$1\$" "$SRC/$MTMACROS" ;;
    REGNO_REG_CLASS)
      grep -qE '^#define REGNO_REG_CLASS\(REGNO\)' "$SRC/$MTMACROS" \
        && grep -qE 'targetm_regs->regno_reg_class' "$SRC/$MTMACROS" ;;
    *) return 1 ;;
  esac
}

is_cdata_num () { case " $CDATA_NUM " in *" $1:"*) return 0;; esac; return 1; }
cdata_num_want () {                    # cdata_num_want <macro> <base>
  local e f
  for e in $CDATA_NUM; do
    case $e in "$1":*) f=${e#*:}
      case $2 in i386) echo "${f%%:*}";; *) echo "${f#*:}";; esac; return;;
    esac
  done
}

# Is macro $1 redirected to a target-cdata slot?  Matched on the
# `#define <M> (targetm_cdata.' form specifically, not on the name appearing
# somewhere in the file -- `defaults.h' still carries each macro's ORIGINAL
# fallback definition (`defaults.h:39' is `#define ASM_COMMENT_START ";#"'),
# and a looser match would report every one of them redirected whether or not
# the redirect below it still existed.  See the note above `reg_redirected'
# for why the file this greps changed.
redirected () {
  grep -qE "^#define $1 \(targetm_cdata\." "$SRC/$MTMACROS"
}

# Comments are not uses.  varasm.cc explains in prose why GLOBAL_ASM_OP became
# a hook, and a plain grep reads that as an unconverted macro -- a FAIL for a
# conversion that is complete.  Weakening the check to make that number move
# would be the wrong move; stripping comments is the right one, and it comes
# with a control (below) so the stripper cannot silently swallow real uses.
strip_comments () {                    # strip_comments <file>
  awk '{ line=$0; out=""
         while (length (line)) {
           if (inblk) { i=index (line, "*/")
                        if (!i) { line=""; break }
                        line=substr (line, i+2); inblk=0; continue }
           i=index (line, "/*"); j=index (line, "//")
           if (j && (!i || j<i)) { out=out substr (line,1,j-1); line=""; break }
           if (i) { out=out substr (line,1,i-1); line=substr (line,i+2); inblk=1; continue }
           out=out line; line="" }
         print out }' "$1"
}

completeness () {                      # completeness <macro> -> "file:line ..."
  local m=$1 f
  ( cd "$SRC" || exit
    for f in $(grep -lw "$m" *.cc *.h); do
      case $f in
        *) echo "$f" | grep -qE "$GLUE" && continue ;;
      esac
      strip_comments "$f" | grep -nw "$m" | sed "s|^|$f:|"
    done ) | tr '\n' ' '
}

# CONTROL for the stripper.  An UNCONVERTED macro that target-independent code
# demonstrably spells must still be reported.  Without this, a stripper bug
# that ate every line would report every conversion as complete -- the exact
# false green this instrument exists to prevent.
ctl_sites=$(completeness UNITS_PER_WORD)
[ -n "$ctl_sites" ] \
  || die "control: UNITS_PER_WORD is spelled all over the middle end and the \
completeness check found nothing.  The comment stripper is eating real code, \
and every COMPLETENESS pass in this run would be meaningless."
echo "control: OK -- completeness check still sees UNITS_PER_WORD at \
$(echo "$ctl_sites" | wc -w) target-independent sites"

########################################################################
# 2.  Read the slots out of the running cc1.
########################################################################
CPPI="-DIN_GCC -DHAVE_CONFIG_H -I$BUILD/gcc -I$SRC -I$SRC/../include \
 -I$SRC/../libcpp/include -I$SRC/../libcody -I$SRC/../libdecnumber \
 -I$SRC/../libdecnumber/bid -I$BUILD/libdecnumber -I$SRC/../libbacktrace"
g++ -fPIC -shared -o "$OUT/tab.so" "$HERE/tab-plugin.cc" $CPPI -std=c++14 -w \
    > "$OUT/plugin-build.out" 2> "$OUT/plugin-build.err" \
  || { cat "$OUT/plugin-build.err"; die "TAB plugin did not build"; }

: > "$OUT/tiny.c"
printf 'int f (int x) { return x + 1; }\n' > "$OUT/tiny.c"
( cd "$BUILD/gcc" && TAB_OUT="$OUT/slots.txt" ./cc1 -quiet -nostdinc -O2 \
    -ftarget-config=specs-x86_64-pc-linux-gnu-config \
    -fplugin="$OUT/tab.so" "$OUT/tiny.c" -o "$OUT/tiny.s" ) \
  > "$OUT/cc1.out" 2> "$OUT/cc1.err" \
  || { cat "$OUT/cc1.err"; die "cc1 failed with the TAB plugin loaded"; }
[ -s "$OUT/slots.txt" ] || die "the plugin wrote no slots; TAB_OUT never opened \
or the callback never fired -- an empty table must not read as a clean run"
want=$(( $(echo $BASES | wc -w) * SLOTS_PER_BASE ))
[ "$(wc -l < "$OUT/slots.txt")" = "$want" ] \
  || die "slot dump has $(wc -l < "$OUT/slots.txt") lines, expected $want"

nm -C --defined-only "$BUILD/gcc/cc1" > "$OUT/nm.txt" 2> "$OUT/nm.err" \
  || { cat "$OUT/nm.err"; die "nm failed on cc1"; }
[ -s "$OUT/nm.err" ] && { cat "$OUT/nm.err"; die "nm wrote to stderr"; }
[ "$(wc -l < "$OUT/nm.txt")" -gt 10000 ] \
  || die "nm produced $(wc -l < "$OUT/nm.txt") symbols for cc1; not a real \
symbol table, and every address would resolve to <unknown>"

resolve () {                           # resolve <hexaddr> -> symbol name
  local a=${1#0x}
  awk -v a="$a" 'BEGIN{ t=tolower(a) }
       { s=$1; sub(/^0+/,"",s); if (tolower(s)==t) { $1=""; $2=""; sub(/^  /,"");
         sub(/\(.*$/,""); print; exit } }' "$OUT/nm.txt"
}
getptr () { awk -F'|' -v b="$2" -v m="$3" '$1=="PTR"&&$2==b&&$3==m{print $5}' "$1"; }
getstr () { awk -F'|' -v b="$2" -v m="$3" '$1=="STR"&&$2==b&&$3==m{print $5}' "$1"; }
getnum () { awk -F'|' -v b="$2" -v m="$3" '$1=="NUM"&&$2==b&&$3==m{print $5}' "$1"; }
getregv () { awk -F'|' -v b="$2" -v m="$3" '$1=="REGV"&&$2==b&&$3==m{print $5}' "$1"; }

########################################################################
# 3.  DISCRIMINATION CONTROLS -- run BEFORE any verdict is issued.
########################################################################
cs_i=$(getptr "$OUT/slots.txt" i386 CTL_SHARED)
cs_a=$(getptr "$OUT/slots.txt" aarch64 CTL_SHARED)
[ -n "$cs_i" ] && [ -n "$cs_a" ] || die "control: CTL_SHARED not in the dump"
[ "$cs_i" = "$cs_a" ] \
  || die "control: a hook BOTH bases leave at the shared default resolved to two \
different addresses ($cs_i vs $cs_a).  TAB reports spurious divergence and every \
'wrong base' verdict below would be unattributable."
cd_i=$(getptr "$OUT/slots.txt" i386 CTL_DIFFER)
cd_a=$(getptr "$OUT/slots.txt" aarch64 CTL_DIFFER)
[ "$cd_i" != "$cd_a" ] \
  || die "control: a hook BOTH bases override with their own function resolved \
to the SAME address.  TAB cannot discriminate, so a 'same symbol' verdict proves \
nothing."
n_i=$(resolve "$cd_i"); n_a=$(resolve "$cd_a")
echo "$n_i" | grep -qE "$own_i386" \
  || die "control: i386's CTL_DIFFER slot resolved to [$n_i], which is not an \
i386 symbol; the ownership test itself is broken"
echo "$n_a" | grep -qE "$own_aarch64" \
  || die "control: aarch64's CTL_DIFFER slot resolved to [$n_a], not an aarch64 \
symbol"

# The (c-DATA) numeric discrimination control.  Fifteen of the eighteen numeric
# slots hold the same value for both bases in this configuration, so their
# agreement cannot distinguish a per-base mechanism from one pinned to the
# primary.  These three must differ.  Asserted here, ahead of every verdict,
# because if the mechanism is pinned then all eighteen PASSes below are
# restating i386's answer twice and none of them means anything.
for m in $CDATA_NUM_DISCRIM; do
  gi=$(getnum "$OUT/slots.txt" i386 "$m")
  ga=$(getnum "$OUT/slots.txt" aarch64 "$m")
  [ -n "$gi" ] && [ -n "$ga" ] \
    || die "control: $m is not in the numeric dump; the discrimination control \
cannot run and the eighteen (c-DATA) numeric verdicts would be unattributable"
  [ "$gi" != "$ga" ] \
    || die "control: $m reads $gi for BOTH bases, but i386.h and aarch64.h give \
different values for it (see PREREGISTER-cdata-num.md).  The per-config slots \
are not per-config: something is answering with one base's data for every base, \
which is the targetm_asm_ops failure again.  No verdict below is meaningful."
done
echo "control: OK -- $(echo $CDATA_NUM_DISCRIM | wc -w) numeric (c-DATA) slots \
that MUST differ between the bases do differ"
echo "control: OK -- TAB reports AGREEMENT (CTL_SHARED -> $(resolve "$cs_i")) \
AND DISAGREEMENT (CTL_DIFFER -> $n_i vs $n_a), and attributes each to its base"

########################################################################
# 4.  The string slots are checked against an INDEPENDENT measurement.
#     Comparing TAB's answer with TAB's own expectation would be a tautology;
#     the header probe measured these bytes by a completely different route.
########################################################################
for b in $BASES; do
  [ -s "$MTP/str-$b.txt" ] || die "no $MTP/str-$b.txt -- run macro-probe-run.sh \
first.  Without it the string slots would be scored against this script's own \
guess, which asserts nothing."
done

########################################################################
# 4a. IS `$MTP' THE PRE-CONVERSION DATASET, AND CAN IT BE DATED AND ATTRIBUTED?
#
# THE FAILURE THIS PREVENTS.  A (c-DATA) macro's HEADER arm is retired the
# moment it becomes CONVERTED_CDATA -- that is the design.  So a macro-probe
# run over HEAD does not measure ASM_COMMENT_START/WCHAR_TYPE/SIZE_TYPE/
# PTRDIFF_TYPE at all, and a dataset produced by one carries no value for them.
# Point this script at such a dataset and every one of those arms scored
# "DISPATCH: no independent value" -- a FAIL, rendered exactly like a WRONG
# MEASURED VALUE.  That is this project's own standing rule broken inside its
# own harness: a MISSING EXPECTED value must never be spelled the same way as a
# disagreeing one.  It happened -- /tmp/mtp-before was overwritten by a
# post-Stage-2 run -- and it cost two agents a session, one of whom reported
# 17/22 and could not prove the five reds were not his own work.
#
# So: refuse, by name, before scoring anything.  A run that cannot get an
# independent value must not produce a scoreboard at all.
########################################################################
# (i)  It must be datable and attributable.  An undated directory in /tmp is
#      not a reference; it is whatever the last person to run a probe left
#      behind.
if [ ! -s "$MTP/PROVENANCE.txt" ]; then
  die "$MTP has no PROVENANCE.txt, so this dataset cannot be dated or \
attributed and there is no way to tell a pre-conversion reference from \
whatever the last macro-probe run left in /tmp.  Regenerate it with \
scratchpad/mtp-before-regen.sh, or point MTP at a dataset that carries one."
fi
head -1 "$MTP/PROVENANCE.txt" | grep -q '^MTP-PROVENANCE ' \
  || die "$MTP/PROVENANCE.txt does not start with an MTP-PROVENANCE line; it is \
not a provenance record this script knows how to read"
mtp_commit=$(sed -n 's/^commit  *//p' "$MTP/PROVENANCE.txt")
[ -n "$mtp_commit" ] \
  || die "$MTP/PROVENANCE.txt names no commit, so the dataset cannot be \
attributed to a tree"

# (ii) It must actually CARRY the retired arms.  This is the check that would
#      have caught the overwrite immediately.  Only macros the current tree has
#      really converted are demanded -- before the conversion the header probe
#      supplied them anyway, and after it, it never will.
#
#      aarch64 is the base asked, deliberately: on i386 the three *_TYPE macros
#      are not constant expressions and the header probe cannot value them on
#      that base even BEFORE the conversion (section 4b supplies i386 from
#      genuine upstream cc1 instead).  Demanding them on i386 would reject a
#      perfectly good reference.
for m in $CDATA_MACROS; do
  redirected "$m" || continue
  awk -v m="$m" '$1==m{f=1} END{exit !f}' "$MTP/str-aarch64.txt" && continue
  die "POST-CONVERSION REFERENCE DATASET.

  $MTP/str-aarch64.txt has no value for $m, and defaults.h redirects $m to a
  target-cdata slot -- so this dataset was produced by a macro-probe run over a
  tree where $m's header arm was ALREADY RETIRED.  Such a run can never supply
  the value; the arm is gone by design, not missing by accident.

  Scoring against it would print FAIL for every (c-DATA) string arm with the
  reason \"no independent value\", which is indistinguishable from the compiler
  producing the WRONG bytes.  Refusing instead.

  What is needed: a macro-probe run over the last tree that PREDATES the
  conversion -- commit 36ba31303e2, the parent of b063704e8a9 (\"per-config
  slots for four (c-DATA) macros\").
  Rebuild it with:  scratchpad/mtp-before-regen.sh
  This dataset says it came from: $mtp_commit"
done
echo "ok: $MTP is a pre-conversion reference (commit $mtp_commit) and carries \
all $(echo $CDATA_MACROS | wc -w) retired macros"

########################################################################
# 4b. AN INDEPENDENT VALUE FOR THE i386 SIDE OF THE TYPE MACROS.
#
# The header probe values `WCHAR_TYPE'/`SIZE_TYPE'/`PTRDIFF_TYPE' for aarch64
# only.  On i386 they are `(TARGET_LP64 ? "long unsigned int" : "unsigned int")'
# -- not constant expressions, so the STR probe cannot value them at all, and
# `$MTP/str-i386.txt' has no entry.  Scoring those three arms against this
# script's own expectation would be a tautology, and skipping them would be a
# floor.
#
# So ask a THIRD compiler that has nothing to do with this branch: the genuine
# upstream x86_64 `cc1' at the merge-base, via its own predefined macros.
# `__SIZE_TYPE__' and friends ARE `SIZE_TYPE' as that compiler resolved it, and
# they are produced by a binary this tree did not build.  It is the same
# authority `stock-compare.sh' uses, asked a different question.
########################################################################
STOCK=${STOCK:-/tmp/b-stock}
declare -A STOCKVAL
if [ -x "$STOCK/gcc/cc1" ]; then
  : > "$OUT/empty.c"
  ( cd "$STOCK/gcc" && ./cc1 -E -dM -quiet -nostdinc "$OUT/empty.c" ) \
    > "$OUT/stock-predef.txt" 2> "$OUT/stock-predef.err" \
    || { cat "$OUT/stock-predef.err"; die "stock cc1 could not be asked for its \
predefined macros"; }
  n=$(wc -l < "$OUT/stock-predef.txt")
  [ "$n" -gt 100 ] || die "stock cc1 printed only $n predefined macros; that is \
not a real -dM run and an absent __SIZE_TYPE__ below would be uninformative"
  tohex () { printf '%s' "$1" | od -An -tx1 -v | tr -d ' \n'; }
  for pair in "WCHAR_TYPE:__WCHAR_TYPE__" "SIZE_TYPE:__SIZE_TYPE__" \
              "PTRDIFF_TYPE:__PTRDIFF_TYPE__"; do
    m=${pair%%:*}; p=${pair##*:}
    v=$(sed -n "s/^#define $p //p" "$OUT/stock-predef.txt")
    [ -n "$v" ] || die "stock cc1 did not define $p; without it the i386 side \
of $m has no independent value and its arm would assert nothing"
    STOCKVAL[$m]=$(tohex "$v")
  done
  echo "control: OK -- genuine upstream cc1 supplies the i386 side independently\
 (__SIZE_TYPE__=[$(sed -n 's/^#define __SIZE_TYPE__ //p' "$OUT/stock-predef.txt")])"
else
  die "no $STOCK/gcc/cc1 -- the i386 side of the type macros would have no \
independent value, and an arm scored against this script's own guess is not an \
arm.  Build it with scratchpad/stock-build.sh."
fi

# CONTROL for `redirected'.  It must say YES for a macro the tree demonstrably
# redirects and NO for one it demonstrably does not -- otherwise a checker
# stuck on one answer would pass or fail everything alike.
redirected ASM_COMMENT_START \
  || die "control: ASM_COMMENT_START is redirected in defaults.h and the check \
says it is not.  Every (c-DATA) completeness verdict below would be red for no \
reason."
redirected UNITS_PER_WORD \
  && die "control: UNITS_PER_WORD is NOT redirected (it is still Stage 2 work) \
and the check says it is.  The check answers yes to everything."
echo "control: OK -- the defaults.h redirect check reports both answers"

########################################################################
# 4c. AN INDEPENDENT VALUE FOR THE REGISTER COUNTS.
#
# The registry inside cc1 says i386 has 92 registers and 34 classes and aarch64
# has 95 and 20.  Scoring that against a table written in this file would be a
# tautology of the same shape PREREGISTER-cdata-num.md exists to avoid, and
# scoring it against the header probe is no longer possible: the header probe
# now reads the UNION for both names in every context -- that is precisely why
# these three arms were retired.
#
# So ask each back end's own headers directly, by the route the widths
# themselves are measured (gcc/multi-target-reg-probe.cc + gen-reg-widths.sh):
# compile a declaration whose array bound is the value, in that base's own
# include context, with -DMULTI_TARGET_REG_PROBE so defaults.h's union block is
# skipped, and read the size back with `nm -S'.  Nothing is executed.  This is
# a different authority from the registry -- headers versus a constexpr table
# built and linked into cc1 -- so a disagreement is a real finding, and a
# registry pinned to one base cannot agree with both.
#
# +1 on every bound, and every way of learning nothing is fatal: a zero-sized
# object and an object `nm' did not report are indistinguishable, and a missing
# answer must never be able to act as an answer.
########################################################################
cat > "$OUT/reghdr.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
#ifndef MULTI_TARGET_REG_PROBE
#error this probe must be compiled with -DMULTI_TARGET_REG_PROBE
#endif
extern "C" {
char mt_hdr_first_pseudo_register[FIRST_PSEUDO_REGISTER + 1];
char mt_hdr_n_reg_classes[N_REG_CLASSES + 1];
}
EOF
declare -A HDR_FPR HDR_NRC
for b in $BASES; do
  [ -d "$BUILD/gcc/$b-inc" ] \
    || die "no $BUILD/gcc/$b-inc; the header oracle would fall back to the \
primary's tm.h and report i386's counts for both bases"
  ( cd "$BUILD/gcc" && g++ -c -o "$OUT/reghdr-$b.o" "$OUT/reghdr.cc" \
      "-I$b-inc" -DMULTI_TARGET_REG_PROBE $CPPI -std=c++14 -w ) \
      > "$OUT/reghdr-$b.out" 2> "$OUT/reghdr-$b.err" \
    || { cat "$OUT/reghdr-$b.err"; die "header oracle did not compile for $b"; }
  for pair in "mt_hdr_first_pseudo_register:FPR" "mt_hdr_n_reg_classes:NRC"; do
    sym=${pair%%:*}; key=${pair##*:}
    sz=$(nm -S --defined-only "$OUT/reghdr-$b.o" \
         | awk -v s="$sym" '$4==s{print strtonum("0x" $2)}')
    [ -n "$sz" ] || die "header oracle: nm reported no size for $sym in $b's \
object.  A symbol nm did not print must not read as a value."
    [ "$sz" -gt 1 ] || die "header oracle: $sym came back size $sz for $b; the \
bound is VALUE+1, so anything <= 1 means the value was 0 or absent"
    eval "HDR_$key[$b]=\$(( sz - 1 ))"
  done
  echo "oracle: $b's OWN headers say FIRST_PSEUDO_REGISTER=${HDR_FPR[$b]} \
N_REG_CLASSES=${HDR_NRC[$b]}"
done

# DISCRIMINATION, ASSERTED BEFORE ANY VERDICT.  If the two bases' headers gave
# the same counts, every PASS below would be equally consistent with a registry
# that answers one base's numbers for everyone -- the targetm_asm_ops failure.
# In THIS configuration they differ in both, so the arms can tell those two
# worlds apart; in a configuration where they did not, this would (correctly)
# refuse rather than print a scoreboard that cannot mean anything.
[ "${HDR_FPR[i386]}" != "${HDR_FPR[aarch64]}" ] \
  || die "oracle: both bases' headers give FIRST_PSEUDO_REGISTER=${HDR_FPR[i386]}; \
the arm cannot discriminate and its PASS would prove nothing"
[ "${HDR_NRC[i386]}" != "${HDR_NRC[aarch64]}" ] \
  || die "oracle: both bases' headers give N_REG_CLASSES=${HDR_NRC[i386]}; \
the arm cannot discriminate"
echo "control: OK -- the two bases' own headers DIFFER in both counts \
(${HDR_FPR[i386]}/${HDR_NRC[i386]} vs ${HDR_FPR[aarch64]}/${HDR_NRC[aarch64]}), \
so the registry cannot satisfy both by answering one"

# The registry must have been found at all.  A NULL lookup would otherwise
# arrive as three missing slots and read as "no slot in the dump", which is a
# FAIL rendered exactly like a wrong value.
for b in $BASES; do
  [ "$(getnum "$OUT/slots.txt" "$b" MT_REGS_FOUND)" = 1 ] \
    || die "target_regs_for(\"$b\") returned NULL inside the running cc1: the \
registry does not carry that base at all.  Every register verdict would be \
'no slot in the dump', which is indistinguishable from a wrong answer."
done

# The control for `reg_redirected', both directions -- a checker stuck on one
# answer would pass or fail all three arms alike.
reg_redirected FIRST_PSEUDO_REGISTER \
  || die "control: defaults.h redirects FIRST_PSEUDO_REGISTER to the union and \
the check says it does not"
reg_redirected UNITS_PER_WORD \
  && die "control: UNITS_PER_WORD is not a register-vocabulary macro and the \
check says it is redirected; it answers yes to everything"
echo "control: OK -- the register redirect check reports both answers"

########################################################################
# 5.  VERDICTS
########################################################################
: > "$OUT/results.txt"
for m in $TAB_MACROS; do
  if is_regs "$m"; then
    for b in $BASES; do
      why=""; v=PASS
      if ! reg_redirected "$m"; then
        v=FAIL; why="COMPLETENESS: defaults.h no longer redirects $m, so every \
target-independent use reads the primary's tm.h again"
      elif [ "$m" = REGNO_REG_CLASS ]; then
        p=$(getptr "$OUT/slots.txt" "$b" "$m")
        o_other=$(for o in $BASES; do [ "$o" = "$b" ] || getptr "$OUT/slots.txt" "$o" "$m"; done)
        vec=$(getregv "$OUT/slots.txt" "$b" "$m")
        v_other=$(for o in $BASES; do [ "$o" = "$b" ] || getregv "$OUT/slots.txt" "$o" "$m"; done)
        own=${HDR_FPR[$b]}
        # Everything at or past this base's own register count must answer 0
        # (NO_REGS).  Generic code walks to the union width, so this fence is
        # the only thing between i386's `regclass_map[REGNO]' and three reads
        # past the end of a real array -- in bounds of the struct, silent.
        tail_ok=$(echo "$vec" | awk -F, -v n="$own" \
          '{ for (i = n + 1; i <= NF; i++) if ($i != 0) { print "no:" i-1 ":" $i; exit } print "yes" }')
        if [ -z "$p" ] || [ -z "$vec" ]; then
          v=FAIL; why="no slot in the dump"
        elif [ "$p" = "$o_other" ]; then
          v=FAIL; why="DISPATCH: $b and the other base hold the SAME \
regno_reg_class address ($p).  One body answers for every base."
        elif [ "$vec" = "$v_other" ]; then
          v=FAIL; why="DISPATCH: the two bases return the SAME class for every \
register number; the dispatch is not per-base"
        elif [ "$tail_ok" != yes ]; then
          v=FAIL; why="FENCE: $b answers ${tail_ok##*:} for register \
$(t=${tail_ok#no:}; echo "${t%%:*}"), which is past its own \
first_pseudo_register ($own).  Generic code walks to the union width, so this \
is the read that would have gone off the end of regclass_map."
        else
          why="DISPATCH: per-base regno_reg_class at $p (the other base holds \
$o_other), answers differ between the bases, and every register at or past \
$b's own count ($own) comes back NO_REGS"
        fi
      else
        g=$(getnum "$OUT/slots.txt" "$b" "$m")
        case $m in
          FIRST_PSEUDO_REGISTER) w=${HDR_FPR[$b]} ;;
          N_REG_CLASSES)         w=${HDR_NRC[$b]} ;;
        esac
        if [ -z "$g" ]; then
          v=FAIL; why="no slot in the dump"
        elif [ -z "$w" ]; then
          v=FAIL; why="DISPATCH: the header oracle produced no value for $m on $b"
        elif [ "$g" = "$w" ]; then
          why="DISPATCH: the registry in the linked cc1 holds $g for $b, \
matching $b's OWN headers measured independently (and the other base's value \
differs, so this arm discriminates)"
        else
          v=FAIL; why="DISPATCH: the registry holds [$g] for $b but $b's own \
headers say [$w]"
        fi
      fi
      echo "$b $m TAB $v $why" >> "$OUT/results.txt"
    done
    continue
  fi
  if is_cdata_num "$m"; then
    # (c-DATA), numeric.  Same two questions as the string case: does
    # defaults.h still redirect the name, and did this base's refresh write
    # THIS base's value -- checked against the hand derivation in
    # PREREGISTER-cdata-num.md, never against the other base's slot.
    for b in $BASES; do
      why=""; v=PASS
      if ! redirected "$m"; then
        v=FAIL; why="COMPLETENESS: defaults.h does not redirect $m to a \
target-cdata slot, so every use still reads the primary's tm.h"
      else
        g=$(getnum "$OUT/slots.txt" "$b" "$m")
        w=$(cdata_num_want "$m" "$b")
        if [ -z "$g" ]; then
          v=FAIL; why="no slot in the dump"
        elif [ -z "$w" ]; then
          v=FAIL; why="DISPATCH: no pre-registered value for $m on $b"
        elif [ "$g" = "$w" ]; then
          why="DISPATCH: $b's refresh wrote $g, matching the derivation from \
$b's own header"
          case " $CDATA_NUM_DISCRIM " in
            *" $m "*) why="$why (and this is one of the three that DIFFER \
between the bases, so it discriminates)";;
            *) why="$why (both bases give $g here, so this arm does NOT \
discriminate -- see the control above)";;
          esac
        else
          v=FAIL; why="DISPATCH: $b's refresh wrote [$g] but $b's header \
derives [$w]"
          case " $CDATA_NUM_OPTSTATE " in
            *" $m "*) why="$why -- and $m is a read of $b's OWN OPTION \
VARIABLES, which this single-run plugin cannot set up for the base it did not \
select.  UNVERIFIED, not known-wrong; needs a second run under $b's target \
config, blocked while aarch64 cc1 ICEs before plugin callbacks fire.";;
          esac
        fi
      fi
      echo "$b $m TAB $v $why" >> "$OUT/results.txt"
    done
    continue
  fi
  if is_cdata "$m"; then
    # (c-DATA): the name survives; what must hold is that defaults.h redirects
    # it, and that each base's refresh writes THAT base's own bytes.
    for b in $BASES; do
      why=""; v=PASS
      if ! redirected "$m"; then
        v=FAIL; why="COMPLETENESS: defaults.h does not redirect $m to a \
target-cdata slot, so every use still reads the primary's tm.h"
      else
        s=$(getstr "$OUT/slots.txt" "$b" "$m")
        exp=$(awk -v m="$m" '$1==m{print $2}' "$MTP/str-$b.txt")
        src="the header probe"
        if [ -z "$exp" ] && [ "$b" = i386 ]; then
          exp=${STOCKVAL[$m]}; src="genuine upstream cc1's __${m%_TYPE}_TYPE__"
        fi
        if [ -z "$s" ]; then
          v=FAIL; why="no slot in the dump"
        elif [ -z "$exp" ]; then
          v=FAIL; why="DISPATCH: no independent value for $m on $b"
        elif [ "$s" = "$exp" ]; then
          why="DISPATCH: $b's refresh wrote $b's own bytes ($s), agreeing with \
$src"
        else
          v=FAIL; why="DISPATCH: $b's refresh wrote [$s] but $src says [$exp]"
        fi
      fi
      echo "$b $m TAB $v $why" >> "$OUT/results.txt"
    done
    continue
  fi
  sites=$(completeness "$m")
  for b in $BASES; do
    why=""; v=PASS
    if [ -n "$sites" ]; then
      v=FAIL; why="COMPLETENESS: still spelled outside the glue: $sites"
    else
      s=$(getstr "$OUT/slots.txt" "$b" "$m")
      if [ -n "$s" ]; then
        exp=$(awk -v m="$m" '$1==m{print $2}' "$MTP/str-$b.txt")
        if [ -z "$exp" ]; then
          v=FAIL; why="DISPATCH: no independent header value for $m on $b"
        elif [ "$s" = "$exp" ]; then
          why="DISPATCH: string slot = $b's own bytes ($s)"
        else
          v=FAIL; why="DISPATCH: slot=[$s] but $b's header says [$exp]"
        fi
      else
        p=$(getptr "$OUT/slots.txt" "$b" "$m")
        [ -n "$p" ] || { v=FAIL; why="no slot in the dump"; }
        if [ -n "$p" ]; then
          sym=$(resolve "$p")
          [ -n "$sym" ] || sym="<unresolved $p>"
          eval "own=\$own_$b"
          other=$(for o in $BASES; do [ "$o" = "$b" ] || { eval "echo \$own_$o"; }; done)
          if echo "$sym" | grep -qE "$own"; then
            why="DISPATCH: $sym (owned by $b)"
          elif echo "$sym" | grep -qE "$other"; then
            v=FAIL; why="DISPATCH: $b's slot holds $sym, which belongs to \
ANOTHER base -- this is the two-stage poison, live"
          else
            # A per-base copy of a static glue wrapper carries no base in its
            # name.  It is only acceptable if the two bases hold DIFFERENT
            # copies; one shared copy means one shared answer.
            o_other=$(for o in $BASES; do [ "$o" = "$b" ] || getptr "$OUT/slots.txt" "$o" "$m"; done)
            if [ "$p" = "$o_other" ]; then
              v=FAIL; why="DISPATCH: $b and the other base hold the SAME \
address ($p -> $sym).  One body answers for every base."
            else
              why="DISPATCH: per-base copy of $sym at $p (distinct from the \
other base's $o_other)"
            fi
          fi
        fi
      fi
    fi
    echo "$b $m TAB $v $why" >> "$OUT/results.txt"
  done
done

nres=$(wc -l < "$OUT/results.txt")
nwant=$(( $(echo $TAB_MACROS | wc -w) * $(echo $BASES | wc -w) ))
[ "$nres" = "$nwant" ] || die "produced $nres verdicts, expected $nwant"

{
  echo "TAB arms: $nwant   bases: $BASES   macros: $TAB_MACROS"
  for b in $BASES; do
    echo "$b: PASS $(awk -v b=$b '$1==b && $4=="PASS"' "$OUT/results.txt" | wc -l)  \
FAIL $(awk -v b=$b '$1==b && $4=="FAIL"' "$OUT/results.txt" | wc -l)"
  done
  echo "---"
  cat "$OUT/results.txt"
} > "$OUT/summary.txt"
cat "$OUT/summary.txt"
awk '$4=="FAIL"' "$OUT/results.txt" | grep -q . && exit 1
exit 0
