#!/bin/sh
# agent-ae59966cf819d72ef-jtboth.sh -- BOTH-SIDED, by target, on the case-vector
# ENTRIES.  PRE vs POST, one input path compiled by both compilers.
#
# WHAT TO EXPECT, STATED BEFORE THE RUN so a flat column is not read as a
# failed conversion.  x86_64, aarch64, riscv64 and s390x are all LP64 and all
# spell `.L', and i386's `ix86_output_addr_vec_elt' emits `.quad .L<n>' for
# exactly that combination -- so all four are CORRECT BY LUCK today and all
# four must come out BYTE-IDENTICAL.  That is the control, and it is a
# prediction this conversion could falsify.
#
# THE TARGET THAT MOVES IS A 32-BIT ONE, and none is on the four-target board.
# `arm-unknown-eabi' is added here through `mt-specs-fallback.sh', i.e. a
# specs-config probed against the BUILD MACHINE's `as'.  Per that script's own
# header that is asked for on purpose and its ANSWERS are trusted for nothing;
# what it supplies is a well-formed config so `cc1' will start.  That is
# legitimate for THIS question and the reason is specific: the case-vector
# directive comes from the back end's own macro
# (`arm.h's ASM_OUTPUT_ADDR_DIFF_ELT switches on `GET_MODE (BODY)'), not from
# anything the assembler probe reports.  Same argument `mt-specs-fallback.sh'
# makes for the ia64 scheduler arm.
#
# ONE INPUT PATH FOR BOTH SIDES.  Compiling `x.pre.c' and `x.post.c' makes
# every target "differ" in its `.file' directive -- the filename sensitivity
# PRINCIPLES records, manufactured by accident.  The file is written once.
set -u
PRE=${PRE:?set PRE to the pre build dir}
POST=${POST:?set POST to the post build dir}
O=${O:-/tmp/w-agent-ae59966cf819d72ef}/jtboth
mkdir -p "$O"

for d in "$PRE" "$POST"; do
  [ -x "$d/gcc/cc1" ] || { echo "FATAL: no cc1 in $d"; exit 9; }
  [ "$(cat "$d/all-gcc.rc" 2>/dev/null)" = 0 ] || { echo "FATAL: $d not stamped rc=0"; exit 9; }
done
[ "$PRE" != "$POST" ] || { echo "FATAL: PRE and POST are the same directory"; exit 9; }

IN=$O/sw.c
cat > "$IN" <<'EOF'
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

changed=0; same=0; skipped=0; scored=0
for cfg in "$PRE"/lib/gcc/*/*/specs-config; do
  t=$(basename "$(dirname "$cfg")")
  pcfg=$POST/lib/gcc/$(basename "$(dirname "$(dirname "$cfg")")")/$t/specs-config
  [ -f "$pcfg" ] || { printf '%-28s SKIP (no POST specs-config)\n' "$t"; skipped=$((skipped+1)); continue; }
  "$PRE/gcc/cc1"  -quiet -nostdinc -O2 -ftarget-config="$cfg"  "$IN" -o "$O/$t.pre.s"  2> "$O/$t.pre.err"
  rp=$?
  "$POST/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$pcfg" "$IN" -o "$O/$t.post.s" 2> "$O/$t.post.err"
  rq=$?
  if [ $rp -ne 0 ] || [ $rq -ne 0 ]; then
    printf '%-28s cc1 rc pre=%s post=%s -- not scored\n' "$t" "$rp" "$rq"
    skipped=$((skipped+1)); continue
  fi
  # NON-VACUITY PER TARGET: there must BE a case vector, or "identical" means
  # "two files with no jump table in them", which is the null result wearing a
  # pass.
  n=$(grep -cE '^[[:space:]]*\.(long|quad|word|dword|hword|byte|short|2byte|4byte|8byte|half|gpword|gpdword)[[:space:]]' "$O/$t.pre.s")
  if [ "$n" -lt 8 ]; then
    printf '%-28s NO TABLE (%s entry lines) -- not scored\n' "$t" "$n"
    skipped=$((skipped+1)); continue
  fi
  scored=$((scored+1))
  a=$(md5sum < "$O/$t.pre.s" | cut -c1-12)
  b=$(md5sum < "$O/$t.post.s" | cut -c1-12)
  if [ "$a" = "$b" ]; then
    printf '%-28s IDENTICAL  md5 %s   entries=%s\n' "$t" "$a" "$n"
    same=$((same+1))
  else
    printf '%-28s CHANGED    %s -> %s\n' "$t" "$a" "$b"
    diff "$O/$t.pre.s" "$O/$t.post.s" | head -14 | sed 's/^/    /'
    changed=$((changed+1))
  fi
done

echo
echo "scored=$scored  changed=$changed  byte-identical=$same  skipped=$skipped"
[ "$scored" -gt 0 ] || {
  echo "FATAL: nothing was scored.  Every line above is a skip, which is"
  echo "       indistinguishable from 'the conversion changed nothing'."
  exit 9; }
# THE md5s MUST DIFFER BETWEEN TARGETS.  Two targets reporting IDENTICAL with
# the SAME md5 is not two agreeing compilers, it is one placeholder written
# twice -- the exact false green `-bracket.sh' produced and nearly banked.
u=$(for f in "$O"/*.pre.s; do md5sum < "$f"; done | sort -u | grep -c .)
[ "$u" -ge "$scored" ] || {
  echo "FATAL: $scored targets produced only $u distinct PRE outputs -- two"
  echo "       architectures cannot emit the same bytes.  Something is writing"
  echo "       a placeholder."
  exit 9; }
echo "control ok: all $scored PRE outputs are distinct from one another"
