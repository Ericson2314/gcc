
---

# #137 -- RANKING THE 75, AND THE ONE THAT WAS ALREADY CONVERTED

Brief: rank the 75 `UNCONVERTED` macros by what actually leaks, report the
ranking even for the ones not converted, then convert a batch from the top.

The ranking was produced. **The top of it was not a conversion target: it was a
macro that had already been converted, was scored `UNCONVERTED` by the board,
and whose header arm was being banked as one of the board's only TWO TRUSTED
aarch64 passes.** That is what got fixed, plus a second finding of the same
family and two instrument defects.

## 1. THE RANKING -- `scratchpad/t137-rank.sh`, output `t137-ranking.txt`

Criterion, stated because a rank is worthless without one: **rank by what
leaks, in five separately-printed signals, never summed.** A single score would
let a reader quote a rank as a severity, and three of the signals mean
different KINDS of failure.

    USE   sites in SHARED code (gcc/, minus config/ testsuite/ ada-interface)
    FILE  distinct shared files
    PPA   sites on a `#if'/`#elif' ARITHMETIC line   -- cannot become runtime
    PPD   sites on a `defined'/`#ifdef' line         -- the ABSENCE channel
    BND   sites where the name appears inside `[...]' -- it SIZES something
    DEF   which configured base defines it: BOTH / i386-only / aarch64-only

The top of the board, by USE:

    UNITS_PER_WORD                  267 uses  50 files              BOTH
    POINTER_SIZE                     74       35      1 PPD 1 BND   BOTH
    BIGGEST_ALIGNMENT                68       19                    BOTH
    TARGET_HAS_FMV_TARGET_ATTRIBUTE  47       15      1 PPD    aarch64-only
    ASM_OUTPUT_ALIGN                 31        7                    BOTH
    MAX_BITSIZE_MODE_ANY_MODE        25        7      1 PPD 10 BND  <- see 2
    MAX_BITS_PER_WORD                23        5      1 PPD 11 BND  BOTH
    CLZ_DEFINED_VALUE_AT_ZERO        23       12                    BOTH
    REG_ALLOC_ORDER                  22        7      2 PPD         BOTH
    MAX_MOVE_MAX                     22        6      1 PPD  3 BND  i386-only
    BRANCH_COST                      22       10                    BOTH
    PIC_OFFSET_TABLE_REGNUM          20       12      1 PPD 1 BND   i386-only

**`PPA` is zero for all 75, and that is a real reading rather than a dead
column.** The `#if NUM_UNSPEC_VALUES > 0` sites `MACRO-LEAK.md` class (d)
enumerates have since been rewritten to `#if defined(...)` form in this tree
(`print-rtl.cc:506,516,1631,1638`). The arithmetic-`#if` blocker that decided
several earlier fixes is, for this population, gone.

**TWO COLUMNS WERE WRONG ON THE FIRST RUN AND ONE OF THEM WAS WRONG IN THE
DANGEROUS DIRECTION.** `DEF` was written with `[ \t]` inside an ERE bracket,
where `\t` is the two characters backslash and t and **not a tab**. Every back
end writes `#define M<TAB>value`, so **every macro scored `neither`** -- an
absence, which is precisely the reading that column exists to detect, produced
by the instrument instead of by the code. `UNITS_PER_WORD` reading "defined by
neither base" is what made it visible; a less obvious macro would have been
believed. The column now has a positive control (`UNITS_PER_WORD` must read
BOTH) and a negative one (a nonexistent name must read `neither`), both of
which fire.

**Stated blind spots.** It is a textual scan: a macro reached only through
another macro's body scores 0 USE and still leaks (`N_REG_CLASSES` expands
through a back-end enum -- `MACRO-LEAK.md`'s identical-text blind spot). `DEF`
reads back ends' `*.h` only, so a definition from a GENERATED header is
invisible -- which is exactly why `MAX_BITSIZE_MODE_ANY_MODE` and
`MAX_BITS_PER_WORD` read `aarch64-only`/`BOTH` rather than the truth. And it
says nothing about VALUE.

## 2. THE FINDING: A CONVERTED MACRO SCORED `UNCONVERTED`, WITH ITS
   WRONG-REASON GREEN BANKED AS TRUSTED

`MAX_BITSIZE_MODE_ANY_MODE` is **already converted**, by the genmodes UNION,
and has been for as long as the union run has been wired up. Measured, not
inferred, from the per-base generators in my own build dir:

    build/genmodes-i386     -h  ->  MAX_BITSIZE_MODE_ANY_MODE 1024
    build/genmodes-aarch64  -h  ->  MAX_BITSIZE_MODE_ANY_MODE 8192
    build/genmodes -U modes-union.list -A <base> -h  ->  8192   (the maximum)

and `/tmp/b137/gcc/insn-modes.h` carries 8192. That is the correct fix and the
only possible one: the macro sizes stack buffers in `fold-const.cc`,
`simplify-rtx.cc`, `expr.cc` and `gimple-fold.cc`, and each buffer's bounds
check is written in terms of **the same constant**, so the value must be
compile-time and identical in every TU (`genmodes.cc:1402-1434` argues this at
length).

**Why the board could not see it.** `macro-probe.sh` derives the converted set
from `defaults.h`'s redirect block plus a hand-declared no-redirect list. A
union macro appears in **neither**: there is no `#undef` (nothing is
redirected) and no `mt_` thunk (it must not become a runtime read). So it sat
saying `UNCONVERTED`.

**And the header arm made it worse rather than merely missing it.** With the
union in force both base contexts read 8192, so the arm scored PASS -- saying
only "this name is now target-neutral", wrong-reason shape 2 -- and that PASS
was **one of only two counted as TRUSTED on the whole board**. This is the
branch's root pattern (one name, several authorities, no diagnostic) aimed at
the instrument for the second time, and in the OPPOSITE direction to the first:
the earlier defect made a converted macro invisible; this one made it read as
unconverted *and* banked its green.

### The sixth probe shape -- `scratchpad/union-probe.sh`

No existing shape can score a union macro, and that is structural rather than
an oversight. All four ask "do the bases differ, and does the selected base get
its own answer?"; for a union macro the number is *deliberately* the same in
both bases -- that is the fix, not a symptom. A TAB arm reading the running
`cc1` would report the same 8192 twice and be green for the same wrong reason.

`union-probe.sh` scores the proposition that is actually true, in three parts:

  * **NON-VACUITY** -- at least two bases must differ on their own, else the
    union is doing nothing. `MAX_BITSIZE_MODE_ANY_INT` is examined and comes
    out **512 on both**, so the arm **refuses to score it** and says so. It is
    deliberately NOT in `UNION_MACROS`; advertising coverage the arm declines
    to provide is the defect the EXIST/PREREG drift check exists to catch.
  * **MAXIMUM** -- the shared answer is the max, and in particular is **not the
    primary's own answer** (1024).
  * **BOTH-SIDEDNESS** -- the per-base generators are read separately, so the
    arm distinguishes "the union works" from "everyone now gets aarch64's
    answer for some other reason".

It reads the GENERATORS, not the checked-in header, because the generator is
where the maximum is computed and `move-if-change` actively hides a generator
that ran and changed nothing.

**Fault-injected, and it fires.** `INJECT=primary` makes the shared answer come
from the primary's generator -- which is not hypothetical: `genmodes.cc` carried
the union machinery since `f7c4d1aed68` with **nothing invoking it**, so every
shared number *was* the primary's. Result:

    MAX_BITSIZE_MODE_ANY_MODE  FAIL: i386=1024 aarch64=8192 shared=1024,
                               expected the maximum 8192      rc=1

### Wired into the board, both directions, in the same change

New status **`CONVERTED_UNION`**, checked against `UNION_MACROS` exactly as
`CONVERTED_EXIST` is checked against `EXIST_MACROS`, kept as a **third separate
population** (`a UNION arm is neither a TAB nor an EXIST arm; do not add the
three`). A third derivation channel `CONVERTED_BY_UNION` is declared and
bounded the same two ways as the existing hand-list: each name must be ABSENT
from the defaults.h-derived set, and must be spelled by `genmodes.cc`'s union
machinery.

Two faults injected, both fire by name:

    status relabelled UNCONVERTED   -> "union-probe.sh scores
      MAX_BITSIZE_MODE_ANY_MODE but macro-status.txt says UNCONVERTED"
    name removed from UNION_MACROS  -> "MAX_BITSIZE_MODE_ANY_MODE is marked
      CONVERTED_UNION but union-probe.sh's UNION_MACROS does not cover it"

### The new reading, run not quoted

    149 macros on the board = 74 unconverted + 32 TAB + 37 EXIST
                            + 1 UNION + 5 NO ARM
    macros probed: 81   i386 PASS 81 FAIL 0   aarch64 PASS 2 FAIL 79
    aarch64 PASS decomposition: 2 = 1 redirect-vs-itself (UNTRUSTED) + 1 other

**The aarch64 PASS fell 3 -> 2 and the TRUSTED count fell 2 -> 1.** That is the
correction, not a regression: the trusted 2 was never 2. One of the pair was a
target-neutral-agreement green on a macro the board did not know was converted.
The surviving trusted arm is `MAX_BITS_PER_WORD`, which is genuinely 64 on both
bases -- vacuous, but honestly so.

## 3. SECOND FINDING: A CHECK THAT DOES NOT EXIST, GUARDING THE HIGHEST-SEVERITY
   CLASS

`target-frame.h:230` declares `int max_move_max;` and its comment said this
base's value is *"checked at selection time so that the day it stops being true
is a diagnostic naming the base rather than a corrupted array."*

Measured by grepping the whole tree **and** the generated build directory:
`max_move_max` occurs **exactly twice, both in that file** -- the declaration
and the comment referring to it. **No initialiser, no reader, no assertion.**
PRINCIPLES section 4's "presence of a mechanism is not evidence anything
invokes it", on the one thing claimed to protect a bound-vs-index relation.

**And the relation it fails to guard is correct BY LUCK.** `caller-save.cc:55`
sizes `regno_save_mem[FIRST_PSEUDO_REGISTER][MAX_MOVE_MAX / MIN_UNITS_PER_WORD
+ 1]` from shared headers and indexes it with `MOVE_MAX_WORDS`, which is now
the *selected* base's. Values, derived from the back ends' own headers:

    i386.h:1929  MAX_MOVE_MAX 64        i386.h:770  MIN_UNITS_PER_WORD 4
    aarch64      defines NEITHER  -> defaults.h floors give 16 and 8

Shared code sizes 64/4 + 1 = **17**; aarch64 indexes to 16/8 = **2**. Nothing
overflows. The correct multi-target bound is
`max(MAX_MOVE_MAX) / min(MIN_UNITS_PER_WORD) + 1`, which for this pair is
**also 17** -- so no measurement available today can tell the leak from the fix,
because **the primary happens to supply both the largest numerator and the
smallest denominator**.

**They are a closure of exactly two, and converting either alone breaks it.**
With aarch64's `MIN_UNITS_PER_WORD` of 8 as the denominator the bound becomes
16/8 + 1 = 3 while i386 still indexes to 64/4 = 16 -- an overrun, quieter than
anything currently failing. So: `MAX_MOVE_MAX` unioned by MAXIMUM and
`MIN_UNITS_PER_WORD` by MINIMUM, **together or not at all**, and both must stay
compile-time constants (both are array bounds; neither may become an `mt_`
call). The generator that would carry them is `gen-reg-widths.sh`, whose every
existing reduction is a maximum -- a minimum needs its own initialiser and its
own refusal, which is precisely the kind of detail that has produced a
generator that ran, exited 0 and changed nothing.

**I did not convert them.** The change is a generator + probe-symbol + consumer
change whose only available arm on this base pair is structural (no value
moves, no behaviour moves), and landing half a two-member closure is the
failure this branch has nearly paid for four times. The comment now states what
is true, with the numbers, so the next agent does not re-derive them.

## 4. THIRD FINDING: THE aarch64 BAR IS SENSITIVE TO THE NAME OF ITS OWN INPUT

The brief's bar is *"aarch64 `int x = 1;` 373 bytes / `b01d9157fdc1`"*. In a
freshly built tree at branch HEAD, **before any change of mine**, it read 371
bytes / `84b06d9df5d2`.

It is not a codegen move. `-S` emits a `.file "<basename>"` directive, so both
the size and the md5 depend on **what the scratch file is called**. Same
compiler, same flags, same source text, one build dir:

    x.c      369 bytes
    one.c    371 bytes   md5 84b06d9df5d2
    mtbar.c  373 bytes   md5 4b06c278c6ca

The recorded **373 is reproduced exactly by any seven-character basename**, so
that figure is evidence about a filename and not about codegen. The md5 differs
again because it depends on the filename's *content*, not merely its length.

So `373 / b01d9157fdc1` is **not quotable between agents unless the input path
is quoted with it**, and no brief states one. The failure runs both ways: an
agent whose scratch file is named differently reads a MOVED bar and hunts a
regression that never happened, and a genuinely wrong compiler can match 373 by
choosing a filename. `t137-bars.sh` pins the basename to `one.c`, prints it,
and says the recorded md5 is not comparable. The x86_64 bar is unaffected only
because `scratchpad/big.c` is a fixed file everyone passes by the same name.

## 5. BARS -- all in `/tmp/b137`, my own build dir, before AND after

`/tmp/b137` configured through the TOP LEVEL with
`--enable-backends=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu`
(`t137-conf.sh`, which refuses any tree whose `gcc/Makefile.in` has fewer than
39 `MULTI_TARGET` hits -- this worktree was created at bare-repo HEAD
`7208eca60d0` with **0**, exactly as PRINCIPLES predicts, and was reset).

  * `make multi-target-objs cc1 lto1` -- **rc=0**.
  * **x86_64 `-O2` `big.c`: 12369 bytes, md5 `378fc33c1e70`** -- matches the
    recorded bar exactly, and **unmoved before and after in the same build
    dir**.
  * **aarch64 `-O2` `int x = 1;` as `one.c`: 371 bytes, md5 `84b06d9df5d2`** --
    unmoved before and after. See section 4 for why this is not the recorded
    373.
  * **stock-compare 5/5 IDENTICAL** vs `/tmp/b-stock`, absolute `IN`, run in
    THIS build dir (`mt cfg : /tmp/b137/lib/gcc/17.0.0/x86_64-pc-linux-gnu/
    specs-config`): O0 `1c00922491f8`, O1 `4fabab94b41b`, O2 `378fc33c1e70`,
    O3 `d220421237bc`, Os `d6787f7e281f`; **5 distinct md5s per side**;
    **negative control firing** (1158 vs 804 lines, differ). `OVERALL rc=0`.
  * Stderr on the rebuild: **360 lines, 95 `warning:`, 0 `error:`**, dominated
    by `-Wsign-compare` and `-Wformat-diag` from nixpkgs gcc compiling GCC.
    This is **not** comparable with the 32-line incremental floor: `target-frame.h`
    is included widely, so this is a partial-cold arm. Quoting which arm it is,
    per PRINCIPLES.
  * `target-specs` run for both targets with real aarch64 binutils
    (`t135-specs.sh`, rc=0) -- required, or the drivers refuse by name.

## 6. WHAT I DID NOT DO, AND WHAT CANNOT BE CHECKED

  * **No macro was converted in the compiler.** The one compiler-source change
    is a corrected comment in `target-frame.h`. The brief asked for a batch
    conversion from the top of the ranking; the top of the ranking turned out
    to be one macro already converted (fixed on the board instead), one pair
    that is a two-member closure with no observable arm on this base pair
    (section 3), and beyond them the large option-state families
    (`UNITS_PER_WORD` at 267 sites in 50 files, `POINTER_SIZE`,
    `BIGGEST_ALIGNMENT`) which are `MACRO-LEAK.md` class (c) and need the
    `targetm` route, not a union.
  * **`MAX_BITS_PER_WORD` was deliberately left alone.** It is 64 on both bases
    (class (a)), it is an array bound in eleven places, `defaults.h:1123` already
    carries a guard against `BITS_PER_WORD` becoming a runtime load underneath
    it, and it is now the board's *only* trusted header arm. Converting it would
    retire that arm to no benefit.
  * **The 5 remaining `CONVERTED_NOARM` macros are untouched** and still need
    the data-section (seventh) shape: `ELIMINABLE_REGS`,
    `RELOAD_ELIMINABLE_REGS` are `.rodata` tables; `ALL_REGS`, `GENERAL_REGS`,
    `LIM_REG_CLASSES` are enumerators whose union width is deliberately
    identical everywhere.
  * **The ranking cannot see value divergence**, only use, position, sizing and
    definedness. `MACRO-LEAK.md`'s measurement is still the authority on values,
    and its ~1049 unclassified identical-text macros remain unclassified.
