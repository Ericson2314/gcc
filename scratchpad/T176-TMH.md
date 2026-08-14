# T176 — the last acceptance criterion: `#include "tm.h"` 163 → 59

Snapshots `374fe605b2c` (before) and `9c301ec45db` (after), anchor
`grep -c MULTI_TARGET gcc/Makefile.in` = **49** in both, 47 back ends
configured, `--enable-languages=c,lto`, built from immutable `git archive`
snapshots.

```
$ git grep '#include *"tm.h"' gcc ':(exclude)gcc/ChangeLog*' ':(exclude)gcc/*/ChangeLog*' | wc -l
59          (was 163)
```

---

## 0. THE FINDING THAT MATTERS MORE THAN THE COUNT

**The stated criterion can reach 0 while the channel it exists to close stays
fully open, and it is open today.**

`backend.h`, `target.h`, `cp/cp-tree.h` and `m2/gm2-gcc/gcc-consolidation.h`
— the four headers PRINCIPLES calls "the whole transitive channel" — no longer
*spell* `#include "tm.h"`. They spell:

```c
/* gcc/backend.h:28 */
#include "multi-target-header.h"
#include MT_HEADER (tm.h)
```

The acceptance grep cannot see that form. And `multi-target-header.h:53-56`:

```c
#ifdef MT_BASE
#define MT_HEADER(f) MT_HDR_XSTR (MT_BASE/f)   /* "i386-inc/tm.h" */
#else
#define MT_HEADER(f) MT_HDR_STR (f)            /* "tm.h" */
#endif
```

**A shared object has no `MT_BASE`.** So for every shared TU the `#else` arm
fires and the include resolves to the build root's `tm.h`, which in this
**47-back-end** build is still exactly what PRINCIPLES describes:

```c
/* b-a7cee-before/gcc/tm.h:45 */
#ifdef IN_GCC
# include "options.h"
# include "insn-constants.h"
# include "config/vxworks-dummy.h"
# include "config/i386/biarch64.h"
# include "config/i386/i386.h"
...
# include "config/i386/linux64.h"
#endif
```

i386's entire header chain under a target-neutral filename, reaching ~500
shared TUs. Measured directly, not inferred — `t176-route.sh` runs `cpp -H`
on a TU whose own include has been cut and names the includer:

```
fold-mem-offsets.cc   included by: gcc/backend.h      tm.h opened: ./tm.h
cp/constraint.cc      included by: gcc/cp/cp-tree.h   tm.h opened: ./tm.h
```

`MT_HEADER` is a real improvement over `-I` shadowing — it names the base at
the point of inclusion for per-base objects. But its `#else` arm is a
**silent fallback to the primary** for shared objects, which is the shape
§2a bans, and it is invisible to the criterion that is supposed to detect it.

**This is a design question and is not resolved here.** The options are not
equivalent and each has a cost:

- make the `#else` arm `#error`, which fails by name and immediately makes
  every shared TU that reaches a channel header a hard build failure (~500
  TUs — this is the honest measurement of how much conversion work is left,
  and it is much larger than 54);
- delete the `MT_HEADER (tm.h)` lines from the four headers, which is Phase 5
  of `T141-TMH-REMOVAL-PLAN.md` and is blocked on the same conversion work;
- widen the criterion to `git grep -E '(#include *"tm\.h"|MT_HEADER *\(tm\.h\))'`
  so the number stops understating the residue.

**The third is not an alternative to the first two** — it changes only what
is measured. It is listed because the count is currently quoted as progress
and it is measuring less than it appears to.

### The same lie, one stem over

`tm_p.h` is the identical artefact and the criterion does not name it at all:

```
$ cat b-a7cee-before/gcc/tm_p.h          $ cat b-a7cee-before/gcc/sparc-inc/tm_p.h
#ifdef IN_GCC                            #include "tm_p-sparc.h"
# include "config/i386/i386-protos.h"
# include "config/linux-protos.h"
# include "tm-preds.h"
#endif
```

**105 shared TUs include a bare `"tm_p.h"`** (`calls.cc`, `expr.cc`,
`function.cc`, `varasm.cc`, `reload1.cc`, `ira.cc`, …) and therefore read
**i386's function prototypes** believing them generic. `BASE_HEADER (tm_p.h)`
is already used in 123 `config/` files, so the mechanism exists and the shared
population simply has not been done. This is PRINCIPLES' own rule arriving
again: *when you enumerate a population by stem, enumerate every stem.*

---

## 1. WHAT MOVED, AND ON WHAT EVIDENCE

| step | count | evidence |
|---|---|---|
| start | **163** | |
| 5 prose hits reworded | 158 | not includes; comment text only |
| 10 `config/` → `BASE_HEADER (tm.h)` | 148 | in-tree precedent + `t176-whichtm.sh` |
| 58 shared TUs, line deleted | 90 | object REBUILT without it |
| 14 redundant lines deleted | 75 | object rebuilt; **channel unchanged** |
| 21 → a neutral header | 54 | object rebuilt with that exact text |
| **5 restored — regression fix** | **59** | the 47-back-end build, see §1a |

**No population left the board silently.** Full census of the 120 measured
candidates: 58 deleted, 21 replaced, 18 REAL-TARGET residue, 14 STILL-REACHES
(deleted, but see below), 9 not measurable in a `c,lto` build.

### 1a. THE SWEEP WAS WRONG ABOUT FOUR FILES, AND THE BUILD IS WHY WE KNOW

This is the part of the task worth reading second, after §0. **The deps-diff
build was run to check for a silent change and it caught a loud one instead**
— which is the argument for running it, not against it.

First verification build: **1401 objects and 4465 errors**, against 4490 and 1.
Three deletions produced 4272 diagnostics (1536 `FIRST_PSEUDO_REGISTER`, 1296
`enum reg_class`, 1296 `N_REG_CLASSES`, 144 `LOAD_EXTEND_OP`, 144
`BITS_PER_WORD`). Second build, after the fix: **4489 objects, 5 errors**, one
new file. Third: pending.

Both mistakes are ONE mistake in two disguises, and it is a lesson about the
instrument, not about `tm.h`:

- `rtl.cc`, `read-rtl.cc`, `print-rtl.cc` are compiled **twice** — as shared
  cc1 objects and once per back end as generators (`build/rtl-<cpu>.o`).
  `-DGENERATOR_FILE` makes `hard-reg-set.h:57` take register widths from the
  **raw** `tm.h` names instead of `multi-target-reg-widths.h`, exactly as that
  header documents in place. Fixed with `#ifdef GENERATOR_FILE`, evidence on
  both sides: the generator half needs it (this build), the shared half does
  not (the amputation arm).
- `c/gccspec.cc` is compiled **once, under a different rule** — the driver's,
  where `options.h` does not arrive by another road.

**The unit of "a configuration" is the object's own recipe**, not the source
file and not the directory. `t176-amp2.sh` borrows `cfgexpand.o`'s recipe for
all 120 candidates, so it answers for one recipe and was read as answering for
every recipe each file is built in. That is PRINCIPLES' "a test in a reduced
environment can pass for a reason the real environment removes", where the
reduced environment was a **recipe** rather than a directory.

Two guards added so it cannot recur: `t176-twice.sh` asks the build system
which sources have a second compilation (it names exactly five and excludes
`main.cc` / `real.cc`, and asserts it found any `build/` objects at all so a
blind instrument fails rather than reporting a clean zero); and
`t176-realrecipe.sh` rebuilds one object with `make -n <object>`'s own line.

`gencheck.cc` and `genmddump.cc` were **reverted, not guarded**: generator-only
(`bconfig.h`), never shared TUs, and unverified in their own recipe because the
build stopped before reaching them. An unverified deletion is not kept. T141
already asked for these two to go to the generator owner separately.

### 1b. AND ONE OF MY OWN EDITS EVADED THE CRITERION

The guarded includes were first written `# include "tm.h"`, which does **not**
match the acceptance grep `#include *"tm.h"`. The count read 54 with three
real includes present — I would have reported a number three lower than the
tree. Caught by `t176-census.sh` disagreeing with itself: it reports the
acceptance grep **and** an independent real-directive regex, and they came back
56 vs 59. The pair was built to separate prose from directives; that it can
also disagree the *other* way was not the reason for it and is the more useful
half. Now spelled `#include`, and the two counts are equal at 59.

The plain form is also the correct one: `build/` generator objects receive no
`-DMT_BASE` (the four `MULTI_TARGET_BASE_DEF` sites are all `mt-*/`), so
`BASE_HEADER (tm.h)` — which `#error`s without `MT_BASE` — is unavailable to
them. **The generator population reaches its base through the include path,
which is the one `-I` selection the branch has not removed.**

### The instrument, and its two corrections

`t176-amp2.sh` extends #160's amputation arm. Per file it rebuilds the object
with the `tm.h` line cut, in the branch's real compile recipe, and requires
`GCC_TM_H` to be **undefined** afterwards — because "it still compiles" is not
evidence: `#if FOO` on an undefined `FOO` evaluates FALSE silently.

Two things the inherited arm got wrong, both found by running it:

- **A file that does not compile in this configuration anyway scored FAIL and
  read as "needs tm.h".** The candidate list spans ten front ends; this build
  configures `c,lto`. A BASELINE arm now compiles each file unmodified first
  and scores N/A-BASELINE (9 files, `ada/` and `cobol/`) rather than revoking
  it.
- **Its negative control's banner — "every file must FAIL" — overstates the
  claim.** With the conversion layer amputated too, `real.cc` fails on
  `enum reg_class` but `hooks.cc` still PASSES, correctly: it consumes nothing
  from either channel. The control does not partition into "arm works" /
  "arm broken". It splits the passes into DELETE-VIALAYER (the layer carries
  it — the arm demonstrating it can fail, 8 files) and DELETE-CLEAN (needs
  neither channel, 50 files). Reported separately, so a run with **zero**
  control-fails would be visible as an arm that proved nothing.

### The 14 that moved the count and not the channel

Scored STILL-REACHES: the object rebuilds without the line, but `GCC_TM_H` is
still defined, so the TU goes on reading `tm.h` through `backend.h` /
`cp-tree.h`. Their own include was a duplicate authority and the terminal
state needs it gone — but **not one of these 14 stopped reading `tm.h`**.
Recorded as its own row because summing it with the 58 would misrepresent
both. This is what §0 is about.

---

## 2. THE RESIDUE, BY CAUSE

### 2a. 18 shared TUs that genuinely read the back end's header chain

Still fail with **both** neutral headers supplied, so this is real conversion
work, not a missing include. Five groups, not eighteen problems:

| cause | files |
|---|---|
| `CUMULATIVE_ARGS` | `print-rtl-function.cc`, `rtl-tests.cc`, `rtlhooks.cc` |
| `call_saved_registers_type` | `d/d-target.cc`, `jit/jit-target.cc`, `vmsdbgout.cc` |
| `INT_TYPE_SIZE` / `CHAR_TYPE_SIZE` | `d/intrinsics.cc`, `fortran/trans-expr.cc`, `fortran/trans-intrinsic.cc`, `rust/rust-gcc.cc` |
| singletons | `TARGET_HAS_FMV_TARGET_ATTRIBUTE`, `HAVE_LD_AT_FILE`, `CLZ_DEFINED_VALUE_AT_ZERO`, `HAVE_COMDAT_GROUP`, `POINTER_SIZE_UNITS`, `DEFAULT_SIGNED_CHAR`, and `lto/lto-common.cc` |
| **shared selector needing per-base types** | `target-cumargs-select.cc` |

The last one is not like the others and should not be worked as if it were.
It fails with `multiple definition of 'enum reg_class'` — the neutral
declaration in `multi-target-macros.h` colliding with the real one. It is a
**shared** object (`multi-target-md.mk:34540`, no `MULTI_TARGET_BASE_DEF`)
whose job is to dispatch between per-base `CUMULATIVE_ARGS`, so it must see
per-base types from a TU that has no base. That is a design question, not a
conversion.

### 2b. 5 `config/` sources — the host/target split

Ten of the fifteen were mechanical. The other five are two distinct things,
and `config.gcc` does not tell you which — the generated fragments do
(`t176-cfgobjs.sh`):

- **`driver-i386.cc`, `driver-aarch64.cc`, `driver-arm.cc`,
  `driver-alpha.cc`** come from the `x-<cpu>` **host** fragments, i.e.
  `host_extra_gcc_objs`. `gcc/Makefile:1026` is `EXTRA_GCC_OBJS =
  driver-i386.o $(MT_GCC_OBJS)` — the first term is the HOST half, answering
  `-march=native` about the machine the driver runs on. These objects never
  receive `-DMT_BASE`, so `BASE_HEADER` cannot be applied as-is. The host's
  back end IS known at configure time, so the fix looks mechanical (emit a
  `MULTI_TARGET_BASE_DEF` for the host driver object, as `MT_GCC_OBJS_<b>`
  already does for the target half) — but it needs a host→back-end mapping in
  the build system that does not exist yet, and `-march=native` being a host
  fact makes it a `gcc/configure.ac` question. **Sized, not landed.**
- **`gen-avr-mmcu-specs.cc`** is a build-time generator program
  (`t-avr:96`, `$(build_exeext)`), single-target by construction.

### 2c. 20 testsuite plugin sources

`gcc.dg/plugin/*.cc` and `g++.dg/plugin/*.cc`. Compiled at *test* time against
the installed plugin headers, not by any build here, so the amputation arm
cannot reach them and none was touched. They are shared TUs by construction —
a plugin has no target — so a bare `tm.h` there resolves to the installed
primary's chain, the same lie. Needs a plugin-recipe arm before any deletion.

---

## 3. VERIFICATION

**Deps-diff over every object both 47-back-end builds produced**, asking which
per-back-end headers each compilation actually opened (`t173-depsdiff.sh`).
Rule: zero per-back-end headers lost.

```
before: rc=2, 4490 objects        (snap-before 374fe605b2c, anchor 49)
after : rc=2, 4490 objects        (snap-after  ff19f9242d8, anchor 49)
objects in common: 2000
PASS: identical per-back-end header sets across 2000 objects
```

**Per-back-end headers LOST 0, ADDED 0.** Both builds `rc=2` on the SAME one
pre-existing failure, `build/gen-target-specs-amdgcn_unknown_amdhsa.o`
(`gtype-desc.h: No such file or directory`), present without any change from
this task; `error:` lines 1 and 1.

Non-vacuity, because a green from an instrument that read nothing is worth
nothing: the compared sets are **20662 records** over 2000 objects spanning
**48** `*-inc/` directories — 2000 objects open a per-base `insn-modes.h`,
1952 open a per-base `tm.h`, 1725 a per-base `insn-codes.h`. The two sides are
byte-identical. (This arm has fired before: it is what caught 94 objects
silently swapping `insn-modes.h` in #174, with both builds compiling clean.)

Both builds are `make -k -j8 all-gcc` from read-only `git archive` snapshots
with the anchor asserted at 49 and an `.rc` stamp written only after `make`
returns; the scorer refuses a log without the stamp.

### Bars, measured on BOTH arms rather than quoted

One-sided evidence cannot separate "unchanged" from "both arms moved the same
way", so the before arm was re-measured here, at **47 bases**, not quoted from
PRINCIPLES:

```
                        specs-config x86_64          x86_64 -O2 big.c
before  374fe605b2c     230 / 222 / a6c4c68bdf33     12369 / 378fc33c1e70
after   ff19f9242d8     230 / 222 / a6c4c68bdf33     12369 / 378fc33c1e70
```

Both match the recorded bar exactly. Note this reproduces the two-base bar at
47 bases, consistent with `688b3afe25d` having made the x86_64 codegen bar
base-count independent.

**aarch64's bar was NOT measured** — it needs a second `target-specs` run and
was not done. Not "unchanged": unmeasured.

**The build-count arm is the one that actually fired in this task**, and it is
worth saying which arm did the work: the deps-diff was clean on the FINAL
tree, but 4490-vs-1401 objects and 1-vs-4465 errors on the first attempt is
what caught the generator regression (§1a). A silent-change instrument and a
loud-failure instrument are not redundant.

### What was verified for the 10 `config/` conversions, and what was not

**None of the ten is compiled by a `c,lto` build** — the six `*-d.cc` need the
D front end and `sol2-c.cc` / `vms-c.cc` / `darwin-driver.cc` /
`vxworks-driver.cc` need a Solaris / VMS / Darwin / VxWorks target. So "the
build stayed green" says nothing about them, and saying so is the point.

What *can* be measured is the only thing the edit changed: which file the
include resolves to. `t176-whichtm.sh` preprocesses each under two different
`-DMT_BASE` and requires the opened `tm.h` to follow the flag **both times**:

```
PASS  config/sparc/sparc-d.cc   sparc=>sparc-inc/tm.h  s390=>s390-inc/tm.h
PASS  config/s390/s390-d.cc     sparc=>sparc-inc/tm.h  s390=>s390-inc/tm.h
PASS  config/sol2-c.cc          sparc=>sparc-inc/tm.h  s390=>s390-inc/tm.h
```

The negative control fires on the unconverted files, and fires in the way
that names the bug — the SAME file under both bases:

```
FAIL  config/i386/driver-i386.cc     sparc=>(no *-inc/tm.h)  s390=>(no *-inc/tm.h)
FAIL  config/alpha/driver-alpha.cc   sparc=>(no *-inc/tm.h)  s390=>(no *-inc/tm.h)
```

A file that hardcoded a path, or that fell back to the build root's `tm.h`,
opens the same file both times and cannot pass this arm.

---

## 4. THINGS THIS TASK'S INSTRUMENTS CANNOT SEE

- The build configures **`c,lto`**. 9 files were not measurable at all, and
  the D / Rust / Cobol / Modula-2 / Ada front-end files that *were* measured
  were compiled with `cfgexpand.o`'s flags, not their own front end's.
- The deps-diff compares only objects **both** builds produced.
- The amputation arm reads one configuration's answer. A macro used only under
  an `#ifdef` that is false for all 47 configured bases is invisible to it —
  which is why the `GCC_TM_H` arm exists, but that arm bounds the channel, not
  every macro.
- **`MT_HEADER (tm.h)` and bare `tm_p.h` were found only because a TU that
  should have left the channel had not.** Neither is in any census on this
  branch. So the other `*-inc/` stems were swept rather than assumed, in
  shared (non-`config/`) TUs:

  | stem | shared bare includes |
  |---|---|
  | `tm.h` | **54** (this task's criterion) |
  | `tm_p.h` | **105** — not in any criterion, i386's protos, see §0 |
  | `tm-preds.h` | 0 |
  | `tm-constrs.h` | 1 — `multi-target-select.cc`, the branch's own dispatcher |

  So `tm_p.h` is not a long tail, it is a second population of the same size
  class as the one this task was pointed at, and nothing is currently
  measuring it.
