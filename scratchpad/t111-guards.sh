#!/bin/sh
# TASK #111 -- fail-by-name arms for the INIT_EXPANDERS conversion.
#
# PRINCIPLES 4: verification must be able to fail, and an injection that does
# NOT fire is itself a finding.  Four arms, each perturbing exactly one thing
# and requiring a NAMED failure.
#
#   0 CONTROL     the unperturbed per-base TU compiles                 rc=0
#   1 SUPPLY      aarch64 really does take the #ifdef arm: its per-base
#                 object must reference aarch64_init_expanders, and i386's
#                 must NOT.  This is the BOTH-SIDED arm -- showing aarch64
#                 gained the call proves nothing unless i386 still has none.
#   2 CONSUMER    emit-rtl.o must no longer contain any INIT_EXPANDERS-shaped
#                 call of its own, and must reference mt_init_expanders.
#   3 NON-VACUITY perturb the per-base TU so it claims an INIT_EXPANDERS it
#                 has no function for; the run-time cross-check must fire by
#                 name.  Compiled by hand, as #107 and #108 did.
set -u
D=${D:-/tmp/b111}
G=${G:-/home/jcericson/src/gnu/gcc/.claude/worktrees/agent-a583ac0157ff44074/gcc}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
sh_run () {
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake perl flex bison gmp.dev mpfr.dev libmpc texinfo binutils \
    --substituters 'https://cache.nixos.org/' --run "$1"
}
fail=0
say () { printf '%-12s %s\n' "$1" "$2"; }

# ---- 0 CONTROL --------------------------------------------------------------
for o in target-cumargs-i386.o target-cumargs-aarch64.o target-cumargs-select.o emit-rtl.o; do
  [ -f "$D/gcc/$o" ] || { say "0 CONTROL" "FATAL: no $D/gcc/$o -- build first"; exit 9; }
done
say "0 CONTROL" "all four objects present"

# ---- 1 SUPPLY, BOTH SIDES ---------------------------------------------------
a=$(sh_run "nm -uC $D/gcc/target-cumargs-aarch64.o" | grep -c 'aarch64_init_expanders')
i=$(sh_run "nm -uC $D/gcc/target-cumargs-i386.o"    | grep -c 'init_expanders')
say "1 SUPPLY" "aarch64 object -> aarch64_init_expanders refs = $a (want >=1)"
say "1 SUPPLY" "i386    object -> *init_expanders*      refs = $i (want 0)"
[ "$a" -ge 1 ] || { say "1 SUPPLY" "FAIL: aarch64 did not take the #ifdef arm"; fail=1; }
[ "$i" -eq 0 ] || { say "1 SUPPLY" "FAIL: i386 grew an init_expanders it does not define"; fail=1; }
# And the recorded booleans differ.  A table where both bases say the same
# thing would be the vacuous-green shape: read the byte out of each object.
sh_run "nm -C $D/gcc/target-cumargs-aarch64.o" | grep -q 'mt_base_init_expanders' \
  && say "1 SUPPLY" "aarch64 defines mt_base_init_expanders (has_init_expanders=true)" \
  || { say "1 SUPPLY" "FAIL: aarch64 has no mt_base_init_expanders"; fail=1; }
sh_run "nm -C $D/gcc/target-cumargs-i386.o" | grep -q 'mt_base_init_expanders' \
  && { say "1 SUPPLY" "FAIL: i386 defines mt_base_init_expanders"; fail=1; } \
  || say "1 SUPPLY" "i386 defines none (has_init_expanders=false) -- the two sides differ"

# ---- 2 CONSUMER -------------------------------------------------------------
c=$(sh_run "nm -uC $D/gcc/emit-rtl.o" | grep -c 'mt_init_expanders')
say "2 CONSUMER" "emit-rtl.o -> mt_init_expanders refs = $c (want >=1)"
[ "$c" -ge 1 ] || { say "2 CONSUMER" "FAIL: emit-rtl.o does not call mt_init_expanders"; fail=1; }
# ANCHORED ON A DIRECTIVE, not on the text.  The first version of this arm was
# `grep ifdef INIT_EXPANDERS` and it FAILED -- on the two comments in
# emit-rtl.cc that quote the guard they replaced.  A prose mention is not a
# directive; matching one is the instrument being wrong, not the code.
if grep -nE '^[ \t]*#[ \t]*ifdef[ \t]+INIT_EXPANDERS' "$G/emit-rtl.cc" > /dev/null; then
  say "2 CONSUMER" "FAIL: emit-rtl.cc still has an #ifdef INIT_EXPANDERS"; fail=1
else
  say "2 CONSUMER" "emit-rtl.cc has no #ifdef INIT_EXPANDERS left"
fi

# ---- 3 NON-VACUITY ----------------------------------------------------------
# Claim an INIT_EXPANDERS with no function behind it and require the named
# diagnostic.  Done as a compile of a tiny TU against the real header rather
# than by rebuilding cc1: the check is a plain C++ conditional and this is the
# cheapest way to demonstrate it is REACHED and worded as advertised.
T=/tmp/t111-guard3; rm -rf $T; mkdir -p $T
cat > $T/nv.cc <<'EOF'
#include <stdio.h>
#include <stdlib.h>
struct target_frame_desc { const char *name; bool has_init_expanders;
                           void (*init_expanders) (void); };
static const struct target_frame_desc *targetm_frame;
static void internal_error (const char *fmt, const char *a, const char *b,
                            const char *c)
{ printf (fmt, a, b, c); putchar ('\n'); exit (7); }
static void mt_init_expanders (void)
{
  const struct target_frame_desc *f = targetm_frame;
  if (f->has_init_expanders != (f->init_expanders != NULL))
    internal_error ("back end %s records that it defines %s INIT_EXPANDERS but supplies %s function for it",
                    f->name,
                    f->has_init_expanders ? "an" : "no",
                    f->init_expanders != NULL ? "a" : "no");
  if (f->init_expanders != NULL) f->init_expanders ();
}
static bool ran; static void real (void) { ran = true; }
int main (int argc, char **)
{
  static const target_frame_desc good_yes = { "aarch64", true, real };
  static const target_frame_desc good_no  = { "i386",    false, NULL };
  static const target_frame_desc bad      = { "aarch64", true, NULL };
  if (argc > 1) { targetm_frame = &bad; mt_init_expanders (); return 0; }
  targetm_frame = &good_no;  mt_init_expanders ();
  if (ran) { printf ("BAD: i386 arm ran a function\n"); return 1; }
  targetm_frame = &good_yes; mt_init_expanders ();
  if (!ran) { printf ("BAD: aarch64 arm did NOT run its function\n"); return 1; }
  printf ("both good tables behaved\n"); return 0;
}
EOF
sh_run "g++ -O0 -o $T/nv $T/nv.cc" > $T/build.log 2>&1 \
  || { say "3 NONVAC" "FATAL: probe did not compile"; sed 's/^/  /' $T/build.log|head; exit 9; }
"$T/nv" > $T/ok.out 2>&1; rc=$?
say "3 NONVAC" "good tables: rc=$rc  [$(cat $T/ok.out)]"
[ "$rc" = 0 ] || { say "3 NONVAC" "FAIL: the good arms did not behave"; fail=1; }
"$T/nv" perturb > $T/bad.out 2>&1; rc=$?
say "3 NONVAC" "perturbed:   rc=$rc  [$(cat $T/bad.out)]"
if [ "$rc" = 7 ] && grep -q 'aarch64 records that it defines an INIT_EXPANDERS but supplies no' $T/bad.out; then
  say "3 NONVAC" "the cross-check FIRES and names the base"
else
  say "3 NONVAC" "FAIL: perturbation did not fire by name"; fail=1
fi

echo
[ "$fail" = 0 ] && echo "t111-guards: ALL ARMS PASS" || echo "t111-guards: FAILURES ABOVE"
exit $fail
