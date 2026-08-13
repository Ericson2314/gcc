#!/bin/sh
# #132 ARM C -- the neighbourhood: what ARG_POINTER_CFA_OFFSET's fallback body
# depends on, whether FRAME_POINTER_CFA_OFFSET / CODEVIEW are defined by any
# CONFIGURED base, and how `machine_function' is treated by gengtype.
set -u
S=$(cd "$(dirname "$0")" && pwd)
G=$(cd "$S/../gcc" && pwd)
cd "$G"

echo "== C1. defaults.h ARG_POINTER_CFA_OFFSET body =="
sed -n '1214,1224p' defaults.h | sed 's/^/   /'
echo
echo "== C2. FIRST_PARM_OFFSET: definitions + is it redirected? =="
grep -rn 'define FIRST_PARM_OFFSET' defaults.h config/i386/i386.h config/aarch64/aarch64.h target-frame.h target-cumargs.cc target-cumargs-select.cc 2>/dev/null | sed 's/^/   /'
echo "   -- uses outside config/ --"
grep -rnw FIRST_PARM_OFFSET . --exclude-dir=config --exclude-dir=testsuite --exclude-dir=doc --exclude=ChangeLog\* --exclude=FSFChangeLog\* | sed 's/^/   /'
echo
echo "== C3. does EITHER configured base define FRAME_POINTER_CFA_OFFSET / CODEVIEW_DEBUGGING_INFO? =="
for h in config/i386/i386.h config/aarch64/aarch64.h; do
  for m in FRAME_POINTER_CFA_OFFSET CODEVIEW_DEBUGGING_INFO ARG_POINTER_CFA_OFFSET; do
    if grep -q "define $m" "$h"; then echo "   $h defines $m"; else echo "   $h does NOT define $m"; fi
  done
done
echo "   (i386 tm.h chain also pulls linux/unix/att/gnu-user/x86-64; CODEVIEW is cygming-only)"
echo
echo "== C4. gengtype treatment of cfun->machine =="
grep -n 'machine;' function.h | sed 's/^/   /'
grep -rn 'struct machine_function' function.h coretypes.h | sed 's/^/   /'
echo
echo "== C5. every OTHER field of `cfun' whose pointee type is per-back-end =="
grep -n 'GTY' function.h | sed -n '1,40p' | sed 's/^/   /'
