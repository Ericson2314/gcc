#!/bin/sh
# #158 -- did the genmodes change touch SINGLE-TARGET output?
#
# The claim in genmodes.cc is that every part of the fix is inert when
# multi_target_p () is false.  That is a code-reading argument, and this turns
# it into a measurement, cheaply: multi_target_p () is `-A<arch> was given', a
# RUNTIME flag, so the same binaries can be re-run WITHOUT -A and diffed.
#
# BEFORE = build/genmodes-<arch> from the pre-fix snapshot's build dir
# AFTER  = the same program from the post-fix snapshot's build dir
# Run both with no -A and no -U: that is exactly a stock single-target run.
#
# usage: t158-stockmodes.sh <before-builddir> <after-builddir> [arch]
set -e
B=${1:?before build dir}/gcc
A=${2:?after build dir}/gcc
ARCH=${3:-i386}
bg="$B/build/genmodes-$ARCH"
ag="$A/build/genmodes-$ARCH"
for f in "$bg" "$ag"; do
  [ -x "$f" ] || { echo "FATAL: $f is not executable; nothing to compare"; exit 9; }
done
# The two must not be the same file, or the diff is vacuous.
[ "$bg" != "$ag" ] || { echo "FATAL: same path twice"; exit 9; }
echo "before: $bg"
echo "after : $ag"

T=$(mktemp -d)
trap 'rm -rf "$T"' 0
for w in "" h i; do
  "$bg" ${w:+-$w} > "$T/b.${w:-c}" 2> "$T/b.${w:-c}.err" || { echo "FATAL: before genmodes -${w:-c} failed"; cat "$T/b.${w:-c}.err"; exit 9; }
  "$ag" ${w:+-$w} > "$T/a.${w:-c}" 2> "$T/a.${w:-c}.err" || { echo "FATAL: after genmodes -${w:-c} failed"; cat "$T/a.${w:-c}.err"; exit 9; }
  # NON-VACUITY: an empty output would diff clean and prove nothing.
  [ -s "$T/b.${w:-c}" ] && [ -s "$T/a.${w:-c}" ] || { echo "FATAL: -${w:-c} produced an empty file"; exit 9; }
  nb=$(wc -l < "$T/b.${w:-c}"); na=$(wc -l < "$T/a.${w:-c}")
  if cmp -s "$T/b.${w:-c}" "$T/a.${w:-c}"; then
    echo "  -${w:-c} : IDENTICAL  ($nb lines)"
  else
    echo "  -${w:-c} : DIFFERS    ($nb -> $na lines)"
    diff "$T/b.${w:-c}" "$T/a.${w:-c}" | head -20
    rc=1
  fi
done

# NEGATIVE CONTROL: the same two binaries WITH -A must differ, or the
# comparison above is passing because these binaries are indistinguishable
# for some other reason (wrong paths, identical builds, a no-op change).
echo
echo "negative control -- WITH -A the two MUST differ:"
# The C output is the DEFAULT, not `-c'; genmodes has no -c and rejects it.
# Never `2>/dev/null' (PRINCIPLES section 5): an earlier draft swallowed the
# usage message and reported only "produced nothing", which reads as "the
# control cannot fire" rather than "the argv was wrong".
"$bg" -U "$B/modes-union.list" -A "$ARCH" > "$T/b.mt" 2> "$T/b.mt.err" || true
"$ag" -U "$A/modes-union.list" -A "$ARCH" > "$T/a.mt" 2> "$T/a.mt.err" || true
[ -s "$T/b.mt" ] && [ -s "$T/a.mt" ] || {
  echo "  FATAL: multi-target run produced nothing; control cannot fire"
  echo "  before stderr:"; sed 's/^/    /' "$T/b.mt.err"
  echo "  after  stderr:"; sed 's/^/    /' "$T/a.mt.err"
  exit 9; }
if cmp -s "$T/b.mt" "$T/a.mt"; then
  echo "  FAIL: identical WITH -A too -- the fix changed nothing, or these are the same binary"
  exit 1
else
  echo "  ok, differs with -A ($(wc -l < "$T/b.mt") -> $(wc -l < "$T/a.mt") lines)"
fi
exit ${rc:-0}
