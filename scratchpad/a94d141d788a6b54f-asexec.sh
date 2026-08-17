#!/bin/sh
# a94d141d788a6b54f-asexec.sh -- ASSERT EACH CROSS `as' ACTUALLY EXECUTES.
#
# WHY THIS EXISTS AS ITS OWN INSTRUMENT.  `A7D26223EEFCFA725-BOARD.md' records
# "45 cross `as', canonical names, every one EXECUTED".  That claim measured
# FALSE when re-run: 8 of the 45 die with
#
#   error while loading shared libraries: libopcodes-2.46.so
#
# because the tool directory was populated by COPYING binaries out of nix store
# paths, and a copy leaves the store's shared libraries behind.  "Every one
# executed" was true when taken and is not a property a copy keeps.
#
# The consequence is the exact null-result confusion PRINCIPLES is about: a
# BROKEN ASSEMBLER and BAD ASSEMBLY give the SAME nonzero rc from the same
# command line.  So no verdict of the form "back end X emits assembly its own
# assembler rejects" may be reported until this script says OK for X.
#
# `--version' and not `-v': `as -v' on some targets waits on stdin.
#
# usage: a94d141d788a6b54f-asexec.sh <tools-dir> [<prefix>...]
#   With no prefixes, every `*-as' in the directory is checked.
#   Exit 0 only if every checked assembler EXECUTED.  Exit 9 if the directory
#   holds no `*-as' at all -- an empty sweep printing "0 dead" is the null
#   result this script exists to make impossible.
set -u
T=${1:?tools dir}
shift
if [ $# -gt 0 ]; then
  LIST=
  for p in "$@"; do LIST="$LIST $T/$p-as"; done
else
  LIST=$(ls "$T"/*-as 2>/dev/null)
fi

n=0; ok=0; dead=0; missing=0
for a in $LIST; do
  n=$((n + 1))
  b=$(basename "$a")
  if [ ! -x "$a" ]; then
    echo "MISSING $b"
    missing=$((missing + 1))
    continue
  fi
  out=$("$a" --version 2>&1)
  if [ $? -eq 0 ]; then
    echo "OK      $b   $(printf '%s' "$out" | head -1)"
    ok=$((ok + 1))
  else
    echo "DEAD    $b   $(printf '%s' "$out" | head -1)"
    dead=$((dead + 1))
  fi
done

echo "asexec: checked=$n ok=$ok dead=$dead missing=$missing"
if [ "$n" = 0 ]; then
  echo "FATAL: no assembler was checked at all -- this is a NULL RESULT, not a pass"
  exit 9
fi
[ "$dead" = 0 ] && [ "$missing" = 0 ]
