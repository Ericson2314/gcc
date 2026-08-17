#!/bin/sh
# t246-asfind.sh -- the four-arm acceptance test for `just_machine_prefix'.
#
# THE DEFECT: find_a_program has a machine-prefixed search pass
# (gcc/gcc.cc:3268) whose prefix, just_machine_prefix, was assigned in exactly
# one place -- to "".  The pass therefore ran on every lookup and could never
# match: a cross compile reached `as' and died `cannot execute as', because a
# cross binutils installs <triple>-as and only `as' was ever tried.
#
# WHY THE PATH IS BUILT BY HAND AND NOT INHERITED.  The whole question is
# WHICH NAME the driver looked for, and an ambient PATH carrying both a
# prefixed and an unprefixed `as' cannot answer it -- either result is
# consistent with either behaviour.  Each arm gets a PATH containing exactly
# one directory whose contents we chose, so a hit names the name.
#
# WHY REAL CROSS BINUTILS AND NOT A SHIM.  A shell script named
# `<triple>-as' would prove the driver found A FILE, not that it found an
# assembler; and the host triple would pass arm 1 for the wrong reason,
# because the prefix would then match the directory the host tools are in
# anyway.  aarch64-unknown-linux-gnu-as is the genuine nixpkgs cross
# assembler and its prefix is nowhere in the host's names.
#
# WHY `-###' AND NOT A COMPILE.  -### prints the argv the driver RESOLVED,
# including the absolute path it picked for the assembler, and does not run
# it.  A successful compile would prove something ran; the resolved path is
# the actual claim.  Arm 5 re-runs the identical commands against a driver
# built from the unfixed source, so every line below has a counterfactual.
#
# usage: t246-asfind.sh <builddir> <xgcc> <tag>
set -u
D=${1:?build dir}
XGCC=${2:?xgcc to test}
TAG=${3:?tag}
T=aarch64-unknown-linux-gnu
V=$(cat "$(cat "$D/MY-SRC")"/gcc/BASE-VER)
CFG="$D/lib/gcc/$V/$T/specs-config"
[ -s "$CFG" ] || { echo "FATAL: no specs-config at $CFG" >&2; exit 9; }
[ -x "$XGCC" ] || { echo "FATAL: no $XGCC" >&2; exit 9; }

W=${TMPDIR:-/tmp}/t246-$TAG
rm -rf "$W"; mkdir -p "$W/pre" "$W/plain" "$W/both"

# The real cross assembler, by store path, so nothing here can silently fall
# back to the host's.
XAS=${T246_XAS:?set T246_XAS to the <triple>-as absolute path}
NAS=${T246_NAS:?set T246_NAS to the unprefixed host as absolute path}
[ -x "$XAS" ] || { echo "FATAL: $XAS not executable" >&2; exit 9; }
[ -x "$NAS" ] || { echo "FATAL: $NAS not executable" >&2; exit 9; }

# Arm 1: ONLY <triple>-as reachable.
ln -s "$XAS" "$W/pre/$T-as"
# Arm 2: ONLY unprefixed as reachable.
ln -s "$NAS" "$W/plain/as"
# Arm 3: BOTH, in one directory, so directory order cannot decide it and only
# the name can.
ln -s "$XAS" "$W/both/$T-as"
ln -s "$NAS" "$W/both/as"

echo "int f (int x) { return x + 1; }" > "$W/t.c"

# THE FIRST VERSION OF THIS TEST COULD NOT FAIL, and the reason is worth
# keeping: `-B$D/gcc/' puts the BUILD DIRECTORY on the exec prefixes, and
# GCC's own build writes a 3841-byte shell wrapper called `$D/gcc/as' there
# (beside `collect-ld').  All three arms resolved to THAT, identically, so
# PATH never entered into it and the fix and the defect gave the same output.
# So -B points at a directory holding cc1 ALONE -- the compiler proper, which
# the driver must still find -- and nothing named `as' is reachable except
# through PATH, which is what each arm is varying.
mkdir -p "$W/bdir"
ln -s "$D/gcc/cc1" "$W/bdir/cc1"
[ -e "$W/bdir/as" ] && { echo "FATAL: -B dir has an as" >&2; exit 9; }

run () {
  _arm=$1; _dir=$2
  echo "--- arm $_arm: PATH=$_dir  ($(ls "$_dir" | tr '\n' ' '))"
  PATH="$_dir" "$XGCC" -B"$W/bdir/" -ftarget-config="$CFG" \
    -c "$W/t.c" -o "$W/t-$_arm.o" '-###' > "$W/$_arm.out" 2> "$W/$_arm.err"
  echo "    rc=$?"
  # The line that RESOLVED the assembler.  -### quotes each argv element; the
  # first element of the `as' command is the path the driver picked.
  grep -o '[^ "]*as[^ "]*' "$W/$_arm.err" | grep -v '^-' | grep '/' \
    | sed 's/^/    resolved: /' | sort -u
  grep -i "cannot execute\|not found\|error" "$W/$_arm.err" \
    | sed 's/^/    DIAG: /' | head -3
}

run prefixed "$W/pre"
run plain    "$W/plain"
run both     "$W/both"
