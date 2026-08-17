# `TARGET_HAS_FMV_TARGET_ATTRIBUTE` — aarch64's #1 residual, root-caused

**aarch64's largest single work item on the board is function multiversioning
(`mv*` 221 + `fmv*` 35 = **256** of its 513 debt, stock fails zero). It is one
macro, and the mechanism is the inverse of the one this branch usually meets.**

Found while the four-target board was running, using that board's own compiler.

## The observable

`gcc.target/aarch64/mv-1.c`, compiled with the 47-base `cc1` for aarch64:

```
error: redefinition of 'foo'
note: previous definition of 'foo' with type 'int(void)'
```

No `-Wattributes` warning, so `target_version` **is** a recognised attribute.
What fails is the decision that two decls are *versions* of one another, so the
second definition is treated as a plain redefinition.

**Control (both-sided, and it is what makes this invisible on x86_64):**
x86_64's own multiversioning works on the same compiler —
`__attribute__((target_clones("default","popcnt")))` emits a resolver
(10 `popcnt`/`resolver`/`ifunc` hits in the `.s`).

## The deciding line

`c/c-decl.cc:3457`:

```c
      /* Check if x is part of a FMV set with b_use.
	 FMV is only supported in c for targets with target_version
	 attributes.  */
      if (!TARGET_HAS_FMV_TARGET_ATTRIBUTE
	  && b_use && TREE_CODE (b_use->decl) == FUNCTION_DECL
	  ...
	  && disjoint_version_decls (x, b_use->decl)
```

With the macro **1**, that whole arm is skipped, `disjoint_version_decls` is
never consulted, and the redefinition diagnostic is emitted instead. The same
macro gates twelve sites in `multiple_target.cc`, five in `attribs.cc` and two
`gcc_assert`s in `tree.cc`.

## The population, and the polarity

```
$ grep -rn 'TARGET_HAS_FMV_TARGET_ATTRIBUTE' gcc/defaults.h gcc/config/
defaults.h:1001    #ifndef TARGET_HAS_FMV_TARGET_ATTRIBUTE
defaults.h:1002    #define TARGET_HAS_FMV_TARGET_ATTRIBUTE 1
aarch64/aarch64.h:1556   #define TARGET_HAS_FMV_TARGET_ATTRIBUTE 0
```

**aarch64 is the only back end in the tree that defines it, and it dissents.**

Measured from the build's own headers, `-DIN_GCC`, rc=0 on all three arms
(the first attempt omitted `-DIN_GCC`, which silently skips the entire back-end
chain inside `#ifdef IN_GCC` and made *every* arm read `1` — the
reduced-environment trap, recorded because the wrong reading is the plausible
one):

```
shared  tm.h            TARGET_HAS_FMV_TARGET_ATTRIBUTE 1   <- what c-decl.cc,
                                                               multiple_target.cc,
                                                               attribs.cc, tree.cc read
aarch64-inc/tm.h        TARGET_HAS_FMV_TARGET_ATTRIBUTE 0   <- aarch64's own answer
i386-inc/tm.h           TARGET_HAS_FMV_TARGET_ATTRIBUTE 1   <- the control
```

**THE POLARITY IS THE OPPOSITE OF `EPILOGUE_USES` AND `REGMODE_NATURAL_SIZE`,
AND THAT IS THE TRANSFERABLE PART.** In those cases the primary *defines* the
name, so `defaults.h`'s `#ifndef` is **dead** and everyone gets i386's body.
Here **i386 defines nothing**, the `#ifndef` floor *does* fire, and the floor's
value is correct for the 46 back ends that say nothing and **wrong for the one
that dissents**.

So the two failure modes are:

| primary | `#ifndef` floor | who is wrong |
|---|---|---|
| defines the name | dead | every back end that disagrees with the primary |
| defines nothing | fires | every back end that disagrees with **the floor** |

and PRINCIPLES §2a's test — *"ask whose answer the fallback is; if a second
configured back end would change it, it is the primary's"* — needs the second
row spelling out. A floor is not made safe by the primary being silent. **"i386
does not define it" is not the absence of a leak; it is the precondition for
this variant of one.** Any `#ifndef` in `defaults.h` whose name is defined by
*any* back end is in this class, whether or not i386 is that back end.

## Why the existing sweeps did not find it

Same reason `DELAY_SLOTS` escaped: the consumers are **runtime `if`s and `&&`
operands on a 0/1 valued macro**, not `#ifdef`s, so an `#ifdef`-shaped sweep
scores all nineteen consumer sites clean. `d1ae5fb5969` records that detection
gap for `DELAY_SLOTS`; this is a second instance of it, and it suggests the
right sweep is *"names `defaults.h` floors AND some back end `#define`s"*,
which is a closed, enumerable set.

## What it is worth

**256 results on aarch64, half that target's remaining debt**, where stock
fails zero. Sized from `A01E6C604F26604A7-BOARD` §5 (`mv*` 221, `fmv*` 35);
that is an upper bound in the `mt-debt-attribute.sh` sense — these files may
owe some of their debt to something else — and it is stated as one.

## The shape of the fix

Not attempted here: the board was mid-run against an immutable snapshot of this
tree, and landing a compiler change would have made my own measurement stale
for no gain. It is the settled cdata conversion —
`targetm_cdata.has_fmv_target_attribute`, supplied per base, with `defaults.h`
giving each *silent* back end upstream's own `1` (a **supply-side** floor,
which §2a explicitly permits) and aarch64 supplying its own `0`. No base would
read another's value.

The one thing to check when doing it: `tree.cc:15659` and `:15685` are
`gcc_assert`s on this macro. Per the `function.cc:6766` /`DELAY_SLOTS` lesson,
an assert that currently holds may be holding *because the answer is wrong*;
asked of the selected base it becomes a real check and must be re-measured, not
assumed.
