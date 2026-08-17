# RELAYED NOTE — the `_FOR_BUILD` / `_FOR_TARGET` export block in `gcc/ng`

**Not my finding and not my task.** Recorded here verbatim in substance because
it arrived mid-board through the only open channel and would otherwise be lost;
the coordinator's own instruction was that it needs no action from me and that
the board comes first. Written down rather than acted on.

## The observation

The user pointed at the `_FOR_BUILD` / `_FOR_TARGET` block in the `gcc/ng`
expressions — the twenty-odd lines that `basename` a tool out of `$AS`,
re-derive it with `lib.getExe'`, then export `AS`, `CC`, `CPP`, `CXX`, `LD`
**and** their `_FOR_BUILD` and `_FOR_TARGET` variants — and named it as exactly
what the libgcc and libgo work should delete.

## Why it is there, in this branch's own terms

**GCC's top level is a distro.** That block is nixpkgs hand-feeding it the
three-machine `build`/`host`/`target` vocabulary it expects, per component, in
shell. A component that ran only its own build system would take a compiler as
an ordinary derivation input and need none of it.

This is the same sentence as PRINCIPLES §2's *"the top level is the only
component that legitimately deals in targets, because it is the dispatcher"* —
seen from the packaging side. The exports exist to satisfy the dispatcher, not
the components.

**`libgcc` is where it bites hardest**, because the top level renames its
`--target` into libgcc's `--host` — and libgcc is **one machine's library**, so
it should have a `--host` and no target at all. That is the recorded
`libgcc config inversion` item, arriving by a second route.

## The adjacent measurement, if someone wants it

> Which of those exports does `libgcc/configure` **actually read**, and which
> are only there for the top level's benefit?

Same shape as the boundary enumeration already done for `libgcc.mvars`, where
the answer was **two variables, one of which is the inversion**. So the prior
is that the real dependency is very small and the block is mostly ceremony for
the dispatcher — but that is a prediction, and the enumeration is the thing
that would settle it.

Method note that transfers directly from this session: enumerate **both**
channels before claiming a population (the `EXTRA_HEADERS` lesson —
`config.gcc` *and* the tmake fragments), and read what the consumer actually
opens rather than what the variable is named after.

---

# THE PACKAGING SHAPE, AS MEASURED FROM THE nixpkgs SIDE

Appended by the `gcc/ng` packaging work (`ElvishJerricco/nixpkgs`, branch
`gccng-multi-target`). These are constraints the branch imposes on anything that
installs it, and each was found by a build failing rather than by reading, so
each is written where the next person will look before rediscovering it.

## `gcc-unwrapped` + `target-specs` CANNOT BE JOINED WITH SYMLINKS

A distro has one compiler for many targets and one spec file per target, and
they are separate artefacts. The obvious way to present them together — a
symlink farm, which is how nixpkgs composes almost everything — **does not
work**, and it fails in a way that names the wrong thing.

`find_target_config` (`gcc/gcc.cc:8694`) searches, in order:

1. `$GCC_EXEC_PREFIX`;
2. `make_relative_prefix (argv0, standard_bindir_prefix, standard_exec_prefix)`;
3. the configured-in `STANDARD_EXEC_PREFIX`.

Route 2 resolves from where the driver binary **really** is. So in a farm whose
`bin/<target>-gcc` is a symlink into the compiler's own store path, the search
root is the *compiler's* prefix — and the diagnostic correctly names a path
where the file genuinely is not, while the spec file sits in the directory the
user actually invoked. Everything about the farm succeeded.

Route 1 is not the escape either: `GCC_EXEC_PREFIX` is also the root for the
executable search, so pointing it at the spec file's prefix finds the config and
then fails with `cannot execute 'cc1'`. **One knob, two questions.**

What works: the driver binaries are **copied** into the composed prefix and
everything else is symlinked. Only `argv0` has to resolve inside it. Measured —
`aarch64-unknown-linux-gnu-gcc -S` then emits correct aarch64, `.arch armv8-a`
and `.type f, %function`.

Corollary for the check: ask the **consumer**. The composed derivation runs
`<target>-gcc -dumpspecs`, which reaches `set_up_specs` and so needs the config
file. Every file-placement check passes for the symlink farm too.

## `target-specs` WRITES NO FILE, AT EXIT 0, WITHOUT THE TARGET'S BINUTILS

Measured by running it with `--with-tools-dir=` empty: it reports
`skipping <path>: target tools unavailable, nothing probed` and exits **0**.
This is the good behaviour — far better than the pessimistic file — but it means
a packaging step must check for the artefact and not the status. With real
tools: aarch64 and x86_64 each probed against their own toolchain differ by 26
capability lines and 45 spec lines, so the instrument discriminates.

## THE COMPOSED COMPILER IS A `targetPlatform` FACT, NOT A `hostPlatform` ONE

Obvious in retrospect, and it cost a build: composing from `hostPlatform` gives
a cross wrapper holding **x86_64's** spec file with **aarch64's** bintools. The
compiler runs on the host and serves the target; the spec file it carries is the
target's. The failure surfaced two components away, in libgcc's configure, as
`cannot compute suffix of object files`.

## WHERE STANDALONE `libgcc` STOPS TODAY — and it is #246

With the above in place, libgcc's configure gets a working driver, cc1 runs and
emits correct aarch64 — and then the driver cannot find an assembler, because it
looks for the **unprefixed** name and a cross binutils installs only
`<triple>-as`. See `just_machine_prefix`: `gcc/gcc.cc:3274` prepends it in every
machine-agnostic directory under a comment about disambiguating targets, and
`gcc/gcc.cc:9305` is the **only** assignment, to `""`, inside `set_up_specs`,
which runs before the target is resolved. Filed as #246. **Do not shim this in
the packaging** — a `PATH` trick would make the mechanism look fine forever.

## `fixincludes` AFTER `37ba8d9fa48`: THE BOUNDARY THAT IS LEFT

`itoolsdir` now has a single producer — `mkinstalldirs` ships with it, so a
consumer no longer installs gcc for one shell script, and `mkheaders`
self-locates by `dirname $0`, which is correct in a store path.

`itoolsdatadir` does **not**. A fixincludes-only install yields exactly
`lib/gcc/<version>/install-tools/include/README`; `fixinc_list`, `gsyslimits.h`
and the per-multilib `limits.h` are still gcc's `install-mkheaders`
(`gcc/Makefile.in:6889`), and `mkheaders`' own `--itoolsdatadir` help text says
so. Verified by pointing `--itoolsdatadir` at fixincludes' own tree: it fails by
name on `fixinc_list`.

So the per-target `include-fixed` step depends on `gcc` for **data**, not for a
script. That is a defensible boundary — the data is per-multilib and gcc is what
knows the multilibs — but it is a boundary, and "no gcc install needed" is true
of `itoolsdir` alone.

## ONE PER-TARGET DECISION IS STILL MADE PER HOST

`fixincludes/Makefile.in:178` runs `mkfixinc.sh $(target)`, which chooses
between the real fixer and a two-line `exit 0` from a `case` listing cygwin,
mingw, vxworks7, several powerpc embedded targets and **every musl target**.
Built once per host, that is one target's answer standing in for everyone's, and
it fails quietly: the no-op exits 0 and leaves an empty `include-fixed`
indistinguishable from a target with nothing to fix. The packaging works around
it by regenerating `fixinc.sh` per target; the decision belongs at run time,
beside everything else `mkheaders` already takes as an option.
