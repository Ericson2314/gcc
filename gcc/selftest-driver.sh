#!/bin/sh
# Gate the in-build selftests on a target having actually been selected.
#
# Usage: selftest-driver.sh <target> <target-config-file> VAR=VAL... prog args...
#
# Why this exists.  On this branch the compiler has no target baked in: cc1
# learns which target it is for from a probed per-target config file passed as
# -ftarget-config=.  That file is written by target-specs/configure, which is a
# separate configure the USER runs after gcc is built -- gcc's own build must
# not run it (a build step that re-runs it with a fixed argument list silently
# overwrites whatever the user configured).
#
# So on a freshly built tree the file legitimately does not exist yet, and the
# selftests have no target.  There are exactly two honest things to do, and this
# script does the second only when it can name why:
#
#   * run them, with -ftarget-config= naming a real probed config; or
#   * SKIP, saying which target and which missing file.
#
# What must never happen is the third thing: running cc1 with no target
# selected.  That either dies at the first common target hook with a diagnostic
# that points nowhere near the cause, or -- the outcome this guard is really
# for -- reports success having exercised nothing, which is a green that tested
# no target at all.  See PRINCIPLES 2a: never let the absence of an answer be an
# answer, and never make a check pass by removing what it was checking.
#
# An empty target is a hard error, not a skip: "which target" is a question the
# build must be able to answer, and a build that cannot is broken rather than
# merely unprobed.

target=$1
cfg=$2
shift 2 || {
  echo "selftest-driver.sh: usage: $0 <target> <config-file> command..." >&2
  exit 1
}

if test -z "$target"; then
  echo "selftest-driver.sh: FATAL -- no target selected." >&2
  echo "selftest-driver.sh: TEST_TARGET is empty, so there is no target for the" >&2
  echo "selftest-driver.sh: selftests to run against.  This is a build" >&2
  echo "selftest-driver.sh: configuration error (--enable-backends named" >&2
  echo "selftest-driver.sh: nothing?), not something to skip past." >&2
  exit 1
fi

if test ! -f "$cfg"; then
  echo "selftest: SKIP $target -- no $cfg"
  echo "selftest: target-specs/configure has not been run for $target in this"
  echo "selftest: build directory, so there is no probed target config to hand"
  echo "selftest: cc1 and no target can be selected.  NOTHING WAS TESTED; this"
  echo "selftest: is a skip, not a pass.  Run target-specs/configure for"
  echo "selftest: $target and re-make to get the selftests."
  exit 0
fi

exec env "$@"
