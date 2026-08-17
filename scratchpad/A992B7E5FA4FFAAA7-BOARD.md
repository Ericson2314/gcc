# THE FOUR-TARGET BOARD AT `e1f0cad1c2c`, 47 BASES

Status: **IN PROGRESS.** Sections filled as arms land, per the standing rule
that a partial board with `.rc`-stamped rows beats a complete one that never
gets reported.

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

Provenance, guards, the board, the debt and the ranked residual follow as they
land.
