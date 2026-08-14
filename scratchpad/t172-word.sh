#!/bin/sh
# #172 arm 1 -- IS THE EMITTED CODE THE RIGHT WIDTH?
#
# PRINCIPLES section 4: "assembles, right ELF machine" is NOT the bar; riscv64
# passed it while emitting 32-bit code.  So this reads SEMANTIC properties of
# the output and nothing else:
#
#   WORDSTORE  the width of the instruction that saves the return address
#              (riscv sd/sw, aarch64 str x/w, s390 stg/st)
#   CFI        the .cfi_offset the unwinder will believe
#   SHIFT      the shift used on a 64-bit `long'
#   ARCHATTR   riscv's `.attribute arch' string, empty when no -march reached
#              cc1 -- the same NULL cmdline_subset_list as the word size
#
# BOTH-SIDED BY CONSTRUCTION: the same source, the same cc1, three back ends.
# One target getting the right answer proves nothing unless the others are
# shown unchanged (PRINCIPLES section 4).
#
# usage: t172-word.sh <builddir> <srcdir> <toolroot> <tag> [extra cc1 args...]
set -u
D=${1:?build dir}; SRC=${2:?srcdir}; ROOT=${3:?tool root}; TAG=${4:?tag}
shift 4
case "$D" in
  */b-a82dcce59b2d6b84e*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
grep -q "$SRC/configure" "$D/config.log" \
  || { echo "FATAL: $D not configured from $SRC"; exit 9; }
[ "$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")" = "${WANT_ANCHOR:-55}" ] \
  || { echo "FATAL: anchor is not ${WANT_ANCHOR:-55}"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
IN=$SRC/scratchpad/t172-word.c
[ -f "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

OUT=$D/t172-$TAG; rm -rf "$OUT"; mkdir -p "$OUT"
printf '%-28s %-9s %-16s %-10s %s\n' TARGET LONG-DIR 'sizeof l,p' SHIFT ARCHATTR
for t in aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  cfg=$(ls "$D"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  [ -n "$cfg" ] || { printf '%-28s %s\n' "$t" "NO-CFG"; continue; }
  ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$cfg" "$@" \
      "$IN" -o "$OUT/$t.s" ) > "$OUT/$t.out" 2> "$OUT/$t.err"
  if [ $? != 0 ] || [ ! -s "$OUT/$t.s" ]; then
    printf '%-28s %s\n' "$t" "CC1-FAIL: $(head -1 "$OUT/$t.err")"
    continue
  fi
  # The directive chosen for a `long', and the two sizeof values beside it.
  dir=$(grep -oE '\.(quad|dword|8byte|xword|word|4byte|long)\b' "$OUT/$t.s" \
        | head -1)
  vals=$(grep -E '\.(quad|dword|8byte|xword|word|4byte|long)\b' "$OUT/$t.s" \
         | head -2 | sed 's/.*[ \t]//' | tr '\n' ',' | sed 's/,$//')
  sh=$(grep -oE '\b(sll|slli|sllw|slliw|lsl|sllg|sla|slag|sra|srai|sraw|sraiw|asr|srag)\b' \
        "$OUT/$t.s" | sort -u | tr '\n' ',' | sed 's/,$//')
  at=$(grep -m1 '\.attribute arch' "$OUT/$t.s" | sed 's/.*arch, *//' | cut -c1-34)
  [ -n "$at" ] || at='(none emitted)'
  printf '%-28s %-9s %-16s %-10s %s\n' "$t" "${dir:--}" "${vals:--}" "${sh:--}" "$at"

  # arm: the target's own real assembler, then the object's word-size evidence.
  d="$ROOT/$t"
  if [ -x "$d/$t-as" ] && "$d/$t-as" -o "$OUT/$t.o" "$OUT/$t.s" \
       > "$OUT/$t.asout" 2> "$OUT/$t.aserr"; then
    "$d/$t-readelf" -h "$OUT/$t.o" | sed -n 's/^ *Machine: */    machine: /p'
    "$d/$t-readelf" -h "$OUT/$t.o" | sed -n 's/^ *Class: */    class:   /p'
  else
    echo "    as: FAIL -- $(head -1 "$OUT/$t.aserr" 2>/dev/null)"
  fi
done
echo
echo "== md5 of each .s (input $IN)"
for f in "$OUT"/*.s; do
  [ -f "$f" ] || continue
  echo "   $(basename "$f")  $(wc -c < "$f") bytes  md5 $(md5sum < "$f" | cut -c1-12)"
done
