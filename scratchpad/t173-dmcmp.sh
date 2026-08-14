#!/bin/sh
# #173 -- compare candidate discriminator macros across the two dumps
# t173-dm.sh left behind, to pick one that is DEFINED ON BOTH SIDES with
# different values.  An `(absent)' reading is a weak arm: an empty dump reads
# the same way.
set -e
D=${1:?build dir}
cd "$D"
[ -s dm-i386.txt ] && [ -s dm-riscv.txt ] || { echo "FATAL: dumps missing or empty"; exit 9; }
for m in "$@"; do :; done
for m in UNITS_PER_WORD BITS_PER_WORD STACK_BOUNDARY FIRST_PSEUDO_REGISTER \
	 MAX_BITS_PER_WORD POINTER_SIZE PARM_BOUNDARY BIGGEST_ALIGNMENT; do
  a=$(awk -v m="$m" '$1=="#define" && $2==m {$1="";$2="";sub(/^  /,"");print;exit}' dm-i386.txt)
  b=$(awk -v m="$m" '$1=="#define" && $2==m {$1="";$2="";sub(/^  /,"");print;exit}' dm-riscv.txt)
  printf '%-24s i386=%-34s riscv=%s\n' "$m" "${a:-ABSENT}" "${b:-ABSENT}"
done
