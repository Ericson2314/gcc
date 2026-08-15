# THE STOCK CONTROL — the multi-target board against unmodified GCC

> ## THE SME/SME2 ACLE CLUSTER IS CLOSED AT `b2fc4c0b9f8` (SME2 at PARITY)
>
> ```
> directory              BEFORE (14,126 board)      NOW           STOCK
> sme2/acle-asm          28544 /  9050          37594 /   0    37594 / 0
> sme/acle-asm            3004 /  1154           3982 / 176     4070 / 0
> ```
>
> **`sme2/acle-asm` is at 37,594 PASS / 0 FAIL — exact parity with stock**, and
> the 9,050 that were the single largest entry on the whole board are gone.
> `sme/acle-asm` is 1,154 -> 176. Measured on a 47-base build against a
> baseline build of the same tree, same harness, GUARD 3c supplying the
> target's own assembler, both `.rc`-stamped, **KILLED 0**, load ~1 at scoring
> (not provisional).
>
> **Two causes, cleanly separable, both "one name, several authorities":**
>
> | cause | fixed in | what it was worth |
> |---|---|---|
> | `EPILOGUE_USES` was i386's (`df-scan.cc:3647`) | `9a15499d33c` | all 8,926 `check-function-bodies` in sme2, all 962 in sme |
> | `ASM_DECLARE_FUNCTION_NAME` was i386's (`varasm.cc:2218`) | `4620cbee33b` + `b2fc4c0b9f8` | the 744 COMPILE the first fix EXPOSED |
>
> The second was **hidden behind the first**: while `EPILOGUE_USES` was
> causing DCE to delete every ZA-writing instruction, the assembler never saw
> them, so the missing per-function `.arch` could not surface. That is why the
> COMPILE column ROSE (124 -> 744) while the FAIL total collapsed. A rising
> sub-count beside a falling total was previously-hidden work becoming
> visible, not a regression — and only reading the errors could tell them
> apart.
>
> **The other two ACLE directories do NOT share the cause, measured rather than
> assumed:** `sve/acle` and `sve2/acle` have **zero** `check-function-bodies`
> failures, so a defect whose entire effect is wrong emitted code cannot
> explain them. `aarch64_epilogue_uses` touches only LR and the ZA/SME state
> registers, so the mechanism agrees with the numbers. They are compile
> failures and are a separate investigation.
>
> Also found and NOT fixed: **multi-target aarch64 emits no DWARF CFI at all**
> (no `.cfi_startproc`, and `-freorder-blocks-and-partition` is silently
> disabled where stock leaves it on), and `riscv64` had been losing its `ra`
> restore before a sibcall — a latent wrong-code bug the `EPILOGUE_USES` fix
> removes. Full detail, with the instruments and one retracted claim, in
> `A5764A65F9EEC0063-EPILOGUE-USES.md`.

> ## SUPERSEDED — BOTH TARGETS, FINAL FIGURES AT `03cfa434d1c` + `6bdfe647912`
>
> ```
>            TAA-BOARD   after specs/headers/cselib   FINAL
> aarch64     205,433              93,526            14,126
> s390x        20,326              14,256             7,884
> ```
>
> **93% of aarch64's recorded debt and 61% of s390x's are gone**, measured
> against these same intact stock sums. aarch64 PASS is now **328,251 against
> stock's 344,463** — within 16,212, having started the day at 88,001.
>
> Four causes, in order of what they were worth:
>
> | cause | fixed in | aarch64 | s390x |
> |---|---|---|---|
> | `extra_headers` per back end | before today | 114,447 | — |
> | `register_filters[]` never filled (#205) | `6bdfe647912` | ~79,400 | — |
> | the HOST x86 assembler (#204, HARNESS) | GUARD 3c | ~10,142 | 7,205 |
> | `-ftarget-config=` read no specs | before today | — | large on riscv64 |
>
> The old §3a/§7 numbers below are all superseded. In particular **§3a's
> 194,711 valuation of `extra_headers` was an over-attribution** (the true
> figure is 114,447), and **§7's #2 item, `gcc.c-torture/compile`, was never a
> compiler defect at all** — it was the host assembler, and that directory's
> s390x debt fell 10,114 → 2,909 once the target's own `as` was used.
>
> **AND §3a's `extra_headers` VALUATION OF 194,711 IS WRONG — DO NOT QUOTE
> IT.** That number is the whole `gcc.target/aarch64` debt, credited to
> `extra_headers` because missing headers were the directory's top diagnostic.
> Measured after the fix, that directory's debt is **194,711 -> 80,264**: the
> fix was worth **114,447 (59%)** and **80,264 (41%) remains**, for causes that
> sat underneath the missing headers and were invisible until they were
> supplied. **Crediting a directory's whole debt to its top diagnostic
> over-attributed by 80,264 results.**
>
> The new figure is itself an UPPER bound: the compiler measured carries the
> `cselib.cc:2650` regression (122,646 ICEs), fixed in `2e5f4730465` and not
> in that build. Full row, ranked residual and by-name diff in
> `A57163422943AAA57-REBASELINE.md`.
>
> **s390x is ALSO superseded, measured at tip `03cfa434d1c` with the `cselib`
> fix in:**
>
> ```
> s390x debt     20,326  ->  14,256
> ```
>
> Read that row with its scope change: s390x produced **32,679 fewer results
> in total** and 10,200 test files produce fewer results than before, so its
> PASS fall of 90,464 -> 77,778 is overwhelmingly scope, not quality — only
> **620** named tests regressed. Neither figure is `-j`-sensitive any more
> (the ERROR column is decomposed).
>
> **Both boards' §7 work queue is now stale.** Re-ranked from the tip runs:
> the SVE/SME ACLE family (~102,000 aarch64 FAILs, stock **0**) is #1, and
> `gcc.c-torture/compile` (aarch64 10,142 + s390x 10,114 = 20,256, stock **0**
> on both) is #2 and untouched by anything that landed today.
>
> ## THE STOCK SIDE STANDS. THE MULTI-TARGET SIDE, AND THEREFORE THE DEBT, DOES NOT.
>
> **The debt figures — aarch64 205,433 and s390x 20,326 — are UPPER BOUNDS and
> are overstated by an unknown amount.** They are `stock PASS -> multi-target
> NOT PASS`, and the multi-target side of that subtraction is `TAA-BOARD.md`'s
> run, which was taken on a compiler that **read no per-target spec file at
> all**: an explicit `-ftarget-config=FILE` left `found_target_config` NULL, so
> `set_up_specs` never opened `dirname(cfg)/specs`, and `mtcheck.sh` drives
> exactly that flag. aarch64 was compiled without `-mabi=lp64
> -mlittle-endian`; s390x without `-march=z900`. See TAA-BOARD.md's header.
>
> The `extra_headers` fix has also landed since, and section 3a values that one
> defect at **194,711 of the 205,433** aarch64 regressions. So the aarch64
> figure in particular should be expected to move by something of that order.
>
> **The stock side is unaffected and has been re-verified.** Re-read at
> `5eb6cb0e5e3` from the same build dirs, which survive intact:
>
> ```
> /tmp/b-stock-agent-a3464debf6893de84-aarch64  344463 PASS  20443 FAIL
> /tmp/b-stock-agent-a3464debf6893de84-s390x    130895 PASS  15627 FAIL
> ```
>
> — reproducing section 2 row for row, including XPASS/XFAIL/UNSUP/UNRES/ERROR.
> The control never used `-ftarget-config=`; stock GCC has no such flag. So
> section 0 (what the control cost to get right), section 1 (provenance),
> section 4 (the common part) and the stock rows of section 2 all stand, and
> re-deriving the debt needs **only a fresh multi-target run**, not a fresh
> control.
>
> One figure in section 2 is additionally an artefact on BOTH sides: the ERROR
> column counted `^ERROR: ` LINES, and one aborted `.exp` emits three of them
> once per `runtest` slot, so it scaled with `-j`. `mtscore.sh` now reports
> distinct causes and distinct aborted `.exp` files beside the raw line count.

`#61` recorded it plainly: **no arm had ever compared against an unmodified
GCC** except for x86_64. This is that control for `aarch64` and `s390x`, and
it changes what every number on `TAA-BOARD.md` means.

**Headline: aarch64's 98,027 FAIL and s390x's 46,009 FAIL are NOT the debt.**
Most of each column is what upstream GCC does to that target in a compile-only
run with no target libgcc. The debt is the part stock does not have.

## 0. WHAT THE CONTROL COST TO GET RIGHT — read this before §2

**The control had two defects of its own, and the first one produced a result
that looked like success.** Both are recorded in full because both are this
project's own recurring shape — a silent floor that reads as a measurement.

| defect | how it presented | scale |
|---|---|---|
| `--with-native-system-header-dir` alone is **inert for a cross** (`cppdefault.cc` flags it `cross_include` and the driver drops it) | GCC's own `stdint.h` is an `#include_next` wrapper with nothing behind it: `fatal error: stdint.h: No such file` | **66,883** occurrences, the top cause of the whole stock run |
| the cross was configured with `ORIGINAL_AS_FOR_TARGET = <nix gcc-wrapper>/bin/as` — **the HOST x86 assembler** — for *both* targets, wrapped as `gcc/as` | everything that assembles died; `gcc.c-torture/compile` drives `-c`, so `dg-do`'s compile-only downgrade never reaches it | **10,100** FAILs in that one directory on **both** targets; on s390x `invalid -march= option: 'z900'` **21,534** times |

The first defect is the instructive one. With it in place the stock aarch64
board read **84,572 PASS / 98,093 FAIL** against the multi-target board's
**88,001 / 98,027** — *a FAIL column agreeing to 0.07%*. Two unrelated
missing-header floors, one per side, summing to an apparent parity. Had that
been reported, the project's acceptance bar would have been "aarch64 is
already at parity with stock", which is false by roughly an order of
magnitude.

**The control has to be audited for its own floors before its agreement with
the thing under test means anything.** Four guards now enforce it, all
reading the *running* compiler rather than the build system:

- **S2** `xgcc -dumpmachine` names the target back.
- **S3** the target's own glibc headers are in `-E -v`'s search list **and** a
  TU including `<stdint.h>` compiles.
- **S4** `-print-prog-name=as` (not a Makefile grep — the defect was a wrapper
  answering to the name `as`), then assemble a real function and require
  `<target>-readelf -h` to name the machine. The host gas accepts an empty
  file, so "no complaint" would have been another way to see nothing.
- **G5a/G5b** the grafted `multi-target.exp` banner **and**, separately, the
  compile-only banner. Without the graft `MT_COMPILE_ONLY` is silently inert
  on the stock side and the control acquires a uniform link-FAIL floor.

## 1. PROVENANCE — quote this with the board

```
multi-target side  /tmp/b-agent-aa9936ad7ccd9023c   (TAA-BOARD.md, unchanged,
                   snapshot 555482db346, anchor 49, four bases)
                   -- the .sum files were re-read, not re-run; the numbers
                      reproduce TAA-BOARD.md exactly (aarch64 88001/98027)
stock side         srcdir /tmp/snap-stock-agent-a3464debf6893de84
                   = upstream c31b7a09eea (the branch's merge-base with
                     upstream/master), git archive, read-only, no .git
                   MULTI_TARGET anchor in gcc/Makefile.in = 0  (INVERTED
                     assert: the control must not be the branch)
                   + EXACTLY TWO testsuite files grafted from ba415463e56:
                     lib/multi-target.exp verbatim, and one `load_lib' line
                     at the same position gcc-dg.exp uses on the branch.
                     NO compiler source is touched.
                   builds /tmp/b-stock-agent-a3464debf6893de84-{aarch64,s390x}
                     --target=<T> --enable-languages=c,lto --disable-bootstrap
                     --disable-nls --disable-multilib --disable-werror
                     --with-as/--with-ld = the same cross binutils the
                       multi-target run uses (nixpkgs pkgsCross, binutils 2.46)
                     --with-sysroot + --with-native-system-header-dir=/include
                       = the same glibc headers, same store paths
                     make all-gcc rc=0, `error:' 0, no target libgcc anywhere
mode               MT_COMPILE_ONLY=1 on BOTH sides, same dg-do downgrade, same
                   full suite, no exclusions, no RUNTESTFLAGS beyond
                   GCC_UNDER_TEST.
scripts            scratchpad/sc-{snap,conf,build,check,diff}.sh
```

**`--target` is used here and it is the stated exception**: this is a
top-level configure of a cross compiler, the dispatcher case, and it is the
only way a control exists at all — stock GCC has no `--enable-backends`.

## 2. THE BOARDS

```
                        PASS      FAIL   XPASS   XFAIL   UNSUP    UNRES  ERROR
aarch64-unknown-linux-gnu
  multi-target         88001     98027       3     832   11012   133394     26
  stock               344463     20443       2    1995    6731    17003      8
  delta              -256462    +77584      +1   -1163   +4281  +116391    +18

s390x-ibm-linux-gnu
  multi-target         90464     46009       5     651    7811    13948     29
  stock               130895     15627       2    1229    7440    12839      8
  delta               -40431    +30382      +3    -578    +371    +1109    +21
```

**Stock aarch64 passes 344,463 tests where multi-target passes 88,001.** The
multi-target FAIL column is not the interesting one — the **UNRESOLVED** column
is, and it is `+116,391`: the compilation failed, so the test could not be run.

**KILLED: 0 on every stock run** (`internal compiler error: Killed`,
`terminated by signal 9`, `out of memory`) — counted, never subtracted.

## 3. THE DEBT — `stock PASS -> multi-target NOT PASS`

### 3a. aarch64 — **205,433 regressions**, and one cause is 95% of them

```
by multi-target verdict    121250 -> UNRESOLVED    84180 -> FAIL    3 -> XPASS
top directories            194711  gcc.target/aarch64
                            10093  gcc.c-torture/compile
                              171  gcc.dg/compat
                               28  gcc.dg/tree-ssa
                               16  c-c++-common/torture
                               14  gcc.c-torture/unsorted
                               13  gcc.dg/torture

DIRECTORY                  FAIL_MT   FAIL_ST     PASS_MT   PASS_ST
gcc.target/aarch64           75306      2260        6441    211477
gcc.c-torture/compile        10120         0         432     15044
```

**Only 12,922 aarch64 FAILs are shared with stock.** Against a board that read
98,027 FAIL, the debt is 205,433 results — *larger* than the FAIL column,
because most of it is UNRESOLVED, which no previous reading counted.

`gcc.target/aarch64` alone is **194,711**, and `TAA-BOARD.md` §4 already names
the cause: `extra_headers` is collected once for the legacy single `${target}`,
so the build dir holds **only i386's intrinsic headers** and every test
including `arm_neon.h`, `arm_sve.h` or `arm_neon_sve_bridge.h` dies. Stock
ships those headers and passes 211,477 results in that directory against
multi-target's 6,441. **That one build-system defect is worth 194,711 test
results** — a number nobody could state before this control existed. (Another
agent is live on `extra_headers`/`config.gcc`; this is that work's valuation, not a
claim on it.)

### 3b. s390x — **20,326 regressions**, against a 46,009 FAIL column. So **14,988 of
the multi-target FAILs are stock's too** and are not this project's bug.

```
by multi-target verdict     19683 -> FAIL      643 -> UNRESOLVED
top directories             9859  gcc.c-torture/compile
                            2540  gcc.dg/torture
                             987  gcc.target/s390
                             887  gcc.dg/tree-ssa
                             593  gcc.dg/vect
                             326  c-c++-common/torture
                             276  gcc.dg/debug
                             253  gcc.dg/sso
                             243  gcc.dg/params
```

**The cleanest single row in the whole exercise:**

```
DIRECTORY                  FAIL_MT   FAIL_ST     PASS_MT   PASS_ST
gcc.c-torture/compile        11623         0        4872     15043
gcc.dg/torture                5060        89       13284     16280
gcc.dg/tree-ssa               1238         3        7962      8905
gcc.dg/vect                   1186         2         949      1544
gcc.target/s390                599         9        2225      3212
c-c++-common/torture           652         0        2186      2512
gcc.dg/sso                     506         0          17       270
gcc.dg/params                  486         0           0       243
```

`gcc.c-torture/compile`: **stock fails zero, multi-target fails 11,623.** That
directory alone is half the s390x debt and it is pure compile-and-assemble —
no libgcc, no execution, nothing to excuse it.

**And the ICEs are 100% debt.** Stock s390x's entire ICE population is the
testsuite's own deliberate `I'm sorry Dave` plus 2 segfaults. The
multi-target side, same target, same tests:

```
5782  internal compiler error: in as_a, at machmode.h:416
4257  Segmentation fault
1295  in s390_match_ccmode_set, at config/s390/s390.cc
```

`as_a, at machmode.h:416` is the site `TAA-BOARD.md` §4c already reports on
**four** non-primary back ends. The control now says what that board could
not: upstream does not do this at all.

## 4. THE COMMON PART — real, and not this project's

`12,922` aarch64 and `14,988` s390x FAILs are identical on both sides. The largest component is the
link floor the compile-only downgrade cannot reach, because it wraps `dg-do`
and some suites drive the compiler themselves:

```
stock s390x top diagnostic:  14126  error: ld returned 1 exit status
gcc.c-torture/execute        FAIL_MT 15789   FAIL_ST 12750
gcc.misc-tests/gcov-19.c     940 FAILs on BOTH sides, and on every target
```

**Do not subtract it.** It is stated so a reader can see how much of the FAIL
column is not a multi-target observation at all.

## 5. SCOPE DIFFERENCE — the two runs did not attempt identical work

```
aarch64   joined 324180   only stock 66465   only multi-target  7115
          only-in-stock:  gcc.target/aarch64 12138, gcc.c-torture/execute 7872,
                          gcc.dg/torture 7066, gcc.dg/vect 6036,
                          c-c++-common/gomp 5046, gcc.c-torture/compile 4564
s390x     joined 146313   only stock 21727   only multi-target 12604
          only-in-stock:  c-c++-common/gomp 5044, gcc.dg/analyzer 4353,
                          c-c++-common/analyzer 3191, c-c++-common/goacc 2843,
                          gcc.dg/gomp 1722, gcc.dg/dfp 748
```

**The multi-target build declines whole test directories the stock build
attempts** — the analyzer, OpenMP and OpenACC suites, ~21.7k results. That is
itself an unexamined finding, not a defect in the comparison: those tests are
not in the multi-target FAIL column *or* its PASS column. Anyone quoting §2's
totals must read them beside this.

## 6. PROVISIONAL, AND WHY

The machine carried other agents throughout; load was 26–53 during these runs
and 32 at scoring, **above the ~25 threshold**. KILLED is 0 on every stock
run, and the conclusions in §3–§4 rest on counts in the thousands, so they
stand. **Test-by-test diffing of individual rows from this board is not
warranted at this load.**

The multi-target side is `TAA-BOARD.md`'s own run, which was itself taken at
load 8–25 and marked provisional there. Two provisional boards were compared;
that is stated rather than hidden.

## 7. WHAT THIS CHANGES ABOUT THE PROJECT'S BAR

The acceptance bar is **parity with stock for that back end**, and it is now
measurable, per target, per directory, per test name.

```
target    board FAIL   shared with stock   THE DEBT
aarch64        98027              12922     205433   (121250 of it UNRESOLVED)
s390x          46009              14988      20326
```

**Both directions of surprise appeared, as expected.** On aarch64 the debt is
*larger* than the FAIL column, because 121,250 regressions are UNRESOLVED and
no reading of the FAIL column could see them. On s390x a third of the FAIL
column turns out to be upstream's own behaviour.

The work queue, in order, with its price:

1. **`extra_headers` per back end** — 194,711 aarch64 results. Already owned.
2. **`gcc.c-torture/compile`** — 10,093 on aarch64 and 9,859 on s390x, and
   **stock fails ZERO** in that directory on both. One directory, two targets,
   ~20k results, pure compile-and-assemble.
3. **`as_a, at machmode.h:416`** — 5,782 on s390x, and stock's entire ICE
   population on that target is the testsuite's own deliberate ICE plus two
   segfaults. `TAA-BOARD.md` §4c reports the same site on four non-primary
   back ends.

**What a stock run does NOT excuse.** The 940 `gcov-19.c` FAILs, the
`ld returned 1 exit status` floor and the whole execution-shaped residue are
present on both sides on both targets. They were never this project's bug and
they are now measured rather than assumed.
