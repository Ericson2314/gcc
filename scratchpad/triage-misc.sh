#!/bin/sh
# riscv word size / Init(...) unconfigured-default sweep, and the testsuite harness.
set -u
cd "$(dirname "$0")/../gcc" || exit 1
echo "=== ix86_pmode Init shape (the riscv-word-size root per PRINCIPLES) ==="
grep -n 'ix86_pmode' config/i386/i386.opt | head
echo
echo "=== Pmode definition sites in the conversion layer ==="
grep -n 'define Pmode' defaults.h multi-target-macros.h config/i386/i386.h 2>/dev/null | head
echo
echo "=== how many .opt Init(...) directives exist across all back ends ==="
grep -rhc 'Init(' config/*/*.opt 2>/dev/null | awk '{s+=$1} END {print s" Init() directives"}'
grep -rl 'Init(' config/*/*.opt 2>/dev/null | wc -l | sed 's/$/ .opt files/'
echo
echo "=== per-target testsuite harness: does one exist? ==="
ls testsuite/lib/multi-target* 2>/dev/null || echo "no testsuite/lib/multi-target* file"
grep -rn 'ftarget-config' testsuite/lib/*.exp 2>/dev/null | head
