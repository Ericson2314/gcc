# The LEAKED-ABSENCE class, swept for the first time — 159 candidates

`scratchpad/agent-a992b7e5fa4ffaaa7-absencesweep.sh` over
`/tmp/snap-agent-a992b7e5fa4ffaaa7` (`e1f0cad1c2c`, anchor 52).

## Why this class needed its own instrument

Three enumerable classes, disjoint by construction, different fixes:

| class | shape | swept by |
|---|---|---|
| floor-dead | `#ifndef` floor in `defaults.h`, primary **defines** the name | `floorsweep.sh` |
| floor-fires | `#ifndef` floor, primary silent, a back end dissents | `floorsweep.sh` |
| **leaked absence** | **bare `#ifdef` in a shared TU, primary silent** | **this** |

In the third, **nothing leaks a value** — the conditional is simply false for
all 47, so the guarded code runs for nobody, including the back ends that asked
for it. A dump of the running `cc1` shows nothing wrong, because what is
missing is a call that never happens.

Its four known members were all found **by accident**:
`FINAL_PRESCAN_INSN`, `DELAY_SLOTS`, `GO_IF_LEGITIMATE_ADDRESS` by hand in
`d1ae5fb5969`, and `TRAMPOLINE_SECTION` in this session by compiling a nested
function and diffing against stock. Four accidents is a reason to build the
sweep, not a reason to keep looking by hand.

```
back-end names the primary does NOT define: 10,273
names a shared TU tests with #ifdef:           535
THE LEAKED-ABSENCE CLASS:                      159
```

**The control fires and the script refuses without it**: it re-finds
`FINAL_PRESCAN_INSN`, `GO_IF_LEGITIMATE_ADDRESS` and `TRAMPOLINE_SECTION`, and
it *expects* `DELAY_SLOTS` to be absent — that one is a 0/1 **value** tested
with `if`, not `#ifdef`, which is the detection gap `d1ae5fb5969` records. The
script names that exception explicitly and exits 9 if anything else is
missing, so a short clean list cannot be mistaken for a clean tree.

## Reading the output: the `target-*.h` column is the fastest discriminator

A row whose "shared TUs" column names `target-cdata-opt.h`, `target-asm-ops.h`,
`target-def.h` or `target-regs.cc` is very likely **already converted** — the
`#ifdef` has moved into the per-base conversion file, where it is a fact about
that back end rather than about the primary. `CALL_REALLY_USED_REGISTERS`,
`CTORS_SECTION_ASM_OP` and `STATIC_CHAIN_REGNUM` all read that way.

The candidates that matter are those tested **only** from genuinely shared code:

```
NAME                          DEFINERS  SHARED TUs THAT TEST IT
CLASS_MAX_NREGS                  25     targhooks.cc
FUNCTION_VALUE_REGNO_P           19     targhooks.cc
PRINT_OPERAND_ADDRESS            17     targhooks.cc
REGISTER_PREFIX                  16     final.cc varasm.cc
PRINT_OPERAND                    16     targhooks.cc
LIBCALL_VALUE                    15     targhooks.cc
ADJUST_INSN_LENGTH               13     final.cc
ADDR_VEC_ALIGN                   12     final.cc
PROFILE_BEFORE_PROLOGUE          12     targhooks.cc
PRINT_OPERAND_PUNCT_VALID_P      11     targhooks.cc
PREFERRED_RELOAD_CLASS           11     targhooks.cc
CASE_VECTOR_SHORTEN_MODE          7     final.cc
BLOCK_REG_PADDING                 9     calls.cc expr.cc function.cc
```

Two corroborations worth noting, because they are independent of this sweep:

- **`CLASS_MAX_NREGS` (25)** is on `A018835BBCFAD2E28-BOARD`'s own leak-census
  head list, arrived at by a different route.
- **`LIBCALL_VALUE`** is PRINCIPLES' recorded *unsupplied hook* — *"every
  target got i386's registers"* — so the sweep re-finds a known defect it was
  not told about, which is the property `mta7-targhook-matrix.sh` failed.

**`BLOCK_REG_PADDING` is the one I would look at first** despite its middling
definer count: it is tested from `calls.cc`, `expr.cc` **and** `function.cc`,
i.e. all three of argument setup, argument expansion and prologue, and it
decides which end of a register a sub-word argument sits in. That is the same
part of the ABI as the s390x `STACK_POINTER_OFFSET` bug, and big-endian and
sub-word-argument targets are where it would show — none of which this board
scores.

## The limits of this instrument, stated

- **Candidates, not verdicts.** A name may be legitimately unused on every
  configured back end, already converted, or guarded for a good reason. The
  discriminator is the same one that worked three times today: compile a
  program that reaches the guarded code and diff against the stock compiler for
  that target.
- **It cannot see the `DELAY_SLOTS` shape at all** — a 0/1 valued macro tested
  with a runtime `if`. That is a fourth class and it needs a fourth sweep,
  keyed on `defaults.h` floors whose consumers are `if (NAME)`. It is named
  here rather than left implicit, because the sweep's own control documents
  that it is blind to it.
- It looks at `gcc/*.cc`, `gcc/*.h`, `gcc/c/` and `gcc/c-family/` only. The C++
  and other front ends are not swept.

---

# THE FOURTH CLASS, AND IT NEEDED A FOURTH INSTRUMENT

`scratchpad/agent-a992b7e5fa4ffaaa7-genhdrsweep.sh`.

Both sweeps above enumerate definers by grepping **`gcc/config/`**, i.e. the
source tree. A whole population is invisible to that: names that exist only in
**generated per-base headers**, where the build root's shared copy is the
**primary's**. `genattr-common` writes `DELAY_SLOTS` and `INSN_SCHEDULING`;
`genconfig` writes `HAVE_*` and the `MAX_*` bounds; `genmodes` writes
`insn-modes.h`; `opth-gen.awk` writes `options.h`. PRINCIPLES records the
`insn-modes.h` and `options.h` instances separately, each measured by hand.

The sweep diffs the shared copy against each per-base copy **body by body**,
not name by name — the interesting case is a name in *both* with *different*
bodies (`DELAY_SLOTS 0` vs `DELAY_SLOTS 1`), which a name-set diff scores as
identical. That is exactly how these survived.

Control fires:

```
$ genhdrsweep.sh <builddir> mips sh sparc aarch64
== insn-attr-common.h
   mips    DELAY_SLOTS  shared[0]  mips[1]
   sh      DELAY_SLOTS  shared[0]  sh[1]
   sparc   DELAY_SLOTS  shared[0]  sparc[1]
```

## What it found: `HAVE_conditional_execution`, five back ends

```
/* targhooks.cc:2039 -- SHARED */
bool default_have_conditional_execution (void)
{
  return HAVE_conditional_execution;      /* the shared copy: i386's 0 */
}
```

```
insn-config-<base>.h says 1 for:   c6x  arc  frv  ia64  nvptx  arm
back ends overriding the hook:     arm  (arm.cc:652) -- and ONLY arm
```

So **c6x, arc, frv, ia64 and nvptx** take the default hook, which returns
i386's `0`, and the middle end believes they have no conditional execution.
`ifcvt` therefore never forms predicated code on five back ends that support
it. arm escapes only because it supplies its own hook — which is also why this
was never noticed: the one back end everybody thinks of when they hear
"conditional execution" is the one back end that is fine.

This is PRINCIPLES' **unsupplied hook** disguise (`TARGET_LIBCALL_VALUE` —
*"every target got i386's registers"*), reached mechanically rather than by
somebody happening to look.

**None of the five is on this board**, so the four-target debt cannot see it —
the third finding today in that category.

## What it correctly did NOT find

`HAVE_lo_sum` diverges (shared 0, aarch64 1) and is **not** a leak: its only
consumers are `target-cumargs.cc`, `multi-target-macros.h` and
`target-insn.h`, all per-base conversion files. `insn-flags.h` diverges by
**403 names** for mips and is the **negative control** — that header is
per-base by design and PRINCIPLES already names it as such
(*"insn-flags-<base>.h 45 files, 45 distinct bodies"*).

And `genconfig.cc` turns out to have handled its own family carefully and to
document it: the six `MAX_`/`NUM_` bounds are **unioned** (a maximum is safe to
raise), and the two booleans that reach a shared `#if` line (`HAVE_rotate`,
`HAVE_rotatert`) are **checked for unanimity rather than averaged**, with the
comment explaining that OR-ing booleans would tell the middle end a pattern
exists when the selected back end has none. `HAVE_conditional_execution` is
the one that escaped, because it reaches shared code through a **function
body** rather than a `#if` line — and a unanimity check keyed on preprocessor
use cannot see that.

**That is the transferable point: `genconfig`'s own safety analysis was
correct and its population was one narrower than the code.**
