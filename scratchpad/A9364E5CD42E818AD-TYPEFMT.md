# `.type`, `.bss` and the prediction that was wrong

Continues `A660907426E03E4E9-ARM-BOARD.md`.  Three findings were handed to me;
**one was right, one had the right observation and the wrong cause, and one was
a prediction that turned out to be false — and the false one is where the
larger defect was.**

## 0. PROVENANCE

```
worktree    agent-a9364e5cd42e818ad
            RESET at the start: created at the bare-repo HEAD 7208eca60d0,
            DIVERGENT (`--is-ancestor` returned 1, rev-parse unequal),
            `grep -c MULTI_TARGET gcc/Makefile.in` = 0, scratchpad/ absent.
            The 22nd agent to start on the wrong tree.
            Re-cut with `git checkout -b mt0-a9364e5cd42e818ad multi-target-0`;
            all three arms then green (rev-parse equal, anchor 55, board present).

BEFORE      /tmp/snap-agent-a9364e5cd42e818ad-bd164c70441  (= multi-target-0)
            build /tmp/b-a9364e5cd42e818ad-base, 47 bases, all-gcc rc=0
AFTER       /tmp/snap-agent-a9364e5cd42e818ad-7eeb91b8187
            build /tmp/b-a9364e5cd42e818ad-fix2,  47 bases, all-gcc rc=0
            `error:` 0, multiple definition 0, undefined reference 0, Killed 0,
            cc1 links (231,333,056 bytes)
anchor      55 on both, MEASURED
MTGAP       2 on both (`mt_base`, `mt_dwarf2_unwind_info_hook` — the two known
            false positives).  Nothing was dropped.

TOOLS       /tmp/tools-agent-a9364e5cd42e818ad — aarch64, riscv64, s390x, arm
            binutils 2.46, each EXECUTED and each asked to produce an object
            whose `Machine:` was read back (AArch64 / RISC-V / IBM S/390 / ARM).
            x86_64 is the host's own target and uses the dev shell's `as`,
            spelled out for that target ALONE.

BARS        x86_64 -O2 big.c   12369 bytes / md5 378fc33c1e70   UNMOVED
            specs-config       232 lines / 224 non-blank on ALL FIVE targets,
                               five DISTINCT md5s — x86_64 cfbc7a65e54e,
                               aarch64 575aff0c188b, riscv64 9af7409ac460,
                               s390x 37901805bf3c, arm 0a72c562746f.
                               All five identical to the values the arm board
                               records.  (The md5 is a function of the probing
                               toolchain's paths and is NOT a bar; the line
                               count is.)
```

## 1. THE RESULT

```
                       PASS     FAIL   XPASS   XFAIL   UNSUP   UNRES
stock  (control)     148432    15997       8    1307   10573   12831
mt     BEFORE        130868    18381       4    1199    8265   12688
mt     AFTER         147674    16191       8    1306   10787   13010

DEBT  (stock PASS -> mt NOT PASS, per-name multiset join)   3288 -> 191
SCOPE (results only the stock run produced)               21181 -> 874
      results in mt                                    171445 -> 189016
```

Both instruments were pointed at the OLD sums first and reproduced the board's
own **3288** and **21181** before being pointed at the new ones, so a changed
figure is a changed measurement rather than a changed measurer.  The stock
control's seven totals were re-derived from the preserved `.sum` and match the
board exactly.

## 2. FINDING 1 — `TYPE_OPERAND_FMT`. RIGHT, AND THE aarch64 ARM IS CONFIRMED

Measured before any change, with each target's own binutils 2.46:

```
TARGET                        .type emitted      its own `as`
aarch64-unknown-linux-gnu     gvar, @object      ASSEMBLES
riscv64-unknown-linux-gnu     gvar, @object      ASSEMBLES
s390x-ibm-linux-gnu           gvar, @object      ASSEMBLES
x86_64-pc-linux-gnu           gvar, @object      ASSEMBLES
arm-unknown-linux-gnueabihf   gvar, @object      Error: unrecognized symbol type ""
```

and after:

```
-- 2 changed, 3 byte-identical, 0 compile-failed, 0 skipped
aarch64  @object -> %object   ASSEMBLES both before and after
arm      @object -> %object   REJECTS before, ASSEMBLES after
riscv64 / s390x / x86_64      byte-identical
```

**aarch64 is the finding, and it is confirmed.**  It asks for `%object`, it is
a target this branch has scored from the beginning, and it has been emitting
`@object` on every board ever taken here without producing a single failure,
because its assembler accepts the wrong answer.  The defect was not invisible
because the scored targets agreed — **one of them dissented and was
mis-served anyway.**  It was invisible because no tooling complained.

### 2a. The counting trap, and what the definer-count missed

The board's `-dissent.sh` lists the definers as `aarch64 arc arm elfos
microblaze openbsd sparc`.  That is a count of files, and PRINCIPLES records
three occasions where counting the back ends that *spell* a macro undercounts
it.  `-typefmt.sh` instead preprocesses each base's own `tm-<base>.h` and
EXPANDS the macro.  Over all 47 configured bases:

| `TYPE_OPERAND_FMT` | bases |
|---|---|
| `"@%s"` | 41 |
| `"%%%s"` | 2 — aarch64, arm |
| `"#%s"` | **1 — sparc** |
| absent | **3 — mmix, nvptx, pdp11** |

Two things a definer-count cannot give.  **sparc is a third dissenter**, and it
was on nobody's list.  And **three bases have no `ASM_OUTPUT_TYPE_DIRECTIVE` at
all** — so shared code was not giving them a wrong operand, it was **emitting a
directive they do not have**.  That is why `mt_output_type_directive` returns
`bool`: `varasm.cc:6647`'s `#else` is an `error_at ("ifunc is not supported")`,
so "nothing was emitted" has to stay observable at the call site.

## 3. FINDING 2 — `ASM_OUTPUT_ALIGN`. THE OBSERVATION IS RIGHT AND THE CAUSE IS NOT

**The brief and the board both attribute the arm `.align 4` to
`ASM_OUTPUT_ALIGN` not being converted.  It was already converted** — in
`7247d7aea83`, which is an ancestor of `b351eb857d1`, the commit that board was
measured on.  Measured on the BEFORE compiler, arm's `.data` path already
emitted `.align 2` correctly, and so did aarch64 and riscv; s390x and x86_64
emitted `.align 4` because they print bytes, which is right for them.

The `.align 4` is nevertheless real, and it is on the `.bss` path — see 4.  A
**converted macro can still be leaked by an unconverted CALLER**, which is a
fifth shape beside INSTRUMENTS.md's four.

### 3a. What its correct value is per back end — it is not two classes

The brief asks for this explicitly rather than assuming a binary split, and it
is right to.  Over the 47 bases, `ASM_OUTPUT_ALIGN` has **seven distinct
shapes**:

| shape | bases |
|---|---|
| `.align LOG` (the power) | 18 — incl. aarch64, arm, riscv, mips, rs6000, sh |
| `.align 1 << LOG` (bytes) | 13 — incl. i386, s390, sparc, pa, ia64, xtensa, m68k |
| `.balign 1 << LOG` | 5 — epiphany, iq2000, m32r, msp430, rl78 |
| `.p2align LOG` | 6 — avr, fr30, frv, ft32, moxie, xstormy16 |
| `.even`, no operand | 1 — pdp11 |
| a no-op | 1 — nvptx |
| a function call | 1 — `mmix_asm_output_align` |
| option-dependent (`.ALIGN` vs `.align`) | rx, on `target_flags` |

So the earlier `.align 256` finding and this one are the same family and the
space is emphatically not binary.

## 4. FINDING 3 — THE PREDICTION IS FALSE, AND THAT IS WHERE THE BIGGER LEAK WAS

The board offers, carefully, as a prediction and not a conclusion: fixing
`TYPE_OPERAND_FMT` may restore `ilp32`.  **It does not.**

```
PROBE       COMPILER  -S    -c    verdict
ilp32       BEFORE    ok    FAIL  FALSE
ilp32       .type-fix ok    FAIL  FALSE     <- the prediction, refuted
lp64 (neg)  both      FAIL  FAIL  FALSE     <- control, fires on both
```

`check_effective_target_ilp32`'s body is `int dummy[...]` with **no
initializer**, so it goes to `.bss` and never touches the site that had been
fixed.  Following the refutation:

```
	.bss
	.align 4               <- i386's `1 << LOG` BYTES; arm asks for `.align 2`
	.type	dummy, @object <- still the primary's `@`
	.zero	4              <- i386's; arm says `.space`
```

`varasm.cc:2447`'s `emit_bss` is shared, its `#if defined` is the primary's,
and i386's `ASM_OUTPUT_ALIGNED_BSS` is **`x86_output_aligned_bss`, a function
in `i386.cc`**:

```
i386.cc:973   if ((ix86_cmodel == CM_MEDIUM || ... || CM_LARGE_PIC)
		  && size > (unsigned int) ix86_section_threshold)
		switch_to_section (get_named_section (decl, ".lbss", 0));
```

**Every uninitialized global on every one of the 47 back ends was emitted by
i386's back end**, with `.bss` vs `.lbss` placement decided by i386's code
model and `-mlarge-data-threshold`.  Not a directive-spelling bug.

All four `SECTION_NOSWITCH` callbacks are the same leak and were converted
together — `emit_local`, `emit_bss`, `emit_common`, `emit_tls_common` — because
meeting this one wall at a time is what left riscv with `.option push` and no
`.option pop`.  `ASM_OUTPUT_SKIP` went with them; **ARM's gas accepts `.zero`
as well as `.space`, so no board would ever have reported that one.**

After:

```
ilp32       AFTER     ok    ok    TRUE
int32plus   AFTER     ok    ok    TRUE
lp64 (neg)  AFTER     FAIL  FAIL  FALSE
```

**The lesson is the method, not the macro.** The prediction was cheap to test
and testing it is what found the second leak.  Had it been assumed, this task
would have closed with the `.bss` leak intact and the whole debt attributed to
`.type`.

## 5. TWO UPSTREAM DEFECTS THE CONVERSION SURFACED

Both are cases of **code that compiles for the first time**.  Upstream compiles
`varasm.cc` once with the primary's macros, so the arms i386 does not take have
never been type-checked against any back end.

1. **`bfin`'s `ASM_OUTPUT_LOCAL` references `ASM_SPACE`, which is defined
   nowhere in the GCC tree.**  `bfin.h:1054`; `bfin.h:1064`'s
   `ASM_OUTPUT_COMMON` calls the same macro, so it is broken too.
   `grep -rn 'define ASM_SPACE' gcc/config/` returns nothing.  **Worth
   reporting upstream.**
2. **31 of the 47 bases take the `ASM_OUTPUT_ALIGNED_LOCAL` arm and several,
   `aarch64` included, define no `ASM_OUTPUT_LOCAL` fallback at all.**  Not a
   bug upstream, but it means that arm's `#else` has never been compiled.

Both are handled by a reachability guard rather than a workaround:
`defaults.h` gains `ASM_OUTPUT_ALIGNED_LOCAL_P_IS_CONSTANT_TRUE`, set exactly
when it also supplied the `true` default.  On PRINCIPLES 2a's own test — "would
a second configured back end change it?" — it is a **supply-side** marker and
not a floor: it is set precisely when this base's own headers were silent, and
no base can read another's.

## 6. WHAT REMAINS, AND WHAT IT IS NOT

191 debt names.  Top directories: `gcc.target/arm` 102, `gcc.dg/lto` 53,
`gcc.dg/torture` 8, `c-c++-common/torture` 8, `gcc.dg/tree-ssa` 6.  The list is
`A9364E5CD42E818AD-ARM-DEBT-AFTER.txt`.

**10 of the 191 were not in the old debt set, and none of them is a
regression.**  Every one belongs to a test that was `UNSUPPORTED` before — the
selector was answered by the assembler, and the assembler refused everything —
so the test produced one line and no per-assertion names.  It now runs:

```
gcc.target/arm/bfloat16_simd_1_1.c   BEFORE  UNSUPPORTED
                                     AFTER   PASS stacktest1, PASS stacktest2,
                                             FAIL stacktest3
```

A test moving from "never attempted" to "attempted, mostly passing" adds FAIL
rows, and **against the debt column alone that is indistinguishable from a
regression.**  `-scope.sh` exists so that the two are always reported together;
the scope column falling 21,181 -> 874 in the same run is what settles it.

## 7. WHAT WOULD BE WORTH DOING NEXT

1. **The remaining 102 `gcc.target/arm` names.** Not attributed.  This is now
   the largest single block and it is arm-specific, so it is the row's own
   residual rather than a shared leak.
2. **Re-score aarch64, riscv64, s390x and x86_64.**  aarch64's `.type` changed
   in this commit and its board has never been taken with the correct operand;
   the other three are byte-identical here but the `.bss` conversion touched
   code every target runs, and "byte-identical on one four-line input" is not a
   board.
3. **`sparc` has never been scored and it is the third `TYPE_OPERAND_FMT`
   dissenter** (`#object`).  Under PRINCIPLES' corollary — an unscored target
   can refute assumptions where a scored one can only refine a number — it is
   worth more than another pass over arm.
4. **Report `bfin`'s `ASM_SPACE` upstream**, with the
   `upstream-libcall-decl-regression` note as precedent.
