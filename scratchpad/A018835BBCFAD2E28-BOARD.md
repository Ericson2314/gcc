# riscv64's `scan-assembler` RESIDUAL — THE SHARED `tm.h` IS i386's

**This does not supersede `A01E6C604F26604A7-BOARD.md`.** It reports one
target's item from that board's hand-over list (#1, riscv64's 1,374
`gcc.target/riscv` `scan-assembler` results) and two items it turns out to
contain (#7, and a class the board had not separated out). Every other row on
that board stands unmeasured here.

## 0. PROVENANCE — quote this with any row

```
worktree    .claude/worktrees/agent-a018835bbcfad2e28
            STARTED STALE: the worktree was created from the BARE REPO's HEAD,
            a GCC-12 release branch, 39,734 commits behind multi-target-0 and
            carrying 30 upstream GCC-12 commits of its own.  Reset to
            multi-target-0 before anything was read.  See section 8 --
            the brief's own three-check recipe does not catch this.
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52   (measured, not copied)
srcdirs     /tmp/snap-agent-a018835bbcfad2e28-<sha>, git archive, read-only,
            SNAP-SHA stamped, one per commit measured
builds      /tmp/b-a018835bbcfad2e28-<sha>, 47 bases from backends-47.txt
            all-gcc rc=0 and `error:' 0 on every one quoted below
stock       riscv64 /tmp/b-stock-agent-ab1900d5279ba137f-riscv64  270248/15904
            x86_64  /tmp/b-stock-agent-ab1900d5279ba137f-x86_64
            aarch64 + s390x /tmp/b-stock-agent-a3464debf6893de84-*
mode        MT_COMPILE_ONLY=1, MT_MAKEFLAGS=-j6, all-gcc only
guards      rename sweep (arm 0e + SWEEP PASSES); per target: specs-config
            present, cc1 NAMES THE TARGET BACK, -ftarget-config= non-vacuity,
            mt-specsread 4 arms, GUARD 3c reporting `RISC-V' and
            `Advanced Micro Devices X86-64', and the `.rc' stamp (all rc=0)
load        sampled every 5 min: 18.89 / 25.16 / 23.26 / 12.78 ...
            It touched 25 once.  Rows are labelled where that matters; the
            KILLED evidence below is the reason I do not think it bit.
KILLED      0 on EVERY riscv64 run here -- base, auto-inc, four-fix --
            against the board's 20.  Counted, never subtracted.
```

**BARS, with the commands that produced them**, on the tip (`d5ad77b33b3`):

```
sh scratchpad/mt-bars.sh <builddir>
  x86_64 -O2 big.c   12369 bytes  md5 378fc33c1e70    == the recorded bar
  specs-config  wc -l 232  grep -c . 224, all four md5s the recorded ones:
    x86_64 cfbc7a65e54e  aarch64 575aff0c188b
    riscv64 9af7409ac460  s390x  37901805bf3c
  -O2 -g: rc=0, real .debug sections, md5 PATH-SENSITIVE -- see section 7,
    the instrument for it was returning a false RED.
```

## 1. THE FINDING

The `tm.h` that every target-INDEPENDENT translation unit is compiled against
includes exactly one back end's header chain, and it is i386's:

```
# include "config/i386/i386.h"      # include "config/i386/att.h"
# include "config/i386/x86-64.h"    # include "config/i386/linux64.h"
```

So every target macro spelled in shared code has ONE value for all 47 bases.
`-leakcensus.sh` sizes it from `tm.texi`'s own `@defmac` list -- so the
population is GCC's statement of what a target macro is, not mine:

```
543 documented target macros
 -87  REDIRECT     an #undef/#define pair in multi-target-macros.h
 -94  DESCRIPTOR   named in a target-*.h conversion header
====
296 still read by target-independent code from the primary's chain
      119  LEAK-PRIMARY   i386 defines it; every other base gets x86's answer
      177  DEAD-DEFAULT   i386 does not, so the `#ifndef' fallback is live
                          for the back ends that do
```

**THE FIRST VERSION OF THIS SAID 408, AND IT WAS WRONG.** It subtracted only
`multi-target-macros.h`, on the reasoning that this is "the branch's own record
of which macros it has moved to run time". It is one of several. Both
`REG_ALLOC_ORDER` (38 back ends) and `ADJUST_REG_ALLOC_ORDER` were reported as
LEAK-PRIMARY and both are fully converted, in `target-regs.h` -- a macro
converted through a `target-*.h` descriptor never appears in
`multi-target-macros.h` at all, because its call sites were REWRITTEN rather
than redirected, which is a deliberate choice for exactly the macros whose use
sites are `#ifdef` pairs. **One name, several authorities, no diagnostic** --
this project's own root pattern, found inside the instrument written to audit
it. Caught only because a residual (`pr56096.c`, below) pointed at register
allocation and the census claimed a macro was leaking that demonstrably was
not.

Still an UPPER bound, and DESCRIPTOR is the weaker of the two subtractions
(those headers also discuss macros they have not converted), so it is reported
separately rather than merged.

The non-vacuity arm asserts that four named macros are CLASSIFIED into some
bucket, not that they are leaks. It used to assert they were leaks, which was
true when written and became FATAL the moment they were fixed -- the same
defect-as-pass-condition shape as section 4, in the audit script itself.

**DEAD-DEFAULT is the harder half to find.** Nothing is undefined, nothing
fails to link, no value is out of range. The pass runs, the dump is produced,
and it is simply empty.

## 2. WHAT WAS FIXED, AND WHAT EACH ONE SCORED

Four causes, each built as its own 47-base tree so the movement attributes.

### 2a. auto-inc: `AUTO_INC_DEC` was converted and its eight macros were not

`rtl.h`'s `AUTO_INC_DEC` had already been made per-base. The eight macros it
is the disjunction of had not. So `auto-inc-dec` is switched ON for the 25 back
ends that have auto-increment addressing and then declines every candidate,
because every form it asks for still reads i386's absence.

`target-insn.h` gave a reason for storing only the disjunction -- *"the
question shared code asks is already the disjunction and never the individual
eight"*. Counted: **34 reads outside `config/`**, in `auto-inc-dec.cc` (26),
`expr.cc` (4) and `cse.cc` (4), plus `tree-ssa-loop-ivopts.cc` through
`rtl.h`'s `USE_*` wrappers. `auto-inc-dec.cc:200-299` is that vocabulary and
nothing else.

**The half-conversion has a worse shape than the original bug**: before it, no
auto-inc pass ran and the code was correct and slower; after it the pass runs,
walks every insn and forms nothing — output identical to never having run.

```
xtheadmemidx-modify.c, auto_inc_dec dump PRODUCED on both sides
   stock  2224 lines, 22 auto-inc rtx, 22 th.* insns
   before 1647 lines,  0 auto-inc rtx,  0 th.* insns
   after  2224 lines, 22 auto-inc rtx, 22 th.* insns
```

**And fixing the `HAVE_*` half alone is not safe.** `aarch64.h:1408-1414`
defines all eight `USE_{LOAD,STORE}_*` to a literal `0` — aarch64 has five of
the modes and tells ivopts not to prefer them. Shared code took `rtl.h`'s
fallback, which expands to `HAVE_POST_INCREMENT`, and **while that was stuck at
0 the fallback accidentally produced aarch64's real answer.** Correcting the
`HAVE_*` half turns it into 1 and overrides a back end's explicit `0`.
PRINCIPLES records this trap running the other way; here the leak was right and
the fix is what made it wrong. Caught only because the instrument compared
against STOCK rather than against the previous multi-target output.

**SCORE, by name (`mt-namediff.sh`), base `3b9f7c8f695` -> `784a5b556d9`:**

```
186  FAIL -> PASS,  all in gcc.target/riscv
  0  PASS -> NOT PASS          <- real regressions
  3  results of cardinality noise, so +186 is far outside it
riscv64 debt          2,074 -> 1,888
gcc.target/riscv      1,374 -> 1,188
```

### 2b. alignment: `FUNCTION_BOUNDARY` and `ASM_OUTPUT_ALIGN` — board item 7

**Board item 7 is not riscv64's and it is not a wrong VALUE.**
`align-3.c` asks for `aligned(256)`, LOG 8:

```
stock         .align<TAB>8      riscv.h:1122   "\t.align\t%d", LOG
multi-target  .align<SPACE>256  i386/att.h:60  "\t.align %d",  1 << LOG
```

riscv's `.align N` means 2^N, so 256 is read as a request for 2^256 and the
assembler's arithmetic saturates — that is the `9223372036854841454`. It is
i386's macro character-for-character, down to the space where riscv uses a tab.

Second, independent leak in the same diff: `i386.h:823` is
`FUNCTION_BOUNDARY 8` **bits** against riscv's 32/16, so `varasm.cc:2155`
computes `floor_log2 (1)` = 0 and **every function on every base lost its
alignment directive**.

Measured on all four scored targets (`-alignsweep.sh`), before / after / stock:

```
x86_64   UNMOVED and == stock          <- it was the leak's SOURCE
aarch64  .align 16      -> .align 4    == stock   (2**16 requested, not 16)
riscv64  .align 8       -> .align 1|1|3 == stock
s390x    .align 2|8     -> 8|8|2|8      == stock
```

**SCORE ON riscv64: ZERO.** `mt-namediff.sh` over `784a5b556d9` ->
`bd6f4dbe3ae`: 0 progress, 0 regressions, 321,217 unchanged. Said plainly
because the four-fix run's `-186` is entirely 2a's.

What it did do, none of which this suite scores: `out of memory allocating`
from the assembler **10 -> 0**; aarch64 stopped over-aligning arrays by 4096x;
function alignment restored on three targets; ~30 shared `ASM_OUTPUT_ALIGN`
sites, 17 of them in `dwarf2out.cc`/`dwarf2codeview.cc`, stopped emitting x86
syntax. `align-3.c` still FAILs — now at LINK time on the host `ld`
(`unrecognised emulation mode: elf64lriscv`), **and stock fails identically**,
so it is both-sided and not debt.

**The lesson is about instruments, not alignment.** The board says this
population is "invisible to every instrument in the set". The suite is also an
instrument, and a defect it does not exercise reads as absent. Only the
byte-level both-sided diff saw this one.

### 2c. `PROMOTE_MODE` — a WRONG-CODE leak, and the biggest of the four

```
riscv.h:298   narrower-than-word -> word_mode, and for SImode UNSIGNEDP = 0.
              The "SImode is kept sign-extended in registers" invariant the
              whole back end is written against.
i386.h:1991   HImode/QImode -> SImode under TARGET_PROMOTE_{HI,QI}_REGS.
              Says nothing about SImode.
```

31 back ends define it; read at `explow.cc:937` and `function.cc:980,990,1030`,
all four under `#ifdef PROMOTE_MODE`. Symptom on `zbb-sext.c` — both
differences are DELETIONS:

```
 foo1:
-	sext.b	a0,a0
 	ret
```

The compiler returned a value it had not sign-extended.

Rewritten at the call sites rather than redirected: i386 DEFINES the macro, so
a `#undef`/`#define` would leave the GUARD permanently true while the BODY came
from the selected base, and the 16 bases that define none would silently start
promoting.

**PREDICTED SCORE** (`-predict.sh`, top 40 debt files, codegen identity against
stock — a stronger statement than "the test passes", and one compilation per
file):

```
                   SAME   DIFFER   MTFAIL
four fixes           2      37       1
+ PROMOTE_MODE      16      23       1        <- +186 results in this window
```

Surviving diffs also shrank sharply (`bclr-lowest-set-bit-1` 60 lines -> 6,
`zbb-min-max-04` 62 -> 24). The suite figure is IN FLIGHT; what is measured is
codegen identity.

### 2d. `taa-tools.sh` did not pin the substituter

12 minutes of network dead time between two rows of a cold run, on caches that
are unreachable here, with every path already substitutable from
cache.nixos.org. The same script with the store warm: 6 seconds. INSTRUMENTS.md
already says to pin it. The damage is not the delay — it reads as "cross
binutils are expensive to build", which is what makes the next agent point
`TOOLS=` at another worktree's directory, i.e. GUARD 3c's own failure mode.

## 3. BOTH-SIDED

```
x86_64 suite, auto-inc tree   162171 / 16295   == the board's row EXACTLY
x86_64 -O2 big.c              12369 / 378fc33c1e70  on every tree built
x86_64 -O2 -g big.c           normalised md5 fedffc19e2de, unchanged by all
                              five commits and equal to the board's build dir
x86_64 al.c -O2               UNMOVED, and == stock
```

x86_64 is the right control for all four causes because it is the base whose
answers were leaking: it must not move, and it did not.

## 4. TWO INSTRUMENTS THAT WERE LYING, BOTH FIXED HERE

**`a5764a65f9eec0063-gcheck.sh` could never return IDENTICAL.** Its header says
"the only thing that can differ is the compiler" — but the BUILD DIR is on the
command line as `-ftarget-config=`, the command line lands in `DW_AT_producer`,
and the two build dirs are what it is comparing. It printed *"DIFFERENT — the
change is real"* for two compilers whose entire diff was that one string. **A
false RED costs what a false green costs**; the remedy it invites is reverting a
correct change — here, four of them. Verdict now taken after folding that path,
over sorted lines, with `MT_GCHECK_SELFTEST=1` proving it can still say
DIFFERENT.

**`-align.sh`'s pass condition was the defect.** Written as a reproducer
("mt must be `.align 256`"), it printed two FAILs and rc=1 against the compiler
that had become byte-identical to stock. The arm is now equality, with the two
leak signatures kept as the diagnosis; shown working in both directions on the
same pair of build dirs.

Two bugs in my own `-bothsided.sh`, both of which produced confident wrong
answers: the stock arm dropped the flags (single-target, no `specs-config`, so
it always took the `else` branch and compiled at `-O0` — a control compiled
with different flags from the arms it controls is not a control); and the
artefact name had no triple in it, so four targets wrote one set of `.s` files
and a diff of the survivors came back empty, which reads as "the change did
nothing".

## 5. THE BOARD ROW

```
                      riscv64 debt   gcc.target/riscv
board (e3fac057ae4)       2,074           1,374
base   3b9f7c8f695        2,074           1,374   <- reproduces EXACTLY
auto-inc 784a5b556d9      1,888           1,188   -186, 0 regressions
+align   bd6f4dbe3ae      1,888           1,188   -0
+PROMOTE d5ad77b33b3      in flight; predicted a further ~186 in the top 40
```

The base run reproducing 267630/18329 — the board's riscv64 row to the result
— is the control that says the rest of this column is about the changes.

## 6. WHAT I WOULD HAND THE NEXT AGENT

1. **Score `d5ad77b33b3`'s riscv64 run** and `-predict.sh` the next 40 files.
   `PROMOTE_MODE` is the largest of the four and only its codegen is measured.
2. **`ASM_OUTPUT_MAX_SKIP_ALIGN`** — the third macro of the alignment family,
   still i386's. aarch64 carries a spurious `.p2align 3` stock does not emit,
   because `varasm.cc:2182-2186` emits both levels and i386's second is 3 where
   aarch64's is 0. LEAK-PRIMARY, 6 back ends, 3 files. riscv64 does not define
   it, so this is aarch64's item.
3. **s390x's missing `.machinemode zarch` / `.machine "z900"`** — the whole of
   that target's residual on a four-line file after these fixes. New, unfiled.
4. **The other 405 macros in `-leakcensus.sh`.** Ranked by back-end count and
   by shared readers. `STATIC_CHAIN_REGNUM` (45 back ends), `CUMULATIVE_ARGS`
   (26), `CLASS_MAX_NREGS` (24), `PRINT_OPERAND` (15) are the head of it.
5. **riscv64's `lra_assert (mode != VOIDmode)`** — untouched here, still 432
   ICEs bounding 686 results. Given 2c, ask whether it is also a promotion
   question before assuming it is not.

## 7. WHAT IS NOT IN THIS BOARD

- **aarch64 and s390x have no suite run here.** Their movement is byte-level
  only. 2a CHANGES both (aarch64 gains auto-inc), so "unmoved" is not
  available as a claim for them and I do not make it; what is shown is that
  aarch64's `sum` loop moved TO stock's form and its `copy` loop moved back to
  stock's form once `USE_*` landed.
- Compile-only on both sides; nothing here is an execution result.
- The `-g` md5 is path-sensitive and is never quoted without its build dir.
- `-predict.sh` figures are predictions and labelled so at every use.
- One load sample touched 25.

## 8. THE BRIEF'S OWN TREE CHECK DOES NOT CATCH THE STALE CASE

The recipe is:

```sh
git merge-base --is-ancestor HEAD multi-target-0   # ancestor, not tip => STALE
```

A cleanly stale HEAD **is** an ancestor, so this returns 0 — the same as a
correct tree. It cannot distinguish them. What it does catch is a tree that has
DIVERGED, which is what mine had done (30 GCC-12 commits), and it returned 1.

**The check that actually decides it is the `rev-parse` equality**, and it
should be stated as the primary one rather than as a follow-up. The board-file
`ls` is a good third arm but dates rather than identifies. Thirteen agents now.
