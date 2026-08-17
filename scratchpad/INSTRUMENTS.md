# INSTRUMENTS — the current harness. Read this before writing a `t<NNN>-*.sh`.

`scratchpad/` holds ~780 files. Almost all of them are **one script copied per
task**. If you are about to write `t<NNN>-conf.sh`, the answer is already here.

## The set

| job | script |
|---|---|
| shared guards, sourced by all | `mt-lib.sh` |
| configure a build dir with a base set | `mt-conf.sh` |
| build in it, stamped | `mt-build.sh` |
| run `target-specs` per target (2 targets, hardcoded) | `mt-specs.sh` |
| run `target-specs` for the 4-target set, real cross tools | `taa-tools.sh` + `taa-specs.sh` |
| the x86_64 `-O2` codegen bar | `mt-bars.sh` |
| **the target's own `specs` file was actually READ** | `mt-specsread.sh` |
| `MULTI_TARGET_RENAME_NAMES` completeness | `mt-rename-sweep.sh` |
| the testsuite, once per target | `mtcheck.sh` |
| score its runs | `mtscore.sh` |
| every cited `scratchpad/` path exists | `mt-cite-check.sh` |
| **run one `.exp` and PRESERVE its `.sum`/`.log`** | `a5764a65f9eec0063-score.sh` |
| classify a `.sum`'s FAILs: COMPILE vs BODIES vs SCAN | `a5764a65f9eec0063-kinds.sh` |
| both-sided codegen, all four targets, two build dirs | `a5764a65f9eec0063-bothsided.sh` |
| is a `-g` md5 difference real or just the path? | `a5764a65f9eec0063-gcheck.sh` |
| **run one `.exp`, PRESERVE its artefacts, TOOLS/OUT from the environment** | `aa1e1db1aead2bffb-score.sh` |

`aa1e1db1aead2bffb-score.sh` is `a5764a65f9eec0063-score.sh` with the two lines
that forced the copy taken out: that script hardcodes
`/tmp/tools-a5764a65f9eec0063/bin` and `/tmp/w-a5764a65f9eec0063/scores`, i.e.
**another worktree's cross assembler**, which is GUARD 3c's own failure mode
wearing a harness's clothes. Here `TOOLS` and `OUT` come from the environment
and `$TOOLS/<triple>-as` is asserted executable before anything runs, so a
missing cross assembler fails by name instead of silently falling back to the
host `as`.

**AND A LONG RUN MUST BE DETACHED (`setsid nohup`), NOT A HARNESS BACKGROUND
TASK.** Measured, twice, in one task: the agent harness culls background
commands, and it killed two `mtcheck` runs mid-`.exp` after ~40 minutes each.
The damage is not only the lost time — a culled `mtcheck` leaves a **stale
`check-<triple>.rc` beside a PARTIAL `gcc.sum`**, which is exactly the shape
PRINCIPLES warns about: the stamp says a run finished and the file no longer
belongs to it. `fixboard.sh`/`baseboard.sh` therefore `rm -f` the stamp before
relaunching, so a copy cannot be authorised by the previous run's rc.

## TWO TRAPS THESE FOUR EXIST FOR, BOTH HIT IN ONE SESSION

**`mtcheck.sh` OVERWRITES THE PREVIOUS RUN'S `gcc.sum` AND `gcc.log`.** Every
run writes `testsuite.<triple>/gcc/gcc.sum`, so launching a second `.exp`
destroys the first's artefacts — and a destroyed file looks exactly like a
present one. I read a `sme/acle-asm` log believing it was `sme2/acle-asm`'s and
built a wrong explanation on it. **The `.rc` stamp says a run FINISHED; it does
not say the file on disk still belongs to that run.** What caught it was that
the classifier greps a literal directory string a foreign `.sum` cannot match,
and its totals equalled `mtcheck`'s own stamped figures — so one reading was
provably of the right file and the other provably was not.
`a5764a65f9eec0063-score.sh` copies both artefacts before returning.

**`mt-bars.sh`'s `-g` ARM IS PATH-SENSITIVE.** It compiles
`$SRC/scratchpad/big.c`, and `-ftarget-config=<builddir>/...` lands in
`DW_AT_producer`. Two build dirs whose names differ by one character give
different `-g` md5s with an identical compiler, because the string length
change also reshuffles the `.LASF` table. The `-O2` bar has no debug info and
is immune. Same shape as the aarch64 `-S` bar being filename-sensitive via
`.file`, which PRINCIPLES already records. **Never quote the `-g` md5 without
its input path AND its build dir**; `a5764a65f9eec0063-gcheck.sh` settles it by
compiling one constant absolute path with both compilers.
| a hard `ulimit -v` around every `cc1` | `tb1-memcap.sh` |

## THE FOUR LEAK CLASSES AND THEIR SWEEPS — read this before hunting a leak by hand

Every leak this branch has found is in one of four enumerable classes, and
until now **three of them had no sweep** and were found by accident.
`A992B7E5FA4FFAAA7-FLOORSWEEP.md` / `-ABSENCESWEEP.md` carry the results.

| class | shape | sweep |
|---|---|---|
| floor-dead | `#ifndef` floor in `defaults.h`, primary **defines** the name, so the floor is dead and all 47 get i386's body (`EPILOGUE_USES`, `REGMODE_NATURAL_SIZE`) | `agent-a992b7e5fa4ffaaa7-floorsweep.sh` |
| floor-fires | `#ifndef` floor, primary **silent**, so the floor runs and the *dissenters* read it (`TARGET_HAS_FMV_TARGET_ATTRIBUTE`, `STACK_POINTER_OFFSET`) | same |
| leaked absence | bare `#ifdef` in a **shared** TU on a name the primary does not define, so the guarded code runs for **nobody** (`FINAL_PRESCAN_INSN`, `TRAMPOLINE_SECTION`) | `agent-a992b7e5fa4ffaaa7-absencesweep.sh` |
| generated header | the name lives only in a **generated per-base header** and the build root's shared copy is the primary's (`DELAY_SLOTS`, `HAVE_conditional_execution`, `insn-modes.h`, `options.h`) | `agent-a992b7e5fa4ffaaa7-genhdrsweep.sh` |
| **guard-true-for-all** | **bare `#ifdef` in shared code on a name the PRIMARY DEFINES, so the guard is true for everyone and the VALUE inside is the primary's** (`EH_RETURN_STACKADJ_RTX` — i386's `CX_REG` is 2, which on riscv is `sp`) | **nothing yet** |

**The fifth row has NO `defaults.h` floor anywhere in its story**, so
`floorsweep.sh` cannot see it, and it is not the leaked-absence row either:
`absencesweep.sh` looks for names the primary is SILENT about, and here the
primary is the definer. It leaks presence and value at once — the guarded code
also runs for the back ends that define nothing. Enumerable in the same way as
the others: *a bare `#ifdef <NAME>` in a shared TU where `<NAME>` is `#define`d
by i386 **and** by some other back end with a different body.*

**The per-row discriminator is `agent-a992b7e5fa4ffaaa7-floorread.sh`** — the
both-sided header read, shared `tm.h` against each `<base>-inc/tm.h`. **It MUST
be run with `-DIN_GCC`**: the back-end header chain sits inside `#ifdef IN_GCC`,
so without it every arm reads the floor, every row looks converted, and the
instrument refutes all findings at once while looking clean. That mistake was
made and caught here.

**A header divergence is a CANDIDATE. The compiler gives the verdict.** Two
worked examples, opposite ways: `DEFAULT_PCC_STRUCT_RETURN` diverges (shared 1,
aarch64 0) and is **not** a leak, because its only consumer is `common.opt`'s
`Init(...)` and the options initialiser is generated per base; while
`STACK_POINTER_OFFSET`'s divergence is a **live ABI break**, shown by diffing
one function's assembly against the stock compiler. The three reproducers
(`-spo.sh`, `-tramp.sh`, `-ehreturn.sh`) are the shape to copy: compile a small
program with both compilers and diff, with a non-vacuity arm that refuses if
the grep read nothing.

**And a compile-only board cannot see any of this.** The s390x ABI break, the
aarch64 trampoline in `.rodata` and `__builtin_eh_return` failing on two
targets all assemble cleanly into well-formed objects of the right machine.
Found by compiling four small programs; invisible to 197,827 test results.
| **a real cross `as` for an ARBITRARY triple** | `a7ee6ca7c923e4a58-astry.sh` |

## GETTING A CROSS ASSEMBLER: THE TWO ATTRIBUTES, AND THE RECORDED CLAIM THAT IS ABOUT THE WRONG THING

`taa-tools.sh` reads `pkgsCross.<attr>`, a **hand-curated** attribute set with
an entry per nixpkgs-supported system. `TAA-BOARD.md` §4b concluded from it
that *"nixpkgs has no binutils for visium or xtensa (0 of 27,157 attributes)"*
and used that to justify the host-`as` fallback, which makes every
assembler-dependent verdict for those targets UNTRUSTED.

**That is a statement about the ATTRIBUTE SET, not about binutils.** An
arbitrary triple can be requested directly:

```nix
with import <nixpkgs> { crossSystem = { config = "alpha-linux-gnu"; }; };
buildPackages.binutils-unwrapped
```

which yields a real `alpha-linux-gnu-as` 2.46 (built from source, ~67s) for a
target with **no `pkgsCross` attribute at all**. Two details, both measured,
both of which turn a non-finding into a "finding" if you get them wrong:

- **`binutils-unwrapped`, NEVER `binutils`.** The *wrapped* cross binutils
  depends on the target libc, so `or1k-elf` fails **inside newlib** — and that
  gets recorded as *"no cross assembler for or1k"* when the assembler builds
  perfectly. A libc is not needed to assemble, and the compile-only /
  `scan-assembler` axis needs no libc by construction. The next agent will
  reach for the obvious attribute; this is why not to.
- **PIN THE SUBSTITUTER.** The ambient nix config lists caches on
  `obsidian.webhop.org` that are unreachable here, retried 5x at a 15s timeout
  **per derivation**. The first sweep spent ~15 minutes on ONE target
  compiling nothing, which reads as *"cross binutils are expensive to build"*
  and is entirely network dead time. Pass
  `--substituters https://cache.nixos.org/ --option connect-timeout 5`, as
  `taa-specs.sh` and `eb-shell.sh` already do.

**THE ROUTE HAS ITS OWN LIMIT, AND IT IS NOT BINUTILS EITHER.** `crossSystem`
goes through `lib.systems.parse`, whose CPU table is narrower than binutils'
target list, so `visium`, `xtensa`, `arc`, `arm-eabi`, `cris`, `csky`,
`epiphany`, `fr30`, `frv`, `ft32`, `h8300`, `lm32`, `m32r`, `mcore` and others
fail to **evaluate** with `error: Unknown CPU type: <cpu>`.

So there are **three** verdicts and they must not be collapsed — each names a
different missing artefact, and only the third is a statement about the target:

| verdict | what is actually missing |
|---|---|
| `EVAL-FAIL` | **nixpkgs cannot describe the triple.** Says nothing about binutils; GNU `as` may well support the target. |
| `BUILD-FAIL` | nixpkgs describes it; binutils does not build or substitute for it. |
| `OK` | `<prefix>-as --version` **executed**. |

`OK` asserts the binary *runs*, not that a path exists: a dangling symlink or a
wrong-arch binary is exactly the shape that falls back to the host `as` three
layers away, which is `taa-tools.sh`'s own recorded naming trap and the defect
GUARD 3c exists for (~10,000 results per target).

**And note what an assembler is and is not needed FOR.** Per the user's ruling
recorded in `TAA-BOARD.md` §3, a `scan-assembler` test needs no libgcc, no
linker, no execution and **no assembler** — it compiles to `.s` and greps the
text. The assembler is required for `target-specs` to probe `<triple>-as` and
emit a `specs-config`, and for GUARD 3c. So "no cross `as`" bounds how far a
target's specs can be TRUSTED; it does not by itself mean the target cannot be
scored on the compile-only axis.
| **which target macros leak from the primary's chain** | `agent-a018835bbcfad2e28-leakcensus.sh` |
| DESCRIPTOR macros still spelled raw in shared code | `agent-a4568de8f522450d3-descaudit.sh` |
| target macros `tm.texi` does not document at all | `agent-a4568de8f522450d3-undoc.sh` |
| **does `target-cumargs.cc` compile for all 47 bases?** | `agent-a4568de8f522450d3-syncheck.sh` |
| does the `.option`/`.machine` bracket balance, both-sided | `agent-a4568de8f522450d3-bracket.sh` |
| **does `cc1` shift out of range in `AARCH64_APPROX_MODE`?** | `a51a0e8b2b458063b-ubshift.sh` |
| the max `AARCH64_APPROX_MODE` shift, from `insn-modes.h` alone | `a51a0e8b2b458063b-shiftscan.sh` |
| aarch64 + x86_64 FP codegen on the inputs that reach that site | `a51a0e8b2b458063b-bothsided.sh` |
| an immutable snapshot **named for its sha as well as the worktree** | `a51a0e8b2b458063b-snap.sh` |

`a51a0e8b2b458063b-ubshift.sh` is the cheap shape for "is there UB in ONE
translation unit": rebuild that object with `-fsanitize=shift`, relink `cc1`,
run. A whole sanitized 47-base build costs hours and answers a wider question.
Its ARM 1 is the part to copy — it refuses to score until it has seen
`__ubsan_handle_shift_out_of_bounds` as an undefined reference in the rebuilt
object, because **"UBSan reported nothing" and "UBSan was never enabled here"
are the same empty log.**

`a51a0e8b2b458063b-snap.sh` puts the sha in the snapshot path, and the reason
is a near-miss worth knowing: overwriting a snapshot path that an
already-configured build dir points at breaks nothing loudly, because a build
dir re-reads its srcdir long after configure — `mt-bars.sh` takes `big.c` from
it, and rebuilding one object recompiles *that tree's* source. The next arm
would have measured the other commit and said so with a green.

## THE EXAMPLE IN THIS FILE WAS WRONG IN TWO WAYS AND BOTH COST BUILDS

Recorded verbatim rather than quietly replaced, because both are shapes an
agent will reproduce from memory:

**1. `--enable-targets=i386,aarch64` DOES NOT WORK. Triples are required.**
`--enable-targets` is the TOP LEVEL's flag and the top level is the target
dispatcher: it hands each entry to `config.sub` and then to `config.gcc`.
Measured at `5eb6cb0e5e3`:

```
$ sh config.sub aarch64   ->  aarch64-unknown-none
$ sh config.sub i386      ->  i386-pc-none
```

and `gcc/config.gcc` has no case matching `*-*-none` for either (`aarch64*-*-elf`,
`aarch64*-*-linux*`, ... but nothing bare), so it reports the target
unsupported and the build dies inside `configure-gcc`. The failure is one
layer below where the flag was typed, which is why it reads as a broken tree.
A bare back-end NAME is what `gcc/configure`'s `--enable-backends` takes, and
that flag is DERIVED by the top level (`configure.ac:279`) — you do not spell
it yourself.

**2. `SRC=$PWD` BUILDS THE LIVE WORKING TREE, which PRINCIPLES §4 forbids at
length.** A merge or an edit landing mid-build produces a torn read that
diagnoses a state no commit ever had, naming real symbols. Snapshot first.

## Typical run — this one was executed at `5eb6cb0e5e3`

```sh
W=$PWD                                             # the worktree
ID=<full worktree id, e.g. agent-a57163422943aaa57>
A=$(grep -c MULTI_TARGET gcc/Makefile.in)          # 52 at 5eb6cb0e5e3;
export WANT_ANCHOR=$A                              #   run it, do not copy it

# 1. an IMMUTABLE snapshot -- never $PWD
rm -rf /tmp/snap-$ID && mkdir -p /tmp/snap-$ID
git archive HEAD | tar -x -C /tmp/snap-$ID
git rev-parse --short HEAD > /tmp/snap-$ID/SNAP-SHA
chmod -R a-w /tmp/snap-$ID

# 2. TRIPLES, comma-separated, and the build dir named for the FULL worktree id
SRC=/tmp/snap-$ID sh scratchpad/mt-conf.sh /tmp/b-$ID \
  x86_64-pc-linux-gnu,aarch64-unknown-linux-gnu,\
riscv64-unknown-linux-gnu,s390x-linux-gnu
sh scratchpad/mt-build.sh /tmp/b-$ID all-gcc all-gcc

# 3. per-target specs.  mt-specs.sh serves the two-base pair ONLY; the
#    four-target set needs real cross binutils, which taa-tools.sh materialises.
sh scratchpad/taa-tools.sh /tmp/tools-$ID
B=/tmp/b-$ID TOOLS=/tmp/tools-$ID sh scratchpad/taa-specs.sh

# 4. bars, and the guard that the specs are actually reaching cc1
sh scratchpad/mt-bars.sh      /tmp/b-$ID
sh scratchpad/mt-specsread.sh /tmp/b-$ID x86_64-pc-linux-gnu aarch64-unknown-linux-gnu
# MT_STAMP must name the tag you passed to mt-build.sh; it defaults to
# `make-cc1.rc' and refuses by name otherwise.  And it needs `nm', so it runs
# INSIDE the dev shell -- outside it, `nm' is absent and a tool-not-found piped
# into `grep -c' scores 0, which looks clean.
sh scratchpad/eb-shell.sh \
  "WANT_ANCHOR=$A MT_STAMP=all-gcc.rc sh scratchpad/mt-rename-sweep.sh /tmp/b-$ID"

# 5. the board.  mt-specsread.sh is a PRECONDITION on this, not a nicety --
#    see its header for what every board taken before it was measuring.
MT_COMPILE_ONLY=1 sh scratchpad/mtcheck.sh /tmp/b-$ID <triples...>
```

Note `s390x-linux-gnu` on the command line and `s390x-ibm-linux-gnu`
everywhere afterwards: `config.sub` canonicalises it, and the canonical form is
what names the per-target directory, the `specs-config` and the tools.

## Why the names carry no task number

Two failures, both this project's own root bug in its own tooling.

**One name, several authorities.** `gcc/Makefile.in` said its rename check was
`scratchpad/sweep.sh`, which did not exist; then `t150-`, `t155-`, `t157-`,
`t165-`, `t167-rename-gap.sh` — six instruments for one job, each written
because the previous "was inadequate", which was true when said and stopped
being true. Nothing said which was live.

**`t<NNN>` collides by construction.** Task numbers are handed out in
neighbouring blocks, so two unrelated agents pick the same filename: four
add/add merge conflicts in one day (`t160-*`, `t173-*`, `t174-*` twice), all on
unrelated work. Taking either side would have silently deleted a working
harness.

**And the thing that FORCED every copy was one guard.** Each script asserted
its build dir by this worktree's hash, hardcoded:

```sh
case "$D" in */b-a7de5*) ;; *) echo "FATAL: not named for this worktree"; exit 9 ;; esac
```

Right guard — a harness must assert which tree it measures — and unrunnable
from the next worktree, so the next agent copied it under a new number.
`mt-lib.sh` **derives** the tag from the script's own path instead. Same guard,
no edit per worktree, no number to collide on. If you find yourself editing one
line of an `mt-*.sh` to make it run, that line is a bug in `mt-lib.sh`; fix it
there rather than making the seventh copy.

## THREE WAYS A SCAN LIES, ALL THREE COMMITTED IN ONE SESSION BY ONE AGENT

These are here rather than only in a board because each is a shape the next
person writing a `grep`-based instrument will reproduce, and two of them were
committed by the agent who had just diagnosed the third.

**1. A SYNTAX CHECKER REPORTED 22 OF 22 BASES `ok` WHILE COMPILING NOTHING.**
`agent-a4568de8f522450d3-syncheck.sh`'s first run swept 22 back ends clean and
then failed its own control:

```
  aarch64      ok      (x22)
  bases checked ok=22 fail=0
  FATAL: the negative control did NOT fire; every 'ok' above is void
       g++: command not found
```

It was run outside the nix dev shell. Every compile died with `command not
found`, produced no `error:` line, and the "no errors" test scored it a pass.
PRINCIPLES already says *"a missing tool looks exactly like a zero result"*
and *"anything shaped `cmd | grep -c` needs `cmd` to have demonstrably run"* —
this is that, in a harness written an hour after reading both sentences.

The arm that caught it appends a deliberately undeclared identifier to the
file under test and **requires the compiler to name it**. Copy that arm. Note
what it is not: "did the command exit 0" would have passed (the loop's exit
status is the grep's), and "is the error file non-empty" would have passed too
(`command not found` is text). Only *demanding a specific diagnostic* works.
Re-run inside `eb-shell.sh`, it found a real missing include on the 20th base.

**2. AN UNANCHORED `grep` MATCHED THE COMMENT EXPLAINING THE FIX — A FALSE
RED.** A snapshot guard asserted a converted tree has no raw `#ifdef
ADJUST_INSN_LENGTH` left:

```sh
grep -q '#ifdef ADJUST_INSN_LENGTH' "$S/gcc/final.cc" && FATAL   # WRONG
```

The conversion's own comment at `final.cc:404` reads *"This was `#ifdef
ADJUST_INSN_LENGTH`, i.e. ..."*, so the guard refused a **correct** snapshot.
Anchor to line start:

```sh
grep -qE '^[[:space:]]*#[[:space:]]*ifdef[[:space:]]+ADJUST_INSN_LENGTH' ...
```

This is *mention versus use*, and the same agent had diagnosed it two commits
earlier in the census's DESCRIPTOR bucket (item 3). **A false RED costs what a
false green costs**: the remedy it invites is reverting a correct change. It
cost nothing here only because it fired before `configure`.

**3. MENTION-VERSUS-USE AT SCALE: A CENSUS BUCKET BUILT ON IT.**
`-leakcensus.sh` scores a macro CONVERTED if its name appears anywhere in a
`target-*.h` header. `agent-a4568de8f522450d3-descaudit.sh` measures the cost:
**35 of 94 are still spelled raw in shared code**, i.e. still leaking.
`ASM_OUTPUT_MAX_SKIP_ALIGN` is DESCRIPTOR on the strength of **one sentence**
in `target-caps.h:314` while `varasm.cc:2173,2181,2182,2184` and
`final.cc:2432,2436,2438` spell it raw.

That audit needed two fixes before its own number meant anything, both left
recorded in it rather than quietly corrected:

- a first-character comment test (`^\s*(/\*|\*|//)`) scored multi-line `/* */`
  prose as code — this branch's conversion notes are exactly that shape. **73
  of 94.** Comments are now removed by a state machine.
- `target-*.cc` was counted as "shared", but it is compiled ONCE PER BASE with
  `BASE_HEADER (tm.h)`, so `#ifdef PROMOTE_MODE` in it is the conversion
  *working*. **73 -> 35.**

**And the general rule the three share: a scan needs a NEGATIVE control, not
just a positive one.** A scan that flags everything has a perfect positive arm
and is worthless. `-descaudit.sh` carries four — `ASM_DECLARE_FUNCTION_NAME`,
`ASM_OUTPUT_FUNCTION_LABEL`, `PROMOTE_MODE`, `REG_ALLOC_ORDER`, all known
converted — and exits 9 if any is flagged. All four *were* flagged before the
population fix and none after; without them, `73 of 94` would have been
reported as a finding.

**A CONTROL ANCHORED ON A CONVERSION TARGET HAS AN EXPIRY DATE.**
`-undoc.sh`'s non-vacuity arm was anchored on `ASM_OUTPUT_FUNCTION_PREFIX` —
the macro the script was written to demonstrate — and went quiet within the
hour when that macro was converted. It printed *"NOT a pass, treat the total
as unverified"* rather than a green, which is the wanted behaviour, but this
is the `macro-probe-run.sh` shape PRINCIPLES records dying unnoticed for a
day. Re-anchored on `ADDR_VEC_ALIGN` **because it is not being converted**,
with an instruction to move rather than delete it. **Never anchor a control on
something your own task is about to change.**

## Adding to the set

Extend an `mt-*.sh`, or add one with a **descriptive** name. Do not fork.
If you must fork (an in-flight run must not see your edits), copy to a name
that says why, and delete it when the run lands.

`mt-cite-check.sh` asserts that every `scratchpad/` path named in
`gcc/Makefile.in` and `PRINCIPLES.md` exists. Run it after touching either.
It cannot say a citation is *right*, only that it is *there* — deliberately, so
it can only ever revoke a citation, never bless one.
