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
5. **A clean result from an instrument with unexamined blind spots is worth very
   little.** Strong-symbol sweeps hid COMDAT; the COMDAT sweep hid macros; the
   macro probe found `BYTES_BIG_ENDIAN` by failing to compile. **State your
   instrument's blind spots.**
6. **A diagnostic-driven sweep fixes exactly the copies some configured triple
   compiles.** A poly_int sweep fixed 2 sites and left 7 identical siblings,
   having demonstrably reached those files. **Sweep the source, not the build
   output** — ~186 targets are never built.

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
- **Probe scoreboard** (verified, quote these): 230 header arms — i386 115 PASS
  / 0 FAIL, aarch64 **5 PASS / 110 FAIL**; 58 TAB arms — i386 29 PASS / 0 FAIL,
  aarch64 24 PASS / 5 FAIL. **Diff verdicts and probe shapes, never totals.**
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

**COMMIT YOUR WORK BEFORE REPORTING IT DONE.** Twice now an agent has reported
a change as "landed" and left it uncommitted in its worktree — once 65 lines,
once 15 files and +881/−332. The coordinator then has to read the diff and
commit it on your behalf, which is slower and puts an unreviewed change in
someone else's hands. `git diff --cached` before committing (the index is
shared), then `git log --oneline -1` to confirm the commit exists.

**`nm -u` with a plain-name grep scores 0 on C++ symbols.** Measured: nine of
`function.o`'s ten undefined `ix86_*` references are mangled, so a sweep built
that way calls the file **clean**. Use `nm -uC`. This is the same shape as the
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
