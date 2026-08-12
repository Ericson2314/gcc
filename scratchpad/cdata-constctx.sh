#!/bin/bash
# RE-SWEEP for contexts that require a COMPILE-TIME CONSTANT (or a string
# literal), over the Stage-2 candidate macros AND over the transitive closure
# of macros DEFINED IN TERMS OF THEM.
#
# Why the closure: CLASS-C-DESIGN 2b swept only the 91 names themselves, and
# its own 8 records the gap -- "a class-(c) macro reached through ANOTHER macro
# that then lands in a #if or an array bound would not be seen" (the
# N_REG_CLASSES lesson).  A grep over the leaf names returning zero is not
# evidence.  MAX_BITS_PER_WORD is literally `#define MAX_BITS_PER_WORD
# BITS_PER_WORD' and IS an array bound; the leaf-only sweep cannot see it.
#
# Contexts checked (7); the 6 of CLASS-C-DESIGN 2b plus the one its sweep
# missed and that cost the last session a build cycle:
#   1 array bound            2 case label        3 enumerator
#   4 bitfield width         5 static_assert     6 namespace-scope initialiser
#   7 ADJACENT STRING LITERAL CONCATENATION            <-- the missed one
# plus three more that 2b did not name at all:
#   8 #if / #elif arithmetic  9 constexpr initialiser  10 alignas/aligned attr
#
# Controls, both must fire or the run is void:
#   POSITIVE  N_REG_CLASSES must be found in a constant context (73 recorded)
#   POSITIVE  FIRST_PSEUDO_REGISTER must be found      (90 recorded)
#   NEGATIVE  a name that exists nowhere must find nothing
set -u

GCC=${GCC:-/home/jcericson/src/gnu/gcc/multi-target/gcc}
OUT=${OUT:-/tmp/cdata-sweep}
mkdir -p "$OUT"

CAND="ATTRIBUTE_ALIGNED_VALUE BYTES_BIG_ENDIAN DWARF_FRAME_RETURN_COLUMN
JUMP_TABLES_IN_TEXT_SECTION LONG_TYPE_SIZE MALLOC_ABI_ALIGNMENT
MAX_FIXED_MODE_SIZE PARM_BOUNDARY PIC_OFFSET_TABLE_REGNUM SHIFT_COUNT_TRUNCATED
STRICT_ALIGNMENT TRAMPOLINE_SIZE WORDS_BIG_ENDIAN BITS_PER_WORD
FLOAT_WORDS_BIG_ENDIAN REG_WORDS_BIG_ENDIAN DWARF_CIE_DATA_ALIGNMENT
STACK_CHECK_FIXED_FRAME_SIZE STACK_CHECK_MAX_FRAME_SIZE SUPPORTS_STACK_ALIGNMENT"

# Files the middle end / front ends are built from: everything under gcc/ that
# is NOT a back end and NOT a test.
find "$GCC" -name '*.cc' -o -name '*.h' -o -name '*.c' -o -name '*.def' \
  | grep -v '/config/' | grep -v '/testsuite/' | sort > "$OUT/files.txt"
# The back ends' own headers, needed only to find DERIVED macro definitions.
find "$GCC" -path '*/config/*' \( -name '*.h' \) | sort > "$OUT/cfgfiles.txt"

# ---------------------------------------------------------------- closure ----
# A macro whose BODY mentions a candidate becomes non-constant too.  Iterate to
# a fixed point over defaults.h, the generic headers, and the two live bases.
cp /dev/null "$OUT/closure.txt"
for m in $CAND; do echo "$m"; done | sort -u > "$OUT/work.txt"
DEFSRC=$(cat "$OUT/files.txt"; grep -E '/(i386|aarch64)/' "$OUT/cfgfiles.txt")
for round in 1 2 3 4 5; do
  cat "$OUT/work.txt" >> "$OUT/closure.txt"
  sort -u "$OUT/closure.txt" -o "$OUT/closure.txt"
  pat=$(tr '\n' '|' < "$OUT/work.txt" | sed 's/|$//')
  # `#define NAME ... <candidate> ...' -- object-like or function-like.
  echo "$DEFSRC" | xargs grep -hE "^[[:space:]]*#[[:space:]]*define[[:space:]]+[A-Za-z_][A-Za-z0-9_]*.*\b($pat)\b" \
    2>/dev/null \
    | sed -E 's/^[[:space:]]*#[[:space:]]*define[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/' \
    | sort -u > "$OUT/new.txt"
  comm -23 "$OUT/new.txt" "$OUT/closure.txt" > "$OUT/work.txt"
  [ -s "$OUT/work.txt" ] || break
done
NEW=$(comm -13 <(for m in $CAND; do echo "$m"; done | sort -u) "$OUT/closure.txt")

# ---------------------------------------------------------------- contexts ---
sweep () {   # $1 = name ; prints one line per hit
  local n="$1"
  xargs grep -nE \
    -e "\[[^]]*\b$n\b[^]]*\][[:space:]]*(=|;|,|\{|\))"   `# 1 array bound` \
    -e "^[[:space:]]*case[[:space:]].*\b$n\b"            `# 2 case label` \
    -e "^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]][^;]*\b$n\b.*,[[:space:]]*$" `# 3 enumerator` \
    -e ":[[:space:]]*[^;]*\b$n\b[[:space:]]*;"           `# 4 bitfield` \
    -e "static_assert[^;]*\b$n\b"                        `# 5` \
    -e "^(static |const |extern )?[A-Za-z_][A-Za-z0-9_ ]*\**[A-Za-z_][A-Za-z0-9_]*\[?[]0-9]*\][[:space:]]*=[^;]*\b$n\b" `# 6` \
    -e "(\"[^\"]*\"[[:space:]]*\b$n\b|\b$n\b[[:space:]]*\")" `# 7 string concat` \
    -e "^[[:space:]]*#[[:space:]]*(if|elif)\b.*\b$n\b"   `# 8 preprocessor` \
    -e "constexpr[^;]*\b$n\b"                            `# 9` \
    -e "(alignas|aligned)[[:space:]]*\([^)]*\b$n\b"      `# 10` \
    < "$OUT/files.txt" 2>/dev/null \
  | grep -vE '^[^:]*:[0-9]+:[[:space:]]*(\*|/\*|//)'
}

report () {
  local n
  for n in $@; do
    sweep "$n" > "$OUT/hit-$n.txt"
    printf '%-34s %4d\n' "$n" "$(wc -l < "$OUT/hit-$n.txt")"
  done
}

echo "=== CONTROLS ==============================================="
report N_REG_CLASSES FIRST_PSEUDO_REGISTER ZZ_NO_SUCH_MACRO_ANYWHERE
echo
echo "=== CANDIDATES (the 20) ===================================="
report $CAND
echo
echo "=== DERIVED (closure, $(echo $NEW | wc -w) names the leaf sweep cannot see) ==="
echo "$NEW" | tr '\n' ' '; echo; echo
report $NEW
