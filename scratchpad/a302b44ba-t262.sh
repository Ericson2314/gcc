#!/bin/sh
# t262 -- acceptance for the silent-structural-default work.
#
# WHAT THIS DOES AND DOES NOT MEASURE.  It runs target-specs/configure against
# the BUILD MACHINE's as/ld with --host=x86_64.  For a probed key that would be
# a lie (#113b: a file naming aarch64 while describing x86_64).  Every assertion
# below is about a key that is PASSED IN rather than probed -- decimal_float,
# decimal_bid_format, s390_excess_float_precision, shared_libgcc, libatomic --
# so the toolchain identity is not load-bearing here.  The one probed thing it
# touches is `*libgcc_variants', whose two forms are pure text selected by
# --with-shared-libgcc.
#
# BOTH DIRECTIONS, EVERY ARM.  Turning all six on is the same defect with the
# sign flipped; that is what the riscv64 control caught for decimal float.
set -u
SRC=/home/jcericson/src/gnu/gcc/multi-target
W=${TMPDIR:-/tmp}/t262; rm -rf "$W"; mkdir -p "$W"
fail=0
pass=0
ck () { # ck <name> <expected: ok|err> <run-dir> <extra args...>
  n=$1; want=$2; d=$3; shift 3
  mkdir -p "$W/$d"
  ( cd "$W/$d" && CONFIG_SITE=no-such-file sh "$SRC/target-specs/configure" \
      --srcdir="$SRC/target-specs" --host=x86_64-pc-linux-gnu \
      --with-specs-file="$W/$d/specs" "$@" ) > "$W/$d/out" 2>&1
  rc=$?
  if test "$want" = ok && test "$rc" -ne 0; then
    echo "FAIL $n: expected success, rc=$rc"; tail -3 "$W/$d/out"; fail=`expr $fail + 1`; return 1
  fi
  if test "$want" = err && test "$rc" -eq 0; then
    echo "FAIL $n: expected an ERROR and configure exited 0"; fail=`expr $fail + 1`; return 1
  fi
  pass=`expr $pass + 1`; echo "ok   $n (rc=$rc)"; return 0
}
line () { # line <name> <file> <regexp> -- must match
  if grep -q "$3" "$2" 2>/dev/null; then pass=`expr $pass + 1`; echo "ok   $1"
  else echo "FAIL $1: no /$3/ in $2"; fail=`expr $fail + 1`; fi
}
noline () {
  if grep -q "$3" "$2" 2>/dev/null; then echo "FAIL $1: /$3/ present in $2"; fail=`expr $fail + 1`
  else pass=`expr $pass + 1`; echo "ok   $1"; fi
}

BASE="--with-target=x86_64-pc-linux-gnu --with-decimal-float=1 --with-decimal-bid-format=1"

echo "--- A. decimal float, both directions (the key that was 0 everywhere)"
ck A1-on ok df-on --with-target=x86_64-pc-linux-gnu \
  --with-decimal-float=1 --with-decimal-bid-format=1
line A1-key "$W/df-on/specs-config" '^decimal_float 1$'
line A1-bid "$W/df-on/specs-config" '^decimal_bid_format 1$'
# THE HOST TRIPLE, not another one.  With no armv6l `as' on PATH, configure
# takes its `target tools unavailable, nothing probed' arm and deliberately
# writes NO FILE -- so naming a foreign triple here measures that arm instead of
# this key, and the first version of this script did exactly that and read as a
# regression.  It is also why the top-level rule tests for the FILE and not for
# the exit status.
ck A2-off ok df-off --with-target=x86_64-pc-linux-gnu \
  --with-decimal-float=0 --with-decimal-bid-format=0
line A2-key "$W/df-off/specs-config" '^decimal_float 0$'
line A2-bid "$W/df-off/specs-config" '^decimal_bid_format 0$'

echo "--- B. an UNSTATED structural option now refuses, rather than writing 0"
ck B1-unstated-df err df-none --with-target=x86_64-pc-linux-gnu \
  --with-decimal-bid-format=1
line B1-msg "$W/df-none/out" 'with-decimal-float=0|1 is required'
ck B2-unstated-dbf err dbf-none --with-target=x86_64-pc-linux-gnu \
  --with-decimal-float=1
line B2-msg "$W/dbf-none/out" 'with-decimal-bid-format=0|1 is required'
ck B3-bogus-df err df-bogus $BASE --with-decimal-float=maybe
line B3-msg "$W/df-bogus/out" "must be .0. or .1., not .maybe."

echo "--- C. shared libgcc, both directions"
ck C1-yes ok slg-yes $BASE --with-shared-libgcc=yes
line C1-shared "$W/slg-yes/specs" 'lgcc_s'
line C1-eh "$W/slg-yes/specs" 'lgcc_eh'
ck C2-no ok slg-no $BASE --with-shared-libgcc=no
noline C2-nolgccs "$W/slg-no/specs" 'lgcc_s'
ck C3-bogus err slg-bogus $BASE --with-shared-libgcc=maybe

echo "--- D. libatomic, both directions plus the third value"
ck D1-yes ok la-yes $BASE --with-libatomic=yes
line D1-latomic "$W/la-yes/specs" 'latomic'
ck D2-no ok la-no $BASE --with-libatomic=no
noline D2-nolatomic "$W/la-no/specs" 'latomic'
ck D3-bogus err la-bogus $BASE --with-libatomic=maybe
line D3-msg "$W/la-bogus/out" 'must be .yes. or .no., not .maybe.'

echo "--- E. s390 excess float precision: required ON s390, defaulted OFF it"
ck E1-nons390-unstated ok s390-off $BASE
line E1-zero "$W/s390-off/specs-config" '^s390_excess_float_precision 0$'
ck E2-s390-unstated err s390-req --with-target=s390x-ibm-linux-gnu \
  --with-decimal-float=1 --with-decimal-bid-format=1
line E2-msg "$W/s390-req/out" 'is required for s390x-ibm-linux-gnu'
ck E3-s390-stated ok s390-on $BASE --with-s390-excess-float-precision=1
line E3-one "$W/s390-on/specs-config" '^s390_excess_float_precision 1$'

echo "--- F. linker build id, both directions plus the third value"
ck F1-off ok lbi-off $BASE
ck F2-on ok lbi-on $BASE --enable-linker-build-id
ck F3-bogus err lbi-bogus $BASE --enable-linker-build-id=n
line F3-msg "$W/lbi-bogus/out" 'takes no argument'

echo "--- G. sjlj tri-state: unstated is DISTINGUISHABLE from an explicit no"
line G1-unstated "$W/df-on/specs-config" '^sjlj_exceptions -1$'
ck G2-no ok sjlj-no $BASE --disable-sjlj-exceptions
line G2-zero "$W/sjlj-no/specs-config" '^sjlj_exceptions 0$'
ck G3-yes ok sjlj-yes $BASE --enable-sjlj-exceptions
line G3-one "$W/sjlj-yes/specs-config" '^sjlj_exceptions 1$'

echo "--- H. specs-config shape unchanged (predicted BEFORE measuring: 232/224)"
for d in df-on df-off s390-on; do
  echo "  $d: wc -l `wc -l < "$W/$d/specs-config"`  grep -c . `grep -c . "$W/$d/specs-config"`"
done

echo "--- I. check-target-caps.sh fails on an ABSENT structural key"
mkdir -p "$W/caps"
cp "$W/df-on/specs-config" "$W/caps/full"
grep -v '^decimal_float ' "$W/df-on/specs-config" > "$W/caps/nodf"
if sh "$SRC/gcc/check-target-caps.sh" "$SRC/gcc" "$W/caps/full" > "$W/caps/full.out" 2>&1
then pass=`expr $pass + 1`; echo "ok   I1 complete config accepted"
else echo "FAIL I1: complete config REJECTED"; tail -5 "$W/caps/full.out"; fail=`expr $fail + 1`; fi
if sh "$SRC/gcc/check-target-caps.sh" "$SRC/gcc" "$W/caps/nodf" > "$W/caps/nodf.out" 2>&1
then echo "FAIL I2: config with decimal_float REMOVED was accepted"; fail=`expr $fail + 1`
else pass=`expr $pass + 1`; echo "ok   I2 missing decimal_float rejected"
     grep -i 'ABSENT' "$W/caps/nodf.out" | head -2; fi

echo
echo "t262: $pass ok, $fail FAIL"
test "$fail" -eq 0
