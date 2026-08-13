# PRINCIPLES — read this before acting on any brief

This is the standing law of the GCC multi-target branch. Every agent reads it.

**If a brief contradicts this document, THIS DOCUMENT WINS.** Say so, stop, and
report the contradiction. Briefs are written by a coordinator who does not
measure and has been wrong many times — including once about a *design shape*
rather than a number, which is the kind an agent can build before anyone
notices. You are expected to push back. Eight agents contradicted their briefs
in one session and were right every time.

---

## 1. The goal

One compiler binary serving all back ends, with **zero target-specific
information baked in at compile time**.

**Terminal state: there is no `tm.h` in `gcc/` at all** — only, possibly, in
`libgcc`. `tm.h` reaches ~520 of 622 middle-end TUs, and every macro in the
conversion programme is one of its exports. "Delete `tm.h` from `gcc/`" and
"finish the macro conversion" are the same task stated twice.

## 2. The user's standing rulings

These are settled. Do not relitigate them; do apply them to whatever you are
handed.

- **No single target, ever.** Not a primary, not a default, not a fallback.
  There is no single-target mode to fall back to.
- **`gcc/configure.ac` is about host and build only — never target.** It was cut
  from 7,982 lines to ~3,449 on that principle.
- **Every `--with`/`--enable` is about the host (or rarely build), never the
  target.** Hence `--enable-host-shared` → `--enable-shared` and
  `--enable-targets` → `--enable-backends` (it selects which back ends go *into
  the binary* — a property of the artefact, i.e. host-side).
- **The top level is the only component that legitimately deals in targets**,
  because it is the dispatcher: it takes **targets, plural**, maps triples →
  back ends, and instantiates per-target trees. Everything below it gets
  `--host` or a back-end list. This is the stated exception to "avoid
  `--target`", not a violation of it.
- **Runtime libraries are single-host.** Plurality lives at the top level; one
  host per runtime tree; no target at all inside `gcc/`.
- **`libgcc`, `target-specs` are `target_module`s**, one instance per configured
  target, configured with `--host=<target>`.
- **`crt` belongs to libgcc, not gcc** — it is runtime and must not be built with
  gcc's configuration.
- **Multilib is mandatory everywhere.** Both `--enable-multilib` and
  `--disable-multilib` were deleted. Multilib *nests inside* per-target
  instantiation; it is an asset, not an obstacle.
- **`target-specs` runs AFTER gcc is built**, as its own configure the user
  invokes. gcc must not generate specs as a build-time prerequisite.
- **Do not rename libgcc symbols; do not let PSIs clobber each other.** Namespace
  rather than rename.

**There is a category of POST-INSTALL, PER-TARGET ENVIRONMENT ADAPTATION**, and
several open problems are one problem once you see it. The user's framing:
*"fixincludes sounds like target-specs — something that might be run post
install, once we are at the final deployed machine, to fix up the headers."*

- `target-specs` probes the actual `as`/`ld` for a target.
- `fixincludes` patches the actual system headers for a target.
- collect2's tool paths (`MD_EXEC_PREFIX`, `REAL_*_FILE_NAME`) are which tools
  exist for a target.
- cppdefault's system header directory is where a target's headers are.

All four are facts about **the deployed machine**, per target. Baking any of
them at gcc build time is wrong for the same reason: **the build machine is not
the deployment machine**, and a compiler serving N targets has no single answer
to bake anyway. They belong in the per-target directory
(`$(libdir)/gcc/$(version)/<target>/`), written by something the user runs after
installing, and read at run time.

**Test for this category:** if the answer could change without rebuilding the
compiler — a new binutils, a different sysroot, headers fixed in place — it is
post-install adaptation, not build configuration.

**HOOK vs CAPABILITY — the other half of that test.** Not every per-target fact
belongs in `target-specs`. The user's rule: *"hooks can be used for static
defaults that vary per target."*

- **A target hook (`targetm.*`)** is for a **static** per-target answer that is
  part of the compiler itself — it ships with the back end, cannot change
  without rebuilding, and the back end is the authority. Example: which
  exception model a target uses by default. `arm_except_unwind_info` already
  computes it from target state; that is a hook doing its job.
- **A `target-specs` capability** is for a fact about the **deployed
  environment** for that target — probed, and able to change without rebuilding
  the compiler. Example: whether this machine's `as` supports `.hidden`.

**Ask: could this differ between two installations of the same compiler serving
the same target?** If yes → capability. If no → hook. Getting this wrong is not
harmless: a static fact routed through the probe channel becomes something an
operator can get wrong, and a probed fact frozen into a hook becomes a lie the
moment the toolchain changes.

**`gcc/configure.ac` is the forcing function.** The user's words: *"I bring up
gcc/configure.ac a lot because I think it is a good forcing function."* If that
file is host-and-build only, then every target fact has had to move somewhere
legitimate — a per-target config, a runtime read, the top level. Shrinking it is
not cosmetic bookkeeping; it is how you find out what is still wrong. It went
7,982 → ~3,500 lines, `gcc_GAS_CHECK_FEATURE` 51 → 0, `case $target` 15 → 1.

Concretely, the first systematic audit of its remaining `--with-*` (only done
because the question kept being asked) found two target-side flags nobody had
noticed: `--with-build-sysroot`, which sets `SYSROOT_CFLAGS_FOR_TARGET`, and
`--with-fixincludes-machine`, a *machine name*. Both had survived every earlier
pass. **When in doubt about whether something is done, ask what is still in
`gcc/configure.ac` and why.**

**Why "no primary" is the strategy, in the user's words: eradicating it
"should force us to fix bugs."** Today every leak has a plausible fallback —
the primary's answer — so wrong code runs silently. With no primary there is no
valid answer to fall back on, so the same code must fail at build time. It is
`#ifdef X` → `if (X)` applied to the whole build system.

## 2a. Changes that LOOK like fixes and actually undo this project

Read this list before you make anything red turn green. Every item is a real
temptation that presents itself as an obvious small fix, and every one of them
destroys the work rather than advancing it. **If your fix is on this list, you
have found a design question, not a bug. Stop and report.**

- **Reintroducing a primary, a default, or a fallback target** — including
  "just for the native case", "just so a bare `gcc` works", or an install rule
  that bakes one target into `gcc/`. A default target is a primary by another
  name. A bare `gcc` failing by name when no target is selected is **correct
  behaviour**, not a bug to fix.
- **Un-unioning a vocabulary** to make a divergence go away. The unions are
  load-bearing: the mode union is the only thing stopping `SImode` meaning 18 to
  one back end and 17 to another. If a union causes a problem (see
  `HAVE_V8HFmode`), the fix is downstream of the union, not a retreat from it.
- **Adding an `#ifndef` floor / a default value / a "sensible fallback"** so a
  missing answer stops erroring. The fallback is always the primary's answer,
  which is the bug. Never let the absence of an answer be an answer.
- **Deleting, relaxing, or narrowing a check that fails.** The check is usually
  the only thing standing between a silent wrong answer and a diagnostic. If
  `--enable-backends=all` reports "45 options blocks for 48 back ends", three
  back ends are unexplained — that is the check working.
- **Editing a probe, retiring an arm, or adjusting an expected value** so the
  scoreboard improves. This is the test-harness floor and it has been refused
  four times, including the subtle form: changing a macro's value so the
  *tautological* i386 column flips red, whose obvious next move is editing the
  probe list.
- **Converting a runtime read back to a compile-time macro** because it is
  simpler. The whole project is the other direction.
- **"Fixing" the top level by removing its target handling.** The top level is
  the dispatcher; targets there are the design.
- **Making a diagnostic disappear without establishing what it was reporting.**
  An unterminated quote, a redundant `@`, a `test: =:` error — on this project
  each has twice meant something was silently truncated with exit 0.
- **Reverting a per-base object, header, or namespace to a shared one** because
  the shared one builds. It builds because it is answering for everyone.

The general form: **if your change makes a measurement stop objecting without
changing the thing it was objecting to, you have deleted evidence.**

## 2b. A debugging-shaped task can contain a design decision

This is the failure that produced the `default-target` mistake, and it is worth
naming because it is invisible from inside the task.

"Write the install rule so a plain `gcc` works" reads as debugging: a symptom, a
missing file, an obvious fix. It was actually a decision about **whether `gcc/`
may know a target at all** — settled policy, contradicted by the obvious fix.

**Test:** if completing the task requires you to *invent* where something lives,
who owns it, or what the default is, it is design, not debugging. Ordinary
debugging changes code so it does what it already intended. Design decides what
it should intend.

When you hit one: say so and report the options with costs. Do not resolve it by
picking whichever makes the build succeed.

## 3. The bug we are hunting, in all its disguises

**One name, several authorities, no diagnostic.** It links cleanly and means
different things. Instances found so far:

| disguise | example |
|---|---|
| shared numbering | `SImode` = 18 for i386, 17 for aarch64 |
| shared numbering | `UNSPECV_BLOCKAGE` = 1 vs 5; `N_REG_CLASSES` 34 vs 20 |
| kind mismatch | `internal_dfa_insn_code`: function vs function *pointer* |
| identity by address | `CUMULATIVE_ARGS_MAGIC` = `&targetm.calls`, broken by copying |
| mutation discarded | 12 back-end writes through `targetm` lost to a copy |
| COMDAT body | `optab_handler` — linker keeps one of three bodies, by link order |
| unsupplied hook | `TARGET_LIBCALL_VALUE` — every target got i386's registers |
| sized by one, written by another | `cl_optimization` — an 8-byte **overflow** |
| bound by one, indexed by another | `NUM_UNSPECV_VALUES` 114 vs a 40-entry table |
| guard hiding a *declaration* | `rs6000_gnu_attr`; `<ldfcn.h>` in collect2 |
| **the union's answer leaking** | `HAVE_V8HFmode` — "exists somewhere" ≠ "exists here" |

Note the last one runs **opposite** to the others: normally the primary's answer
leaks to everyone; there the union's does. Same root — one authority answering
for many.

**The design rule that fixes it:** union the vocabulary, keep the data per
configuration, select at run time, qualify only what actually collides. Landed
eight times. Reuse the union-list mechanism (`#`-prefixed setting lines, hard
failure by name when a base is missing); do not invent a second one.

## 4. Method — this project has produced 26+ false greens

**Never let the absence of an answer be an answer.** No `#ifndef` floors. A
missing value must fail *by name*. The natural fallback is always the primary's
answer, which is the bug.

**Verification must be able to fail.** Inject a deliberate `#error`; require the
build to FAIL naming it. **An injection that does not fire is a finding** — one
revealed four sites inside a dead `#if TARGET_XCOFF`; another revealed a
936-byte empty `collect2-aix.o` silently built for weeks.

**A GUARD SCRIPT CAN BUILD SOMEBODY ELSE'S TREE AND REPORT A CLEAN GREEN.**
Twenty-three `tNNN-build.sh` scripts had `SRC=` hardcoded to **another agent's
worktree**. They configure, build and pass — against a compiler that is not
the one under test. Measured by content anchor: this worktree has **39**
`MULTI_TARGET` hits in `gcc/Makefile.in`; the trees those scripts pointed at
had **27, 28 or 39**. A script pointing at a 28 builds a compiler **missing
eleven landed changes** and reports success, with no diagnostic anywhere.

Two lessons, and the second is the sharper one:
- **Every harness must assert which tree it is measuring**, by content anchor,
  not by assuming its own `$0` location.
- **A loud break can mask a silent one.** These scripts were *also* broken by
  the `--enable-targets` flag day, which is what got them looked at. Fixing
  only the loud defect would have left every "repaired" script measuring the
  wrong compiler — and would have looked like a completed repair. When you fix
  a noisy failure in something that was not being watched, **audit the thing
  mechanically rather than by eye** before declaring it healthy.

**SWEEP THE FAMILY; DO NOT MEET IT ONE WALL AT A TIME.** Four generated
per-base families were found built, linked, **and never selected** — the
`targetm` asm ops, the optab tables, the predicates/constraints, and the insn
attribute tables — each discovered by *walking into it* during an unrelated
debug session. When the fourth turned up, enumerating the whole of `OBJS`
took one agent-session and produced a verdict per family, including six that
were already clean (worth stating: **a family you checked and judged fine is
a result; silence about it is not**). It also found, *outside* the family it
was sent to look at, a **163KB overrun of a shared `.bss` object**:
`NUM_INSN_CODES` was 15429 (i386's) while shared code writes at codes up to
20511.

**"Is a per-base variant built?" and "does a selector exist?" and "does
anything CALL the selector?" are three arms, not one.** A selector has been
found complete, well-commented and with **no caller anywhere** while its table
arm was green and correct.

**"WHERE DOES IT ICE" IS NOT THE MEASUREMENT. "IS THE OUTPUT RIGHT" IS.**
A wall was handed between agents as *"`int g(int a){return a+1;}` fails in
`aarch64_can_eliminate` during postreload"*. At branch HEAD it did not fail at
all — it **compiled, exited 0, and emitted**

    str  x19, [x7, -32]!

with matching wrong CFI: i386's `STACK_POINTER_REGNUM` and
`FRAME_POINTER_REGNUM` (7 and 19) used as **aarch64's** stack and frame
pointers. The loud failure had already become a quiet one, and tracking ICEs
would have recorded that as *progress*.

So: **every wall report must state what the compiler produced, not only where
it stopped.** A wall that "moves" may have become silent wrong code. Check the
emitted assembly against the target's real registers before believing a
failure went away — and treat a disappeared ICE as suspicious until the output
is inspected.

**THE SYMBOL INSTRUMENT IS BLIND TO MACROS THAT EXPAND TO OPTION STATE, AND
THAT IS EXACTLY WHERE THE WORST LEAKS LIVE.** `nm -uC` scores them as *absent*,
and not by bad luck: `ix86_pmode` is `global_options.x_ix86_pmode`, a struct
member shared code legitimately links against, so **no object anywhere carries
an undefined reference naming it**. Two agents hit this independently — one
found `nm` scoring four real leaks clean because `Var(ix86_branch_cost)` is
likewise `global_options.x_…`. So the instrument sees macros expanding to
**code** and misses macros expanding to **option state**. When a macro's body
is an option variable, `nm` cannot help you; read the value in the running
`cc1`.

**The silent-default variant, which is worse than an ordinary leak.** i386's
`Pmode` is `(ix86_pmode == PMODE_DI ? DImode : SImode)`, and `ix86_pmode` is
`Init (PMODE_SI)`, promoted to `PMODE_DI` only by `ix86_option_override` —
which runs only when i386 is selected. So shared code compiling for aarch64
did **not** get x86_64's answer; it got the primary's **unconfigured
default**, correct for *neither* base. Note the trap in that: **a leak serving
the primary's real value would have produced the right mode by luck and hidden
this indefinitely.** When you find an option-state macro, check what it reads
before any `*_option_override` has run, not what it reads afterwards.

**An undefined symbol names the macro that DRAGGED IT IN, not the macro that
caused the control flow.** `nm -uC` cleared three walls in a row and then
pointed at the wrong macro on the fourth. `cfgexpand.o` showed
`U ix86_incoming_stack_boundary`, and `INCOMING_STACK_BOUNDARY` really does
leak — but the function was only *entered* because
`SUPPORTS_STACK_ALIGNMENT` is `(MAX_STACK_ALIGNMENT > STACK_BOUNDARY)`, and
only i386, cygming and nvptx define `MAX_STACK_ALIGNMENT`, so `defaults.h`'s
`#ifdef` is true purely because the primary is i386. aarch64's own answer
makes it `128 > 128` — **false** — so aarch64 should have returned two lines
in and never reached the assert at all. Converting the named macro alone
would have left aarch64 inside the function running i386's realignment path,
with the assert now passing: **a loud failure turned quiet.** So: when a
symbol names your suspect, walk the *guards* that decided you reached that
line, and convert the closure.

**Ask what would have had to change for your comparison to mean anything, then
show it did.** Models: `nm -C` 1379 `poly_int<1u>`→0 and 0→1619 `poly_int<2u>`;
`targetm` instructions 3060→0 with `targetm_ptr` 0→2938; `sub $0x4b8,%rsp` →
`sub $0x9d8,%rsp`; `sizeof` 1520→1528 while the settled struct held at 8392.

**Both-sided evidence.** Showing target A gets A's answer proves nothing unless
you also show target B still gets B's. One-sided evidence cannot distinguish
"fixed" from "everyone now gets the same new answer".

**Separate arms on the data and on the selection.** A green arm on a per-base
table says nothing about whether the pointer choosing between tables is wired.
`targetm_asm_ops` was pinned to the primary while `target_asm_ops_for()` had
**no caller anywhere**, and the table arm was green and correct.

Six rules that each cost a session:

1. **Absence of an artefact is not absence of a mechanism.** No file in a build
   dir ≠ no rule; make is lazy. Grep the generated `.mk`, never `ls`.
2. **Presence of a mechanism is not evidence anything invokes it.** A complete,
   well-commented mode union sat inert for weeks. Grep the generated fragment
   for your flag; diff the artefact it should have changed.
3. **A written invariant is not evidence anyone ran it.** A comment claiming "no
   back end writes through `targetm`" was false by 12 sites the moment someone
   ran the grep it described. A `Makefile.in` comment about `OBJS` was false.
4. **A measurement that scores 0 may be a false negative from the instrument.**
   Confirm a 0 by finding the thing under another name.

   **And a count is not the divergence.** `ELIMINABLE_REGS` leaks between
   bases, and i386 and aarch64 both have **exactly four pairs** — a
   length check would have scored the leak as *absent*. (`vax.h` has one,
   `rs6000.h` six, so a count looks like a discriminator until you try it on
   the pair you actually have.) All four register *numbers* differ. **Print
   the contents and compare them; do not assert on a count**, and do not
   predict which elements differ — a previous wall's missing registers turned
   out to be 16–19, not the 92–94 predicted.
5. **A clean result from an instrument with unexamined blind spots is worth very
   little.** Strong-symbol sweeps hid COMDAT; the COMDAT sweep hid macros; the
   macro probe found `BYTES_BIG_ENDIAN` by failing to compile. **State your
   instrument's blind spots.**

   **Including gdb.** An arm set three breakpoints in one run and narrated
   labels between `finish` commands, assuming they fired in the order written.
   One function is hit first and repeatedly, so all three readings were *that
   one function's* return value under three different names — two arms
   compared the wrong function entirely, and **the third passed**, because
   0/1 happened to be what it was reading. One breakpoint per run, and match
   gdb's own reported breakpoint against the function under test.
6. **A diagnostic-driven sweep fixes exactly the copies some configured triple
   compiles.** A poly_int sweep fixed 2 sites and left 7 identical siblings,
   having demonstrably reached those files. **Sweep the source, not the build
   output** — ~186 targets are never built.
7. **A mitigation can score the very error it was written to catch as a pass.**
   TOPLEVEL-DESIGN §2.2 twice described the `$(eval)` failure mode as "a
   silently empty recipe" and mandated a **non-emptiness assertion**. Measured
   by injecting the error rather than by reading: under-quoting `$$(srcdir)`
   produces a complete, non-empty, *plausible* recipe with the call-time value
   baked in where a deferred one belonged. The prescribed check would have
   passed. **The failure was silently WRONG, not silently EMPTY** — and a
   length test cannot tell those apart. Diff the artefact against an
   independently-produced control; never assert on its size.

   Generalise it: **whenever you write a mitigation, inject the exact fault it
   names and confirm the mitigation fires.** An unfired mitigation is
   indistinguishable from an absent one, and reads as protection.

   **The same lesson arrived twice in one day by a different route, which is
   the signal.** `target-specs/configure` was exiting 1 for *every* target
   (a key emitted but absent from `ts_expected`), aborting partway and leaving
   `specs-<target>` **truncated at 39 lines** instead of 101. Every aarch64
   measurement taken in that window used a truncated spec file. The guards
   missed it because **they assert the file is non-empty — and 39 lines is
   non-empty.**

   So: **"non-empty" and "long enough" and "exists" are not checks.** They are
   the shape that passes on the corrupted artefact. Check the artefact against
   what it should *be* — a line count you predicted, a diff against a control,
   the specific keys you expect by name. If you find yourself asserting
   `test -s`, ask what a half-written version of that file looks like, because
   that is the case the assertion will meet.

   **Third instance, and the sharpest: a GENERATOR that ran, exited 0, and
   changed nothing.** An agent added a probe symbol, a loop and a refusal
   check to `gen-reg-widths.sh` — but never added the `#define` to its
   heredoc. The header came out **byte-identical**, `move-if-change` therefore
   kept the old one, and make reported success. Exit status, existence,
   timestamp and non-emptiness *all* pass on that. Note `move-if-change`
   actively hides it: its whole purpose is to make "no change" invisible to
   make.

   **So for anything generated, assert on the CONTENT you added, by name and
   value, and run that arm first.** "The generator ran" is not evidence the
   generator did anything.

**Check the count in BOTH directions when moving a walk onto a union list.** A
fix can improve the axis you are watching while silently regressing the one you
are not. Real case: `cl_optimization_compare` walked `flags[]` with 1116
comparisons and **zero** aarch64 members. Switching it to `sv_flags[]` compiles
and adds 17 aarch64 members — and takes the count **1116 → 585**, because `R`
records are the *save* set while that walk needs every option with a
`gcc_options` member. **531 common options silently stop being compared.** A
non-vacuity check asking only "did aarch64 appear?" scores that as a pass. The
correct fix added a new record kind: 1116 → 1169, none lost, 44 aarch64.

**Never retire or weaken a probe to move a number** (the test-harness floor).
Refused four times, including the subtle form: changing a macro's value to flip
the *tautological* i386 column. An arm turning green because both bases now
expand to the same target-neutral text is a **wrong-reason** flip — retire it as
`CONVERTED_CDATA` with a TAB arm, never bank it.

**One file complaining while ninety stay quiet can mean the ninety are silently
wrong** (the `-I<base>-inc` bug). And its dual: **many errors in one file while
siblings compile clean is usually systemic** (the `GCC_TM_H` forwarder bug).

**Landing a subset is fine; leaving a non-linking `cc1` blocks everyone.** If you
cannot land it whole, land what keeps `cc1` linking and hand over a
decomposition with measurements. That call has been made correctly 17 times here
and never regretted. **A half-fix that makes a failing check pass while the
answer is still wrong is worse than the failure.**

## 5. Environment traps, each paid for in hours

- **DEVSHELL.md is mandatory.** `nm`/`make` are not on PATH outside the
  nix-shell; a reduced shell writes `#define rlim_t long` into `auto-host.h`,
  which looks exactly like someone else's source bug.
- **Worktrees are created at bare-repo HEAD `7208eca60d0`**, 39,111 commits
  behind. It presents as *"stale line numbers"*, not *"wrong tree"*. Check:
  `git merge-base --is-ancestor HEAD multi-target`, or grep `MULTI_TARGET` in
  `gcc/Makefile.in` — **empty means wrong tree**.
- **The git index is SHARED.** `git commit` commits whatever is staged, including
  another agent's files. `git diff --cached` immediately before every commit.
- **Build your own build dir.** Sharing `/tmp/b-objs` produces meaningless
  verdicts and spurious `mv: cannot stat tmp-*` failures; it has killed runs.
  **In a shared build dir, a file you did not write is not a fixture.**
- **A generator or configure script can fail and exit 0** — four times. One `'`
  in a comment truncated a block out of a generated makefile; a backtick in a
  heredoc comment wrote nothing and silently defaulted all 97 capability keys.
  Read `config.log`; check the artefact, not the exit status.
- **`config.status` re-uses cached substitutions — `--recheck` is required**, in
  the full shell.
- **A quoted `#include` beats every `-I`.** Per-base sources must be compiled
  from `mt-<cpu>/`; the build-root copy opens the primary's headers.
- **Stale `.deps/*.Po`** from a cloned build dir makes objects silently not
  rebuild — it produced a Frankenstein `cc1` that ICEd. **An A/B control across
  `git stash` is not an A/B control** (mtimes refresh). Delete objects.
- **`make` in the wrong directory**: `cc1` builds in `<builddir>/gcc`; at the top
  level you get `No rule to make target 'cc1'` — or worse, `Nothing to be done`
  and exit 0 next to a stale binary.
- `-j16` once failed with **no diagnostic at all** under memory pressure; use
  `-j8`. `pgrep -f` matches its own command line; `pgrep -a` is the tell.
- **Tool-not-found piped into `grep -c` scores 0** — in the direction that makes
  the reference look correct. Assert your tools exist and inputs are non-empty
  before scoring anything.
- `@substitutions@` inside `Makefile.in` **comments** are still substituted, and
  are invisible in `git diff`.
- Immediate vs recursive assignment has bitten three times (`INCLUDES :=`
  dropped a flag; `ALL_GTFILES_H :=` made a late `+=` silently too late).
- Never `2>/dev/null`. Use `cmd > out 2> err` and assert `err` is empty.

## 6. Current acceptance bars

- **stock-compare**: `scratchpad/stock-compare.sh` with an **absolute** `IN`
  (a relative path silently produced a false green, and the negative control
  reported "ok, differs" while comparing two nonexistent files) —
  **5/5 IDENTICAL** vs `/tmp/b-stock` (genuine upstream at merge-base
  `c31b7a09eea`), distinct md5s per side, negative control firing.
- **Probe scoreboard** (re-measured 2026-08-12 by running
  `scratchpad/macro-probe-run.sh`, not by reconciling on paper — quote these):
  **224 header arms over 112 macros — i386 112 PASS / 0 FAIL, aarch64 8 PASS /
  104 FAIL, of which only 2 of the 8 passes are TRUSTED; 64 TAB arms — i386 32
  PASS / 0 FAIL, aarch64 27 PASS / 5 FAIL.** **Diff verdicts and probe shapes,
  never totals.**

  **Never quote the raw 8.** It is 2 trusted (`MAX_BITS_PER_WORD`,
  `MAX_BITSIZE_MODE_ANY_MODE`) + **6 retired-pending** — #108's stack/arg
  boundary set (`FUNCTION_ARG_REGNO_P`, `MINIMUM_ALIGNMENT`,
  `OUTGOING_REG_PARM_STACK_SPACE`, `PREFERRED_STACK_BOUNDARY`,
  `STACK_BOUNDARY`, `STACK_SLOT_ALIGNMENT`), which are green because the
  probe's base-B context does not define `MULTI_TARGET_TARGETM_BASE`, so
  `defaults.h` redirects both sides and **the arm compares the redirect with
  itself**. Their real both-sided evidence is at the object level
  (`scratchpad/t108-evidence.sh`); they need TAB arms before any of it counts.

  This line was reconciled after two documents disagreed, and **both were
  partly right on the same board**: this file had #92's retire-3 but not
  #108's six (2 / 110); STATE.md had #108's six but not #92's retire-3
  (5 / 104 + 6). `5 − 3 = 2` and `104 + 6 = 110` — the arithmetic closes, but
  it was settled by re-running the harness, because closing arithmetic is
  exactly how a wrong shared number survives. #92's retire-3
  (`FIRST_PSEUDO_REGISTER`, `N_REG_CLASSES`, `REGNO_REG_CLASS`) was a
  **correction, not a regression** — same wrong-reason flip as the six, caught
  rather than banked; they are `CONVERTED_REGS` and carry TAB arms that read
  the running `cc1` against each base's own headers.

  Earlier figures, kept because each was quoted after it stopped being true.
  230/58 with aarch64 5/110 and 24/5 is the pre-#92 state and is now stale.
  (An earlier version of this line said aarch64 2/113. That is stale and was
  arithmetically impossible at 230 arms — 113+2 = 115 macros; the 2/113 figure
  belonged to the 266-arm era before 18 macros were retired to TAB. Two agents
  measured 5/110 independently. **If a number in a brief cannot be reconciled
  with the arm count, say so rather than reporting against it.**)
- **Stderr**: the **incremental** floor is **at most 32 lines** — 8
  `is unchanged` + 24 `'@' is redundant` from unmodified aarch64 `.md` files,
  because those rules write through `move-if-change` with no stamp. **It varies
  with what was last rebuilt**: a no-op `make` in a dir whose `.md` rules had
  not re-run gave **8**, with the 24 absent entirely. Quote the composition you
  measured, never a remembered number.

  **A cold build is NOT empty** — an earlier version of this file said so and it
  is false on this host. A cold `all-gcc` is ~870 lines, ~370 of them
  `warning:`, dominated by `-Wmissing-field-initializers` and
  `-Wunused-parameter` from **nixpkgs gcc 15.2 compiling GCC** — host-compiler
  noise, not this tree. Figures of 664 / 698 / 867 are all the cold arm and are
  not comparable with the 32.

  So: classify against the 32-line composition for incremental, and against a
  recorded cold baseline for cold. **Never quote a stderr number without saying
  which arm it is.**
- `make cc1` rc=0 and `multi-target-objs` rc=0.

## 7. Reporting

**A TASK NUMBER IN YOUR BRIEF IS NOT SOMETHING YOU CAN READ.** The task list
lives in the coordinator's tooling; it is not in the worktree, and `STATE.md`
has sections for only some of it. A brief saying "read tasks #59, #56, #53"
is asking for something you do not have. **This is the coordinator's error,
not yours.** Say so plainly in your report, work from the measured evidence
and from `STATE.md`, and do **not** report against numbers you could not read
— an agent that quietly writes "#56: done" because the brief mentioned it is
manufacturing a green. One agent hit exactly this, said "these six are not in
this worktree", and worked from the wall it could measure instead. That was
the right response.

Coordinator's side of the same rule: **inline the content, not the pointer.**
If a task's finding matters to the brief, quote the finding.

**COMMIT YOUR WORK BEFORE REPORTING IT DONE.** Twice now an agent has reported
a change as "landed" and left it uncommitted in its worktree — once 65 lines,
once 15 files and +881/−332. The coordinator then has to read the diff and
commit it on your behalf, which is slower and puts an unreviewed change in
someone else's hands. `git diff --cached` before committing (the index is
shared), then `git log --oneline -1` to confirm the commit exists.

**"No `AC_ARG_*` and no assignment" does NOT mean a variable is unsettable.**
Generated `configure` auto-assigns `with_X` / `enable_X` from the command line
even with no `AC_ARG_*` for them. A naive scan for unsettable variables reports
**~40 false positives**; the genuinely unsettable set is small. Force the
variable and observe the branch before believing it is dead.

**When every arm of your probe reads empty, that looks exactly like "branch not
taken."** An agent's probe harness was wrong four ways and **all four failed
towards its hypothesis** — because an all-empty read is indistinguishable from
the thing it was trying to prove. Add a non-vacuity FATAL: the harness must
refuse to score when it cannot show it read anything at all.

**A count check passes when two errors cancel.** Measured: a generated
`global_options_init` had **1674 elements for a 1669-member struct** — five
invented and two missing. All the compiler said was `too many initializers for
gcc_options`. It noticed the *count* and nothing about the **1656 misplaced
values** — and had the five and the two been equal, it would have said nothing
at all while every member after the first divergence held another member's
value. Compare bodies, offsets and names; a count is the weakest evidence
available and is silent in exactly the case that matters.

**`awk '$0 ~ f'` ON A DEMANGLED C++ NAME MATCHES NOTHING.** The `()` in
`foo(rtx_insn*)` is an **empty regex group**, so the pattern matches nothing
and six object-level arms scored EMPTY — which reads as *"there is no per-base
copy"*, the opposite of the truth. Use `index($0, f)`. Sibling case: an `nm -C`
sweep anchored on `$` scored zero definitions for twelve of fourteen entry
points, the two that "worked" being function *pointers* with no argument-list
suffix.

**"There is no fallback for this macro" is NOT "this macro is not yet
defined."** An agent skipped the `#undef` when redirecting `FUNCTION_MODE`,
reasoning correctly that `defaults.h` has no fallback for it — but **the
primary's `i386.h` has already been read** by that point. `rc` stayed 0, the
redirect still won, and **the only signal was 495 warnings**. Always `#undef`
before redefining, and treat a warning-count change as a finding rather than
noise.

**`python3` IS NOT IN THE DEV SHELL, and a script that "runs" without it can
score a false green.** An injection arm written in Python did **nothing** —
`python3: command not found` — so every downstream reading was of the
*unmodified, fixed* compiler. It was caught only because that arm asserted
both halves of every hunk were actually gone; a "did it still build?" check
would have passed cleanly. Use `awk`/`sed`, and **assert that your injection
produced the state you intended** rather than that it exited. (A sibling case:
an injection deleted a `#define` but left the matching `#undef`, so the macro
became *undefined* rather than the primary's — the injection ran, and produced
a third state nobody was testing.)

**Your grep's `--include` list can exclude the answer.** Real case: a search for
what invokes `gen-reg-widths.sh` used `--include='*.in' --include='*.ac'
--include='*.sh' --include='Makefile*'` and concluded **nothing invoked it**.
The invocation is in a `*.awk` file, emitted into the *generated* makefile. That
is rule 1 of this section, committed by the person who wrote it. **Search the
generated artefact, and check what your filter excluded before believing a
zero.**

**`nm -u` with a plain-name grep can score 0 on C++ symbols — but check which
part failed.** Measured one way: nine of `function.o`'s ten undefined `ix86_*`
references are mangled, so a sweep built that way called the file clean.
Measured the other way, later: plain `nm -u | grep ix86_` scores the same as
`nm -uC`, because `_Z13ix86_cfun_abiv` *contains* the substring — the 0 needs
`grep -w` or `^`. **So the lesson is about the pattern, not the tool.** Use
`nm -uC`, and know which of the two you are relying on.

**One symbol can have several macro paths.** `ix86_cfun_abi` survived after
`STACK_BOUNDARY` was converted, because `function.cc` also spells
`ACCUMULATE_OUTGOING_ARGS`, which also expands `TARGET_64BIT_MS_ABI`. Closing
the path you found does not close the symbol; re-measure rather than assuming. This is the same shape as the
`T D B R` filter hiding COMDAT, and as `internal_dfa_insn_code` scoring 0
because it is a function on one back end and a pointer on another: **a zero from
a name-matching instrument is a claim about the instrument, not the code.**

**A symbol's name does not tell you which macro pulled it in.** `function.cc`
references `ix86_local_alignment`, which comes from `STACK_SLOT_ALIGNMENT` — not
from `LOCAL_ALIGNMENT`, which the name suggests and which that file never
spells. Converting the macro the symbol implies converts one nothing uses.

**An exit status of 0 is not evidence a pipeline succeeded.** Real case found
this session: `s-macro_list` ICEd and exited 0, because the ICE was the *head*
of a pipeline whose status is the last command's (`sort`'s). An empty
`macro_list` shipped and `fixinc.sh` read it as "nothing is predefined". Use
`set -o pipefail`, or check the artefact.



Say what you measured, what you did not, and what your instrument cannot see.
**A measured "still cannot be checked, because X" is a useful result; an
unexamined pass is not.** Distinguish upper bounds from lower bounds explicitly
and never quote one as the other. If a number in your brief is stale or
impossible, say so rather than reporting against it.
