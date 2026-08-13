#!/bin/sh
# #138 -- FAULT INJECTION for t138-gate.sh.  An unfired mitigation is
# indistinguishable from an absent one, so each arm of the gate script is made
# to fail on purpose and required to say so BY NAME.
#
#   inject=old    restore the EXACT pre-change bug: the `*stack_regs' gate
#                 returns true unconditionally, which is what
#                 `#ifdef STACK_REGS -> return true' compiled to when the
#                 primary answered for everybody.  ARM A must report FAIL
#                 (aarch64 still runs the pass).
#
#   inject=dead   i386's own table says it has no register stack.  This is the
#                 quiet failure the whole change risks -- a compiler in which
#                 the pass runs nowhere.  ARM A must report FATAL-VACUOUS,
#                 NOT a pass.
#
# Both injections are ASSERTED to have produced the state intended, per
# PRINCIPLES: a `sed' that matched nothing exits 0 and leaves the fixed
# compiler in place, and every downstream reading is then of the fixed
# compiler.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${1:?build dir}
MODE=${2:?old|dead}

RS=$SRC/gcc/reg-stack.cc
TR=$SRC/gcc/target-regstack.cc
cp "$RS" "$S/.t138-reg-stack.bak" || exit 9
cp "$TR" "$S/.t138-target-regstack.bak" || exit 9

restore () {
  cp "$S/.t138-reg-stack.bak" "$RS"
  cp "$S/.t138-target-regstack.bak" "$TR"
  rm -f "$S/.t138-reg-stack.bak" "$S/.t138-target-regstack.bak"
}
trap 'restore' EXIT INT TERM

case $MODE in
old)
  sed -i 's/      return targetm_regstack != NULL \&\& targetm_regstack->has_stack_regs;/      return true; \/* INJECTED *\//' "$RS"
  grep -q 'return true; /\* INJECTED \*/' "$RS" || {
    echo "FATAL: injection 'old' matched nothing; refusing to score"; exit 9; }
  grep -q 'targetm_regstack->has_stack_regs;' "$RS" && {
    echo "FATAL: injection 'old' left the original gate in place too"; exit 9; }
  ;;
dead)
  # The `true' in the STACK_REGS arm of the table, and only that one.
  awk 'BEGIN{done=0}
       /^  true,$/ && done==0 { print "  false, /* INJECTED */"; done=1; next }
       { print }
       END{ if (done==0) { print "NOMATCH" > "/dev/stderr"; exit 3 } }' \
      "$TR" > "$TR.tmp" || { echo "FATAL: injection 'dead' matched nothing"; rm -f "$TR.tmp"; exit 9; }
  mv "$TR.tmp" "$TR"
  grep -q 'false, /\* INJECTED \*/' "$TR" || {
    echo "FATAL: injection 'dead' did not take"; exit 9; }
  ;;
*) echo "FATAL: unknown mode $MODE"; exit 9 ;;
esac

echo "--- injected: $MODE ---"
D=$B sh "$S/t135-build.sh" cc1 > "$S/.t138-inj-$MODE.log" 2>&1 || {
  echo "INJECT $MODE: build failed -- see $S/.t138-inj-$MODE.log"; exit 9; }
sh "$S/t138-gate.sh" "$B"
echo "--- injection $MODE done (rc above is the GATE script's) ---"
