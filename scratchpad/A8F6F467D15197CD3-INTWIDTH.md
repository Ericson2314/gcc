# `INT_TYPE_SIZE` — `int` is 32 bits on every back end, including the six that say 16

Worktree `agent-a8f6f467d15197cd3`, snapshot `e1f0cad1c2c`, anchor **52**,
cold 47-base build `/tmp/b-a8f6f467d15197cd3-PRE`, `--enable-languages=c,c++`,
rc=0, 0 `error:`. Instrument:
`scratchpad/agent-a8f6f467d15197cd3-intsize.sh`.

**This was not in the brief and it is the largest thing this task found.** It
came out of the `cp/` sweep the brief did ask for: `INT_TYPE_SIZE` is in
`cp/`'s and `c-family/`'s target-macro surface, it is **not** redirected in
`multi-target-macros.h` (its sibling `LONG_TYPE_SIZE` is), and its only
shared consumer is the one that matters most.

## 1. The leak

```c
tree.cc:9709   integer_type_node   = make_signed_type (INT_TYPE_SIZE);
tree.cc:9710   unsigned_type_node  = make_unsigned_type (INT_TYPE_SIZE);
```

A **shared** translation unit, reached through `tm.h`, so `INT_TYPE_SIZE` is
the primary's `i386.h` value **32** for all 47 back ends. That node is what
the C and C++ front ends mean by `int`.

## 2. The measurement, with the control that makes it evidence

`char mt_int_width[sizeof (int)];` and `char mt_ptr_width[sizeof (void *)];`
compiled by the 47-base `cc1` for each of the 45 targets with a real cross
assembler, width read from the emitted `.size`/`.comm`.

**`sizeof (void *)` is the control and it is load-bearing.** `POINTER_SIZE`
*is* already redirected on this branch, so pointer width must already be
per-target. A run in which both columns are constant would mean the target
was never selected and neither column is evidence — that is the reading this
arm exists to make impossible, and the script refuses rather than scoring if
the control does not vary.

```
targets read: 33 of 45   distinct sizeof(int): 1   distinct sizeof(void*): 3
  sizeof(int)   values:  4
  sizeof(void*) values:  2  4  8
```

**The control varies over three values and `int` does not vary at all.** The
four targets with 2-byte pointers — `avr`, `msp430`, `rl78`, `xstormy16` —
each report `sizeof (int) == 4`.

Twelve targets are not scored and are named rather than netted out: ten are
`UNREADABLE` (aout/mmixware emit no `.size` or `.comm` for these objects —
`bfin`, `cris`, `ft32`, `iq2000`, `mcore`, `mips64`, `moxie`, `pdp11`, `vax`,
`visium`), `mmix` ICEs with *"back end 'mmix' has no assembler-directive
table"* and `pru` ICEs — both pre-existing and both already recorded by the
previous task.

## 3. The population is SIX, and the static census said THREE

The value census (`agent-a8f6f467d15197cd3-macrocensus.sh`) resolved
`INT_TYPE_SIZE` as diverging on **3** of 47: `msp430`, `rl78`, `xstormy16`,
all literal `16`. Asking each base's own header chain directly:

```
avr         (TARGET_INT8  ? 8  : 16)     -> 16 by default
msp430      16
rl78        16
xstormy16   16
h8300       (TARGET_INT32 ? 32 : 16)     -> 16 by default
pdp11       (TARGET_INT16 ? 16 : 32)     -> 32 by default, 16 under -mint16
i386        32
```

**Six back ends, not three.** The three the census missed are the ones whose
value is an **option-state expression**, which the arithmetic evaluator
correctly declined to resolve and reported as `UNRESOLVED` rather than
guessing. That is the instrument behaving well and the *reader* having to
finish the job — and it is the third recorded instance of the same shape:
*counting the back ends that spell a literal undercounts the population.*
`avr` and `h8300` are confirmed at the compiler (`sizeof (int) == 4` on
both); `pdp11` is `UNREADABLE` at the compiler and is claimed from its header
only, which is stated rather than folded in.

## 4. Why this is worse than the `TARGET_VTABLE_ENTRY_ALIGN` residual

The vtable-alignment defect changes the alignment of one object. This changes
**what `int` means** — every integer promotion, every `INT_MAX`, every
`sizeof`, the calling convention for `int` arguments, and the C and C++ ABIs
in their entirety, on six back ends, in both front ends that exist today. It
is the same severity class as the ptrmemfunc break that occasioned this task
and it is live now, at rc=0, on a build with zero `error:`.

## 5. What was NOT done, and why

**Not fixed here.** It is a `target_frame_desc`-shaped conversion — the value
is option state on three of the six, so it must be a CALL and not a
`TARGET_CDATA_FIELDS` slot, exactly as `TARGET_VTABLE_ENTRY_ALIGN` was — but
its closure is not swept, and that sweep is the whole job:

* `defaults.h` spells `INT_TYPE_SIZE` in the body of other definitions, so
  redirecting it converts an unmeasured set of derived names for free, the
  way `POINTER_SIZE` converted eleven.
* `tree.cc:9709` runs at `build_common_tree_nodes` time, i.e. **once per
  compilation, after the target is selected** — which is the precondition a
  call needs and which was checked, not assumed.
* but `optabs-libfuncs.cc:879`, `builtins.cc:12360` and `toplev.cc:2198`
  compare it against `BITS_PER_WORD`, and `stor-layout.cc:2941` assigns it to
  a `precision`. Whether any of those is a constant-expression context has
  **not** been swept, and `PRINCIPLES` is explicit that a call-valued macro
  in an array bound or a `case` label is a build failure by name at best.

Landing it without that sweep is how "convert one member of a closure" goes
wrong, and this task did not have the budget to do it after the vtable work.
**It is a measured, reproducible, named defect with an instrument that
demonstrates it, handed over rather than half-fixed.**

## 6. The neighbours, from the same census run

Same instrument, same build, so these come at no extra cost. `VALUE-DIFF` is
over the 47 bases where both sides reduce to an integer; `+N?` is the
option-state residue no static reading can settle, and §3 above is what that
residue can hide.

```
macro                     VALUE-DIFF   redirected today?
WCHAR_TYPE_SIZE               8/47     NO   -- only d/ and ada/ read it (latent)
INT_TYPE_SIZE                 3/47+4?  NO   -- real population 6; section 3
STRICT_ALIGNMENT             32/47     yes  (targetm_cdata)
WORDS_BIG_ENDIAN             13/47     yes  (targetm_cdata)
BYTES_BIG_ENDIAN             12/47     yes  (targetm_cdata)
PCC_BITFIELD_TYPE_MATTERS     0/47+7?  NO   -- no resolvable divergence
SHORT_TYPE_SIZE               0/47+14? NO   -- no resolvable divergence
LONG_LONG_TYPE_SIZE           0/47+1?  NO   -- no resolvable divergence
CHAR_TYPE_SIZE                0/47     NO   -- 8 everywhere
BOOL_TYPE_SIZE                0/47     NO   -- 8 everywhere
```

**Read the zeros as carefully as the numbers.** `CHAR_TYPE_SIZE`,
`BOOL_TYPE_SIZE` and `LONG_LONG_TYPE_SIZE` are unconverted macros that a
*textual* census scored as diverging on 4, 4 and 9 back ends — the same
number written two ways (`BITS_PER_UNIT` vs `8`, `(BITS_PER_WORD * 2)` vs
`64`). They are not defects and converting them would move nothing. That
distinction cost one wrong version of the instrument and is why it now has
three columns.
