#!/bin/sh
# TASK #113 GUARDS -- five arms, seven scored checks: five affirmative and two
# injections that must make an affirmative arm go red.
#
# TAB-SHAPED, NOT HEADER-SHAPED.  Arms 1 and 2 read the RUNNING `cc1' with a
# base actually selected; arms 3-5 read the OBJECTS the running cc1 is made
# of.  A header probe would ask the preprocessor what `MOVE_RATIO' expands to,
# get `(mt_move_ratio (...))' on both sides, and score green while proving
# only that a `#define' exists -- PRINCIPLES 6's wrong-reason flip, and the
# vacuous shape #108 refused.
#
# BOTH-SIDED THROUGHOUT.  Showing aarch64 gets aarch64's move ratio proves
# nothing unless x86_64 still gets i386's; a change that gave EVERY target the
# same new answer would pass a one-sided arm.
#
# WHAT EACH ARM WOULD HAVE TO SEE TO FAIL:
#   1  the two bases' tables holding the same move_max / move_ratio /
#      data_alignment, or the same answer to "do you define DATA_ABI_ALIGNMENT"
#   2  `int x = 1;' not compiling, or compiling to the wrong architecture
#   3  a shared object still naming ix86_cost / ix86_move_max /
#      ix86_data_alignment
#   4  (INJECTION) the redirect removed from defaults.h and arm 3 STILL green
#      -- which would mean arm 3 was never reading anything
#   5  (INJECTION) the two per-base supply objects being interchangeable
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098
D=${D:-/tmp/b113}
O=${O:-/tmp/t113-guards}
rm -rf "$O"; mkdir -p "$O"
pass=0; fail=0
ok   () { echo "  PASS  $*"; pass=$((pass+1)); }
bad  () { echo "  FAIL  $*"; fail=$((fail+1)); }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
printf 'int x = 1;\n' > "$O/tiny.c"

nm_ () {
  nix-shell -I "nixpkgs=$NP" -p binutils --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && nm -uC $*"
}
gdb_ () {
  nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && gdb -batch -x $1 ./cc1"
}

# ---------------------------------------------------------------- ARM 1
# The two bases' frame tables, read out of the RUNNING cc1 after selection.
#
# `targetm_frame' is a pointer to the selected base's `target_frame_desc'.
# The tree is built -g0 so there is no DWARF and `p targetm_frame->move_max'
# cannot work; the fields are read as raw words and the function pointers are
# resolved with `info symbol', which uses the minimal symbol table.  That also
# makes the arm say WHICH base's thunk is installed, by name, rather than only
# that some number differs.
echo "ARM 1: the running cc1's targetm_frame, per selected base (both-sided)"
#
# The struct layout is not guessed: the raw words are DUMPED as well as
# indexed, so a wrong offset shows up as a nonsense value in the log rather
# than as a silently green arm.  On this host every member is 8-byte aligned,
# giving word 0 = name, 9 = move_max, 13 = move_ratio, 17 = data_alignment.
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  cat > "$O/f-$t.gdb" <<EOF
set pagination off
set confirm off
break varpool_node::analyze
run -quiet -nostdinc -O2 -ftarget-config=specs-$t-config $O/tiny.c -o $O/o-$t.s
printf "TABLE %s\n", ((char**)targetm_frame)[0]
echo RAWDUMP\n
x/20gx ((void**)targetm_frame)
printf "MOVE_MAX_THUNK %p\n", ((void**)targetm_frame)[9]
printf "MOVE_RATIO_THUNK %p\n", ((void**)targetm_frame)[13]
printf "DATA_ALIGNMENT_THUNK %p\n", ((void**)targetm_frame)[17]
printf "DATA_ABI_ALIGNMENT_THUNK %p\n", ((void**)targetm_frame)[19]
EOF
  gdb_ "$O/f-$t.gdb" > "$O/f-$t.log" 2> "$O/f-$t.err"
  grep -q 'TABLE' "$O/f-$t.log" \
    || { bad "arm1 $t: gdb never reached the breakpoint -- NOT a green"; continue; }
  grep -E 'TABLE|_THUNK' "$O/f-$t.log" | sed "s/^/    $t  /"
done
L1=$O/f-x86_64-pc-linux-gnu.log; L2=$O/f-aarch64-unknown-linux-gnu.log
if [ ! -s "$L1" ] || [ ! -s "$L2" ]; then
  bad "arm1: one of the two runs produced no log -- refusing to score"
else
  d=0
  # DATA_ALIGNMENT is in the DIFFER list, not the asymmetry list, and finding
  # that out was itself a result: this arm was written expecting aarch64 to
  # define no DATA_ALIGNMENT and it FAILED.  aarch64.h:133 defines it as
  # `aarch64_data_alignment (EXP, ALIGN)'.  So the old `#ifdef' in varasm.cc
  # was not merely importing i386's presence into a back end that wanted
  # none -- it was calling i386's function INSTEAD OF aarch64's own, which is
  # a wrong VALUE and not only a wrongly-taken branch.  The guard was wrong
  # and the code was right; corrected here rather than by relaxing the check.
  for k in TABLE MOVE_MAX_THUNK MOVE_RATIO_THUNK DATA_ALIGNMENT_THUNK; do
    a=$(grep "^$k " "$L1" | head -1); b=$(grep "^$k " "$L2" | head -1)
    if [ -z "$a" ] || [ -z "$b" ]; then
      bad "arm1: $k missing from a log -- instrument failure, not a result"; d=1
    elif [ "$a" = "$b" ]; then
      bad "arm1: $k is IDENTICAL across the two bases ($a)"; d=1
    fi
  done
  # DATA_ABI_ALIGNMENT is where the asymmetry actually lives, and it is the
  # half of the evidence that a "both bases got the same new answer" change
  # could not fake: i386.h:900 defines it, only five back ends do at all, and
  # aarch64 is not one -- so its slot MUST be null while i386's must not.  A
  # null on both sides would mean nobody supplies it; a thunk on both sides
  # would mean the existence question is still being answered once for
  # everyone, which is the bug.
  x=$(grep '^DATA_ABI_ALIGNMENT_THUNK ' "$L1" | head -1)
  y=$(grep '^DATA_ABI_ALIGNMENT_THUNK ' "$L2" | head -1)
  case "$y" in
    *' 0x0'|*' (nil)') : ;;
    '') bad "arm1: DATA_ABI_ALIGNMENT_THUNK missing from the aarch64 log"; d=1 ;;
    *) bad "arm1: aarch64 supplies a DATA_ABI_ALIGNMENT thunk ($y); it defines no such macro"; d=1 ;;
  esac
  case "$x" in
    *' 0x0'|*' (nil)') bad "arm1: i386 supplies NO DATA_ABI_ALIGNMENT thunk, but i386.h:900 defines it"; d=1 ;;
    '') bad "arm1: DATA_ABI_ALIGNMENT_THUNK missing from the i386 log"; d=1 ;;
    *) : ;;
  esac
  [ "$d" = 0 ] && ok "arm1: different tables, different move/data-alignment thunks, and opposite DATA_ABI_ALIGNMENT answers"
fi

# ---------------------------------------------------------------- ARM 2
# The wall this task moved.  `int x = 1;' died in ix86_data_alignment for
# aarch64 before this change (gdb-confirmed, scratchpad/t113-align-diag.sh).
# Scored on rc AND on the architecture actually emitted, because an rc=0 that
# emitted x86 assembly for aarch64 would be a worse result than the ICE.
echo "ARM 2: 'int x = 1;' compiles for BOTH bases, to each one's own assembly"
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="specs-$t-config" \
     "$O/tiny.c" -o "$O/a2-$t.s") > "$O/a2-$t.log" 2>&1
  rc=$?
  [ "$rc" = 0 ] || { bad "arm2 $t: rc=$rc"; continue; }
  [ -s "$O/a2-$t.s" ] || { bad "arm2 $t: rc=0 but empty .s"; continue; }
  case $t in
    aarch64*) if grep -q '\.arch[ 	]*armv8' "$O/a2-$t.s" && grep -q '^	\.word' "$O/a2-$t.s"
              then ok "arm2 $t: rc=0 and the output is genuinely aarch64"
              else bad "arm2 $t: rc=0 but the assembly is not aarch64"; fi ;;
    x86_64*)  if grep -q '^	\.long' "$O/a2-$t.s" && ! grep -q 'armv8' "$O/a2-$t.s"
              then ok "arm2 $t: rc=0 and the output is genuinely x86"
              else bad "arm2 $t: rc=0 but the assembly is not x86"; fi ;;
  esac
done

# ---------------------------------------------------------------- ARM 3
# Object level.  The shared TUs that spelled the ten converted macros must now
# reference the `mt_' entry points and must NOT reference the three i386
# symbols those macros used to drag in.
#
# `nm -uC' with an ANCHORED pattern, per PRINCIPLES 7: a plain `grep ix86_'
# scores the same as `nm -u' because a mangled name CONTAINS the substring,
# and the zero would then be a claim about the pattern rather than the code.
SHARED="tree-inline.o expr.o varasm.o gimplify.o targhooks.o tree-sra.o
        caller-save.o gimple-fold.o gimple-ssa-store-merging.o cp/rtti.o"
echo "ARM 3: shared objects name the mt_ entry points, not i386's state"
nm_ $SHARED > "$O/shared.nm" 2> "$O/shared.nm.err"
[ -s "$O/shared.nm" ] || { echo "FATAL: nm produced nothing"; cat "$O/shared.nm.err"; exit 9; }
gone=0
for s in ix86_cost ix86_move_max ix86_data_alignment; do
  if grep -qE "^ +U $s\b|^ +U $s\(" "$O/shared.nm"; then
    bad "arm3: $s is STILL referenced from shared code"; gone=1
  fi
done
[ "$gone" = 0 ] && ok "arm3: none of ix86_cost / ix86_move_max / ix86_data_alignment"
# NON-VACUITY: an empty or unreadable nm would satisfy the above trivially.
nmt=$(grep -cE '^ +U mt_(move|clear|set|store|compare|data)' "$O/shared.nm")
if [ "$nmt" -ge 8 ]; then
  ok "arm3: $nmt mt_ references present, so the instrument did read something"
else
  bad "arm3: only $nmt mt_ references -- refusing to score the absence above"
fi

# ---------------------------------------------------------------- ARM 4
# THE INJECTION.  Remove the MOVE_MAX/MOVE_RATIO redirects from defaults.h,
# rebuild ONE shared object, and require ix86_cost to come BACK.  If it does
# not, arm 3 was not reading what it claims to read and its green is worthless.
echo "ARM 4 (INJECTION): with the redirect removed, ix86_cost must RETURN"
cp "$W/gcc/defaults.h" "$O/defaults.h.orig"
awk '/^#define MOVE_RATIO\(SPEED\) \(mt_move_ratio/ { print "#define MOVE_RATIO(SPEED) ((SPEED) ? ix86_cost->move_ratio : 3)"; next } { print }' \
    "$O/defaults.h.orig" > "$O/defaults.h.poisoned"
if cmp -s "$O/defaults.h.orig" "$O/defaults.h.poisoned"; then
  bad "arm4: the injection changed nothing -- the line it targets is not there"
else
  cp "$O/defaults.h.poisoned" "$W/gcc/defaults.h"
  rm -f "$D/gcc/tree-inline.o"
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && make tree-inline.o" > "$O/inj.log" 2> "$O/inj.err"
  irc=$?
  cp "$O/defaults.h.orig" "$W/gcc/defaults.h"
  if [ "$irc" != 0 ]; then
    bad "arm4: poisoned build failed to compile (rc=$irc) -- inconclusive, see $O/inj.err"
  else
    nm_ tree-inline.o > "$O/inj.nm" 2>&1
    if grep -qE '^ +U ix86_cost\b' "$O/inj.nm"; then
      ok "arm4: ix86_cost reappears when the redirect is removed -- arm 3 can fail"
    else
      bad "arm4: ix86_cost did NOT reappear -- arm 3 proves nothing"
    fi
  fi
  # Restore the real object so the build dir is not left poisoned.
  rm -f "$D/gcc/tree-inline.o"
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo \
    --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && make tree-inline.o" > "$O/restore.log" 2> "$O/restore.err"
  nm_ tree-inline.o > "$O/restore.nm" 2> "$O/restore.nm.err"
  if grep -qE '^ +U ix86_cost\b' "$O/restore.nm"; then
    bad "arm4: FAILED TO RESTORE -- $D/gcc/tree-inline.o is still poisoned"
  elif grep -qE '^ +U mt_move_ratio' "$O/restore.nm"; then
    echo "    (restored: tree-inline.o rebuilt clean, mt_move_ratio back)"
  else
    bad "arm4: after restore tree-inline.o names NEITHER symbol -- object is wrong"
  fi
fi

# ---------------------------------------------------------------- ARM 5
# The two SUPPLY objects must not be interchangeable: each is compiled with
# `-I<base>-inc' precisely so its macro expansions are that base's.  If they
# were identical the whole per-base mechanism would be decoration.
echo "ARM 5: the two per-base supply objects differ"
m1=$(md5sum "$D/gcc/target-cumargs-i386.o" 2>/dev/null | cut -d' ' -f1)
m2=$(md5sum "$D/gcc/target-cumargs-aarch64.o" 2>/dev/null | cut -d' ' -f1)
if [ -z "$m1" ] || [ -z "$m2" ]; then
  bad "arm5: one of the per-base cumargs objects does not exist"
elif [ "$m1" = "$m2" ]; then
  bad "arm5: the two per-base objects are byte-identical"
else
  ok "arm5: distinct per-base objects ($m1 vs $m2)"
fi

echo
echo "t113-guards: $pass PASS / $fail FAIL"
[ "$fail" = 0 ]
