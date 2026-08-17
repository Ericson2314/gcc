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

**And there is a SECOND authority for this floor.** It is not only in
`defaults.h`:

```c
/* function.cc:1396 */
#ifndef STACK_POINTER_OFFSET
#define STACK_POINTER_OFFSET	0
#endif
```

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

The 90-row `FLOOR-FIRES` list is a ranked queue with a cheap per-row
discriminator (the `-DIN_GCC` both-sided read). **42 rows were read here and 5
are live leaks**, every one on a target this board scores:

```
name                            wrong for      kind
EH_RETURN_HANDLER_RTX           aarch64 s390x  LOUD (error) + silent df-scan
STACK_POINTER_OFFSET            s390x          stack layout, 0 vs 160
TARGET_HAS_FMV_TARGET_ATTRIBUTE aarch64 riscv  256 results on aarch64
TRAMPOLINE_ALIGNMENT            aarch64 riscv s390x
SHORT_IMMEDIATES_SIGN_EXTEND    riscv64        combine pessimisation
TARGET_MEM_CONSTRAINT           s390x          flagged, not diagnosed
```

**48 rows are unread.** A hit rate of 5 in 42 on the read half is not a
prediction about the unread half, and is not offered as one.

The 106-row `FLOOR-DEAD` list is the already-understood variant and is not
re-derived here.

**Do not run the both-sided read without `-DIN_GCC`.** The back-end chain lives
inside `#ifdef IN_GCC`, so omitting it makes every arm read the floor and every
row look converted — it refutes all findings at once, and it looks like a clean
tree. My first probe did exactly this.
