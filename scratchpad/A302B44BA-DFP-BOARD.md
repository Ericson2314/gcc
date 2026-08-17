`decimal_float` RE-TAKE, THE BOARD — x86_64, aarch64, s390x, DEBT AND SCOPE
===========================================================================

The second half of `A302B44BA-DFP-RETAKE.md`.  That row settled the mechanism
and wrote down a PREDICTION before the runs landed, so that it could be wrong.
This is the check.

0. PROVENANCE
-------------

```
worktree    /home/jcericson/src/gnu/gcc/multi-target, branch multi-target-0
            THE TRAP DID NOT FIRE.  rev-parse equality, not ancestry:
              git rev-parse HEAD           = 1167d3f15f7a9c38aab0473023a35f452e10ba25
              git rev-parse multi-target-0 = 1167d3f15f7a9c38aab0473023a35f452e10ba25
            EQUAL -- NEITHER divergence case.  Not the bare repo's stale HEAD,
            not another agent's line.  scratchpad/ present (1283 files).

MULTI-TARGET SIDE (the compiler under test)
  srcdir    /tmp/snap-multi-target-7b39423abba  (git archive, read-only)
  anchor    grep -c MULTI_TARGET gcc/Makefile.in = 55   MEASURED on the snapshot
  build     /tmp/b-302b44ba-mt  (+ two verified byte-identical copies, §2)

STOCK SIDE (THE CONTROL, and it is named)
  srcdir    /tmp/snap-stock-302b44ba, upstream merge-base
            c31b7a09eea3c33bccca12bab4a7bb6b01da1ff6, anchor 0, testsuite graft
  builds    /tmp/b-stock-agent-302b44ba-<triple>, one per target
  tools     /tmp/tools-302b44ba: real cross binutils and real target glibc
```

1. THE BOARD IS AT `7b39423abba`, AND THAT IS WHY IT CAN BE ATTRIBUTED
-----------------------------------------------------------------------

The brief's central complication is that a great deal landed after the recorded
figures were taken, so a moved number may have several causes.  **On this board
it cannot, and the reason is ancestry, checked rather than assumed.**  The
compiler under test is the snapshot at `7b39423abba`:

```
commit          in the build under test   at the branch tip
9ee972c229d     IN                        in    decimal_float from the manifest -- THE FIX
3ff8b3f835c     IN                        in    driver just_machine_prefix
80ded688145     NOT IN                    in    as_dtprel_reloc + 4 `$ts_ppc_s' probes
423c81b65f2     NOT IN                    in    generated back-end headers installed
83dd42cc697     NOT IN                    in    --target=<host> stops enrolling a back end
207e43bf5dd     NOT IN                    in    build_target_triple coupling named
5e122b17aa7     NOT IN                    in    gcc/default-backends deleted
```

**Every one of the five confounders the brief names is absent from the compiler
that produced these numbers.**  So no delta on this board can be caused by
them — not as a judgement, but by construction: the code is not in the
binary.  The one change that separates this board from the recorded one, in
the area under test, is `9ee972c229d`.

This also fixes the anchor.  `grep -c MULTI_TARGET gcc/Makefile.in` is **58**
at the tip and **55** here, and passing 58 to the harness makes it REFUSE — as
it should, because 58 is not this compiler.  Attributed exactly:
`git show 423c81b65f2^:gcc/Makefile.in | grep -c MULTI_TARGET` = 55,
`git show 423c81b65f2:...` = 58, and the diff adds exactly three
`MULTI_TARGET_GEN_HDRS` lines.  The brief's account of that bar is TRUE.

2. HOW THE RUN WAS FINISHED, AND THE ONE REAL CORRUPTION IT HIT
-----------------------------------------------------------------

The row was left with two detached serial drivers, each a `for t in <4 targets>`
loop with a single-threaded runtest inside it, both still on their x86_64 arm
after 1h20m.  `a302b44ba-par.sh` started the remaining arms in parallel instead
of queueing them behind x86_64.

The stock side is free — four separate build dirs.  The multi-target side is
not: `mtcheck.sh:335` does `rm -rf "$ASDIR"` and the script does `rm -f
site.exp` per target, because site.exp does NOT depend on `TEST_TARGET`, so two
concurrent runs in ONE build dir race on exactly the file whose readback proves
target attribution.  Each extra multi-target arm therefore got its **own copy**
of the 1.4G build tree, and the copy is REFUSED unless `gcc/xgcc` and `gcc/cc1`
are md5-identical to the original.  Both copies passed
(`xgcc 649546843f9b44568c97d2ce6ec0f373`, `cc1 624d390e75a9ba8c48c378c1820fa30c`)
and then produced their own distinct per-target `specs-config`
(md5 `977235d26055` aarch64, `2306c687a1d8` s390x, vs `bb32b9ec25ca` x86_64),
which is the evidence that the copy is not silently running one target's config.

**AND THE PARALLEL START EXPOSED A REAL CORRUPTION, WHICH IS RECORDED BECAUSE
IT INVALIDATED DATA.**  The surviving serial stock driver finished its x86_64
arm and advanced to aarch64 — into
`/tmp/b-stock-agent-302b44ba-aarch64-unknown-linux-gnu`, the same build dir the
parallel arm was already using.  Two `runtest`s were appending to ONE
`gcc.sum`.  Confirmed by name, not inferred: PIDs 329820 and 549642, both
`sc-check.sh` on that directory, and two `runtest.exp` processes with
`TESTSUITEDIR=testsuite.aarch64-unknown-linux-gnu`.

The contaminated `gcc.sum` was DISCARDED — not repaired, not deduplicated —
the serial loop was killed so it could not advance again, and the aarch64 stock
arm was rerun from an empty testsuite dir.  Deduplicating it was rejected: the
scorers key on `name#occurrence`, so a doubled result set does not read as
corrupt, it reads as a target with twice the coverage.

3. THE INSTRUMENTS, RE-VALIDATED BEFORE ANY NEW NUMBER WAS QUOTED
-------------------------------------------------------------------

All three scorers reproduce the recorded i686 row exactly, on the surviving
i686 build pair, with no adjustment:

```
scorer                              recorded                 measured now
taa-mtscore.sh                      PASS 157580 FAIL 16048   PASS 157580 FAIL 16048
                                    UNSUP 5816 UNRES 12951   UNSUP 5816 UNRES 12951
a9364e5cd42e818ad-scope.sh          193997 / 194232          193997 / 194232
                                    only-mt 114 / stock 349  only-mt 114 / stock 349
a660907426e03e4e9-debtnames.sh      34                       34
```

**AND SO DOES THE STOCK CONTROL, WHICH MATTERS MORE.**  The stock x86_64
control built for THIS row, from merge-base `c31b7a09eea`, scores

```
PASS 163816   FAIL 16223
```

— which is, to the unit, the figure `A992B7E5FA4FFAAA7-BOARD.md:281` records
for the stock x86_64 control of the board that produced the recorded debt of
67.  That is an independently rebuilt compiler landing on the same two numbers,
so the two boards' "before" and "after" are being measured against the SAME
control, and the comparison below is a like-for-like one rather than two
different baselines subtracted.

4. THE ASSEMBLER GUARD CAN FAIL — AND ITS ADVERTISED CLAUSE CANNOT
--------------------------------------------------------------------

`8be9340191f` rewrote GUARD 3c after finding it RED at the tip.  A rewritten
guard that now passes is exactly what this project has been burned by, so the
claim tested was not "3c passes" but "3c still refuses a wrong assembler"
(`a302b44ba-guard3c.sh`).  Two findings.

**The obvious fault injection proves nothing, and it looked like it did.**
Repointing `$ASDIR/{as,$T-as}` at the host assembler is ERASED by
`mtcheck.sh:335` (`rm -rf "$ASDIR"`), which rebuilds both links from `$TDIR`
before the guard runs.  That run printed
`-- guard: assembler is riscv64-unknown-linux-gnu's own` with both links
pointing at the host `as` on disk at launch.  The script reported INCONCLUSIVE
rather than reading it as a detection.

**With the fault moved to `$TDIR`, where it survives, the block DOES refuse —
but not by the clause the commit message advertises.**

```
ARM A  real tools dir          rc=0   assembler ... produces: IBM S/390
ARM B  $TDIR/$T-as = host as   rc=9   the target's own assembler rejected the output
```

In ARM B the `readlink -f` identity clause **passed**, printing
`(= s390x-ibm-linux-gnu's own)` while `$T-as` was the host assembler.  It
compares `$ASDIR/$T-as` with `$TDIR/$T-as`, and `mtcheck.sh` created the former
as a symlink to the latter — so `readlink -f` of the two is the same file for
ANY content of `$TDIR`, and the clause CANNOT FAIL.  It re-checks the link the
script just made.  The clause that caught the wrong assembler is the ELF-machine
check at `mtcheck.sh:411`.

So the guard is sound, the rewrite did not loosen it, and the brief's
description of *why* it is sound is wrong: the `readlink -f` proof it credits
is decorative.  The build-dir name guard also fired for real on the first
attempt, refusing `/tmp/g3c-302b44ba`.

5. BARS, MEASURED ON THE TREE UNDER TEST
------------------------------------------

```
grep -c MULTI_TARGET gcc/Makefile.in    58 at tip / 55 on the snapshot under test
                                        both measured; attributed to 423c81b65f2 in §1
a660907426e03e4e9-mtgap.sh               2   mt_base, mt_dwarf2_unwind_info_hook
                                        (336 called, 334 declared)  AS THE BRIEF SAYS
x86_64 -O2 big.c                    12369 bytes  md5 378fc33c1e70   == THE RECORDED BAR
  in=/tmp/snap-multi-target-7b39423abba/scratchpad/big.c, via
  MT_TAG=b-302b44ba WANT_ANCHOR=55 mt-bars.sh, after mt-specs.sh (rc=0)
  specs-config x86_64: wc -l 232  grep -c . 224  md5 bb32b9ec25ca
mt-shcheck.sh                         rc=1  RED, AS THE BRIEF SAYS.  arm 1: 1 of
                                        1208 files fails `sh -n` --
                                        scratchpad/t132-neigh.sh line 30,
                                        "unexpected EOF looking for matching `".
                                        Pre-existing, another agent's file, NOT
                                        TOUCHED.  This row's two new scripts are
                                        among the 1207 that pass.
```

The bar was taken on the idle verification copy, not on a tree with a run in
it, so measuring it could not perturb the board.

6. THE PREDICTION'S `dfp.exp` HALF — RE-DERIVED, AND IT HOLDS EXACTLY
-----------------------------------------------------------------------

Re-counted from the `.sum`s rather than inherited:

```
target                       manifest   gcc.dg/dfp  c-c++-common/dfp  TOTAL   verdicts
x86_64-pc-linux-gnu                 1          749               110    859        858
aarch64-unknown-linux-gnu           1          749               110    859        858
s390x-ibm-linux-gnu                 1          749               110    859        858
riscv64-unknown-linux-gnu           0            1                 0      1          0
```

```
target                        PASS   FAIL   UNSUPPORTED   UNRESOLVED
x86_64-pc-linux-gnu            846      0            12            0
aarch64-unknown-linux-gnu      845      0            13            0
s390x-ibm-linux-gnu            839      0            19            0
```

**Every figure the brief predicts for this half is confirmed to the unit**:
859 = 749 + 110 on all three, 1 on riscv64 with **zero results of any verdict**
in its `.sum`, 858 verdicts carrying **0 FAIL**, PASS 846/845/839, and
846+12 = 845+13 = 839+19 = 858, so the remainder is UNSUPPORTED exactly as
stated.  The riscv64 `1` is the `Running ...` banner and nothing else — the
negative control, and the sharpest available: same compiler, same harness, same
`dfp.exp`, three orders of magnitude apart, decided by the target's own
manifest line.

7. THE BOARD — x86_64, AND THE PREDICTION IS REFUTED ON IT
------------------------------------------------------------

```
x86_64-pc-linux-gnu     stock control: PASS 163816 / FAIL 16223 (both runs)

                        BEFORE (e1f0cad1c2c)      AFTER (7b39423abba)
multi-target PASS/FAIL  162164 / 16295            163438 / 16299
DEBT                    67                        70          <- PREDICTED 67
SCOPE  results in mt    197,878                   199,046
       results in stock 199,289                   199,289
       only in STOCK    1,647                     322
       only in MT       236                       79
```

`.rc` stamp 0, `make check-gcc` rc=0, 1/1 `site.exp` attributes to
x86_64-pc-linux-gnu, `multi-target.exp` banner present, GUARD 3c reports
*Advanced Micro Devices X86-64*.

**THE SCOPE HALF OF THE PREDICTION HOLDS AND THEN SOME.**  The only-in-stock
column closes by **1,325**, of which 858 are the `dfp.exp` verdicts — so the
understatement really was in scope, and the fix accounts for about two thirds
of the closure.

**THE DEBT HALF IS REFUTED.  67 was predicted UNCHANGED; it is 70.**  Reported
as a refutation rather than rounded to "essentially unchanged": the prediction
was written to be falsifiable and this falsifies it.

**AND THE THREE ARE CLASSIFIED, NOT ASSUMED.**  The standing rule on this
branch is that new debt names are not automatically regressions — ten such were
once measured to be previously-UNSUPPORTED tests that had started running.
These are not those.  Joined by name against the before run and the control:

```
gcc.target/i386/pr43644.c scan-assembler-times movq 2      before PASS -> now FAIL, stock PASS
gcc.target/i386/pr78671.c (test for excess errors)         before PASS -> now FAIL, stock PASS
gcc.target/i386/zext-sse-2.c check-function-bodies func2   before PASS -> now FAIL, stock PASS
```

Zero debt names went away.  All three are **genuine PASS -> FAIL regressions**,
and all three are `gcc.target/i386` codegen — **none is decimal float**.

`pr78671` is not a scan mismatch at all; it is an ICE, and it reproduces off
the built `xgcc` in about a second:

```
error: insn does not satisfy its constraints:
(insn 228 21 22 2 (set (reg:TI 43 r15 [orig:699 _37 ] [699])
        (reg:TI 0 ax [orig:699 _37 ] [699])) ... 98 {*movti_internal})
during RTL pass: reload
internal compiler error: in extract_constrain_insn, at recog.cc:2794
```

A TImode value allocated to `r15` — the last general register, which cannot
start a two-register pair.  That is the register allocator's
prohibited-class-mode table failing to prohibit it.

**WHAT THE ATTRIBUTION IS, AND WHAT IT IS NOT YET.**  Established:

* **It is NOT the `decimal_float` fix.**  All 858 dfp verdicts on this target
  are 846 PASS / 0 FAIL / 12 UNSUPPORTED (§6); none of the three regressions
  involves decimal float; and `pr78671`'s failure is in `reload`.
* **It is NOT any of the five commits the brief names as confounders.**  None
  of them is in this binary (§1).
* **It is new in `e1f0cad1c2c..7b39423abba`.**  All three names are `PASS` in
  FOUR preserved earlier x86_64 boards — `a992b7e5fa4ffaaa7` (the recorded
  one), `a01e6c604f26604a7`, `a97cff7619d3cabd9` and `ab1900d5279ba137f` — so
  the introducing commit is inside that 150-commit window.
* Of those 150, exactly **three** touch the register/mode/recog machinery:
  `3241754cf12` (bounds the MODE axis of two `ira.cc` walks,
  `setup_prohibited_and_exclude_class_mode_regs` among them),
  `f1c3095db2c` (`asm_fprintf`'s `%R`/`%I`/`%L`) and `24ef2a0c2ff`.

**NOW ESTABLISHED BY BISECT — it is `3241754cf12`.  See §9.**  The paragraph
below is what motivated the bisect and is kept as written, because the reading
turned out to name the right commit for a reason that does not survive contact
with §9's hunk-level result: reading points hard at `3241754cf12` — it
makes `ira_prohibited_class_mode_regs[cl][j]` stay CLEARED for skipped modes,
and for a *prohibition* table CLEARED is not the inert value its commit message
claims ("both already mean 'nothing here'"); it is the maximally PERMISSIVE
value, which is exactly what would let `r15` hold TImode.  But `MODE_IS_HOLE_P`
is per-base and x86 really has TImode, so that path should not fire for this
mode, and the reading does not close.  **Stated as an open suspect, not as the
attribution**, because on this branch a plausible mechanism that was never run
is precisely the failure mode being guarded against.  A bisect is running
(`a302b44ba-icebuild.sh`); `pr78671` answers in one second per step, so only
the build is expensive.

8. THE BOARD — s390x, REFUTED IN THE OTHER DIRECTION, AND THE PREDICTION'S
   PREMISE IS WHAT BREAKS
---------------------------------------------------------------------------

```
s390x-ibm-linux-gnu     stock control: PASS 130895 / FAIL 15627 (both runs)

                        BEFORE (e1f0cad1c2c)      AFTER (7b39423abba)
multi-target PASS/FAIL  128882 / 15776            130465 / 15744
DEBT                    206                       134         <- PREDICTED 206
SCOPE  results in mt    166,594                   167,787
       results in stock 168,040                   168,040
       only in STOCK    1,998                     340
       only in MT       552                       87
```

**Debt was predicted UNCHANGED at 206.  It is 134 — it FELL by 72.**  So the
prediction is refuted on this target too, in the opposite direction from
x86_64.  A board that reported only "206 -> 134, an improvement" would be
hiding the more interesting fact, which is that **the prediction's REASONING
was wrong, not just its number.**

Movement by name: **74 debt items gone, 2 new.**

**THE 74, ATTRIBUTED.**  Of the 74 that went away, **60 are in test files that
use `_Decimal`** — `gcc.target/s390/dfp-1.c`, `dfp-conv1.c`,
`dfp_to_bfp_rounding.c`, `pfpo.c`, the six `vector/long-double-{from,to}-
decimal{32,64,128}.c`, `signbit-2/3.c` and
`isfinite-isinf-isnormal-signbit-1/2.c`.  **That is `9ee972c229d`, the
`decimal_float` fix, and it is removing DEBT — which the prediction says it
cannot do.**

**WHY THE PREDICTION WAS WRONG, AND IT IS A GATING FACT, NOT AN ARITHMETIC
SLIP.**  The prediction generalised from `dfp.exp` to all decimal-float tests.
`gcc.dg/dfp/dfp.exp:23` is

```tcl
if { ![check_effective_target_dfp] } {
```

and it `return`s — **the whole `.exp` bails out**, so its 859 results are never
attempted and land wholly in SCOPE, contributing nothing to debt in either
direction.  That is exactly what §6 measures and it is true.

But the target-specific decimal tests are **NOT GATED**.  `gcc.target/s390/
dfp-1.c`, `dfp-conv1.c` and `vector/long-double-from-decimal64.c` carry **no**
`dg-require-effective-target dfp` (measured: 0 each), and they run from
`s390.exp`, which does not bail.  So they were **attempted, and they FAILED**
with an excess error — they were sitting in the DEBT column all along, not in
scope.  The prediction reasoned from the gated suite to the ungated tests and
that step does not hold.

**AND THE SAME MEASUREMENT EXPLAINS WHY x86_64 DID NOT MOVE THIS WAY.**  Of
x86_64's 67 before-debt items, the number whose test file uses `_Decimal` is
**0**.  There was nothing on that target for the fix to take out of debt.  The
asymmetry is not noise; it is which back end has ungated decimal tests in its
own directory.

The remaining **14** of the 74 are not decimal at all —
`atomic-align-1.c` (4 `.align` scans), `isfinite-isinf-isnormal-signbit-3.c`
(9) and `pr79890.c` (1).  Those are `.align`/codegen scans and belong to the
assembler-output work in the same range (`3d1ca4b936b`, `46335722ef7` and
neighbours); they are **not** attributed to a single commit here, and are
listed as unattributed rather than folded into the dfp count.

**THE 2 NEW ARE NOT REGRESSIONS, AND THEY WERE CHECKED RATHER THAN ASSUMED.**

```
gcc.dg/lto/pr52634 ... link, -flto -r -flto-partition=1to1   before-MT: (absent)  now FAIL  stock PASS
gcc.dg/torture/pr67619.c -O3 -g (test for excess errors)     before-MT: (absent)  now FAIL  stock PASS
```

Both are **absent from the before run entirely** — no verdict of any kind.
They were never attempted before and are attempted now, so they are SCOPE
converting into DEBT, not `PASS -> FAIL`.  This is the same class as the ten
previously-UNSUPPORTED tests the standing rule was written for, and it is why
the rule exists: counted as regressions they would have read as the fix
breaking LTO.

Guards: `make check-gcc` rc=0, `site.exp` attributes to s390x-ibm-linux-gnu,
`multi-target.exp` banner present, GUARD 3c reports **IBM S/390**, and the run
was taken on a copy proven md5-identical to the original build (§2).

9. THE x86_64 REGRESSION, ATTRIBUTED BY BISECT — `3241754cf12`
----------------------------------------------------------------

An unattributed delta is not a measurement, so the +3 was bisected rather than
argued.  `a302b44ba-icebisect.sh`, 150 commits, `e1f0cad1c2c..7b39423abba`:

```
   e1f0cad1c2c (want NO):  NO         <- endpoints VERIFIED before any search
   7b39423abba (want YES): YES
-- [1..150]   mid=75  5d28dd6c071 : NO
-- [76..150]  mid=113 3241754cf12 : YES
-- [76..113]  mid=94  23a070127c8 : NO
-- [95..113]  mid=104 4bfbb8abf87 : BAD   (build failed; EXCLUDED, not scored)
-- [105..113] mid=109 6905962904b : NO
-- [110..113] mid=111 01218faa6f2 : NO
-- [112..113] mid=112 f1c3095db2c : NO

BISECT: FIRST BAD COMMIT = 3241754cf12
  two more hook-calling ordinal mode walks in `ira.cc', following pru's backtrace
```

**The answer does not rest on the skipped build.**  Index 112 (`f1c3095db2c`)
is NO and index 113 (`3241754cf12`) is YES — adjacent, both measured — so the
first bad commit is 113 regardless of what `4bfbb8abf87` would have said.  That
is stated because a bisect with a skip in it is exactly where a convergence can
be an artefact of the skip.

**HOW IT WAS MADE AFFORDABLE, and each step was measured first, not assumed:**
`pr78671.c` reproduces off the built `xgcc` in about a second, and the ICE
still fires at **two bases** — so each step is a ~6-minute two-base build
rather than a 47-base one.  Had it needed the full union the bisect would have
been unaffordable, which is precisely why the base count was measured before
the script was written.

**IT DOES NOT USE `git bisect`.**  This runs in the shared main worktree with
other agents live in it; `git bisect` moves HEAD and rewrites the working tree
every step.  The search is a plain binary search over `git rev-list`, and every
tree is materialised with `git archive | tar -x` into /tmp — object database
only, never HEAD, the index, or a worktree file.

**THE INSTRUMENT REFUSED THREE TIMES BEFORE IT MEASURED ANYTHING**, each time
for a real reason and each time reporting that the endpoints did not bracket
the fault rather than bisecting on failed builds: no `specs-config` (it is a
post-build `mt-specs.sh` pass, not part of `all-gcc`), no `SNAP-SHA` stamp, and
a writable snapshot.  A bisect that had "converged" through any of those would
have named a commit chosen by a broken probe.

**WHAT THIS MEANS FOR THE BOARD.**  The x86_64 debt of 70 is
`67 + 3`, and the 3 belong to `3241754cf12` — an `ira.cc` change unrelated to
this row's subject.  So the `decimal_float` fix moves x86_64's debt by **0**,
which is the prediction's claim; the prediction is refuted on the *figure* and
correct on the *cause*.  Both halves are reported.

10. THE STOCK CONTROL FOR `3241754cf12` — THE DEFECT IS OURS, NOT INHERITED
-----------------------------------------------------------------------------

"The bisect names this commit on the branch" is **not** the claim "this commit
is a regression".  `ira.cc` has already been made per-base by this branch in
several places — #123 (i386's `ELIMINABLE_REGS` reaching every back end) and
#205 (`init_reg_class_start_regs` compiled to an empty body) — so a
branch-specific interaction was entirely plausible, and it is the difference
between *fix our bug* and *inherit upstream's behaviour change*.  §9 could not
distinguish them.  This section does.

**THE ASKED-FOR CONTROL WAS "STOCK AT `3241754cf12` AND AT ITS PARENT", AND
THAT TURNS OUT NOT TO BE TWO TREES.**  Measured before building anything:

```
git merge-base <rev> c31b7a09eea   ==  c31b7a09eea   for ALL of
    e1f0cad1c2c, 3241754cf12^, 3241754cf12, 7b39423abba
git log -1 --format=%p 3241754cf12 ==  f1c3095db2c   (ONE parent, not a merge)
author                              =  John Ericson (branch-authored)
```

The upstream content is **byte-identical either side of the boundary**.  There
is no stock boundary to cross, so "stock regressed across it too" is not a
possibility the evidence leaves open — and building two identical stock trees
to compare them would have been a check that could not fail.

**ANCESTRY ARGUMENTS HAVE BEEN WRONG ON THIS BRANCH BEFORE, so that is not left
as the whole answer.**  The positive half asks the stock control the question
directly (`a302b44ba-stockctl.sh`), with the ICE **compiled** rather than read
out of a `.sum`:

```
STOCK CONTROL: /tmp/b-stock-agent-302b44ba-x86_64-pc-linux-gnu
  srcdir /tmp/snap-stock-302b44ba (upstream merge-base c31b7a09eea, anchor 0)
  full-suite score: PASS 163816  FAIL 16223
      == A992B7E5FA4FFAAA7-BOARD.md:281's figure for the control behind debt 67

  gcc.target/i386/pr43644.c scan-assembler-times movq 2      PASS
  gcc.target/i386/pr78671.c (test for excess errors)         PASS
  gcc.target/i386/zext-sse-2.c check-function-bodies func2   PASS

  stock compiled the ICE case cleanly: 341 lines of asm, no ICE.
```

The script refuses to score "no ICE" as clean unless the compiler also emitted
assembly, so "did not ICE" cannot be the same silence as "did not compile".

```
STOCKCTL: STOCK IS CLEAN ACROSS THE BOUNDARY.
```

**CONCLUSION: the branch regresses where stock does not.**  `3241754cf12` is
interacting with THIS BRANCH's per-base `ira.cc` work; the defect is **ours to
fix**, not an upstream behaviour change to absorb.  §11 says which half of the
commit does it.
