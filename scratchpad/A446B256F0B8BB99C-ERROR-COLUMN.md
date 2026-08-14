# The `ERROR` column moves for environmental reasons — named

The #176 writeup recorded, as an honest negative it could not explain:

> `ERROR` fell 32 → 16 on **both** targets by the same amount, and `UNRES`
> moved −7 on x86_64.  An identical move on both targets is not attributable
> to a change that only alters what aarch64 computes; it is a harness or
> environment difference between the baseline run and this one.

That reading was correct.  This is the mechanism, measured.

## 1. The `ERROR` column counts LINES, not errors

DejaGnu reports one tcl failure as a multi-line block, and every line of it
begins `ERROR: `.  `mtscore.sh:66` scores the column as
`grep -c '^ERROR: '`, so **one failure contributes eight**.

Measured on a third target (riscv64, from another agent's run at
`/tmp/b-agent-a7481b2dba98203e0`), where the whole column is a single
occurrence:

```
$ grep -n '^ERROR' testsuite.riscv64-unknown-linux-gnu/gcc/gcc.sum
6290:ERROR: tcl error sourcing .../gcc.dg/asan/asan.exp.
6291:ERROR: tcl error code CHILDSTATUS 774622 1
6292:ERROR: xgcc: fatal error: no target selected
31829:ERROR: -------------------------------------------
31830:ERROR: in testcase .../gcc.dg/asan/asan.exp
31831:ERROR:  xgcc: fatal error: no target selected
31838:ERROR:  tcl error code CHILDSTATUS 774622 1
31839:ERROR:  tcl error info:
```

`grep -c` says **8**.  The number of things that went wrong is **one**.  The
block is even split in two places in the file (a 3-line summary near the top,
a 5-line detail block 25,000 lines later), which is why it does not look like
a block when you meet it.

So the column's unit is not "an error", and **a move of 32 → 16 is a move of
four blocks → two blocks**, not sixteen fixed defects.

## 2. The root cause is one thing, and it is target-independent BY CONSTRUCTION

Every line above descends from a single event: `gcc.dg/asan/asan.exp` fails to
source, because it invokes `xgcc` with no `-ftarget-config`, and this branch's
compiler answers

```
xgcc: fatal error: no target selected
```

That refusal is **this branch's own designed behaviour** — PRINCIPLES §2a:
*"A bare `gcc` failing by name when no target is selected is correct
behaviour, not a bug to fix."*  It is not a target-specific computation, so it
produces the identical text, and the identical line count, on **every**
target.  aarch64 and riscv above show the same classes; the aarch64 column's
remaining lines are the same shape (`c-c++-common` musttail globs, likewise
target-independent).

This is the whole answer to "an aarch64-only change cannot cause an identical
move on both targets": **nothing in this column is a target-specific
measurement in the first place.**  It cannot help but move identically.

## 3. Why it varies between runs at all

The count is a function of *how many times `asan.exp` gets sourced*, which is
scheduling, not compilation:

- Under `-j` the suite runs in parallel slot dirs (`mtcheck.sh:155` — "under
  `-j` there is one [`site.exp`] per parallel slot", and it mentions 128), and
  the merged `.sum` aggregates them.
- Two of the aarch64 classes embed a **PID** (`CHILDSTATUS 774622`,
  `struct_musttail2847408.cc`), so those lines are not even stable across two
  runs of the same compiler on the same tree.

So the column is expected to move whenever `-j`, slot count, or machine load
changes — all of which differed between the baseline run and #176's run, and
none of which is a property of the code under test.

## 4. What to do with it

- **Do not read `ERROR` as signal.**  Report it, do not net it out, and do not
  attribute a move in it to a code change without first checking whether the
  block count changed rather than the defect count.
- **Score it as blocks, not lines**, if it is to be scored at all: the useful
  number is `grep -c 'ERROR: tcl error sourcing'`, which is one per failure.
- `UNRES` moving on x86_64 is consistent with the same root — the tests inside
  a `.exp` that fails to source go UNRESOLVED — but that link is *not measured
  here* and is stated as a hypothesis, not a finding.
- The genuinely useful fix is upstream of the scoreboard: `asan.exp` should be
  reached with a target selected, or skipped by name.  Until then it is a
  constant, target-independent tax on two columns.

**Instrument caveat:** this was measured on another agent's surviving run
(`/tmp/b-agent-a7481b2dba98203e0`), because the runs #176 scored had already
been deleted.  The mechanism (block structure, root cause, target-independence
across aarch64 and riscv) is directly observed there; the specific 32 and 16
are #176's figures and are not re-derived.
