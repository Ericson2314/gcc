#!/bin/sh
# TASK #117 -- IS THE OPTAB VOCABULARY REALLY SHARED, OR IS IT THE PRIMARY'S?
#
# `insn-opinit-<base>.cc' defines four rodata tables that shared code
# references BARE (so today it gets the primary's copy):
#   code_to_optab_  optab_to_code_  convlib_def  normlib_def
#
# If their bodies are byte-identical across every configured base, they are
# genuine target-independent vocabulary (they come from optabs.def, not from
# the .md) and the bare reference is harmless.  If ANY of them differs, the
# bare reference is a live one-name-many-authorities leak and must be selected
# like insn_data is.
#
# This script answers that by DIFFING THE BODIES, not by comparing sizes.  Two
# tables of equal size with different contents is exactly the case a size
# comparison cannot see -- and equal sizes is what a first look reported.
#
# It also diffs the two per-base headers, so that a divergence anywhere in
# insn-opinit-<base>.h is reported rather than only the four names guessed at.
#
# Env: D = build dir (default /tmp/b117).
set -u
D=${D:-/tmp/b117}
G="$D/gcc"
W=/tmp/t117-vocab.$$
mkdir -p "$W" || exit 9

bases=""
for f in "$G"/insn-opinit-*.h; do
  [ -f "$f" ] || continue
  b=$(basename "$f" .h); b=${b#insn-opinit-}
  bases="$bases $b"
done
n=$(echo $bases | wc -w)
[ "$n" -ge 2 ] || { echo "FATAL: found $n bases ($bases); need >=2 to compare"; exit 9; }
echo "bases:$bases"

first=$(echo $bases | cut -d' ' -f1)

echo
echo "=== A. the four rodata tables, BODY diff (not size)"
rc=0
for s in code_to_optab_ optab_to_code_ convlib_def normlib_def; do
  ref=""
  for b in $bases; do
    src="$G/mt-$b/insn-opinit-$b.cc"
    [ -f "$src" ] || { echo "FATAL: no $src"; exit 9; }
    awk -v S="$s" 'index($0, S "[") && /=/ {p=1} p{print} p && /^};/{exit}' \
      "$src" > "$W/$s.$b"
    lines=$(wc -l < "$W/$s.$b")
    # Non-vacuity: an empty extraction would make every diff trivially clean.
    [ "$lines" -gt 3 ] || { echo "FATAL: extracted only $lines lines for $s/$b; refusing to score"; exit 9; }
    if [ -z "$ref" ]; then ref="$W/$s.$b"; refb=$b; continue; fi
    d=$(diff "$ref" "$W/$s.$b" | wc -l)
    if [ "$d" -eq 0 ]; then
      echo "  SAME  $s : $refb vs $b ($lines lines)"
    else
      echo "  DIFFERS $s : $refb vs $b ($d diff lines)  <-- LEAK"
      rc=1
    fi
  done
done

echo
echo "=== B. whole-header diff, so a divergence outside the four is not missed"
for b in $bases; do
  [ "$b" = "$first" ] && continue
  echo "--- insn-opinit-$first.h vs insn-opinit-$b.h"
  # The per-base namespaced declaration blocks legitimately differ (they name
  # that base's own patterns).  What must NOT differ is anything the SHARED
  # header exports: everything before the `namespace insn_<base> {' line.
  sed -n "1,/^namespace insn_$first {/p" "$G/insn-opinit-$first.h" > "$W/hdr.$first"
  sed -n "1,/^namespace insn_$b {/p"     "$G/insn-opinit-$b.h"     > "$W/hdr.$b"
  hl=$(wc -l < "$W/hdr.$first")
  [ "$hl" -gt 100 ] || { echo "FATAL: shared prefix is only $hl lines; refusing to score"; exit 9; }
  diff "$W/hdr.$first" "$W/hdr.$b"
  echo "    (shared prefix: $hl lines)"
done

echo
echo "=== C. the trailing shared block (struct target_optabs and friends)"
for b in $bases; do
  echo "--- $b"
  grep -n 'define NUM_OPTAB_PATTERNS' "$G/insn-opinit-$b.h"
done
grep -n 'define NUM_OPTAB_PATTERNS' "$G/insn-opinit.h"

rm -rf "$W"
echo
[ "$rc" -eq 0 ] && echo "VERDICT: the four tables are shared vocabulary" \
               || echo "VERDICT: at least one table is a per-base authority"
exit $rc
