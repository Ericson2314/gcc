#!/bin/sh
# WHICH BACK ENDS DISSENT FROM THE PRIMARY ON A GIVEN MACRO -- and, the load-
# bearing part, WHETHER ANY OF THE FOUR PREVIOUSLY SCORED TARGETS IS AMONG
# THEM.
#
# `a660907426e03e4e9-fouragree.sh' asks the running MULTI-TARGET compiler and
# therefore CANNOT answer this: the whole defect is that all five print the
# primary's answer, so all five agree and the table is uniform.  That instrument
# is not wrong, it is measuring the symptom; this one measures the population.
#
# A `#define' of a string or format constant is one of the few things a grep
# CAN settle, because there is nothing to evaluate.  Anchored at line start
# through `#define' so a mention in prose cannot match -- INSTRUMENTS.md's
# `ADJUST_INSN_LENGTH' false RED is the cost of not doing that.
#
# NEGATIVE CONTROL: `elfos.h' must appear as a definer of every macro asked
# about here, since that is where the primary's answer comes from.  If it does
# not, the pattern is wrong and every "N dissenters" below is void.
set -u
cd "$(dirname "$0")/.." || exit 9
FOUR='i386 aarch64 riscv s390 '
for M in TYPE_OPERAND_FMT ASM_OUTPUT_ALIGN ASM_OUTPUT_SKIP; do
  echo "== $M"
  hits=$(grep -rlE "^[ \t]*#[ \t]*define[ \t]+$M\b" gcc/config 2>/dev/null | sort)
  echo "$hits" | grep -q 'gcc/config/elfos.h' \
    || { echo "   FATAL: elfos.h is not among the definers of $M -- the pattern is wrong,"
         echo "          and every count below would be void."; exit 9; }
  # back-end name = the directory under config/, or `elfos'/`defaults' for the
  # shared headers.
  ends=$(echo "$hits" | sed -e 's|^gcc/config/||' -e 's|/.*||' -e 's|\.h$||' | sort -u | tr '\n' ' ')
  echo "   definers: $ends"
  echo "   of the FOUR previously scored back ends (i386 aarch64 riscv s390),"
  n=0
  for b in i386 aarch64 riscv s390; do
    case " $ends " in *" $b "*) echo "     $b  DEFINES its own"; n=$((n+1)) ;;
                      *) echo "     $b  takes elfos.h's" ;; esac
  done
  case " $ends " in *" arm "*) echo "     arm DEFINES its own  <- the dissenter" ;;
                    *) echo "     arm takes elfos.h's too" ;; esac
  echo
done
