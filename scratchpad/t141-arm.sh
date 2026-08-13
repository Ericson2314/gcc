#!/bin/sh
# #141 -- THE ACCEPTANCE ARM for the option-state family (UNITS_PER_WORD,
# POINTER_SIZE, BIGGEST_ALIGNMENT).
#
# WHY THIS IS A NEW PROBE SHAPE AND NOT exist-probe.sh OR tab-probe.sh.
# `exist-probe.sh' scores existence predicates; these three all exist on every
# base, so it has nothing to ask.  `tab-probe.sh' reads constants out of the
# running cc1 through a plugin -- and that plugin runs INSIDE ONE BASE
# SELECTION, so the unselected base's reading comes out of the SELECTED base's
# option storage.  For an option-state macro that is not a blind spot at the
# margin, it is the entire quantity.  So this is the third shape the brief
# predicted would be needed, and it is BEHAVIOURAL: inject the redirect off
# and on in the SAME build dir and compare emitted assembly.
#
# THE DISCRIMINATOR HAD TO BE MEASURED AND IT IS NOT THE OBVIOUS ONE.
# At default options the two configured bases AGREE on all three macros:
#
#     UNITS_PER_WORD     i386 (TARGET_64BIT ? 8 : 4) -> 8    aarch64 8
#     POINTER_SIZE       i386 (TARGET_X32 ? 32 : BITS_PER_WORD) -> 64
#                                                        aarch64 (TARGET_ILP32 ? 32 : 64) -> 64
#     BIGGEST_ALIGNMENT  i386 ... TARGET_AVX ? 256 : 128 -> 128   aarch64 128
#
# so a default-options arm is GREEN WHETHER OR NOT THE REDIRECT IS PRESENT --
# the wrong-reason green PRINCIPLES forbids banking.  The one option that
# separates them is aarch64 `-mabi=ilp32', which makes aarch64's POINTER_SIZE
# 32 while the leaked i386 macro still says 64.  That is what this arm uses,
# and the arm asserts the discriminator actually discriminates (ARM 0) before
# it scores anything.
#
# ARMS
#   ARM 0  non-vacuity: both compilers produce non-empty asm, and the ilp32
#          and lp64 aarch64 outputs DIFFER from each other.  If ilp32 is not
#          supported by this build, that is a FATAL, not a pass -- "the option
#          did nothing" and "the redirect works" are the same picture.
#   ARM A  x86_64 output BYTE-IDENTICAL with the redirect off and on.
#          The primary must not move; this is the project's trusted signal.
#   ARM B  aarch64 -mabi=ilp32 output DIFFERS between redirect off and on.
#          This is the whole content of the change: without it aarch64 is
#          reading i386's POINTER_SIZE.
#   ARM C  restore: every md5 returns to its ARM 0 value, so the injection is
#          shown to be reversible and the build dir is not left poisoned.
#
# The injection edits gcc/defaults.h and ASSERTS IT PRODUCED THE INTENDED
# STATE before building -- per PRINCIPLES, an injection that silently does
# nothing makes every downstream reading a reading of the unmodified compiler.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
# THE BUILD DIR IS NAMED AFTER THE WORKTREE, NOT AFTER A TASK NUMBER, and that
# is a rule paid for rather than a convention.  `/tmp/b<task number>' collides
# BY CONSTRUCTION: task numbers are handed out in neighbouring blocks, so two
# concurrent agents pick adjacent ones and land in the same directory.  This
# task's first build dir was `/tmp/b141' and its configure step -- which begins
# `rm -rf $D' -- destroyed another agent's build underneath it mid-measurement.
# Its guards caught it (its config.log came back naming THIS worktree) and it
# discarded a whole green set.  A worktree name is unique by construction.
D=${1:-/tmp/b-$(basename "$SRC" | sed 's/^agent-//')}
W=${TMPDIR:-/tmp}/t141-arm
rc=0

DEF=$SRC/gcc/defaults.h
BK=$W/defaults.h.orig
MARK='#define UNITS_PER_WORD (mt_units_per_word ())'

rm -rf "$W"; mkdir -p "$W"

# ---- tree and build-dir identity, per PRINCIPLES section 4 ----------------
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$n" -ge 43 ] || { echo "FATAL: wrong tree, anchor=$n"; exit 9; }
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$D/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $D was configured from '$got', not $SRC"; exit 9; }
echo "tree $SRC anchor=$n; build dir $D configured from it OK"

[ -x "$D/gcc/cc1" ] || { echo "FATAL: no $D/gcc/cc1"; exit 9; }
# Two inputs, deliberately.  big.c is the recorded x86_64 codegen bar and must
# stay that file so the byte count is comparable with it.  t141-ptr.c is the
# aarch64 probe: big.c ICEs under -mabi=ilp32 in i386's sync.md (the per-base
# recog blocker, STATE.md #138), which would mask this arm rather than inform
# it.  Both are quoted with every byte count below, per PRINCIPLES section 6 --
# `-S' emits a `.file' directive, so a byte count without its input path is
# evidence about a filename.
BIG=$S/big.c
PTR=$S/t141-ptr.c
[ -s "$BIG" ] || { echo "FATAL: no input $BIG"; exit 9; }
[ -s "$PTR" ] || { echo "FATAL: no input $PTR"; exit 9; }

build () { sh "$S/eb-shell.sh" "cd $D/gcc && make -j8 multi-target-objs cc1" ; }

# Emit assembly by driving cc1 directly, as rv-a64.sh does: the driver would
# drag in specs and a real assembler, and the question here is entirely about
# what cc1 emits.  $1 = tag, $2 = target triple, $3... = extra flags.
# The spec files live in the INSTALL layout, not in $D/gcc: #140 moved them to
# $D/lib/gcc/<ver>/<target>/specs-config, which is where the driver looks with
# no -B.  rv-specs.sh still says `make target-specs' in $D/gcc and is stale --
# that target no longer exists and the top level refuses `all-target-specs' as
# ambiguous, by name, which is the design working.
VER=$(ls "$D/lib/gcc" | sed -n 1p)
cfgfile () { echo "$D/lib/gcc/$VER/$1/specs-config"; }
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  f=$(cfgfile "$t")
  [ -s "$f" ] || { echo "FATAL: no spec file $f -- target-specs SKIPped it"; exit 9; }
  # `non-empty' is not a check: a half-written spec file is non-empty, and a
  # 39-line truncation once poisoned every aarch64 measurement for a day.
  n=$(wc -l < "$f")
  [ "$n" -ge 200 ] || { echo "FATAL: $f has $n lines, expected ~230 -- truncated"; exit 9; }
  echo "spec $t: $n lines OK"
done

# emit <tag> <triple> <input> [flags...]
emit () {
  t=$1; cfg=$2; in=$3; shift 3
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 \
      -ftarget-config="$(cfgfile "$cfg")" "$@" "$in" -o "$W/$t.s" ) \
    > "$W/$t.out" 2> "$W/$t.err"
  echo $?
}
md5of () { md5sum "$W/$1.s" 2>/dev/null | cut -c1-12; }
sz () { wc -c < "$W/$1.s" 2>/dev/null | tr -d ' '; }

X86=x86_64-pc-linux-gnu
A64=aarch64-unknown-linux-gnu

# ==== ARM 0 -- control readings and the non-vacuity gate ===================
echo
echo "=== ARM 0  control (redirect PRESENT), non-vacuity"
r1=$(emit on-x86 "$X86" "$BIG")
r2=$(emit on-a64-lp64 "$A64" "$PTR")
r3=$(emit on-a64-ilp32 "$A64" "$PTR" -mabi=ilp32)
echo "  x86_64  big.c        rc=$r1 bytes=$(sz on-x86)       md5=$(md5of on-x86)"
echo "  a64 lp64  t141-ptr.c rc=$r2 bytes=$(sz on-a64-lp64)  md5=$(md5of on-a64-lp64)"
echo "  a64 ilp32 t141-ptr.c rc=$r3 bytes=$(sz on-a64-ilp32) md5=$(md5of on-a64-ilp32)"
for t in on-x86 on-a64-lp64 on-a64-ilp32; do
  [ -s "$W/$t.s" ] || { echo "FATAL-VACUOUS: $t produced no assembly"; sed -n 1,5p "$W/$t.err"; exit 9; }
done
[ "$(md5of on-a64-ilp32)" != "$(md5of on-a64-lp64)" ] || {
  echo "FATAL-VACUOUS: -mabi=ilp32 changed nothing, so it cannot discriminate"
  exit 9; }
echo "  ilp32 differs from lp64: the discriminator discriminates"

# CONTENT, not just an md5.  With the redirect present, aarch64 -mabi=ilp32
# must lay the struct out at ITS OWN pointer size: sizeof (struct S) == 20,
# emitted as a 4-byte object.  With i386's POINTER_SIZE leaking it is 32/8.
# Asserted by name and value because an md5 that merely differs cannot say
# WHICH answer it is -- and "differs" is satisfied by being wrong in a new way.
if grep -qE '^[[:blank:]]*\.word[[:blank:]]+20$' "$W/on-a64-ilp32.s" \
   && grep -qE '^[[:blank:]]*\.size[[:blank:]]+sz, 4$' "$W/on-a64-ilp32.s"; then
  echo "  ARM 0 CONTENT ok: ilp32 sizeof(struct S)=20 in a 4-byte object"
else
  echo "FATAL: redirect is present but ilp32 did not lay out at 4-byte pointers"
  grep -nE '\.word|\.xword|\.size[[:blank:]]+sz' "$W/on-a64-ilp32.s" | sed 's/^/    /'
  exit 9
fi

# ==== INJECT -- remove the three redirects =================================
echo
echo "=== INJECT  redirect ABSENT"
cp "$DEF" "$BK"
grep -qF "$MARK" "$DEF" || { echo "FATAL: marker absent from $DEF before inject"; exit 9; }
# Neutralise the three #define lines only.  The #undef lines STAY: dropping a
# redirect without the #undef would leave the name UNDEFINED rather than the
# primary's -- a third state nobody is testing (PRINCIPLES section 7).  With
# the #undef kept and the #define replaced by the base macro's own spelling
# restored via tm.h... is not possible, so instead the whole block is cut and
# the primary's tm.h definition is left in force, which IS the pre-change
# state this arm exists to reproduce.
sed -e '/^#undef UNITS_PER_WORD$/d' \
    -e '/^#define UNITS_PER_WORD (mt_units_per_word ())$/d' \
    -e '/^#undef POINTER_SIZE$/d' \
    -e '/^#define POINTER_SIZE (mt_pointer_size ())$/d' \
    -e '/^#undef BIGGEST_ALIGNMENT$/d' \
    -e '/^#define BIGGEST_ALIGNMENT (mt_biggest_alignment ())$/d' \
    "$BK" > "$DEF"
# ASSERT THE INJECTION PRODUCED THE INTENDED STATE, both halves of every hunk.
for m in mt_units_per_word mt_pointer_size mt_biggest_alignment; do
  grep -q "$m ())" "$DEF" && { echo "FATAL: inject left $m redirect in place"; cp "$BK" "$DEF"; exit 9; }
done
d=$(diff "$BK" "$DEF" | grep -c '^<')
[ "$d" -eq 6 ] || { echo "FATAL: inject removed $d lines, expected exactly 6"; cp "$BK" "$DEF"; exit 9; }
echo "  6 lines removed, no mt_ redirect remains"

build > "$W/build-off.log" 2>&1 || { echo "FATAL: build with redirect off failed"; tail -20 "$W/build-off.log"; cp "$BK" "$DEF"; exit 9; }
r1=$(emit off-x86 "$X86" "$BIG")
r3=$(emit off-a64-ilp32 "$A64" "$PTR" -mabi=ilp32)
echo "  x86_64  big.c        rc=$r1 bytes=$(sz off-x86)       md5=$(md5of off-x86)"
echo "  a64 ilp32 t141-ptr.c rc=$r3 bytes=$(sz off-a64-ilp32) md5=$(md5of off-a64-ilp32)"
# NOTE the asymmetry: only the x86_64 side is required to have produced
# assembly.  The aarch64 side is ALLOWED to have failed here, and in fact does
# -- see ARM B.  Requiring output from it would have been a non-vacuity check
# that refuses to score the very state this arm exists to exhibit.
[ -s "$W/off-x86.s" ] || {
  echo "FATAL-VACUOUS: redirect-off build emitted no x86_64 assembly"; cp "$BK" "$DEF"; exit 9; }

# THE WARNING DELTA, because a warning-count change is a finding.  The
# `#undef'-omission bug's ONLY signal was 495 warnings, and these three macros
# change the SIGNEDNESS of expressions all over the middle end: as int-valued
# CONSTANTS they were exempt from -Wsign-compare, as calls they are not.  This
# is the only place the two builds can be compared on equal terms.
won=$(grep -c 'Wsign-compare' "$W/build-back.log" 2>/dev/null || echo n/a)
woff=$(grep -c 'Wsign-compare' "$W/build-off.log" 2>/dev/null || echo 0)
echo "  -Wsign-compare warnings in the redirect-OFF rebuild: $woff"

# ==== ARM A / ARM B =======================================================
echo
if [ "$(md5of on-x86)" = "$(md5of off-x86)" ]; then
  echo "ARM A PASS  x86_64 byte-identical with the redirect off and on ($(md5of on-x86))"
else
  echo "ARM A FAIL  x86_64 MOVED: on=$(md5of on-x86) off=$(md5of off-x86)"; rc=1
fi
# ARM B.  TWO ACCEPTABLE SHAPES FOR THE REDIRECT-OFF STATE, and which one
# occurs was MEASURED rather than predicted.  The arm was first written to
# expect the leaked 8-byte layout -- aarch64 quietly using i386's 64-bit
# POINTER_SIZE.  What actually happens is louder: the compilation ICEs in
#
#     aarch64_function_arg_alignment, at config/aarch64/aarch64.cc:7704
#
# i.e. AARCH64'S OWN code, evaluated in aarch64's own translation unit where
# these names mean aarch64's answers, rejecting the alignment shared code
# computed from I386'S macros.  That is the same one-name-two-authorities
# shape as the `aarch64_can_eliminate' assert, and it is a stronger
# demonstration of the leak than wrong output would have been.
#
# Both shapes are scored PASS because both are "the compiler was wrong without
# the redirect"; what is NOT accepted is a silent third state -- output that
# differs in some way unrelated to pointer size.  PRINCIPLES warns that a
# disappeared ICE must be treated as suspicious until the output is inspected;
# the converse applies here, so the ICE is required to name aarch64's own file
# rather than merely to be an ICE.
if [ "$(md5of on-a64-ilp32)" != "$(md5of off-a64-ilp32)" ]; then
  if grep -qE '^[[:blank:]]*\.size[[:blank:]]+sz, 8$' "$W/off-a64-ilp32.s" 2>/dev/null; then
    echo "ARM B PASS  without the redirect, aarch64 ilp32 emits sz at 8 bytes"
    echo "            i.e. i386's POINTER_SIZE, not aarch64's -- the leak, shown"
  elif grep -q 'internal compiler error.*aarch64_function_arg_alignment' "$W/off-a64-ilp32.err"; then
    echo "ARM B PASS  without the redirect, aarch64 ilp32 ICEs in aarch64's OWN"
    echo "            aarch64_function_arg_alignment (config/aarch64/aarch64.cc):"
    echo "            aarch64 code rejecting an alignment computed from i386's"
    echo "            macros.  With the redirect it compiles and lays out at 20/4."
  else
    echo "ARM B FAIL  it changed, but into neither the leaked layout nor the"
    echo "            aarch64-side ICE -- an unexplained third state:"
    sed -n 1,6p "$W/off-a64-ilp32.err" | sed 's/^/    /'
    rc=1
  fi
else
  echo "ARM B FAIL  aarch64 -mabi=ilp32 IDENTICAL -- the redirect changed nothing"; rc=1
fi

# ==== ARM C -- restore ====================================================
echo
echo "=== ARM C  restore"
cp "$BK" "$DEF"
grep -qF "$MARK" "$DEF" || { echo "FATAL: restore did not put the redirect back"; exit 9; }
build > "$W/build-back.log" 2>&1 || { echo "FATAL: restore build failed"; tail -20 "$W/build-back.log"; exit 9; }
emit back-x86 "$X86" "$BIG" > /dev/null
emit back-a64-ilp32 "$A64" "$PTR" -mabi=ilp32 > /dev/null
ok=1
[ "$(md5of back-x86)" = "$(md5of on-x86)" ] || { echo "ARM C FAIL x86_64 did not return"; ok=0; }
[ "$(md5of back-a64-ilp32)" = "$(md5of on-a64-ilp32)" ] || { echo "ARM C FAIL aarch64 did not return"; ok=0; }
[ "$ok" = 1 ] && echo "ARM C PASS  both md5s returned to their ARM 0 values" || rc=1
won=$(grep -c 'Wsign-compare' "$W/build-back.log" 2>/dev/null || echo 0)
echo "  -Wsign-compare in redirect-ON rebuild: $won   vs OFF: $woff"
echo "  (both are partial rebuilds of the same object set, so the DELTA is the"
echo "   quantity; an absolute count here is not comparable with a cold build)"

echo
echo "OVERALL rc=$rc"
exit $rc
