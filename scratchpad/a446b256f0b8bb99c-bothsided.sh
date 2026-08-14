#!/bin/sh
# a446b256f0b8bb99c-bothsided.sh -- the both-sided arm for this task.
#
# An aarch64 fix must leave x86_64 BYTE-IDENTICAL, and aarch64 must actually
# move; one-sided evidence cannot distinguish "fixed" from "everyone now gets
# the same new answer".  Compares the reproducer outputs from the BEFORE and
# AFTER build dirs file by file, and states which side each result is on.
set -eu
B=${1:?before output dir}
A=${2:?after output dir}
fail=0; moved=0; same=0
for f in cv-x86_64.s cv-x86_64-pic.s cv-aarch64.s cv-aarch64-pic.s \
         cfi-x86_64.s cfi-aarch64.s; do
  bf=$B/$f; af=$A/$f
  case $f in *x86_64*) side=CONTROL ;; *) side=SUBJECT ;; esac
  if [ ! -f "$bf" ] && [ ! -f "$af" ]; then
    printf '%-8s %-18s absent both sides\n' "$side" "$f"; continue
  fi
  if [ ! -f "$bf" ]; then
    printf '%-8s %-18s APPEARED (before: none -- the ICE produced no output)\n' \
      "$side" "$f"; moved=$((moved+1)); continue
  fi
  if [ ! -f "$af" ]; then
    printf '%-8s %-18s DISAPPEARED -- regression\n' "$side" "$f"; fail=1; continue
  fi
  if cmp -s "$bf" "$af"; then
    printf '%-8s %-18s identical  md5 %s\n' "$side" "$f" \
      "$(md5sum < "$bf" | cut -c1-12)"
    same=$((same+1))
    [ "$side" = SUBJECT ] || true
  else
    printf '%-8s %-18s DIFFERS    %s -> %s\n' "$side" "$f" \
      "$(md5sum < "$bf" | cut -c1-12)" "$(md5sum < "$af" | cut -c1-12)"
    moved=$((moved+1))
    if [ "$side" = CONTROL ]; then
      echo "  ^^ FATAL: an aarch64 fix moved x86_64"; fail=1
    fi
  fi
done
echo "-- moved=$moved unchanged=$same"
# NON-VACUITY: if NOTHING moved, the comparison proves nothing -- that is the
# "both lists came out empty" shape.  A pass REQUIRES at least one subject-side
# movement as well as an unmoved control.
[ "$moved" -gt 0 ] || { echo "FATAL: nothing moved at all -- arm is vacuous"; exit 9; }
[ "$same" -gt 0 ] || { echo "FATAL: nothing stayed the same -- no control"; exit 9; }
[ "$fail" = 0 ] || { echo "FATAL: control side moved"; exit 9; }
echo "PASS: subject moved, control byte-identical"
