# `extract_insn, at recog.cc:2892` ON SIX BACK ENDS: it is `STACK_SAVEAREA_MODE`

The first cause found by scoring more than four back ends, and it is one name
with several authorities rather than six bugs. **69 of its 71 rows are a single
leaked macro; the other 2 are a different leaked macro, named and sized rather
than folded in.**

## PROVENANCE — quote this with any row

```
worktree    agent-a95a42fd940ce4d8e
            STARTED ON THE STALE BARE-REPO HEAD 7208eca60d0 and was reset.
            `--is-ancestor' returned FALSE here (39,766 commits behind, not an
            ancestor at all), so for once it would have caught it -- but the
            deciding arm was the rev-parse equality, as the brief says.
srcdir PRE  /tmp/snap-4387bf9ce42-agent-a95a42fd940ce4d8e   (4387bf9ce42)
srcdir POST /tmp/snap-6f3afb46376-agent-a95a42fd940ce4d8e   (6f3afb46376)
            git archive, read-only, SNAP-SHA stamped, sha IN THE PATH
build PRE   /tmp/b-a95a42fd940ce4d8e         47 triples, MT_MAKEFLAGS=-j8
build POST  /tmp/b-a95a42fd940ce4d8e-post    47 triples, same list
anchor      52, MEASURED on both trees.  UNMOVED: this task touches no
            gcc/Makefile.in line.
bars        make all-gcc rc=0;  `error:' 0;  cc1 links (231,051,864 bytes PRE)
            x86_64 -O2 big.c  12369 bytes / md5 378fc33c1e70  == recorded
            specs-config  232 lines / 224 non-blank, 10 targets, md5s ALL
              DISTINCT.  MD5s NOT QUOTED: they are a function of the probing
              toolchain's paths and this build dir is not the board's.
tools       real cross binutils 2.46, canonical spellings, each asserted to
            EXECUTE, with a firing negative control (nosuch-triple-as)
subset      gcc.c-torture/compile ONLY
```

**Precondition checked before ranking anything:** the one-line census
(`a7ee6ca7c923e4a58-onelinecensus.sh`) reads **OK=9, ICE=0, OTHER=1** over the
ten targets with a specs-config. No back end dies on its first input, so
nobody is invisible to a `.sum`-based ranking here. arc's OTHER is the
`does not have delayed branches` warning, not a failure.

## 1. THE 71 ROWS, BY NAME — and they are only TWO tests

`mtcheck.sh`'s preserved logs from the scored board reproduce the published
**71** exactly, which is the only independent check that those logs still
belong to the run that was scored (`-rows.sh`):

```
alpha  25   pr82337 6, pr21728 5, 20050122-2 5, 20011029-1 5, complex-6 4
arc    10   pr21728 5, 20050122-2 5
arm    10   pr21728 5, 20050122-2 5
avr     7   pr21728 5, string-large-1 2
mips64  9   pr21728 5, 20050122-2 4
or1k   10   pr21728 5, 20050122-2 5
```

**`pr21728.c` is on all six and `20050122-2.c` on five — 54 of 71 rows.** Both
are nonlocal goto: `__label__` plus a `goto` out of a nested function.

## 2. THE CAUSE, MEASURED BEFORE ANYTHING WAS CHANGED

`defaults.h:1493`'s `#ifndef STACK_SAVEAREA_MODE` is **dead**, because
`config/i386/i386.h:2011` has already defined the name in every shared
translation unit. The build's own `gcc/tm.h` includes `config/i386/i386.h` at
line 50; this is the `REGMODE_NATURAL_SIZE` / `EPILOGUE_USES` trap, **third
instance**.

`builtins.cc:1203` builds `gen_rtx_MEM (STACK_SAVEAREA_MODE (SAVE_NONLOCAL),
…)` and `explow.cc:1256` does `emit_insn (gen_move_insn (stack_pointer_rtx,
sa))`. A wrong mode here is therefore a load of the wrong width into the stack
pointer — an insn no back end's `.md` declares:

```
arm    (set (reg/f:SI 13 sp)       (mem:TI (reg/f:SI 688)  [0 S16 A64]))
avr    (set (reg/f:HI 32 __SP_L__) (mem:TI (plus:HI …)     [0 S16 A8]))
alpha  (set (reg/f:DI 30 $30)      (mem:TI (plus:DI …)     [0 S16 A128]))
```

All six are the same insn shape. **The RTL is wrong on its face**, so the
brief's fork is settled without a stock cross: the defect is UPSTREAM of
`recog`, not in pattern conditions or numbering.

### The value is i386's, and the proof is avr

Over ten selected targets shared code read exactly two values, and **neither
group got its own answer**:

```
alpha arc arm avr mips64 or1k   TImode   own answer Pmode -- HI / SI / DI
x86_64 aarch64 riscv64 s390x    DImode   own answers TI, CDI, DI, OI
```

`defaults.h`'s `Pmode` is `HImode` on avr and could not produce `TImode`;
`{TImode, DImode}` is exactly the range of i386's
`(TARGET_64BIT ? TImode : DImode)`. So the value is i386's macro — and
`TARGET_64BIT` is `global_options.x_ix86_isa_flags`, **option state**, which is
why it is not even constant across selections and why `nm -uC` is
structurally blind to it.

**The four that do not ICE are NOT proven fine.** They carry the same wrong
answer and merely happen to own a move of that width. aarch64 loads 8 bytes
where its own `STACK_SAVEAREA_MODE` asks for `CDImode`'s 16. That is why the
fix is a `machine_mode` read and not a floor, and it is the same
"3 LOUD / N UNVERIFIED" shape as `avr-fuse-add`.

### Why it survived two boards: a comment

`multi-target-macros.h:768` stated that `STACK_SAVEAREA_MODE` "expands to
`Pmode` for a base that defines no such macro, and is defined EARLIER in this
file". **There was no `#undef` and no `#define` for that name anywhere in that
file.** The sentence describes `defaults.h`'s fallback, which is dead. A
comment reasoning correctly about a fallback reads as evidence that someone
checked whether the fallback runs. It is kept verbatim in the file beside the
correction. `TAA-BOARD` §4 recorded the site as fixed; it was never fixed.

## 3. THE FIX

The settled `FUNCTION_MODE` shape, four files: a `stack_savearea_mode` slot in
the frame descriptor (`target-frame.h`), a per-base thunk
(`target-cumargs.cc`), an uncached selector (`target-cumargs-select.cc`), and
the redirect (`multi-target-macros.h`) ordered after `Pmode`.

The forty back ends defining nothing take `defaults.h:1494`'s `Pmode`
**expanded in their own translation unit**, where `Pmode` is still the real
macro. That is the supply-side floor PRINCIPLES §2a permits — upstream's own
answer for a back end that says nothing — and no base reads another's value
through it. The banned consumer-side floor is precisely the bug.

## 3a. WHY EXACTLY THOSE SIX — the causal story closed

`explow.cc:1235` picks `gen_restore_stack_nonlocal` when the back end defines
one and falls back to `gen_move_insn` otherwise. **Only the fallback puts the
save-area mode directly against the stack pointer's**, so only a back end
without the expander can ICE. Measured against the `.md` files:

```
HAVE restore_stack_nonlocal   aarch64 i386 ia64 riscv rs6000 s390 sparc
the six that ICEd             alpha arc arm avr mips or1k
```

Exactly disjoint, and the four controls are four of the seven that have it.
**The leak reached all 47; the six without the expander are the ones it could
not reach silently.**

## 3b. RESULT — POST vs PRE, both built cold from immutable snapshots

```
make all-gcc      rc=0 (stamp at the build-dir ROOT, not gcc/)   `error:' 0
cc1               links, 231,057,176 bytes
x86_64 -O2 big.c  12369 bytes / md5 378fc33c1e70    == recorded, UNMOVED
specs-config      232 lines / 224 non-blank, 10 targets, md5s ALL DISTINCT
one-line census   OK=9 ICE=0 OTHER=1                 == PRE, UNMOVED
anchor            52                                  == PRE, UNMOVED
```

**Targeted by-name arm, 14 tests x 5 optimisation levels, 75 pairs:**

```
recog.cc:2892     PRE 71  ->  POST 2
new ICEs at that site: 0
```

The save-area mode, per back end, now its **own** answer:

```
alpha  TI -> DI     arc TI -> SI     arm TI -> SI
avr    TI -> HI     mips64 TI -> SI  or1k TI -> SI
```

and the ten POST modes are **3 distinct values, not 1** — the non-vacuity arm
that would have caught a redirect merely swapping i386's answer for one other
shared answer.

**A DEFECT CAN HIDE BEHIND A DEFECT, and it does here.** Nine of the 69 fixed
rows do not become PASS; they get further and land on a *different*,
already-recorded cause:

```
avr    pr21728.c     -O2 -Os -O3   back end 'avr' has no pipeline automaton
mips64 20050122-2.c  -O1 -O2 -Os -O3   Segmentation fault
```

Both are the A7EE board's own separate findings (its hand-off items 3 and 4).
**The site is fixed; those tests still fail.** Reporting "69 rows fixed" as
"69 tests pass" would be the error PRINCIPLES records as reading a falling
total without reading what the new failures say.

**The control side is weaker than it looks and is stated as such.** All four
controls emit **byte-identical** assembly PRE vs POST on `pr21728.c`. That is
no regression; it is **not** evidence their save-area mode is now correct,
because each adjusts the address inside its own `restore_stack_nonlocal`
expander, so the incoming mode is largely inert there — which is also why they
never ICEd. `-bothsided.sh`'s `MISMATCH (wanted CDI/OI/TI)` rows for those
four are an artefact of that script and are **not** findings; it reads the
expander's output, where the save-area mode is not present. That script is
left unmodified with the limitation written into its header.

## 4. THE RESIDUAL, NOT FOLDED IN

`avr string-large-1.c`, 2 of 71 rows, is a **different** cause:

```
(set (reg:HI 697) (const_int 2147483647 [0x7fffffff]))
```

a 32-bit `INT_MAX` in avr's 16-bit `int` mode. Measured from cc1's own
predefines, avr gets `__SIZEOF_INT__ 4`; `avr.h` says `INT_TYPE_SIZE` is
`(TARGET_INT8 ? 8 : 16)`. `INT_TYPE_SIZE` is LEAK-PRIMARY in the census —
**40 back ends define it, 8 shared files spell it**, i386's is 32.

The control column is `__SIZEOF_POINTER__`, which reads **2** for avr and is
correct, because `Pmode` is already converted. So the target is genuinely
selected and this is the macro's own leak rather than a run that chose no
target. Not fixed here: its blast radius is the size of `int`, not two ICE
rows, and bundling it would make the `STACK_SAVEAREA_MODE` result
unattributable.

At `-O2` avr's `string-large-1.c` does not reach this at all — it hits
`back end 'avr' has no pipeline automaton`, the board's own separate finding.

## 5. A CORRECTION TO THE BRIEF'S STRONGEST LEAD

The leak census's **296** is right and its **119 / 177** split is right, but
only with `TMH=` pointing at the build's real `tm.h`. Run without it — which
is what the script does by default, printing a NOTE and continuing — it reads
**88 / 208**, because its hardcoded fallback chain is 9 headers where the real
one is 16. Same total, different split, no failure. Anyone quoting a split
from that script must say whether `TMH` was set.

The lead itself ("a `.md` pattern condition reading a leaked macro") **did not
hold and was cheap to refuse**: `insn-recog-<cpu>-N.o` is in
`MULTI_TARGET_OBJS_<cpu>` and gets `-DMT_BASE=<cpu>-inc`, so `.md` conditions
are compiled per base. Likewise the `HAVE_nonlocal_goto` shape: `builtins.cc`
and `except.cc` reach those through `targetm.have_*` / `targetm.gen_*`, which
are per-base dispatched. Both died in minutes.

## 6. WHAT IS NOT HERE

- **`gcc.c-torture/compile` only.** A floor on each back end's trouble.
- **No execution**, no target libgcc; a PASS means it compiled.
- **The other four causes on the shared ranking were not investigated**
  (`simplify_subreg` 4 back ends, `emit_move_insn` 3, `expand_call` 2,
  `Segmentation fault` 2). Nothing here says whether they share a root with
  this one; the companion-cause question the brief asked was answered only for
  the `extract_insn` rows themselves.
- **`INT_TYPE_SIZE` is diagnosed, not fixed**, and its 40-back-end population
  is a count of definers, not a measured blast radius.
- **gdb could not read the option state.** `cc1` is built `-g0` by
  `mt-conf.sh`, so `print global_options.x_ix86_isa_flags` yields no value; the
  breakpoint fired and the variable was unreadable. The whose-macro question
  was settled by the value RANGE instead, which is stronger, but the direct
  reading of `TARGET_64BIT` per selection was **not** taken and the DI-vs-TI
  split therefore has an inferred rather than observed proximate cause.
