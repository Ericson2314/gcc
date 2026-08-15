# #203: the SVE/SME ACLE cluster is `enum constraint_num` — the PRIMARY'S, in every shared TU

**~102,000 aarch64 FAILs where stock fails zero, and the cause is that
`lra-constraints.o` and `recog.o` evaluate aarch64's constraints against
i386's constraint table.** This is the branch's signature bug — one name,
several authorities, no diagnostic — in the constraint vocabulary.

## The measurement

```
tm-preds-i386.h      94 constraints
tm-preds-aarch64.h  143
tm-preds-riscv.h     83
tm-preds-s390.h      93
tm-preds.h  (SHARED) 94        <- exactly i386's count, and i386's contents

aarch64 constraints ABSENT from the shared table:  113 of 143
```

The shared table is not a union and not a subset chosen for neutrality: it is
**i386's, entire**. And the consumers are the ones that matter —
`.deps/lra-constraints.Po` and `.deps/recog.Po` name `tm-preds.h` and no
per-base variant.

## How it presents, both-sided

Same test, same insn, same alternative, stock cross vs multi-target
(`gcc.target/aarch64/sme2/acle-asm/add_s16_x2.c`, `-Os -g -march=armv8-a+sme2`):

```
              Considering alt=0 of insn 18:  (0) =Uw2  (1) 0  (2) x

STOCK         overall=0,  losers=0, rld_nregs=0
              Assign 60 to reload r104              -> compiles, 0 FAIL

MULTI-TARGET  0 Operand reload: losers++
              0 Non-pseudo reload: reject+=2
              1 Operand reload: losers++
              overall=17, losers=2, rld_nregs=4
              Creating newreg=137, assigning class FP_REGS
              -> "unable to find a register to spill"
                 ICE in lra_split_hard_reg_for, at lra-assigns.cc:1907
```

`Uw2` is `(define_register_constraint "Uw2" "FP_REGS" ... "regno % 2 == 0")` —
FP_REGS plus an *even-register* filter, which is how an SVE 2-tuple gets an
aligned pair. Shared code cannot resolve the name at all, so the operand is
treated as needing a reload into plain `FP_REGS`; no plain FP register
satisfies a 2-tuple's alignment, the reload is unsatisfiable, and LRA fails.

`tm-preds-aarch64.h` has `CONSTRAINT_Uw2` and its `get_register_filter`;
`grep -c Uw2 tm-preds.h` is **0**.

## WHAT THIS IS NOT — two hypotheses tested and refuted

Both were plausible, both were mine or the coordinator's, and neither survives:

- **NOT the register-count band.** `reginfo.cc:304`'s tail fence already marks
  every regno from a base's own count to the union's as `fixed_regs[i]=1`,
  `call_used_regs[i]=0`, with its own name, and `reg_class_contents` is filled
  only below that count. Phantom registers are fixed, unallocatable, classless.
- **NOT register-class numbering.** This was my own next hypothesis and the
  IRA dumps refute it directly: stock and multi-target produce **identical**
  cost lines, same class names, same costs —

  ```
  r102/r135 costs: FP_LO8_REGS:2000 FP_LO_REGS:2000 FP_REGS:2000
                   POINTER_AND_FP_REGS:20000 ALL_REGS:20000 MEM:5000
  ```

  Classes are fine. The divergence appears later, in constraint matching, and
  the IRA dump was the check that could distinguish them.

## WHY IT IS A DESIGN ITEM, NOT A FIX

`enum constraint_num` has the same shape as the mode vocabulary, and the same
two halves:

- **The NAMES must be unioned**, or shared code cannot look up a constraint
  another base defines. 113 aarch64 names are simply absent.
- **The DATA must stay per base.** `Uw2` means *even FP register* on aarch64
  and nothing on i386; a table that let one base's `Uw2` answer for another's
  would be the `HAVE_V8HFmode` leak in a new place. Constraint *satisfaction*
  is per base by construction — it calls that base's filter and predicates.

So this is the union-the-vocabulary/keep-the-data-per-configuration pattern
this branch has landed eight times, applied to constraints. It is **not** a
sed and it is not a bound/predicate split.

**The producer/consumer rule (#201) governs the fix.** `genpreds` produces the
per-base tables; `lra-constraints.cc` and `recog.cc` consume `constraint_num`
ordinals. Widening the consumer's enum without regenerating every producer in
the same numbering reproduces the withdrawn sweep exactly: it will build clean
and then mis-resolve constraints, which is *quieter* than a segfault.

## SIZING

```
gcc.target/aarch64/sve/acle     mt 59896/35027   stock 79980/0
gcc.target/aarch64/sve2/acle    mt 35177/34268   stock 59021/0
gcc.target/aarch64/sme/acle-asm mt  1996/ 3186   stock  4070/0
gcc.target/aarch64/sme2/acle-asm mt 2516/30146   stock 37594/0
```

~102,000 FAILs, stock zero. riscv (83) and s390 (93) also differ from the
shared 94, so this is not aarch64-only — it is every non-primary base, and
aarch64 is merely where the ACLE suites make it loud.

## Reproducer

```sh
xgcc -B<build>/gcc/ -ftarget-config=<aarch64 cfg> -std=c11 -Os -g -DTEST_FULL \
  -march=armv8-a+sme2 -mtune=generic -fno-ipa-icf \
  -I<src>/gcc/testsuite/gcc.target/aarch64/sme2/acle-asm \
  <src>/gcc/testsuite/gcc.target/aarch64/sme2/acle-asm/add_s16_x2.c -S
```

Add `-fdump-rtl-reload-details` and read the `Considering alt=0 of insn 18`
block; compare with the stock cross, which is intact at
`/tmp/b-stock-agent-a3464debf6893de84-aarch64`.

**Nothing was changed for this investigation.**
