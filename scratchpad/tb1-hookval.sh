#!/bin/sh
# #163 -- `#define TARGET_HAVE_TLS HAVE_AS_TLS' -> `true', in the seven back
# ends that spell it that way.
#
# THIS ONE IS NOT COSMETIC AND WOULD NOT HAVE COMPILED.  TARGET_HAVE_TLS lands
# in a STATIC INITIALIZER (the gcc_target table).  `HAVE_AS_TLS' is
# `(targ_caps.as_tls)' now -- a read of a global object, not an integral
# constant expression -- so leaving these would be a hard error at the
# TARGET_INITIALIZER line, naming a macro that is nowhere near this file.
#
# `true' is each back end's OWN former answer: the AC_DEFINE that fed the old
# spelling was unconditional 1 for everybody.  The assembler's half of the
# question is target_have_tls_p ().
set -e
cd "$(dirname "$0")/../gcc"
FILES="config/alpha/alpha.cc config/arc/arc.cc config/frv/frv.cc \
config/loongarch/loongarch.cc config/mips/mips.cc config/rs6000/rs6000.cc \
config/xtensa/xtensa.cc"
n=0
for f in $FILES; do
  grep -q '^#define TARGET_HAVE_TLS HAVE_AS_TLS$' "$f" \
    || { echo "FATAL: $f has no '#define TARGET_HAVE_TLS HAVE_AS_TLS'"; exit 9; }
  sed -i 's/^#define TARGET_HAVE_TLS HAVE_AS_TLS$/#define TARGET_HAVE_TLS true/' "$f"
  grep -q '^#define TARGET_HAVE_TLS true$' "$f" || { echo "FATAL: $f not rewritten"; exit 9; }
  n=$((n+1)); echo "converted $f"
done
[ "$n" = 7 ] || { echo "FATAL: converted $n of 7"; exit 9; }
