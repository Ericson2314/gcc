#!/bin/sh
# Re-read the four stock control gcc.sum files and print PASS/FAIL, so the
# brief's figures are VERIFIED rather than quoted.  A missing summary marker is
# a refusal: a truncated .sum greps clean.
set -u
export LC_ALL=C
X=/tmp/b-stock-agent-ab1900d5279ba137f-x86_64/gcc/testsuite.x86_64-pc-linux-gnu/gcc/gcc.sum
A=/tmp/b-stock-agent-a3464debf6893de84-aarch64/gcc/testsuite.aarch64-unknown-linux-gnu/gcc/gcc.sum
R=/tmp/b-stock-agent-ab1900d5279ba137f-riscv64/gcc/testsuite.riscv64-unknown-linux-gnu/gcc/gcc.sum
S=/tmp/b-stock-agent-a3464debf6893de84-s390x/gcc/testsuite.s390x-ibm-linux-gnu/gcc/gcc.sum
for f in "$X" "$A" "$R" "$S"; do
  [ -f "$f" ] || { echo "FATAL: no $f"; exit 9; }
  grep -q '=== gcc Summary' "$f" || { echo "FATAL: $f truncated (no summary marker)"; exit 9; }
  p=$(grep -c '^PASS:' "$f")
  n=$(grep -c '^FAIL:' "$f")
  echo "$p / $n   $f"
done
