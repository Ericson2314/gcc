#!/bin/sh
# t116: BOTH-SIDED evidence that `targ_caps.as_ltoffx_ldxmov_relocs' -- which
# gcc/defaults.h:1655 defines HAVE_AS_LTOFFX_LDXMOV_RELOCS over, and which
# ia64.h and ia64.md expand -- has no field in struct target_caps.
#
# The control is `as_s390_architecture_modifiers': the same shape, same block of
# defaults.h, a field that DOES exist.  Without it, a compile failure here would
# be indistinguishable from "my test harness cannot compile target-caps.h at
# all", which is the all-arms-empty trap.
#
# Expected BEFORE the fix:  control compiles, subject FAILS.
# Expected AFTER  the fix:  both compile.
# A run where the CONTROL fails is a broken harness and is reported as such.
set -eu
cd "$(dirname "$0")/.."
ROOT=$(pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' 0

mk () {   # $1 = field name, $2 = output basename
  cat > "$W/$2.cc" <<EOF
#include <stdbool.h>
#include "target-caps.h"
struct target_caps targ_caps;
bool probe (void) { return targ_caps.$1; }
EOF
}

mk as_s390_architecture_modifiers control
mk as_ltoffx_ldxmov_relocs        subject

run () {
  if g++ -fsyntax-only -I "$ROOT/gcc" "$W/$1.cc" > "$W/$1.out" 2> "$W/$1.err"; then
    echo "COMPILES"
  else
    echo "FAILS"
  fi
}

c=$(run control)
s=$(run subject)

echo "control (as_s390_architecture_modifiers): $c"
echo "subject (as_ltoffx_ldxmov_relocs)       : $s"
echo "--- subject diagnostic:"
sed 's/^/    /' "$W/subject.err" | head -5

if [ "$c" != "COMPILES" ]; then
  echo
  echo "HARNESS BROKEN: the control field does not compile either, so the"
  echo "subject's failure proves nothing about the tree.  Control diagnostic:" >&2
  sed 's/^/    /' "$W/control.err" >&2
  exit 1
fi
echo
echo "VERDICT: control=$c subject=$s"
