# #200 — the LRA cluster: hypothesis REFUTED, target narrowed, root cause open

## 1. IT IS ONE EVENT, NOT TWO — read from the source, not inferred

`lra-assigns.cc:1907` is the `fatal_insn` immediately following the `error`:

```c
error ("unable to find a register to spill");
fatal_insn ("this is the insn:", insn);      /* <- :1907 */
```

So the board's **23,154 `lra_split_hard_reg_for`** and **7,718 `unable to find
a register to spill`** are the *same* failures counted twice, not two causes.
The remaining two members of the cluster (`could not split insn` 2,556,
`maximum number of LRA assignment passes is achieved (30)` 1,884) are
plausibly downstream of the same shortage but that is **not** established here.

## 2. THE UNION-128 HYPOTHESIS IS REFUTED — the fence already handles it

The hypothesis was: LRA fails because its notion of the register file is the
union's 128 while aarch64's own is 95, so regnos 95..127 are phantom
allocatable registers. **That is not what happens.** `reginfo.cc:304` already
carries a tail fence, and its comment states the exact reasoning:

```c
/* THE TAIL FENCE, AND IT IS NOT TIDINESS. ... */
for (i = nregs; i < FIRST_PSEUDO_REGISTER; i++)
  {
    fixed_regs[i] = 1;
    call_used_regs[i] = 0;
    reg_names[i] = mt_absent_reg_name;
  }
```

and `reg_class_contents` is populated only for `j < nregs`, so the phantom
registers are in no class either. **They are fixed, unallocatable, and
individually named.** A walk to 128 therefore does not offer LRA registers
that do not exist.

**This is a refutation, and it is a result** — the cheap hypothesis was worth
testing and it is wrong. Do not spend another session on it. (17 shared loops
still walk `0 .. FIRST_PSEUDO_REGISTER` in `lra*.cc`/`ira*.cc`; 5 are in LRA.
They are wasteful but not, on this evidence, the cause.)

## 3. IT IS 100% MULTI-TARGET DEBT, AND IT IS THE SVE/SME ACLE FAMILY

The control settles it — same tests, stock aarch64 cross vs multi-target:

```
directory                    mt PASS   mt FAIL  |  stock PASS  stock FAIL
gcc.target/aarch64/sve/acle    59896     35027  |      79980           0
gcc.target/aarch64/sve2/acle   35177     34268  |      59021           0
gcc.target/aarch64/sme/acle-asm 1996      3186  |       4070           0
gcc.target/aarch64/sme2/acle-asm 2516     30146 |      37594           0
```

**Stock fails ZERO in all four**, and emits `unable to find a register to
spill` **0 times** in the entire run. ~102,000 FAILs here are this project's,
and they are the bulk of the remaining 93,526 aarch64 debt.

## 4. NARROWED: not tuples as such — the multi-vector "single" forms

A plain tuple move compiles **clean**:

```c
#include <arm_sve.h>
svint16x2_t f (svint16x2_t a) { return a; }     /* 0 errors, -march=armv9-a+sve */
```

The failure is on the multi-vector *single* forms. The reported insn:

```
(set (reg/v:VNx16HI 137 [ z24 ])
     (plus:VNx16HI (reg/v:VNx16HI 137 [ z24 ])
        (vec_duplicate:VNx16HI (reg:VNx8HI 134 [ z0.0_1 ]))))
     13169 {aarch64_sve_single_addvnx16hi}
```

i.e. an insn whose operands carry register-CLASS constraints (the `single`
forms restrict one operand to a low-numbered Z register subset).

## 5. THE NEXT HYPOTHESIS, AND WHY IT IS THE RIGHT ONE TO TEST NEXT

**Register CLASS numbering, not register numbering.**
`MULTI_TARGET_UNION_N_REG_CLASSES` is **34**. PRINCIPLES section 3 already
lists `N_REG_CLASSES 34 vs 20` as a recorded instance of this branch's root
bug — *one name, several authorities* — in the class vocabulary specifically.
An insn constraint naming class *N* while the class tables are indexed by a
different *N* yields an empty or wrong class, and "no register to spill" is
exactly what LRA says when the required class is empty.

**Test it before converting anything**: read, in the running compiler, the
class that `aarch64_sve_single_addvnx16hi`'s constrained operand resolves to,
and compare its `reg_class_contents` against aarch64's own tables. Both-sided:
do the same for an i386 insn with a restricted class.

## 6. THE #201 PRODUCER/CONSUMER TRAP APPLIES HERE AND IS THE REASON THIS FILE STOPS SHORT

Whatever the cause, **do not convert an LRA consumer ahead of its producer.**
That is precisely the sweep that built clean and then segfaulted in
`record_operand_costs`, because `ira-build.cc` creates allocnos only for
regnos >= the bound *it* uses. LRA has the same structure: `lra_reg_info` is
sized by `max_reg_num () * 3 / 2 + 1` (`lra.cc:1381`) and filled by
`init_reg_info`, so any consumer reclassification has to be checked against
that producer first.

**Nothing in `lra*.cc` was changed by this investigation.**
