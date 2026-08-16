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

## Adding to the set

Extend an `mt-*.sh`, or add one with a **descriptive** name. Do not fork.
If you must fork (an in-flight run must not see your edits), copy to a name
that says why, and delete it when the run lands.

`mt-cite-check.sh` asserts that every `scratchpad/` path named in
`gcc/Makefile.in` and `PRINCIPLES.md` exists. Run it after touching either.
It cannot say a citation is *right*, only that it is *there* — deliberately, so
it can only ever revoke a citation, never bless one.
