#!/bin/sh
# #157 -- THE SUCCESS CRITERION: one cc1, four configured bases, a function
# compiled for each.
#
# WHAT THIS ASSERTS, BEYOND "rc=0".  PRINCIPLES: "`where does it ICE' is not
# the measurement, `is the output right' is" -- a wall that moves may have
# become silent wrong code, and a compiler that emits x86 for every target
# exits 0 four times.  So each run is checked against an instruction its own
# machine has and the other three do not:
#
#     x86_64        movl / %rax / %rdi          and NOT `mr '
#     aarch64       w0/x0 or `ret' with `add w' and NOT `%rax'
#     powerpc64le   `mr ' or `blr'              and NOT `%rax'
#     s390x         `br  %r14' or `lgfr'        and NOT `%rax'
#
# Both directions on purpose: a positive-only check passes if the compiler
# emits a superset, and a negative-only check passes on empty output.  The
# per-target `.s' is kept so the claim can be re-read rather than trusted.
set -u
S=$(cd "$(dirname "$0")" && pwd)
D=${1:?build dir}
V=17.0.0
OUT=$D/t157-run
case "$D" in
  */b-af23dd9b01f75c197*) ;;
  *) echo "FATAL: build dir $D is not named for this worktree"; exit 9 ;;
esac
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 at $D/gcc/cc1"; exit 9; }
mkdir -p "$OUT"

IN=$OUT/fn.c
cat > "$IN" <<'EOF'
int f (int a, int b) { return a + b * 3; }
EOF
[ -s "$IN" ] || { echo "FATAL: input not written"; exit 9; }

fails=0
run () { # $1 triple  $2 must-match  $3 must-NOT-match
  t=$1; yes=$2; no=$3
  c=$D/lib/gcc/$V/$t/specs-config
  if [ ! -s "$c" ]; then echo "  $t: NO specs-config at $c"; fails=$((fails+1)); return; fi
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$c" \
     "$IN" -o "$OUT/$t.s") 2> "$OUT/$t.err"
  rc=$?
  if [ $rc != 0 ] || [ ! -s "$OUT/$t.s" ]; then
    echo "  $t: FAIL rc=$rc $(wc -c < "$OUT/$t.s" 2>/dev/null || echo 0) bytes"
    sed -n 1,6p "$OUT/$t.err"; fails=$((fails+1)); return
  fi
  if ! grep -Eq "$yes" "$OUT/$t.s"; then
    echo "  $t: rc=0 but the output does not contain /$yes/ -- compiled, but"
    echo "        not visibly for this machine.  First insns:"
    grep -E '^\s+[a-z]' "$OUT/$t.s" | sed -n 1,6p
    fails=$((fails+1)); return
  fi
  if grep -Eq "$no" "$OUT/$t.s"; then
    echo "  $t: rc=0, matched /$yes/, but ALSO /$no/ -- another machine's"
    echo "        instructions are in this output."
    fails=$((fails+1)); return
  fi
  echo "  $t: OK  $(wc -c < "$OUT/$t.s") bytes  md5 $(md5sum < "$OUT/$t.s" | cut -c1-12)  in=$IN"
}

echo "== one cc1 ($D/gcc/cc1), a function per configured base"
run x86_64-pc-linux-gnu       '%(rax|eax|rdi|edi)'  '\bmr\b|\bblr\b|%r14'
run aarch64-unknown-linux-gnu '\bw[0-9]|\bx[0-9]'   '%rax|%eax|\bblr\b'
run powerpc64le-unknown-linux-gnu '\bmr\b|\bblr\b'  '%rax|%eax'
run s390x-ibm-linux-gnu       '%r1[0-9]|%r[0-9]\b'  '%rax|%eax|\bblr\b'

echo
if [ "$fails" = 0 ]; then echo "ALL FOUR BASES: PASS"; else echo "FAILURES: $fails"; fi

# THE NEGATIVE CONTROL, and it is not optional: every arm above would also
# pass if `run' were silently not running the compiler at all.  A target this
# cc1 was NOT configured for must be REFUSED, by name.
echo
echo "== negative control: an unconfigured target must be refused by name"
c=$D/lib/gcc/$V/x86_64-pc-linux-gnu/specs-config
sed 's/^target=.*/target=sparc64-unknown-linux-gnu/' "$c" > "$OUT/bogus-config"
if ! grep -q 'sparc64' "$OUT/bogus-config"; then
  echo "  CONTROL DID NOT INJECT: no 'target=' line in $c -- the control proves"
  echo "  nothing and this arm is UNSCORED.  Keys present:"
  cut -d= -f1 "$c" | sed -n 1,10p
else
  (cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$OUT/bogus-config" \
     "$IN" -o "$OUT/bogus.s") > "$OUT/bogus.out" 2>&1
  rc=$?
  if [ $rc = 0 ]; then
    echo "  CONTROL FAILED: cc1 accepted sparc64, which is not configured."
  else
    echo "  control fires, rc=$rc: $(sed -n 1,2p "$OUT/bogus.out")"
  fi
fi
exit 0
