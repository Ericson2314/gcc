#!/bin/sh
# Task #45/#98 -- re-run gcc/configure in the build dir, CORRECTLY.
#
# ---------------------------------------------------------------------------
# TWO WRONG WAYS, BOTH MEASURED, BOTH KEPT HERE BECAUSE EACH LOOKED FINE.
#
# WRONG 1 -- recheck the TOP LEVEL.  `./config.status --recheck' in $D
# regenerates the top-level Makefile and does NOT reconfigure gcc/ at all:
# gcc/auto-host.h and gcc/config.status kept their original timestamps
# (21:44, against a 21:50 recheck).  The auto-host.h diff then said
# "identical" about a file nothing had touched -- a comparison that could not
# have failed.  Hence the mtime assertion below.
#
# WRONG 2 -- recheck gcc/ BY HAND.  `cd $D/gcc && ./config.status --recheck'
# does regenerate auto-host.h, and silently flipped
#   -#define TARGET_PROVIDES_LIBATOMIC 1
#   +/* #undef TARGET_PROVIDES_LIBATOMIC */
# That is not a source change.  TARGET_CONFIGDIRS reaches gcc/configure only
# as an environment variable exported by the TOP-LEVEL Makefile
# (Makefile.tpl:252); a hand-run recheck does not have it, so the libatomic
# test takes its "no libatomic" arm and -latomic disappears from every
# target link line.  gcc/configure.ac:2650-2665 already documents this exact
# failure -- the trap was known and this script walked into it anyway.
#
# RIGHT -- let the TOP-LEVEL make reconfigure gcc/, which exports
# TARGET_CONFIGDIRS.  Remove gcc/config.status and gcc/Makefile so
# t45-build.sh's `configure-gcc' branch fires, and reconfigure from $D.
# The check at the end is that TARGET_PROVIDES_LIBATOMIC is still defined;
# if it is not, this script has damaged the build dir and says so.
# ---------------------------------------------------------------------------
set -u
S=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-add93fb43c802e701/scratchpad
D=${D:-/tmp/b45}
G="$D/gcc"

[ -f "$G/config.status" ] || { echo "FATAL: $G is not configured"; exit 9; }

cp "$G/auto-host.h" /tmp/t45-auto-host.before || exit 9
before_mtime=$(stat -c %Y "$G/auto-host.h") || exit 9

rm -f "$G/config.status" "$G/Makefile" || exit 9

# t45-build.sh re-runs `configure-gcc' from the top level when gcc/Makefile is
# absent, in the known-cached -p set (no autoconf, no binutils).
# `auto-host.h' is a real target and is what this script is about, so the
# reconfigure step cannot succeed without producing it.
D="$D" sh "$S/t45-build.sh" auto-host.h 2>&1 | tail -3

[ -f "$G/auto-host.h" ] || { echo "FATAL: no auto-host.h after reconfigure"; exit 9; }
after_mtime=$(stat -c %Y "$G/auto-host.h") || exit 9
if [ "$before_mtime" = "$after_mtime" ]; then
  echo "FATAL: $G/auto-host.h was never regenerated (mtime unchanged:"
  echo "  $before_mtime).  Any 'identical' verdict below would be vacuous."
  exit 9
fi
echo "auto-host.h WAS regenerated (mtime $before_mtime -> $after_mtime)"

if grep -n 'define rlim_t' "$G/auto-host.h"; then
  echo "FATAL: auto-host.h corrupted by the reconfigure (see DEVSHELL.md)"; exit 9
fi

echo "=== the two defines this task touches, and the one WRONG 2 destroyed:"
grep -n 'OFFLOAD_TARGETS\|ENABLE_OFFLOADING\|TARGET_PROVIDES_LIBATOMIC' "$G/auto-host.h"
if grep -q '^#define TARGET_PROVIDES_LIBATOMIC 1' "$G/auto-host.h"; then
  echo "    TARGET_PROVIDES_LIBATOMIC still 1 -- TARGET_CONFIGDIRS survived"
else
  echo "    FATAL: TARGET_PROVIDES_LIBATOMIC lost again; build dir is damaged"
  exit 9
fi

echo "=== auto-host.h diff across the reconfigure"
echo "    (expected: ONLY the OFFLOAD_TARGETS comment this task rewrote)"
diff /tmp/t45-auto-host.before "$G/auto-host.h" && echo "    (no diff at all)"
