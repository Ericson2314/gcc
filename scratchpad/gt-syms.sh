#!/bin/sh
# The OBJECT-level arm: `gt_ggc_mx_machine_function' must no longer be a single
# definition serving everyone.
#
# Two traps this avoids, both recorded in PRINCIPLES:
#   * `awk '$0 ~ f'' on a demangled C++ name matches NOTHING, because the `()'
#     is an empty regex group.  These are extern "C"-ish plain names with no
#     parens, but grep -F is used throughout anyway so the arm cannot acquire
#     that bug later.
#   * `objdump -d' ALONE erases callee names; -dr keeps the relocations that
#     say who is called.  The call-site arm below needs -dr.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b-a2c4f72addc68d136-pair}
got=$(sed -n 's|^  \$ \(/[^ ]*\)/configure .*|\1|p' "$B/config.log" | sed -n 1p)
[ "$got" = "$SRC" ] || { echo "FATAL: $B configured from '$got', not $SRC"; exit 9; }
command -v nm > /dev/null || { echo "FATAL: no nm on PATH"; exit 9; }
command -v objdump > /dev/null || { echo "FATAL: no objdump on PATH"; exit 9; }
cd "$B/gcc"
[ -x ./cc1 ] || { echo "FATAL: no cc1"; exit 9; }

echo "--- definitions (nm -C, T/t only) in cc1"
nm -C ./cc1 | grep -F ' T gt_ggc_mx_machine_function' \
            | sed 's/^/  /' || echo "  (none)"
n=$(nm -C ./cc1 | grep -Fc ' T gt_ggc_mx_machine_function' || true)
echo "total gt_ggc_mx_machine_function* text symbols: $n"

echo "--- per-base objects that DEFINE one"
for o in mt-*/*.o; do
  if nm -C "$o" 2>/dev/null | grep -Fq ' T gt_ggc_mx_machine_function_'; then
    echo "  $o: $(nm -C "$o" | grep -F ' T gt_ggc_mx_machine_function_' \
	  | awk '{print $3}' | tr '\n' ' ')"
  fi
done

echo "--- gtype-desc.o's references to the per-base routines (objdump -dr)"
# NOT -d alone: -d erases the callee names and this arm would read empty.
# NOT anchored on the DEMANGLED name either: a first version of this arm
# bracketed the disassembly on `<gt_ggc_mx_machine_function>:' and printed
# nothing, because the symbols in the object are MANGLED
# (_Z26gt_ggc_mx_machine_functionPv).  An empty result there reads as "the
# dispatcher calls nothing", which is the opposite of the truth -- so the arm
# now matches the unmangled substring, which is present in both spellings, and
# REFUSES to score if it finds no relocation at all.
rel=$(objdump -dr gtype-desc.o 2>/dev/null \
      | grep -F 'R_X86_64' | grep -F 'gt_ggc_mx_machine_function_')
if [ -z "$rel" ]; then
  echo "  FATAL: no relocation from gtype-desc.o names a per-base routine;"
  echo "  the dispatcher would be calling nothing.  Refusing to score."
  exit 1
fi
echo "$rel" | sed 's/^/  /'
echo "per-base routines referenced from shared code: $(echo "$rel" | wc -l)"
