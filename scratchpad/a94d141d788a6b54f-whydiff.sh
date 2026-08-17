#!/bin/bash
# bash, not sh: the comparison uses process substitution, exactly as
# a76a331dcb554f700-bothsided.sh does.  `sh -n' happens to ACCEPT `<(...)',
# so mt-shcheck.sh cannot catch a wrong shebang here -- stated because a
# passing syntax check is not evidence the right interpreter will run it.
# a94d141d788a6b54f-whydiff.sh -- ACCOUNT FOR EVERY `DIFFER' ROW, BY CAUSE.
#
# WHY THIS IS NOT OPTIONAL HERE.  The usual both-sided acceptance is
# "N changed, M byte-identical, 0 DIFFER", and a nonzero DIFFER column is
# normally a regression.  This task's change is one that is SUPPOSED to move
# output: converting ASM_OUTPUT_LABELREF and ASM_GENERATE_INTERNAL_LABEL means
# every base that spells a label differently from the PRIMARY now emits its own
# spelling instead of i386's.  So "0 DIFFER" would have meant the conversion
# was DEAD, and a bare count of 49 says nothing about whether the 49 are the
# intended ones.
#
# The two must therefore be told apart per file, which is what this does: it
# classifies each differing pair as LABELS-ONLY (every changed line is a label
# definition or a label reference) or OTHER (anything else, which needs
# reading).  An OTHER row is not automatically a bug and is never automatically
# fine -- it is printed with its diff so the reader can decide.
#
# NON-VACUITY: exits 9 if it was given no differing pair at all, because a run
# that compared nothing and a run where everything was intended both print
# "OTHER 0".
#
# usage: C=<bs dir> a94d141d788a6b54f-whydiff.sh
set -u
C=${C:-/tmp/bs-a76a331dcb554f700}
[ -d "$C/a" ] && [ -d "$C/b" ] || { echo "FATAL: no $C/a and $C/b -- run the bothsided script first"; exit 9; }

n=0; lab=0; oth=0
for fa in "$C"/a/*.s; do
  f=$(basename "$fa")
  fb="$C/b/$f"
  [ -f "$fb" ] || continue
  # Same normalisation the bothsided script uses.
  da=$(sed -e '/\.file/d' -e '/target-config/d' "$fa")
  db=$(sed -e '/\.file/d' -e '/target-config/d' "$fb")
  [ "$da" = "$db" ] && continue
  n=$((n + 1))
  # Every changed line, both sides, with the diff markers.
  changed=$(diff <(printf '%s\n' "$da") <(printf '%s\n' "$db") | grep -E '^[<>]')
  # A line is label-shaped if it DEFINES a label (`<something>:') or MENTIONS
  # one in a directive/operand.  Deliberately broad on the mention side: the
  # question is "is anything here NOT about a label", so a test that is too
  # eager can only move a row from LABELS-ONLY to OTHER, never the reverse --
  # the safe direction, per PRINCIPLES on instruments that can only revoke.
  other=$(printf '%s\n' "$changed" \
          | grep -vE '^[<>][[:space:]]*[^[:space:]]*[A-Za-z_.$][A-Za-z0-9_.$]*:' \
          | grep -vE '\.(size|type|globl|global|global_asm|ent|end|proc|word|long|quad|gpword|hword|byte|space|align|section|weak|local|set|def|dword)\b' \
          | grep -vE '[.$][A-Za-z]*L[A-Za-z]*[0-9]' \
          | grep -E '^[<>]')
  if [ -z "$other" ]; then
    lab=$((lab + 1))
  else
    oth=$((oth + 1))
    echo "OTHER  $f"
    printf '%s\n' "$other" | head -6
  fi
done

echo "whydiff: differing pairs=$n  LABELS-ONLY=$lab  OTHER=$oth"
[ "$n" -gt 0 ] || { echo "FATAL: no differing pair was examined -- NULL RESULT, not a pass"; exit 9; }
