#!/bin/sh
# lto-wrapper SHIM.  Records the argv it was handed and the two environment
# variables lto-wrapper reads its options out of, then execs the real one so
# the link still completes.
#
# WHY A SHIM RATHER THAN -###.  `-###' shows what the DRIVER spawns.  It cannot
# show lto-wrapper's argv, because lto-wrapper is spawned by collect2 (which
# builds the argv itself, from COLLECT_LTO_WRAPPER plus object names) or by the
# linker's LTO plugin (which builds it from the -plugin-opt= it was given).
# Neither argv is spec text, so reading specs cannot answer #78 for them.
set -u
: "${T78_LOG:?T78_LOG must be set}"
: "${T78_REAL:?T78_REAL must be set}"
{
  echo "=== lto-wrapper invoked  tag=${T78_TAG:-?}"
  echo "--- argv (\$0 excluded):"
  for a in "$@"; do echo "    [$a]"; done
  echo "--- COLLECT_GCC_OPTIONS=${COLLECT_GCC_OPTIONS-<unset>}"
  echo "--- COLLECT_GCC=${COLLECT_GCC-<unset>}"
  echo "--- argv has -ftarget-config=: $(for a in "$@"; do echo "$a"; done | grep -c -- '^-ftarget-config=')"
  echo "--- env  has -ftarget-config=: $(printf '%s' "${COLLECT_GCC_OPTIONS-}" | grep -c -- '-ftarget-config=')"
} >> "$T78_LOG"
exec "$T78_REAL" "$@"
