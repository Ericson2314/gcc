#!/bin/sh
# agent-aa9d4bba0b6e950b3-vararg.sh -- the s390x `Segmentation fault' cluster,
# both-sided over the four board targets.
#
# 683 of s390x's FAILs are a bare `internal compiler error: Segmentation fault'
# and the test names are overwhelmingly varargs: va-arg-*, vararg-*, stdarg-*,
# vsnprintf-chk, vsprintf-chk, gcc.dg/compat.  This is the 15-line reproducer
# and the control: a cause that fires on every target is not a leak, a cause
# that fires on one is.
#
# usage: agent-aa9d4bba0b6e950b3-vararg.sh <builddir>
set -u
W=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-aa9d4bba0b6e950b3
D=${1:?build dir}
SRC=$(cat "$D/MY-SRC")
V=$(cat "$SRC/gcc/BASE-VER")

C=/tmp/va-repro-aa9d4bba0b6e950b3.c
cat > $C <<'EOF'
typedef __builtin_va_list va_list;
#define va_start(v,l) __builtin_va_start(v,l)
#define va_arg(v,l)   __builtin_va_arg(v,l)
#define va_end(v)     __builtin_va_end(v)

int f (int n, ...)
{
  va_list ap;
  int s = 0;
  va_start (ap, n);
  for (int i = 0; i < n; i++)
    s += va_arg (ap, int);
  va_end (ap);
  return s;
}
EOF

# NON-VACUITY CONTROL: the same compiler on a NON-varargs function must succeed
# on every target.  Without it, "s390x fails" cannot be told from "this build
# dir compiles nothing for s390x".
K=/tmp/va-ctrl-aa9d4bba0b6e950b3.c
printf 'int g (int a) { return a + 1; }\n' > $K

for T in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu \
         riscv64-unknown-linux-gnu s390x-ibm-linux-gnu; do
  CFG="$D/lib/gcc/$V/$T/specs-config"
  if [ ! -s "$CFG" ]; then echo "$T: NO specs-config -- refusing to score"; continue; fi
  for pair in "control:$K" "vararg:$C"; do
    lbl=${pair%%:*}; in=${pair#*:}
    ( cd "$D/gcc" && ./cc1 -quiet -nostdinc -O2 -ftarget-config="$CFG" \
        "$in" -o /tmp/va-out-$$.s ) > /dev/null 2> /tmp/va-err-$$.txt
    rc=$?
    if grep -q 'internal compiler error' /tmp/va-err-$$.txt; then
      w=$(grep -m1 'internal compiler error' /tmp/va-err-$$.txt | sed 's/^.*internal/internal/')
      f=$(grep -m1 -E '^0x[0-9a-f]+ (s390|ix86|aarch64|riscv|make_tree|expand)' /tmp/va-err-$$.txt | sed 's/^0x[0-9a-f]* //')
      printf '%-28s %-8s rc=%-3s %s  [%s]\n' "$T" "$lbl" "$rc" "$w" "$f"
    else
      printf '%-28s %-8s rc=%-3s ok, %s bytes\n' "$T" "$lbl" "$rc" "$(wc -c < /tmp/va-out-$$.s 2>/dev/null || echo 0)"
    fi
  done
done
rm -f /tmp/va-out-$$.s /tmp/va-err-$$.txt
