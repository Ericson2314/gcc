#!/bin/sh
# TASKS 249/261 IDENTITY HARNESS.  Run `target-specs/configure' standalone for
# three targets and snapshot each `specs-config'.  Run it once BEFORE the
# change and once AFTER; the two trees must be byte-identical.  This is a
# refactor: any difference is a defect, not an improvement.
#
# Two of the three targets have REAL cross binutils in mt-hdr/tools/bin; the
# third (the build machine's own triple) is probed with the host's `as', which
# is legitimate HERE because both runs probe the SAME tools -- the question
# this harness asks is whether the DERIVATION changed, not whether the probe
# is right.  x86_64 is also the arm that matters most: it is NOT in
# mt-hdr's manifest, so after the change its values can only have come from
# config.gcc.
#
# ${AA_EXTRA}/${AR_EXTRA}/${X8_EXTRA} are ONE string each and are eval'd, not
# word-split: `--with-option-defaults=cpu=arm10e float=hard tls=gnu' is a
# single argument in the top-level rule, and splitting it drops every pair
# after the first WITH NO DIAGNOSTIC -- autoconf ignores an unknown `--with-'.
#
# usage: a302b44ba-t249-specsid.sh <outdir> [extra configure args...]
set -eu
SRC=/home/jcericson/src/gnu/gcc/multi-target
TOOLS=/home/jcericson/src/gnu/gcc/build/mt-hdr/tools/bin
O=${1:?outdir}; shift
mkdir -p "$O"

run () { # $1 = triple, $2 = extras as ONE eval'd string, $3.. = plain args
  t=$1; extra=$2; shift 2
  d="$O/$t"; rm -rf "$d"; mkdir -p "$d"
  eval "set -- \"\$@\" $extra"
  ( cd "$d" && "$SRC/target-specs/configure" \
      --srcdir="$SRC/target-specs" \
      --build=x86_64-pc-linux-gnu --host="$t" \
      --with-target="$t" \
      --with-specs-file="$d/specs" \
      "$@" > configure.out 2>&1 ) \
    || { echo "FAIL $t rc=$?"; tail -25 "$d/configure.out"; return 1; }
  test -f "$d/specs-config" || { echo "FAIL $t: no specs-config"; return 1; }
  # BOTH artefacts.  `specs-config' is cc1's runtime target config; the SPEC
  # FILE is where `*option_defaults' lands, so a harness that hashed only
  # specs-config would be blind to the very key this change re-derives --
  # measured: mangling --with-option-defaults left specs-config's md5
  # untouched.
  test -f "$d/specs" || { echo "FAIL $t: no specs"; return 1; }
  printf '%-36s specs-config %4s lines md5 %s   specs %4s lines md5 %s\n' "$t" \
    "$(wc -l < "$d/specs-config")" "$(md5sum < "$d/specs-config" | cut -c1-16)" \
    "$(wc -l < "$d/specs")" "$(md5sum < "$d/specs" | cut -c1-16)"
}

rc=0
run aarch64-unknown-linux-musl        "${AA_EXTRA:-}" --with-tools-dir="$TOOLS" "$@" || rc=1
run armv6l-unknown-linux-gnueabihf    "${AR_EXTRA:-}" --with-tools-dir="$TOOLS" "$@" || rc=1
run x86_64-pc-linux-gnu               "${X8_EXTRA:-}" "$@" || rc=1
echo "rc=$rc"
exit $rc
