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
