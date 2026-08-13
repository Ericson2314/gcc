#!/bin/sh
# #113b -- the CONFIGURE arms for --enable-targets.
#
# Three negative controls and one affirmative.  The negative ones matter more:
# the bar is that something FAILS when the per-target instantiation is wrong,
# and a build that passes because a loop ran zero times is a false green.
#
# Each arm asserts the DIAGNOSTIC TEXT, not merely a non-zero exit.  "configure
# failed" is not a diagnosis and would be satisfied by an unrelated breakage.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
W=${W:-/tmp/t113b}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_run () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev \
    libmpc texinfo --substituters 'https://cache.nixos.org/' --run "$1"
}

T1=aarch64-unknown-linux-gnu
T2=x86_64-pc-linux-gnu
HDR=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include

COMMON="--disable-werror --disable-bootstrap --disable-nls \
  --enable-backends=$T2,$T1 \
  --with-native-system-header-dir=$HDR \
  CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
  CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
  --enable-languages=c,lto"

run_arm () {   # $1 = arm name, $2 = extra configure args
  d="$W/$1"
  rm -rf "$d"; mkdir -p "$d" || exit 9
  sh_run "cd $d && $SRC/configure $COMMON $2" > "$d/out" 2> "$d/err"
  echo $? > "$d/rc"
}

fail=0

echo "=============================================================="
echo "ARM A (NEGATIVE): no --enable-targets at all must FAIL BY NAME"
echo "=============================================================="
run_arm none ""
rc=$(cat "$W/none/rc")
if [ "$rc" = 0 ]; then
  echo "  FAIL: configure SUCCEEDED with no target named.  That is a tree"
  echo "        with a default target, i.e. a primary."
  fail=1
elif grep -q -- "--enable-targets=LIST is required" "$W/none/err" "$W/none/out"; then
  echo "  OK: rc=$rc and it says so by name:"
  grep -h -- "--enable-targets=LIST is required" "$W/none/err" "$W/none/out" | sed 's/^/      /'
else
  echo "  FAIL: rc=$rc but not by name.  tail of stderr:"
  tail -5 "$W/none/err" | sed 's/^/      /'
  fail=1
fi

echo
echo "=============================================================="
echo "ARM B (NEGATIVE): an UNRECOGNISED triple must FAIL BY NAME"
echo "=============================================================="
# The trap being controlled for: config.sub rejects the triple, the element
# becomes empty, the empty element is skipped, and the build proceeds with
# one fewer target than asked for -- silently.
run_arm badtriple "--enable-targets=$T2,nosucharch-nosuchvendor-nosuchos"
rc=$(cat "$W/badtriple/rc")
if [ "$rc" = 0 ]; then
  echo "  FAIL: configure accepted a triple config.sub does not recognise."
  echo "        The element was silently dropped."
  fail=1
elif grep -q "is not a recognised target triple" "$W/badtriple/err" "$W/badtriple/out"; then
  echo "  OK: rc=$rc and it names the offending element:"
  grep -h "is not a recognised target triple" "$W/badtriple/err" "$W/badtriple/out" | sed 's/^/      /'
else
  echo "  FAIL: rc=$rc but not by name.  tail of stderr:"
  tail -5 "$W/badtriple/err" | sed 's/^/      /'
  fail=1
fi

echo
echo "=============================================================="
echo "ARM C (WARNING): --target= must WARN, explicitly"
echo "=============================================================="
run_arm targetopt "--enable-targets=$T2,$T1 --target=$T1"
if grep -q "is not how this tree selects targets" "$W/targetopt/err" "$W/targetopt/out"; then
  echo "  OK: warned explicitly:"
  grep -h "is not how this tree selects targets" "$W/targetopt/err" "$W/targetopt/out" | sed 's/^/      /'
else
  echo "  FAIL: --target= passed without the explicit warning.  Relying on"
  echo "        autoconf's option checking is not enough:"
  echo "        --disable-option-checking propagates."
  fail=1
fi

echo
echo "=============================================================="
echo "ARM D (AFFIRMATIVE): two targets -> two DISTINCT trees"
echo "=============================================================="
run_arm two "--enable-targets=$T2,$T1"
rc=$(cat "$W/two/rc")
if [ "$rc" != 0 ]; then
  echo "  FAIL: configure rc=$rc.  tail of stderr:"
  tail -20 "$W/two/err" | sed 's/^/      /'
  fail=1
else
  sub=$(grep -h "^mt_target_subdirs=" "$W/two/Makefile" 2>/dev/null)
  echo "  configure rc=0"
  echo "  Makefile says: $(grep -h '^MT_TARGET_SUBDIRS' "$W/two/Makefile")"
  n=$(grep -h '^MT_TARGET_SUBDIRS' "$W/two/Makefile" | sed 's/.*= *//' | wc -w)
  if [ "$n" != 2 ]; then
    echo "  FAIL: expected 2 target subdirs, got $n -- N did not survive"
    fail=1
  else
    echo "  OK: 2 target subdirs"
  fi
fi

echo
echo "=============================================================="
echo "ARM E (PERMUTATION): the order of --enable-targets must NOT matter"
echo "=============================================================="
# This is the enforcement mechanism for "no primary".  If reversing the list
# changes the substituted value, something treats position 1 as privileged.
run_arm two_rev "--enable-targets=$T1,$T2"
a=$(grep -h '^MT_TARGET_SUBDIRS' "$W/two/Makefile" 2>/dev/null)
b=$(grep -h '^MT_TARGET_SUBDIRS' "$W/two_rev/Makefile" 2>/dev/null)
if [ -z "$a" ] || [ -z "$b" ]; then
  echo "  FAIL: could not read MT_TARGET_SUBDIRS from both trees (vacuous)"
  fail=1
elif [ "$a" = "$b" ]; then
  echo "  OK: both orders give the same list -- no position is privileged"
  echo "      $a"
else
  echo "  FAIL: order changed the result; position 1 is privileged"
  echo "      forward: $a"
  echo "      reverse: $b"
  fail=1
fi

echo
echo "=============================================================="
[ $fail = 0 ] && { echo "ALL CONFIGURE ARMS PASS"; exit 0; }
echo "SOME CONFIGURE ARMS FAILED"
exit 1
