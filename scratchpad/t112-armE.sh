#!/bin/sh
# TASK #112 -- ARM E: TARGET MACROS THAT READ THE PRIMARY BACK END'S MUTABLE
# STATE.
#
# WHY THIS IS A DIFFERENT ARM FROM EVERY EXISTING ONE.
#
#   arm A   divergent macro TEXT between bases.
#   arms B/C UNDEFINED SYMBOLS after conversion.
#   arm D   EXISTENCE predicates -- #ifdef with nothing on the other side.
#
# None of them can see this.  `MOVE_RATIO(speed)' is i386.h:1968
#     ((speed) ? ix86_cost->move_ratio : 3)
# `tree-inline.cc' is shared, compiled once against i386, so every target gets
# that expansion.  There is no divergent text to compare (aarch64 has its own
# MOVE_RATIO, but shared code never sees it), no undefined symbol (`ix86_cost'
# is defined in i386.cc and links cleanly), and no #ifdef anywhere.
#
# The macro does not expand to a VALUE.  It expands to a DEREFERENCE OF A
# BACK-END GLOBAL that only that back end's option-override writes.  With
# aarch64 selected, ix86_option_override never runs, ix86_cost stays at its
# i386.cc:130 initialiser NULL, and the load faults.
#
# MEASURED: that fault is confirmed (scratchpad/t112-ipa-diag.sh) --
#   mov 0x31ec3c4(%rip),%rax   # <ix86_cost>
#   mov 0xf4(%rax),%eax        <- SIGSEGV, si_addr == 0xf4 == offsetof move_ratio
#
# THE NULL IS LUCK, AND THAT IS THE POINT OF COUNTING THE REST.  ix86_cost
# happens to start NULL, so it crashes.  A sibling that reads a back-end
# global with a NON-NULL or scalar initialiser -- `ix86_move_max' in MOVE_MAX,
# say -- answers with i386's tuning while compiling for aarch64 and emits
# WRONG CODE with no diagnostic at all.  Those are the ones nobody has
# counted.
#
# BLIND SPOTS, stated per PRINCIPLES 4 rule 5:
#   * TEXT ONLY.  A macro whose body calls a back-end FUNCTION that in turn
#     reads state is not distinguished from one that reads state directly.
#   * Macros reaching back-end state through ANOTHER macro are counted only if
#     the intermediate is also in i386.h.  Two-step chains through defaults.h
#     are missed.  UPPER bound on safety, LOWER bound on the problem.
#   * Only the i386 (primary) side is scanned, because only the primary's
#     expansion reaches shared code.  That is the correct side, but it means
#     the count is specific to this primary.
set -u
G=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa0b6da0fbac13315/gcc
O=${O:-/tmp/t112-armE}
A=${A:-/tmp/t112-armD2}
rm -rf "$O"; mkdir -p "$O"
[ -s "$A/shared-files.txt" ] || { echo "FATAL: run t112-armD2.sh first"; exit 9; }

# 1. Every macro i386's headers define whose BODY names an ix86_/ia32_ symbol.
#    Multi-line bodies are joined on the trailing backslash first, or a macro
#    whose state read is on continuation line 3 scores clean.
find "$G/config/i386" -name '*.h' -print0 \
| xargs -0 sed -e :a -e '/\\$/N; s/\\\n//; ta' \
| sed -n 's/^[ \t]*#[ \t]*define[ \t][ \t]*\([A-Za-z_][A-Za-z0-9_]*\)\((\{0,1\}\)/\1\t/p' \
| grep -E 'ix86_|ia32_' > "$O/state-macros-raw.txt"
cut -f1 "$O/state-macros-raw.txt" | sort -u > "$O/state-macros.txt"
n=$(wc -l < "$O/state-macros.txt")
[ "$n" -gt 0 ] || { echo "FATAL: no state-reading macros found at all -- instrument broken"; exit 9; }

# NON-VACUITY: the instrument must find the one we already proved by hand.
grep -qx MOVE_RATIO "$O/state-macros.txt" \
  || { echo "FATAL: MOVE_RATIO not found, yet it is CONFIRMED by gdb -- instrument is wrong"; exit 9; }

# 2. Which of those are actually SPELLED in genuinely shared code.
: > "$O/hits.txt"
while read -r m; do
  f=$(grep -lw "$m" $(cat "$A/shared-files.txt") 2>/dev/null | head -40)
  [ -n "$f" ] || continue
  c=$(printf '%s\n' "$f" | grep -c .)
  printf '%s\t%s\t%s\n' "$m" "$c" "$(printf '%s\n' "$f" | sed "s#$G/##" | tr '\n' ' ')" \
    >> "$O/hits.txt"
done < "$O/state-macros.txt"

echo "macros in config/i386/*.h whose body reads ix86_/ia32_ state: $n"
echo "of those, SPELLED IN SHARED CODE (so the primary answers for all):"
echo "  $(grep -c . "$O/hits.txt")"
echo
printf '%-34s %4s  %s\n' MACRO TUs 'SHARED TUs THAT SPELL IT'
sort -t"$(printf '\t')" -k2 -rn "$O/hits.txt" \
  | awk -F'\t' '{printf "%-34s %4s  %s\n", $1, $2, substr($3,1,90)}'
echo
echo "=== already known and excluded from target-cdata as NOT invariant ==="
echo "    BIGGEST_ALIGNMENT STACK_BOUNDARY STORE_MAX_PIECES MOVE_MAX"
echo "    MOVE_MAX_PIECES COMPARE_MAX_PIECES"
echo "=== of the hits above, the ones with NO existing ticket ==="
for m in $(cut -f1 "$O/hits.txt"); do
  case $m in
    BIGGEST_ALIGNMENT|STACK_BOUNDARY|STORE_MAX_PIECES|MOVE_MAX|MOVE_MAX_PIECES|COMPARE_MAX_PIECES) ;;
    *) printf '    %s\n' "$m" ;;
  esac
done
