#!/bin/sh
# #133 -- JOB 2: CLASSIFY EVERY `PUSH_ROUNDING' SITE BY POSITION OF USE,
# BEFORE converting any of them.
#
# Why this arm exists at all: a macro on a `#if'/`#ifdef' line CANNOT always
# become a runtime value.  Two sjlj consumers had to keep a build-time switch
# for exactly that reason, and two `#if HAVE_ATTR_length' gates would have
# silently evaluated a call-valued macro to 0, turning both passes OFF FOR
# EVERY TARGET.  So the guards are enumerated and each is given a shape
# verdict; nothing is converted here.
#
# TWO ARMS, not one, because #132 measured that they find different things:
#   ARM A  position of use   -- can THIS spelling become a call?
#   ARM B  guard context     -- is this use REACHED under a primary-decided
#                               guard?  (this is the arm that found
#                               STACK_DYNAMIC_OFFSET in the first place)
#
# `--exclude=ChangeLog*' is load-bearing in the FALSE-POSITIVE direction here,
# as #132 recorded.  `--include' is NEVER used, because a filter is how a zero
# gets manufactured.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G" || exit 9

echo "=== ARM 0: non-vacuity.  If these are 0 the sweep proves nothing. ==="
all=$(grep -rn 'PUSH_ROUNDING' . --exclude-dir=config --exclude-dir=testsuite \
        --exclude-dir=doc --exclude-dir=po --exclude=ChangeLog\* \
        --exclude=FSFChangeLog\* | wc -l)
echo "total shared mentions (incl. comments): $all"
[ "$all" -gt 20 ] || { echo "FATAL: implausibly few; refusing to score"; exit 9; }

echo
echo "=== ARM A: PREPROCESSOR sites -- the ones that decide the shape ==="
grep -rn '^ *# *if.*PUSH_ROUNDING' . --exclude-dir=config --exclude-dir=testsuite \
  --exclude-dir=doc --exclude-dir=po --exclude=ChangeLog\* --exclude=FSFChangeLog\* \
  | sort
echo "--- preprocessor site count: $(grep -rn '^ *# *if.*PUSH_ROUNDING' . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc --exclude-dir=po --exclude=ChangeLog\* --exclude=FSFChangeLog\* | wc -l)"

echo
echo "=== ARM A2: VALUE sites -- PUSH_ROUNDING (...) actually expanded ==="
grep -rn 'PUSH_ROUNDING *(' . --exclude-dir=config --exclude-dir=testsuite \
  --exclude-dir=doc --exclude-dir=po --exclude=ChangeLog\* --exclude=FSFChangeLog\* \
  | grep -v '^\./[a-z0-9_.-]*:[0-9]*: *\*' | grep -v '# *define' | sort

echo
echo "=== ARM B: per-base DEFINEDNESS of PUSH_ROUNDING and its closure ==="
for m in PUSH_ROUNDING PUSH_ARGS_REVERSED REG_PARM_STACK_SPACE \
         INCOMING_REG_PARM_STACK_SPACE STACK_DYNAMIC_OFFSET; do
  i=$(grep -c "^#define $m" config/i386/i386.h || true)
  a=$(grep -c "^#define $m" config/aarch64/aarch64.h || true)
  n=$(grep -rl "^#define $m" config/*/*.h | wc -l)
  printf '%-32s i386=%s aarch64=%s  back-end headers defining it: %s\n' "$m" "$i" "$a" "$n"
done

echo
echo "=== ARM C: what the primary's answer currently decides for everyone ==="
echo "PUSH_ARGS_REVERSED use sites in SHARED code (gimplify.cc):"
grep -rn 'PUSH_ARGS_REVERSED' gimplify.cc
