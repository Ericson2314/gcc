# The `FIRST_PSEUDO_REGISTER` classifier queue — and why the obvious sweep is UNSOUND

`HARD_REGISTER_NUM_P` and `cselib.cc` are converted and verified
(`2e5f4730465`). **The remaining ~147 sites must NOT be converted the way I
tried.** This file is the criterion, paid for with a build.

## WHAT I DID, AND WHAT IT COST

Converted the 176 sites where the left operand is `REGNO (...)` — reasoning
that `REGNO` of an rtx is definitionally a specific register being classified,
never a loop bound. 44 files, 262 lines, built clean: **rc=0, 0 `error:`, 0
multiple definition, 0 undefined reference.**

Then the x86_64 codegen bar **segfaulted**:

```
during RTL pass: ira
big.c:24: internal compiler error: Segmentation fault
  crash_signal -> record_operand_costs
```

A/B in the same build dir: cselib-only = `12369 / 378fc33c1e70`; + sweep =
segfault. **Withdrawn.**

## WHY — AND IT IS NOT THE CLASSIFIER/BOUND SPLIT

The split I was given is real but INCOMPLETE:

```
array size / loop bound  -> the union's FIRST_PSEUDO_REGISTER
                            (and MUST stay a constant expression where it
                             sizes an array -- MAX_SETS)
classifier               -> HARD_REGISTER_NUM_P
```

Every one of the 176 was a genuine classifier by that rule, and the sweep was
still wrong, because of a third thing neither category names:

> **A CONSUMER'S CLASSIFIER MAY ONLY BE CONVERTED IF EVERY PRODUCER THAT
> POPULATES THE STRUCTURES ITS PSEUDO-BRANCH TOUCHES USES THE SAME NUMBER.**

Read the producer, don't reason about the predicate. `ira-costs.cc:747`:

```c
enum reg_class pref_class = pref[COST_INDEX (REGNO (op))];
#define COST_INDEX(regno) (allocno_p \
        ? ALLOCNO_NUM (ira_curr_regno_allocno_map[regno]) : (int) regno)
```

and the producers, `ira-build.cc:2065`, `:2523`, `:2791`, `:3187`:

```c
for (i = max_reg_num () - 1; i >= FIRST_PSEUDO_REGISTER; i--)   /* the UNION's 95 */
```

**Allocnos are created only for regnos >= 95.** Converting the consumer made
x86_64 regnos 92-94 take the pseudo branch, where
`ira_curr_regno_allocno_map[92]` is NULL and `ALLOCNO_NUM (NULL)` dereferences
it. The classifier became *correct* and the data it indexed did not exist yet.

`cselib.cc` was safe from this for a reason worth stating: it consults no
producer-populated per-pseudo structure — it walks `REG_VALUES`, which is
union-sized and populated on demand.

## THE TEST TO APPLY, PER SITE

For each candidate, follow the branch the classifier guards:

1. **Does the pseudo branch index a structure keyed by regno?** If no, the
   conversion is local and safe (the `cselib.cc` case).
2. **If yes, who fills that structure, and with which number?** Grep the
   producer for `FIRST_PSEUDO_REGISTER`. If the producer still walks from the
   union's value, converting the consumer alone creates a NULL or a negative
   index. Convert both, or neither.
3. **Watch for the paired OFFSET**, which is the same defect with a louder
   name — `calls.cc:1990` says it in its own comment:
   *"Vector indexed by REGNO - FIRST_PSEUDO_REGISTER"*, used at `calls.cc:2021`
   and `:2079`, and at `lra-lives.cc:887`, `:912`, `lra-constraints.cc:7336`,
   `:7683`, `:7865`, `alias.cc:3374`, `:3376`. **A classifier and its index
   base must be the same number.** `92 - 95` on an unsigned is not a small
   negative, it is ~4 billion.

## THE RESIDUAL, WITH ITS SHAPE

~147 hand-spelled comparisons remain where the operand is a bare variable
(`regno`, `i`, `dreg`) rather than `REGNO (...)` — plus the 176 above, which
are now known to need step 2 rather than a blanket conversion.

```
reload.cc 46   lra-constraints.cc 32   reload1.cc 27   combine.cc 27
cse.cc 17      expr.cc 15              lra-remat.cc 13 ira-costs.cc 13
ira-lives.cc 10  sched-deps.cc 9       caller-save.cc 8  alias.cc 8
```

**IRA/LRA are the dangerous cluster** — they are exactly the files that build
per-pseudo side tables, so they are where step 2 fails most often. The
middle-end files that only ask "is this a hard register?" before consulting
`targetm` or a union-sized table are the safe ones, and they are the ones
already converted in `alias.cc`, `expr.cc`, `ira.cc`, `function-abi.cc`,
`reginfo.cc`.

**Suggested order:** do the producers first, not the consumers. Converting
`ira-build.cc`'s four allocno-creation loops to `MT_FIRST_PSEUDO_REGISTER`
makes allocnos exist for 92-94 and would let the ira-costs consumers follow.
That is a real change to how many allocnos IRA creates and needs its own
measurement — which is precisely why it is a task and not a sed.

## WHAT VERIFIED, SO THE NEXT AGENT KNOWS THE FLOOR

`2e5f4730465` (merged) — `HARD_REGISTER_NUM_P` + 8 `cselib.cc` sites:

```
make all-gcc            rc=0, error: 0, multiple definition 0
x86_64 -O2 big.c        12369 / 378fc33c1e70          (== recorded)
x86_64 -O2 -g big.c     rc=0, 78536 bytes, debug sections present
                          (UNFIXED: ICE, 93-byte truncated .s)
aarch64/riscv64/s390x   byte-identical unfixed vs fixed
specs-config x4         md5s unchanged
replay of 200 real ICEing commands   194 cselib ICEs -> 0
named reproducer        rc=1/no object -> rc=0 / 3760-byte object
```

Residual after that fix, from the same 200-command replay: **7 hit
`in_hard_reg_set_p, at regs.h:312`** from `recog.cc:1598`, which is the same
question spelled by hand. That site is in the 176 and is subject to step 2
above — it was NOT independently verified and must not be assumed safe.
