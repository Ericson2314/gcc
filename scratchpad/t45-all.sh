#!/bin/sh
# Task #45/#98 -- BLAST RADIUS.  config.gcc edits reach all 188 targets, but a
# two-target build exercises two arms.  --enable-backends=all sources
# config.gcc once per back end, so it is the check that actually covers the
# file this task edits.
#
# CONFIGURE ONLY -- this does not build.  The acceptance bar is that it
# configures and that the generated per-target makefile fragment contains no
# $(error).
#
# Traps this script is written against, all paid for on this branch:
#  * a configure script can FAIL AND EXIT 0.  So the exit status is recorded
#    but the ARTEFACTS are what is scored.
#  * a 0-line manifest was once produced with configure exiting 0.  So the
#    stanza count is asserted to be plausible, and a small count is fatal.
#  * `| head' once hid a rule from two people.  Nothing here is piped to head.
#  * never 2>/dev/null: stderr goes to a file and is reported.
#
# THE TWO LISTS ARE DELIBERATELY DIFFERENT HERE, AND THIS IS THE ONE SCRIPT IN
# THE CORPUS WHERE THAT IS TRUE.  Everywhere else `--enable-targets' and
# `--enable-backends' carry the same list and conf-repair.sh asserts they do.
# Here they cannot: `--enable-backends=all' is legal and is the entire point of
# this script (source config.gcc once per back end, i.e. the blast radius),
# but `--enable-targets=all' is NOT legal -- the top level runs every element
# through config.sub and fails by name on anything that is not a real triple
# (configure.ac:143).  The two flags mean different things: backends is which
# back ends go INTO the binary, targets is which per-target trees to
# instantiate.  So: all back ends compiled in, two target trees instantiated.
# That is coherent, and it is what this script needs -- the artefact it scores
# is the per-target makefile fragment, which only exists for instantiated
# targets.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
# REFUSE THE WRONG TREE.  This line used to name ANOTHER agent's
# worktree; those trees measure 27-28 `MULTI_TARGET' hits in
# gcc/Makefile.in against this one's 39, so the script configured and
# built a STALE compiler and reported a clean green for it, with no
# diagnostic.  0 hits is the documented bare-repo-HEAD case
# (PRINCIPLES section 5).
grep -q MULTI_TARGET "$SRC/gcc/Makefile.in" || { echo "FATAL: $SRC is not a multi-target tree"; exit 9; }
D=${D:-/tmp/b45all}
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
PKGS="-p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo"

rm -rf "$D"; mkdir -p "$D" || exit 9

nix-shell -I "nixpkgs=$NP" $PKGS --substituters 'https://cache.nixos.org/' --run \
  "cd $D && $SRC/configure --disable-werror --enable-backends=all \
      --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu \
      --disable-bootstrap --disable-nls \
      --with-native-system-header-dir=/nix/store/q5wv2ldpcv5w8yb2wmsngsygvlxb73fk-glibc-2.42-67-dev/include \
      CC=gcc CFLAGS='-O1 -g0 -Wno-error=format-security' \
      CXX=g++ CXXFLAGS='-O1 -g0 -Wno-error=format-security' \
      --enable-languages=c,lto" > "$D/conf.out" 2> "$D/conf.err"
echo "configure rc=$?   (NOT scored on its own: configure can fail and exit 0)"
echo "configure stderr: $(wc -l < "$D/conf.err") lines"
[ -s "$D/conf.err" ] && sed 's/^/    /' < "$D/conf.err"

# gcc/ is configured by the top level.
nix-shell -I "nixpkgs=$NP" $PKGS --substituters 'https://cache.nixos.org/' --run \
  "cd $D && make configure-gcc" > "$D/cg.out" 2> "$D/cg.err"
echo "configure-gcc rc=$?   stderr: $(wc -l < "$D/cg.err") lines"
[ -s "$D/cg.err" ] && sed 's/^/    /' < "$D/cg.err"

M="$D/gcc/multi-target.manifest"
F="$D/gcc/multi-target-common.mk"
for f in "$M" "$F"; do
  [ -s "$f" ] || { echo "FATAL: missing or EMPTY artefact: $f"; exit 9; }
done

# One stanza per target, blank-line separated.
stanzas=$(grep -c '^target ' "$M")
lines=$(wc -l < "$F")
echo "manifest stanzas (grep -c '^target '): $stanzas"
echo "multi-target-common.mk lines: $lines"
if [ "$stanzas" -lt 40 ]; then
  echo "FATAL: only $stanzas stanzas.  A near-empty manifest with configure"
  echo "exiting 0 is a known failure mode here; this run proves nothing."
  exit 9
fi

echo "=== \$(error) in the generated fragment (acceptance: ZERO):"
n=$(grep -c '\$(error' "$F")
echo "    count: $n"
if [ "$n" -ne 0 ]; then grep -n '\$(error' "$F"; echo "FATAL: \$(error) present"; exit 9; fi

echo "=== the arms this task edited, as they came out for real targets:"
echo "--- msp430 stanza gcc_cv_initfini_array is NOT a manifest field; check"
echo "    instead that msp430 and a vms target are present and configured:"
grep -n '^target .*msp430\|^target .*vms' "$M"
echo "OK"
