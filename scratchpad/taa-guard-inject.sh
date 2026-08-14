#!/bin/sh
# INJECTION FOR GUARDS 5 AND 6 of taa-mtcheck.sh.  An unfired mitigation is
# indistinguishable from an absent one and reads as protection (PRINCIPLES 4),
# so both new arms are run against a deliberately faulty artefact and are
# required to refuse BY NAME, with a passing negative control beside them.
set -u
B=${B:?build dir}
T=${T:?a target whose run finished}
W=${1:-/tmp/b-aa99-inject}
rm -rf "$W"; mkdir -p "$W"
LOG="$B/gcc/testsuite.$T/gcc/gcc.log"
[ -f "$LOG" ] || { echo "FATAL: no $LOG"; exit 9; }

# ARM 1 -- the fault: a log with section 1's banner but NOT section 2's, which
# is exactly what an inert MT_COMPILE_ONLY produces.
grep -v 'MULTI-TARGET RUN: compile-only' "$LOG" > "$W/bad.log"
grep -q 'MULTI-TARGET RUN: target = ' "$W/bad.log" \
  || { echo "FATAL: injection removed too much"; exit 9; }
if grep -q 'MULTI-TARGET RUN: compile-only' "$W/bad.log"; then
  echo "ARM1 FAIL: the injection did not take"; exit 9
fi
echo "ARM1: guard-5 grep on the doctored log -> $(grep -c 'MULTI-TARGET RUN: compile-only' "$W/bad.log") hits (must be 0: guard would REFUSE)"

# ARM 1 negative control -- the real log must still satisfy the same grep.
echo "ARM1-CTL: guard-5 grep on the real log -> $(grep -c 'MULTI-TARGET RUN: compile-only' "$LOG") hits (must be >0: guard passes)"

# ARM 2 -- guard 6: two targets sharing one probe's answer.
VER=$(cat "$B/gcc/BASE-VER" 2>/dev/null || echo 17.0.0)
mkdir -p "$W/a" "$W/b"
cp "$B/lib/gcc/$VER/$T/specs-config" "$W/a/specs-config"
cp "$B/lib/gcc/$VER/$T/specs-config" "$W/b/specs-config"
dup=$(md5sum < "$W/a/specs-config" | cut -d' ' -f1; md5sum < "$W/b/specs-config" | cut -d' ' -f1)
n=$(printf '%s\n' "$dup" | sort | uniq -d | grep -c .)
echo "ARM2: two identical specs-config -> duplicate md5 groups $n (must be 1: guard would REFUSE)"
n2=$(for X in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
       md5sum < "$B/lib/gcc/$VER/$X/specs-config" | cut -d' ' -f1
     done | sort | uniq -d | grep -c .)
echo "ARM2-CTL: the four real specs-config files -> duplicate md5 groups $n2 (must be 0: guard passes)"
