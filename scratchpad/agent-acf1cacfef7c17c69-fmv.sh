#!/bin/sh
# TARGET_HAS_FMV_TARGET_ATTRIBUTE -- the `#ifndef' floor in the polarity where
# the PRIMARY IS SILENT, so the floor fires and the DISSENTERS read it.
#
# BOTH-SIDED, and the control is the point.  aarch64 must GAIN function
# multiversioning; x86_64 must KEEP it, byte for byte against genuine stock.
# A one-sided arm cannot distinguish "aarch64 fixed" from "everyone now gets
# the same new answer", which is the failure this project keeps meeting.
#
# THE OBSERVABLE IS A DIAGNOSTIC, NOT A BYTE COUNT, and that is deliberate.
# With the floor's 1, `c/c-decl.cc:3459' skips the `disjoint_version_decls'
# arm, so a second `target_version' definition is diagnosed as
#
#     error: redefinition of 'foo'
#
# i.e. the compiler never gets as far as emitting anything to compare.  So arm
# 1 is the absence of that error AND the presence of the mangled version
# symbols; "it compiled" alone would pass on a compiler that emitted one
# unversioned function.
#
# usage: agent-acf1cacfef7c17c69-fmv.sh <mt-builddir> [stock-aarch64] [stock-x86_64]
set -u
B=${1:?mt build dir}
SA=${2:-/tmp/b-stock-agent-a3464debf6893de84-aarch64}
SX=${3:-/tmp/b-stock-agent-ab1900d5279ba137f-x86_64}
TA=aarch64-unknown-linux-gnu
TX=x86_64-pc-linux-gnu
W=$(cd "$(dirname "$0")" && pwd)
O=/tmp/fmv-acf1cacfef7c17c69
rm -rf "$O"; mkdir -p "$O"

[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }

# The compiler must NAME THE TREE IT CAME FROM, or a green here is about
# somebody else's build dir (PRINCIPLES: every harness asserts which tree it
# measures).
[ -r "$B/MY-SRC" ] || { echo "FATAL: no $B/MY-SRC"; exit 9; }
echo "mt build   $B"
echo "mt srcdir  $(cat "$B/MY-SRC")"

mtc () {  # mtc <triple> <src> <out> <errout>
  "$B/gcc/xgcc" -B"$B/asdir-$1/" -B"$B/gcc/" \
    -ftarget-config="$B/lib/gcc/17.0.0/$1/specs-config" \
    -S -O0 "$2" -o "$3" 2> "$4"
}

##############################################################################
# ARM 0 -- NEGATIVE CONTROL ON THE INSTRUMENT ITSELF.
# The reproducer is a test that is EXPECTED to fail before the fix, so "no
# error in the log" and "the compiler never ran" are the same empty file.
# Compile something that must fail, and require it to.
##############################################################################
printf 'int f (void) { return undeclared_thing_xyzzy (); }\n' > "$O/neg.c"
if mtc "$TA" "$O/neg.c" "$O/neg.s" "$O/neg.err"; then
  echo "FATAL: ARM 0 -- a call to an undeclared function compiled cleanly."
  echo "       The instrument is not reading this compiler.  REFUSING."
  exit 9
fi
grep -q 'undeclared_thing_xyzzy' "$O/neg.err" \
  || { echo "FATAL: ARM 0 -- failure did not name the symbol; wrong compiler?"; exit 9; }
echo "ARM 0  negative control fires (the harness is reading a real cc1)   OK"

##############################################################################
# ARM 1 -- aarch64 `target_version' multiversioning.  gcc.target/aarch64/mv-1.c
##############################################################################
IN=$W/../gcc/testsuite/gcc.target/aarch64/mv-1.c
[ -f "$IN" ] || IN=$(cd "$W/.." && pwd)/gcc/testsuite/gcc.target/aarch64/mv-1.c
[ -f "$IN" ] || { echo "FATAL: no mv-1.c at $IN"; exit 9; }

mtc "$TA" "$IN" "$O/mv1.s" "$O/mv1.err"; rc=$?
echo
echo "ARM 1  aarch64 mv-1.c  rc=$rc"
if grep -q 'redefinition' "$O/mv1.err"; then
  echo "       FAIL -- 'redefinition' still emitted; the floor is still winning:"
  sed -n '1,6p' "$O/mv1.err"
  a1=FAIL
elif [ "$rc" != 0 ]; then
  echo "       FAIL -- rc=$rc for some OTHER reason (read it, do not assume):"
  sed -n '1,10p' "$O/mv1.err"
  a1=FAIL
else
  # Not "it compiled": the VERSIONS must be in the output.  A compiler that
  # emitted one unversioned `foo' also exits 0.
  nd=$(grep -c '^foo\.default:' "$O/mv1.s" || true)
  nv=$(grep -c '^foo\._M' "$O/mv1.s" || true)
  nr=$(grep -c '^foo\.resolver:' "$O/mv1.s" || true)
  echo "       foo.default=$nd  foo._M*=$nv  foo.resolver=$nr  (want 1 / 3 / 1)"
  if [ "$nd" = 1 ] && [ "$nv" -ge 3 ] && [ "$nr" = 1 ]; then a1=PASS; else a1=FAIL; fi
  echo "       $a1"
fi

##############################################################################
# ARM 2 -- BOTH-SIDED CONTROL.  x86_64 uses the `target' attribute for FMV and
# reads the floor's 1, which is its OWN answer, so NOTHING here may move.
# Compared against genuine stock, not against a remembered number.
##############################################################################
cat > "$O/tc.c" <<'EOF'
__attribute__((target_clones("default","popcnt")))
int f (int x) { return __builtin_popcount (x); }
int g (int x) { return f (x); }
EOF
mtc "$TX" "$O/tc.c" "$O/tc-mt.s" "$O/tc-mt.err"; rcx=$?
echo
echo "ARM 2  x86_64 target_clones control  rc=$rcx"
if [ "$rcx" != 0 ]; then
  sed -n '1,10p' "$O/tc-mt.err"; a2=FAIL
elif [ -x "$SX/gcc/xgcc" ]; then
  "$SX/gcc/xgcc" -B"$SX/gcc/" -S -O0 "$O/tc.c" -o "$O/tc-stock.s" 2> "$O/tc-stock.err" \
    || { echo "FATAL: stock x86_64 compile failed"; cat "$O/tc-stock.err"; exit 9; }
  # Directives carry the file name and the producer; compare the CODE.
  grep -v '^[[:space:]]*\.' "$O/tc-stock.s" > "$O/tc-stock.body"
  grep -v '^[[:space:]]*\.' "$O/tc-mt.s"    > "$O/tc-mt.body"
  n=$(grep -c . "$O/tc-stock.body" || true)
  [ "$n" -ge 5 ] || { echo "FATAL: stock body is $n lines -- the arm read nothing"; exit 9; }
  if diff -u "$O/tc-stock.body" "$O/tc-mt.body" > "$O/tc.diff"; then
    echo "       IDENTICAL to genuine stock over $n body lines            PASS"
    a2=PASS
  else
    echo "       DIFFERS from stock:"; sed -n '1,30p' "$O/tc.diff"; a2=FAIL
  fi
else
  echo "       (no stock x86_64 at $SX -- resolver-presence arm only)"
  nr=$(grep -c 'resolver\|ifunc' "$O/tc-mt.s" || true)
  echo "       resolver/ifunc hits = $nr (want >= 2)"
  [ "$nr" -ge 2 ] && a2=PASS || a2=FAIL
fi

##############################################################################
# ARM 3 -- riscv64's half of the same macro, and the SEPARATOR.
# riscv.h says TARGET_HAS_FMV_TARGET_ATTRIBUTE 0 and
# TARGET_CLONES_ATTR_SEPARATOR '#'.  With the leak open it parsed on ',' --
# so a two-version list spelled with '#' arrived as ONE version whose name
# contained a '#'.  This arm is about the separator, which no aarch64 arm can
# see.
##############################################################################
TR=riscv64-unknown-linux-gnu
cat > "$O/sep.c" <<'EOF'
__attribute__((target_clones("default#arch=+v")))
int f (int x) { return x + 1; }
int g (int x) { return f (x); }
EOF
if [ -r "$B/lib/gcc/17.0.0/$TR/specs-config" ]; then
  mtc "$TR" "$O/sep.c" "$O/sep.s" "$O/sep.err"; rcr=$?
  echo
  echo "ARM 3  riscv64 '#'-separated target_clones  rc=$rcr"
  nv=$(grep -c '\.default\|\.arch' "$O/sep.s" 2>/dev/null || true)
  echo "       version labels in the output = $nv"
  sed -n '1,4p' "$O/sep.err"
  a3=$([ "$rcr" = 0 ] && echo PASS || echo INFO)
else
  echo; echo "ARM 3  SKIPPED -- no riscv64 specs-config in this build dir"
  a3=SKIP
fi

echo
echo "SUMMARY  arm1(aarch64 gains FMV)=$a1  arm2(x86_64 control unmoved)=$a2  arm3(riscv sep)=$a3"
[ "$a1" = PASS ] && [ "$a2" = PASS ] || exit 1
exit 0
