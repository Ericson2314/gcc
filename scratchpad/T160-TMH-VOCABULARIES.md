# T160 — the second vocabulary, and what it did to the Class A numbers

Measured at anchor 48, worktree `agent-a51d424a65fb6e21d`, build
`/tmp/b-a51d424a65fb6e21d` from immutable snapshot `/tmp/snap-a51d424a`.
Instruments: `t160-vocab.sh`, `t160-need2.sh`, `t160-amputate.sh`,
`t160-crosstab.sh`. The one-vocabulary scan `t152-need1.sh` is left unmodified
so the two readings can be compared.

---

## 1. `tm.h` is FIVE things, not four, and only three of them are per-target

`gcc/tm.h` in a two-base build dir, all 66 lines of it:

| lines | channel | route other than `tm.h`? |
|---|---|---|
| 1–38 | the mkconfig.sh top half (`LIBC_*`, `DEFAULT_LIBC`, `ANDROID_DEFAULT`, `HEAP_TRAMPOLINES_INIT`, `TARGET_HAS_IFUNC`, `HAVE_LD_*`) | none |
| 40 | `#include "options.h"` | **YES** — 108 source-level includers, `tree.h` among them |
| 41 | `#include "insn-constants.h"` | none (only `genenums.cc` names it) |
| 42–57 | the back end's header chain | none |
| 60 | `#include "insn-flags.h"` | none |
| 63 | `#include "insn-modes.h"` | **YES** — `coretypes.h:553`, in every shared TU |
| 65 | `#include "defaults.h"` | none (already severed for the converted set) |

The brief names four; there are five, because `insn-constants.h` sits on its own
line beside `options.h` and is *not* covered by the back-end-chain vocabulary.

**The brief's open question — do `insn-flags`/`insn-modes` need their own
vocabulary — has two different answers.** `insn-flags.h` does: nothing else
includes it. `insn-modes.h` does **not**: `coretypes.h` includes it through
`INSN_MODES_H`, ahead of `tm.h`, in every shared translation unit. That is also
why `target_unit` could move out of `defaults.h` unchanged — its `#if` is on
`BITS_PER_UNIT`, which is `insn-modes.h`'s, i.e. the genmodes union quantity and
never the primary's.

**Only three of the five are per-target at all.** The top half is
target-neutral by inspection (it is `#ifndef`-guarded defaults about libc and
the linker), and `options.h` is generated from *every* configured back end's
`.opt` files, so a shared TU including it directly gets no primary's answer.
That reframes the options.h revocations: they are not leaks to be converted,
they are **a missing include**.

## 2. The four vocabularies, and what they did to the 39

`t160-vocab.sh` builds them from the BUILT headers plus the sources, and
asserts by name that each contains the identifier that revoked a real deletion
(`POINTER_SIZE`, `flag_checking`, `OPT_x`, `DEFAULT_LIBC`, `HAVE_LD_PIE`,
`GCC_INSN_FLAGS_H`) — an instrument that cannot show a defect it already knows
about cannot be used to grind a population.

```
v1-config    10881 names     v2-options    5273 names
v3-tophalf     125 names     v4-insn      43409 names
```

Re-scoring t141's Class A over all four:

| verdict | count | meaning |
|---|---|---|
| CLEAR | **31** | no vocabulary hit |
| OPTIONS-ONLY | **8** | hit by `options.h` names and nothing else |
| REVOKE | 0 | — |

Over all 625 shared TUs the answer is the same 31 / 8 / 586. **So the extra
vocabularies revoke nothing at the level of a file's own text**: the eight they
catch (`main.cc` `flag_checking`, `cppspec.cc` `OPT_E`, `lto-dump.cc`,
`a68spec.cc`, `c-aux-info.cc`, `m2except.cc`, `m2misc.cc`,
`selftest-run-tests.cc`) were CLEAR before and are now merely *conditional*,
with a one-line remedy that 108 files in this tree already use.

**A first draft of these vocabularies revoked all 39 and was wrong.** Taking
every token on an `extern`/`struct` line put `void`, `int`, `const`, `enum`
and `rtx` into the vocabulary; `struct GTY(()) gcc_options` contributed `GTY`.
A scan that revokes everything reads as "nothing is deletable" and is
indistinguishable from a result.

## 3. The real correction is not the vocabulary — it is the transitive channel

`t160-amputate.sh` deletes the `#include "tm.h"` line into a copy and compiles
it with the real recipe. Cross-tabulated against the source-text scan
(`t160-crosstab.sh`), on the tree BEFORE this task's fix:

```
             FAIL   PASS
CLEAR          17     14
OPTIONS-ONLY    5      3
```

**Seventeen files are clean against every vocabulary and still cannot be built
without `tm.h`.** Their causes, from the build rather than from a scan:

```
13  'flag_checking' was not declared in this scope
 8  use of enum 'reg_class' without previous declaration
 1  'OPT_E' was not declared in this scope
```

`flag_checking` is `options.h`'s, reached through `system.h`'s
`gcc_checking_assert`; `enum reg_class` is `hard-reg-set.h:551`'s, reached
through `rtl.h`. Neither is in the file's own text and no text-reading
instrument can see either.

So: **`t141-delete-ready.txt`'s 23 and Class A's 39 are upper bounds, and the
binding constraint is not the second vocabulary the brief asked for.** The
options.h vocabulary explains 1 of the 22 revocations from a file's own text;
the other 21 come through headers.

## 4. After the Phase 2 fix

With `rtl.h`/`hard-reg-set.h` taking the conversion layer and `enum reg_class`,
`target_unit` and `LOAD_EXTEND_OP` answered neutrally (commit `c3ca86166f8`),
the same instrument on the same build scores the 23 direct includers:

```
21 PASS   2 FAIL   (main.cc 'flag_checking', cppspec.cc 'OPT_E')
```

and over the 39: `PASS=21 FAIL=3 STILL-REACHES=15`, where STILL-REACHES is the
honest verdict for a TU that has no direct include and reaches `tm.h` through
another header — untestable by deleting a line, and scored as such rather than
as a pass.

**Remaining, in order of population:** the `options.h` route (2 of the 23, and
the majority of the 15 once Phase 5 removes the header route), then Phase 5
itself. `target-asm-ops-select.cc` fails on `TARGETM_ASM_OPS_SYMBOL` and is a
generated-header question, not a target-macro one.

## 5. What these instruments cannot see

- `t160-vocab.sh`'s `options.h` and `insn-flags` vocabularies come from the two
  CONFIGURED bases' built headers plus the sources. A name only some
  unconfigured target's `.opt`/`.md` generates is not in them.
- `t160-amputate.sh` compiles each TU with `cfgexpand.o`'s recipe. A front-end
  file needing its own `-D` may fail for a reason that is not `tm.h`; the cause
  string is printed for exactly that reason and must be read, not counted.
- Neither says anything about the ~186 targets never built.
- `AUTO_INC_DEC` is compared with and without `tm.h` and never differed, so the
  deletions change no behaviour there. That is NOT a statement that
  `AUTO_INC_DEC` is right: see below.

## 6. Found on the way, not fixed here: `AUTO_INC_DEC` is 0 for every target

`rtl.h:2876` computes it from `defined (HAVE_PRE_INCREMENT)` and seven
siblings. `config/aarch64/aarch64.h:1346-1347` defines `HAVE_POST_INCREMENT`
and `HAVE_PRE_INCREMENT`; 22 back ends define the family; **i386, the base the
middle end is compiled against, defines none.** So shared code has
`AUTO_INC_DEC 0` and `FIND_REG_INC_NOTE` 0 for every target, and the 22 back
ends that can address auto-increment are compiled by a middle end that believes
they cannot.

It is the leaked-ABSENCE shape (`INIT_EXPANDERS`, `LOAD_EXTEND_OP`) and it is
both-sidable with the pair already configured — i386 says no, aarch64 says yes,
so no third back end is needed. It is NOT converted here because `AUTO_INC_DEC`
is read on `#if` lines across the middle end, so it is a sweep of the E1 shape
rather than a redirect, and it deserves its own task.
