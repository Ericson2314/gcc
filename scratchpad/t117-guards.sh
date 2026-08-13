#!/bin/sh
# TASK #117 GUARDS -- the optab selection and the NUM_OPTAB_PATTERNS union.
#
# Seven arms.  Five affirmative, two INJECTIONS that remove something the fix
# relies on and require the old symptom back.  An injection that does not fire
# is a finding, not a pass, so each one asserts on the CONTENT of what comes
# back rather than merely on a non-zero exit.
#
# INSTRUMENT NOTES
#   * `grep -q' is not used.  Under a pipeline it exits 141 on SIGPIPE, which
#     scores a match as a miss.  Everything counts lines.
#   * Symbol matching is EXACT on the demangled name.  Substring matching
#     counts `selected_raw_optab_handler' as `raw_optab_handler' and turns the
#     subject of arm 2 from 0 into 51.
#   * `nm' is asserted present before any arm is scored: a missing tool piped
#     into a counter scores 0, which here would read as "no leak".
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
SRCD=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a75a2f51f92af9802
D=${D:-/tmp/b117}
G="$D/gcc"
pass=0; fail=0
ok   () { echo "PASS  $*"; pass=$((pass+1)); }
bad  () { echo "FAIL  $*"; fail=$((fail+1)); }

command -v nm > /dev/null || { echo "FATAL: nm not on PATH; run under the nix-shell"; exit 9; }
[ -x "$G/cc1" ] || { echo "FATAL: no cc1 in $G"; exit 9; }

echo "=== ARM 1  the union list exists, names every base, and is WIRED UP"
# Wired-up is checked against the GENERATED fragment, never against the awk:
# a mechanism present in the source and absent from the artefact is the
# recorded failure mode here.
nwire=$(grep -c -- ' -Uinsn-opinit-union.list ' "$G/multi-target-md.mk")
nlist=$(grep -c '^base ' "$G/insn-opinit-union.list" 2>/dev/null || echo 0)
nbase=$(ls -d "$G"/*-inc 2>/dev/null | wc -l)
echo "  -U occurrences in multi-target-md.mk : $nwire  (want = number of bases = $nbase)"
echo "  base lines in insn-opinit-union.list : $nlist  (want $nbase)"
[ "$nwire" -eq "$nbase" ] && [ "$nlist" -eq "$nbase" ] \
  && ok "union list built over all $nbase bases and used by all $nbase runs" \
  || bad "union list not wired for every base"

echo
echo "=== ARM 2  NO OBJECT REFERENCES THE FOUR BARE OPTAB ENTRY POINTS"
# This is the arm that says the primary stopped answering.  The bare symbols
# are still DEFINED (insn-opinit.o stays in OBJS for its four rodata
# vocabulary tables); what must be true is that nothing calls them.
cd "$G" || exit 9
leak=0
for s in "raw_optab_handler(unsigned int)" \
         "init_all_optabs(target_optabs*)" \
         "swap_optab_enable(optab_tag, machine_mode, bool)" \
         "partial_vectors_supported_p()"; do
  refs=""
  for o in *.o mt-*/*.o; do
    [ "$o" = insn-opinit.o ] && continue
    [ -f "$o" ] || continue
    n=$(nm -C -u "$o" 2>/dev/null | sed 's/^ *U //' | grep -c -x -F -- "$s")
    [ "$n" -gt 0 ] && refs="$refs $o"
  done
  if [ -n "$refs" ]; then
    echo "  LEAK [$s] ->$refs"
    leak=$((leak+1))
  else
    echo "  clean [$s]"
  fi
done
[ "$leak" -eq 0 ] && ok "no bare reference to any of the four" \
                 || bad "$leak of the four are still reached bare"

echo
echo "=== ARM 3  NON-VACUITY FOR ARM 2: the selected_ funnels ARE referenced"
# Without this, arm 2 would go green if the calls had simply disappeared --
# or if the demangled spelling had drifted and every count were 0.
tot=0
for s in "selected_raw_optab_handler(unsigned int)" \
         "selected_init_all_optabs(target_optabs*)" \
         "selected_swap_optab_enable(optab_tag, machine_mode, bool)" \
         "selected_partial_vectors_supported_p()"; do
  n=0
  for o in *.o; do
    [ -f "$o" ] || continue
    c=$(nm -C -u "$o" 2>/dev/null | sed 's/^ *U //' | grep -c -x -F -- "$s")
    [ "$c" -gt 0 ] && n=$((n+1))
  done
  echo "  $n objects reference [$s]"
  tot=$((tot+n))
done
[ "$tot" -gt 4 ] && ok "the funnels carry the traffic ($tot object-references)" \
                 || bad "funnels barely referenced ($tot); arm 2 may be vacuous"

echo
echo "=== ARM 4  BOTH SIDES: each base's slot resolves to ITS OWN back end"
# One-sided evidence cannot tell "fixed" from "everyone now gets the same new
# answer", so both bases are read, and they must differ.
for b in i386 aarch64; do
  for s in raw_optab_handler init_all_optabs; do
    n=$(nm -C --defined-only "insn-opinit-$b.o" 2>/dev/null \
        | grep -c -F "insn_$b::$s")
    echo "  insn-opinit-$b.o defines insn_$b::$s : $n"
    [ "$n" -eq 1 ] || bad "insn_$b::$s missing"
  done
done
a=$(nm -C "$G/cc1" | grep -c -F 'insn_aarch64::raw_optab_handler')
i=$(nm -C "$G/cc1" | grep -c -F 'insn_i386::raw_optab_handler')
echo "  both present in the linked cc1: aarch64=$a i386=$i"
[ "$a" -ge 1 ] && [ "$i" -ge 1 ] \
  && ok "both bases' handlers are in the binary to be chosen between" \
  || bad "a base's handler is missing from cc1"

echo
echo "=== ARM 5  THE SHARED STRUCT IS NOW BIG ENOUGH FOR EVERY BASE"
shared=$(sed -n 's/^#define NUM_OPTAB_PATTERNS  *\([0-9]*\).*/\1/p' "$G/insn-opinit.h")
[ -n "$shared" ] || { echo "FATAL: cannot read shared NUM_OPTAB_PATTERNS"; exit 9; }
echo "  shared NUM_OPTAB_PATTERNS = $shared"
worst=0
for f in "$G"/insn-opinit-*.h; do
  b=$(basename "$f" .h); b=${b#insn-opinit-}
  v=$(sed -n 's/^#define NUM_OPTAB_PATTERNS  *\([0-9]*\).*/\1/p' "$f")
  own=$(grep -c '^  { 0x' "$G/mt-$b/insn-opinit-$b.cc")
  echo "  $b: header says $v, its own pats[] holds $own entries"
  [ "$v" = "$shared" ] || bad "$b's header disagrees with the shared bound"
  [ "$own" -gt "$worst" ] && worst=$own
  # The per-base pats[] must NOT have been padded to the union: padding
  # unsorts the binary search in lookup_handler.
  [ "$own" -le "$shared" ] || bad "$b's pats[] is larger than the shared bound"
done
echo "  largest per-base pattern count = $worst"
[ "$shared" -ge "$worst" ] && ok "shared bound $shared covers the worst base ($worst)" \
                          || bad "shared bound $shared is BELOW the worst base ($worst)"
# And the union must actually have moved: if it equals the primary's own
# count and some other base is smaller, nothing was proved.
echo "  (a shared bound equal to the max of the bases is the whole point;"
echo "   it was 2975 against aarch64's 3328 before this change)"

echo
echo "=== ARM 6 (INJECTION)  remove the -U flag: genopinit must go back to"
echo "                       the primary's count, and the OLD SIZE must reappear"
INJ=/tmp/t117-inj6
rm -rf "$INJ"; mkdir -p "$INJ"
# Run the primary's genopinit by hand, once WITH the union flags and once
# WITHOUT, and require the two headers to differ in exactly the macro.
GO="$G/build/genopinit"
[ -x "$GO" ] || { echo "FATAL: no $GO"; exit 9; }
( cd "$G" && ./build/genopinit -Uinsn-opinit-union.list -Ai386 \
    "$SRCD/gcc/common.md" "$SRCD/gcc/config/i386/i386.md" insn-conditions.md \
    -h"$INJ/with.h" -c"$INJ/with.cc" ) > "$INJ/with.log" 2>&1
( cd "$G" && ./build/genopinit \
    "$SRCD/gcc/common.md" "$SRCD/gcc/config/i386/i386.md" insn-conditions.md \
    -h"$INJ/without.h" -c"$INJ/without.cc" ) > "$INJ/without.log" 2>&1
vw=$(sed -n 's/^#define NUM_OPTAB_PATTERNS  *\([0-9]*\).*/\1/p' "$INJ/with.h")
vo=$(sed -n 's/^#define NUM_OPTAB_PATTERNS  *\([0-9]*\).*/\1/p' "$INJ/without.h")
echo "  with    -U : NUM_OPTAB_PATTERNS = ${vw:-<none>}"
echo "  without -U : NUM_OPTAB_PATTERNS = ${vo:-<none>}"
if [ -z "$vw" ] || [ -z "$vo" ]; then
  bad "injection produced no header at all -- it tested nothing"
elif [ "$vw" = "$vo" ]; then
  bad "removing -U changed nothing; the union is not doing the work"
elif [ "$vw" -gt "$vo" ]; then
  ok "removing -U drops $vw -> $vo, i.e. back to the primary's own count"
else
  bad "removing -U RAISED the count ($vo > $vw); that is not the expected shape"
fi
# And the per-base pats[] must be the same in both -- it is deliberately not
# sized by the union, so the injection must NOT move it.
pw=$(grep -c '^  { 0x' "$INJ/with.cc"); po=$(grep -c '^  { 0x' "$INJ/without.cc")
echo "  pats[] entries: with -U = $pw, without -U = $po (must be equal)"
[ "$pw" = "$po" ] && ok "pats[] is unaffected by the union, as intended" \
                  || bad "pats[] moved with the union -- lookup_handler would unsort"

echo
echo "=== ARM 7 (INJECTION)  a union list that omits a base must be FATAL,"
echo "                       and the diagnostic must NAME that base"
INJ7=/tmp/t117-inj7
rm -rf "$INJ7"; mkdir -p "$INJ7"
grep -v 'aarch64' "$G/insn-opinit-union.list" > "$INJ7/short.list"
nleft=$(grep -c '^base ' "$INJ7/short.list")
echo "  doctored list has $nleft base line(s)"
[ "$nleft" -ge 1 ] || { echo "FATAL: doctored list is empty; the arm would pass for the wrong reason"; exit 9; }
( cd "$G" && ./build/genopinit -U"$INJ7/short.list" -Aaarch64 \
    "$SRCD/gcc/common.md" "$SRCD/gcc/config/aarch64/aarch64.md" \
    insn-conditions.md -h"$INJ7/o.h" -c"$INJ7/o.cc" ) > "$INJ7/log" 2>&1
rc7=$?
named=$(grep -c 'aarch64' "$INJ7/log")
echo "  genopinit rc=$rc7 ; diagnostic mentions aarch64: $named"
sed -n '1,3p' "$INJ7/log" | sed 's/^/    /'
if [ "$rc7" -eq 0 ]; then
  bad "a union list missing this base was accepted -- silently undersized"
elif [ "$named" -lt 1 ]; then
  bad "it failed, but without naming the missing base"
else
  ok "missing base is fatal and named"
fi

echo
echo "=== ARM 8 (INJECTION)  put the selection back the way it was, and"
echo "                       REQUIRE THE BARE SYMBOL TO REAPPEAR"
# Arm 2's green says nothing on its own: it would look identical if the four
# names had merely been spelled differently, or if `nm' had silently stopped
# matching.  This removes the one line the fix turns on -- the dispatch inside
# selected_raw_optab_handler -- rebuilds ONLY that object, and requires
# `U raw_optab_handler' to come back.  If it does not, arm 2 is a claim about
# the grep and not about the code.
SRC="$SRCD/gcc/multi-target-select.cc"
BAK=/tmp/t117-inj8.bak
cp "$SRC" "$BAK" || { echo "FATAL: cannot back up $SRC"; exit 9; }
restore () { cp "$BAK" "$SRC"; }
trap 'restore' EXIT INT TERM

before=$(nm -C -u "$G/multi-target-select.o" | sed 's/^ *U //' \
         | grep -c -x -F -- "raw_optab_handler(unsigned int)")
echo "  before injection: multi-target-select.o references bare handler: $before (want 0)"

# The injection: forward to the bare (primary's) handler, as optabs-query.cc
# used to.  Anchored on the mt_in_force line so a failed substitution is
# visible rather than silent.
sed -i 's|return mt_in_force ("raw_optab_handler")->raw_optab_handler (scode);|return raw_optab_handler (scode);|' "$SRC"
nsub=$(grep -c '^  return raw_optab_handler (scode);$' "$SRC")
if [ "$nsub" -ne 1 ]; then
  echo "  FATAL: the injection did not apply ($nsub sites); it would have tested nothing"
  restore; exit 9
fi

rm -f "$G/multi-target-select.o"
( cd "$SRCD" && sh scratchpad/t117-build.sh multi-target-select.o ) \
   > /tmp/t117-inj8.log 2>&1
if [ ! -f "$G/multi-target-select.o" ]; then
  echo "  FATAL: the injected object did not build; the arm proves nothing"
  restore; exit 9
fi
after=$(nm -C -u "$G/multi-target-select.o" | sed 's/^ *U //' \
        | grep -c -x -F -- "raw_optab_handler(unsigned int)")
echo "  after  injection: multi-target-select.o references bare handler: $after (want 1)"
[ "$before" -eq 0 ] && [ "$after" -eq 1 ] \
  && ok "removing the dispatch brings the primary's symbol straight back" \
  || bad "injection did not fire (before=$before after=$after) -- arm 2 is unproven"

# Restore, rebuild, and VERIFY the restore: an arm that leaves the tree
# injected turns every later measurement into a lie.
restore
trap - EXIT INT TERM
rm -f "$G/multi-target-select.o"
( cd "$SRCD" && sh scratchpad/t117-build.sh multi-target-select.o ) \
   > /tmp/t117-inj8-restore.log 2>&1
back=$(nm -C -u "$G/multi-target-select.o" 2>/dev/null | sed 's/^ *U //' \
       | grep -c -x -F -- "raw_optab_handler(unsigned int)")
echo "  after  restore  : multi-target-select.o references bare handler: $back (want 0)"
[ "$back" -eq 0 ] && ok "tree and object restored" || bad "RESTORE FAILED -- tree is dirty"

echo
echo "t117-guards: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
