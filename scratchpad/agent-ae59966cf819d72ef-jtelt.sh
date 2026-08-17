#!/bin/sh
# agent-ae59966cf819d72ef-jtelt.sh -- what directive does each target write into
# a jump table?
#
# THE CLAIM UNDER TEST.  `final.cc:2578' and `:2586' spell
# `ASM_OUTPUT_ADDR_VEC_ELT' / `ASM_OUTPUT_ADDR_DIFF_ELT'.  `final.cc' is SHARED,
# so those are `i386.h:2231' and `:2237' for all 47 bases, i.e. every target's
# case vector is written by `ix86_output_addr_vec_elt'.  Confirmed at the object
# level: `nm -uC final.o' binds both bare `ix86_' symbols.
#
# WHY IT IS WORSE THAN A WRONG DIRECTIVE STRING.  `ix86_output_addr_vec_elt'
# picks `.quad' over `.long' on `TARGET_LP64', which is
# `global_options.x_ix86_isa_flags' -- promoted only by `ix86_option_override',
# which runs only when i386 is SELECTED.  So a non-i386 base reads the
# UNCONFIGURED default, the `Pmode'/riscv-32-bit-in-an-ELF64-object shape
# PRINCIPLES records.  `LPREFIX' is i386's label prefix too.
#
# NON-VACUITY, and it is the whole risk here: a target that emits no jump table
# at all produces a file with no directive, which reads exactly like "the
# directive is absent".  So ARM 0 requires the ADDR_VEC/ADDR_DIFF_VEC label
# block to be PRESENT in each output before any directive is scored, and the
# script exits 9 rather than reporting a clean sweep of nothing.
set -u
W=$(cd "$(dirname "$0")/.." && pwd)
B=${B:?set B to a built 47-base build dir}
O=${O:-/tmp/w-agent-ae59966cf819d72ef}/jtelt
mkdir -p "$O"

CC1=$B/gcc/cc1
[ -x "$CC1" ] || { echo "FATAL: no cc1 at $CC1"; exit 9; }

cat > "$O/sw.c" <<'EOF'
extern void f0 (void); extern void f1 (void); extern void f2 (void);
extern void f3 (void); extern void f4 (void); extern void f5 (void);
extern void f6 (void); extern void f7 (void); extern void f8 (void);
extern void f9 (void); extern void fa (void); extern void fb (void);
void sw (int x)
{
  switch (x)
    {
    case 0: f0 (); break;   case 1: f1 (); break;
    case 2: f2 (); break;   case 3: f3 (); break;
    case 4: f4 (); break;   case 5: f5 (); break;
    case 6: f6 (); break;   case 7: f7 (); break;
    case 8: f8 (); break;   case 9: f9 (); break;
    case 10: fa (); break;  case 11: fb (); break;
    }
}
EOF

any=0
for cfg in "$B"/lib/gcc/*/*/specs-config; do
  t=$(basename "$(dirname "$cfg")")
  out=$O/$t.s
  "$CC1" -quiet -nostdinc -O2 -ftarget-config="$cfg" "$O/sw.c" -o "$out" \
      > "$O/$t.out" 2> "$O/$t.err"
  rc=$?
  if [ $rc -ne 0 ]; then
    printf '%-30s cc1 rc=%s  %s\n' "$t" "$rc" "$(head -1 "$O/$t.err")"
    continue
  fi
  # ARM 0: is there a jump table in this file AT ALL?
  n=$(grep -cE '^[[:space:]]*\.(long|quad|word|dword|hword|byte|short|4byte|8byte|2byte)[[:space:]]+\.?L' "$out")
  if [ "$n" -lt 8 ]; then
    printf '%-30s NO TABLE (%s entry-shaped lines) -- not scored\n' "$t" "$n"
    continue
  fi
  any=$((any + 1))
  d=$(grep -oE '^[[:space:]]*\.[a-z0-9]+' "$out" \
      | grep -E '\.(long|quad|word|dword|hword|4byte|8byte|2byte)$' \
      | sort | uniq -c | sort -rn | head -2 | tr -s ' \n' ' ')
  p=$(grep -oE '\.?L[A-Za-z]*[0-9]+' "$out" | sed 's/[0-9]*$//' | sort | uniq -c | sort -rn | head -1)
  printf '%-30s entries=%-4s directives=[%s] toplabel=[%s]\n' "$t" "$n" "$d" "$p"
done

echo
[ "$any" -gt 0 ] || {
  echo "FATAL: no target produced a scorable jump table.  Every row above is"
  echo "       'no table', which is indistinguishable from 'no directive' --"
  echo "       this is a null result, NOT a pass."
  exit 9; }
echo "scored $any target(s)"
