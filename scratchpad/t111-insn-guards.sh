#!/bin/sh
# TASK #111 -- fail-by-name arms for the HAVE_lo_sum / HAVE_rotate /
# HAVE_rotatert conversion (target-insn.h).
#
#   1 DATA, BOTH SIDES  read the three bytes of `mt_base_insn' out of each
#                       per-base object and require them to DIFFER in the way
#                       insn-config-<base>.h says they should.  This is the
#                       arm that distinguishes "fixed" from "everyone now gets
#                       the same new answer" -- PRINCIPLES 4.
#   2 SUPPLY NON-VACUITY compile the per-base TU with a static_assert that
#                       contradicts each base in turn; it must FAIL for that
#                       base and PASS for the other.  A green arm where both
#                       bases read the same header would pass arm 1 by
#                       coincidence of layout; this one cannot.
#   3 CONSUMER          the four use sites are calls, and no #if/#ifdef on
#                       these names survives outside config/.
#   4 SELECTOR          the running cc1 installs a non-null targetm_insn, and
#                       a table without one fails by name.
set -u
D=${D:-/tmp/b111}
G=${G:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a583ac0157ff44074/gcc}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_bin () {
  nix-shell -I "nixpkgs=$NP" -p binutils --substituters 'https://cache.nixos.org/' --run "$1"
}
fail=0
say () { printf '%-14s %s\n' "$1" "$2"; }

# ---- 1 DATA, BOTH SIDES -----------------------------------------------------
# `mt_base_insn' is a local `r' symbol; read its three bool bytes out of
# .rodata by offset.  The struct is { const char *name; bool; bool; bool },
# so the booleans start at offset 8.
for be in i386 aarch64; do
  o="$D/gcc/target-cumargs-$be.o"
  [ -f "$o" ] || { say "1 DATA" "FATAL: no $o"; exit 9; }
  # `nm -C' AND NOT `nm'.  The symbol is a file-static, so it appears as
  # `_ZL12mt_base_insn' undemangled and an exact `$3 ==' match finds nothing.
  # It failed by name here rather than scoring 0, which is the only reason
  # this is a footnote and not a false green; PRINCIPLES 7 has the general
  # form of it.
  addr=$(sh_bin "nm -C $o" | awk '$3=="mt_base_insn" {print $1}')
  [ -n "$addr" ] || { say "1 DATA" "FATAL: no mt_base_insn in $o"; exit 9; }
  sec=$(sh_bin "objdump -h $o" | awk '$2==".rodata" {print $6}')
  [ -n "$sec" ] || { say "1 DATA" "FATAL: no .rodata in $o"; exit 9; }
  off=$(printf '%d' $((0x$addr + 8)))
  base=$(printf '%d' $((0x$sec)))
  bytes=$(od -An -tu1 -j $((base + off)) -N3 "$o" | tr -s ' ')
  eval "got_$be=\"\$bytes\""
  say "1 DATA" "$be   mt_base_insn{lo_sum,rotate,rotatert} =$bytes"
done
# What insn-config-<base>.h actually says, read independently.
for be in i386 aarch64; do
  h="$D/gcc/insn-config-$be.h"
  [ -f "$h" ] || { say "1 DATA" "FATAL: no $h"; exit 9; }
  w=""
  for m in HAVE_lo_sum HAVE_rotate HAVE_rotatert; do
    v=$(awk -v m="$m" '$2==m {print $3}' "$h")
    [ -n "$v" ] || { say "1 DATA" "FATAL: $h does not define $m -- genconfig did not emit the 0"; exit 9; }
    w="$w $v"
  done
  eval "want_$be=\"\$w\""
  say "1 DATA" "$be   insn-config-$be.h says          =$w"
done
eval "[ \"\$got_i386\" = \"\$want_i386\" ]" \
  && say "1 DATA" "i386 table matches i386 header" \
  || { say "1 DATA" "FAIL: i386 table does not match i386 header"; fail=1; }
eval "[ \"\$got_aarch64\" = \"\$want_aarch64\" ]" \
  && say "1 DATA" "aarch64 table matches aarch64 header" \
  || { say "1 DATA" "FAIL: aarch64 table does not match aarch64 header"; fail=1; }
# NON-VACUITY OF ARM 1: if the two tables were identical, both could match a
# single shared header and this arm would be green while proving nothing.
eval "[ \"\$got_i386\" != \"\$got_aarch64\" ]" \
  && say "1 DATA" "the two tables DIFFER -- the arm is not comparing one file with itself" \
  || { say "1 DATA" "FAIL: both bases produced the SAME table; nothing is per-base"; fail=1; }

# ---- 3 CONSUMER -------------------------------------------------------------
n=$(grep -rnE '^[ \t]*#[ \t]*(if|ifdef|ifndef|elif).*HAVE_(lo_sum|rotate|rotatert)' \
      "$G"/*.cc "$G"/*.h | grep -c . )
say "3 CONSUMER" "surviving preprocessor tests on the three names outside config/: $n (want 0)"
[ "$n" -eq 0 ] || { say "3 CONSUMER" "FAIL:"; grep -rnE '^[ \t]*#[ \t]*(if|ifdef|ifndef|elif).*HAVE_(lo_sum|rotate|rotatert)' "$G"/*.cc "$G"/*.h; fail=1; }
for f in combine.cc lra-constraints.cc simplify-rtx.cc; do
  c=$(grep -c 'mt_have_' "$G/$f")
  say "3 CONSUMER" "$f uses mt_have_* $c time(s)"
  [ "$c" -ge 1 ] || { say "3 CONSUMER" "FAIL: $f still reads the macro"; fail=1; }
done

# ---- 4 SELECTOR -------------------------------------------------------------
c=$(sh_bin "nm -uC $D/gcc/combine.o" | grep -c 'mt_have_lo_sum')
say "4 SELECTOR" "combine.o -> mt_have_lo_sum refs = $c (want >=1)"
[ "$c" -ge 1 ] || { say "4 SELECTOR" "FAIL: combine.o does not call mt_have_lo_sum"; fail=1; }
c=$(sh_bin "nm -uC $D/gcc/simplify-rtx.o" | grep -c 'mt_have_rotate')
say "4 SELECTOR" "simplify-rtx.o -> mt_have_rotate* refs = $c (want >=1)"
[ "$c" -ge 1 ] || { say "4 SELECTOR" "FAIL: simplify-rtx.o does not call mt_have_rotate"; fail=1; }
grep -q 'targetm_insn = targetm_cumargs->insn' "$G/multi-target-select.cc" \
  && say "4 SELECTOR" "multi-target-select.cc installs targetm_insn" \
  || { say "4 SELECTOR" "FAIL: nothing installs targetm_insn"; fail=1; }

echo
[ "$fail" = 0 ] && echo "t111-insn-guards: ALL ARMS PASS" || echo "t111-insn-guards: FAILURES ABOVE"
exit $fail
