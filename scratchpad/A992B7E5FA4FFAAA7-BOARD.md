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

**PREDICTION, RECORDED BEFORE THE RUN: this board should reproduce the
previous figures, and a null result is the CORRECT result.** That is an
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

Provenance, guards, the board, the debt and the ranked residual follow as they
land.
