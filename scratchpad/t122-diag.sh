#!/bin/sh
# #122 -- WHY setup_class_hard_regs asserts.  Reads the RUNNING cc1 under gdb.
#
# The hypothesis under test: ira.cc's `#ifdef REG_ALLOC_ORDER' and
# `#ifdef ADJUST_REG_ALLOC_ORDER' are compile-time tests in a MIDDLE-END
# translation unit, so they answer with the PRIMARY's headers for every base.
# Under an aarch64 selection that calls i386's `x86_order_regs_for_local_alloc'
# and then walks i386's allocation order over aarch64's register classes.
#
# NON-VACUITY: the script refuses to score unless it actually read a
# reg_alloc_order vector of the union width with at least one non-zero entry,
# and unless BOTH bases were observed.  An all-empty read is indistinguishable
# from the thing being proved.
set -u
S=$(cd "$(dirname "$0")" && pwd)
B=${B:-/tmp/b122}
NP="$HOME/src/nixos-configuration/dep/nixpkgs"

cat > "$B/diag.gdb" <<'EOF'
set confirm off
set pagination off
set height 0
break setup_class_hard_regs
run
printf "BASE %s\n", targetm_regs->name
printf "OWN_NREGS %d\n", targetm_regs->first_pseudo_register
printf "OWN_NCLASSES %d\n", targetm_regs->n_reg_classes
printf "ALLOC_ORDER_PTR_NULL %d\n", (targetm_regs->d_reg_alloc_order == 0)
set $i = 0
while $i < 95
  printf "ORDER %d %d\n", $i, this_target_hard_regs->x_reg_alloc_order[$i]
  set $i = $i + 1
end
EOF

export NIX_HARDENING_ENABLE="fortify stackprotector pic strictoverflow relro bindnow"
run_gdb () {
  drv=$1; out=$2
  nix-shell -I "nixpkgs=$NP" -p gcc gnumake gdb \
    --substituters 'https://cache.nixos.org/' --run \
    "cd $B/gcc && gdb -q -batch -x $B/diag.gdb --args ./cc1 -quiet $B/big.c -o /dev/null -ftarget-config=$drv" \
    > "$out" 2>&1
}

CFG=$B/lib/gcc/17.0.0
run_gdb "$CFG/aarch64-unknown-linux-gnu/specs-config" "$B/diag-a64.txt"
run_gdb "$CFG/x86_64-pc-linux-gnu/specs-config"       "$B/diag-x86.txt"

rc=0
for f in "$B/diag-a64.txt" "$B/diag-x86.txt"; do
  base=$(sed -n 's/^BASE //p' "$f" | head -1)
  nregs=$(sed -n 's/^OWN_NREGS //p' "$f" | head -1)
  ncls=$(sed -n 's/^OWN_NCLASSES //p' "$f" | head -1)
  nulp=$(sed -n 's/^ALLOC_ORDER_PTR_NULL //p' "$f" | head -1)
  n=$(grep -c '^ORDER ' "$f")
  nz=$(sed -n 's/^ORDER [0-9]* //p' "$f" | grep -vc '^0$')
  if [ -z "$base" ] || [ "$n" -ne 95 ]; then
    echo "NON-VACUITY FATAL: $f -- base='$base' order entries=$n (expected 95).  Refusing to score."
    rc=9; continue
  fi
  if [ "$nz" -eq 0 ]; then
    echo "NON-VACUITY FATAL: $f -- reg_alloc_order is entirely zero; cannot distinguish a real read from a failed one."
    rc=9; continue
  fi
  # Is the order a permutation of 0..nregs-1, as every consumer assumes?
  perm=$(sed -n 's/^ORDER [0-9]* //p' "$f" | head -"$nregs" | sort -n | uniq | wc -l)
  # Which register numbers never appear in the first nregs entries?
  miss=$(sed -n 's/^ORDER [0-9]* //p' "$f" | head -"$nregs" | sort -n | uniq > "$B/seen.$base"
         seq 0 $((nregs-1)) | sort -n > "$B/want.$base"
         comm -13 "$B/seen.$base" "$B/want.$base" | tr '\n' ' ')
  echo "$base: own nregs=$nregs classes=$ncls alloc_order_ptr_null=$nulp"
  echo "$base: distinct values in first $nregs entries = $perm (a permutation needs $nregs)"
  echo "$base: register numbers ABSENT from its own allocation order: ${miss:-none}"
done
exit $rc
