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
are converted. The aarch64/riscv64/s390x rows are **not** expected to carry
this cause — the union's 95 *is* aarch64's own number, so aarch64 is not the
victim — but any cross-target comparison that leans on x86_64 as "the back end
that is served correctly" is currently invalid.
