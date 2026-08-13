#!/bin/sh
# t116: survey the 17 unconverted probe names -- who reads them, who defines them.
# Deliberately NOT using grep --include (it silently excludes *.awk and *.md);
# instead exclude only the generated `configure` by path.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)

MACROS='HAVE_AS_ARCHITECTURE_MODIFIERS
HAVE_AS_MACHINE_MACHINEMODE
HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS
HAVE_AS_VECTOR_LOADSTORE_ALIGNMENT_HINTS_ON_Z13
HAVE_AS_AVR_MGCCISR_OPTION
HAVE_AS_AVR_MLINK_RELAX_OPTION
HAVE_AS_AVR_MRMW_OPTION
HAVE_AS_LTOFFX_LDXMOV_RELOCS
HAVE_AS_NO_MUL_BUG_ABORT_OPTION
LD64_VERSION
DSYMUTIL_VERSION
LD64_HAS_DEMANGLE
LD64_HAS_EXPORT_DYNAMIC
LD64_HAS_MACOS_VERSION_MIN
LD64_HAS_NO_DEDUPLICATE
LD64_HAS_PLATFORM_VERSION
HAVE_GOLD_NON_DEFAULT_SPLIT_STACK'

# Non-vacuity: assert the sweep can see a name we KNOW is present.
if ! grep -rlw targ_caps "$ROOT/gcc" > /dev/null; then
  echo "FATAL: sweep instrument reads nothing (targ_caps not found)" >&2
  exit 1
fi

for m in $MACROS; do
  echo "=== $m"
  printf '  readers: '
  grep -rlw "$m" "$ROOT/gcc" "$ROOT/libgcc" "$ROOT/target-specs" 2>/dev/null \
    | grep -v '/gcc/configure$' | grep -v '/config\.in$' \
    | sed "s|$ROOT/||" | tr '\n' ' '
  echo
  printf '  defs-in-configure.ac: '
  grep -cw "$m" "$ROOT/gcc/configure.ac" 2>/dev/null || echo 0
done
