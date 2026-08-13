#!/bin/sh
# TASK #113 -- ARM E, RE-FILTERED.  Supersedes t113-armE.sh's headline 40.
#
# #112 reported 40 as an UPPER BOUND WITH KNOWN CONTAMINATION and said so.
# This script says exactly what the contamination is and removes it with two
# filters, each of which reports what it dropped so the drop is auditable.
#
#   FILTER M (machinery).  A "hit" is a shared TU that SPELLS the macro name.
#     The conversion machinery spells every macro it has already converted --
#     `target-cdata.h' lists STORE_MAX_PIECES and MOVE_MAX in a comment
#     recording that they are NOT invariant; `target-cumargs.h' names
#     OVERRIDE_ABI_FORMAT because it converted it; `defaults.h' names all of
#     them because that is where the `#ifndef' floors and the mt_ redirects
#     live.  None of those is a leak; they are the fix, mentioning the bug.
#     A macro whose ONLY shared spellings are machinery is dropped.
#
#   FILTER P (preprocessor).  THE ONE THAT SETTLES MEMBERSHIP.  #112's own
#     trap 3 and the INIT_ARRAY_SECTION_ASM_OP correction both say the text
#     sweep is not the authority.  Here the question is not "does i386.h
#     define this reading ix86_ state" but "IS THAT THE DEFINITION IN FORCE
#     WHERE SHARED CODE SPELLS IT".  It is not, for every macro already
#     converted: defaults.h now redirects the name to an `mt_' call, so the
#     in-force definition names no back-end state at all.  Asked with `-dM'
#     in a real shared TU's include context, i.e. of the actual preprocessor.
#
#   FILTER L (linker).  THE FINAL AUTHORITY, AND ADDED BECAUSE FILTER P WAS
#     NOT ENOUGH.  Filters M and P are still text: they read the macro's name
#     and the macro's definition.  Two macros converted by this very task --
#     DATA_ALIGNMENT and DATA_ABI_ALIGNMENT -- survive both, because they were
#     converted by DELETING THEIR `#ifdef' CALL SITES rather than by
#     redirecting the name, and the replacement code carries comments that
#     still spell the macro.  The text sweep sees the comment; the linker does
#     not.  So the last filter asks `nm -uC' whether each macro's i386 symbol
#     is still UNDEFINED-AND-REFERENCED from any shared object.  If nothing
#     shared needs it, no shared code can be calling it, whatever the text
#     says.  This is PRINCIPLES 4 rule 1 in its general form: ask the
#     artefact.  Note the direction of its blind spot -- a macro whose
#     expansion folds to a constant with no symbol, or whose i386 symbol is
#     also referenced by some unrelated shared TU, is NOT dropped.  So filter
#     L can only shrink a genuine over-count -- EXCEPT for one class it gets
#     WRONG in the other direction: a macro reading an `i386.opt Var()' reads
#     `global_options.x_...' and emits NO ix86_ symbol at all.  Four macros
#     were dropped that way before the exception below existed.  See it.
#
#   RANKING, AND WHAT IT CANNOT DO.  Of the survivors, split by what the
#     in-force expansion DOES with the state it reaches:
#       LOUD   -- the macro body dereferences a back-end pointer that is NULL
#                 until that back end's option-override runs.  Faults, so we
#                 find out.
#       QUIET  -- the macro body reads a back-end scalar with a benign
#                 initialiser.  Answers with the primary's tuning for every
#                 target and emits wrong code with no diagnostic.
#       UNRANK -- the macro CALLS an i386 function.  NOT rankable from here,
#                 and DATA_ALIGNMENT is exactly why: its body dereferences
#                 nothing, so a body-reading classifier called it QUIET, and
#                 it ICEs on `int x = 1;' because `ix86_data_alignment' reads
#                 `ix86_tune_cost->prefetch_block' two levels down.  An
#                 UNRANK row is UNMEASURED, not safe.
#     Decided by looking each referenced symbol up in i386-protos.h and
#     config/i386/*.cc, not by eye.
#
# BLIND SPOTS (PRINCIPLES 4 rule 5):
#   * Inherits t113-armE.sh's: text-only discovery of the candidate set, so a
#     macro reaching back-end state through a helper FUNCTION is invisible,
#     and a two-step chain through defaults.h is missed on the discovery side
#     (MOVE_MAX_PIECES and COMPARE_MAX_PIECES are exactly that -- i386.h does
#     not define them, defaults.h derives them from MOVE_MAX -- so they are
#     ADDED BY HAND below and the script asserts they were).  So the filtered
#     number is a LOWER bound on the problem and an UPPER bound only on what
#     this instrument can see.
#   * Filter M is a NAME LIST.  If the machinery grows a file, this list goes
#     stale in the direction that flatters us, so every name on it must exist.
#   * LOUD/QUIET is decided from the initialiser, not from a run.  A QUIET
#     macro that no test exercises is UNMEASURED, not absent.
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a8e4f809d46e47098
G=$W/gcc
D=${D:-/tmp/b113}
O=${O:-/tmp/t113-armE2}
E=${E:-/tmp/t113-armE}
rm -rf "$O"; mkdir -p "$O"
[ -s "$E/hits.txt" ] || { echo "FATAL: run t113-armE.sh first (no $E/hits.txt)"; exit 9; }
[ -f "$D/gcc/tm.h" ] || { echo "FATAL: no $D/gcc/tm.h -- build first"; exit 9; }

raw=$(grep -c . "$E/hits.txt")
echo "arm E raw (t113-armE.sh):            $raw"

# ---------------------------------------------------------------- FILTER M
# Files that are the conversion machinery or the macro-definition floor,
# never a use site.
cat > "$O/machinery.txt" <<'EOF'
defaults.h
target-cdata.h
target-caps.h
target-c-ops.h
target-c-ops-select.cc
target-cumargs.h
target-frame.h
target-insn.h
target-regs.h
target-addr.h
target-asm-ops.h
multi-target-select.cc
genconditions.cc
EOF
while read -r f; do
  [ -e "$G/$f" ] || { echo "FATAL: machinery list names missing file $f"; exit 9; }
done < "$O/machinery.txt"

: > "$O/afterM.txt"
: > "$O/droppedM.txt"
while IFS="$(printf '\t')" read -r m c tus; do
  keep=
  for t in $tus; do
    b=$(basename "$t")
    grep -qx "$b" "$O/machinery.txt" && continue
    keep="$keep $t"
  done
  if [ -n "$keep" ]; then
    printf '%s\t%s\n' "$m" "$(echo $keep)" >> "$O/afterM.txt"
  else
    printf '%s\t%s\n' "$m" "$tus" >> "$O/droppedM.txt"
  fi
done < "$E/hits.txt"
echo "after FILTER M (machinery-only drop): $(grep -c . "$O/afterM.txt")   dropped $(grep -c . "$O/droppedM.txt")"

# ---------------------------------------------------------------- add the
# two-step chain members the discovery sweep structurally cannot see.
for m in MOVE_MAX_PIECES COMPARE_MAX_PIECES; do
  grep -q "^$m	" "$O/afterM.txt" && { echo "FATAL: $m already present -- the hand-add is stale"; exit 9; }
  grep -q "^#define $m" "$G/defaults.h" \
    || { echo "FATAL: $m is not derived in defaults.h -- hand-add unjustified"; exit 9; }
  printf '%s\t%s\n' "$m" "(via defaults.h from MOVE_MAX)" >> "$O/afterM.txt"
done

# ---------------------------------------------------------------- FILTER P
# What is the definition IN FORCE in a shared TU?  Ask the preprocessor.
cat > "$O/probe.cc" <<'EOF'
#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "tm.h"
EOF
INC="-I. -I$G -I$G/. -I$G/../include -I$G/../libcpp/include -I$G/../libcody -I$G/../libdecnumber -I$G/../libdecnumber/bid -I../libdecnumber -I$G/../libbacktrace"
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
nix-shell -I "nixpkgs=$NP" -p gcc gnumake gmp.dev mpfr.dev libmpc --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && g++ -E -dM -DIN_GCC -DHAVE_CONFIG_H $INC $O/probe.cc" \
  > "$O/dM.txt" 2> "$O/dM.err"
[ -s "$O/dM.txt" ] || { echo "FATAL: -dM produced nothing; see $O/dM.err"; sed -n 1,20p "$O/dM.err"; exit 9; }
grep -q '^#define MOVE_RATIO' "$O/dM.txt" \
  || { echo "FATAL: -dM has no MOVE_RATIO at all -- instrument wrong"; exit 9; }

# TRANSITIVE.  `-dM' prints an UNEXPANDED body, so `MOVE_MAX_PIECES MOVE_MAX'
# names no back-end state on its face while being exactly the silent sibling
# this whole task is about.  Chase the body through the other definitions in
# force until it stops growing.  Cycle-guarded and depth-limited: an
# unguarded chase on this macro set does not terminate (Pmode, defaults.h).
expand () {
  cur=$(grep "^#define $1\([( ]\)" "$O/dM.txt" | head -1 | sed 's/^#define [^ (]*//')
  [ -n "$cur" ] || return 1
  seen=" $1 "
  d=0
  while [ $d -lt 12 ]; do
    d=$((d+1))
    nxt=$cur
    for id in $(echo "$cur" | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*\b' | sort -u); do
      case $seen in *" $id "*) continue;; esac
      body=$(grep "^#define $id\([( ]\)" "$O/dM.txt" | head -1 | sed 's/^#define [^ (]*//')
      [ -n "$body" ] || continue
      seen="$seen$id "
      nxt="$nxt $body"
    done
    [ "$nxt" = "$cur" ] && break
    cur=$nxt
  done
  printf '%s' "$cur"
}

: > "$O/leaks.txt"
: > "$O/droppedP.txt"
while IFS="$(printf '\t')" read -r m tus; do
  if ! full=$(expand "$m"); then
    printf '%s\tNOT-DEFINED-IN-SHARED-CONTEXT\t%s\n' "$m" "$tus" >> "$O/droppedP.txt"
    continue
  fi
  def=$(grep "^#define $m\([( ]\)" "$O/dM.txt" | head -1)
  if echo "$full" | grep -qE 'ix86_|ia32_'; then
    if echo "$def" | grep -qE 'ix86_|ia32_'; then how=direct; else how=transitive; fi
    printf '%s\t%s\t%s\t%s\n' "$m" "$full" "$how" "$tus" >> "$O/leaks.txt"
  else
    printf '%s\t%s\t%s\n' "$m" "$def" "$tus" >> "$O/droppedP.txt"
  fi
done < "$O/afterM.txt"
echo "after FILTER P (in-force def reads back-end state): $(grep -c . "$O/leaks.txt")   dropped $(grep -c . "$O/droppedP.txt")"

# NON-VACUITY, IN THE ONLY FORM THAT SURVIVES ITS OWN FIX.
#
# The first version of this check simply required MOVE_RATIO and MOVE_MAX to
# be in `leaks.txt', because both were gdb-confirmed leaks when it was
# written.  It then FIRED the moment this task converted them -- correctly, as
# an instrument, and uselessly, as an assertion.  Weakening it to "MOVE_RATIO
# may be absent" would have been the test-harness floor: the check would no
# longer distinguish "converted" from "the filter dropped it by accident",
# which is exactly the case it exists for.
#
# So the check is now on the DISPOSITION rather than on membership: each of
# the two must be accounted for as EITHER a leak OR converted (its in-force
# definition naming an `mt_' entry point).  Anything else -- silently missing,
# or defined as something that is neither -- still refuses to score.
for m in MOVE_RATIO MOVE_MAX; do
  if grep -q "^$m	" "$O/leaks.txt"; then
    echo "non-vacuity: $m accounted for as UNCONVERTED LEAK"
  elif grep "^$m	" "$O/droppedP.txt" | grep -q 'mt_'; then
    echo "non-vacuity: $m accounted for as CONVERTED (redirected to an mt_ call)"
  else
    echo "FATAL: $m is neither a leak nor converted; the filter has lost it."
    grep "^$m	" "$O/droppedP.txt" "$O/droppedM.txt" || echo "  (not in either dropped list)"
    exit 9
  fi
done

# ---------------------------------------------------------------- RANK
# For every ix86_/ia32_ symbol the in-force definition names, find its
# DEFINITION in config/i386/*.cc and decide whether a null deref is possible.
# ---------------------------------------------------------------- FILTER L
# Every ix86_/ia32_ symbol still UNDEFINED in a SHARED object.  Per-base and
# back-end objects are excluded by name: they are compiled FOR i386 and are
# supposed to reference i386.
NP2="$HOME/src/nixos-configuration/dep/nixpkgs"
# SUBDIRECTORIES MUST BE INCLUDED.  `cp/rtti.o' is one of the objects this
# task changed, and a top-level `*.o' glob misses it -- and every c/, cp/,
# analyzer/, common/ and lto/ object with it.  Missing shared objects make
# filter L drop MORE than it should, i.e. they flatter the result, which is
# the direction that must never be left to chance.  `mt-*/' is the per-base
# tree and `build/' is the generators, both single-target by construction.
find "$D/gcc" -name '*.o' -print \
  | grep -vE "^$D/gcc/(mt-[^/]*|build)/" \
  | grep -vE '/[^/]*(i386|aarch64)[^/]*\.o$' \
  | grep -vE '/insn-(emit|output)-' \
  | sort > "$O/shared-objs.txt"
no=$(grep -c . "$O/shared-objs.txt")
[ "$no" -gt 100 ] || { echo "FATAL: only $no shared objects -- object list is wrong"; exit 9; }
sub=$(grep -cE "^$D/gcc/[a-z-]+/" "$O/shared-objs.txt")
[ "$sub" -gt 10 ] \
  || { echo "FATAL: only $sub subdirectory objects -- the find is not descending"; exit 9; }
# STATED BLIND SPOT, not an assertion: this build dir is
# `--enable-languages=c,lto', so `cp/rtti.o' does not exist and filter L
# cannot see the C++ front end at all.  `cp/rtti.cc' is one of the five
# DATA_ABI_ALIGNMENT sites, so its conversion is verified by reading the
# source and by the build succeeding, NOT by this filter.
if [ ! -f "$D/gcc/cp/rtti.o" ]; then
  echo "NOTE: cp/rtti.o absent (c,lto build) -- filter L is blind to the C++ front end"
fi
nix-shell -I "nixpkgs=$NP2" -p binutils --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && nm -uC \$(cat $O/shared-objs.txt)" > "$O/shared.nm" 2> "$O/shared.nm.err"
grep -oE '\b(ix86|ia32)_[A-Za-z0-9_]*' "$O/shared.nm" | sort -u > "$O/live-syms.txt"
nl=$(grep -c . "$O/live-syms.txt")
[ "$nl" -gt 0 ] || { echo "FATAL: nm found no ix86_ symbols at all in $no shared objects -- instrument broken"; exit 9; }
echo "shared objects scanned: $no; distinct ix86_/ia32_ symbols they still need: $nl"

: > "$O/leaks2.txt"
: > "$O/droppedL.txt"
rm -f "$O/keptL-optvar.txt"
while IFS="$(printf '\t')" read -r m full how tus; do
  syms=$(echo "$full" | grep -oE '\b(ix86|ia32)_[A-Za-z0-9_]*' | sort -u)
  live=no
  for s in $syms; do
    grep -qx "$s" "$O/live-syms.txt" && live=yes
  done
  # THE EXCEPTION THAT MAKES FILTER L SOUND, AND THE REASON IT NEEDED ONE.
  #
  # `ASSEMBLER_DIALECT' is `(ix86_asm_dialect)', and `i386.opt:269' declares
  # that as `Var(ix86_asm_dialect)' -- which is a `#define' onto
  # `global_options.x_ix86_asm_dialect', NOT a symbol.  Shared code reading it
  # therefore emits NO undefined `ix86_' reference at all, and filter L scores
  # it clean while the leak is entirely real: i386's option variable is
  # answering for aarch64 exactly as `ix86_move_max' was.
  #
  # Four macros were dropped this way before the exception existed
  # (ASSEMBLER_DIALECT, BRANCH_COST, CASE_VECTOR_MODE,
  # OPTIMIZE_MODE_SWITCHING).  So filter L's error is NOT one-directional
  # after all, and the header's earlier claim that it "can only shrink a
  # genuine over-count" was wrong -- recorded here rather than quietly fixed,
  # because the wrong claim is the more instructive half.
  opt=no
  for s in $syms; do
    grep -qE "Var\($s\)" "$G/config/i386/i386.opt" && opt=yes
  done
  if [ "$live" = yes ]; then
    printf '%s\t%s\t%s\t%s\n' "$m" "$full" "$how" "$tus" >> "$O/leaks2.txt"
  elif [ "$opt" = yes ]; then
    printf '%s\t%s\t%s\t%s\n' "$m" "$full" "$how(opt-var)" "$tus" >> "$O/leaks2.txt"
    printf '%s\t%s\n' "$m" "$syms" >> "$O/keptL-optvar.txt"
  else
    printf '%s\t%s\n' "$m" "$syms" >> "$O/droppedL.txt"
  fi
done < "$O/leaks.txt"
[ -f "$O/keptL-optvar.txt" ] && \
  echo "  filter L exception: $(grep -c . "$O/keptL-optvar.txt") macro(s) kept because the state is an i386.opt Var(), which has no symbol for nm to see"
mv "$O/leaks2.txt" "$O/leaks.txt"
echo "after FILTER L (i386 symbol still needed by shared code): $(grep -c . "$O/leaks.txt")   dropped $(grep -c . "$O/droppedL.txt")"

#
# KIND is the second axis and it matters as much as LOUD/QUIET.  The brief's
# arm E is specifically "a DEREFERENCE OF BACK-END MUTABLE STATE".  A macro
# that CALLS an i386 function is also the primary answering for everyone, but
# it is the older, already-named leak, and it cannot fault on uninitialised
# state.  Decided by whether i386-protos.h declares the symbol as a function.
echo
printf '%-26s %-6s %-6s %-10s %s\n' MACRO CLASS KIND REACHED 'ix86_ SYMBOL'
: > "$O/rank.txt"
while IFS="$(printf '\t')" read -r m full how tus; do
  syms=$(echo "$full" | grep -oE '\b(ix86|ia32)_[A-Za-z0-9_]*' | sort -u)
  cls=QUIET; kind=FUNC; note=
  for s in $syms; do
    if grep -qE "\b$s *\(" "$G/config/i386/i386-protos.h"; then
      note="$note $s()"
      # A CALL CANNOT BE RANKED FROM HERE, AND SAYING SO IS THE POINT.
      # `DATA_ALIGNMENT' is `ix86_data_alignment (TYPE, ALIGN, true)': the
      # macro body dereferences nothing, so a body-reading classifier calls
      # it QUIET.  It is LOUD -- gdb-confirmed on `int x = 1;', si_addr
      # 0x190, `ix86_tune_cost' null (scratchpad/t113-align-diag.sh) --
      # because the FUNCTION reads uninitialised state two levels down.
      # Ranking these would need an interprocedural pass or a run; this
      # instrument has neither, so they are UNRANKED rather than assumed
      # safe.  An unranked one is UNMEASURED, not absent, and by the
      # standing argument the unmeasured ones are where the risk is.
      cls=UNRANK
      continue
    fi
    kind=STATE
    # A pointer variable: the deref faults while it is still null.
    if grep -hE "^[A-Za-z_][A-Za-z0-9_ ]*\*+ *$s\b" "$G"/config/i386/*.cc "$G"/config/i386/*.h \
       | head -1 | grep -q .; then
      cls=LOUD; note="$note $s(ptr)"
    else
      note="$note $s"
    fi
  done
  [ -n "$syms" ] || note=" (derived)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$m" "$cls" "$kind" "$how" "$note" >> "$O/rank.txt"
  printf '%-26s %-6s %-6s %-10s %s\n' "$m" "$cls" "$kind" "$how" "$note"
done < "$O/leaks.txt"

echo
echo "LOUD   (macro body derefs a null back-end pointer -- crashes)   : $(cut -f2 "$O/rank.txt" | grep -c '^LOUD$')"
echo "QUIET  (macro body reads a benign scalar -- silently i386's)   : $(cut -f2 "$O/rank.txt" | grep -c '^QUIET$')"
echo "UNRANK (macro CALLS an i386 function -- cannot be ranked here) : $(cut -f2 "$O/rank.txt" | grep -c '^UNRANK$')"
echo
echo "  KIND=STATE (arm E proper: the macro itself reads back-end state): $(awk -F'\t' '$3=="STATE"' "$O/rank.txt" | grep -c .)"
echo "  KIND=FUNC  (the macro dispatches to an i386 function)          : $(awk -F'\t' '$3=="FUNC"' "$O/rank.txt" | grep -c .)"
echo
echo "READ THE UNRANK LINE AS RISK, NOT AS SAFETY.  DATA_ALIGNMENT sat in that"
echo "column and turned out to fault on 'int x = 1;'.  The LOUD count is the"
echo "count of leaks that ANNOUNCE themselves; everything else is either known"
echo "to be silent or not known at all, and both need converting."
echo
echo "=== FILTER M dropped (machinery-only spellings) ==="
cat "$O/droppedM.txt"
echo "=== FILTER P dropped (in-force definition names no back-end state) ==="
cat "$O/droppedP.txt"
