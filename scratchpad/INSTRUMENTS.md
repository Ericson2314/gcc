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
| a hard `ulimit -v` around every `cc1` | `tb1-memcap.sh` |

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
