#!/bin/sh
# #122 -- guards for the ADJUST_REG_ALLOC_ORDER dispatch.
#
# ARM 2 reads the RUNNING cc1 rather than a header or an object.  The build is
# -g0, so breakpoints are set on the ADDRESSES `nm' reports, and the addresses
# are asserted DISTINCT before anything is scored -- otherwise "both bases
# entered their own function" is satisfiable by one function with two names.
#
# ARM 4 is the injection the brief requires: it puts ira.cc's `#ifdef
# ADJUST_REG_ALLOC_ORDER' back, rebuilds only ira.o, and REQUIRES the primary's
# symbol to reappear as an undefined reference AND the old ICE to come back at
# its old site.  Then it restores and requires both to go away again.  A guard
# that has only ever said PASS has not been shown able to say FAIL.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
B=${B:-/tmp/b122}
CFG=$B/lib/gcc/17.0.0
A64=$CFG/aarch64-unknown-linux-gnu/specs-config
X86=$CFG/x86_64-pc-linux-gnu/specs-config
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
pass=0; fail=0
ok   () { echo "PASS  $*"; pass=$((pass+1)); }
bad  () { echo "FAIL  $*"; fail=$((fail+1)); }

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_run () { nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev \
              mpfr.dev libmpc texinfo gdb --substituters 'https://cache.nixos.org/' \
              --run "$1"; }

# ARM 2 NEEDS A FUNCTION, AND THIS COST A FALSE NEGATIVE.
# The first version of this harness probed with `small.c' (`int x = 1;').  No
# breakpoint was ever hit and the non-vacuity guard declared the probe blind --
# correctly, and for a reason that is not about the dispatch at all: `ira_init'
# runs from `init_function_start', so a translation unit with no FUNCTION in it
# never reaches the allocation order.  An input chosen to be trivial was
# trivial in the one way that mattered.
printf 'int f (int x) { return x * x; }\n' > "$B/fn.c" || exit 9
for f in "$A64" "$X86" "$B/gcc/cc1" "$B/big.c" "$B/small.c" "$B/fn.c"; do
  [ -s "$f" ] || { echo "FATAL: missing or empty $f"; exit 9; }
done

# ---------------------------------------------------------------- ARM 1
# Both adjust functions are in the binary, at DIFFERENT addresses.
sh_run "cd $B/gcc && nm -C cc1" > "$B/g-nm.txt" 2>&1
AX=$(sed -n 's/^\([0-9a-f]*\) T x86_order_regs_for_local_alloc()$/\1/p' "$B/g-nm.txt")
AA=$(sed -n 's/^\([0-9a-f]*\) T aarch64_adjust_reg_alloc_order()$/\1/p' "$B/g-nm.txt")
if [ -z "$AX" ] || [ -z "$AA" ]; then
  echo "FATAL non-vacuity: one or both adjust symbols absent from cc1 (x86='$AX' a64='$AA')"; exit 9
fi
if [ "$AX" = "$AA" ]; then
  echo "FATAL non-vacuity: the two adjust symbols share address $AX; ARM 2 would be tautological"; exit 9
fi
ok "ARM 1  both ADJUST_REG_ALLOC_ORDER bodies present at distinct addresses (x86=$AX aarch64=$AA)"

# ---------------------------------------------------------------- ARM 2
# BOTH-SIDED, ON THE RUNNING cc1.  Each base must enter its OWN body and not
# the other's.
probe_running () {
  cfg=$1; out=$2
  cat > "$B/g.gdb" <<EOF
set confirm off
set pagination off
break *0x$AX
commands
silent
printf "ENTER_X86\n"
continue
end
break *0x$AA
commands
silent
printf "ENTER_A64\n"
continue
end
run
EOF
  sh_run "cd $B/gcc && gdb -q -batch -x $B/g.gdb --args ./cc1 -quiet -nostdinc $B/fn.c -o /dev/null -ftarget-config=$cfg" > "$out" 2>&1
}
probe_running "$X86" "$B/g-run-x86.txt"
probe_running "$A64" "$B/g-run-a64.txt"
xx=$(grep -c ENTER_X86 "$B/g-run-x86.txt"); xa=$(grep -c ENTER_A64 "$B/g-run-x86.txt")
ax=$(grep -c ENTER_X86 "$B/g-run-a64.txt"); aa=$(grep -c ENTER_A64 "$B/g-run-a64.txt")
if [ "$((xx+xa+ax+aa))" -eq 0 ]; then
  echo "FATAL non-vacuity: no breakpoint was hit in either run; the probe read nothing"; exit 9
fi
[ "$xx" -gt 0 ] && [ "$xa" -eq 0 ] \
  && ok "ARM 2a x86_64 selection enters i386's body ($xx) and NOT aarch64's ($xa)" \
  || bad "ARM 2a x86_64: i386 body $xx, aarch64 body $xa"
[ "$aa" -gt 0 ] && [ "$ax" -eq 0 ] \
  && ok "ARM 2b aarch64 selection enters aarch64's body ($aa) and NOT i386's ($ax)" \
  || bad "ARM 2b aarch64: aarch64 body $aa, i386 body $ax"

# ---------------------------------------------------------------- ARM 3
# ira.o, a middle-end object, must no longer name the primary's function.
undef_count () { sh_run "cd $B/gcc && nm -uC ira.o" 2>/dev/null \
                   | grep -cw 'x86_order_regs_for_local_alloc()'; }
n=$(undef_count)
[ "$n" -eq 0 ] \
  && ok "ARM 3  ira.o has no undefined reference to x86_order_regs_for_local_alloc ($n)" \
  || bad "ARM 3  ira.o still names the primary's adjust function ($n)"

# ---------------------------------------------------------------- ARM 4
# THE INJECTION.  Put the compile-time dispatch back and require the old
# symbol AND the old ICE to return; then restore and require both to go.
IRA=$SRC/gcc/ira.cc
cp "$IRA" "$B/ira.cc.orig" || exit 9
restore () { cp "$B/ira.cc.orig" "$IRA"; }
trap 'restore' EXIT INT TERM

# WHERE big.c STOPS, IN EITHER OF THE TWO ICE SHAPES.
#
# The first version of this matched only `internal compiler error: in <fn>, at
# <file>:<line>' and so reported the INJECTED run as "no ICE at all" -- a false
# negative produced by the change under test, because the whole point of the
# ira.cc:507 rewrite is that the failure now reports as a NAMED diagnostic
# ("back end 'aarch64': register class ...") and not as a bare assert site.
# The instrument was written against the old shape of the thing it measures.
big_ice_site () {
  sh_run "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o /dev/null $B/big.c" \
    > /dev/null 2> "$B/g-big.txt"
  s=$(sed -n 's/.*internal compiler error: in \([a-z_]*\), at \([^ ]*\).*/\1 \2/p' "$B/g-big.txt" | head -1)
  [ -n "$s" ] || s=$(sed -n "s/.*internal compiler error: \(back end '[a-z0-9_]*': register class '[A-Z_]*'\).*/NAMED \1/p" "$B/g-big.txt" | head -1)
  echo "$s"
}

before_site=$(big_ice_site)

# perl, not python3: python3 is not in this project's nix shell and was not on
# the ambient PATH either, so the first run of this arm aborted with
# "python3: command not found" -- which the harness reported as a FATAL rather
# than skipping, which is the only reason it was noticed.
cat > "$B/inject.pl" <<'PL'
use strict; use warnings;
my $p = $ARGV[0];
local $/; open my $fh, '<', $p or die "cannot read $p: $!";
my $s = <$fh>; close $fh;
my $new = "  if (targetm_regs->adjust_reg_alloc_order != NULL)\n"
        . "    targetm_regs->adjust_reg_alloc_order ();";
my $old = "#ifdef ADJUST_REG_ALLOC_ORDER\n  ADJUST_REG_ALLOC_ORDER;\n#endif";
die "INJECTION SITE NOT FOUND -- the guard would be testing nothing\n"
  unless index($s, $new) >= 0;
my $i = index($s, $new);
substr($s, $i, length($new)) = $old;
open my $out, '>', $p or die "cannot write $p: $!";
print $out $s; close $out;
PL
sh_run "perl $B/inject.pl $IRA" || { echo "FATAL: injection could not be applied"; exit 9; }

sh_run "cd $B/gcc && make -j8 cc1" > "$B/g-inj-build.log" 2>&1
irc=$?
n_inj=$(undef_count)
inj_site=$(big_ice_site)
restore
sh_run "cd $B/gcc && make -j8 cc1" > "$B/g-res-build.log" 2>&1
rrc=$?
n_res=$(undef_count)
res_site=$(big_ice_site)

if [ "$irc" -ne 0 ] || [ "$rrc" -ne 0 ]; then
  bad "ARM 4  a rebuild failed (injected rc=$irc restored rc=$rrc); the arm cannot be scored"
else
  [ "$n_inj" -eq 1 ] \
    && ok "ARM 4a INJECTION: removing the run-time dispatch brings the primary's symbol BACK into ira.o (0 -> $n_inj)" \
    || bad "ARM 4a INJECTION DID NOT FIRE: ira.o undefined refs to x86_order_regs_for_local_alloc = $n_inj, expected 1"
  [ "$n_res" -eq 0 ] \
    && ok "ARM 4b RESTORE verified: the symbol is gone again ($n_inj -> $n_res)" \
    || bad "ARM 4b RESTORE FAILED: symbol count $n_res, expected 0"
  # The injected build must fail in setup_class_hard_regs' check -- either as
  # the old bare assert or, as it does now, as the named diagnostic that
  # replaced it.  Requiring the NAMED form additionally proves the mitigation
  # written for this fault actually fires on this fault, rather than being an
  # unfired guard that merely reads as protection.
  case "$inj_site" in
    setup_class_hard_regs*ira.cc*)
      ok "ARM 4c INJECTION reproduces the ORIGINAL wall (bare assert form): $inj_site" ;;
    NAMED*aarch64*register\ class*)
      ok "ARM 4c INJECTION reproduces the wall AND the new diagnostic fires, naming the base and the class: $inj_site" ;;
    *) bad "ARM 4c injection did not reproduce the ICE; got '${inj_site:-<no ICE at all>}'" ;;
  esac
  if [ "$res_site" = "$before_site" ]; then
    ok "ARM 4d RESTORE verified on behaviour too: big.c stops where it did before the injection ($res_site)"
  else
    bad "ARM 4d after restore big.c stops at '$res_site', but before the injection it stopped at '$before_site'"
  fi
fi

# ---------------------------------------------------------------- ARM 5
# The property that must not regress.
sh_run "cd $B/gcc && ./aarch64-unknown-linux-gnu-gcc -S -nostdinc -o $B/g-small.s $B/small.c" \
  > /dev/null 2> "$B/g-small.err"
src=$?
sz=$(wc -c < "$B/g-small.s" 2>/dev/null || echo 0)
esz=$(wc -c < "$B/g-small.err")
[ "$src" -eq 0 ] && [ "$sz" -gt 300 ] && [ "$esz" -eq 0 ] \
  && ok "ARM 5  aarch64 'int x = 1;' still compiles: rc=0, $sz bytes of .s, empty stderr" \
  || bad "ARM 5  aarch64 small input regressed: rc=$src, $sz bytes, $esz bytes of stderr"

echo "--- t122 guards: $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ]
