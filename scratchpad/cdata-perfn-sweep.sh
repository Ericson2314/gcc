#!/bin/sh
# WHICH `target_cdata' MACROS ARE NOT COMPILE-TIME DATA AT ALL.
#
# `target-cdata.cc' computes every field ONCE, at startup, with `cfun' and
# `current_function_decl' both null.  `target-cdata.h' already states the
# rule: a macro that needs a DECLARATION is fine; a macro that needs
# per-function STATE is not, "however easy the include makes it to compile".
#
# That distinction has NO DIAGNOSTIC OF ITS OWN.  A macro reading
# `current_function_decl' fails to compile only because the name happens to be
# out of scope in that translation unit; add `tree.h' and it compiles,
# evaluates against a null `current_function_decl', and is silently wrong for
# every function that would have taken the other arm.  The loud failure and
# the silent wrong answer are ONE INCLUDE APART, in the wrong direction.
#
# Two deliberate properties:
#
#  * It reads the SOURCE, not the build log.  ~186 targets are never built, so
#    a diagnostic-driven sweep sees only the copies some configured triple
#    compiles.
#
#  * IT IS TRANSITIVE, and that is the whole reason it exists in this form.
#    The first version matched only the macro's own body and reported TWO
#    hits -- and MISSED the one that a 47-back-end build had actually failed
#    on, because `epiphany.h' says
#        DWARF_FRAME_RETURN_COLUMN  ->  DWARF_FRAME_REGNUM (EPIPHANY_RETURN_REGNO)
#    and only EPIPHANY_RETURN_REGNO names `current_function_decl'.  A
#    non-transitive sweep scores that back end CLEAN, which is the reassuring
#    direction.  Bodies are therefore expanded through macros defined in the
#    same back end's own directory, to a fixed depth.
#
# It is OVER-BROAD on purpose: it can nominate a macro for inspection, never
# clear one.  A hit is a question, not a verdict.  In particular it does not
# know whether a nominated macro is reached on a path that runs at cdata time.
#
# usage: cdata-perfn-sweep.sh [depth]
set -e
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "${n:-0}" = "${WANT_ANCHOR:-45}" ] || { echo "FATAL: $SRC anchor=$n"; exit 9; }
cd "$SRC/gcc"
DEPTH=${1:-4}
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# ---------------------------------------------------------------------------
# The field list, taken from target-cdata.h itself rather than retyped, so a
# field added there cannot be silently missed here.  Continuation lines are
# JOINED FIRST: several entries wrap, and parsing one entry per line drops
# exactly those -- a quiet undercount that would make the result look cleaner.
# ---------------------------------------------------------------------------
sed -n '/^#define TARGET_CDATA_FIELDS/,/^struct target_cdata/p' target-cdata.h \
  | sed -e :a -e '/\\$/{N; s/\\\n//; ta}' \
  | sed -e 's/\(OPTNUM\|STR\|NUM\) *(/\n&/g' > "$T/list"
MACROS=$(sed -n \
  -e 's/^STR *([^,]*,[[:space:]]*\([A-Z][A-Z0-9_]*\)).*/\1/p' \
  -e 's/^NUM *([^,]*,[[:space:]]*[^,]*,[[:space:]]*\([A-Z][A-Z0-9_]*\)).*/\1/p' \
  -e 's/^OPTNUM *([^,]*,[[:space:]]*[^,]*,[[:space:]]*\([A-Z][A-Z0-9_]*\)).*/\1/p' \
  "$T/list" | sort -u)
NM=$(echo "$MACROS" | grep -c .)
# 23 STR/NUM entries + 5 OPTNUM entries = 28.  The number is asserted so that
# a parse change cannot quietly report a smaller, tidier result.  It is
# checked against target-cdata.h's OWN struct, not against a number typed
# here: the struct has one member per STR/NUM and two per OPTNUM.
WANT=$(sed -n '/^struct target_cdata$/,/^};/p' target-cdata.h | grep -c ';')
[ "$NM" -gt 0 ] || { echo "FATAL: parsed no macro names out of target-cdata.h"; exit 9; }
[ "$NM" = "${WANT_FIELDS:-28}" ] || {
  echo "FATAL: parsed $NM macro names; expected 28 (struct lines: $WANT)"; exit 9; }
echo "cdata macros parsed from target-cdata.h: $NM"

# Per-function / per-compilation state.  `cfun' and `current_function_decl'
# are the two target-cdata.h names by name; the rest are the same category.
STATE='current_function_decl|\bcfun\b|crtl->|reload_completed|regs_ever_live|frame_pointer_needed|epilogue_completed'

# Emit the full body of macro $2 as defined in file $1.
body_of () {
  awk -v M="$2" '
    $0 ~ ("^[ \t]*#[ \t]*define[ \t]+" M "([ \t(]|$)") { inb = 1 }
    inb { print; if ($0 !~ /\\[ \t]*$/) inb = 0 }' "$1"
}

echo
echo "== nominated: a cdata macro whose expansion reaches per-function state"
hits=0
for m in $MACROS; do
  for f in $(grep -rl "define[ \t][ \t]*$m\b" config 2>/dev/null || true); do
    dir=$(dirname "$f")
    body_of "$f" "$m" > "$T/b"
    chain=""
    i=0
    while [ "$i" -lt "$DEPTH" ]; do
      if grep -Eq "$STATE" "$T/b"; then break; fi
      # Expand one level: append the body of every all-caps name in the
      # current text that this back end's own directory defines.
      : > "$T/next"
      for tok in $(grep -oE '\b[A-Z][A-Z0-9_]{2,}\b' "$T/b" | sort -u); do
        for g in "$dir"/*.h; do
          [ -e "$g" ] || continue
          grep -q "define[ \t][ \t]*$tok\b" "$g" || continue
          body_of "$g" "$tok" >> "$T/next"
          case " $chain " in *" $tok "*) ;; *) chain="$chain $tok";; esac
        done
      done
      # No growth means the expansion has closed; stop rather than spin.
      [ -s "$T/next" ] || break
      cat "$T/next" >> "$T/b"
      i=$((i+1))
    done
    grep -Eq "$STATE" "$T/b" || continue
    hits=$((hits+1))
    printf -- '-- %-28s %s\n' "$m" "$f"
    echo "   state named: $(grep -oE "$STATE" "$T/b" | sort -u | tr '\n' ' ')"
    [ -n "$chain" ] && echo "   reached through:$chain"
  done
done
echo
echo "nominated (macro, file) pairs: $hits   (expansion depth $DEPTH)"
# A zero here would be indistinguishable from a broken instrument, and this
# sweep's first version scored a real case clean.  Refuse to report a zero.
[ "$hits" -gt 0 ] || { echo "FATAL: zero hits -- the instrument is not demonstrably able to fire"; exit 9; }
