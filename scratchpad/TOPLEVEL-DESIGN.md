# TOP-LEVEL MULTI-TARGET RESTRUCTURE — DESIGN FOR REVIEW

Status: **design only, nothing built, nothing committed, nothing staged.**
Written against branch `multi-target` at `cfd84583a55` in
`/home/jcericson/src/gnu/gcc/multi-target`. Every number below was measured in
this session; the commands are given so they can be re-run. Where a figure in
the brief differs from what I measured, I say so.

---

## 0. THE RULING, RESTATED SO THE DESIGN CAN BE CHECKED AGAINST IT

1. The top-level `configure` takes **targets, plural**.
2. **There is no primary target.** Not a first, not a default, not a fallback.
   A single-target mode does not exist.
3. The top level owns **triple → back end**. `gcc/` receives a *back-end list*
   (`--enable-backends`, #66) and is host-and-build only.
4. `libgcc` and `target-specs` become **`target_module`s**, instantiated once
   per configured target with `--host=<target>`. Runtime libraries are
   **single-host**: plurality lives above them, never inside them.
5. Terminal state: **no `tm.h` in `gcc/` at all.**

Point 2 is what makes this hard, and it is the reason the design below is
shaped the way it is. Point 5 is the acceptance criterion for the whole
programme, and §7 shows it is the same task as the macro conversion.

---

## 1. THE INTERFACE: SPELLING "TARGETS, PLURAL"

### 1.1 What exists today, measured

- The top level declares **one** target, via `AC_CANONICAL_TARGET`
  (`configure.ac:83`) and `ACX_NONCANONICAL_TARGET` (`configure.ac:72`).
- **The top level does not pass `--enable-targets` down to `gcc` at all.**
  Measured: `grep -n 'enable_targets\|enable-targets' configure.ac
  gcc/configure.ac Makefile.def` returns **zero hits in the top-level
  `configure.ac` and zero in `Makefile.def`**; all 8 hits are inside
  `gcc/configure.ac`. Today's multi-target builds are configured by hand in
  `gcc/`, and the top level has never seen the target list. This is not a
  small gap — it means **no top-level component has ever had the list**, and
  therefore no existing top-level behaviour depends on its shape. The
  interface is genuinely unconstrained by back-compatibility *inside* the
  tree; only external scripts constrain it.

### 1.2 The three candidate spellings

**(a) Repeated `--target=<triple>`.**
Cost: autoconf's own `AC_CANONICAL_TARGET` consumes `--target` and keeps the
*last* one; `$target_alias` is a scalar. Supporting repetition means
intercepting `$ac_option` parsing before autoconf's generated case arms, which
is exactly the kind of hand-edit into generated `configure` that DEVSHELL
forbids. Worse, it is **silently lossy against every existing script**: a
wrapper that passes `--target=x` twice today gets the last one and is correct;
under the new scheme it gets two targets and a different tree layout, with no
diagnostic. Rejected.

**(b) `--targets=a,b,c` (plural, comma-separated).**
Cost: one new `AC_ARG_ENABLE`-style option, no interaction with autoconf's
canonicalisation machinery. `config.sub` is applied per element by our own
loop (as `gen-target-manifest.sh:100-118` already does — it canonicalises and
deduplicates, and **fails by name** on an unrecognised triple rather than
defaulting). Comma is already the separator `--enable-targets` uses
(`gcc/configure.ac:1625`), so the muscle memory is right.
Risk: a triple containing a comma. None exist; `config.sub` output never
contains one.

**(c) `--enable-targets=a,b,c` reused at the top level.**
Cost: it collides in *meaning* with `gcc/`'s current `--enable-targets`, which
after #66 becomes `--enable-backends`. Reusing the name across the boundary
during the transition guarantees a period where the same spelling means two
things at two levels — which is precisely the "shared numbering, many
authorities" failure recorded in memory. Rejected on that ground alone.

### 1.3 Recommendation

**`--targets=<comma-separated list>`, mandatory, no default.**

- **Mandatory** is the direct expression of "no single target ever": there is
  no fallback to `$host`, and omitting it is a hard error naming the option.
  This mirrors `gcc/configure.ac:1632-1634`, which already errors with
  `--enable-targets=LIST is required` rather than defaulting.
- `--target=` is **removed**, not aliased. An alias is a silent fallback with
  extra steps: `--target=x` would have to become `--targets=x`, i.e. a
  single-target build, i.e. the thing that must not exist. Removing it makes
  every existing invocation fail loudly at configure time with a message that
  names `--targets`. That is the correct failure: these scripts genuinely do
  need editing, and a build that quietly produced a one-element list would be
  a privileged primary reintroduced through the front door.
- `--host` and `--build` are untouched. This is fully consistent with the
  standing "avoid `--target`" rule: the dispatcher is the one component whose
  job *is* targets, and it now says so in a plural spelling that cannot be
  mistaken for a library's host.

**Canonicalisation.** `config.sub` runs per element in a loop we own, before
anything consumes the list. Two triples that canonicalise to the same string
are deduplicated (already implemented at `gen-target-manifest.sh:104-117`).
A triple `config.sub` rejects is fatal, named. **No element ever becomes empty
and is skipped** — that is the "absence of an answer becoming an answer"
shape, and it is the exact bug DEVSHELL records for `target-specs` SKIP.

**Ordering.** The list must be **sorted canonically** before use, and the
build must be **byte-identical for any permutation of the input**. This is not
tidiness: it is the enforcement mechanism for "no primary". If reordering
`--targets` changes any output, something is treating position 1 as
privileged, and a permutation test finds it. **Make this a CI arm** (§6.3).

---

## 2. MULTI-INSTANCE TARGET MODULES — THE CORE PROBLEM

### 2.1 Where the single-`$target` assumption is baked in — named, file and line

There is exactly **one** load-bearing site, and everything else is downstream
of it:

> **`config/acx.m4:101`** — `target_subdir=${target_noncanonical}`

That scalar is `AC_SUBST`ed (`config/acx.m4:105`) and lands in
**`Makefile.tpl:308`** — `TARGET_SUBDIR = @target_subdir@`.

Every target module is built under that one directory. The chain, all in
`Makefile.tpl`:

| Site | What it does |
|---|---|
| `Makefile.tpl:308` | `TARGET_SUBDIR = @target_subdir@` — the scalar |
| `Makefile.tpl:311` | `TARGET_CONFIGARGS = @target_configargs@ --with-target-subdir="$(TARGET_SUBDIR)"` |
| `Makefile.tpl:1511` | `[+ FOR target_modules +]` — the loop, once per *module*, never per target |
| `Makefile.tpl:1514,1525` | `[+ configure prefix="target-" subdir="$(TARGET_SUBDIR)" ... target_alias=(get "target" "${target_alias}") +]` |
| `Makefile.tpl:1238-1239` (DEFINE `configure`) | `--build=${build_alias} --host=[+host_alias+] --target=[+target_alias+]` |
| `Makefile.tpl:1002-1003` | `rm -rf $(TARGET_SUBDIR)` in clean |
| `Makefile.tpl:1779-1793, 1972` | bootstrap stage `mv stageN-$(TARGET_SUBDIR)` shuffling |
| `configure.ac:3523-3525` | force-reconfigure logic reads `${target_subdir}/${module}/Makefile` |
| `configure.ac:3250` | `tooldir='${exec_prefix}'/${target_noncanonical}` |

`Makefile.def` declares **26 `target_modules`** (`Makefile.def:182-226`);
`libgcc` is `Makefile.def:196`. `target-specs` is **currently a
`host_modules`** at `Makefile.def:51` and must move.

Note `Makefile.tpl:1238-1239`: the generated configure line **always passes
`--target=`**. For a target module `host_alias` is `${target_alias}` and
`target_alias` is `${target_alias}` — i.e. libgcc is already configured with
`--host=<target>`, and the `--target=` is redundant baggage autoconf's
consistency check wants. Under the new scheme the `--target=` argument for
target modules should be **dropped**, not made plural: a runtime library is
single-host and has no target. (Keep it for `host_modules` like `gcc`
temporarily; see §3.)

### 2.2 THE ROUTE: split the two loops between the two tools

**Direction received from the user, evaluated as the recommended route.
Verdict: it works, it is the right decomposition, and the evidence for it is
stronger than the direction claimed.**

> **autogen owns the module dimension (M). GNU make owns the target
> dimension (N).**
>
> AutoGen's `[+ FOR target_modules +]` (`Makefile.tpl:1509`) emits one
> *parameterised* block per module — the target left as a parameter instead
> of the hard-coded `subdir="$(TARGET_SUBDIR)"` and
> `host_alias=(get "host" "${target_alias}")` (`Makefile.tpl:1514, 1525`).
> GNU make's `$(foreach)`/`$(eval)` then expands each block across the
> configure-substituted target list, producing N×M rules at make time.

Neither tool is asked for information it cannot have: autogen runs before
configure and never learns the target list; make is handed M blocks and never
needs the module list statically. That is the whole argument and it is sound.

**The GNU-make premise is not merely "a constraint that has changed" — it was
never a constraint at this level.** Measured, `Makefile.tpl:29-33`:

```
@if gcc
ifeq (,$(.VARIABLES)) # The variable .VARIABLES, new with 3.80, is never empty.
$(error GNU make version 3.80 or newer is required.)
endif
@endif gcc
```

The top level has required **GNU make ≥ 3.80** all along, and `$(eval)` was
introduced in exactly 3.80. **The route sits precisely at the already-declared
floor and needs no new requirement at all.** `bb013cbe0f6`
(`Get rid of `with_multisrctop`, and `MULTISRCTOP``) is consistent with this
and is confirmed present in the branch's history.

⚠️ **One concrete defect in that guard, which this route makes load-bearing.**
The version check is wrapped in `@if gcc` — it only fires in a tree that
configured the `gcc` module. The `$(eval)` machinery would be emitted from a
configure substitution and would *not* be so guarded, so a non-GNU or
pre-3.80 make in a gcc-less tree meets `$(eval)` with no diagnostic and
produces an empty rule set. Fix: **move the version check out of `@if gcc` so
it is unconditional**, before any `$(eval)` is added. One line, and it is the
difference between "your make is too old" and a tree that configures and
builds nothing.

**Current GNU-only constructs in `Makefile.tpl`, measured:** `$(foreach)` ×1
(line 872), `ifeq` ×1, `ifneq` ×1, `$(eval)` **×0**; the generated
`Makefile.in` contains zero `$(eval)`. So `$(foreach)` and conditionals are
already established here and `$(eval)` is the one genuinely new construct.

#### Why this beats the two options I had identified

I accept the user's reasoning and it is better than mine:

- A checked-in `targets={}` block in `Makefile.def` (my option (A)) would
  reintroduce **"configured once, baked in"** — the exact property this whole
  effort deletes. I rejected it for the weaker reason that the list is not
  known at autogen time; the stronger reason is that even if it *were*
  knowable, encoding it there is the wrong shape.
- Generating `Makefile.def` from configure would make **autogen a
  configure-time dependency for every builder**, which it has never been.
  AutoGen is a maintainer tool; `Makefile.in` ships generated. I had not
  priced this and it is disqualifying on its own.

My option (C) — a make `define` parameterised by target — is the make half of
the user's route. What I got wrong is that I framed it as an alternative to
autogen rather than a **division of labour with it**, and consequently I
described the work as a "rewrite of `Makefile.tpl`'s target block" when it is
better described as *parameterising* that block and leaving its structure
intact. The revised cost is below.

#### Revised cost

The AutoGen side is small: `Makefile.tpl:1509-1644` stops hard-coding
`$(TARGET_SUBDIR)` and `${target_alias}` and takes them as `$(1)`/`$(2)`; the
`configure` and `all` DEFINEs (`:1197-1240` and the bootstrap variants) take
the same parameters. The block count is unchanged — 26 modules in, 26
parameterised blocks out.

The make side is the risk, and it is entirely **`$(eval)` quoting**: every `$`
in the recipes must be doubled, and the failure mode of getting it wrong is a
*silently empty recipe*, not an error. This is this project's signature bug
shape in a new location. Mitigation is mandatory and cheap: after the
`$(eval)` pass, assert every expected rule exists and is non-empty, modelled
on `gcc/Makefile.in:2649-2651`, which already refuses to link when
`MULTI_TARGET_OBJS` is empty and says why.

> ⚠️ **CORRECTED BY #113 — THE MITIGATION IN THIS PARAGRAPH DOES NOT WORK.**
> The probe was run (§8 item 1) and the route is confirmed to exist: 4/4 arms,
> N=2, `$(eval)` reproduces the shipped recipe text exactly. But the failure
> mode measured is **silently WRONG, not silently EMPTY**. Dropping one level
> of quoting on `$$(srcdir)` yields a complete, non-empty, plausible recipe
> with the *call-time* value baked in where a deferred `$(srcdir)` belonged.
> **A non-emptiness assertion scores that as a pass.** The check must diff
> rule text against a literal control, not measure its length. See
> `scratchpad/t113-eval-probe.sh` (arm 4) and the #113 entry in STATE.md.
> Two further measured facts land there: `$(call)`/`$(eval)` **collapses
> backslash-newline continuations**, so a raw text diff goes red on a correct
> change; and **`make -n` executes recipe lines containing `$(MAKE)`**, which
> disqualifies `--dry-run` as the instrument for §6.3's permutation harness.

**Revised estimate: 2 weeks** (down from 2–3), because the AutoGen structure
survives rather than being rewritten.

### 2.2a What the route does NOT solve — sized

**(a) Rule-name collisions.** `all-target-libgcc` carries no target component,
so N instances collide whichever tool emits them. Names need a target element
— `all-target-libgcc-<triple>` or `all-<triple>-libgcc`.

Measured blast radius, and it is **much smaller than feared**:

- `Makefile.def` has **272** `dependencies` lines; **44** name a target
  module. The user's figure of 44 is exactly right.
- Of those 44: **39 are target → target** (`all-target-libgo` on
  `all-target-libatomic`). **These need no decision at all** — both sides take
  the same target suffix, so a mechanical rewrite that appends `-$(1)` to both
  names is correct by construction, and correct for every N.
- Only **5 are cross-kind**, and they are the entire hard part:
  - `all-gnattools` on `all-target-libada`
  - `all-gnattools` on `all-target-libstdc++-v3`
  - `all-gotools` on `all-target-libgo`
  - `configure-target-newlib` on `all-binutils`
  - `configure-target-newlib` on `all-ld`

  The first three are **host tools depending on a target library, and they do
  not say which target**. Under "no primary" there is no defensible answer
  except "all of them" or "gnattools/gotools become per-target too". That is a
  genuine design question and it should be put to the reviewer explicitly; it
  is the only place in the 44 where the ruling bites. The last two are
  target → host and replicate trivially (every target's newlib waits for the
  one binutils).
- **Outside `Makefile.def` and the top-level `Makefile.in`, exactly one file
  in the tree types these names**: `gcc/Makefile.in:2572`
  (`cd $(toplevel_builddir) && $(MAKE) all-target-libgcc`). Measured by
  `grep -rln` over `*.sh`, `*.py`, `Makefile*`, `*.exp`; stderr asserted
  empty. **One site.**

  Caveat, and it is the standing one: *absence of an artefact is not absence
  of a mechanism.* This grep bounds files that spell the name literally. CI
  configs, distro packaging and developers' fingers are outside the tree and
  outside this measurement. `all-target-libgcc` is a name people type. Whatever
  scheme is chosen, **the old unsuffixed names should be kept as aliases that
  fail by name** ("`all-target-libgcc` is ambiguous in a multi-target build;
  use `all-target-libgcc-<triple>`, one of: …") rather than either working or
  producing "no rule to make target".

**(b) The scalars.** Three families, measured:

- **`config/acx.m4:101`'s `target_subdir`** — one line, already identified as
  *the* baking point (§2.1). Becomes a list.
- **The `_FOR_TARGET` variables.** The user says ~30; **measured 45 distinct
  names** across `Makefile.tpl` and `configure.ac` (`AR_FOR_TARGET`,
  `CC_FOR_TARGET`, `CXX_FOR_TARGET`, `GCC_FOR_TARGET`, `FLAGS_FOR_TARGET`,
  `SYSROOT_CFLAGS_FOR_TARGET`, … full list captured). **This is the largest
  single item in the whole restructure by site count** and it is 50% larger
  than briefed. Each is a scalar answer to a per-target question:
  `AS_FOR_TARGET` is *which assembler*, and with N targets there are N. Note
  this is the same failure DEVSHELL already records from the other end —
  `target-specs` silently skips a target whose `<triple>-as` is not on PATH,
  and the symptom surfaces three steps downstream as
  `option_init_struct ... before a target was selected`. Making these
  per-target is what turns that into a named configure-time error.
- **Bootstrap staging.** The user says nine `bootstrap=true` modules;
  **measured 6 target modules** with `bootstrap=true` (`Makefile.def:196`
  libgcc, `:199` libbacktrace, `:206` libphobos, `:217` zlib, `:222` libgomp,
  `:224` libatomic). The nine presumably counts host modules too. The
  `mv stage[+id+]-$(TARGET_SUBDIR) $(TARGET_SUBDIR)` shuffle
  (`Makefile.tpl:1779-1793`, `:1972`) becomes a loop over the target list.
  Sharpest hazard: those `mv`s are prefixed `-`/guarded by `|| test -f`, so a
  missing directory is currently *ignored*. With N targets that silence
  becomes "one target's stage tree vanished and the build continued". **Every
  such `mv` must fail by name if its source is absent for a configured
  target.**

**(c) Multilib.** Confirmed as an asset, per §2.4 — the per-target dimension is
added *outside* the directory config-ml.in owns, so they nest. But see §2.6:
they nest, they do not merge, and the mechanism cannot be reused to express a
second triple.

### 2.2b The options as originally weighed (retained for the record)

AutoGen's `FOR` iterates over *definitions in `Makefile.def`*, not over
configure-time values. It cannot loop over `--targets` because that list does
not exist when `Makefile.in` is generated. Three options:

**(A) Nested `FOR` over a target list in `Makefile.def`.** Requires the target
list at autogen time. Impossible — the list is a configure argument. Rejected.

**(B) N literal expansions at configure time.** Have `configure` emit, into a
generated `multi-target-modules.mk` (`-include`d by the top-level `Makefile`),
one copy of every target-module rule per configured target. This is the same
technique `gcc/` already uses successfully and at scale:
`gcc/gen-target-manifest.sh` writes `multi-target-common.mk` with one rule per
target (`gen-target-manifest.sh:76-78, 273-300`), and `gcc/Makefile.in:676`
`-include`s it; `gen-multi-target-md.awk` writes `multi-target-md.mk`
(`gcc/Makefile.in:1360-1365, 1388`). **The precedent is in-tree and working.**

**(C) Restructure `Makefile.tpl` so the target-module block is a make macro
(`define`/`$(eval $(call ...))`) parameterised by target**, with configure
emitting only `$(eval $(call target_module_rules,libgcc,aarch64-...))` lines.

**Superseded by §2.2.** (C) is the make half of the accepted route; (A) and (B)
are rejected for the stronger reasons given there. Retained because the size
arguments below still hold.

Reasons (C) beat (B), in order:

- (B) alone means `Makefile.in` grows by (rules per module) × (26 modules) ×
  (N targets). Measured basis: the target-module section of `Makefile.tpl`
  spans lines 1509-1644 plus the `configure`/`all` DEFINEs (1197-1240 and the
  bootstrap variants to ~1400) — the *expanded* `Makefile.in` target-module
  region is the dominant part of its size. Multiplying that by N literally is
  how you get a 40 MB `Makefile.in` at N=8. Unacceptable.
- (C) keeps one copy of the recipe text and pays only one `$(eval)` line per
  (module, target) pair — 26 × N lines. At N=8 that is 208 lines. Bounded.
- (C) does not require AutoGen changes at all: `Makefile.tpl` still runs
  through AutoGen once, but the target-module `FOR` body becomes a
  `define`/`endef` block instead of literal rules. The AutoGen loop is still
  over *modules*; the per-target dimension is added by make, at make time.

**Cost estimate.** The rewrite touches `Makefile.tpl` lines 1509-1644 (the
target-module block, ~135 lines), the two DEFINEs `configure` (1197-1240) and
`all`, the bootstrap-stage variants, and the ~12 `[+ FOR target_modules +]`
aggregation sites listed in §2.1's table. `$(eval)`-safe quoting is the real
work: every `$` in those recipes needs doubling, and getting that wrong
produces recipes that silently expand to empty rather than erroring. **That is
a fail-silent shape and needs a test that asserts each generated rule is
non-empty** (§6), modelled on `gcc/Makefile.in:2649-2651`, which already
refuses to link when `MULTI_TARGET_OBJS` is empty and says why.

### 2.3 Build-directory layout: side-by-side trees

```
<builddir>/
  build-<build_noncanonical>/      unchanged
  host-<host_noncanonical>/        unchanged (gcc, binutils, ... — ONE gcc)
  <target1_noncanonical>/          libgcc/ target-specs/ libstdc++-v3/ ...
    libgcc/
      <multilib-1>/                config-ml.in's subdirs, unchanged
      <multilib-2>/
  <target2_noncanonical>/
    libgcc/
      ...
```

This is **exactly today's layout with the scalar made plural**, which is the
argument for `target_module`: the per-triple dimension is added *outside* the
directory that multilib already owns, so the two nest rather than compete.
`target_subdir` stops being a scalar and becomes a list; `TARGET_SUBDIR`
disappears from `Makefile.tpl` and is replaced by the per-target parameter of
the `$(eval $(call ...))`.

Bootstrap staging (`Makefile.tpl:1779-1793`) shuffles `stageN-$(TARGET_SUBDIR)`
and must become a loop over the target list. This is mechanical but it is the
part most likely to break silently: a `mv` of a directory that does not exist
under `-` prefix is ignored today. **Every such `mv` must be made to fail by
name if its source is absent for a target that was configured.**

`tooldir` (`configure.ac:3250`) becomes per-target
`${exec_prefix}/${target_noncanonical}` — one per element. This is already the
GNU convention for a multi-target install and needs no invention.

### 2.4 Does `libgcc`'s multilib handling compose or fight?

**It composes, and the reason is structural.** Three facts:

1. `Makefile.tpl:1209-1222` (`check_multilibs`) runs
   `$(CC_FOR_TARGET) --print-multi-lib` and caches it in
   `[+subdir+]/[+module+]/multilib.out`. That is *already* per-`subdir`, so
   making `subdir` per-target makes the multilib probe per-target with no
   change to its logic.
2. `config-ml.in:177-178` gates the entire mechanism on
   `${enable_multilib} = yes`, which `configure.ac:3877` now passes
   unconditionally (`target_configargs="--enable-multilib ${target_configargs}"`)
   — the comment there records that the old guard tested a variable nothing
   sets. So multilib is genuinely mandatory and unconditional, as the brief
   states.
3. `config-ml.in` creates its subdirectories *below* the module's own build
   directory, re-invoking the module's `configure` with the same `--host`.
   Per-target instances therefore never share a `config-ml.in` scope.

**The one real hazard.** `Makefile.tpl:1212` and `:1257` both write
`--print-multi-lib > .../multilib.tmp 2> /dev/null`. That is the DEVSHELL
failure verbatim: a `CC_FOR_TARGET` that does not exist produces an **empty**
`multilib.out`, which reads as "one multilib, the default" rather than as an
error. With N targets there are N chances to hit it and the resulting tree
looks plausible. **This must be fixed as part of the work, not after**:
capture stderr to a file, assert it empty, assert the output non-empty, and
fail naming the target. It is a two-line change and it is the single
highest-value defensive edit in this whole design.

### 2.5 `libgcc`'s coupling to the enclosing `gcc` build dir — surveyed

The survey came back and it changes two things in this design.

**What composes cleanly:**

- `libgcc/configure.ac` has **no** `AM_ENABLE_MULTILIB` / `config/multi.m4`
  use at all. It hand-rolls the hook at `libgcc/configure.ac:1037-1054`,
  sourcing `config-ml.in` at `:1044`. Its own `config.host` reads **12**
  `enable_*`/`with_*` variables — `enable_darwin_at_rpath`,
  `enable_vtable_verify`, `enable_shared`, `with_multisubdir`, `with_gnu_ld`,
  `with_libf7`, `with_avrlibc`, `with_fixed_point`, `with_system_libunwind`,
  `with_newlib`, `with_nds32_lib` — **all of which are libgcc's own configure
  options arriving via `TARGET_CONFIGARGS`, none read from `gcc`'s build dir.**
  Twelve per-instance options is entirely tractable under `--host=<target>`.
- `libgcc/Makefile.in:23,25`:
  `gcc_objdir = $(MULTIBUILDTOP)../../$(host_subdir)/gcc`. The `../../` assumes
  libgcc sits at `<target_subdir>/libgcc/`. **Under the side-by-side layout of
  §2.3 that depth is unchanged**, so this path keeps working without edit.
- This branch has **already** moved several probes out of `gcc`'s
  `auto-host.h` into libgcc's own `auto-target.h` — `libgcc/configure.ac:237-245`
  (`sys/sdt.h`, `dl_iterate_phdr`), `:247-283` (`HAVE_GAS_HIDDEN`,
  `HAVE_GAS_WEAK`), `:355-398` (`LIBGCC_HAVE_LD_EH_FRAME_HDR`, deliberately
  renamed so gcc's `tm.h` default cannot override it), `:400-415`
  (`__cxa_atexit`). Commits `3cb734407ac`, `2d129bb3dfb`, `d91e716c4d7`,
  `f20d6148812`, `90d451f3e88`. **That programme is the right shape and it is
  already underway.**

**What fights, and it is the single worst finding in this document:**

> `libgcc/Makefile.in:285-286` — `INCLUDES = -I. -I$(@D) -I$(gcc_objdir) ...`
>
> That `-I$(gcc_objdir)` is how `tconfig.h` pulls in `auto-host.h` **and the
> generated `tm.h`** from the `gcc` *build* directory into every libgcc
> object. Consumers: `libgcc/crtstuff.c:73`, `emutls.c:26`,
> `unwind-compat.c:26`, `offloadstuff.c:37`, `fixed-bit.c:45`, `fp-bit.c:36`,
> `generic-morestack.c:31`, `generic-morestack-thread.c:26`, `strub.c:26`.

There is **one** `gcc_objdir` and it holds **one** bare `tm.h` — the
primary's. So today, **every target's libgcc is compiled against the primary
target's `tm.h`.** This is `LIBCALL_VALUE` again, in the runtime library, and
it is exactly what the ruling "crt belongs to libgcc, not gcc" was meant to
prevent. `gcc/Makefile.in:620-631` already carries an in-tree FIXME saying
`FIXINCLUDES_MACHINE` and "the whole `GCC_TARGET_TEMPLATE` list" still come
from gcc's `$host` and reach libgcc through `tconfig.h`.

**Consequence for the plan:** "no `tm.h` in `gcc/`" (§5) is not only a `gcc/`
job. Until `gcc_objdir`'s `tm.h` is gone or per-target, N libgccs built
side-by-side will all be built against one target's headers and **will look
correct**. This is a **Stage 3 blocker**, not a Stage 6 item: the moment
libgcc becomes multi-instance, this leak goes from "wrong for the one
non-primary case nobody builds" to "wrong for N−1 of N trees we ship". It is
added to the plan as Stage 3a.

`libgcc/Makefile.in:184` (`include $(gcc_objdir)/libgcc.mvars`, produced by
`gcc/Makefile.in:2900-2905`) has the same singular problem and the same fix
shape: per-target `libgcc.mvars`.

Two smaller notes: `MULTILIB_CFLAGS` is used at `libgcc/Makefile.in:303` and
**defined nowhere in libgcc** — dead, and another empty-means-default site.
`libgcc/configure.ac:1050` *prepends* `--enable-multilib` to
`ac_configure_args`, and `config-ml.in:174` is last-one-wins, so it is a weak
default rather than the mandate it reads as.

### 2.6 A correction to the framing: multilib and multi-target do not unify

The brief says "multi-target is multilib generalised across triples". At the
level of **directory layout** that is true and it is why `target_module` is
the right class. At the level of **`config-ml.in`'s mechanism it is false**,
and the design must not assume otherwise:

`config-ml.in:938-940` re-runs the *same* configure script with the
**identical `${ac_configure_args}`** — same `--host`, same `--build` — and
differentiates a multilib **only** by `CC="$CC $flags"` (`:790`), where
`$flags` is the `;`-suffix of a `--print-multi-lib` line (`:782-789`). Its
target-specific filtering is `case "${host}" in` (`:233-489`), with an
explicit comment at `:232`: *"Target libraries are configured for the host
they run on, so we check `$host` here, not `$target`."*

So a multilib is modelled as **one triple plus compiler flags**. A second
target is **a different triple**, which that encoding cannot express. The two
mechanisms **nest** (per-target dir, then per-multilib subdir inside it) but
do not merge. Anyone who tries to express the second target as a multilib will
hit `config-ml.in:940`'s argument replay, the `${dir};${flags}` encoding, and
the `case "${host}"` filters — three places at once.

⚠️ #37 records that **target libraries beyond `libgcc`** still take gcc's
build-time config. The survey above covers `libgcc` only. `libstdc++-v3`,
`libgomp`, `libatomic` and the other 23 target modules are **not surveyed**
and each may have its own `-I$(gcc_objdir)`.

---

## 3. MOVING THE TRIPLE → BACK END MAPPING

### 3.1 The ~70, measured

The brief says `config.gcc` reads "~70" of configure's `enable_*`/`with_*`
variables. **Measured: 64 distinct names appear in `gcc/config.gcc`**
(`grep -oE '\b(enable|with)_[A-Za-z0-9_]+' gcc/config.gcc | sort -u` → 64).

Of those 64, splitting reads (`${v}`) from assignments (`v=`):

- **51 are genuinely read** at least once with no prior assignment in
  `config.gcc`, i.e. they must come from the enclosing configure.
- **13 are never read** by `config.gcc` (`with_advance_toolchain`,
  `with_cmodel`, `with_compact_branches`, `with_divide`, `with_fp_32`,
  `with_fpu_config`, `with_lxc1_sxc1`, `with_madd4`, `with_mips_plt`,
  `with_mode`, `with_msa`, `with_nan`, `with_nds32_lib`, `with_odd_spreg_32`,
  `with_picolibc`, `with_riscv_attribute`, `with_strict_align_lib`,
  `with_synci`, `with_tune_64`) — these are pure outputs or dead. (That list
  is 19 names; several also appear as assign-only, so the read/assign split
  is not a clean partition. The number that matters is the **51 inputs**.)

**So "~70" is high but the right order of magnitude; the accurate figure is
64 names, 51 of them inputs.** The heaviest readers, by occurrence count:
`with_cpu` (47), `with_multilib_list` (32), `with_arch` (20), `enable_threads`
(19), `with_endian` (15), `with_abi` (11), `enable_targets` (8).

One finding worth flagging on its own: **`with_multllib_default` is read twice
in `config.gcc` and is a typo** for `with_multilib_default`. `grep -c` says
reads=2, assigns=0, and no configure anywhere sets that spelling. It is
therefore always empty — a live instance of "absence of an answer becoming an
answer", sitting in the file this design has to move. Worth a separate
one-line fix and a check of what the two sites intended.

### 3.2 Why sourcing is required, and what that costs

`gcc/gen-target-manifest.sh:33-40` states the reason and it is correct:
configure does not export these variables, so a child process sourcing
`config.gcc` sees them unset and produces a *different, silently plausible*
answer. `gcc/configure.ac:1646` sources the script; the script's inner loop
(`gen-target-manifest.sh:121-133`) runs `config.gcc` inside a **command
substitution subshell** with a documented clear-list of the *output* variables
(`tm_defines cpu_type target_cpu_default tm_file tm_p_file tmake_file
extra_objs extra_options extra_headers out_file md_file target_gtfiles
common_out_file target_has_targetm_common dwarf2 extra_modes
TM_MULTILIB_CONFIG`) while **inheriting** the 51 inputs. That is the correct
design and it already works.

### 3.3 The three options for moving it up

**(i) Carry the coupling to the top level.** Declare all 51 input variables in
the top-level `configure.ac` and source `config.gcc` there.
Cost: the top level acquires 51 target-shaped `--with-`/`--enable-` options it
does not otherwise want. But note: **many of them are already declared at the
top level or are inherently per-target** — `--with-cpu`, `--with-arch`,
`--with-abi`, `--with-multilib-list`, `--with-float`, `--with-endian` are all
statements *about one target*. With N targets they cannot remain scalar
either. This is the hidden cost nobody has priced: **moving the mapping up
forces every one of those 51 to become per-target too**, or to be declared
inapplicable.

**(ii) Restructure `config.gcc`'s interface.** Make `config.gcc` take its
inputs as named parameters rather than ambient shell variables — i.e. runnable
as a child with an explicit environment. Cost: an edit at every one of the 51
read sites plus a wrapper; 4,953 lines of `config.gcc` to audit. Large, but
**mechanical and testable**: the acceptance test is that for every triple in
`contrib/config-list.mk`, sourced and executed forms produce byte-identical
output. That test is cheap to write and is a genuine control.

**(iii) Split the mapping from the rest of `config.gcc`.** Extract only
*triple → back-end name* (the `cpu_type` / `out_file` / `common_out_file` /
`tm_file` skeleton) into a new file with **no** `enable_*`/`with_*` inputs,
leaving the per-target *tuning* (`with_cpu` defaults, multilib lists, thread
models) in `config.gcc` where the target module can consult it.

**Recommendation: (iii), with (ii) as the fallback if (iii)'s split line
cannot be drawn cleanly.**

The reason is that (iii) is the only one that respects "gcc/ is host-and-build
only". What `gcc/` needs after #66 is a **back-end list** — `i386`, `aarch64` —
which is exactly what (iii)'s extracted file produces and which needs **none**
of the 51 variables. Everything the 51 variables influence is either a
*target-module* concern (multilib lists, thread model, ABI defaults → belongs
with `libgcc`/`target-specs`, configured per target with `--host=<target>`,
where a scalar `--with-cpu` is legitimate again because that instance has
exactly one host) or a *spec* concern (already being moved to `target-specs`
by #65).

**The measurement that decides (iii)'s feasibility, and which I have not
made:** how many of the 51 inputs can change `cpu_type`, `out_file`,
`common_out_file` or the `tm_file` *set* — as opposed to only changing
`tm_defines`/`with_cpu` defaults. If that number is zero or near-zero, (iii)
is clean. `enable_targets`, `enable_fdpic`, `enable_multilib` and
`with_multilib_list` are the likely offenders. **This is a half-day probe and
it should be run before the design is approved**, because it is the single
fact (iii) stands on. See §8.

---

## 4. DELETING THE PRIMARY — THE INVENTORY

### 4.1 `$target` in `gcc/configure.ac`: the residue is small and enumerable

Measured: 22 textual matches for `${target}`, of which the **live** uses are:

| Line | Use | Fate |
|---|---|---|
| `1587-1595` | canonicalise `${target}` before `config.gcc` | **disappears** — the loop in `gen-target-manifest.sh:100-118` already canonicalises |
| `1598` | `. ${srcdir}/config.gcc` for the primary | **disappears** — this *is* the primary |
| `1639` | `gcc_manifest_targets="${gcc_extra_targets} ${target}"` | **disappears** — the list comes whole from above |
| `1808` | `if test x$host = x$target` | becomes a host-side question or disappears |
| `2776, 2781` | `libatomic_target=${target}`, `TARGET_PROVIDES_LIBATOMIC` | **becomes per-target** — belongs to the target module |
| `3091` | `lang.${target}` Make-hooks | this is a *make target* named `$target`, unrelated — **false positive, no change** |
| `3262-3274` | "Links are now set up…" messages | cosmetic; becomes plural |
| `3398` | `build_target_triple=${target}` | **disappears** — see below |

`build_target_triple` (`gcc/configure.ac:3398`) is the sharpest instance of
the bug shape: it is "the triple the target libraries in THIS BUILD TREE are
being built for", a scalar answer to a question that now has N answers. It
must not become "the first one".

**This is the good news in the whole design: `gcc/configure.ac` is already
~90% free of the primary.** The 7,982 → 3,449 cut did most of this work. What
remains is ~8 sites.

### 4.2 The singular `@…@` substitutions — measured inventory

Cross-referencing every `@VAR@` in `gcc/Makefile.in` against every variable
assigned in `gcc/config.gcc` gives **23 target-derived singular
substitutions**:

```
common_out_file   c_target_objs     cxx_target_objs   d_target_objs
extra_gcc_objs    extra_objs        extra_programs    fortran_target_objs
inhibit_libc      jit_target_objs   md_file           out_file
rust_target_objs  target_cpu_default tmake_file       tm_defines
TM_MULTILIB_CONFIG  TM_MULTILIB_EXCEPTIONS_CONFIG
use_gcc_stdint    user_headers_inc_next_post  user_headers_inc_next_pre
xmake_file        xm_defines
```

Taking the brief's list item by item, with what I measured:

| Name | In `gcc/Makefile.in`? | Verdict | Depends on `tm.h` removal? |
|---|---|---|---|
| `tmake_file` | `@tmake_file@` ×1 | **disappears from `gcc/`.** A tmake fragment is target-library build configuration; it belongs to the target module. | **Independent** — it is Makefile-level, not header-level. |
| `out_file` | `@out_file@` ×1 | **becomes per-target.** Already is, in fact: `MULTI_TARGET_OBJS` (`gcc/Makefile.in:1387-1388`) and `multi-target-md.mk` build one object set per back end. The `@out_file@` is the leftover primary. | Independent |
| `out_object_file` | `@out_object_file@` ×1 (`gcc/Makefile.in:648`), rule at `:3505` | **disappears.** Superseded by `MULTI_TARGET_OBJS`; `Makefile.in:2642-2643` already documents that `OBJS` names `$(MULTI_TARGET_OBJS)` rather than the primary's `$(out_object_file)`. | Independent |
| `OBJS` | **not a substitution** — literal list at `gcc/Makefile.in:1679`, includes `$(MULTI_TARGET_OBJS)` at `:1683` | **already a genuine host-side singleton.** Correct as is. | Independent |
| `EXTRA_GCC_OBJS` | `gcc/Makefile.in:953` `EXTRA_GCC_OBJS =@extra_gcc_objs@` | **becomes per-target and is a known live blocker.** `gcc/Makefile.in:3126-3130` records it precisely: arm's `target_mode_check`, loongarch's `driver_init`, avr's `double-lib` live in `config/<cpu>/driver-<cpu>.cc`, linked through `extra_gcc_objs`; 13 of 183 targets' spec files are rejected for exactly this. This is the **spec-function registry problem**, and `gen-target-manifest.sh` already builds `gcc_all_spec_fn_objects` (`:85-90`) as the union. | Independent |
| `target_gtfiles` | **not `@target_gtfiles@`** — reaches `Makefile.in:4104` as `@all_gtfiles@`, set at `gcc/configure.ac:2962` from `gcc_all_target_gtfiles` | **already fixed.** `gcc/configure.ac:2921-2924` documents the switch from the primary's `target_gtfiles` to the union over every back end, folding in each `$(out_file)`. Genuine union, no primary. | Independent |
| `INCLUDE_DEFAULTS` | **not a substitution at all** — a *macro*, `gcc/cppdefault.cc:129-137` | **disappears with `tm.h`.** `cppdefault.cc:50` already carries the comment "Guarded, because a target header that supplies its own `INCLUDE_DEFAULTS`…" and `:134` names the job as "getting `INCLUDE_DEFAULTS` itself out of the privileged target's `tm.h`". This one is **squarely a `tm.h` dependent.** |

**Correction to the brief:** three of the seven named items (`OBJS`,
`target_gtfiles`, `INCLUDE_DEFAULTS`) are **not `@…@` substitutions**, and two
of them (`OBJS`, `target_gtfiles`) are **already correct**. The remaining
singular substitutions that nobody has listed are the six `*_target_objs`
families (`c_`, `cxx_`, `d_`, `fortran_`, `jit_`, `rust_`) — front-end target
hooks, one set for the primary, serving all N. **Those are un-inventoried
primary leaks and they are exactly the `LIBCALL_VALUE` shape.** They should be
added to the tracked list.

### 4.3 What "no primary" buys

The argument, stated for the record because it is the justification for
sequencing build work ahead of more macro conversion:

Every bug this project has spent effort on has one shape — a component serves
the primary's answer to everyone, and *looks correct* because the primary is a
real, consistent target. `targetm` copied not pointed; `SImode` 18 vs 17;
`NUM_REGISTER_FILTERS` 0 vs 4; `LIBCALL_VALUE` returning i386 registers for
every target. Each was found by building a better instrument after the last
one came back clean.

With no primary, the same defect **cannot look correct**: there is no
consistent target whose answers to serve. A component that answers with one
target's data becomes visibly asymmetric under permutation of `--targets`
(§1.3). **The build-system restructure is not a prerequisite for the macro
conversion in a dependency sense — it is the instrument that makes the
remaining conversion work self-reporting.** That is the strongest argument for
doing it first, and it should be the one made to the reviewer.

---

## 5. THE TERMINAL STATE: NO `tm.h` IN `gcc/`

### 5.1 The 521/623 figure — verified, and it is worse than reported

Measured from the builds' own `.deps`, `grep -lE "(^|[ /])tm\.h( |$|\\)"`:

| build dir | TUs | include `tm.h` | % |
|---|---|---|---|
| `/tmp/b-tp` | 622 | **520** | 83.6% |
| `/tmp/b-objs` | 632 | **526** | 83.2% |
| `/tmp/b-a79` | 630 | 526 | 83.5% |
| `/tmp/b-slg2` | 629 | 525 | 83.5% |
| `/tmp/b-stock` (upstream at `c31b7a09eea`) | 561 | **472** | **84.1%** |
| `/tmp/b-ref1` | 562 | 466 | 82.9% |

**The brief's "521 of 623" is confirmed** — `/tmp/b-tp` gives 520/622, within
one of the quoted figure (the difference is which dep files were current at
measurement time). Stderr was empty on every run; the tools were asserted
present first.

**The finding the figure does not carry, and which matters more:** upstream
GCC is at **84.1%** and this branch is at **83.4%**. *The macro conversion
programme has not measurably reduced `tm.h`'s reach.* It has changed what
`tm.h` *means* for the per-target objects — `/tmp/b-objs/gcc/` contains
`i386-inc/tm.h` and `aarch64-inc/tm.h`, included by 22 and 82 dep files
respectively — but the **952 references to the bare, primary `tm.h`** are
untouched.

That is the honest size of the gap to the terminal state: **~520 TUs must stop
including `tm.h`**, and 0 of them have so far. The per-target `-inc/tm.h`
mechanism is the *back-end* half, which works; the *middle-end* half has not
started.

### 5.2 Why "delete `tm.h`" and "finish the macro conversion" are one task

Confirmed by construction: the only thing `tm.h` does for a middle-end TU is
export target macros. If no middle-end TU spells a target macro, no
middle-end TU needs `tm.h`, and the `#include "tm.h"` lines can be deleted
mechanically. Conversely, as long as one middle-end TU spells
`BYTES_BIG_ENDIAN`, `tm.h` must be there.

**So the macro programme has a definition of done, and it is falsifiable in
one command:** `grep -l 'tm\.h' <builddir>/gcc/.deps/* | wc -l` reaching the
set of TUs that legitimately are per-back-end objects (currently ~104 via the
`-inc` paths). Everything above that number is remaining work. **This should
replace the open-ended macro burn-down as the programme's headline metric** —
it is measured from the build, not from a hand-maintained list, and it cannot
be gamed by reclassifying a macro.

### 5.3 Prerequisite vs independent

**Prerequisites for removing `tm.h`** (must land first):
- Nothing in the top-level restructure is a hard prerequisite. `tm.h` removal
  is entirely inside `gcc/`.

**Independent, but strongly sequencing-relevant:**
- Removing the primary from the build system makes the remaining `tm.h` users
  *visible*. Today a TU that includes `tm.h` and reads `UNITS_PER_WORD`
  compiles and produces plausible code. With no primary there is no
  `tm.h` to include and the TU fails to compile — **by name, at the include**.
  That converts an open-ended audit into a compiler-enforced worklist.
- This is the argument for sequencing the build work first, and it is the
  strongest one available. State it to the reviewer in these terms.

**Dependent on `tm.h` removal:** of the inventory in §4.2, only
`INCLUDE_DEFAULTS`. Everything else is Makefile-level and independent.

---

## 6. STAGED PLAN

Each stage is independently landable and leaves the tree building. The rule
holds: landing a subset is fine; leaving a non-linking `cc1` blocks everyone.

**Stage 0 — the free intermediate: move the target-*list* computation up.**
Per the user's direction, this is Stage 0 and it is genuinely free. Today
`gcc/configure.ac:1604-1627` computes `gcc_extra_targets` from
`--enable-targets` — including the `--enable-targets=all` case, which shells
out to `contrib/config-list.mk` (`:1612-1619`). **That computation is pure
list arithmetic: it reads no `enable_*`/`with_*` target variable, sources no
`config.gcc`, and touches none of the nine blockers.** Moving just it to the
top level and passing the resulting list down is ~25 lines across 2 files.

What it buys is out of proportion to its size: **it is the first time the top
level has ever known the target list** (§1.1), and every later stage needs
that fact to be true. It also lets `--targets=` (Stage 2) be introduced with a
real consumer instead of as a dead option.
*Cost: 1 day. Fully revertible.*

**Stage 0b — defensive, zero behaviour change. Land alongside Stage 0.**
- Move `Makefile.tpl:29-33`'s GNU make version check out of `@if gcc` so it is
  unconditional, **before** any `$(eval)` is introduced (§2.2).
- Fix `Makefile.tpl:1212` and `:1257`: `--print-multi-lib 2> /dev/null` →
  capture, assert stderr empty, assert output non-empty, fail naming the
  module and target. (§2.4)
- Fix `with_multllib_default` typo in `config.gcc` (§3.1), after determining
  what its two sites intended.
- Add the permutation test harness (§6.3) as a no-op arm against today's
  single-target build.
*Landable alone. Cost: 1 day. No point of no return.*

**Stage 1 — the mapping probe.** Measure which of the 51 `config.gcc` inputs
can change `cpu_type`/`out_file`/`common_out_file`/`tm_file`-set, for every
triple in `contrib/config-list.mk`. Decide (iii) vs (ii) (§3.3). Produces a
number, not a code change.
*Cost: 0.5–1 day. This gates the design, not the build.*

**Stage 2 — `--targets` at the top level, list of one.** Add `--targets=`,
remove `--target=`, canonicalise and deduplicate per element, `AC_SUBST` the
list. Nothing consumes the plural dimension yet; `target_subdir` still takes
element 1. **This deliberately keeps a primary**, so it is landable and the
tree builds.
*Cost: 2–3 days. Still no point of no return.*

**Stage 3 — target modules become multi-instance.** `Makefile.tpl` target
block → `define`/`$(eval $(call ...))`; configure emits
`multi-target-modules.mk`; `libgcc` and `target-specs` built once per target
under `<target>/`. `target-specs` moves `Makefile.def:51` from `host_modules`
to `target_modules`. Bootstrap staging looped. `tooldir` per target.
*Cost: 2–3 weeks, dominated by `$(eval)` quoting and bootstrap staging.*

**Stage 3a — `gcc_objdir`'s singular `tm.h` and `libgcc.mvars`, per target.**
(§2.5.) Must land **with** Stage 3, not after: the moment N libgccs exist,
`libgcc/Makefile.in:285-286`'s `-I$(gcc_objdir)` builds N−1 of them against
the wrong target's headers, and they will compile. Fix shape: per-target
`libgcc.mvars` and a per-target include dir, mirroring the `<base>-inc/tm.h`
mechanism `gcc/` already has (`/tmp/b-objs/gcc/i386-inc/tm.h`,
`aarch64-inc/tm.h`).
*Cost: 3–5 days.*

**This is the point of no return.** Once `TARGET_SUBDIR` is gone from
`Makefile.tpl`, there is no single-target build of this tree, `/tmp/b-ref1`
stops being reproducible, and every acceptance arm that used it must already
have been replaced (§6.2). Do not enter Stage 3 until §6.2 is done and green.

**Stage 4 — the mapping moves up.** Per Stage 1's verdict. `gcc/` receives
`--enable-backends`; `gcc/configure.ac`'s 8 residual `$target` sites (§4.1)
are removed or made per-target. `build_target_triple` deleted.
*Cost: 1–2 weeks if (iii); 3–4 weeks if (ii).*

**Stage 3b — rule names take a target element.** (§2.2a(a).) 39 of the 44
`Makefile.def` target-module dependency lines rewrite mechanically; 5 need a
decision; 1 in-tree consumer (`gcc/Makefile.in:2572`). Old unsuffixed names
retained as aliases that **fail by name** with the list of valid targets.
*Cost: 2–4 days, plus the gnattools/gotools decision (§2.2a(a)).*

**Stage 5 — the `*_target_objs` families and `extra_gcc_objs`.** The six
front-end hook sets and the driver spec-function registry (§4.2). This is what
unblocks the 13 rejected spec files and #63.
*Cost: 1–2 weeks.*

**Stage 6 — `tm.h` out of `gcc/`.** ~520 TUs. Not sized here; it is the macro
programme, now with a compiler-enforced worklist because Stage 3 removed the
primary `tm.h` that made non-conversion compile.

### 6.1 Ordering justification

Stages 0–2 are pure preparation and each is individually revertible. Stage 3
is the irreversible one and is placed after Stage 2 so that the plural
interface exists and is exercised (as a list of one) before the layout
changes. Stage 4 after Stage 3 because moving the mapping is only meaningful
once there is somewhere per-target for the tuning variables to live. Stage 6
last because Stage 3 is what makes it self-reporting.

### 6.2 Verification without a single-target build of our own tree

This is the hard consequence of "no single target ever" and it must be settled
**before** Stage 3, not during.

- **`/tmp/b-stock`** (genuine upstream at merge-base `c31b7a09eea`, 561 TUs,
  measured above) remains valid and becomes the **only** external control. It
  is not our tree, so it is unaffected by the ruling.
- **`/tmp/b-ref1`** (562 TUs, our tree single-target) **dies at Stage 3.** Any
  arm that uses it must be re-expressed before then. Concretely: arms that
  compare "our multi-target answer" against "our single-target answer for the
  same triple" must become "our multi-target answer for triple A" against
  "our multi-target answer for triple B", i.e. **symmetry arms** rather than
  reference arms.
- **The replacement control is permutation, not reference.** Configure the
  same N targets in a different order; every output must be byte-identical.
  This is a stronger control than `/tmp/b-ref1` ever was, because it tests the
  property we actually want ("no target is privileged") rather than a proxy
  ("target X's answer matches a build that only had target X").
- **Non-vacuity for the permutation arm must be demonstrated before it is
  trusted.** A permutation arm on a build that ignores `--targets` entirely
  passes trivially. Poison it: hard-code one component to element 1 and
  confirm the arm goes red. Without that, it is a false green of exactly the
  shape recorded in memory (§"False-green checks").

**#62 dependency, stated plainly.** A fresh build directory does not bootstrap
on this branch (circular `genconstants.o` ← `insn-constants.h`). Every build
dir in use — including all six measured in §5.1 — is a survivor of an earlier
state. **A top-level restructure changes the configure and directory layout,
which means it cannot be verified against a tree that only builds from
surviving artefacts.** Stage 3 therefore has a hard prerequisite that is not
in the plan above:

> **Stage 3 cannot be accepted until #62 is fixed and a cold build from an
> empty directory succeeds.**

I want to be blunt about this: if #62 is not fixed, Stage 3 is unverifiable in
principle, and the honest thing is to say the restructure cannot proceed
rather than to proceed on a build dir whose provenance we cannot reproduce.
**#62 should be promoted to a blocker of this project, not tracked beside it.**

### 6.3 The permutation harness

```
for each permutation P of --targets:
    configure fresh dir, build, record md5 of every generated file
assert all permutations produce identical md5 sets
```
Assert the tools exist first (`command -v md5sum nm ...`), redirect stderr to
a file and assert it empty — never `2>/dev/null`, and never pipe stderr into
a counter. (DEVSHELL's `nm`-not-on-PATH incident scored 0 for both compilers
and read as agreement.)

### 6.4 The 288-arm probe scoreboard under "no primary"

Today those arms compare a multi-target header context against a per-base one.
Under "no primary" the *per-base* context is unchanged (each back end still
has `i386-inc/tm.h`), but the **multi-target context ceases to exist as a
thing with a single answer** — there is no bare `tm.h` to build the
multi-target side against.

So: **the arms do not survive Stage 3 unchanged.** Their meaning becomes
"does back end A's per-base context agree with back end B's per-base context
where the macro is target-independent, and differ where it is
target-dependent". That is a *two-sided* test where today's is one-sided
against a privileged reference, and it is strictly stronger. But it is a
rewrite of the harness, and it must be scheduled inside Stage 3, not
afterwards — an unrewritten harness against a tree with no primary will
produce a scoreboard that is not wrong so much as meaningless, and meaningless
scoreboards on this project have read as green.

---

## 6.5 #65a AND #64 — THE STATUS IS OUT OF DATE, AND ONE HALF IS MISSING

I was asked to fold in "#65a, independently landable, fixes #64". **Measured:
#65a is already landed and committed.** `gcc/gcc.cc:8617-8672` implements the
full resolution order, and `git status` shows `gcc/gcc.cc` clean:

1. `-ftarget-config=` from the argv scan (`gcc.cc:8599-8601`)
2. `target_from_progname ()` (`:8468`, `:8621`) — matched against the **closed
   set** of configured targets, never parsed
3. `target_from_default_file ()` (`:8545`, `:8649`) — consulted only if both
   above are silent

with an explicit `early_fatal_error` when (1) and (2) disagree, and another
when the selected target is not one this compiler was configured for. This is
exactly the shape this project's constraints demand, and it is done. Nothing
needs scheduling for it.

**But #64 is only half fixed, and the missing half is the trap this project
keeps hitting.** Step 3's input does not exist:

> `grep -rn "default-target" gcc/Makefile.in gcc/configure.ac target-specs/`
> → **zero hits**, stderr empty.

**Nothing in the tree writes or installs a `default-target` file.** The
mechanism is present, correct, and reads a file no rule produces — *presence
of a mechanism is not evidence anything invokes it*, live and in the open. So
today:

- `aarch64-linux-gnu-gcc` works — step 2 answers.
- A plain installed **`gcc`** still gets NULL from all three steps, keeps the
  empty back end, and fails at `option_init_struct` — **#64's exact reported
  symptom.**

So #64 is fixed for triple-named drivers and unfixed for the native one, which
is the case the bug was filed about. The remaining work is a rule that writes
`default-target` at install time — small, but it must be scheduled, and it
should not be assumed done because #65a is. Suggested placement: **Stage 0**,
since it is independent of everything else here.

---

## 7. WHAT I AM LEAST CONFIDENT ABOUT

Stated outright, weakest first.

**(1) That the triple → back-end mapping can be split from `config.gcc`
without carrying the 51 inputs with it. (§3.3 option (iii).)**
This is the load-bearing unmeasured claim of this design. Option (iii) is
recommended, the whole "gcc/ is host-and-build only" story depends on it, and
**I did not measure it.** The specific risk: `config.gcc` may select
`cpu_type`, `out_file` or the `tm_file` *set* on the basis of `enable_fdpic`,
`with_multilib_list`, `enable_targets` or `with_abi` for some targets — in
which case the mapping is not separable, option (ii) is forced, and Stage 4's
cost triples from 1–2 weeks to 3–4. This is a half-day probe (Stage 1) and
**the design should not be approved before it is run.** Precedent: the
class-(c) design named `__attribute__((target))` invariance as its
load-bearing unmeasured claim and it was one probe from being settled.

**(2) That the other 25 target modules are no worse than `libgcc`.** The
`libgcc` survey is done (§2.5) and found one serious leak
(`-I$(gcc_objdir)` → the primary's `tm.h`, in 9 named source files) which is
now Stage 3a. **`libstdc++-v3`, `libgomp`, `libatomic`, `libitm`,
`libsanitizer` and the remaining 20 target modules were not surveyed**, and
#37 records that target libraries beyond `libgcc` do take gcc's build-time
config. Each may have its own `-I$(gcc_objdir)`. If several do, Stage 3a is
not 3–5 days.

*Partially closed during writing.* A grep for `gcc_objdir|tconfig\.h` across
20 target-module directories (excluding ChangeLogs, stderr asserted empty)
finds hits in only **three**: `libatomic` (2 files), `libobjc` (4),
`libga68` (2). Seventeen are clean, including `libstdc++-v3`, `libgomp`,
`libitm` and `libsanitizer`. **This is much better than feared and I now
believe Stage 3a's 3–5 days.** But note the caveat that has cost this project
before: *absence of an artefact is not absence of a mechanism.* Those 17 may
reach `gcc`'s build dir by another spelling (`../gcc`, `$(MULTIBUILDTOP)`,
`GCC_DIR`, or via `CC_FOR_TARGET`'s `-B` paths). The grep bounds one shape of
coupling, not all of them, and it is not a substitute for the survey.

**(3) — NOW THE WEAKEST, AND IT IS THE ONE TO ACT ON — that the split-loop
route's make half survives contact with `$(eval)` at the 2-week estimate.**
I have not attempted it, and three things make it the load-bearing unknown:

- The generated `Makefile.in` contains **zero** `$(eval)` today (measured), so
  there is no in-tree precedent at this level to copy. The `gcc/` precedent I
  cited (`multi-target-common.mk`) is *configure emitting literal rules*, not
  `$(eval)` — a different technique with a different failure mode.
- `$(eval)`'s failure mode is a **silently empty recipe**, not an error. This
  is the project's signature bug shape landing in the one file that decides
  whether anything gets built at all.
- **Bootstrap staging is the specific place I expect it to break.**
  `Makefile.tpl:1779-1793` moves whole stage directories with `mv`, and the
  stage machinery is stateful across make invocations in a way the module
  rules are not. If per-target staging cannot be expressed without
  restructuring the stage machinery itself, Stage 3 is a multi-month item and
  must be split (target modules first, bootstrap staging second).

**The probe that settles it is small and should be run before approval:**
parameterise **one** module — `libgcc` — through `define`/`$(foreach)`/
`$(eval)`, with N=2, non-bootstrap path only, and confirm two configured
targets each get a complete non-empty rule set. A day. If the quoting is
tractable for libgcc it is tractable for the other 25; if it is not, the whole
route needs rethinking and it is far better to learn that now. **This has
displaced the `config.gcc` split as my top-ranked risk**, because the
`config.gcc` question changes a cost estimate whereas this one decides whether
the recommended route exists.

**(3b) That the 45 `_FOR_TARGET` variables are mechanical.** I counted them
(§2.2a(b)) but did not examine how they are *computed*. Some are probed by
configure against `$target`, and probing 45 tools × N targets may surface
DEVSHELL's exact failure — a missing `<triple>-as` scoring as an empty answer
rather than an error — 45N times instead of once.

**(4) That removing `--target=` outright is acceptable.** I recommend it on
principle (§1.3) and I believe it is right, but it breaks every existing
invocation of this tree's top-level configure, including any in `contrib/`,
`maintainer-scripts/`, and CI. I did not enumerate them.

**(5) The `.deps`-based `tm.h` count.** 520–526 of 622–632 is a count of
*dependency files that mention `tm.h`*, which conflates a direct
`#include "tm.h"` with a transitive one through another header. The number
needed for Stage 6's worklist is the *direct* count, which is smaller and
which I did not measure. The 84%-vs-83% comparison against upstream is sound
because both sides are measured the same way, but the absolute figure is an
upper bound on the edit list, not the edit list.

---

## 8. WHAT MUST HAPPEN BEFORE THIS DESIGN IS APPROVED

1. ~~**Run the one-module `$(eval)` probe** (§7(3)). One day, `libgcc` only,
   N=2. It decides whether the recommended route exists. **Highest
   priority.**~~ **DONE — #113. The route exists**: 4/4 arms, both-sided,
   with an empty list failing by name and the comparison demonstrably
   sensitive to the quoting error. Two corrections to this document came out
   of it; see the annotation in §2.2. Bootstrap staging remains unprobed.
2. **Run the `config.gcc` split probe** (§3.3, §7(1)). Half a day. It decides
   Stage 4's cost and whether "gcc/ is host-and-build only" survives.
3. **Decide #62's status.** If a cold build cannot be made to work, Stage 3 is
   unverifiable and this design should not be built (§6.2).
4. **Decide the gnattools/gotools question** (§2.2a(a)). Three of the 44
   dependency lines are host tools depending on *a* target library without
   saying which. Under "no primary" there is no default available.
5. **Confirm the reviewer accepts that `/tmp/b-ref1` dies** and that
   permutation replaces reference (§6.2).
6. **Schedule the `default-target` install rule** — #64 is only half fixed
   and the half that is missing is the native-`gcc` case the bug is about
   (§6.5).

Nothing was committed, staged, or written into the source tree.
