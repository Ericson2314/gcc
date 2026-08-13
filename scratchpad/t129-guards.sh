#!/bin/sh
# #129 -- guards for the NUM_INSN_CODES union.
#
# ARM 0 RUNS FIRST and asserts the GENERATED CONTENT BY NAME AND BY VALUE.
# "The generator ran" is not evidence the generator did anything: a generator
# has already once run, exited 0 and changed nothing here because a #define
# was missing from its heredoc, and move-if-change made that invisible to make.
#
# ARM 3 is the INJECTION.  Every refusal gencodes.cc claims to make is
# provoked by hand and required to fire BY NAME.  An unfired mitigation is
# indistinguishable from an absent one and reads as protection.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b129}
G=$B/gcc
pass=0; fail=0
ok   () { pass=$((pass+1)); echo "PASS  $*"; }
bad  () { fail=$((fail+1)); echo "FAIL  $*"; }
chk  () { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1: got '$2' want '$3'"; fi; }

echo "===== ARM 0: the generated content, by name and by value ====="

for f in insn-codes.h insn-codes-i386.h insn-codes-aarch64.h; do
  v=$(grep -h '^const unsigned int NUM_INSN_CODES' "$G/$f" | sed 's/[^0-9]//g')
  chk "$f NUM_INSN_CODES is the union max" "$v" "20512"
done

# The union list must name BOTH bases and carry BOTH values.  A list that
# parses and is non-empty is exactly the shape a truncated one has, so check
# the keys by name.
chk "union list base count" \
    "$(grep -c '^base ' "$B/gcc/insn-codes-union.list")" "2"
chk "union list has i386's own value"    \
    "$(grep -c '^NUM_INSN_CODES 15429$' "$B/gcc/insn-codes-union.list")" "1"
chk "union list has aarch64's own value" \
    "$(grep -c '^NUM_INSN_CODES 20512$' "$B/gcc/insn-codes-union.list")" "1"

# NON-VACUITY: the two bases must NOT have had the same count to begin with,
# or this whole change is untested by construction.
i=$(grep -c '^NUM_INSN_CODES 15429$' "$B/gcc/insn-codes-union.list")
a=$(grep -c '^NUM_INSN_CODES 20512$' "$B/gcc/insn-codes-union.list")
if [ "$i" = 1 ] && [ "$a" = 1 ]; then
  ok "NON-VACUITY: the two bases genuinely disagree (15429 vs 20512)"
else
  bad "NON-VACUITY: cannot show the bases disagreed; the union proves nothing"
fi

# Wired up in the GENERATED fragment, not in the awk source.
chk "multi-target-md.mk passes -U to the per-base gencodes runs" \
    "$(grep -c ' -Uinsn-codes-union.list ' "$G/multi-target-md.mk")" "2"
chk "multi-target-md.mk has a .part rule per base" \
    "$(grep -c '^insn-codes-.*\.part:' "$G/multi-target-md.mk")" "2"
chk "gcc/Makefile passes -U to the shared gencodes run" \
    "$(grep -c 'CODES_UNION_FLAGS = -Uinsn-codes-union.list' "$G/Makefile")" "1"

# insn-codes.h must have LEFT simple_rtl_generated_h and JOINED
# generated_files.  Losing the second is the order-only-barrier race that
# insn-config.h already paid for; it presents as a cold-build-only failure.
chk "insn-codes.h is out of simple_rtl_generated_h" \
    "$(grep -c 'simple_rtl_generated_h.*insn-codes\.h' "$G/Makefile")" "0"
chk "insn-codes.h is named in generated_files" \
    "$(grep -c 'insn-config.h insn-codes.h specs.h' "$G/Makefile")" "1"

echo
echo "===== ARM 1: the sized objects actually grew, by value ====="
# "Ask what would have had to change for your comparison to mean anything."
# default_target_recog is x_bool_attr_masks[N][3] + x_op_alt[N], so
# N*3*8 + N*8 = N*32 bytes plus the rest of the struct.
sz=$(sh "$S/eb-shell.sh" "cd $G && nm -S --defined-only recog.o | grep ' default_target_recog'" | awk '{print $2}')
lsz=$(sh "$S/eb-shell.sh" "cd $G && nm -S --defined-only lra.o | grep ' insn_code_data'" | awk '{print $2}')
[ -n "$sz" ]  || { echo "FATAL: nm produced nothing for default_target_recog"; exit 9; }
[ -n "$lsz" ] || { echo "FATAL: nm produced nothing for insn_code_data"; exit 9; }
d=$(printf '%d' "0x$sz"); l=$(printf '%d' "0x$lsz")
echo "  default_target_recog = $d bytes (0x$sz);  insn_code_data = $l bytes (0x$lsz)"
chk "insn_code_data is 20512 pointers" "$l" "$((20512*8))"
if [ "$d" -ge $((20512*32)) ]; then
  ok "default_target_recog is sized for 20512 (>= $((20512*32)))"
else
  bad "default_target_recog is $d, too small for 20512 (need >= $((20512*32)))"
fi
if [ "$d" -gt $((15429*32)) ]; then
  ok "and it is LARGER than the old i386 bound would give ($((15429*32)))"
else
  bad "default_target_recog did not grow; the bound did not reach recog.o"
fi

echo
echo "===== ARM 2: the enumerators did NOT get unioned ====="
# Only the bound is shared.  If the CODE_FOR_ lists had been merged, two back
# ends would be spelling one name for two patterns -- the exact bug class this
# branch exists to remove.  The per-base headers must still differ in LENGTH.
ci=$(grep -c '^  CODE_FOR_' "$G/insn-codes-i386.h")
ca=$(grep -c '^  CODE_FOR_' "$G/insn-codes-aarch64.h")
cs=$(grep -c '^  CODE_FOR_' "$G/insn-codes.h")
echo "  CODE_FOR_ lines: shared=$cs i386=$ci aarch64=$ca"
if [ "$ci" != "$ca" ]; then ok "the enumerator lists still differ per base"
else bad "the enumerator lists are the same length; did they get merged?"; fi
chk "the shared header still carries the primary's enumerators" "$cs" "$ci"

echo
echo "===== ARM 3: THE INJECTION -- every refusal must fire BY NAME ====="
U=$G/insn-codes-union.list
cp "$U" "$B/codes-union.orig" || exit 9

inject_and_expect () {  # $1 = label, $2 = expected substring in stderr
  rc=$(sh "$S/eb-shell.sh" \
    "cd $G && ./build/gencodes -Uinsn-codes-union.list -Ai386 $MDARGS" \
    > "$B/inj.out" 2> "$B/inj.err"; echo $?)
  if [ "$rc" = 0 ]; then
    bad "$1: gencodes exited 0; the refusal did not fire"
  elif grep -qF "$2" "$B/inj.err"; then
    ok "$1: refused by name -- $(head -1 "$B/inj.err")"
  else
    bad "$1: failed for the WRONG reason: $(head -2 "$B/inj.err" | tr '\n' ' ')"
  fi
}

MDARGS="$(cd "$S/.." && pwd)/gcc/config/i386/i386.md insn-conditions.md"

# (3a) SANITY: the unmodified list must let gencodes SUCCEED, or every
# refusal below would fire for a reason unrelated to the injection.
rc=$(sh "$S/eb-shell.sh" "cd $G && ./build/gencodes -Uinsn-codes-union.list -Ai386 $MDARGS" > "$B/inj.out" 2> "$B/inj.err"; echo $?)
if [ "$rc" = 0 ] && grep -q 'NUM_INSN_CODES = 20512' "$B/inj.out"; then
  ok "3a control: unmodified list accepted, and gives the UNION value"
else
  bad "3a control: gencodes failed on the good list (rc=$rc); the arms below are meaningless"
  head -3 "$B/inj.err"
fi

# (3b) A list that does not mention this base -- the stale-list failure.
grep -v '^base i386$' "$B/codes-union.orig" > "$U"
# ASSERT THE INJECTION PRODUCED THE STATE INTENDED, not merely that sed ran.
chk "3b injection state: 'base i386' gone" "$(grep -c '^base i386$' "$U")" "0"
chk "3b injection state: 'base aarch64' still there" "$(grep -c '^base aarch64$' "$U")" "1"
inject_and_expect "3b missing base" "none of them \`i386'"

# (3c) A list whose base is present but whose key is missing.  This is the
# case a "file is non-empty" check passes and a bound of zero comes out of.
grep -v '^NUM_INSN_CODES 15429$' "$B/codes-union.orig" > "$U"
chk "3c injection state: i386's key gone"    "$(grep -c '^NUM_INSN_CODES 15429$' "$U")" "0"
chk "3c injection state: base lines intact"  "$(grep -c '^base ' "$U")" "2"
inject_and_expect "3c missing key" "given for 1 of 2 back ends"

# (3d) A STALE list: every value present, but below what this base needs.
sed -e 's/^NUM_INSN_CODES 15429$/NUM_INSN_CODES 12/' \
    -e 's/^NUM_INSN_CODES 20512$/NUM_INSN_CODES 13/' \
    "$B/codes-union.orig" > "$U"
chk "3d injection state: both values lowered" \
    "$(grep -c '^NUM_INSN_CODES 1[23]$' "$U")" "2"
inject_and_expect "3d stale list" "the union file is stale"

# (3e) -U with no -A at all.
rc=$(sh "$S/eb-shell.sh" "cd $G && ./build/gencodes -Uinsn-codes-union.list $MDARGS" > "$B/inj.out" 2> "$B/inj.err"; echo $?)
if [ "$rc" != 0 ] && grep -qF 'require -A' "$B/inj.err"; then
  ok "3e -U without -A refused by name"
else
  bad "3e -U without -A: rc=$rc $(head -1 "$B/inj.err")"
fi

# RESTORE, and prove the restore reversed the injection.
cp "$B/codes-union.orig" "$U" || exit 9
chk "3z restore: base count back"  "$(grep -c '^base ' "$U")" "2"
chk "3z restore: i386 value back"  "$(grep -c '^NUM_INSN_CODES 15429$' "$U")" "1"
chk "3z restore: aarch64 value back" "$(grep -c '^NUM_INSN_CODES 20512$' "$U")" "1"
rc=$(sh "$S/eb-shell.sh" "cd $G && ./build/gencodes -Uinsn-codes-union.list -Ai386 $MDARGS" > "$B/inj.out" 2> "$B/inj.err"; echo $?)
if [ "$rc" = 0 ] && grep -q 'NUM_INSN_CODES = 20512' "$B/inj.out"; then
  ok "3z restore: gencodes accepts again and still gives 20512"
else
  bad "3z restore: gencodes no longer works (rc=$rc)"
fi

echo
echo "===== ARM 4: JOB 2 -- the families with NO selector, recorded as a FACT ====="
# This arm asserts the CURRENT, UNFIXED state so that the day somebody wires a
# selector, this guard fails and has to be updated deliberately rather than
# the fix landing unremarked.  It is a ratchet, not a pass.
sel=$(grep -c -E 'get_attr_enabled|insn_default_length|internal_dfa_insn_code|state_transition|maximal_insn_latency' \
      "$S/../gcc/multi-target-select.cc" "$S/../gcc/target-cumargs-select.cc" \
      "$S/../gcc/target-cumargs.cc" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
chk "attrtab/automata/dfatab/latencytab still have NO selector (known debt)" "$sel" "0"

echo
echo "===== $pass PASS / $fail FAIL ====="
[ "$fail" = 0 ]
