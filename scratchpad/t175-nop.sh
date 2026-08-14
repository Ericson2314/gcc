#!/bin/sh
# #175 -- the five-line `gen_nop' witness, read from the RUNNING compiler.
#
# The instrument is the ICE, not a symbol table.  Three bodies named gen_nop
# exist in cc1 (bare, insn_i386::, insn_aarch64::) and every arrangement of
# them LINKS, so `nm' cannot say which one shared code binds.  The RTL dump
# can: i386's nop pattern is a bare `(const_int 0)' and aarch64's is
# `(unspec [(const_int 0)] UNSPEC_NOP)', so the vregs dump names the back end
# that actually answered.
#
# `nm' without -C matches nothing here in any case -- these names are mangled
# (_Z7gen_nopv) -- so a grep written against the C spelling reads exactly like
# "the name is already gone".
#
# usage: B=<builddir> t175-nop.sh
set -u
B=${B:?set B to the build dir}
# BASE-VER lives in the SOURCE tree, not the build dir.
SRC=$(cat "$B/MY-SRC")
VER=$(cat "$SRC/gcc/BASE-VER")
[ -n "$VER" ] || { echo "FATAL: empty BASE-VER"; exit 9; }
CC1="$B/gcc/cc1"
[ -x "$CC1" ] || { echo "FATAL: no $CC1"; exit 9; }

C=/tmp/t175-min.c
printf 'void foo (int x) { if (x) ; }\n' > $C

rc_all=0
for T in aarch64-unknown-linux-gnu x86_64-pc-linux-gnu; do
  CFG="$B/lib/gcc/$VER/$T/specs-config"
  [ -f "$CFG" ] || { echo "FATAL[$T]: no $CFG -- target-specs was not run"; exit 9; }
  echo "== $T  specs md5 $(md5sum < "$CFG" | cut -c1-12)  wc -l $(wc -l < "$CFG")"

  D=/tmp/t175-vregs-$T.txt
  rm -f $D
  out=$("$CC1" -quiet -nostdinc -O0 -ftarget-config="$CFG" \
	  -fdump-rtl-vregs=$D $C -o /tmp/t175-$T.s 2>&1)
  rc=$?
  echo "   cc1 rc=$rc"
  [ "$rc" = 0 ] || rc_all=1
  echo "$out" | grep -m1 'internal compiler error' && rc_all=1

  # WHICH back end's nop pattern reached the insn stream.  Both arms are
  # printed, so an empty result cannot read as either answer.
  echo "   nop insn in the vregs dump:"
  sed -n '/(insn /,/^$/p' $D | grep -B1 -A2 'UNSPEC_NOP\|{nop}' | sed 's/^/     /' \
    || echo "     (none -- and `none' is not the same as `correct')"
  echo "   asm:  $(grep -c '^	nop$' /tmp/t175-$T.s) nop mnemonic(s)"
done
echo "overall rc=$rc_all  (0 = neither target ICEs)"
exit $rc_all
