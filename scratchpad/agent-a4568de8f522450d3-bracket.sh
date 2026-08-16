#!/bin/sh
# agent-a4568de8f522450d3-bracket.sh -- does the function-decoration bracket
# actually BALANCE now, and is every other target byte-identical?
#
# THE TWO CLAIMS UNDER TEST, stated so the arms can be compared against them:
#
#   riscv64  a function with `__attribute__((target(...)))' or `norelax' gets
#            `.option push' ... `.option pop'.  BEFORE, the push was emitted
#            (ASM_DECLARE_FUNCTION_NAME is converted) and the pop was not
#            (ASM_DECLARE_FUNCTION_SIZE was i386's/elfos.h's), so the ISA
#            override leaked forward into every later function in the file.
#
#   s390x    a function with `#pragma GCC target' gets `.machine push' /
#            `.machinemode zarch' ... `.machine pop'.  BEFORE, NEITHER
#            appeared: s390 is the only definer of ASM_OUTPUT_FUNCTION_PREFIX
#            so that `#ifdef' was false for all 47 bases, and the pop half was
#            elfos.h's.
#
# AND THE CONTROL, WHICH IS THE POINT.  x86_64 and aarch64 do not override
# ASM_DECLARE_FUNCTION_SIZE, so the per-base thunk evaluates the SAME
# `elfos.h:397' text shared code used to.  Their output must be byte-identical,
# and that is a prediction the conversion could falsify.
#
# STOCK IS THE REFERENCE, NOT THE PREVIOUS MULTI-TARGET OUTPUT.  The board's
# auto-inc work records why: an leaked answer can be accidentally RIGHT, and
# comparing against the previous multi-target output cannot see that.
set -u
PRE=${PRE:?set PRE to the pre build dir}
POST=${POST:?set POST to the post build dir}
O=${O:-/tmp/w-a4568de8f522450d3}/bracket
mkdir -p "$O"

for d in "$PRE" "$POST"; do
  [ -x "$d/gcc/cc1" ] || { echo "FATAL: no cc1 in $d"; exit 9; }
  [ -f "$d/all-gcc.rc" ] || { echo "FATAL: no .rc stamp in $d"; exit 9; }
  [ "$(cat "$d/all-gcc.rc")" = 0 ] || { echo "FATAL: $d stamp is not 0"; exit 9; }
done

# ---- the inputs.  Each is the SMALLEST thing that reaches the site. ----
cat > "$O/rv.c" <<'EOF'
__attribute__((target("arch=rv64gc_zbb"))) int tgt (int a) { return a + 1; }
int plain (int a) { return a + 2; }
EOF
cat > "$O/s390.c" <<'EOF'
#pragma GCC target("arch=z14")
int tgt (int a) { return a + 1; }
#pragma GCC reset_options
int plain (int a) { return a + 2; }
EOF
cat > "$O/plain.c" <<'EOF'
int f (int a) { return a + 1; }
int g (int a) { return a + 2; }
EOF

run () { # run <builddir> <triple> <src> <out>
  d=$1; t=$2; s=$3; o=$4
  cfg=$(ls "$d"/specs-"$t"-config 2>/dev/null | head -1)
  if [ -n "$cfg" ]; then
    "$d/gcc/cc1" -quiet -nostdinc -O2 -ftarget-config="$cfg" "$s" -o "$o" 2> "$o.err"
  else
    echo "NO-SPECS" > "$o"; echo "no specs-config for $t in $d" > "$o.err"
  fi
  echo $?
}

echo "== ARM 1: riscv64, the .option bracket"
for tag in pre post; do
  eval d=\$$( [ $tag = pre ] && echo PRE || echo POST )
  run "$d" riscv64-unknown-linux-gnu "$O/rv.c" "$O/rv.$tag.s" > /dev/null
  printf '  %-5s push=%s pop=%s arch=%s\n' "$tag" \
    "$(grep -c '\.option push' "$O/rv.$tag.s" 2>/dev/null)" \
    "$(grep -c '\.option pop'  "$O/rv.$tag.s" 2>/dev/null)" \
    "$(grep -c '\.option arch' "$O/rv.$tag.s" 2>/dev/null)"
done

echo "== ARM 2: s390x, the .machine bracket"
for tag in pre post; do
  eval d=\$$( [ $tag = pre ] && echo PRE || echo POST )
  run "$d" s390x-ibm-linux-gnu "$O/s390.c" "$O/s390.$tag.s" > /dev/null
  printf '  %-5s mpush=%s mpop=%s zarch=%s machine=%s\n' "$tag" \
    "$(grep -c '\.machine push'     "$O/s390.$tag.s" 2>/dev/null)" \
    "$(grep -c '\.machine pop'      "$O/s390.$tag.s" 2>/dev/null)" \
    "$(grep -c '\.machinemode zarch' "$O/s390.$tag.s" 2>/dev/null)" \
    "$(grep -c '\.machine "'        "$O/s390.$tag.s" 2>/dev/null)"
done

echo "== ARM 3: THE CONTROL -- targets that do not override the macro"
for t in x86_64-pc-linux-gnu aarch64-unknown-linux-gnu; do
  run "$PRE"  "$t" "$O/plain.c" "$O/p.pre.s"  > /dev/null
  run "$POST" "$t" "$O/plain.c" "$O/p.post.s" > /dev/null
  if cmp -s "$O/p.pre.s" "$O/p.post.s"; then
    printf '  %-28s IDENTICAL  (md5 %s)\n' "$t" "$(md5sum < "$O/p.pre.s" | cut -c1-12)"
  else
    printf '  %-28s DIFFERS <- the conversion is not transparent here\n' "$t"
    diff "$O/p.pre.s" "$O/p.post.s" | head -20 | sed 's/^/      /'
  fi
done

# NON-VACUITY.  Every arm above reads a COUNT out of a file, and a missing
# cc1, an empty .s or a compile failure all score 0 -- in the direction that
# makes `pre' look correct.  So: the files must be non-trivial, and the ONE
# thing that must be true on both sides (a function label) must be there.
echo
echo "NON-VACUITY: the .s files must contain real code on BOTH sides"
rc=0
for f in "$O/rv.pre.s" "$O/rv.post.s" "$O/s390.pre.s" "$O/s390.post.s"; do
  n=$(grep -c 'tgt' "$f" 2>/dev/null || echo 0)
  s=$(wc -c < "$f" 2>/dev/null || echo 0)
  if [ "$n" -ge 1 ] && [ "$s" -gt 100 ]; then
    printf '  ok   %-22s %6s bytes, names tgt\n' "$(basename "$f")" "$s"
  else
    printf '  FAIL %-22s %6s bytes, tgt=%s  <- every count from it is void\n' \
      "$(basename "$f")" "$s" "$n"
    head -3 "$f.err" 2>/dev/null | sed 's/^/         /'
    rc=9
  fi
done
exit $rc
