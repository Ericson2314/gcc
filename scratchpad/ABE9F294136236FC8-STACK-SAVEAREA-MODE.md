# `extract_insn, at recog.cc:2892` on six back ends is ONE macro: `STACK_SAVEAREA_MODE`

Task: take the `extract_insn` rows on the six back ends carrying them to zero,
or explain the residual per back end. `A7EE6CA7C923E4A58-BOARD.md` §4.

## THE ANSWER IN ONE LINE

`config/i386/i386.h:2011` defines `STACK_SAVEAREA_MODE`, so all 47 back ends
save the stack pointer for a nonlocal goto into an **x86-64-sized `TImode`
slot**, and `emit_stack_restore` then builds a `set` whose two halves have
different modes -- malformed RTL that no back end's `recog` can match.

**69 of the 71 rows.** The remaining 2 are avr's `string-large-1.c` and are a
different cause; see the last section.

## PROVENANCE

```
board artefacts  /tmp/b-a7ee6ca7c923e4a58/gcc/testsuite.<triple>/gcc/gcc.sum
                 the 47-base build the board was taken on, still on disk,
                 read-only; `.rc'-stamped, 10 targets
this worktree    agent-abe9f294136236fc8, HEAD 3b9f7c8f695 == multi-target-0
anchor           grep -c MULTI_TARGET gcc/Makefile.in = 52   (MEASURED)
```

The 71 rows reproduce exactly off the board's own `.sum` files:

```
alpha 25   arc 10   arm 10   avr 7   mips64 9   or1k 10        = 71
i386 0     aarch64 0        riscv64 0          s390x 0
```

## THE MEASUREMENT THAT DISTINGUISHED, TAKEN BEFORE ANYTHING WAS CHANGED

The brief asked for the decisive first measurement to be *the RTL that reached
`recog`*, because "the RTL is wrong" and "the RTL is right and only matching
fails" want completely different fixes and the ICE cannot tell them apart.

It is in the board's own `gcc.log`, and it settles it without a stock control:

```
arm-unknown-eabi, gcc.c-torture/compile/pr21728.c, -O0
error: unrecognizable insn:
(insn 17 16 18 2 (set (reg/f:SI 13 sp)
        (mem:TI (reg/f:SI 688) [0  S16 A64])) ...)
during RTL pass: vregs
```

Read the two halves separately:

- **The destination is CORRECT.** `reg:SI 13` is genuinely arm's stack pointer
  in arm's own `Pmode`. This is *not* a `Pmode` leak, and a `Pmode` hypothesis
  would have been the natural one to reach for -- `Pmode` is the redirect
  immediately above the site in `multi-target-macros.h` and has caused this
  class before. It is dead on this evidence.
- **The source is `mem:TI`, `S16` -- sixteen bytes.** Only the MEM's mode is
  wrong.

A `set` with mismatched modes is malformed by construction, so **the bug is
upstream of `recog`** and no pattern condition, insn numbering or `.md`
omission is involved. `builtins.cc:1203` builds that MEM; `explow.cc:1246`
hands it to `gen_move_insn` against `stack_pointer_rtx`.

## WHOSE SIXTEEN BYTES

```c
/* config/i386/i386.h:2011 */
#define STACK_SAVEAREA_MODE(LEVEL)			\
  ((LEVEL) == SAVE_NONLOCAL ? (TARGET_64BIT ? TImode : DImode) : Pmode)
```

`defaults.h:1493` has the fallback that would have given every other base the
right answer:

```c
#ifndef STACK_SAVEAREA_MODE
#define STACK_SAVEAREA_MODE(LEVEL) Pmode
#endif
```

and it is **dead**, because `i386.h` defines the name first in every shared
translation unit. That is the `EPILOGUE_USES` / `REGMODE_NATURAL_SIZE` trap in
a third place, and PRINCIPLES already names the rule: *an `#ifndef` in a shared
TU is never taken if the primary defines the name, so "it has a fallback" is
not evidence the fallback runs.*

## THE DISCRIMINATOR: `restore_stack_nonlocal`, 4/6 WITH NO EXCEPTIONS

The obvious objection is that i386 *and* aarch64 *and* riscv *and* s390 all
pass, so the leak cannot be reaching everyone. It is, and here is why they are
quiet.

`explow.cc:emit_stack_restore` uses `gen_move_insn` **unless** the back end
supplies its own `restore_stack_nonlocal` expander -- which takes the mode as
given and absorbs the wrong one. Exactly seven back ends define that pattern:

```
$ grep -rln restore_stack_nonlocal gcc/config/
aarch64  i386  ia64  riscv  rs6000  s390  sparc
```

Against the ten scored back ends:

```
PASS  i386  aarch64  riscv  s390          -- all four HAVE the expander
FAIL  alpha arc arm avr mips64 or1k       -- none of the six has it
```

Ten of ten, no exceptions. **So the four passing targets were never
unaffected; they were CONCEALED.** The leak reaches them identically and their
own expander swallows it. A board scoring only those four could not have seen
this in principle -- which is exactly how `TAA-BOARD.md` §4 came to record the
site as *"does not appear at all -- someone fixed it"*. It was never fixed. It
was invisible, and it was invisible for a mechanical reason, not by luck.

## THE CITATION THAT READ AS EVIDENCE THE WORK HAD BEEN DONE

`multi-target-macros.h`, immediately above the `Pmode` redirect, said:

> `STACK_SAVEAREA_MODE` above expands to `Pmode` for a base that defines no
> such macro, and is defined EARLIER in this file, so it picks this up by
> ordinary macro expansion -- the redirect being last is what makes that work
> rather than a coincidence.

**Both halves are false.** There was no `STACK_SAVEAREA_MODE` anywhere in that
file (`grep` scores 2 hits, both inside this comment and the `FUNCTION_MODE`
one that cites it as a precedent). And the `defaults.h` fallback it appeals to
is dead, as above. This is the `sweep.sh` shape PRINCIPLES records: a comment
describing a mechanism reads as evidence the mechanism is there. Two later
comments took it as settled precedent and reasoned from it.

Both comments are corrected in place, with the false sentence quoted rather
than deleted, so the next reader can see what was believed.

## THE FIX -- the settled `mt_*` shape, following `FUNCTION_MODE` exactly

| file | change |
|---|---|
| `target-frame.h` | `machine_mode (*stack_savearea_mode) (int level);` in `struct target_frame_desc`, after `function_mode`; `extern machine_mode mt_stack_savearea_mode (int);` |
| `target-cumargs.cc` | `mt_base_stack_savearea_mode`, compiled once per back end so the macro is that base's own; `#include "explow.h"`; added to the positional initialiser |
| `target-cumargs-select.cc` | `mt_stack_savearea_mode`, through `mt_frame ()`, **uncached** |
| `multi-target-macros.h` | `#undef` + `#define STACK_SAVEAREA_MODE(LEVEL) (mt_stack_savearea_mode ((int) (LEVEL)))`, after the `Pmode` redirect |

Four decisions worth stating, each measured rather than assumed:

- **A CALL, not a `target-cdata` constant.** i386's body reads `TARGET_64BIT`,
  which is `global_options.x_ix86_isa_flags` -- option state that moves within
  one run -- and the thirty-odd back ends defining no macro reach
  `defaults.h`'s `Pmode`, which is *already* a run-time call. A value read once
  at selection time would be frozen twice over.
- **`machine_mode`, not `scalar_int_mode`** (unlike `pmode` beside it).
  aarch64's answer is `E_CDImode`, which is not a scalar int at all; s390's and
  ia64's are 256-bit integer modes. Narrowing the type would make a legal
  per-base answer unrepresentable. `tree-nested.cc:792` narrows it itself with
  an explicit `as_a <fixed_size_mode>`.
- **`int` in the interface, not `enum save_level`.** The enum lives in
  `explow.h:90`, which cannot be required of the hundreds of shared TUs that
  reach `multi-target-macros.h`. The cast back happens in the base's own thunk,
  which is where the enumerator has to be in scope anyway -- `sparc.h:565`,
  `s390.h:328` and `i386.h:2011` each test `(LEVEL) == SAVE_NONLOCAL` by name.
- **Swept for constant-expression contexts before landing.** Seven use sites
  outside `config/`: `explow.cc:1153`, `builtins.cc:889 :996 :1203 :1275`,
  `tree-nested.cc:792`, plus a comment at `explow.cc:1263`. Every one is an
  ordinary run-time argument -- no `#if`, no `#ifdef`, no case label, no array
  bound, no static initialiser.

## THE RESIDUAL, BY NAME

`extract_insn` rows and what each is:

```
BACK END  ROWS  TESTS                                     CAUSE
alpha       25  pr21728 pr82337 20050122-2 20011029-1     STACK_SAVEAREA_MODE
                complex-6
arc         10  pr21728 20050122-2                        STACK_SAVEAREA_MODE
arm         10  pr21728 20050122-2                        STACK_SAVEAREA_MODE
mips64       9  pr21728 20050122-2                        STACK_SAVEAREA_MODE
or1k        10  pr21728 20050122-2                        STACK_SAVEAREA_MODE
avr          7  pr21728                            (5)    STACK_SAVEAREA_MODE
                string-large-1                     (2)    DIFFERENT -- see below
```

`pr21728.c` and `20050122-2.c` are both nonlocal-goto tests (`__label__` plus
a nested function doing `goto`). alpha's three extras are the **save** side of
the same macro rather than the restore side, and the insn says so:

```
alpha, 20011029-1.c / complex-6.c / pr82337.c
(set (mem:TI (plus:DI (reg/f:DI 684) (const_int 16)) [2  S16 A128])
     (reg/f:DI 30 $30))
```

-- alpha's `$30` (its stack pointer, DImode, correct) stored into a `TImode`
slot. Same macro, opposite direction, and it is why alpha carries 25 rows
rather than 10.

### avr `string-large-1.c`, 2 rows -- NOT this cause, not fixed here

```
(set (reg:HI 711) (const_int 2147483647 [0x7fffffff]))
```

`SIZE4` is `((unsigned int) -1) >> 1`. The destination `HImode` is avr's
correct `size_t` width; the constant was built at 32 bits and never truncated
to it, so `gen_int_mode` was not used or was used with someone else's mode.
Nothing about it involves the stack save area. It is one back end, two rows,
and it is stated rather than folded into the headline -- reporting 71 as fixed
when 69 are is exactly the shape this project keeps paying for.
