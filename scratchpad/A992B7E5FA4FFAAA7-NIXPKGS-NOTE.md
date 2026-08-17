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
