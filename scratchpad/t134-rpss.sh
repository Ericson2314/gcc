#!/bin/sh
# #134 -- JOB 2 ARM.  `REG_PARM_STACK_SPACE' has SEVERAL paths into shared
# code and #133 closed one of them.  This arm (a) shows the second one is now
# closed at the object level, (b) shows both per-base thunks exist and DIFFER,
# and (c) ENUMERATES every remaining path so a verdict can be given for each,
# including the ones judged fine.
#
# `index ($0, f)' and not `$0 ~ f': a demangled C++ name contains `()', which
# as a regex is an EMPTY GROUP matching nothing -- six arms once scored EMPTY,
# reading as "no per-base copy exists", the opposite of the truth.
#
# NON-VACUITY FLOOR: refuses to score if `nm' produced nothing.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b134}
SRC=$(cd "$S/.." && pwd)

nm_of () { sh "$S/eb-shell.sh" "nm -C $1" 2>/dev/null; }

echo "=== A. the objects exist"
for o in $B/gcc/function.o $B/gcc/gimplify.o \
         $B/gcc/target-cumargs-i386.o $B/gcc/target-cumargs-aarch64.o \
         $B/gcc/target-cumargs-select.o; do
  [ -f "$o" ] || { echo "FATAL: $o does not exist -- refusing to score"; exit 9; }
  echo "  ok $(basename $o) $(wc -c < $o) bytes"
done

echo "=== B. non-vacuity floor"
tot=$(nm_of "$B/gcc/function.o" | wc -l)
echo "  function.o symbol lines: $tot"
[ "$tot" -gt 100 ] || { echo "FATAL: nm read nothing useful"; exit 9; }

echo "=== C. does shared code still bind the primary's ix86_* argument-space fns?"
for o in function.o gimplify.o calls.o expr.o; do
  n=$(nm_of "$B/gcc/$o" | awk '/^ *U /' \
      | awk 'index ($0, "ix86_reg_parm_stack_space")' | wc -l)
  echo "  $o : U ix86_reg_parm_stack_space x $n"
done

echo "=== D. and the two new selectors, bound where they should be"
for pair in "function.o:mt_incoming_reg_parm_stack_space" \
            "gimplify.o:mt_push_args_reversed"; do
  o=${pair%%:*}; f=${pair##*:}
  n=$(nm_of "$B/gcc/$o" | awk -v f="$f" 'index ($0, f)' | wc -l)
  echo "  $o binds $f : $n"
done

echo "=== E. the per-base thunk BODIES -- both bases, and they must differ"
for base in i386 aarch64; do
  o=$B/gcc/target-cumargs-$base.o
  for f in mt_base_incoming_reg_parm_stack_space mt_base_push_args_reversed; do
    d=$(nm_of "$o" | awk -v f="$f" 'index ($0, f)' | wc -l)
    echo "  $base : $f defined-lines=$d"
  done
done

echo "=== F. disassembled bodies (the reading, not the existence)"
for base in i386 aarch64; do
  echo "--- $base"
  sh "$S/eb-shell.sh" "objdump -d --demangle $B/gcc/target-cumargs-$base.o" 2>/dev/null \
    | awk '/^[0-9a-f]+ </ { inb = (index ($0, "mt_base_incoming_reg_parm_stack_space") \
                                   || index ($0, "mt_base_push_args_reversed")); \
                            if (inb) print "  " $0; next } \
           inb { if ($0 ~ /^$/) { inb = 0; next } print "   " $0 }'
done

echo "=== G. EVERY REMAINING PATH, enumerated from the source (not from memory)"
cd "$SRC/gcc"
echo "--- preprocessor tests of REG_PARM_STACK_SPACE in shared code"
grep -n '^#.*\<REG_PARM_STACK_SPACE\>' *.cc *.h | grep -v OUTGOING_REG | grep -v INCOMING_REG
echo "--- value uses of REG_PARM_STACK_SPACE in shared code"
grep -n '\<REG_PARM_STACK_SPACE *(' *.cc *.h | grep -v OUTGOING_REG | grep -v INCOMING_REG
echo "--- INCOMING_REG_PARM_STACK_SPACE anywhere in shared code"
grep -n '\<INCOMING_REG_PARM_STACK_SPACE\>' *.cc *.h
echo "--- which back-end headers define each"
grep -rln '^#define REG_PARM_STACK_SPACE' config/ | sort | tr '\n' ' '; echo
grep -rln '^#define INCOMING_REG_PARM_STACK_SPACE' config/ | sort | tr '\n' ' '; echo
