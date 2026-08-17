# THE FOUR-TARGET BOARD AT `e1f0cad1c2c`, 47 BASES

**COMPLETE. `BOARD.rc` = 0, all four `.rc` stamps 0, all four sums preserved.**

```
TARGET      DEBT   WAS   stock PASS/FAIL     multi-target PASS/FAIL   KILLED
x86_64        67    67   163816 / 16223      162164 / 16295             0
s390x        206   207   130895 / 15627      128882 / 15776             0
aarch64      443   513   344463 / 20443      341962 / 20688             0
riscv64      772   772   270248 / 15904      268925 / 16762            10
                  ----                                                 ---
TOTAL      1,488  1,559
```

**Movement by name — the only column that distinguishes a fix from a
regression:**

```
target    baseline       joined rows   unchanged   PROGRESS  REGRESSIONS
x86_64    d5ad77b33b3      197,827     197,827          0         0
riscv64   d5ad77b33b3      320,946     320,946          0         0
aarch64   e3fac057ae4      388,970     388,898         71         1
s390x     e3fac057ae4      166,546     166,545          1         0
```

## 0. THE BRIEF'S CENTRAL EXPECTATION IS REFUTED BEFORE THE RUN, AND IT IS
##    MEASURABLE FROM THE BUILD'S OWN GENERATED HEADERS

The brief says:

> **`DELAY_SLOTS` is the one to watch.** Delay-slot filling has never run on
> 12 back ends; turning it on changes their code generation substantially [...]
> Expect movement.

**None of those twelve back ends is on this board.** Measured from this build's
own `genattr-common` output, `/tmp/b-a992b7e5fa4ffaaa7/gcc/insn-attr-common-*.h`:

```
$ grep -H '^#define DELAY_SLOTS 1' insn-attr-common-*.h
arc cris fr30 h8300 iq2000 microblaze mips or1k pa sh sparc visium   (12)

$ grep -H 'define DELAY_SLOTS' insn-attr-common-{i386,aarch64,riscv,s390}.h
i386 0   aarch64 0   riscv 0   s390 0
```

The board's four targets are exactly the four that read **0** — i.e. the four
for which i386's leaked `0` was *already the right answer*. The fix is real and
it is real for twelve back ends this board does not score.

The same holds, for its own reason, for each of the other three landed causes:

| cause | back ends it reaches | any of the four? |
|---|---|---|
| `STACK_SAVEAREA_MODE` / `extract_insn` 71 → 2 | the six with **no** `restore_stack_nonlocal`: alpha arc arm avr mips or1k | **no** — and `aarch64 i386 riscv s390` are four of the seven that HAVE the expander, i.e. exactly the ones the leak could not reach |
| the DFA-absent fix | the 9 automaton-less back ends; the 29 automaton-bearing ones were byte-identical | **no** — all four have automata |
| `GO_IF_LEGITIMATE_ADDRESS` | `fr30`, the tree's only definer | **no** |
| `TARGET_PTRMEMFUNC_VBIT_LOCATION` + 2 vtable macros | 8 back ends, and it is a **C++** ABI fact | **no** — this board is `check-gcc` |
| `FINAL_PRESCAN_INSN` | 14 definers, **including `aarch64`** | **yes, aarch64 only** |

So exactly one of the four unmeasured causes can touch this board at all, on
exactly one of its four rows. And that one is bounded further:

```c
/* aarch64.h:1045 */
#define FINAL_PRESCAN_INSN(INSN, OPVEC, NOPERANDS) aarch64_final_prescan_insn (INSN);

/* aarch64.cc:24340 */
void aarch64_final_prescan_insn (rtx_insn *insn)
{
  if (aarch64_madd_needs_nop (insn))
    fprintf (asm_out_file, "\tnop // between mem op and mult-accumulate\n");
}

/* aarch64.cc:24304 */
  if (!TARGET_FIX_ERR_A53_835769)
    return false;
```

`TARGET_FIX_ERR_A53_835769` is off unless `-mfix-cortex-a53-835769` is passed,
so aarch64's prescan hook is a **no-op on every test this board runs**.

## 0a. AND THAT PREDICTION IS ONLY TRUE FOR TWO OF THE FOUR ROWS — THE BRIEF'S
##     "LANDED SINCE, UNMEASURED" LIST IS INCOMPLETE, AND NOT IN A SMALL WAY

Written after §0 and before the run, as a correction to my own paragraph.

The commit chain is `e3fac057ae4` → `d5ad77b33b3` → HEAD `e1f0cad1c2c`
(`git merge-base --is-ancestor`, both arms, asserted). What was scored where:

| commit | board | what it scored |
|---|---|---|
| `e3fac057ae4` | `A01E6C604F26604A7` | all four — 67 / 513 / 2,074 / 207 |
| `d5ad77b33b3` | `A018835BBCFAD2E28` | riscv64 (**772**, superseding 2,074) and x86_64 (`162171/16295`, byte-for-byte inert) — and **aarch64 and s390x NOT AT ALL** |

Between those two commits landed the auto-inc conversion (`784a5b556d9`,
`bd6f4dbe3ae`), the alignment leaks (`7247d7aea83`, `4f2f6fcb8c5`) and
**`PROMOTE_MODE`** (`0f82873ef1a`, `d5ad77b33b3`). None of these is on the
brief's list, because the brief's list is "since the last *full* board" and
riscv64 was scored later and alone.

**That set is not inert on aarch64 and s390x, and it is the one that moves
numbers.** `PROMOTE_MODE` alone took riscv64 1,116 results in one step;
`aarch64.h` is one of its definers and `s390` is not, so aarch64 changes
answer and s390x stops receiving i386's. `bd6f4dbe3ae` is titled *"the eight
`USE_*` macros too, **or aarch64 regresses**"*. The A018 board files this as
its own handover item 6 — *"a suite run for aarch64 and s390x on this tip [...]
aarch64 is the one to do first"* — and says plainly that "unmoved" is not a
claim available for them.

So the honest per-row prediction is:

```
row       baseline       span                              predicted
x86_64    d5ad77b33b3    the brief's 4 causes              NULL
riscv64   d5ad77b33b3    the brief's 4 causes              NULL
aarch64   e3fac057ae4    4 causes + auto-inc/align/PROMOTE MOVEMENT, unattributable
                                                           to the brief's four
s390x     e3fac057ae4    4 causes + auto-inc/align/PROMOTE MOVEMENT, ditto
```

**Whatever aarch64 and s390x do, it must not be credited to the four causes in
the brief**, and this section exists so that it cannot be after the fact. If
those rows move, this board cannot say which of the two sets did it; separating
them needs a run at `d5ad77b33b3` for those two targets, which is stated as
missing rather than papered over.

**PREDICTION, RECORDED BEFORE THE RUN, FOR THE `d5ad77b33b3`-BASELINED ROWS
(x86_64 and riscv64): they should reproduce the previous figures, and a null
result is the CORRECT result.** That is an
uncomfortable thing to write down, because a null result is also what a run
that silently did not happen produces — which is this project's dominant
failure mode and the reason the acceptance list says a null must be impossible
to confuse with a pass. What separates them here:

- the `.rc` stamp per target (a run FINISHED), asserted, never the
  `=== gcc Summary` marker;
- `mt-namediff.sh`'s **per-name and cardinality** arms against the previous
  board's preserved sums, which distinguish "the same 162,171 tests passed"
  from "no tests ran" — a run that did not happen has a cardinality of zero,
  not a matching one;
- the stock controls re-read at scoring time and reproducing their recorded
  figures exactly, so the *subtrahend* is known good.

If the board instead **moves**, the movement is not attributable to any of the
four causes named in the brief, and this section says so in advance so that a
post-hoc story cannot be fitted to it.

## 0b. THE BOARD COULD NOT START: `check-gcc` HAD BEEN DEAD IN THE COMMITTED
##     HARNESS SINCE THE COMMIT THAT FIXED `check-g++`

The first launch aborted at `GUARD 4`. `make check-gcc` returned **rc=0 in
twenty seconds** beside a **zero-byte `gcc.sum`**, with no
`MULTI-TARGET RUN: target = ...` banner. One line, in `mtcheck.sh`:

```sh
DEJAGNU='${DEJAGNU:-}' \
export MT_TARGET_NAME MT_TARGET_CONFIG MT_COMPILE_ONLY DEJAGNU;
```

`DEJAGNU` is set only on the **`g++`** arm. On the `gcc` arm nothing sets it,
so this exported the **empty string** — and DejaGnu tests
`[info exists env(DEJAGNU)]`, TRUE for an empty value, then sources a file
named `""`:

```
ERROR: global config file  not found.      <- the doubled space is the empty name
```

twelve times (once per parallel job), after which runtest writes a zero-byte
`gcc.sum`. `make check-gcc` still exits **0**, because the `check-%` recipe is
wrapped in `-(...)`.

`32dbd04da25` — *"`make check-g++` exited 0 having run nothing, twice, for two
reasons"* — **introduced for `gcc` the exact failure it fixed for `g++`.** One
name, two authorities, the authorities being the two values of
`MT_CHECK_TOOL`.

**The blast radius is bounded and it is zero.** Both prior boards predate the
breakage (`git merge-base --is-ancestor 32dbd04da25 <sha>` is FALSE for both
`e3fac057ae4` and `d5ad77b33b3`), so no recorded figure was taken through it.
No four-target board has been taken since it landed — which is exactly why
nothing scored it, and why the brief's "landed since, unmeasured" list did not
know the harness itself was one of the unmeasured things.

Fixed in `5850a790922`: the assignment **and** the `export` are both
conditional, so an unset `DEJAGNU` stays unset — the state DejaGnu's own
`info exists` arm is written for. Not a default value; the absence stays an
absence. Verified in both directions on the real 47-base build:

```
MT_RUNTESTFLAGS=dg.exp=pr100*.c    62 PASS / 0 FAIL, banner present
MT_RUNTESTFLAGS=dg.exp=pr9906*     0 results -> "REFUSED: a board of zeroes
                                    is not a clean sweep"
```

so the instrument is shown able to report a pass **and** a refusal, rather than
merely having stopped complaining.

## 0c. TWO INHERITED WORK ITEMS RE-VERIFIED AT TIP, AND ONE OF THEM IS
##     MIS-FILED IN THE DOCUMENT THAT HANDED IT OVER

Checked against the snapshot rather than copied forward, because a handover
item is a claim with an expiry date.

**`ASM_OUTPUT_MAX_SKIP_ALIGN` (A018 item 3) — LIVE, and the population is 7,
not 6.** `final.cc:2434` and `varasm.cc:2173,:2181` still spell
`#ifdef ASM_OUTPUT_MAX_SKIP_ALIGN` in shared TUs, so it is unconverted. The
definers are:

```
aarch64/aarch64-elf.h  arm/arm.h  rs6000/darwin.h  rs6000/sysv4.h
rx/rx.h  visium/visium.h                                   -- the recorded six
i386/i386.h:2262                                           -- AND i386
```

i386 being a definer is the whole mechanism and the handover list omits it:
the shared `#ifdef` is **true for all 47 back ends** because the primary
defines the name, so every target executes i386's body. That is the
`REGMODE_NATURAL_SIZE` / `EPILOGUE_USES` shape exactly — a `#ifdef` in shared
code that is not "off for the 40 that say nothing" but "on, with the primary's
answer, for everybody".

**`.machinemode zarch` (A018 item 4) — LIVE, but it is NOT "new, unfiled".**
The board that handed it over calls it *"new, unfiled"*. It is filed, in the
artefact itself. `s390.cc:8633` guards the emitter on
`#ifdef HAVE_AS_MACHINE_MACHINEMODE`, which `auto-host.h` does not define (0
occurrences — correct, `gcc/configure.ac` is host-and-build only). The probe
runs and the answer is deliberately withheld, with the reason written into
`specs-config` where the key would be:

```
# as_s390_machine_machinemode is PROBED AND NOT WRITTEN.  Its consumer is
# S390_USE_TARGET_ATTRIBUTE, which is tested with "#if" in nine places, one of
# them selecting SWITCHABLE_TARGET -- that one changes data layout and cannot
# become a run-time answer.  Making it a capability needs s390 to stop deciding
# SWITCHABLE_TARGET from an assembler probe, which is its own change.
#   as_s390_machine_machinemode 1
```

So it is a **blocked** item with a named blocker, not an unexamined one, and
the next agent should not spend a session rediscovering the blocker. The
underlying question — a capability that selects `SWITCHABLE_TARGET`, i.e. one
that cannot be a runtime read — is a design question of the kind §2b says to
report rather than resolve by whichever choice builds.

## PROVENANCE — quote this with any row

```
srcdir      /tmp/snap-agent-a992b7e5fa4ffaaa7
            git archive of e1f0cad1c2c, read-only, SNAP-SHA stamped
anchor      grep -c MULTI_TARGET gcc/Makefile.in = 52  (measured on this tree,
            not copied from the brief; UNCHANGED from the last two boards)
build       /tmp/b-a992b7e5fa4ffaaa7
            --enable-targets = the 47 triples of scratchpad/backends-47.txt
            make all-gcc rc=0;  `error:' 0;  multiple definition 0;
            undefined reference 0;  Killed 0;  cc1 links (231,133,040 bytes)
bars        x86_64 -O2 big.c   12369 bytes / md5 378fc33c1e70  == THE RECORDED BAR
              in=/tmp/snap-agent-a992b7e5fa4ffaaa7/scratchpad/big.c
            x86_64 -O2 -g big.c  rc=0, 78520 bytes, md5 d1e4d264c34e,
              debug sections present (non-vacuity arm OK)
              -- PATH-SENSITIVE, never quotable bare.  78520 bytes is identical
                 to the last two boards; only the md5 moved, because the build
                 dir lands in DW_AT_producer.
            specs-config, all four:  wc -l 232 / grep -c . 224
              -- THE LINE COUNT IS THE BAR.  The md5s are a function of the
                 probing toolchain's paths and are NOT quoted as one, per the
                 correction in PRINCIPLES near line 1016.  (They did in fact
                 reproduce the recorded values, the nix store paths still being
                 live; that is an observation, not a check that was applied.)
mode        MT_COMPILE_ONLY=1, make -j12, all-gcc only, no target libgcc
tools       real cross binutils + each target's own glibc headers (taa-tools.sh)
memcap      ulimit -v 8 GB on the shell launching runtest, read back and
            refused if it did not take
guards      sweep (arm 0e + arm 0f + SWEEP PASSES) once; then per target:
            specs-config exists, cc1 NAMES THE TARGET BACK, non-vacuity of
            -ftarget-config=, mt-specsread 4 arms (incl. its ARM3 negative
            control), GUARD 3c the target's OWN assembler, 12/12 site.exp
            attribution, multi-target.exp banner in the MERGED log, `.rc' stamp
rename      mt-rename-sweep.sh: 0 base-vs-base and 0 base-vs-shared strong-symbol
            collisions, run in the dev shell so `nm' exists
stock       all four controls re-read at scoring time and reproducing their
            recorded figures EXACTLY (163816/16223, 344463/20443, 270248/15904,
            130895/15627) -- verified, not quoted
artefacts   preserved per run in /tmp/board-agent-a992b7e5fa4ffaaa7/
```

**GUARD 3c reports the target's own assembler on all four** — `Advanced Micro
Devices X86-64`, `AArch64`, `RISC-V`, `IBM S/390`.

### LOAD — sampled for the whole run, not read once at the end

`loadsamples.txt`, every 5 minutes. The fifteen-minute column is the one the
~25 threshold applies to, and its maximum over the run is **24.21** (21:55).
So on the standing rule these rows are **NOT provisional** — but the peak was
close, it was during the x86_64 arm, and it is stated rather than rounded away.
KILLED is the contamination signal and it is 0 on x86_64.

The previous board had to decide this from a single reading taken hours after
the arms that mattered; that is why the sampler was added here.

## 1. THE BOARD — rows as they land

### x86_64-pc-linux-gnu — LANDED, `.rc` = 0, DEBT **67**, PREDICTION CONFIRMED

```
TARGET                    PASS    FAIL   XPASS   XFAIL   UNSUP   UNRES  ERRLIN
x86_64-pc-linux-gnu     162164   16295       3    1556    4451   13365      44
KILLED 0
```

```
                 multi-target        stock           DEBT      WAS
x86_64      PASS 162164 FAIL 16295   163816 / 16223    67       67
```

**The debt is 67 — the recorded figure, to the unit.** Guards: `.rc` stamp 0,
12/12 `site.exp` attribution, `multi-target.exp` banner present in the merged
log, `specs-config` 232/224, GUARD 3c reports *Advanced Micro Devices X86-64*,
mt-specsread 4 arms, KILLED 0.

**And the null is shown in the strong form, which is the whole point of §0's
advance prediction.** Against the `d5ad77b33b3` baseline
(`mt-namediff.sh`, keyed on `(name, occurrence)`):

```
joined rows: 197,827        unchanged: 197,827
REAL REGRESSIONS (PASS -> NOT PASS, by name):   0
REAL PROGRESS    (NOT PASS -> PASS, by name):   0
```

Every one of 197,827 shared rows is unchanged. **That is not what a run which
silently did not happen produces** — that produces a cardinality of zero, and
it is what the first launch of this board produced before GUARD 4 refused it
(§0b). The two are now distinguishable by evidence rather than by assertion.

The column deltas that look like movement are not:

```
PASS -7      FAIL +0      UNRESOLVED +6      ERROR +26 -> 44  (+18)
```

`mt-namediff.sh`'s cardinality arm attributes all of it: three pseudo-"test
files" (`tcl`, `testcase`, `xgcc:` — fragments of `ERROR:` lines, not test
files) produced **+24 results**, and the script says so itself:

> *24 of the new run's results come from tests that produced FEWER results
> before. Any column delta smaller than this is inside the noise this effect
> creates, in EITHER direction.*

−7 and +18 are both inside 24. `ERRLIN` is the raw `^ERROR:` count and **scales
with `-j`** (this board `-j12` → 44; the last `-j16` → 56), which the previous
board already recorded. So the x86_64 row is unchanged in substance and the
only thing that moved is a harness artefact whose own instrument named it.

### aarch64-unknown-linux-gnu — LANDED, `.rc` = 0, DEBT **443** (was 513)

```
TARGET                      PASS    FAIL   XPASS   XFAIL   UNSUP   UNRES  ERRLIN
aarch64-unknown-linux-gnu 341962   20688       2    1994    7009   17317      46
KILLED 0
```

```
                 multi-target        stock           DEBT      WAS
aarch64     PASS 341962 FAIL 20688   344463 / 20443   443      513
```

Guards: `.rc` 0, 12/12 `site.exp`, banner present, `specs-config` 232/224,
GUARD 3c reports **AArch64**, KILLED **0** (the previous board's 2
`virtual memory exhausted` are gone and stayed gone).

**Movement, by name, against `e3fac057ae4`:**

```
joined rows: 388,970      unchanged: 388,898
REAL PROGRESS    (NOT PASS -> PASS):  71    all in gcc.target/aarch64
REAL REGRESSIONS (PASS -> NOT PASS):   1
```

Cardinality moved by **3 results**, so 71 and 1 are an order of magnitude
outside the noise this effect creates — the arm that exists because a FAIL
column once rose +38,303 while 87,963 tests went `UNRESOLVED`→`PASS`.

**THE ONE REGRESSION, NAMED, because a net figure would bury it:**

```
FAIL  gcc.target/aarch64/ands_3.c
      scan-assembler ands\t(x|w)[0-9]+,[ \t]*(x|w)[0-9]+,[ \t]*255
```

A mask-immediate codegen difference. That shape is *consistent with*
`PROMOTE_MODE` changing whether a sub-word value is promoted before the `and`
— but that is a hypothesis, not a measurement, and it is labelled as one.

**AND THIS ROW'S MOVEMENT IS NOT ATTRIBUTABLE TO THE BRIEF'S FOUR CAUSES**,
exactly as §0a predicted in advance. aarch64's only available baseline is
`e3fac057ae4`, so the span also contains the auto-inc, alignment and
`PROMOTE_MODE` work — and aarch64 is a `PROMOTE_MODE` definer, while
`bd6f4dbe3ae` is titled *"the eight `USE_*` macros too, **or aarch64
regresses**"*. §0 showed the four named causes cannot reach this target except
through `FINAL_PRESCAN_INSN`, whose aarch64 body is a no-op without
`-mfix-cortex-a53-835769`. **This board cannot separate the two sets**;
separating them needs a run at `d5ad77b33b3` for aarch64, which is stated as
missing rather than papered over.

#### aarch64's ranked residual — and 58% of it is ONE macro, root-caused this session

```
DIRECTORY                                    DEBT  STOCK_FAIL  STOCK_PASS
gcc.target/aarch64/fmv_priority2.c             26           0          26
gcc.target/aarch64/sve                         17           5       91512
gcc.target/aarch64/mv-and-mvc3.c               15           0          15
gcc.target/aarch64/aapcs64                     12          44          42
gcc.target/aarch64/mv-symbols{7,8,9,10}.c      11 each      0          11
gcc.target/aarch64/mv-and-mvc{1,2,4}.c         10 each      0          10
gcc.target/aarch64/mv-1.c                       9           0           9
... 42 files in the mv*/fmv* family
```

**The `mv*`/`fmv*` family sums to exactly `256` of the 443 — 58%.** Stock fails
**zero** in every one of those files, so all 256 are genuine debt.

`A992B7E5FA4FFAAA7-FMV.md` root-causes the whole family to **one macro**,
found independently of this ranking and confirmed both-sided:

```
                                 SHARED  aarch64  i386  riscv  s390
TARGET_HAS_FMV_TARGET_ATTRIBUTE     1       0       1     0      1
```

`defaults.h:1001` floors it to `1`; `aarch64.h:1556`, `riscv.h:1349` and
`loongarch.h:1297` are the tree's only definers and all three say `0`. With the
macro `1`, `c-decl.cc:3457`'s FMV arm is skipped entirely, so the second
`target_version` definition is diagnosed as a plain redefinition — measured on
this board's own compiler:

```
error: redefinition of 'foo'          (aarch64, and riscv64)
```

against the control that x86_64's own `target_clones` still emits a resolver on
the same `cc1`.

**So aarch64's number-one item is closed as a diagnosis and open as a fix**,
and the fix shape is written down (a cdata field, with `defaults.h` supplying
upstream's own `1` to the silent back ends — a *supply-side* floor, which §2a
permits — and the three definers supplying their own `0`). The one trap
recorded with it: `tree.cc:15659`/`:15685` are `gcc_assert`s on this macro and
may be holding *because* the answer is wrong, the `function.cc:6766` /
`DELAY_SLOTS` shape.

**AND THE BOARD'S OWN LOG CLOSES THE CHAIN, which upgrades this from
"consistent with" to "measured".** The debt row itself carries no diagnostic —

```
FAIL: gcc.target/aarch64/mv-1.c (test for excess errors)
```

— which is exactly why `mt-debt-attribute.sh` exists and why
`grep <diagnostic>` over a debt list returns 0 on a target where that cause is
dominant. The `gcc.log` for the *same run* does carry it:

```
gcc.target/aarch64/mv-1.c:12:1: error: redefinition of 'foo'
gcc.target/aarch64/mv-1.c:18:1: error: redefinition of 'foo'
gcc.target/aarch64/mv-1.c:24:1: error: redefinition of 'foo'
```

byte-for-byte the diagnostic my hand reproducer produced before this row was
scored. So the chain is closed at every link: **board FAIL → run's own log →
standalone reproducer → the deciding line in `c-decl.cc` → the both-sided
header read** — rather than a plausible story fitted to a number.

`gcc.dg/lto`'s 53 — the item the last board flagged as identical on three
targets — is **gone from aarch64's top rows entirely**.

### riscv64-unknown-linux-gnu — LANDED, `.rc` = 0, DEBT **772**, PREDICTION CONFIRMED

```
TARGET                      PASS    FAIL   XPASS   XFAIL   UNSUP   UNRES  ERRLIN
riscv64-unknown-linux-gnu 268925   16762       4    1522   20625   13116      46
KILLED 10
```

```
                 multi-target        stock           DEBT      WAS
riscv64     PASS 268925 FAIL 16762   270248 / 15904   772      772
```

**The debt is 772 — the recorded figure, to the unit**, and §0a predicted NULL
for this row because its baseline `d5ad77b33b3` makes its span *exactly* the
brief's four causes. Shown in the strong form:

```
joined rows: 320,946      unchanged: 320,946
REAL REGRESSIONS:  0        REAL PROGRESS:  0
```

Every one of 320,946 shared rows unchanged. The `PASS -7 / ERROR +18` is the
same `tcl`/`testcase`/`xgcc:` `ERROR:`-line artefact as x86_64, and
`mt-namediff.sh` sizes it at **+27 results** — larger than either delta, in
either direction.

**KILLED IS 10, AND IT IS NOT THE SAME TEN AS BEFORE — the column's meaning
changed and quoting the old explanation would have been wrong.** Both previous
boards recorded riscv64 KILLED **20**, every one the assembler asked to
allocate `9223372036854841454` bytes (2^63 − 6162) on
`gcc.c-torture/execute/align-2.c` and `align-3.c`, flagged as *"a compiler
defect wearing the KILLED column's clothes"*.

In this run that message does not appear at all — `grep -o 'out of memory
allocating [0-9]*'` over the whole log returns **nothing** — while
`align-2.c`/`align-3.c` are still exercised (225 mentions). The ten that remain
are a different thing entirely:

```
virtual memory exhausted: Cannot allocate memory     x10
  gcc.target/riscv/pr117483.c
  gcc.target/riscv/pr117506.c
```

i.e. **the `ulimit -v` 8 GB cap firing**, on the two files the harness already
knows about — `mtcheck.sh`'s own comment records `pr117506.c` taking `cc1` to
20.8 GB RSS on a four-line testcase, which is why the cap exists.

So: the 2^63 assembler bug is **absent from this board**, and I am not claiming
it fixed — it is not in the debt either way, the sums are equal to the unit,
and the honest statement is *"that diagnostic did not occur in this run"*. The
brief's note that riscv64's ~20 are "known non-contaminating, present on both
sides" is **stale for this board**: the count is 10 and the cause is different.

### s390x-ibm-linux-gnu — LANDED, `.rc` = 0, DEBT **206** (was 207)

```
TARGET                PASS    FAIL   XPASS   XFAIL   UNSUP   UNRES  ERRLIN
s390x-ibm-linux-gnu 128882   15776       2    1228    7647   13013      46
KILLED 0
```

```
                 multi-target        stock           DEBT      WAS
s390x       PASS 128882 FAIL 15776   130895 / 15627   206      207
```

By name against `e3fac057ae4`: **166,546 joined rows, 166,545 unchanged, 1
`FAIL`→`PASS` (in `gcc.target/s390`), 0 regressions.** Cardinality noise 3.

**AND THIS IS A RESULT, NOT AN ABSENCE OF ONE.** s390x's span is the *same* as
aarch64's — it also holds the auto-inc, alignment and `PROMOTE_MODE` work that
no board had scored on this target. aarch64 moved **70**; s390x moved **1**.
The asymmetry matches the mechanism: `aarch64.h` **defines** `PROMOTE_MODE` and
gains its own answer, while `s390` defines none and merely stops receiving
i386's, which for this suite changes almost nothing.

So `A018835BBCFAD2E28-BOARD`'s handover item 6 — *"a suite run for aarch64 and
s390x on this tip"* — is **discharged for both**, and for s390x the answer is
"no measurable effect", which is worth as much as the 70.

## 2. THE RANKED RESIDUAL, PER TARGET

Ranked by DEBT with stock's figure beside every row: a directory where both
sides fail is not a work item; one where stock fails **zero** is.

### x86_64 — 67, unchanged, still 43 of it `_Float16`/HFmode

Unmoved to the unit. `A01E6C604F26604A7-BOARD` characterised it as `part-vect`
32 / `avx512fp16` 10 / any `hf` 36 — **43 of 67 matched, 24 matched by none** —
and nothing in this session's span touches it.

### aarch64 — 443, and **256 of it is one macro**

```
fmv_priority2.c 26 | sve 17 (stock fails 5 of 91,512) | mv-and-mvc3.c 15
aapcs64 12 (stock itself fails 44) | mv-symbols{7,8,9,10}.c 11 each | ...
    the mv*/fmv* family, 42 files:  256   <- TARGET_HAS_FMV_TARGET_ATTRIBUTE
```

### riscv64 — 772, and it is no longer the ICE-shaped residual it was

```
DIRECTORY                                  DEBT  STOCK_FAIL  STOCK_PASS
gcc.dg/Wstringop-overread.c                 129           0         148
gcc.target/riscv/rvv                        100         259      106729
c-c++-common/Wrestrict.c                     39           0         155
gcc.target/riscv/zilsd-align-word-4.c        21           0          21
gcc.dg/Wstringop-overflow-25.c               15           0          52
gcc.target/riscv/attribute-5.c               14           0          14
gcc.dg/torture/inline-mem-cpy-cmp-1.c        12           0          21
gcc.dg/torture/inline-mem-cpy-1.c            10           0          14
gcc.target/riscv/nozicond-3.c                 8           0          20
gcc.target/riscv/pr-crossing-jump-1.c         8           0          16
gcc.target/riscv/{mcpu-1,mcpu-2}.c            7 each      0           7
```

**`gcc.dg/params` is gone from the head entirely** (239 → 1 → absent) and with
it the `lra.cc:192` cluster that was this board's #2 item for three boards. The
head is now **`Wstringop-overread` / `Wrestrict` / `Wstringop-overflow` — 183
results across three files, stock failing zero** — a *diagnostics* family, a
different kind of item from anything previously ranked here, and shared with no
other target. `gcc.target/riscv/rvv`'s 100 sits against **259 stock failures
and 106,729 stock passes**, i.e. a small residue on a directory both sides find
hard.

**Two leads for this target come from this session's sweeps and are not in the
ranking**: `SHORT_IMMEDIATES_SIGN_EXTEND` (riscv 1, shared 0 — a `combine`
pessimisation, and riscv64's residual is exactly the "compiled and emitted
different code" shape) and `TARGET_CLONES_ATTR_SEPARATOR` (`'#'` vs `','`).
Neither is sized; both are in `A992B7E5FA4FFAAA7-FLOORSWEEP.md`.

### s390x — 206

```
DIRECTORY                                              DEBT  STOCK_FAIL  STOCK_PASS
gcc.target/s390/vector                                   19           2         540
gcc.target/s390/isfinite-isinf-isnormal-signbit-1.c      17           0          17
gcc.target/s390/signbit-3.c                              13           0          13
gcc.target/s390/isfinite-isinf-isnormal-signbit-{2,3}.c   9 each      0           9
gcc.target/s390/md                                        8           0         388
gcc.dg/debug/pr104337.c                                   7           0          10
gcc.target/s390/risbg-ll-1.c                              7           1          44
gcc.c-torture/compile/pr104327.c                          6           0           7
gcc.dg/lto/{20091027-1,20100603-1,-2,-3}                  6 each      0       12-18
```

Essentially identical to the last board's s390x ranking. The
signbit/isfinite family (**48 across four files, stock passes all**) remains
the one coherent, self-contained work item on this target.

### `gcc.dg/lto` — STILL 53 ON THREE TARGETS, AND MY FIRST READING OF IT WAS WRONG

I wrote, from the depth-3 rankings, that *"`gcc.dg/lto` is now s390x's alone …
absent from the other two heads … whatever it was has largely closed"*. **That
is false.** Measured at depth 2 (`/tmp/ltocheck-a992.sh`):

```
aarch64-unknown-linux-gnu    gcc.dg/lto debt 53
riscv64-unknown-linux-gnu    gcc.dg/lto debt 53
s390x-ibm-linux-gnu          gcc.dg/lto debt 53
x86_64-pc-linux-gnu          gcc.dg/lto debt  0
```

**Unchanged from the last board, to the unit, on all four.** The previous
board's observation stands exactly as written: *"the same count on three
targets is not three bugs"*, and x86_64's zero is still the clue.

The error is worth recording because it is a *reading* error with a clean
mechanism, not a measurement error. At **depth 3** the directory splits into
`gcc.dg/lto/20091027-1`, `/20100603-1`, `/20100603-2` … each worth ~6, so no
single row shows anything like 53 and the family is invisible in a top-14
listing. At **depth 2** it is one row of 53. `mt-debt-rank.sh`'s header says
the depth is a parameter *"for that reason"* — I used the depth tuned for
aarch64's `gcc.target/aarch64/*` subdirectories and read a different question's
answer off it.

Generalises to: **a ranking is an answer at one granularity, and "absent from
the head" is not "absent".** Re-run at the depth the family actually lives at
before saying something has gone.

## 3. WHAT THIS BOARD CANNOT SEE — the most important section

Three of this session's most serious findings are **absent from every number
above**, and all three were found by compiling four small programs and diffing
against the stock compiler:

| defect | target | why the board is blind to it |
|---|---|---|
| `STACK_POINTER_OFFSET` 0 vs **160** — outgoing stack args land in the callee's register save area | s390x | compile-only; the wrong code assembles cleanly into a correct-machine ELF object |
| `TRAMPOLINE_SECTION` ignored — the trampoline is emitted into **`.rodata`** | aarch64 | nested functions are rare in the suite, and it assembles |
| `EH_RETURN_HANDLER_RTX` NULL — `__builtin_eh_return` **errors** | aarch64, s390x | few tests use the builtin |

`s390x`'s measured debt is **206** and its ABI is broken for every function
taking more than five integer arguments. PRINCIPLES already states the general
form for riscv64 emitting 32-bit code while passing "assembles, right ELF
machine"; this is the same lesson arriving three more times in one session.

**So the four numbers above are a LOWER BOUND on what is wrong, and a
compile-only board is a weak instrument for anything wrong about the ABI.**
That is the single most useful thing this board says, and it is not a number.
