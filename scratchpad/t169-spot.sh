#!/bin/sh
# #169 -- spot check: read the four KNOWN instances out of the dumps.  If the
# dumps cannot reproduce a defect this project has already diagnosed, no queue
# derived from them is worth grinding (PRINCIPLES section 4).
set -u
O=${1:?dump dir}
cd "$O" || exit 9
for m in LEAF_REGISTERS TARGET_SUPPORTS_WIDE_INT HAVE_PRE_INCREMENT \
         HAVE_POST_INCREMENT HAVE_PRE_DECREMENT LOAD_EXTEND_OP \
         TARGET_DLLIMPORT_DECL_ATTRIBUTES MAX_STACK_ALIGNMENT; do
  n=$(grep -l "^$m	" *.m | wc -l)
  i=$(grep -c "^$m	" i386.m || true)
  a=$(grep -c "^$m	" aarch64.m || true)
  iv=$(sed -n "s/^$m	//p" i386.m | head -1)
  printf '%-34s definers=%-3s i386=%s aarch64=%s  i386-value=[%s]\n' "$m" "$n" "$i" "$a" "$iv"
done
