#!/bin/sh
# #143 -- WHAT DO THE DRIVER OBJECTS ACTUALLY DECIDE?
#
# The known answer is `-march=native'.  This reads, from each configured back
# end's REAL header chain in a 48-back-end build, whether that back end
# publishes a `local_cpu_detect' spec function at all.
#
# WHY IT IS NOT "every target gets i386's answer".  Each back end that has a
# native detector guards it on a HOST predefine -- aarch64.h:1576 is
# `#if defined(__aarch64__)', rs6000.h likewise.  So on an x86_64 host only
# i386's table publishes the entry, and the others publish nothing rather than
# resolving to i386's `host_detect_local_cpu'.  That is the difference between
# a leak and an absence, and PRINCIPLES section 4 requires distinguishing them:
# "absent artefact" and "absent mechanism" look identical.
#
# HAVE_LOCAL_CPU_DETECT is the readable witness: every back end with a detector
# defines it next to the EXTRA_SPEC_FUNCTIONS entry, inside the same guard.
#
# usage: t143-native.sh <builddir>
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${1:?build dir}
case "$B" in
  */b-ad1798a2b26398cc6*) ;;
  *) echo "FATAL: build dir $B is not named for this worktree"; exit 9 ;;
esac
G="$B/gcc"
SRCG=$(grep -m1 -o '/tmp/snap-[a-z0-9]*' "$B/config.log")/gcc
[ -d "$SRCG" ] || { echo "FATAL: srcdir from config.log missing"; exit 9; }

# The 8 back ends whose sources define a BARE host_detect_local_cpu.
BASES="i386 aarch64 alpha arm mips rs6000 s390 sparc riscv"

printf '%-9s %-22s %-24s %s\n' BASE HAVE_LOCAL_CPU_DETECT MCPU_MTUNE_NATIVE 'bare definer in sources?'
scored=0
for b in $BASES; do
  h="$G/tm-$b.h"
  [ -f "$h" ] || { printf '%-9s %s\n' "$b" "(not configured in this build)"; continue; }
  dm=$(sh "$S/eb-shell.sh" "cd $G && echo '#include \"tm-$b.h\"' | cpp -dM -DIN_GCC -I. -I$SRCG -x c++ - 2>>$B/t143-native.err")
  n=$(printf '%s\n' "$dm" | grep -c . || true)
  [ "$n" -gt 1000 ] || { echo "FATAL: $b preprocessed to $n macros; refusing to score an empty read"; exit 9; }
  scored=$((scored+1))
  hl=$(printf '%s\n' "$dm" | grep -cE '^#define HAVE_LOCAL_CPU_DETECT\b' || true)
  # READ THE VALUE, NOT ITS PRESENCE.  Counting `#define MCPU_MTUNE_NATIVE_SPECS'
  # scored aarch64 as "has native specs but publishes no spec function" -- the
  # two-halves defect spec-functions.cc documents.  That was a FALSE ALARM: the
  # `#else' branch defines it as the empty string, so both halves are absent
  # together and the back end is coherent.  PRINCIPLES section 4: a count is the
  # weakest evidence available and is silent in exactly the case that matters.
  mnv=$(printf '%s\n' "$dm" | sed -n 's/^#define MCPU_MTUNE_NATIVE_SPECS //p;s/^#define ASM_CPU_NATIVE_SPEC //p' | head -1)
  case "$mnv" in
    ''|'""') mn=0 ;;
    *local_cpu_detect*) mn=1 ;;
    *) mn=0 ;;
  esac
  bare=$(grep -rlE '^(extern )?const char \*ho?st_detect_local_cpu|^host_detect_local_cpu' "$SRCG/config/$b/" 2>/dev/null | wc -l)
  printf '%-9s %-22s %-24s %s\n' "$b" \
    "$([ "$hl" -gt 0 ] && echo yes || echo no)" \
    "$([ "$mn" -gt 0 ] && echo yes || echo no)" \
    "$bare file(s)"
done
echo
[ "$scored" -ge 3 ] || { echo "FATAL: scored only $scored bases; #143 needs MORE THAN TWO"; exit 9; }
echo "== bases read from their own chains: $scored"
echo
echo "== bare host_detect_local_cpu definers anywhere under config/ (the LATENT collision):"
grep -rl 'host_detect_local_cpu' "$SRCG/config" | sed "s|$SRCG/config/||" | sort | tr '\n' ' '
echo
echo "== is it in MULTI_TARGET_RENAME_NAMES?"
awk '/^MULTI_TARGET_RENAME_NAMES/,/^$/' "$SRCG/Makefile.in" | grep -c host_detect_local_cpu
