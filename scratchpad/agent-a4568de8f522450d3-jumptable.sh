#!/bin/sh
# agent-a4568de8f522450d3-jumptable.sh -- did ADDR_VEC_ALIGN reach the jump
# table, and is a target that does NOT define it unmoved?
#
# THE CLAIM.  `final.cc:485's `#ifndef ADDR_VEC_ALIGN' was taken for all 47
# bases, because i386 defines no such macro, so every back end got the generic
# `exact_log2 (GET_MODE_SIZE (<table mode>))'.  aarch64 asks for **0** -- no
# alignment at all -- and vax, csky likewise; sh, pa, nds32 ask for 2;
# xstormy16 for 1.  Twelve back ends, none of them served.
#
# WHAT TO EXPECT AND WHY THE ARM IS A DIFF, NOT A COUNT.  aarch64's jump table
# is SImode, so the generic answer is exact_log2 (4) = 2 and aarch64's own is
# 0.  The observable is the `.align' emitted immediately before the table.  A
# COUNT of `.align' lines is the wrong arm -- function alignment emits them
# too, and PRINCIPLES records a count scoring a leak as absent when both sides
# happened to have the same number of entries.  So this diffs the files and
# shows the hunk.
#
# THE CONTROL.  x86_64 defines no ADDR_VEC_ALIGN, so its thunk calls the very
# same `final_addr_vec_align' shared code used to call: byte-identical, and
# that is a prediction this conversion could falsify.
set -u
PRE=${PRE:?set PRE to the pre build dir}
POST=${POST:?set POST to the post build dir}
O=${O:-/tmp/w-a4568de8f522450d3}/jt
mkdir -p "$O"

for d in "$PRE" "$POST"; do
  [ -x "$d/gcc/cc1" ] || { echo "FATAL: no cc1 in $d"; exit 9; }
  [ "$(cat "$d/all-gcc.rc" 2>/dev/null)" = 0 ] || { echo "FATAL: $d not stamped 0"; exit 9; }
done

# ONE INPUT PATH, COMPILED BY BOTH COMPILERS.  The first version wrote
# `<target>.pre.s.c' and `<target>.post.s.c' and diffed the outputs -- so every
# target "DIFFERED", in the `.file' directive, by the two names I had just
# chosen.  That is the aarch64 `-S' filename sensitivity PRINCIPLES records,
# manufactured on purpose by accident.  A control whose two sides are compiled
# from different paths is not a control.
#
# AND THE RETURN VALUES MUST BE IRREGULAR.  The first version used 11, 22, 33
# ... 99, i.e. `11 * (x + 1)', and GCC computed it -- no switch, no jump table,
# nothing to align, on every target.  The non-vacuity arm caught it; a diff of
# two tableless files comes back empty and reads as "unchanged".
# AND THE CASES MUST DO DIFFERENT *WORK*, NOT RETURN DIFFERENT CONSTANTS.
# The second version returned irregular constants and GCC built a rodata
# LOOKUP TABLE of values (`.word 37 / .word 5 / ...`) with no branching at all
# -- so there was no ADDR_VEC, `ADDR_VEC_ALIGN` was never consulted, and both
# sides were byte-identical for a reason that has nothing to do with the
# change.  A `.align 3` was even present in that output, from the data
# alignment of the value table, which is exactly the near-miss that would have
# been read as "the alignment is there, unmoved".
#
# Distinct external calls cannot be tabulated, so the switch stays a jump
# through a label vector.
SW="$O/sw.c"
cat > "$SW" <<'EOF'
void a0 (void); void a1 (void); void a2 (void); void a3 (void);
void a4 (void); void a5 (void); void a6 (void); void a7 (void);
void a8 (void); void a9 (void); void a10 (void); void a11 (void);

void f (int x)
{
  switch (x)
    {
    case 0:  a0 ();  break;  case 1:  a1 ();  break;
    case 2:  a2 ();  break;  case 3:  a3 ();  break;
    case 4:  a4 ();  break;  case 5:  a5 ();  break;
    case 6:  a6 ();  break;  case 7:  a7 ();  break;
    case 8:  a8 ();  break;  case 9:  a9 ();  break;
    case 10: a10 (); break;  case 11: a11 (); break;
    }
}
EOF

run () { # run <builddir> <triple> <out> -- ALWAYS from the one $SW path
  d=$1; t=$2; o=$3
  cfg=$(ls "$d"/lib/gcc/*/"$t"/specs-config 2>/dev/null | head -1)
  [ -n "$cfg" ] || { echo "FATAL: no specs-config for $t under $d" >&2; exit 9; }
  "$d/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$cfg" "$SW" -o "$o" 2> "$o.err"
}

for t in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  short=$(echo "$t" | cut -d- -f1)
  run "$PRE"  "$t" "$O/$short.pre.s"
  run "$POST" "$t" "$O/$short.post.s"
  echo "== $t"
  if cmp -s "$O/$short.pre.s" "$O/$short.post.s"; then
    echo "   IDENTICAL  (md5 $(md5sum < "$O/$short.pre.s" | cut -c1-12))"
  else
    echo "   DIFFERS:"
    diff "$O/$short.pre.s" "$O/$short.post.s" | sed 's/^/     /'
  fi
done

# NON-VACUITY.  Every reading above is void if the compile failed or if the
# target emitted no jump table at all -- and "no table" is indistinguishable
# from "table unchanged" in a diff that comes back empty.  So BOTH must be
# shown: real output, and an actual jump table in it.
echo
echo "NON-VACUITY: real output, and a jump table actually present"
rc=0
for f in "$O/aarch64.pre.s" "$O/aarch64.post.s" "$O/x86_64.pre.s" "$O/x86_64.post.s"; do
  s=$(wc -c < "$f" 2>/dev/null); s=${s:-0}
  # A jump table shows as a label-difference vector or a .quad/.word table
  # under an Lrtx/L<n> label; `.word'/`.quad'/`.long' after a jump-table label.
  j=$(grep -cE '\.(word|quad|long|byte)[[:space:]]+\.?L' "$f" 2>/dev/null); j=${j:-0}
  if [ "$s" -gt 100 ] && [ "$j" -ge 4 ]; then
    printf '  ok   %-20s %6s bytes, %s jump-table entries\n' "$(basename "$f")" "$s" "$j"
  else
    printf '  FAIL %-20s %6s bytes, %s table entries <- reading is void\n' \
      "$(basename "$f")" "$s" "$j"
    head -3 "$f.err" 2>/dev/null | sed 's/^/         /'
    rc=9
  fi
done
exit $rc
