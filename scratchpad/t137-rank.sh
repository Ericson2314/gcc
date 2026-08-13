#!/bin/sh
# #137 -- RANK THE REMAINING `UNCONVERTED' MACROS BY WHAT LEAKS, NOT BY WHAT IS
# EASY.  Read-only over the source tree; no build dir, no compiler.
#
# It reports, per macro, five independent signals.  Each has found a real bug
# on this branch, and they are printed SEPARATELY rather than summed into one
# score, because three of them mean different KINDS of failure and a single
# number would let a reader quote a rank as a severity.
#
#   USE   sites in SHARED code (gcc/*.cc gcc/*.h and the language front ends;
#         NOT config/, NOT testsuite/, NOT generated files in a build dir).
#         Zero here is the `cfun->machine' verdict: nine of eleven were
#         confined to config/ and were correctly left alone.  A macro nothing
#         shared spells cannot leak into shared code.
#   FILE  distinct shared files, so one file spelling it ten times does not
#         outrank ten files spelling it once.
#   PP    sites on a `#if/#elif/#ifdef/#ifndef' line.  A macro used here
#         CANNOT simply become a runtime call: two `#if HAVE_ATTR_length'
#         gates would have silently evaluated a call to 0 and turned two
#         passes off for every target.  Split into:
#           PPA  arithmetic use (`#if M > 0')      -- needs a per-site design
#           PPD  existence use (`#ifdef M')        -- the ABSENCE channel
#   BND   sites where the name appears inside `[...]', i.e. it SIZES something.
#         Seven bound-vs-index instances so far, the largest a 163KB overrun.
#   DEF   which of the two configured bases defines it, read from each back
#         end's own headers: `BOTH', `i386', `aarch64', or `neither'.
#         `i386' or `aarch64' ALONE is the ABSENCE leak -- `STACK_DYNAMIC_OFFSET'
#         was defined by aarch64 and not i386, and `#ifndef' in shared code
#         discarded aarch64's own definition for every target.  An absence
#         emits no code, so no symbol or value instrument can see it; this
#         column is the only one that can.
#
# BLIND SPOTS, stated rather than discovered later:
#   * It is a TEXTUAL scan.  A macro reached only through another macro's body
#     scores 0 USE here and still leaks (the `MACRO-LEAK.md' identical-text
#     blind spot: `N_REG_CLASSES' expands through a back-end enum).
#   * `DEF' greps each back end's *.h for `#define'; a definition inherited
#     from a shared header (defaults.h) or produced by a generator is not
#     seen, and `#undef' is not tracked.  It is a lower bound on both sides.
#   * It says nothing about VALUE.  Two bases can both define a macro,
#     identically-spelled, to different values (that is exactly the blind spot
#     MACRO-LEAK.md measured); USE/DEF cannot see it.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)/gcc
n=$(grep -c MULTI_TARGET "$SRC/Makefile.in" || true)
[ "$n" -ge 39 ] || { echo "FATAL: anchor=$n, wrong tree"; exit 9; }

LIST=${1:-$S/t137-unconverted.txt}
[ -s "$LIST" ] || { echo "FATAL: macro list $LIST missing or empty"; exit 9; }

OUT=${OUT:-/tmp/t137-rank}
rm -rf "$OUT"; mkdir -p "$OUT" || exit 9

# The shared-code file set, materialised ONCE so every macro is scored against
# exactly the same population and the set itself can be inspected.
find "$SRC" -name '*.cc' -o -name '*.h' -o -name '*.c' \
  | grep -v "^$SRC/config/" \
  | grep -v "^$SRC/testsuite/" \
  | grep -v "^$SRC/ada/gcc-interface/" \
  | sort > "$OUT/files.txt"
nf=$(wc -l < "$OUT/files.txt")
[ "$nf" -gt 500 ] || { echo "FATAL: only $nf shared files found; the scan is vacuous"; exit 9; }

# Non-vacuity: a control macro that MUST score non-zero.  If this reads 0 the
# grep idiom is broken and every 0 below is a false negative rather than a
# finding -- the failure mode PRINCIPLES section 7 describes as
# "every arm reads empty, which looks exactly like the hypothesis".
ctl=$(grep -lw 'BITS_PER_UNIT' $(cat "$OUT/files.txt") | wc -l)
[ "$ctl" -gt 10 ] || { echo "FATAL: control BITS_PER_UNIT matched $ctl files; grep idiom dead"; exit 9; }

# DEF needs its OWN control, and it earned it: the first version of this
# script wrote `[ \t]' in an ERE bracket, where `\t' is the two characters
# backslash and t and NOT a tab.  Every back end writes `#define M<TAB>value',
# so EVERY macro scored `neither' -- an absence, which is precisely the
# reading this column exists to detect, produced by the instrument instead of
# by the code.  `UNITS_PER_WORD' is defined by BOTH bases with a tab
# (i386.h:767, aarch64.h:75), so it must read BOTH or the column is dead.
def_of () {
  _i=$(grep -rlE "^[[:blank:]]*#[[:blank:]]*define[[:blank:]]+$1([[:blank:](]|\$)" "$SRC/config/i386/" | wc -l)
  _a=$(grep -rlE "^[[:blank:]]*#[[:blank:]]*define[[:blank:]]+$1([[:blank:](]|\$)" "$SRC/config/aarch64/" | wc -l)
  if   [ "$_i" -gt 0 ] && [ "$_a" -gt 0 ]; then echo BOTH
  elif [ "$_i" -gt 0 ]; then echo i386-only
  elif [ "$_a" -gt 0 ]; then echo aarch64-only
  else echo neither; fi
}
[ "$(def_of UNITS_PER_WORD)" = BOTH ] || {
  echo "FATAL: DEF control UNITS_PER_WORD read $(def_of UNITS_PER_WORD), expected BOTH"; exit 9; }
# And the other direction: a name no back end defines must read `neither', or
# the pattern matches too much and every macro looks defined.
[ "$(def_of MT_NO_SUCH_MACRO_CONTROL)" = neither ] || {
  echo "FATAL: DEF negative control matched something"; exit 9; }

printf '%-34s %5s %5s %5s %5s %5s  %s\n' MACRO USE FILE PPA PPD BND DEF
while read -r m; do
  [ -n "$m" ] || continue
  grep -nw "$m" $(cat "$OUT/files.txt") > "$OUT/h-$m.txt" 2>/dev/null
  # Drop the macro's own plumbing: its #define/#undef/poison lines in
  # defaults.h and friends are not USES.
  awk -v m="$m" '
    { line = $0; sub(/^[^:]*:[0-9]*:/, "", line) }
    line ~ ("^[[:blank:]]*#[[:blank:]]*(define|undef)[[:blank:]]+" m "([[:blank:](]|$)") { next }
    line ~ /pragma GCC poison/ { next }
    { print }' "$OUT/h-$m.txt" > "$OUT/u-$m.txt"
  use=$(wc -l < "$OUT/u-$m.txt")
  file=$(cut -d: -f1 < "$OUT/u-$m.txt" | sort -u | wc -l)
  ppd=$(awk -v m="$m" '{l=$0; sub(/^[^:]*:[0-9]*:/,"",l)}
        l ~ /^[[:blank:]]*#[[:blank:]]*(if|elif|ifdef|ifndef)/ && l ~ ("(defined|ifdef|ifndef)[[:blank:](]*" m) {c++}
        END{print c+0}' "$OUT/u-$m.txt")
  ppa=$(awk -v m="$m" '{l=$0; sub(/^[^:]*:[0-9]*:/,"",l)}
        l ~ /^[[:blank:]]*#[[:blank:]]*(if|elif)/ && l !~ ("(defined|ifdef|ifndef)[[:blank:](]*" m) {c++}
        END{print c+0}' "$OUT/u-$m.txt")
  bnd=$(awk -v m="$m" '{l=$0; sub(/^[^:]*:[0-9]*:/,"",l)}
        l ~ ("\\[[^]]*" m) {c++} END{print c+0}' "$OUT/u-$m.txt")
  def=$(def_of "$m")
  printf '%-34s %5s %5s %5s %5s %5s  %s\n' "$m" "$use" "$file" "$ppa" "$ppd" "$bnd" "$def"
done < "$LIST"
