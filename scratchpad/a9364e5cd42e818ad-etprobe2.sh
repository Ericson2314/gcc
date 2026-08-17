#!/bin/sh
# DOES FIXING `TYPE_OPERAND_FMT` RESTORE `ilp32`?  A PREDICTION, TESTED.
#
# `a660907426e03e4e9-etprobe.sh` established that `check_effective_target_ilp32`
# and `check_effective_target_int32plus` are `check_no_compiler_messages <name>
# **object** { ... }` -- `object` means the ASSEMBLER RUNS -- and that both read
# FALSE on the multi-target arm compiler while the compiler's own answer about
# `sizeof (void *)` is correct and is never consulted.  189 `object`-mode and
# 116 `assembly`-mode selectors in `target-supports.exp` are answered this way.
#
# A660907426E03E4E9-ARM-BOARD.md 8 offers the mechanism as SUFFICIENT to explain
# 21,181 results the stock run produced and the multi-target run did not.  It is
# careful to call that a prediction rather than a conclusion, and this script is
# the test.  It runs the two probes with the BEFORE and AFTER compilers, in both
# `-S` and `-c` mode.
#
# THE `-S` COLUMN IS THE ARGUMENT, NOT DECORATION.  If a translation unit
# COMPILES and only fails to ASSEMBLE, the probe is not measuring the property
# it names.  If it fails BOTH ways the probe is a real negative and this whole
# line of reasoning is wrong.
#
# AND THE NEGATIVE CONTROL IS MANDATORY.  `lp64.c` asserts `sizeof (void *) ==
# 8`, which is FALSE on arm.  It must FAIL on both compilers in both modes.  If
# it passes, the probe body is not being evaluated at all and every "TRUE" in
# the table is vacuous -- the exact shape PRINCIPLES calls a null result that
# reads as a pass.
#
# usage: OLD=<builddir> NEW=<builddir> TOOLS=<toolsdir> sh ...-etprobe2.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
if [ "${MT_INSHELL:-}" != 1 ]; then
  exec sh "$S/eb-shell.sh" "MT_INSHELL=1 OLD='${OLD:?}' NEW='${NEW:?}' TOOLS='${TOOLS:?}' sh '$0'"
fi
OLD=${OLD:?}; NEW=${NEW:?}; TOOLS=${TOOLS:?}
T=arm-unknown-linux-gnueabihf
W=/tmp/etprobe2-$$; mkdir -p "$W"

# GUARD 3c IN MINIATURE: the compiler must be handed THIS TARGET's assembler by
# name.  A `-B` dir without an `as` in it falls through to the host's, which
# accepts `@object` and would report every probe TRUE -- turning this script
# into a machine for confirming whatever it was pointed at.
AS=$W/asdir; mkdir -p "$AS"
[ -x "$TOOLS/bin/$T-as" ] || { echo "FATAL: no $TOOLS/bin/$T-as"; exit 9; }
ln -sf "$TOOLS/bin/$T-as" "$AS/as"
ln -sf "$TOOLS/bin/$T-ld" "$AS/ld"
m=$(printf '\t.text\n' > "$W/m.s"; "$AS/as" -o "$W/m.o" "$W/m.s" >/dev/null 2>&1 && \
    "$TOOLS/bin/$T-readelf" -h "$W/m.o" | sed -n 's/.*Machine: *//p')
[ "$m" = ARM ] || { echo "FATAL: $AS/as produced Machine='$m', not ARM"; exit 9; }
echo "-- assembler in the -B dir produces Machine: ARM"

cat > "$W/ilp32.c" <<'EOF'
int dummy[sizeof (int) == 4 && sizeof (void *) == 4 && sizeof (long) == 4 ? 1 : -1];
EOF
cat > "$W/int32plus.c" <<'EOF'
int dummy[sizeof (int) >= 4 ? 1 : -1];
EOF
cat > "$W/lp64.c" <<'EOF'
int dummy[sizeof (void *) == 8 ? 1 : -1];
EOF

VER=$(cat "$(cat "$OLD/MY-SRC")/gcc/BASE-VER")
run () { if "$@" > "$W/e" 2>&1; then echo ok; else echo FAIL; fi; }
printf '%-11s %-7s %-5s %-5s %-7s %s\n' PROBE COMPILER -S -c verdict note
for p in ilp32 int32plus lp64; do
  for side in old new; do
    case $side in
      old) B=$OLD ;;
      new) B=$NEW ;;
    esac
    CFG="$B/lib/gcc/$VER/$T/specs-config"
    [ -f "$CFG" ] || { echo "FATAL: no $CFG"; exit 9; }
    set -- "$B/gcc/xgcc" -B"$AS/" -B"$B/gcc/" -ftarget-config="$CFG"
    s=$(run "$@" -S -o "$W/$p.$side.s" "$W/$p.c")
    c=$(run "$@" -c -o "$W/$p.$side.o" "$W/$p.c")
    if [ "$s" = ok ] && [ "$c" = FAIL ]; then
      v=FALSE; note="compiles, will not ASSEMBLE -- the probe measures the assembler"
    elif [ "$c" = ok ]; then v=TRUE; note=
    else v=FALSE; note="does not compile either -- a real negative"
    fi
    printf '%-11s %-7s %-5s %-5s %-7s %s\n' "$p" "$side" "$s" "$c" "$v" "$note"
    if [ "$p" = lp64 ] && [ "$v" = TRUE ]; then
      echo "FATAL: the lp64 negative control passed on a 32-bit target."
      echo "       The probe body is not being evaluated; every TRUE above is vacuous."
      exit 9
    fi
  done
done
echo "-- negative control (lp64) FALSE on both compilers, as it must be"
echo "-- artefacts in $W"
