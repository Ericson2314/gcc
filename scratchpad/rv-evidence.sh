#!/bin/sh
# NON-VACUITY.  The x86_64 arm being byte-identical is only good news if the
# binary actually changed; an arm that passes because nothing was built proves
# nothing.  This shows the mechanism is present AND that the selection happens,
# which are two separate claims -- the `targetm_asm_ops' bug was a table that
# existed, was correct, and was never pointed at.
set -u
NP="$HOME/src/nixos-configuration/dep/nixpkgs"
D=${D:-/tmp/b-rv59}
nix-shell -I "nixpkgs=$NP" -p binutils --substituters 'https://cache.nixos.org/' --run "
  cd $D/gcc
  echo '--- ARM A: the per-base TABLES exist, one per configured back end'
  nm -S target-regs-i386.o target-regs-aarch64.o 2>&1 | grep -i 'targetm_regs_'
  echo
  echo '--- ARM B: the SELECTION happens.  multi-target-select.o must carry an'
  echo '    UNDEFINED reference to target_regs_for.  A call that was deleted or'
  echo '    constant-folded leaves no relocation and this goes empty.'
  nm -u multi-target-select.o | grep -c target_regs_for
  echo '    positive control (a function it demonstrably calls):'
  nm -u multi-target-select.o | grep -c internal_error
  echo '    negative control (a real function it does NOT call):'
  nm -u multi-target-select.o | grep -c 'expand_expr' || true
  echo
  echo '--- ARM C: reginfo.o READS the selected table rather than the macros.'
  echo '    It must reference targetm_regs and must NOT define the six old'
  echo '    file-static arrays.'
  nm -u reginfo.o | grep -c targetm_regs
  echo '    old statics still present (must be 0):'
  nm reginfo.o | grep -c 'int_reg_class_contents\|initial_fixed_regs\|initial_reg_names' || true
  echo
  echo '--- ARM D: the two tables really differ (a table that is a copy of the'
  echo '    primary would pass every arm above and mean nothing).'
  cmp -s target-regs-i386.o target-regs-aarch64.o && echo '    IDENTICAL -- BAD' || echo '    differ -- ok'
"
