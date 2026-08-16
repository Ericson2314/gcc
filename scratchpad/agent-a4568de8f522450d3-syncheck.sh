#!/bin/sh
# agent-a4568de8f522450d3-syncheck.sh -- compile the WORKING TREE's
# target-cumargs.cc for MANY bases against an existing 47-base build dir,
# `-fsyntax-only', and report every base that fails.
#
# WHY.  Converting a macro whose body is a back end's own code means the
# per-base translation unit must now satisfy THAT back end's headers.  Each
# missing declaration is one `error:' and stops the build, so discovering them
# through full 47-base builds costs one build per missing include -- this task
# has already paid that twice (`epiphany.h' needing `attribs.h', then
# `attribs.h' needing `stringpool.h', an hour each).
#
# The compile line is taken from the FAILED build's own log rather than
# reconstructed, so the flags are exactly the ones make used -- including the
# ~90 `-D<name>=<name>_<base>' renames, which no hand-written command would
# reproduce.  Only MULTI_TARGET_TARGETM_BASE, MT_BASE and
# TARGETM_CUMARGS_SYMBOL are rewritten per base.
#
# THIS IS NOT A BUILD AND DOES NOT REPLACE ONE.  `-fsyntax-only' does not link
# and does not run the generators, so it can only find missing declarations --
# which is precisely the class being hunted.  A clean run here is a
# PRECONDITION for spending an hour on a build, never a substitute for it.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
D=${D:?set D to an existing 47-base build dir}
LOG=${LOG:-$D/all-gcc.log}
SRC=${SRC:?set SRC to the source tree whose target-cumargs.cc to check}
BASES=${BASES:-aarch64 epiphany s390 riscv i386 arm rs6000 mips avr sh nvptx alpha ia64 microblaze c6x pa nds32 v850 rx msp430 arc iq2000}

[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }
[ -f "$SRC/gcc/target-cumargs.cc" ] || { echo "FATAL: no $SRC/gcc/target-cumargs.cc"; exit 9; }

# The template command: the g++ line whose NEXT line names target-cumargs.cc.
n=$(grep -n '/gcc/target-cumargs\.cc[[:space:]]*$' "$LOG" | head -1 | cut -d: -f1)
[ -n "$n" ] || { echo "FATAL: no target-cumargs.cc compile in $LOG"; exit 9; }
CMD=$(sed -n "$((n-1))p" "$LOG" | sed 's/[[:space:]]*\\$//')
case "$CMD" in *target-cumargs-*.o*) ;; *) echo "FATAL: line $((n-1)) is not the compile"; exit 9 ;; esac
OLDBASE=$(printf '%s\n' "$CMD" | grep -o 'MULTI_TARGET_TARGETM_BASE=[A-Za-z0-9_]*' | cut -d= -f2)
[ -n "$OLDBASE" ] || { echo "FATAL: no MULTI_TARGET_TARGETM_BASE in the command"; exit 9; }
echo "template taken from $LOG:$((n-1)), base=$OLDBASE"
echo "checking $SRC/gcc/target-cumargs.cc"
echo

cd "$D/gcc" || exit 9
fail=0; ok=0
for b in $BASES; do
  [ -f "$D/gcc/$b-inc/tm.h" ] || { printf '  %-12s SKIP (no %s-inc in this build dir)\n' "$b" "$b"; continue; }
  C=$(printf '%s\n' "$CMD" \
      | sed "s/MULTI_TARGET_TARGETM_BASE=$OLDBASE/MULTI_TARGET_TARGETM_BASE=$b/g" \
      | sed "s/MT_BASE=$OLDBASE-inc/MT_BASE=$b-inc/g" \
      | sed "s/TARGETM_CUMARGS_SYMBOL=targetm_cumargs_$OLDBASE/TARGETM_CUMARGS_SYMBOL=targetm_cumargs_$b/g" \
      | sed "s/-o target-cumargs-$OLDBASE\.o//" \
      | sed "s/-MT target-cumargs-$OLDBASE\.o//" \
      | sed "s#-MF \./\.deps/target-cumargs-$OLDBASE\.TPo##" \
      | sed 's/ -MMD -MP//')
  err=/tmp/syn-a4568-$b.err
  eval "$C -fsyntax-only '$SRC/gcc/target-cumargs.cc'" > /dev/null 2> "$err"
  if grep -q 'error:' "$err"; then
    printf '  %-12s FAIL\n' "$b"
    grep 'error:' "$err" | head -3 | sed 's/^/       /'
    fail=$((fail+1))
  else
    printf '  %-12s ok\n' "$b"
    ok=$((ok+1))
  fi
done

echo
echo "bases checked ok=$ok fail=$fail"

# NON-VACUITY.  `-fsyntax-only' with a broken command line produces NO
# `error:' and an empty file, which scores as a pass for every base -- the
# "tool did not run" and "all clean" collision this project keeps meeting.
# So: at least one base must have been compiled, and the compiler must have
# demonstrably READ our file.  Checked by asking for a deliberate error.
echo "NON-VACUITY (can this harness fail at all?):"
BAD=/tmp/syn-a4568-negctl.cc
{ cat "$SRC/gcc/target-cumargs.cc"; echo 'int mt_negative_control (void) { return undeclared_on_purpose_a4568; }'; } > $BAD
C=$(printf '%s\n' "$CMD" | sed "s/-o target-cumargs-$OLDBASE\.o//" \
      | sed "s/-MT target-cumargs-$OLDBASE\.o//" \
      | sed "s#-MF \./\.deps/target-cumargs-$OLDBASE\.TPo##" | sed 's/ -MMD -MP//')
eval "$C -fsyntax-only $BAD" > /dev/null 2> /tmp/syn-a4568-negctl.err
if grep -q 'undeclared_on_purpose_a4568' /tmp/syn-a4568-negctl.err; then
  echo "  ok: an injected undeclared identifier IS reported -- the harness runs"
else
  echo "  FATAL: the negative control did NOT fire; every 'ok' above is void"
  head -5 /tmp/syn-a4568-negctl.err | sed 's/^/       /'
  exit 9
fi
[ $ok -gt 0 ] || { echo "FATAL: zero bases compiled"; exit 9; }
exit $([ $fail -eq 0 ] && echo 0 || echo 1)
