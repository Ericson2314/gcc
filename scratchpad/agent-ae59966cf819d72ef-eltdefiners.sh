#!/bin/sh
# Which of the 47 configured back ends define the case-vector ELEMENT macros,
# and which do not.  The non-definers matter: `final.cc's `#else' for both is
# `gcc_unreachable ()', so a base that defines neither has no way to write a
# jump table at all -- and today that is invisible, because the base that
# ANSWERS is i386, which defines both.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
cd "$W/gcc"
# `backends-47.txt' holds TRIPLES (`aarch64-unknown-linux-gnu'), NOT back-end
# directory stems (`aarch64').  Comparing the two directly gives "0 of 47
# definers" for EVERY macro -- a null result that reads exactly like the
# finding, and the first version of this script printed it.  The build dir
# names the real mapping: `gcc/mt-<base>/' is one directory per configured
# back end.
B=${B:?set B to a configured build dir -- the triple->back-end mapping lives there}
ls -d "$B"/gcc/mt-*/ 2>/dev/null | sed 's|.*/mt-||; s|/$||' | sort > /tmp/ae-bases.txt
n=$(grep -c . /tmp/ae-bases.txt)
[ "$n" -ge 40 ] || { echo "FATAL: $n back ends found under $B/gcc/mt-*/ -- expected 47."; exit 9; }
echo "configured back ends, read from $B/gcc/mt-*/: $n"
for m in ASM_OUTPUT_ADDR_VEC_ELT ASM_OUTPUT_ADDR_DIFF_ELT \
         ASM_OUTPUT_ADDR_VEC ASM_OUTPUT_ADDR_DIFF_VEC \
         ASM_OUTPUT_CASE_LABEL ASM_OUTPUT_CASE_END ; do
  git grep -lE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" -- config/ \
    | sed 's|^config/||; s|/.*||' | sort -u > /tmp/ae-def.txt
  # `config/*.h' entries (elfos.h, dbxelf.h, ...) sed to their own stem and are
  # NOT back ends; they are in the tm.h CHAIN of many, which is why they are
  # listed separately rather than dropped.
  chain=$(git grep -lE "^[[:space:]]*#[[:space:]]*define[[:space:]]+$m\b" -- config/ \
          | grep -vE '^config/[^/]+/' | tr '\n' ' ')
  have=$(comm -12 /tmp/ae-bases.txt /tmp/ae-def.txt | grep -c .)
  miss=$(comm -23 /tmp/ae-bases.txt /tmp/ae-def.txt | tr '\n' ' ')
  printf '%-26s configured definers %2s/47\n' "$m" "$have"
  [ -n "$chain" ] && printf '    also in the shared chain: %s\n' "$chain"
  printf '    NOT defined by: %s\n' "$miss"
done
