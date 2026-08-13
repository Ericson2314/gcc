#!/bin/sh
# Run target-specs/configure post-build, once per target, the way the user is
# meant to.  `make target-specs' no longer exists in gcc/ (by design: see
# PRINCIPLES 2 -- target-specs runs AFTER gcc is built, as its own configure),
# so rv-specs.sh, which drives that rule, is stale.
#
# x86_64 is the host, so plain as/ld are the right tools and are found.
# aarch64 needs aarch64-unknown-linux-gnu-as/-ld; when they are absent the
# probes all answer "no" QUIETLY, so this script requires the caller to say
# which targets to do and reports what it found rather than guessing.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b78}
SRC=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a4f7386f72ea30a8c
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
T=${T:-x86_64-pc-linux-gnu}

[ -d "$D/gcc" ] || { echo "FATAL: no $D/gcc"; exit 9; }
for f in "$D/gcc/specs-src-$T" "$D/gcc/mlib-specs-$T"; do
  [ -f "$f" ] || { echo "FATAL: missing source-derived half $f (run 'make multi-target-specs')"; exit 9; }
done

mkdir -p "$D/ts-$T" || exit 9
nix-shell -I "nixpkgs=$NP" \
  -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo binutils \
  --substituters 'https://cache.nixos.org/' \
  --run "cd $D/ts-$T && $SRC/target-specs/configure --with-target=$T \
      --with-specs-file=$D/gcc/specs-$T \
      --with-source-specs='$D/gcc/specs-src-$T $D/gcc/mlib-specs-$T'"
rc=$?
echo "configure rc=$rc"
[ $rc -eq 0 ] || exit $rc

# The artefact, not the exit status (PRINCIPLES 5).
for f in "$D/gcc/specs-$T" "$D/gcc/specs-$T-config"; do
  if [ -s "$f" ]; then
    echo "ok: $f  ($(wc -l < "$f") lines)"
  else
    echo "FATAL: $f is missing or empty"; rc=9
  fi
done
exit $rc
