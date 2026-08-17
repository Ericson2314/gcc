#!/bin/sh
# "COULD THE FOUR HAVE SEEN THIS?" -- asked of the RUNNING compilers, not of
# the headers.
#
# The claim this task exists to test is structural: a leaked assumption is
# invisible from any set of targets that SHARES it.  So for each candidate
# defect, the question is not "does arm differ from i386" but "do
# aarch64/riscv64/s390x/x86_64 all AGREE with i386 here" -- because if they do,
# no board built from those four can contain the observation, at any sample
# size.
#
# Asked by compiling one file per target with the SAME multi-target compiler
# and reading the emitted assembly, so the answer is about what the compiler
# does rather than about what a header says.  A header census would be the
# `mention versus use' trap INSTRUMENTS.md records; here the text is the
# artefact.
#
# usage: B=<47-base build dir> a660907426e03e4e9-fouragree.sh
set -u
B=${B:?set B to the 47-base build dir}
VER=$(cat "$(cat "$B/MY-SRC")/gcc/BASE-VER")
SRC=/tmp/a660-agree.c
printf 'int x[4];\nint f (int a) { return a + 1; }\n' > "$SRC"
printf '%-30s %-14s %-12s %s\n' TARGET '.type-operand' '.align-form' 'skip-form'
for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu \
         s390x-ibm-linux-gnu arm-unknown-linux-gnueabihf; do
  CFG="$B/lib/gcc/$VER/$T/specs-config"
  [ -f "$CFG" ] || { printf '%-30s %s\n' "$T" 'NO specs-config -- NOT MEASURED (not a pass)'; continue; }
  o=/tmp/a660-agree-$T.s
  if ! "$B/gcc/xgcc" -B"$B/gcc/" -ftarget-config="$CFG" -O1 -w -S -o "$o" "$SRC" 2>/dev/null; then
    printf '%-30s %s\n' "$T" 'DID NOT COMPILE -- NOT MEASURED'; continue
  fi
  ty=$(sed -n 's/.*\.type[ \t]*x,[ \t]*//p' "$o" | head -1)
  al=$(grep -m1 -oE '\.align[ \t]*[0-9]+' "$o" | tr -s ' \t' ' ')
  sk=$(grep -m1 -oE '\.(space|zero|skip)[ \t]*[0-9]+' "$o" | tr -s ' \t' ' ')
  printf '%-30s %-14s %-12s %s\n' "$T" "${ty:-<none>}" "${al:-<none>}" "${sk:-<none>}"
done
echo
echo "Read the first column: if the four LP64 rows all print the SAME token and"
echo "arm prints a different one, then NO board built from those four could"
echo "have contained the observation -- which is the point, not a coverage"
echo "preference."
