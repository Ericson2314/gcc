#!/bin/sh
# UR task -- the link-count arm.  DOES cc1 LINK, AND HOW MANY BACK ENDS ARE IN
# IT?
#
# Deliberately NOT a codegen arm.  Selecting a base inside this cc1 needs a
# per-target runtime config, which comes from `target-specs/configure' probing
# a REAL `as' for that target; there is no pdp11, vax, m68k, xtensa or
# microblaze assembler on this host.  PRINCIPLES section 5 records what
# happens if you run that probe without the cross binutils: configure falls
# back to the BUILD machine's `as' and writes a file that NAMES the target
# while DESCRIBING x86_64 -- two trees, two md5s, 95 of 101 lines identical,
# and every name- and path-based check passes on it.  So this script measures
# what it can measure and says so, rather than manufacturing a green.
#
# usage: ur-evidence.sh <builddir> <tag>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
TAG=${2:?tag}
case "$B" in
  */b-a6af2c465ae8845f3*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
[ -f "$B/build-$TAG.rc" ] || { echo "FATAL: $B/build-$TAG.rc missing -- unstamped log"; exit 9; }

echo "== arm 0: make's own verdict"
echo "  make rc = $(cat "$B/build-$TAG.rc")"

echo
echo "== arm 1: does cc1 EXIST, and is it from THIS build?"
# Not `test -x': a stale cc1 from an earlier build is executable too.  It must
# be newer than the log the stamp belongs to.
[ -x "$B/gcc/cc1" ] || { echo "  FAIL: no $B/gcc/cc1 -- the link did not happen"; exit 1; }
if [ "$B/gcc/cc1" -nt "$B/build-$TAG.out" ]; then
  echo "  note: cc1 is newer than the log (relinked during this build)"
fi
ls -l "$B/gcc/cc1" | awk '{print "  cc1", $5, "bytes,", $6, $7, $8}'

echo
echo "== arm 2: how many BACK ENDS are in it?"
# From the build's own testimony, not from what was passed to configure.
n=$(grep -c '^MULTI_TARGET_OBJS_[a-z0-9]* =' "$B/gcc/multi-target-md.mk" || true)
echo "  MULTI_TARGET_OBJS_<cpu> lists in the generated makefile: $n"
[ "$n" -gt 2 ] || { echo "  REFUSING TO SCORE: $n is not more than two bases"; exit 9; }

echo
echo "== arm 3: the link wall, both populations, from the stamped log"
u=$(sed -n "s/.*undefined reference to \`\([^']*\)'.*/\1/p" "$B/build-$TAG.err" | sort -u | wc -l)
m=$(sed -n "s/.*multiple definition of \`\([^']*\)'.*/\1/p" "$B/build-$TAG.err" | sort -u | wc -l)
echo "  distinct 'undefined reference' symbols: $u   (this task's population)"
echo "  distinct 'multiple definition' symbols: $m   (not this task's)"

echo
echo "== arm 4: does the linked cc1 RUN, and does it fail BY NAME?"
# The positive result here is an ERROR, and that is not a trick: PRINCIPLES
# section 2a says a compiler failing by name when no target is selected is
# CORRECT behaviour, not a bug.  What this arm rules out is the two ways a
# linked-but-dead cc1 looks identical to a working one -- a binary that
# segfaults before parsing, and one that silently compiles for the primary.
printf 'int f(int a){return a+1;}\n' > "$B/ur-fn.c"
out=$(sh "$S/eb-shell.sh" \
        "cd $B/gcc && ./cc1 -quiet -nostdinc $B/ur-fn.c -o $B/ur-fn.s" 2>&1 | head -1)
echo "  [$out]"
case "$out" in
  *"no target configuration was selected"*)
    echo "  PASS: cc1 loads, runs, and reaches its own target-selection check." ;;
  *"Segmentation fault"*|"")
    echo "  FAIL: cc1 links but does not run."; exit 1 ;;
  *)
    echo "  SUSPICIOUS: cc1 ran and said something else.  If it COMPILED with no"
    echo "    target selected, it compiled for the primary -- read the .s before"
    echo "    calling this a pass." ;;
esac
