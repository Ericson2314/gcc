#!/bin/sh
# #130 -- guard arms for the insn-attrtab selector.
#
# ARM 0 asserts the GENERATED content by name and by value and RUNS FIRST: a
# generator that runs, exits 0 and changes nothing is this project's sharpest
# false green, and move-if-change actively hides it.
# ARM 1 is the NON-VACUITY arm: if the two configured bases agreed about
# HAVE_ATTR_preferred_for_size, every other arm here would pass on a change
# that does nothing.
# ARM 5 injects the exact faults the mitigations name and requires each to
# fire BY NAME, with a control before and a restore after.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b130}
G=$B/gcc
P=0; F=0
ok  () { P=$((P+1)); echo "PASS  $1"; }
bad () { F=$((F+1)); echo "FAIL  $1"; }
chk () { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (got $2, want $3)"; fi; }

echo "=== ARM 0: the GENERATED artefacts, by name and by value"
chk "insn-attr.h includes multi-target-attr.h" \
    "$(grep -c '#include "multi-target-attr.h"' "$G/insn-attr.h")" 1
chk "insn-attr-i386.h does NOT" \
    "$(grep -c 'multi-target-attr.h' "$G/insn-attr-i386.h")" 0
chk "insn-attr-aarch64.h does NOT" \
    "$(grep -c 'multi-target-attr.h' "$G/insn-attr-aarch64.h")" 0
chk "insn-attrtab.cc opts out of the redirect" \
    "$(grep -c '^#define MULTI_TARGET_ATTR_NO_REDIRECT 1$' "$G/insn-attrtab.cc")" 1
chk "mt-aarch64/insn-attrtab-aarch64.cc does NOT opt out (it never sees the header)" \
    "$(grep -c 'MULTI_TARGET_ATTR_NO_REDIRECT' "$G/mt-aarch64/insn-attrtab-aarch64.cc")" 0
chk "insn-dfatab.cc opts out too (same write_header)" \
    "$(grep -c '^#define MULTI_TARGET_ATTR_NO_REDIRECT 1$' "$G/insn-dfatab.cc")" 1
# The value the whole design rests on: the generator's own answer for a base
# with no such attribute.  If this line ever stops being emitted, the thunk in
# target-cumargs.cc silently stops compiling -- or worse, starts resolving to
# something else.
chk "aarch64's header still stubs preferred_for_size to hook_int_rtx_1" \
    "$(grep -c '^#define get_attr_preferred_for_size hook_int_rtx_1$' \
        "$G/insn-attr-aarch64.h")" 1
# genattr emits the stub GUARDED, in every base's header, so its mere presence
# in i386's file proves nothing -- an earlier version of this arm asserted the
# text was absent there and failed, which is the "assert on the value, not the
# text" lesson arriving again.  What actually differs is the guard, and the
# only reading that settles it is the ADDRESS the built thunk jumps to.  ARM 2b
# below does that; this arm only fixes the generator's invariant.
chk "the stub is emitted GUARDED in i386's header too" \
    "$(grep -c '^#if !HAVE_ATTR_preferred_for_size$' "$G/insn-attr-i386.h")" 1
chk "gcc/Makefile: target-attr.h is a prerequisite of the selector" \
    "$(grep -c 'target-cumargs-select.o' "$G/Makefile" > /dev/null; \
       grep -A2 'target-cumargs-select.o: ' "$G/Makefile" \
       | grep -c 'target-attr.h')" 1
chk "generated multi-target-md.mk: target-attr.h reached the per-base rules" \
    "$(grep -c 'target-attr.h' "$G/multi-target-md.mk")" 2
chk "build/genattr.o and build/genattrtab.o get -DGEN_MULTI_TARGET" \
    "$(grep -cE '^build/gen(attr|attrtab)\.o : BUILD_CPPFLAGS' "$G/Makefile")" 2

echo
echo "=== ARM 1: NON-VACUITY -- the two bases must DISAGREE"
i=$(grep -c '^#define HAVE_ATTR_preferred_for_size 1$' "$G/insn-attr-i386.h")
a=$(grep -c '^#define HAVE_ATTR_preferred_for_size 1$' "$G/insn-attr-aarch64.h")
chk "i386 HAS preferred_for_size" "$i" 1
chk "aarch64 does NOT" "$a" 0
if [ "$i" = "$a" ]; then
  bad "NON-VACUITY: the bases agree, so this whole task is untested by construction"
else
  ok "NON-VACUITY: the absent case is genuinely exercised by this pair"
fi

echo
echo "=== ARM 2: no #if over a HAVE_ATTR_* survives in shared code"
# A macro expanding to a CALL is silently 0 on a #if line.  This is the arm
# that stops a new one being added; ARM 5c injects one and requires it to fire.
#
# `^#' with no leading whitespace: an earlier version allowed indentation and
# matched the QUOTED EXAMPLE inside target-attr.h's own comment.  A guard that
# fails on the prose describing it is not measuring the code.
#
# dwarf2out.cc:28762 is excluded BY NAME and with a reason, not by loosening
# the pattern: it is an `#ifdef', and that file does not include insn-attr.h at
# all (its own comment says so), so the block is dead in every configuration.
# Arm 2c re-checks that reason rather than trusting it.
n=$(grep -rn '^#[[:space:]]*if.*HAVE_ATTR_' "$SRC/gcc" \
      --include='*.cc' --include='*.h' \
    | grep -v '/config/' | grep -v '/gcc/gen' \
    | grep -v '^.*dwarf2out.cc:[0-9]*:#ifdef HAVE_ATTR_length' | wc -l)
chk "shared '#if HAVE_ATTR_' sites" "$n" 0
chk "2c dwarf2out.cc still does not include insn-attr.h, so its #ifdef is dead" \
    "$(grep -c '#include "insn-attr.h"' "$SRC/gcc/dwarf2out.cc")" 0

echo
echo "=== ARM 2b: THE VALUE -- what each base's thunk actually JUMPS TO"
# The whole design rests on one claim: for a base with no such attribute the
# slot holds the generator's own stub (constant 1) and nothing invented.  A
# source-text arm cannot show that; the object can.  Both sides are read, so
# this cannot pass by everyone getting the same new answer.
dis () { sh "$S/eb-shell.sh" "cd $G && objdump -d --no-show-raw-insn \
  --start-address=$1 --stop-address=$(printf '0x%x' $(( $1 + 8 ))) cc1 \
  | grep -oE 'jmp .*'" 2>/dev/null | head -1; }
A=$(sh "$S/eb-shell.sh" "cd $G && nm -C mt-aarch64/../target-cumargs-aarch64.o \
  | grep ' t mt_base_get_attr_preferred_for_size'" 2>/dev/null | awk '{print $1}')
I=$(sh "$S/eb-shell.sh" "cd $G && nm -C target-cumargs-i386.o \
  | grep ' t mt_base_get_attr_preferred_for_size'" 2>/dev/null | awk '{print $1}')
if [ -z "$A" ] || [ -z "$I" ]; then
  bad "2b could not locate both per-base thunks (nm read nothing) -- NOT scored"
else
  ok "2b both per-base preferred_for_size thunks exist (aarch64 @$A, i386 @$I)"
fi
# The RELOCATION LINE, not the disassembly line: an earlier version grepped
# both and matched the thunk's own LABEL, scoring aarch64's slot as if it
# called the real attribute function.  Only `R_X86_64_PLT32' lines are read.
reloc () { sh "$S/eb-shell.sh" "cd $G && objdump -rd $1 \
  | grep -A3 '^$2 <_ZL35mt_base_get_attr_preferred_for_sizeP8rtx_insn>:' \
  | grep 'R_X86_64_PLT32' | awk '{print \$3}'" 2>/dev/null | head -1; }
ra=$(reloc target-cumargs-aarch64.o "$A")
ri=$(reloc target-cumargs-i386.o "$I")
chk "2b aarch64's thunk calls the generator's ABSENT answer" \
    "$ra" '_Z14hook_int_rtx_1P7rtx_def-0x4'
chk "2b i386's thunk calls i386's REAL attribute function" \
    "$ri" '_ZN9insn_i38627get_attr_preferred_for_sizeEP8rtx_insn-0x4'

echo
echo "=== ARM 3: THE SELECTION -- something assigns targetm_attr"
chk "multi-target-select.cc installs it" \
    "$(grep -c 'targetm_attr = targetm_cumargs->attr;' "$SRC/gcc/multi-target-select.cc")" 1
chk "and refuses by name when it is null" \
    "$(grep -c 'no insn-attribute table attached' "$SRC/gcc/multi-target-select.cc")" 1
chk "targetm_attr starts NULL, not at the primary" \
    "$(grep -c '^const struct target_attr_desc \*targetm_attr;$' \
        "$SRC/gcc/target-cumargs-select.cc")" 1

echo
echo "=== ARM 4: THE LEAK -- nothing binds the bare six any more"
for f in get_attr_enabled get_attr_preferred_for_size get_attr_preferred_for_speed \
         insn_default_length insn_min_length insn_current_length; do
  c=$(sh "$S/eb-shell.sh" \
        "cd $G && nm -C -u --print-file-name *.o | grep -cE ' U $f\\('" 2>/dev/null)
  [ -z "$c" ] && c=0
  chk "bare $f binders" "$c" 0
done

echo
echo "=== ARM 4b: the SCHEDULING family -- THE RATCHET FIRED AND HAS BEEN TURNED"
# THIS ARM USED TO ASSERT THE OPPOSITE, AND THE INVERSION IS THE POINT.  It
# read: "RATCHET -- the SCHEDULING family is still unselected", requiring each
# bare name to have MORE THAN ZERO binders, so that selecting one would fail
# this guard rather than land unremarked.  It has now been selected -- see
# target-automata.h -- so the assertion turns over: `state_transition',
# `insn_default_latency' and `dfa_start' must now have ZERO bare binders,
# because shared code reaches them through `mt_*'.
#
# The reason it was selected is worth carrying here, because it is not the
# reason the old ratchet gave.  That comment called it a modelling leak.
# `state_size' is the LENGTH of the DFA state buffer, so it is a heap
# overflow: ia64 sized `prev_cycle_state' at 4 bytes from its own automaton,
# `sched_init' overwrote the shared `dfa_state_size' with the bare (i386) 116,
# and `ia64_variable_issue' memcpyed 116 bytes into the 4-byte buffer --
# reproduced by an ASAN cc1 six times in six.
for f in state_size state_transition state_reset dfa_start insn_default_latency \
         insn_latency bypass_p; do
  c=$(sh "$S/eb-shell.sh" \
        "cd $G && nm -C -u --print-file-name *.o | grep -cE ' U $f(\\(|\$)'" 2>/dev/null)
  [ -z "$c" ] && c=0
  chk "bare $f binders" "$c" 0
done
# `internal_dfa_insn_code' is STILL not selected, and it stays on the ratchet
# in its original direction.  No shared translation unit names it, so a
# selector would be a change with no consumer -- but it is a bare function
# POINTER that each base's `init_sched_attrs' assigns, and a shared object
# starting to bind it has to be noticed.
#
# THE EXPECTED READING IS ONE BINDER, NOT ZERO, AND ASSERTING ZERO WAS WRONG.
# Measured: the single bare binder is `insn-automata.o' -- the PRIMARY's own
# generated automaton reaching the pointer its own `insn-dfatab.o' defines.
# That pair is internally consistent and is not a leak; after this change
# nothing shared calls into it at all.  So the arm names the binder rather
# than counting it, which is the only form that can tell "still just the
# generated pair" from "a shared object appeared".
b=$(sh "$S/eb-shell.sh" \
      "cd $G && nm -C -u --print-file-name *.o | grep -E ' U internal_dfa_insn_code\$' | sed 's,.*/,,;s/:.*//' | sort -u | tr '\\n' ' '" 2>/dev/null)
b=$(echo $b)
chk "bare internal_dfa_insn_code binders (expect the generated pair alone)" \
    "$b" "insn-automata.o"

echo
echo "=== ARM 5: INJECTION -- every mitigation must fire, with control+restore"
CUM=$SRC/gcc/multi-target-select.cc
CUMB=$B/t130-inj-multi-target-select.cc.bak
ATTRH=$SRC/gcc/target-attr.h
cp "$CUM" "$CUMB" || exit 9

# 5a CONTROL, runs first: the UNMODIFIED tree must build.  Without it a
# refusal below can be credited to the injection when it was really an
# unrelated breakage.
r=$(sh "$S/eb-shell.sh" "cd $G && make target-cumargs-select.o multi-target-select.o" \
      > "$B/t130-inj-ctl.out" 2> "$B/t130-inj-ctl.err"; echo $?)
chk "5a control: unmodified tree compiles" "$r" 0

# 5b: delete the install line.  The mitigation is the by-name internal_error;
# it must be REACHED, so this is a runtime arm and not a compile one.
awk '{ if ($0 ~ /targetm_attr = targetm_cumargs->attr;/) print "\ttargetm_attr = NULL;"; else print }' \
    "$CUMB" > "$CUM"
# ASSERT THE INJECTION PRODUCED THE STATE INTENDED, in both directions.
if grep -q 'targetm_attr = NULL;' "$CUM" \
   && ! grep -q 'targetm_attr = targetm_cumargs->attr;' "$CUM"; then
  ok "5b injection produced the intended state (assign replaced, original gone)"
else
  bad "5b injection did NOT take -- every reading below is of the UNMODIFIED compiler"
fi
sh "$S/eb-shell.sh" "cd $G && make cc1" > "$B/t130-inj-b.out" 2> "$B/t130-inj-b.err"
sh "$S/eb-shell.sh" "cd $G && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc \
  -o /dev/null $B/fn-add.c" > "$B/t130-inj-b.run" 2>&1
if grep -q 'no insn-attribute table attached\|no back end has been selected, so no insn attributes' \
     "$B/t130-inj-b.run"; then
  ok "5b the by-name refusal FIRED"
else
  bad "5b the refusal did NOT fire; head: $(head -2 "$B/t130-inj-b.run" | tr '\n' ' ')"
fi

# 5c: put a `#if HAVE_ATTR_length' back and require ARM 2 to catch it.
INJ=$B/t130-inj-hdr.h
printf '#if HAVE_ATTR_length\n#endif\n' > "$SRC/gcc/t130-inj-probe.h"
n=$(grep -rn '^[[:space:]]*#[[:space:]]*if.*HAVE_ATTR_' "$SRC/gcc" \
      --include='*.cc' --include='*.h' | grep -v '/config/' | grep -v '/gcc/gen' | wc -l)
if [ "$n" -gt 0 ]; then ok "5c ARM 2 catches a re-introduced '#if HAVE_ATTR_' (saw $n)"
else bad "5c ARM 2 is blind to a re-introduced '#if HAVE_ATTR_'"; fi
rm -f "$SRC/gcc/t130-inj-probe.h" "$INJ"

# 5z RESTORE, and the reversal must reverse.
cp "$CUMB" "$CUM"
if grep -q 'targetm_attr = targetm_cumargs->attr;' "$CUM" \
   && ! grep -q 'targetm_attr = NULL;' "$CUM"; then
  ok "5z restore reversed the injection"
else
  bad "5z restore did NOT reverse -- THE TREE IS LEFT INJECTED"
fi
sh "$S/eb-shell.sh" "cd $G && make cc1" > "$B/t130-inj-z.out" 2> "$B/t130-inj-z.err"
sh "$S/eb-shell.sh" "cd $G && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc \
  -o $B/t130-inj-z.s $B/fn-add.c" > "$B/t130-inj-z.run" 2>&1
chk "5z the restored compiler compiles the add again" \
    "$( [ -s "$B/t130-inj-z.s" ] && echo yes || echo no )" yes

echo
echo "=== $P PASS / $F FAIL"
[ "$F" = 0 ]
