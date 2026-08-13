#!/bin/sh
# TASK #117 -- IS THE NULL GEN_FCN REALLY THE PRIMARY'S raw_optab_handler?
#
# The wall is a null PC out of `emit_move_insn_1', i.e. `GEN_FCN (icode)' was
# NULL.  `GEN_FCN (icode)' is `insn_data[icode].genfun', and `insn_data' IS
# already selected per back end (multi-target-select.cc).  So the suspect is
# the OTHER half of that expression: the icode.
#
# `optab_handler' -> `selected_raw_optab_handler' (optabs-query.cc) -> the BARE
# `raw_optab_handler', which is the PRIMARY's, from the un-namespaced
# `insn-opinit.o' that gcc/Makefile.in still puts in $(OBJS).  If that is the
# cause, then for the mode `init_set_costs' asks about:
#
#     bare(i386) raw_optab_handler(scode)  ->  some i386 icode I
#     insn_aarch64::insn_data[I].genfun    ->  NULL          <- the crash
#     insn_aarch64::raw_optab_handler(scode) -> aarch64's OWN icode J
#     insn_aarch64::insn_data[J].genfun    ->  non-NULL      <- what should run
#
# THE LAST TWO LINES ARE THE POINT.  Showing only that the i386 answer gives a
# null genfun would be one-sided: it cannot distinguish "the primary answered"
# from "aarch64 has no move pattern at all".  Both sides are required.
#
# -g0 tree, so nothing here uses `p symbol' or reads a local.  Function
# addresses come from `nm' and are called through an explicit cast; globals are
# read with `x/'.  (PRINCIPLES: `x/20gx sym' fails with "has unknown type" at
# -g0; the cast must be inside the expression.)
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b117}
SRCD=/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a75a2f51f92af9802
IN=${IN:-$SRCD/scratchpad/big.c}
O=${O:-/tmp/t117-cause}
TC=${TC:-specs-aarch64-unknown-linux-gnu-config}
mkdir -p "$O"
[ -s "$IN" ] || { echo "FATAL: no input $IN"; exit 9; }
[ -x "$D/gcc/cc1" ] || { echo "FATAL: no cc1 in $D/gcc"; exit 9; }
[ -s "$D/gcc/$TC" ] || { echo "FATAL: no target config $D/gcc/$TC"; exit 9; }

# mov_optab's value, and SImode's, read from the generated headers rather than
# hard-coded.  A hard-coded number here would be the same "shared numbering"
# bug this task is about, committed by the instrument.
OPI="$D/gcc/insn-opinit.h"
# NOTE ON THE AWK: the first version of this used gsub(/[ ,].*/,"") to trim,
# which deletes the WHOLE line -- every entry starts with the indent, so the
# match begins at column 1.  It printed nothing and the `-n' guard below caught
# it.  That guard is why this is a stopped script rather than a scode of 0
# silently probing `unknown_optab' in VOIDmode and reporting a tidy null.
enum_index () {   # $1 = file, $2 = regexp opening the enum, $3 = member
  awk -v open="$2" -v want="$3" '
    $0 ~ open {p=1; n=0; next}
    p && /^};/ {exit}
    p {
      s=$0; sub(/^[ \t]+/,"",s); sub(/[ \t]*[,=].*$/,"",s);
      if (s == "" || s == "{") next;
      if (s ~ /^[#\/]/) next;
      if (s == want) { print n; exit }
      n++
    }' "$1"
}
MOV=$(enum_index "$OPI" '^enum optab_tag' 'mov_optab')
[ -n "$MOV" ] || { echo "FATAL: could not read mov_optab's value from $OPI"; exit 9; }
SI=$(enum_index "$D/gcc/insn-modes.h" '^enum machine_mode' 'E_SImode')
[ -n "$SI" ] || { echo "FATAL: could not read E_SImode's value"; exit 9; }

# CONTROLS ON THE TWO NUMBERS ABOVE.  An enum walker that is off by one, or
# that silently stops early, produces a plausible small integer -- exactly the
# failure a `-n' test cannot see.  Both are cross-checked against a value the
# generator wrote independently.
ctl_void=$(enum_index "$D/gcc/insn-modes.h" '^enum machine_mode' 'E_VOIDmode')
[ "$ctl_void" = 0 ] || { echo "FATAL: E_VOIDmode came out as [$ctl_void], not 0; the enum walker is wrong"; exit 9; }
ctl_unk=$(enum_index "$OPI" '^enum optab_tag' 'unknown_optab')
[ "$ctl_unk" = 0 ] || { echo "FATAL: unknown_optab came out as [$ctl_unk], not 0; the enum walker is wrong"; exit 9; }
# And SImode must agree with what the compiler itself would compute.
si_decl=$(grep -c "^  E_SImode," "$D/gcc/insn-modes.h")
[ "$si_decl" = 1 ] || { echo "FATAL: E_SImode declared $si_decl times; refusing to score"; exit 9; }
# THE SHIFT IS 20, AND THE FIRST VERSION OF THIS SCRIPT USED 16.
# optabs-query.h:64 is `(op << 20) | mode'.  With 16 the scode named a
# different optab entirely, both handlers answered CODE_FOR_nothing, and the
# script printed a tidy, symmetric, ENTIRELY MEANINGLESS result -- "neither
# base has a move pattern for SImode", which is absurd on its face and which
# nothing in the harness objected to, because 0 is a legal answer.  Read from
# the header rather than re-typed, and backed by the positive control below.
SHIFT=$(sed -n 's/.*unsigned scode = (op << \([0-9]*\)) | mode;.*/\1/p' \
        "$SRCD/gcc/optabs-query.h" | head -1)
[ -n "$SHIFT" ] || { echo "FATAL: cannot read the scode shift from optabs-query.h"; exit 9; }
SCODE=$(( (MOV << SHIFT) | SI ))
echo "mov_optab=$MOV  E_SImode=$SI  shift=$SHIFT  scode=$SCODE"

# Addresses.  Asserted non-empty: an empty address silently becomes 0 in the
# gdb expression below and every arm would then read as "null", which is the
# answer this script is trying to establish.
addr () {
  a=$(nm "$D/gcc/cc1" | grep -F " $1" | awk '{print $1}' | head -1)
  [ -n "$a" ] || { echo "FATAL: no symbol matching [$1] in cc1" >&2; exit 9; }
  echo "0x$a"
}
A_BARE=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
  "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* T raw_optab_handler(unsigned int)' | awk '{print \$1}'")
A_A64=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
  "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* T insn_aarch64::raw_optab_handler(unsigned int)' | awk '{print \$1}'")
A_DATA=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
  "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* [DdBb] insn_aarch64::insn_data' | awk '{print \$1}'")
A_IBARE=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
  "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* T init_all_optabs(target_optabs\*)' | awk '{print \$1}'")
A_IA64=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
  "nm -C $D/gcc/cc1 | grep -x '[0-9a-f]* T insn_aarch64::init_all_optabs(target_optabs\*)' | awk '{print \$1}'")
for v in A_BARE A_A64 A_DATA A_IBARE A_IA64; do
  eval "x=\$$v"
  [ -n "$x" ] || { echo "FATAL: symbol for $v not found in cc1; refusing to score"; exit 9; }
  echo "$v = 0x$x"
done

# sizeof (struct insn_data_d) and the offset of genfun differ with CHECKING_P
# and with the target, so they are not hard-coded either: gdb is asked for
# them through the type, which IS present because insn_data is a typed global
# in the minimal symbol table of at least one object.  If gdb cannot type it,
# the arm below prints "UNTYPED" and the script fails rather than guessing.
# struct insn_data_d: name(8) output-union(8) genfun(8) operand(8) 5 chars(8)
# = 40 bytes, genfun at +16.  NOT hard-coded on faith: the stride is checked
# below against `nm -S' on BOTH bases' insn_data_tab, which is the only way to
# tell the 40-byte union layout from the 56-byte struct layout the
# !HAVE_DESIGNATED_UNION_INITIALIZERS arm of recog.h would give.
STRIDE=40
GENOFF=16
chk_stride () {
  b=$1; ncodes=$(grep -h 'NUM_INSN_CODES = ' "$D/gcc/insn-codes-$b.h" \
                 | sed 's/[^0-9]*\([0-9]*\).*/\1/')
  sz=$(nix-shell -I "nixpkgs=$NP" -p binutils --run \
        "nm -CS $D/gcc/insn-output-$b.o | grep -F 'insn_$b::insn_data_tab' | awk '{print \$2}'")
  [ -n "$ncodes" ] && [ -n "$sz" ] || { echo "FATAL: cannot size insn_data_tab for $b"; exit 9; }
  got=$(awk -v s="0x$sz" -v n="$ncodes" 'BEGIN{printf "%d", strtonum(s)/n}')
  echo "  $b: insn_data_tab / NUM_INSN_CODES = $got"
  [ "$got" = "$STRIDE" ] || { echo "FATAL: stride for $b is $got, not $STRIDE"; exit 9; }
}
echo "=== insn_data_d stride control (both bases must agree)"
chk_stride i386
chk_stride aarch64

cat > "$O/cmds.gdb" <<EOF
set pagination off
set confirm off
set \$scode = $SCODE

break *0x$A_BARE
break *0x$A_A64
break *0x$A_IBARE
break *0x$A_IA64

echo \n===== WHICH init_all_optabs / raw_optab_handler EVER RUNS =====\n
echo bp1 = bare raw_optab_handler, bp2 = insn_aarch64::raw_optab_handler\n
echo bp3 = bare init_all_optabs,   bp4 = insn_aarch64::init_all_optabs\n
run -quiet -nostdinc -O2 -ftarget-config=$TC $IN -o $O/out.s
echo \n--- first stop was:\n
frame 0
disable
echo \n--- continuing to the fault, with all four disabled\n
continue

echo \n===== AT THE FAULT =====\n
bt 6
info breakpoints

echo \n===== BOTH SIDES, for mov_optab in SImode, AT THE FAULT =====\n
set \$bare = ((int (*) (unsigned)) 0x$A_BARE) (\$scode)
set \$a64  = ((int (*) (unsigned)) 0x$A_A64)  (\$scode)
printf "bare(primary) raw_optab_handler(scode) = %d\n", \$bare
printf "insn_aarch64::raw_optab_handler(scode) = %d\n", \$a64

set \$tab = *(unsigned long *) 0x$A_DATA
printf "insn_aarch64::insn_data          = 0x%lx\n", \$tab
printf "  genfun for the BARE icode  (%d) = 0x%lx\n", \$bare, \
   *(unsigned long *) (\$tab + $STRIDE * \$bare + $GENOFF)
printf "  genfun for the a64  icode  (%d) = 0x%lx\n", \$a64, \
   *(unsigned long *) (\$tab + $STRIDE * \$a64 + $GENOFF)
printf "  name   for the BARE icode  (%d) = %s\n", \$bare, \
   *(char **) (\$tab + $STRIDE * \$bare)
printf "  name   for the a64  icode  (%d) = %s\n", \$a64, \
   *(char **) (\$tab + $STRIDE * \$a64)

echo \n===== NON-VACUITY =====\n
echo A move pattern for SImode exists on every real back end.  If BOTH\n
echo answers are CODE_FOR_nothing the scode is wrong and nothing above\n
echo means anything -- which is exactly what a mis-read shift produced.\n
if \$bare == 0 && \$a64 == 0
  printf "VACUOUS: both handlers answered CODE_FOR_nothing for mov/SImode\n"
else
  printf "OK: at least one handler answered a real icode\n"
end
EOF

nix-shell -I "nixpkgs=$NP" -p gdb --substituters 'https://cache.nixos.org/' \
  --run "cd $D/gcc && gdb -batch -x $O/cmds.gdb ./cc1" > "$O/gdb.log" 2> "$O/gdb.err"
echo "--- which handler is reached first (the selection question):"
grep -n 'Breakpoint [12],' "$O/gdb.log" | head -3
echo "    bare handler is at 0x$A_BARE, insn_aarch64's at 0x$A_A64"
cat "$O/gdb.log" | tail -20
