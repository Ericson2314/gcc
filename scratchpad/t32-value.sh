#!/bin/sh
# t32-value.sh -- the value-level arm the census's text comparison cannot do.
#
# WHY.  t32-census.sh compares macro BODIES as text, so it reports a macro as
# DIVERGENT whenever two back ends spell the same number differently.
# Measured example: `CHAR_TYPE_SIZE' is `BITS_PER_UNIT' in 45 bases and the
# literal `8' in 4 -- two bodies, one value.  Converting such a macro changes
# nothing and proves nothing, which is exactly what the brief warns about, so
# it must be named rather than counted.
#
# The arm fully EXPANDS each candidate through each base's real chain and
# compares the results.  A residue that is still not a literal (because the
# body reads an option variable such as `TARGET_INT8') is reported as
# OPTION-STATE: those are the leaks `nm' is blind to per PRINCIPLES, and they
# are divergent by construction even when the expansion text matches.
#
# usage: t32-value.sh <dumpdir> <snapshot-srcdir> <builddir> <macro>...
set -u
DUMP=${1:?dump dir}; SRC=${2:?snapshot srcdir}; D=${3:?build dir}; shift 3
[ $# -gt 0 ] || { echo "FATAL: no macros named"; exit 9; }
W=$(mktemp -d); trap 'rm -rf "$W"' 0
CFGI=""
for d in "$SRC"/gcc/config/*/; do CFGI="$CFGI -I$d"; done

BASES=$(cat "$DUMP/bases.txt")
[ -n "$BASES" ] || { echo "FATAL: no bases"; exit 9; }

for m in "$@"; do
  : > "$W/vals"
  for b in $BASES; do
    printf 'MTVAL %s\n' "$m" > "$W/in.c"
    v=$(cpp -x c++ -P -I"$D/gcc" -I"$SRC/gcc" -I"$SRC/gcc/config" -I"$SRC/include" \
          $CFGI -I"$D/gcc/include" -DIN_GCC -imacros "$D/gcc/tm-$b.h" "$W/in.c" 2>/dev/null \
        | sed -n 's/^MTVAL //p' | tr -s ' ')
    [ -n "$v" ] || v="<UNDEFINED>"
    # NORMALISE.  Two defects this arm had on its first run, both of which
    # produced a WRONG classification rather than a missing one:
    #
    #  - `CHAR_TYPE_SIZE' expanded to `(8)' in 45 bases and `8' in 4, and was
    #    scored DIVERGENT-BY-VALUE.  It is one value in two spellings -- the
    #    exact identity trap the census is supposed to catch, committed by the
    #    instrument written to catch it.  Strip redundant outer parens and all
    #    whitespace before comparing.
    #  - A FUNCTION-LIKE macro (`BRANCH_COST(speed_p, predictable_p)') cannot
    #    be expanded by naming it alone: cpp leaves the bare identifier, all 48
    #    bases "agree", and it scored IDENTITY -- a green for a macro that was
    #    never read.  Detect that the result is just the macro's own name and
    #    say so instead.
    v=$(printf '%s' "$v" | tr -d ' \t')
    while :; do
      case "$v" in
        \(*\)) inner=${v#\(}; inner=${inner%\)}
               case "$inner" in *\(*|*\)*) break ;; esac
               v=$inner ;;
        *) break ;;
      esac
    done
    [ "$v" = "$m" ] && v="<NOT-EXPANDED:function-like>"
    echo "$v" >> "$W/vals"
  done
  n=$(grep -c . "$W/vals")
  [ "$n" -gt 0 ] || { echo "FATAL: $m read no base at all"; exit 9; }
  u=$(sort -u "$W/vals" | grep -c .)
  lit=yes
  grep -qE '[A-Za-z_]' "$W/vals" && lit=no
  if grep -q 'NOT-EXPANDED' "$W/vals"; then k="UNREADABLE-function-like"
  elif [ "$u" = 1 ] && [ "$lit" = yes ]; then k="IDENTITY-BY-VALUE"
  elif [ "$u" = 1 ]; then k="IDENTITY-TEXT-OPTION-STATE"
  elif [ "$lit" = yes ]; then k="DIVERGENT-BY-VALUE"
  else k="DIVERGENT-OPTION-STATE"; fi
  printf '%-30s %-28s bases=%s distinct=%s : %s\n' "$m" "$k" "$n" "$u" \
    "$(sort -u "$W/vals" | head -6 | tr '\n' '|')"
done
