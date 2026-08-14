#!/bin/sh
# EVERY cc1 THIS AGENT RUNS FROM HERE ON GOES THROUGH THIS.
#
# `gcc.target/riscv/pr117506.c' took cc1 to 20.8 GB RSS on a four-line
# testcase and caused visible memory pressure on the user's machine.  A
# compilation that needs 20 GB is not one that is going to pass; it must die
# in seconds and be recorded as a failure instead of taking the box.
#
# `ulimit -v' and not `-m': Linux does not enforce RLIMIT_RSS, so `-m' is
# accepted and does nothing -- which is the "mitigation that cannot fire"
# shape.  -v caps the address space, which malloc actually observes, and GCC
# turns the failed allocation into `out of memory allocating N bytes'.
#
# usage: sh tb1-memcap.sh <kb> <command...>
set -u
KB=${1:?cap in kilobytes}; shift
ulimit -v "$KB" || { echo "FATAL: ulimit -v $KB refused"; exit 9; }
# Non-vacuity: prove the cap is in force before running anything under it.
have=$(ulimit -v)
[ "$have" = "$KB" ] || { echo "FATAL: asked for $KB, ulimit -v reports $have"; exit 9; }
exec "$@"
