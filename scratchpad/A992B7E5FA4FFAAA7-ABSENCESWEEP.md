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
