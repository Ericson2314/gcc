# The `defaults.h` FLOOR class, swept — 196 candidates, 106/90 split, and two
# live leaks found on targets this board scores

`scratchpad/agent-a992b7e5fa4ffaaa7-floorsweep.sh`, run over
`/tmp/snap-agent-a992b7e5fa4ffaaa7` (`e1f0cad1c2c`, anchor 52).

## The generator

`TARGET_HAS_FMV_TARGET_ATTRIBUTE` is not a one-off. Its class is: **a
`#ifndef` floor in `defaults.h` whose name some back end `#define`s.** That is
closed and enumerable:

```
defaults.h floors:                                219
names #defined anywhere under config/:         13,927
THE CLASS (floored AND defined by a back end):    196
  FLOOR-DEAD   (i386 among the definers)          106
  FLOOR-FIRES  (i386 silent)                       90
```

The two halves are **different bugs needing different evidence**:

| primary | the `#ifndef` | who reads the wrong value |
|---|---|---|
| defines the name | **dead** | every back end that disagrees with i386 — `EPILOGUE_USES`, `REGMODE_NATURAL_SIZE` |
| defines nothing | **fires** | every back end that disagrees with **the floor** — `TARGET_HAS_FMV_TARGET_ATTRIBUTE` |

The script classifies `EPILOGUE_USES` as `FLOOR-DEAD` and
`TARGET_HAS_FMV_TARGET_ATTRIBUTE` as `FLOOR-FIRES`, i.e. it reproduces the two
recorded cases in the right buckets, and it **refuses to run** if the known
member is absent from the class — a clean result there would be a false green,
not a clean tree.

## Membership is a CANDIDATE, not a verdict — and most heads are already fixed

The `-DIN_GCC` both-sided header read is the discriminator. Of the ten largest
`FLOOR-FIRES` candidates, **five are already converted** and the floor is
inert:

```
NAME                        SHARED                 aarch64   riscv   s390
WORD_REGISTER_OPERATIONS    (targetm_cdata.…)      same      same    same   CONVERTED
SHIFT_COUNT_TRUNCATED       (targetm_cdata.…)      same      same    same   CONVERTED
STORE_FLAG_VALUE            (targetm_cdata.…)      same      same    same   CONVERTED
BITS_PER_WORD               (targetm_cdata.…)      same      same    same   CONVERTED
CASE_VECTOR_PC_RELATIVE     (mt_case_vector_…)     same      same    same   CONVERTED
LOAD_EXTEND_OP              (undef)                (undef)   …       …      not via tm.h
ARG_POINTER_CFA_OFFSET      (undef)                (undef)   …       …      not via tm.h
```

That is the sweep working as designed: over-broad, so it can only add to a
review queue, never authorise anything.

## TWO ARE LIVE, AND BOTH ARE ON THIS BOARD

### `TRAMPOLINE_ALIGNMENT` — 36 definers, i386 silent

```
SHARED   FUNCTION_ALIGNMENT (FUNCTION_BOUNDARY)     <- i386's, via the floor
aarch64  64                     (aarch64.h:1482)
riscv    POINTER_SIZE
s390     BITS_PER_WORD          (s390.h:727)
```

Three of the four scored targets disagree with the value they get. Bounded by
how much trampoline code the suite exercises, which is small — recorded for
completeness and correctness, not as a debt item.

### `STACK_POINTER_OFFSET` — s390x gets 0 where it needs 160, and it is a STACK LAYOUT OFFSET

```
SHARED   0        <- the floor
s390     160      (s390.h:569)
aarch64  0        riscv 0        i386 0      <- correct for them
```

This is the serious one. The consumers are shared and they are load-bearing:

```
calls.cc:4576                      plus_constant (…, STACK_POINTER_OFFSET)
function.cc:1964    out_arg_offset = STACK_POINTER_OFFSET;
function.cc:2725    && known_eq (STACK_POINTER_OFFSET, 0)
function.cc:4198    poly_int64 sp_offset = STACK_POINTER_OFFSET;
```

160 is s390's register save area — the offset from `%r15` at which outgoing
arguments begin. Every shared consumer computes it as **0** for s390x, so
`out_arg_offset` and the `sp_offset` in `function.cc` are short by 160 bytes.
`function.cc:2725`'s `known_eq (STACK_POINTER_OFFSET, 0)` is a guard whose
comment says *"Don't make any assumptions if `STACK_POINTER_OFFSET` is in
use"* — and it is currently **true for s390x**, i.e. the assumption is being
made precisely where the comment says not to. Same shape as
`function.cc:6766`'s `gcc_assert (!DELAY_SLOTS)` holding only because the
answer was wrong.

#### CONFIRMED WRONG CODE, both-sided against genuine upstream stock

Not inferred from the header read.
`scratchpad/agent-a992b7e5fa4ffaaa7-spo.sh` compiles one ten-argument function
with **the board's compiler** and with **the stock s390x compiler the board's
debt is scored against**:

```
-- outgoing-argument stores, STOCK (correct):
   stg %r4,160(%r15)   stg %r3,168   stg %r2,176   stg %r0,184   stg %r1,192
-- outgoing-argument stores, MULTI-TARGET:
   stg %r4,0(%r15)     stg %r3,8     stg %r2,16    stg %r0,24    stg %r1,32
```

**Every other instruction in the function is identical.** The entire diff is
those five offsets, each exactly **160 low** — `STACK_POINTER_OFFSET` to the
byte.

The consequence is not cosmetic. 160 is the s390x ELF register save area and
the callee's own prologue is `stmg %r6,%r15,48(%r15)`, so **arguments 6..10 are
written into the region the callee immediately overwrites with its saved
registers**. Any s390x function taking more than five integer arguments
receives garbage.

**THE BOARD CANNOT SEE THIS, WHICH IS THE PART TO CARRY.** Every arm is
`MT_COMPILE_ONLY=1`, so the bad code compiles, assembles with the real
`s390x-ibm-linux-gnu-as`, and yields a well-formed `ELF64 / IBM S/390` object
`readelf` is happy with. s390x's measured debt is **207** and this is not in
it. Same lesson as riscv64 emitting 32-bit code while passing
"assembles, right ELF machine": **a compile-only board is a lower bound, and a
weak one for anything wrong about the ABI.**

**And there is a SECOND authority for this floor.** It is not only in
`defaults.h`:

```c
/* function.cc:1396 */
#ifndef STACK_POINTER_OFFSET
#define STACK_POINTER_OFFSET	0
#endif
```

#### THE FIX IS A CALL, NOT A `NUM` cdata SLOT — the obvious shape is wrong

Worth settling before anyone writes it, because `target-cdata.h` is full of
`NUM (unsigned short, …)` rows and this looks exactly like one. The 20 definers:

```
constants          s390 160, s390/tpf 448, ia64 16, c6x 4, mn10300 4, avr 1,
                   or1k 0, gcn 0, nds32 0, m32r 0, fr30 0, frv 0
derived-constant   sparc  (FIRST_PARM_OFFSET(0) + SPARC_STACK_BIAS)
                   lm32   (UNITS_PER_WORD)
NOT INVARIANT      epiphany  epiphany_stack_offset      <- a VARIABLE
                   rs6000    RS6000_SAVE_AREA           <- ABI-flag dependent
                   microblaze FIRST_PARM_OFFSET(FNDECL)
                   pa        a multi-line conditional
```

A `NUM` slot caches its value when the base is selected. For epiphany, rs6000,
microblaze and pa that would **freeze a value that is currently correct and
dynamic** — which is precisely the argument `target-cdata.h` already makes, in
its own words, for keeping `TARGET_VTABLE_ENTRY_ALIGN` out:

> a slot here would FREEZE a value that is currently correct and dynamic for 44
> back ends, in order to fix 3. That is a regression wearing a fix's clothes.

So the shape is the **call** family — `mt_stack_pointer_offset ()`, as
`POINTER_SIZE`, `MOVE_MAX_PIECES` and `mt_case_vector_pc_relative` already are
— and the fix must remove `function.cc:1396`'s local floor in the same change
or four of the five uses keep reading 0.

**Not implemented here.** It is a design choice between two existing
mechanisms with a live counterexample on each side, the board was mid-run, and
§2b's test applies: getting it wrong reintroduces the class this project
exists to remove, on four back ends, silently.

a shared TU re-flooring the same name locally. One name, two floors, no
diagnostic — so converting `defaults.h` alone would leave `function.cc`'s four
uses still reading 0. Both must go together, and a fix that moves the s390x
number by zero has refuted its own story.

### `EH_RETURN_HANDLER_RTX` — `__builtin_eh_return` is BROKEN on two of the four scored targets

The sharpest of the three, because it has a **loud** half that can be measured
in one command and a **silent** half of the `EPILOGUE_USES` kind.

```
NAME                    SHARED  aarch64                       i386  riscv  s390
EH_RETURN_HANDLER_RTX   NULL    gen_rtx_REG (Pmode, R6_REGNUM) NULL  NULL   gen_rtx_MEM (Pmode, …)
                                (aarch64.h:875)                             (s390.h)
```

`defaults.h:1432` floors it to `NULL`; i386 is silent, so the floor fires and
every shared consumer sees `NULL`.

**Measured, both-sided, with the board's own `cc1`** (`/tmp/ehrun-a992.sh`, on
`void f (long o, void *h) { __builtin_eh_return (o, h); }`):

```
aarch64-unknown-linux-gnu    rc=1  error: '__builtin_eh_return' not supported on this target
s390x-ibm-linux-gnu          rc=1  error: '__builtin_eh_return' not supported on this target
x86_64-pc-linux-gnu          rc=0
riscv64-unknown-linux-gnu    rc=0
```

Upstream all four support it. The two that fail are exactly the two whose own
header defines a non-`NULL` handler RTX.

The path is `except.cc:2320`:

```c
  if (targetm.have_eh_return ())
    emit_insn (targetm.gen_eh_return (crtl->eh.ehr_handler));
  else
    {
      if (rtx handler = EH_RETURN_HANDLER_RTX)      /* NULL, from the floor */
	emit_move_insn (handler, crtl->eh.ehr_handler);
      else
	error ("%<__builtin_eh_return%> not supported on this target");
    }
```

**And the two failures are ONE defect, not two — which took checking, because
s390 *does* have an `eh_return` pattern.** `s390.md:11103` conditions it on
`TARGET_TPF`, false for `s390x-linux`, so `have_eh_return ()` is correctly
false and s390 falls through to the same floor. aarch64 has no `eh_return`
pattern at all (`grep -c 'define_expand "eh_return"' aarch64.md` = **0**).
x86_64 passes because i386's pattern is unconditional — i.e. the primary takes
a path that never reads the macro, which is why this survived.

**The silent half is `df-scan.cc:3738`**, and it is `EPILOGUE_USES` again in a
new place:

```c
  if ((!targetm.have_epilogue () || ! epilogue_completed)
      && crtl->calls_eh_return)
    {
      rtx tmp = EH_RETURN_HANDLER_RTX;
      if (tmp && REG_P (tmp))
	df_mark_reg (tmp, exit_block_uses);
    }
```

With `NULL`, aarch64's `R6_REGNUM` is never added to the exit block's use set,
so dataflow may conclude the instruction writing the handler is dead. That is
precisely the mechanism by which `EPILOGUE_USES` emptied SME functions to a
bare `ret` — same file, same set, adjacent lines. It cannot be observed today
because the loud half stops compilation first; **fixing the loud half without
the silent one would convert a diagnostic into wrong code**, which is the
half-fix shape §4 warns about.

### `SHORT_IMMEDIATES_SIGN_EXTEND` — riscv64 reads 0 and needs 1, in `combine`

```
SHARED 0    aarch64 0    i386 0    riscv 1    s390 0
```

`defaults.h:1393` floors it to 0; only riscv dissents among the four.
Consumers are all shared and all in the value-range machinery:

```
combine.cc:1606      combine.cc:10301      rtlanal.cc:4837
```

— `nonzero_bits` / `num_sign_bit_copies`. Reading 0 where the target sign-
extends short immediates makes those analyses **over-broad**: correct but
pessimistic, so combine declines simplifications it could make. **The
symptom is different-but-valid code, not a diagnostic**, which is precisely
the shape of riscv64's residual: `A018835BBCFAD2E28-BOARD` records 384 left in
`gcc.target/riscv`, three quarters `scan-assembler*`, described as *"the
compiler COMPILED and EMITTED, and emitted different code than stock"*.

This is a **lead, not an attribution.** Nothing here says how many of the 384
it is worth; sizing it means fixing it and re-running, exactly as
`mt-debt-attribute.sh`'s header says there is no lower bound available from a
`.sum`.

### `TARGET_MEM_CONSTRAINT` — s390x's memory constraint letter is `'e'`, shared says `'m'`

```
SHARED 'm'    aarch64 'm'    i386 'm'    riscv 'm'    s390 'e'
```

Shared consumers are `reload.cc` and `recog.h`. (`genoutput.cc` and
`genpreds.cc` also read it, but those are **generators invoked per base** with
`-A<base>`, so they are likely getting s390's own value — which would make this
a *disagreement between the generated tables and the shared consumers*, a worse
shape than a plain leak and one that needs its own check before anything is
claimed.)

Flagged, not diagnosed. It is on the board's s390x row and it is the kind of
divergence that would show as constraint-matching differences rather than as a
diagnostic.

## What this hands over

**THE `FLOOR-FIRES` LIST IS NOW READ IN FULL: 90 of 90.** Seven confirmed live
leaks and one flagged, every one on a target this board scores:

```
name                             wrong for              what it is
EH_RETURN_HANDLER_RTX            aarch64 s390x   LOUD error + silent df-scan
STACK_POINTER_OFFSET             s390x           stack layout, 0 vs 160
TARGET_HAS_FMV_TARGET_ATTRIBUTE  aarch64 riscv64 256 results on aarch64
TRAMPOLINE_ALIGNMENT             aarch64 riscv64 s390x
SHORT_IMMEDIATES_SIGN_EXTEND     riscv64         combine pessimisation
TARGET_CLONES_ATTR_SEPARATOR     riscv64         ',' vs '#'  -- the FMV family again
INITIAL_FRAME_ADDRESS_RTX        s390x           NULL vs plus_constant(...)
TARGET_MEM_CONSTRAINT            s390x           FLAGGED, not diagnosed
```

Two additions from the tail of the list:

- **`TARGET_CLONES_ATTR_SEPARATOR`** — shared `','`, riscv `'#'`. It is the
  separator for `target_clones` attribute components, i.e. **the same family
  as the FMV macro and the same target**, so riscv64 both mis-selects the FMV
  attribute *and* mis-parses the clone list. They should be fixed together;
  fixing one alone would move riscv64's FMV tests from one wrong answer to
  another.
- **`INITIAL_FRAME_ADDRESS_RTX`** — shared `NULL`, s390
  `(plus_constant (Pmode, …))`. One shared consumer, `builtins.cc:819`, which
  is `__builtin_frame_address`. Same floor-returns-NULL shape as
  `EH_RETURN_HANDLER_RTX`.

**Known false positive, stated so the count is honest:** `GCC_DEFAULTS_H` is in
the class because it is the file's own **include guard**, not a target macro.
`ARG_POINTER_CFA_OFFSET` reads `(undef)` through `tm.h` on all five arms, so
the sweep cannot decide it from headers — PRINCIPLES records it as *"correct
only because `FIRST_PARM_OFFSET` is 0 in both bases"*, which is a live
question this instrument does **not** answer. Both are listed rather than
quietly dropped.

Per-target totals from this sweep alone:

```
s390x    5   EH_RETURN_HANDLER_RTX, STACK_POINTER_OFFSET, TRAMPOLINE_ALIGNMENT,
             INITIAL_FRAME_ADDRESS_RTX, TARGET_MEM_CONSTRAINT (flagged)
riscv64  4   TARGET_HAS_FMV_TARGET_ATTRIBUTE, TARGET_CLONES_ATTR_SEPARATOR,
             SHORT_IMMEDIATES_SIGN_EXTEND, TRAMPOLINE_ALIGNMENT
aarch64  3   EH_RETURN_HANDLER_RTX, TARGET_HAS_FMV_TARGET_ATTRIBUTE,
             TRAMPOLINE_ALIGNMENT
x86_64   0   -- it is the primary; the floor is i386's answer by construction
```

**x86_64's zero is the control and it is not a compliment to that target.** It
is the reason every one of these survived: the primary agrees with the floor
in all seven cases, so no amount of testing on x86_64 could have found any of
them.

## THE `FLOOR-DEAD` HALF, SAMPLED — AND A CANDIDATE REFUTED BY MEASUREMENT

The 106-row half is **not** read in full. Its eighteen largest rows were, and
they are almost all already cdata (`PTRDIFF_TYPE`, `SIZE_TYPE`, `WCHAR_TYPE`,
`ASM_COMMENT_START`, `LONG_TYPE_SIZE`, `ACCUMULATE_OUTGOING_ARGS`, …).

One row diverged and **it is not a leak**, which is worth more than another
finding because it fixes the method:

```
DEFAULT_PCC_STRUCT_RETURN    SHARED 1    aarch64 0    i386 1    riscv 1    s390 1
```

A header divergence on a macro consumed by `function.cc:2122`:

```c
  if (flag_pcc_struct_return && AGGREGATE_TYPE_P (type))
    return true;                       /* BEFORE targetm.calls.return_in_memory */
```

which would force every aarch64 aggregate into memory — an ABI break. Measured
instead of believed, `struct s { int a, b; } f (int)` at `-O2`:

```
f:  mov w2,0 / add w1,w0,1 / bfi x2,x0,0,32 / bfi x2,x1,32,32 / mov x0,x2 / ret
```

Returned in `x0`. **No leak.** The reason is that this macro's only consumer is
`common.opt:2594`'s `Init(DEFAULT_PCC_STRUCT_RETURN)`, and the options
initialiser is generated **per base** (`mt-<base>/options-init.o`), so the
runtime `flag_pcc_struct_return` is already aarch64's own 0. The shared
*header* value is read by nobody.

**So the rule the sweep needs, and which the FMV write-up did not state: a
header divergence is a leak only if a SHARED consumer reads the MACRO.** A
macro whose only consumer is `common.opt` reaches the compiler through per-base
generated code and is already correct. Check the consumer's population before
believing a divergence, and prefer an end-to-end observable to a header read —
the header read produces candidates, the compiler produces verdicts.

That test also states its own limit: it shows the flag is right *today, at
`-O2`, for this type*. It is not a proof the macro is unreachable from any
shared TU.

The 106-row `FLOOR-DEAD` list is the already-understood variant and is not
re-derived here.

**Do not run the both-sided read without `-DIN_GCC`.** The back-end chain lives
inside `#ifdef IN_GCC`, so omitting it makes every arm read the floor and every
row look converted — it refutes all findings at once, and it looks like a clean
tree. My first probe did exactly this.
