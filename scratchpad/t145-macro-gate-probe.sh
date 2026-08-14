#!/bin/sh
# #145 -- WHICH ARM DO THE POLY GATES TAKE, in each context, measured.
#
# Four gates decide whether a back end gets the fixed-size shorthand:
#
#   coretypes.h:622      POLY_INT_CONVERSION     keyed on TARGET_POLY_AWARE
#   machmode.h:107       ONLY_FIXED_SIZE_MODES   keyed on TARGET_POLY_AWARE
#   machmode.h:957       MACRO_MODE              keyed on NUM_POLY_INT_COEFFS == 1
#   poly-int-types.h:89  MACRO_INT               keyed on NUM_POLY_INT_COEFFS == 1
#
# The first two were de-conjoined from the build-wide constant by task #33.
# The last two were not.  This probe reads the arm each one ACTUALLY takes
# rather than reasoning about it, in the real compile context of a per-base
# object, by re-running that object's own recipe with `-E -dM'.
#
# THE RECIPE COMES FROM `make -n', NOT FROM THE BUILD LOG.  A build log echoes
# the command with the shell's line continuations intact, so the `-o <obj>'
# and the compiler name land on DIFFERENT lines and a `grep' for `-o <obj>'
# finds a line that is not the command.  Measured: that grep returned nothing
# for an object that had in fact been compiled -- "no compile line" and "no
# such object" reading the same, which is the shape this file exists to avoid.
#
# NON-VACUITY: refuses to report unless the dump is a real one.  An empty
# `-dM' dump greps identically to "the gate is off".
set -u
D=${D:-/tmp/b-a88fe2f04579b6092}
S=$(cd "$(dirname "$0")" && pwd)
OBJ=${1:?object, e.g. target-cumargs-i386.o}

SRC=${2:?source basename, e.g. target-cumargs.cc}
# `make -n' prints the recipes of every out-of-date PREREQUISITE too, so the
# output is not one command.  Join the shell's backslash continuations first,
# then take the LAST joined line that is both a g++ invocation and names this
# source -- anything else picked up the options generators and failed with a
# shell syntax error, which again produced an empty dump.
sh "$S/eb-shell.sh" "cd $D/gcc && make -n $OBJ" > /tmp/t145-mn.txt 2>/tmp/t145-mn.err
cmd=$(awk '{ if (sub(/\\$/, "")) { buf = buf $0; next } print buf $0; buf = "" }' /tmp/t145-mn.txt \
      | grep '^g\+\+' | grep -F "$SRC" | tail -1)
[ -n "$cmd" ] || { echo "FATAL: no g++ recipe naming $SRC for $OBJ"; sed 's/^/    /' /tmp/t145-mn.err | head; exit 9; }
cmd=$(printf '%s' "$cmd" | sed -e 's/ -o [^ ]*\.o / /')" -E -dM -o /dev/stdout"

# The recipe is far past ARGV_MAX for `nix-shell --run', which fails with
# `Argument list too long' -- and that failure produced an EMPTY dump, i.e.
# exactly the reading the non-vacuity arm below exists to refuse.  Write it to
# a file and run the file.
printf '%s\n' "$cmd" > /tmp/t145-cmd.sh
sh "$S/eb-shell.sh" "cd $D/gcc && sh /tmp/t145-cmd.sh" > /tmp/t145-dM.txt 2> /tmp/t145-dM.err
n=$(wc -l < /tmp/t145-dM.txt)
if [ "$n" -lt 1000 ]; then
  echo "FATAL: dump for $OBJ is only $n lines; refusing to score."
  sed 's/^/    /' /tmp/t145-dM.err | head -20
  exit 9
fi
echo "== $OBJ: $n macros dumped"
for m in NUM_POLY_INT_COEFFS ONLY_FIXED_SIZE_MODES POLY_INT_CONVERSION \
         MACRO_MODE MACRO_INT TARGET_POLY_AWARE IN_TARGET_CODE; do
  v=$(grep -E "^#define $m($| |\()" /tmp/t145-dM.txt || true)
  if [ -z "$v" ]; then echo "     $m: (not defined)"; else echo "     $v"; fi
done
