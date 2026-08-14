#!/bin/sh
# "Mechanism present but never invoked" check for the per-target testsuite harness.
set -u
cd "$(dirname "$0")/../gcc/testsuite" || exit 1
echo "=== who loads multi-target.exp ==="
grep -rn 'multi-target' lib/*.exp *.exp 2>/dev/null | grep -v '^lib/multi-target.exp' | head -20
echo
echo "=== MT_TARGET_NAME readers ==="
grep -rn 'MT_TARGET_NAME' . 2>/dev/null | head -20
echo
echo "=== is it reachable from the Makefile / site.exp path ==="
grep -rn 'multi-target\|MT_TARGET' ../Makefile.in 2>/dev/null | head
