#!/bin/sh
# TASK #112 GUARDS -- BOTH-SIDED EVIDENCE FOR THE FIVE CONVERTED OPTIONAL
# SCALARS.
#
# PRINCIPLES 4: showing aarch64 gets aarch64's answer proves nothing unless
# x86_64 still gets x86_64's.  Here x86_64's answer is ABSENCE for all five --
# i386 defines none of them -- so the two sides are maximally different and
# the comparison has real content:
#
#   aarch64   has_static_chain_regnum          1, value 18   (R18_REGNUM)
#             has_static_chain_incoming_regnum 0, value POISON
#             has_empty_field_boundary         1, value 32
#             has_structure_size_boundary      1, value 8
#             has_dwarf_alt_frame_return_column 1, value 96
#                                  (AARCH64_DWARF_V0 64 + AARCH64_DWARF_NUMBER_V 32)
#   i386      all five has_ == 0, all five values == the POISON
#
# THE POISON IN THE VALUE SLOT IS THE LOAD-BEARING PART OF THE i386 SIDE.  A
# check that only asked "is has_ zero" would pass just as well against a build
# where the refresh never ran, because zero is what an unwritten bool looks
# like.  The value slot still holding 0xdeadbeef is what distinguishes "this
# back end genuinely has no answer" from "nobody asked".
#
# Reads the RUNNING cc1 rather than the source, and reads it once per selected
# target, so it is a TAB-shaped arm (PRINCIPLES: the header probe's per-base
# context lacks MULTI_TARGET_TARGETM_BASE and would compare a redirect with
# itself -- a vacuous green this project has correctly refused).
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b112}
IN=${IN:-/tmp/claude-1000/-home-jcericson-src-gnu-gcc-multi-target/302b44ba-1161-4d28-acc5-9fe8f40a000b/scratchpad/min.c}
O=${O:-/tmp/t112-guards}
rm -rf "$O"; mkdir -p "$O"
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1"; exit 9; }
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
fail=0

# `estimate_move_cost' is reached by BOTH targets (x86_64 passes through it,
# aarch64 faults in it), and both are after init_targetm_cdata, so one
# breakpoint serves both sides.  The tree is -g0, so targetm_cdata has no
# type: dump raw memory through the minimal symbol instead.
dump () { # $1 = target triple, $2 = out file
  cat > "$O/cmds.gdb" <<EOF
set pagination off
set confirm off
break estimate_move_cost
run -quiet -nostdinc -O2 -ftarget-config=specs-$1-config $IN -o $O/$1.s
printf "CDATA-DUMP\n"
x/64xh &targetm_cdata
EOF
  nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
    --run "cd $D/gcc && gdb -batch -x $O/cmds.gdb ./cc1" > "$2" 2> "$2.err"
}

dump x86_64-pc-linux-gnu     "$O/x86.log"
dump aarch64-unknown-linux-gnu "$O/a64.log"

for f in "$O/x86.log" "$O/a64.log"; do
  grep -q CDATA-DUMP "$f" || { echo "FAIL: no dump in $f (breakpoint never hit?)"; fail=1; }
done
[ "$fail" = 0 ] || { echo "t112-guards: ABORTED, no usable dumps"; exit 1; }

sed -n '/CDATA-DUMP/,$p' "$O/x86.log" | grep '^0x' > "$O/x86.hex"
sed -n '/CDATA-DUMP/,$p' "$O/a64.log" | grep '^0x' > "$O/a64.hex"

echo "=== ARM 1: the two dumps must DIFFER ==="
echo "    (if they are identical, one base's data is answering for both --"
echo "     the exact bug this mechanism exists to remove)"
if cmp -s "$O/x86.hex" "$O/a64.hex"; then
  echo "  FAIL: x86_64 and aarch64 see BYTE-IDENTICAL target_cdata"; fail=1
else
  echo "  PASS: the dumps differ"
fi

echo
echo "=== ARM 2: aarch64 must show its OWN values ==="
# 0xdead/0xbeef are the poison halves; the real values are small.
for v in 0012 0020 0008 0060; do
  case $v in 0012) n="STATIC_CHAIN_REGNUM 18 (R18_REGNUM)" ;;
             0020) n="EMPTY_FIELD_BOUNDARY 32" ;;
             0008) n="STRUCTURE_SIZE_BOUNDARY 8" ;;
             0060) n="DWARF_ALT_FRAME_RETURN_COLUMN 96" ;; esac
  if grep -qi "0x$v" "$O/a64.hex"; then
    echo "  PASS: aarch64 dump contains 0x$v -- $n"
  else
    echo "  FAIL: aarch64 dump lacks 0x$v -- $n"; fail=1
  fi
done

echo
echo "=== ARM 3: i386 must show the POISON in those value slots ==="
echo "    (absence represented, not inferred: 0xbeef/0xdead must be present)"
nb=$(grep -ci 'beef' "$O/x86.hex")
nd=$(grep -ci 'dead' "$O/x86.hex")
echo "  x86_64 dump lines containing beef: $nb   dead: $nd"
if [ "$nb" -ge 1 ]; then
  echo "  PASS: x86_64 value slots still hold the poison, i.e. ABSENT is recorded"
else
  echo "  FAIL: no poison in the x86_64 dump -- absence is not being represented"; fail=1
fi

echo
echo "=== ARM 4: NEGATIVE CONTROL -- the arm must be able to fail ==="
if grep -qi '0x0060' "$O/x86.hex" && grep -qi '0x0020' "$O/x86.hex"; then
  echo "  FAIL: x86_64 shows aarch64's 96 AND 32 -- the arm cannot discriminate"
  fail=1
else
  echo "  PASS: x86_64 does NOT carry aarch64's values, so ARM 2 is discriminating"
fi

echo
[ "$fail" = 0 ] && echo "t112-guards: ALL ARMS PASS" || echo "t112-guards: FAILURES ABOVE"
exit $fail
