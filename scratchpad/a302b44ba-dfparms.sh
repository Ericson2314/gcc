#!/bin/sh
# BOTH ARMS OF `decimal_float', AT THE COMPILER, ON A BUILD THAT IS ALREADY UP.
#
# The claim to be tested is that `decimal_float' in the target's `specs-config'
# is what decides whether cc1 will accept `_Decimal32/64/128' -- i.e. that
# 9ee972c229d's fix is the thing making `dfp.exp' run, and not something else
# that changed at the same time.
#
# A test with only the AFTER arm cannot say that.  "The TU compiles" is also
# what you would see if the front end had stopped consulting `targ_caps' at all,
# or if the flag were being supplied from somewhere else entirely.  So this
# takes the build's OWN specs-config, makes ONE substitution in a copy of it
# (`decimal_float 1' -> `decimal_float 0'), and requires the SAME compiler on
# the SAME source to REFUSE.  One byte of difference between the two arms.
#
# It also checks the file really did differ in exactly that one line, so that a
# sed that matched nothing cannot present itself as a passing test -- the
# "absent artefact vs absent mechanism" shape.
#
# usage: a302b44ba-dfparms.sh <builddir> <triple>
set -u
B=${1:?build dir}
T=${2:?triple}
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
CFG=$(ls "$B"/lib/gcc/*/"$T"/specs-config 2>/dev/null | head -1)
[ -n "$CFG" ] && [ -f "$CFG" ] || { echo "FATAL: no specs-config for $T under $B"; exit 9; }

W=$(mktemp -d) || exit 9
trap 'rm -rf "$W"' 0

cat > "$W/df.c" <<'EOF'
_Decimal32  a;
_Decimal64  b;
_Decimal128 c;
_Decimal64 add (_Decimal64 x, _Decimal64 y) { return x + y; }
EOF

have=$(sed -n 's/^decimal_float //p' "$CFG" | head -1)
echo "-- $T specs-config: $CFG"
echo "-- decimal_float as built: '$have'"
[ "$have" = 1 ] || { echo "FATAL: this arm needs a build whose specs-config says 1; it says '$have'"; exit 9; }

# ---- ARM A: the file as the build produced it (decimal_float 1) ----
if "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" -S -o "$W/a.s" "$W/df.c" 2> "$W/a.err"; then
  A=compiled
else
  A=refused
fi
echo "-- ARM A (decimal_float 1): $A"
[ "$A" = compiled ] || { echo "   compiler said:"; sed -n 1,5p "$W/a.err" | sed 's/^/     /'; }

# ---- ARM B: the same file with that one line flipped to 0 ----
sed 's/^decimal_float 1$/decimal_float 0/' "$CFG" > "$W/cfg0"
d=$(diff "$CFG" "$W/cfg0" | grep -c '^[<>]')
[ "$d" = 2 ] || { echo "FATAL: the flip changed $d diff lines, not exactly 2 (one < and one >)."
  echo "  A sed that matched nothing would leave the two files identical and ARM B"
  echo "  would then be a re-run of ARM A wearing a different name."; exit 9; }
echo "-- the two config files differ in exactly one line (decimal_float 1 -> 0)"

if "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$W/cfg0" -S -o "$W/b.s" "$W/df.c" 2> "$W/b.err"; then
  Bx=compiled
else
  Bx=refused
fi
echo "-- ARM B (decimal_float 0): $Bx"
[ "$Bx" = refused ] && { echo "   compiler said:"; sed -n 1,3p "$W/b.err" | sed 's/^/     /'; }

if [ "$A" = compiled ] && [ "$Bx" = refused ]; then
  echo "DFPARMS: PASS -- decimal_float in specs-config is what decides it, both ways"
  exit 0
fi
echo "DFPARMS: FAIL -- ARM A=$A ARM B=$Bx; expected compiled/refused."
echo "  If BOTH arms compiled, cc1 is not consulting targ_caps.decimal_float and"
echo "  the dfp results are green for a reason that is not this fix."
exit 1
