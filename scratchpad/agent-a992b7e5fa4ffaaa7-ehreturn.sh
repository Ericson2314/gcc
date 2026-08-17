#!/bin/sh
# Both-sided: does `__builtin_eh_return' work on each scored target?
#
# THIS SCRIPT HARDCODED `B=/tmp/b-a992b7e5fa4ffaaa7' -- ANOTHER WORKTREE'S
# BUILD DIR.  That is the FOREIGN-SRC defect PRINCIPLES section 4 records at
# length: 485 of 506 scripts on this branch name someone else's tree, the line
# was correct when written and became foreign the moment the file was
# committed and inherited.  Run from a later worktree it would have measured a
# compiler that is not the one under test -- or, once that directory is
# cleaned up, printed `rc=127' four times, which reads as "the targets fail".
#
# It also had no non-vacuity arm and no control.  `rc=1' on all four and
# "xgcc is missing" produce the same table.
#
# usage: agent-a992b7e5fa4ffaaa7-ehreturn.sh <mt-builddir>
#          [stock-aarch64] [stock-s390x] [stock-x86_64] [stock-riscv64]
set -u
B=${1:?mt build dir -- do NOT default this, see the header}
SA=${2:-/tmp/b-stock-agent-a3464debf6893de84-aarch64}
SS=${3:-/tmp/b-stock-agent-a3464debf6893de84-s390x}
SX=${4:-/tmp/b-stock-agent-ab1900d5279ba137f-x86_64}
SR=${5:-/tmp/b-stock-agent-ab1900d5279ba137f-riscv64}
SRC=$(cd "$(dirname "$0")" && pwd)/agent-a992b7e5fa4ffaaa7-ehreturn.c
[ -f "$SRC" ] || { echo "FATAL: no $SRC"; exit 9; }
[ -x "$B/gcc/xgcc" ] || { echo "FATAL: no $B/gcc/xgcc"; exit 9; }
[ -r "$B/MY-SRC" ] || { echo "FATAL: no $B/MY-SRC -- cannot say which tree this is"; exit 9; }
echo "mt build   $B"
echo "mt srcdir  $(cat "$B/MY-SRC")"
echo

# NON-VACUITY ON THE INSTRUMENT.  A build dir with no cc1, a missing
# specs-config and a genuine target failure all give a nonzero rc; compile
# something that MUST succeed on every target first, so a later rc=1 is a
# statement about the builtin.
ok=0
for T in aarch64-unknown-linux-gnu s390x-ibm-linux-gnu \
         x86_64-pc-linux-gnu riscv64-unknown-linux-gnu; do
  [ -r "$B/lib/gcc/17.0.0/$T/specs-config" ] || continue
  printf 'int mt_ctl (int x) { return x + 1; }\n' > "/tmp/ehctl-$T.c"
  if "$B/gcc/xgcc" -B"$B/asdir-$T/" -B"$B/gcc/" \
       -ftarget-config="$B/lib/gcc/17.0.0/$T/specs-config" \
       -S -O2 "/tmp/ehctl-$T.c" -o "/tmp/ehctl-$T.s" 2> "/tmp/ehctl-$T.err"; then
    ok=$((ok + 1))
  else
    echo "FATAL: control 'int f(int x){return x+1;}' FAILED for $T:"
    head -3 "/tmp/ehctl-$T.err"
    echo "       Nothing below would be a statement about __builtin_eh_return."
    exit 9
  fi
done
[ "$ok" -ge 2 ] \
  || { echo "FATAL: only $ok targets had a specs-config -- the arm read nothing"; exit 9; }
echo "control  'int f(int x){return x+1;}' compiles on $ok/4 targets   OK"
echo

stock_for () {
  case $1 in
    aarch64-*) echo "$SA" ;; s390x-*) echo "$SS" ;;
    x86_64-*)  echo "$SX" ;; riscv64-*) echo "$SR" ;;
  esac
}

fail=0
for T in aarch64-unknown-linux-gnu s390x-ibm-linux-gnu \
         x86_64-pc-linux-gnu riscv64-unknown-linux-gnu; do
  printf '%-28s ' "$T"
  if [ ! -r "$B/lib/gcc/17.0.0/$T/specs-config" ]; then
    echo "SKIP (no specs-config)"; continue
  fi
  "$B/gcc/xgcc" -B"$B/asdir-$T/" -B"$B/gcc/" \
    -ftarget-config="$B/lib/gcc/17.0.0/$T/specs-config" \
    -S -O2 "$SRC" -o "/tmp/ehret-$T.s" 2> "/tmp/ehret-$T.err"
  rc=$?

  # THE CONTROL IS GENUINE STOCK, not a remembered expectation.  Upstream
  # supports the builtin on all four; showing multi-target rc=0 proves nothing
  # about whether it emitted the right thing.
  S=$(stock_for "$T")
  if [ -x "$S/gcc/xgcc" ]; then
    "$S/gcc/xgcc" -B"$S/gcc/" -S -O2 "$SRC" -o "/tmp/ehret-stock-$T.s" \
      2> "/tmp/ehret-stock-$T.err"
    src=$?
    if [ "$rc" = "$src" ] && [ "$rc" = 0 ]; then
      grep -v '^[[:space:]]*\.' "/tmp/ehret-stock-$T.s" > "/tmp/ehret-stock-$T.body"
      grep -v '^[[:space:]]*\.' "/tmp/ehret-$T.s"       > "/tmp/ehret-$T.body"
      n=$(grep -c . "/tmp/ehret-stock-$T.body")
      if [ "$n" -lt 3 ]; then
        printf 'VOID  stock body is %s lines -- arm read nothing\n' "$n"; fail=$((fail+1))
      elif diff -q "/tmp/ehret-stock-$T.body" "/tmp/ehret-$T.body" > /dev/null; then
        printf 'rc=0  IDENTICAL to stock over %s body lines\n' "$n"
      else
        printf 'rc=0  DIFFERS from stock (see /tmp/ehret-%s.body)\n' "$T"; fail=$((fail+1))
      fi
    else
      printf 'rc=%s (stock rc=%s)  %s\n' "$rc" "$src" "$(head -1 "/tmp/ehret-$T.err")"
      [ "$rc" = "$src" ] || fail=$((fail+1))
    fi
  else
    printf 'rc=%s  %s   (no stock at %s)\n' "$rc" "$(head -1 "/tmp/ehret-$T.err")" "$S"
    [ "$rc" = 0 ] || fail=$((fail+1))
  fi
done

echo
[ "$fail" = 0 ] && echo "ALL TARGETS MATCH STOCK" || echo "$fail target(s) disagree with stock"
exit "$fail"
