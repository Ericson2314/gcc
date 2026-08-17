# TASK PROPOSAL: `specs-src-<target>` / `mlib-specs-<target>` — the last per-triple artefact

Filed as a proposal, not a task: task numbers live in the coordinator's tooling
and this agent has no `TaskCreate`. Coordinator to enter it; everything needed
to do so is below.

Split out of #261 at the coordinator's direction — **do not scope it into
#261.**

---

## THE FINDING, AND IT IS NOT WHAT MY FIRST REPORT SAID

I reported these as two more per-triple files in *gcc's* install. That was
wrong and the correction makes the finding bigger, not smaller.

**GCC does not install them at all.** Nothing in this tree does:

- `Makefile.tpl:2527` only *reads* them out of the gcc **build** directory, to
  pass as `--with-source-specs`.
- `grep -rn 'specs-src' gcc/Makefile.in` is four hits, all comments or the
  `find ... ! -name 'specs-src-*'` exclusions at `:4150` and `:4227`.

**nixpkgs installs them**, in `postInstall`:

    pkgs/development/compilers/gcc/ng/common/gcc/default.nix:751-755
      srcspecs="$out/lib/gcc/${release_version}/multi-target"
      install -m644 multi-target.manifest multi-target.multilib "$srcspecs/"
      install -m644 specs-src-* "$srcspecs/"
      for f in mlib-specs-*; do ...

So this is **packaging specifying an upstream gap**, in the exact sense the
project already uses: the expression enumerates per triple *because gcc cannot
produce a target's source-derived spec half on demand*. Every `install
specs-src-*` is a claim about a missing GCC mechanism, and the claim is true.

## WHY IT IS THE SAME DEFECT

The mechanical test from PRINCIPLES — *"does a target triple appear anywhere
below the top level: in a source file, a generated file, an installed path, a
manifest key?"* — is satisfied here. `specs-src-<target>` is triple-**named**
rather than triple-**directoried**, which is why acceptance arm 1's wording
("no directory named after a triple") missed it while the principle does not.

It is a finite sample of an infinite set: a target the compiler was not built
for has no `specs-src-` file, so it cannot get a spec file, so it cannot be a
machine in the package set.

## WHY IT LOOKS CLOSABLE BY THE MOVE #261 JUST MADE

`specs-src-<target>` is the **`tm.h`-derived half** of the spec file — the nix
expression says so itself (`target-specs/default.nix`: *"That is the tm.h-derived
half of this target's spec file, and there is no probe that could recover it
here"*). That sentence was true when written. It is no longer:

**`tm.h` is now generable from source for an arbitrary triple, outside any build
directory, byte-identical to the build tree's** — measured in `26d238fe1a2`, for
`aarch64-unknown-linux-musl` and `armv6l-unknown-linux-gnueabihf`, and
demonstrated on demand for `riscv64-linux-gnu`, `x86_64-w64-mingw32` and
`pdp11-aout`, none of which is configured in this tree and none of which has
binutils here.

So the input that `specs-src-<target>` is derived FROM is now available to
`target-specs/configure` at the moment it runs. If the generator that turns
`tm.h` into the source-derived spec half can be run there too, the file stops
being an installed per-triple artefact and becomes a computation — and
`--with-source-specs` disappears along with the last of nixpkgs' class (a)
flags.

## WHAT TO MEASURE FIRST (do not assume the above)

1. **What actually produces `specs-src-<target>`?** `gcc/Makefile.in:4085` and
   the `multi-target-specs` target. Establish whether its inputs are exactly
   (`tm.h`, back-end sources) or whether it also needs something only a built
   compiler has — the second would sink the whole idea and is the cheap thing
   to check first.
2. **`mlib-specs-<target>` is a different animal and may not follow.** It comes
   from `gen-multilib-specs.sh`, which the nix expression notes *"can fail for a
   target with no multilib tables"* and which is therefore already optional.
   Multilib data may be genuinely per-triple in a way `tm.h` is not. Treat the
   two files as two questions, and expect the answer to differ.
3. **Non-vacuity:** whatever is generated must be compared byte-for-byte against
   the build tree's `specs-src-<target>` for at least two targets on DIFFERENT
   back ends, and those two must differ from each other. The identity harness
   `scratchpad/a302b44ba-t249-specsid.sh` has the shape.

## WHAT IS ALREADY TRUE AND NEED NOT BE REDERIVED

- `target-specs/configure` sources `config.gcc` and canonicalises through
  `config.sub`; `cpu_type`, `option_defaults`, `decimal_float`,
  `decimal_bid_format` and the `t-slibgcc` answer are all derived (`7f8bf7d047e`).
- It writes `tm-<key>.h` + `tm.h` into `$(dirname $specs_file)/include`
  (`26d238fe1a2`), ungated on `$have_target_tools` because nothing there is
  probed.
- The three replication traps — the `gen-target-manifest.sh:490` per-base
  rewrite, the deliberate `TARGET_CPU_DEFAULT` disagreement between the two
  generators, and `gcc/configure.ac`'s post-`config.gcc` appends — are commented
  at their sources.
