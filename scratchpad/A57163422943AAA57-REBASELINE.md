# THE RE-BASELINED BOARD at `5eb6cb0e5e3` — x86_64 first, and it is CONTAMINATED

Re-run after the `-ftarget-config=` specs fix, because every board this
project held was measured on a compiler that read no per-target spec file.

## Provenance — quote this with any row

```
srcdir      /tmp/snap-agent-a57163422943aaa57
            git archive of 5eb6cb0e5e3, read-only, SNAP-SHA stamped
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52   (measured)
build       /tmp/b-a57163422943aaa57
            --enable-targets=x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,
                             riscv64-unknown-linux-gnu,s390x-linux-gnu
            make all-gcc rc=0; `error:' 0; multiple definition 0;
            undefined reference 0; Killed 0
bars        x86_64 -O2 big.c  12369 bytes / md5 378fc33c1e70   (== recorded)
            specs-config wc -l 232  grep -c . 224
              x86_64 cfbc7a65e54e   aarch64 575aff0c188b       (== recorded)
              riscv64 9af7409ac460  s390x   37901805bf3c
mode        MT_COMPILE_ONLY=1, make -j6, all-gcc only, no target libgcc
tools       real cross binutils + each target's own glibc headers (taa-tools.sh)
memcap      ulimit -v 8 GB on the shell launching runtest, INHERITED by every
            cc1 -- verified on the RUNNING cc1 via /proc/<pid>/limits, not
            merely set in a shell
guards      mt-specsread.sh PASSES 4 arms per target (the spec file is read AND
            its contents reach cc1); site.exp attribution; multi-target.exp
            banner; non-vacuity
scorers     mtscore.sh with the ERROR-line fix (ERRUNQ/ERRTCL/ERRLIN)
```

## x86_64 — DO NOT USE AS A BASELINE

```
              OLD (TAA-BOARD, 555482db346)   NEW (5eb6cb0e5e3)     delta
PASS                162118                        155030          -7088
FAIL                 16340                         29955         +13615
XPASS                    3                             4             +1
XFAIL                 1556                          1554             -2
UNSUPPORTED           4451                          4451             +0
UNRESOLVED           13366                         14165           +799
ERROR (raw lines)       26                            26             +0
KILLED                   0                             0
load at scoring 6.3-7.9 fifteen-minute -- below the ~25 threshold
```

**This row is not a baseline. It is a known, diagnosed, UNFIXED regression
being measured.**

`scratchpad/A446B256F0B8BB99C-CSELIB-X86-REGRESSION.md` (commit `1c2aa68c52d`)
found it at two bases and `a8eb6bb16e3` and reported 6784 ICEs. It is **still
live at `5eb6cb0e5e3` at four bases**, and this run adds three things that
report did not have:

- **It is deterministic.** 8 runs of the new compiler on the same input:
  `rc=1` eight times. 8 runs of TAA-BOARD's own surviving compiler on the same
  input: `rc=0` eight times, 3480-byte object. Not the flaky/heap-corruption
  class.
- **It is the dominant cause of the whole column move.** ICE occurrences in the
  x86_64 log went from ~10 in the entire TAA-BOARD run to:

  ```
  7164  in cselib_invalidate_regno, at cselib.cc:2650
   294  in df_ref_record, at df-scan.cc:2614
   223  in hashtab_chk_error, at hash-table.cc:126
   215  Floating point exception
  ```

- **Quantified by NAME, not by column: 7,018 real regressions**
  (`PASS -> NOT PASS` on the same test name): 6,220 to FAIL and 798 to
  UNRESOLVED, against only 7 `NOT PASS -> PASS`. Top directories
  `gcc.dg/torture` 2158, `gcc.c-torture/compile` 1922, `gcc.target/i386` 1079,
  `gcc.dg/debug` 371.

The recorded diagnosis stands and is worth restating because it is the exact
shape PRINCIPLES calls the commonest remaining one — **the bound is the
union's, the numbering is per base** — with the primary as the *victim* for
once:

```
MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER   95   (aarch64's)
i386's own FIRST_PSEUDO_REG                92
```

so x86_64 regnos **92, 93, 94** are genuine pseudos that `cselib.cc:2648`'s
`if (regno < FIRST_PSEUDO_REGISTER)` classifies as hard registers. The
CLASSIFIER sites need `MT_FIRST_PSEUDO_REGISTER`; the BOUNDS/LAYOUT sites
correctly want the union's.

**Why no bar caught it: none of the bars uses `-g`.** 5,699 of the 6,784 were
on `-ON -g` variants, because `cselib` is reached through `vartrack`. That
report's own closing recommendation — a `-g` arm on the codegen bar, one extra
`cc1` invocation — is still not implemented and would have caught this the day
it landed.

## What I checked and RULED OUT, including one I got wrong first

**It is NOT the specs fix.** The obvious hypothesis was that x86_64 now
receives `-march=x86-64 -mtune=generic` from its spec file and did not before.
Ruled out three ways: neither flag reproduces it when added by hand; a valid
"no per-target specs" fixture ICEs **identically**; and TAA-BOARD's own
compiler, *with* its own per-target specs, compiles the file clean.

**And the first version of that experiment was a FALSE NEGATIVE that pointed
the other way.** The "without specs" arm initially read *clean*, which I
briefly took as decisive evidence that the specs fix caused the ICE. It was
measuring a **deleted fixture**: `mt-specsread.sh` does `rm -rf` on its work
directory, and running it per target (as `mtcheck.sh` GUARD 3b now does)
destroys the previous target's bare fixture. `xgcc` answered
`fatal error: no target selected` and produced no object — and my grep was for
the ICE string, which is absent from that message. **`rc=1` with no object
looked exactly like `rc=0` with an object through a grep for one substring.**
Caught by asserting the control had actually *compiled something* rather than
merely *not printed the thing I was looking for*. That assertion is the whole
difference between the two conclusions, and they were opposite.

**It is not the memcap.** 0 `out of memory` / `virtual memory exhausted`
markers and 0 KILLED in the x86_64 log; the failing inputs are a few lines
long and nowhere near 8 GB.

## aarch64 — NOT MEASURED. The run was killed, and the `=== gcc Summary` guard PASSED on the wreckage.

The four-target run was stopped during aarch64. What it left behind is worth
recording, because it is a live instance of a guard this project already knew
was insufficient and had not seen fail:

```
gcc.sum has `=== gcc Summary'      YES   -- the guard passes
results in the merged sum          54,900
a COMPLETE aarch64 run             ~331,000  (TAA-BOARD's own figure)
check-aarch64-...rc stamp          ABSENT
```

The summary block is internally consistent — 28948 + 18908 + 223 + 5069 +
1742 ≈ the 54,900 lines present — so **nothing about the file looks
truncated.** It is a complete-looking summary of a sixth of a run. Had the
scorer trusted the `=== gcc Summary` marker alone it would have printed
`aarch64 28948 PASS / 18908 FAIL` beside x86_64's real numbers, and that row
is not obviously wrong: it is the right shape, the right order of magnitude
for a bad target, and it would have been quoted.

**The `.rc` stamp is what caught it**, exactly as its comment claims:

```
aarch64-unknown-linux-gnu   REFUSED: no check-aarch64-...rc stamp -- the run did not finish
```

The post-conditions I ran by hand all PASS on this wreckage too — the
`multi-target.exp` banner is present, and all 6 `site.exp` files attribute to
aarch64. So four of the five guards are green on a partial run and only the
stamp is red. That ratio is the argument for keeping it.

**No aarch64 number from this run may be quoted, including by me.**

## Consequence for the re-baselining exercise

x86_64 cannot serve as the control column until `cselib.cc`'s classifier sites
are converted. ~~The aarch64/riscv64/s390x rows are **not** expected to carry
this cause — the union's 95 *is* aarch64's own number, so aarch64 is not the
victim~~ — **THAT SENTENCE IS FALSE AND IS RETRACTED; see the aarch64 section
below. The union is 128 at four bases, not 95, so every base except the widest
has a band and aarch64 carries 122,646 of these ICEs.** Any cross-target
comparison that leans on x86_64 as "the back end that is served correctly" is
currently invalid.

---

# aarch64 — MEASURED, and I WAS WRONG ABOUT WHY IT WAS SAFE

## The row

```
TARGET                       PASS     FAIL  XPASS  XFAIL  UNSUP   UNRES  ERRUNQ ERRTCL ERRLIN
aarch64-unknown-linux-gnu  200002   136330      3   1246  11012   34980       6      1     26

KILLED 2   (`virtual memory exhausted' -- the ulimit -v cap firing, i.e. two
            compilations that would otherwise have taken the box.  Counted,
            never subtracted.)
load at scoring   8.86 / 10.73 / 9.65 -- fifteen-minute 9.65, well under 25.
                                         NOT provisional.
.rc stamp         PRESENT (asserted; the `=== gcc Summary' marker is NOT
                  sufficient -- it passed on a sixth of a run, above)
```

Against TAA-BOARD's aarch64 run at `555482db346`: **PASS 88,001 -> 200,002**,
**UNRESOLVED 133,394 -> 34,980**.

## MY "aarch64 IS IMMUNE TO THE cselib BUG" CLAIM WAS FALSE

I told the coordinator this board could run on the pre-`cselib` compiler
because aarch64's own `FIRST_PSEUDO_REGISTER` **is** the union's. Measured:

```
MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER   128    <- at FOUR bases
i386's own                                  92
aarch64's own                               95
```

**The union is 128.** The recorded diagnosis measured 95 in a TWO-base build,
where 95 was aarch64's own. At four bases every base except the widest has a
band; aarch64's is regnos 95..127. The log carries **122,646**
`cselib_invalidate_regno` ICEs against **0** in the old run.

**AND MY CORROBORATION COULD NOT HAVE DETECTED THE ERROR.** I offered, as an
independent second direction, that aarch64 codegen was byte-identical between
the fixed and unfixed compilers. That comparison was run at `-O2` **without
`-g`**, and `cselib` is reached through `vartrack`, which only runs with debug
info — so it never entered the affected path and was structurally incapable of
firing. Same shape as the paren-balance check that passed on 16 corruptions:
**a check that answers a different question than the one asked comes back
clean and reads as confirmation.** Third instance today.

What survives: a base whose own count EQUALS the union has no band. What was
wrong was believing aarch64 was that base at four bases.

## THE CORRECTED DEBT — 205,433 -> 93,526

Both ends confirmed rather than quoted: stock re-verified at 344463/20443, and
`sc-diff.sh` reproduces the recorded 205,433 exactly including its
121250/84180/3 split.

```
                       BEFORE (TAA-BOARD)   NOW (5eb6cb0e5e3)
debt                        205,433              93,526
  -> UNRESOLVED             121,250              23,250
  -> FAIL                    84,180              70,273
```

**111,907 results taken back.** The figure is still an UPPER bound on the true
debt: this compiler carries the `cselib` regression, which is fixed in
`2e5f4730465` and not in this build.

## AND IT DISAGREES WITH SC-BOARD §3a — THAT IS THE FINDING

§3a attributed **194,711** — the entire `gcc.target/aarch64` debt — to
`extra_headers`, because the missing-header diagnostics were that directory's
top cause. Measured:

```
gcc.target/aarch64 debt   194,711  ->  80,264
                          taken back: 114,447   (59%)
                          REMAINING:   80,264   (41%)
```

`extra_headers` was worth **114,447, not 194,711**. The estimate
over-attributed in the familiar way: **the top diagnostic in a directory was
credited with the whole directory.** 80,264 results there fail for causes that
sat underneath the missing headers and were invisible until they were
supplied. Do not quote 194,711 again.

## RANKED RESIDUAL — the work-list

```
122,646  cselib_invalidate_regno, at cselib.cc:2650    FIXED in 2e5f4730465,
                                                       absent from this build
 23,154  lra_split_hard_reg_for, at lra-assigns.cc:1907  \
  7,718  unable to find a register to spill              |  plausibly ONE
  2,556  could not split insn                            |  register-allocation
  1,884  maximum number of LRA assignment passes (30)    /  family
  7,668  final_scan_insn_1, at final.cc:2844
     45  hashtab_chk_error, at hash-table.cc:126
      6  find_strided_accesses, at aarch64-early-ra.cc:2373
```

The LRA cluster is the next target. "Unable to find a register to spill" and
"maximum assignment passes achieved" are what a register allocator says when
its notion of the register file disagrees with the target's — and the union is
128 while aarch64's own is 95. **That is the first hypothesis to test, and it
is the same family as the `cselib` fix rather than a new one.**

## BY-NAME DIFF — the cardinality arm earning its place

```
PASS   88,001 -> 200,002   (+112,001)
FAIL   98,027 -> 136,330   (+38,303)     <- a RISE
UNRES 133,394 ->  34,980   (-98,414)

CARDINALITY: 10,099 test files produce MORE results, +52,876 in total
  e.g. gcc.target/aarch64/sve/acle/asm/dup_s16.c   248 -> 258

*** 52,876 of the new run's results come from tests that produced fewer
    results before.  The +38,303 FAIL rise is SMALLER than that, i.e. inside
    the noise the effect creates.

TRANSITIONS      87,963  UNRESOLVED -> PASS
                 26,789  FAIL       -> PASS
                 10,203  UNRESOLVED -> FAIL
                  2,677  PASS       -> FAIL
                    166  PASS       -> UNRESOLVED

REAL REGRESSIONS (PASS -> NOT PASS, by name): 2,843
  1,656 gcc.dg/torture   369 gcc.dg/debug   164 gcc.target/aarch64
  named: overwhelmingly `-O2 -g' and `-O3 -g' variants
```

**This is the #188 shape and the arm resolves it.** As columns, FAIL rose
38,303 and reads as a regression. As names, 114,752 results moved INTO PASS
and only 2,843 tests genuinely got worse — and those are `-g`-shaped, i.e. the
`cselib` regression the old run did not have and which is already fixed.

---

# s390x and riscv64 at `03cfa434d1c` (tip, `cselib` fix IN)

Build `/tmp/b-a57163422943aaa57-lra`, snapshot `/tmp/snap-a57163422943aaa57-lra`,
anchor 52, four bases, `make all-gcc` rc=0 / `error:` 0. Bars at tip: x86_64
`-O2` **12369 / `378fc33c1e70`**, and the new `-g` arm rc=0 with debug
sections present.

```
TARGET                       PASS    FAIL  XPASS  XFAIL  UNSUP   UNRES  ERRUNQ ERRTCL ERRLIN
s390x-ibm-linux-gnu         77778   30153      3    620   8186    9469       6      1     26
riscv64-unknown-linux-gnu  205641   23455     19    868  21911    9345       6      1     26

was (TAA-BOARD)  s390x    90464   46009 ... 13948
                 riscv64  75980   90931 ... 97787
KILLED   s390x 0   riscv64 10   (`virtual memory exhausted' = the ulimit -v cap
                                 firing; counted, never subtracted)
```

**`cselib_invalidate_regno` is 0 on both** — the fix confirmed on two further
targets, not only on x86_64.

## riscv64 — the largest single movement on the board

**PASS 75,980 -> 205,641; FAIL 90,931 -> 23,455; UNRESOLVED 97,787 -> 9,345.**
TAA-BOARD's top riscv cause was 26,718 `default_version, at
riscv-common.cc:162` — the driver reaching `cc1` with no `-march` and no
`-mabi`, which is exactly what the `-ftarget-config=` specs defect caused.
This is that fix measured over a full suite.

## s390x — the debt: 20,326 -> 14,256

```
                    BEFORE      NOW
debt                20,326    14,256
  -> FAIL           19,683    14,076
  -> UNRESOLVED        643       177
```

**AND ITS TOTALS FELL ON EVERY AXIS, WHICH THE CARDINALITY ARM EXPLAINS AND A
COLUMN READING WOULD NOT.** PASS fell 90,464 -> 77,778 — but so did FAIL
(46,009 -> 30,153) and UNRESOLVED (13,948 -> 9,469). The run produced **32,679
fewer results in total.**

```
test files producing FEWER results:  10,200
test files gone entirely:               361
test files producing MORE:               78  (+87)
REAL REGRESSIONS (PASS -> NOT PASS, by name):  620
  495 gcc.c-torture/compile   44 gcc.target/s390   22 gcc.dg/torture
```

This is the **inverse** of aarch64's shape — there, tests expanded because
they began compiling; here they contracted. **The PASS drop is overwhelmingly
a scope change, not 12,686 tests getting worse: only 620 named tests
regressed.** *Why* 10,200 files yield fewer results is NOT established here
and is the honest open question on this row. Anyone quoting s390x's PASS
column must quote the scope change beside it.

## s390x ranked residual

```
3,860  s390_match_ccmode_set, at config/s390/s390.cc:1518
   21  hashtab_chk_error, at hash-table.cc:126
    3  assert_rtx_eq_at, at selftest-rtl.cc:57
```

**TAA-BOARD's top two s390x causes are GONE**: `as_a, at machmode.h:416`
(5,782) and `Segmentation fault` (4,257) are both **0**.
`s390_match_ccmode_set` rose 1,295 -> 3,860, which is what a cause left
standing looks like once the ones in front of it are removed.

## s390x RE-RUN under GUARD 3c — and the 10,200 contracted files are explained

Same build, same snapshot, with the target's **own** assembler (GUARD 3c) and
the register-filter fix (`6bdfe647912`):

```
                     host as        own as + filter fix
PASS                  77,778              121,026
FAIL                  30,153               29,633
UNRESOLVED             9,469               13,328
total results        126,209              172,875     (+46,666)
KILLED                     0                    0
guard: assembler is s390x-ibm-linux-gnu's own, and it produces: IBM S/390
```

**THE OPEN QUESTION IS ANSWERED.** The 10,200 s390x files that "contracted"
and the 32,679 missing results were not a scope change in the suite: they were
tests dying at the assembler before producing their remaining results. Given
its own assembler the target produces **46,666 more results** and PASS rises
by 43,248. Nobody needs to diff the old numbers — they were taken through an
x86 assembler.

## THE DEBT, three readings of the same target

```
20,326   TAA-BOARD, before anything landed today
14,256   after the specs + cselib fixes, still assembling with the HOST as
 7,884   with the target's own assembler and the register-filter fix
```

**s390x's debt is 7,884, not 20,326** — 61% of it was removed today, and the
part attributable to the harness alone is visible in one directory:

```
gcc.c-torture/compile debt   10,114  ->  2,909
```

7,205 of that directory's "debt" was the host assembler, exactly as
`A57163422943AAA57-HOST-ASSEMBLER.md` predicted. **The 2,909 that remain are
real** and are now the honest top entry for this target.

Current s390x debt by directory: `gcc.c-torture/compile` 2,909,
`gcc.dg/torture` 1,581, `gcc.target/s390` 502, `gcc.dg/tree-ssa` 500,
`gcc.dg/vect` 336, `gcc.dg/params` 243, `gcc.dg/debug` 243.

## The standing #2 work item is untouched and is now the largest after SVE/SME

`gcc.c-torture/compile`: **aarch64 10,142 + s390x 10,114 = 20,256 results of
debt, and stock fails ZERO there on both targets.** SC-BOARD ranked it #2
before today; nothing that landed today touched it.
