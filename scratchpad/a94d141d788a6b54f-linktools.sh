#!/bin/sh
# a94d141d788a6b54f-linktools.sh -- present an existing tools dir in the
# `<dir>/bin/<triple>-as' layout `a7ee6ca7c923e4a58-specsN.sh' expects, BY
# SYMLINK.
#
# SYMLINK, NEVER COPY, and this is the whole reason the script exists rather
# than a `cp -a'.  `A7D26223EEFCFA725-BOARD.md' recorded "45 cross `as', every
# one EXECUTED"; re-run later, 8 of the 45 died with
# `error while loading shared libraries: libopcodes-2.46.so', because they had
# been gathered by COPY out of nix store paths and a copy leaves the store's
# shared libraries behind.  "Every one executed" was true when taken and is not
# a property a copy keeps.  A symlink keeps the binary in its store output,
# where its RUNPATH still resolves.
#
# usage: a94d141d788a6b54f-linktools.sh <src tools dir> <dest dir>
# Exits 9 unless every linked assembler EXECUTES afterwards -- an unusable
# assembler and bad assembly produce the same rc downstream.
set -eu
S=${1:?source tools dir}
D=${2:?destination dir}
W=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$D/bin"
n=0
for f in "$S"/*-as; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$D/bin/$(basename "$f")"
  n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "FATAL: no *-as under $S -- NULL RESULT, not a pass"; exit 9; }
echo "linked $n assemblers into $D/bin"
exec sh "$W/a94d141d788a6b54f-asexec.sh" "$D/bin"
