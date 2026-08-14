#!/bin/sh
# #158 -- BOTH-SIDED arms for the top-level --enable-backends refusal.
#
# One-sided evidence cannot distinguish "fixed" from "everything now fails"
# (PRINCIPLES section 4), so ARM 2 is the arm that the refusal did not simply
# break the supported spelling, and it checks the ARTEFACT (how many
# --enable-backends gcc/configure was actually handed), not just an exit code.
#
# These are CONFIGURE-time arms only: no compiler is built, so nothing here is
# a codegen or runtime bar and none is claimed.
#
# usage: t158-guards.sh <srcdir> <scratch-parent>
set -e
SRC=${1:?srcdir}
P=${2:?scratch parent}
WANT=${WANT_ANCHOR:-48}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in" || true)
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }
S=$(cd "$(dirname "$0")" && pwd)

# NON-VACUITY FIRST: if the tree under test has no refusal in its GENERATED
# configure, every arm below is scoring a tree that cannot fail, and ARM 1
# would read as "the fix works" only because configure died for some other
# reason.  Refuse to score.
grep -q 'enable-backends is not accepted at the top level' "$SRC/configure" \
  || { echo "FATAL: $SRC/configure carries no refusal text; arms would be vacuous"; exit 9; }
echo "non-vacuity: refusal text present in $SRC/configure"

T2=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu
fail=0

run () { # run <dir> <args...>
  d=$1; shift
  rm -rf "$d"; mkdir -p "$d"
  ( cd "$d" && sh "$SRC/configure" "$@" ) > "$d/o" 2> "$d/e"
}

echo
echo "ARM 1  both spellings, disagreeing -- must REFUSE, naming the flag"
set +e
run "$P/g1" --enable-targets=$T2 --enable-backends=all
rc=$?
set -e
if [ "$rc" = 0 ]; then
  echo "  FAIL: configure accepted the pair (rc=0)"; fail=1
elif grep -q 'enable-backends is not accepted at the top level' "$P/g1/e"; then
  echo "  PASS: rc=$rc and the message names --enable-backends"
else
  echo "  FAIL: rc=$rc but the message does not name the flag:"; tail -3 "$P/g1/e"; fail=1
fi

echo
echo "ARM 2  the supported spelling alone -- must still WORK, and gcc/ must be"
echo "       handed the derived list EXACTLY ONCE (the artefact, not the rc)"
set +e
run "$P/g2" --enable-targets=$T2 --disable-bootstrap --disable-nls --enable-languages=c
rc=$?
set -e
if [ "$rc" != 0 ]; then
  echo "  FAIL: the supported spelling now fails (rc=$rc)"; tail -3 "$P/g2/e"; fail=1
else
  # The derived value is substituted INLINE into the configure-gcc recipe (it
  # is not a Makefile variable), so read it from there.  Assert the VALUE, not
  # merely that something is present: "non-empty" is the shape that passes on
  # the corrupted artefact (PRINCIPLES section 4).
  got=$(tr ' ' '\n' < "$P/g2/Makefile" | grep -c '^--enable-backends=' || true)
  val=$(tr ' ' '\n' < "$P/g2/Makefile" | grep '^--enable-backends=' | sort -u | tr '\n' ' ')
  echo "  rc=0; occurrences=$got; distinct value(s)= $val"
  [ "$got" -ge 1 ] || { echo "  FAIL: the Makefile names no --enable-backends at all"; fail=1; }
  case "$val" in
    "--enable-backends=aarch64-unknown-linux-gnu,x86_64-pc-linux-gnu ")
      echo "  PASS: exactly ONE distinct derived list, the sorted pair" ;;
    *) echo "  FAIL: distinct derived list(s) = '$val'"; fail=1 ;;
  esac
fi

echo
echo "ARM 3  --enable-backends ALONE -- must name the flag the user TYPED,"
echo "       not '--enable-targets is required' (that was the misleading order)"
set +e
run "$P/g3" --enable-backends=all
rc=$?
set -e
if [ "$rc" = 0 ]; then
  echo "  FAIL: accepted (rc=0)"; fail=1
elif grep -q 'enable-backends is not accepted at the top level' "$P/g3/e"; then
  echo "  PASS: rc=$rc and it names --enable-backends"
else
  echo "  FAIL: rc=$rc, message is:"; tail -4 "$P/g3/e"; fail=1
fi

echo
[ "$fail" = 0 ] && echo "ALL ARMS PASS" || { echo "SOME ARM FAILED"; exit 1; }
