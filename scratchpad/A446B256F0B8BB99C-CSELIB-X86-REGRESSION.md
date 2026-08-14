# A live 6784-ICE x86_64 regression at `cselib.cc:2650` — found by re-scoring

Found while doing the brief's item 3 (re-score the board non-provisionally).
**It is not caused by this task's changes** — it is in the BASELINE build, at
branch HEAD `a8eb6bb16e3`, and the before/after reproducers show it identical
on both sides.

It is reported here rather than fixed, because it is a separate cause of a
size that deserves its own task, and because the diagnosis below names the
mechanism precisely enough to be actionable.

## 1. The measurement

Baseline suite run, `a8eb6bb16e3`, two bases, `MT_COMPILE_ONLY=1`, `-j8`,
all four `mtcheck.sh` guards green on both targets:

```
                           PASS     FAIL   XPASS  XFAIL  UNSUP   UNRES  ERROR
x86_64   T176 board      162165    16290       3   1556   4451   13354     16
x86_64   this run        136104    37386       4   1478   4459   25337     32
         delta          -26061   +21096      +1    -78     +8  +11983    (-j)

aarch64  T176 board       93055    96910       3    845  11012  128852     16
aarch64  this run         93042    96911       3    839  11012  128891     32
         delta             -13       +1       0     -6      0     +39    (-j)
```

**aarch64 reproduces T176 to within 13 PASS and 1 FAIL.**  x86_64 does not
reproduce at all, and the ICE column says why:

```
x86_64 ICE FAILs by site, this run
  6784  internal compiler error: in cselib_invalidate_regno, at cselib.cc:2650
     1  internal compiler error: in fail_formatted, at selftest.cc:64
  ----
  7113  total ICE FAILs
```

5699 of the 6784 are on `-ON -g` variants.  `-g` is the tell: `cselib` is
driven by **var-tracking**, which only runs when debug info is on.

The ERROR 16 → 32 is the `-j` artefact documented in
`A446B256F0B8BB99C-ERROR-COLUMN.md` and is not a defect.

## 2. The diagnosis — the union's bound used as a per-base classifier

`cselib.cc:2648`:

```c
  if (regno < FIRST_PSEUDO_REGISTER)
    {
      gcc_assert (mode != VOIDmode);        /* <- line 2650 */
```

and `multi-target-macros.h:292`:

```c
#define FIRST_PSEUDO_REGISTER MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER
```

so the shared spelling is **the union's** value.  Measured in the build dir:

```
multi-target-reg-widths.h:21   MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER  95
insn-constants-i386.h:87       FIRST_PSEUDO_REG                          92   (i386's own)
config/aarch64/aarch64.h:770   FIRST_PSEUDO_REGISTER = LAST_FAKE_REGNUM+1 = 95
```

**The band is regnos 92, 93, 94.**  On x86_64 those are genuine PSEUDOS, but
they are `< 95`, so `cselib.cc:2648` takes the hard-register branch for them.
`VOIDmode` is the documented argument for invalidating a *pseudo* across a
call (the function's own comment, `cselib.cc:2631`), so the very next line
asserts.

**aarch64's own value IS 95, so aarch64 has no band and cannot show this
bug.**  That asymmetry is the whole explanation for an x86_64-only ICE column
on a branch whose defects are almost always the other way round, and it is a
neat inversion of the usual shape: here the primary is the victim, because the
union bound happens to equal the *other* base's answer.

This is PRINCIPLES' documented third instance — *"the bound is the union's,
the numbering is per base"* — and `MT_FIRST_PSEUDO_REGISTER` exists precisely
so a site can say which of the two it means.

## 3. What the fix looks like (not done here)

`cselib.cc` spells `FIRST_PSEUDO_REGISTER` at 882, 2438, 2480, 2641, 2648,
2676, 2932, 3065, 3372.  They are **two different questions** and must not be
converted as a block:

- **CLASSIFIERS** — "is this regno a hard register?" — 2438, 2480, 2641, 2648,
  2676, 2932.  These need the SELECTED base's own count,
  `MT_FIRST_PSEUDO_REGISTER`.
- **BOUNDS / LAYOUT** — 882 and 3372 walk `0 .. FIRST_PSEUDO_REGISTER`, and
  3065 is `#define MAX_SETS (FIRST_PSEUDO_REGISTER * 2)`, an array size.
  These want the union, i.e. stay as they are — a walk sized by the base but
  indexed into a union-sized table is the *opposite* bug.

Getting that split wrong in either direction is a live crash, so each site
needs deciding individually rather than by sed.

## 4. Provenance — when did it land?

Not established.  It is **absent from T176's board** (x86_64 frozen to the
unit against T173) and **present at `a8eb6bb16e3`**, so it entered on the
merges between them.  `git log 2b20283b6b1..a8eb6bb16e3` is the range to
bisect, and the reproducer is one file:

```
cc1 -quiet -nostdinc -O2 -g -ftarget-config=<x86_64 cfg> \
    scratchpad/a446b256f0b8bb99c-cfi.c -o x.s
  -> internal compiler error: in cselib_invalidate_regno, at cselib.cc:2650
```

(that file is a copy of `gcc.dg/shrink-wrap-sibcall.c`, and it reproduces in
one second — it does not need the suite).

## 5. Why this matters beyond its size

The x86_64 `-O2 big.c` codegen bar is **byte-identical** through all of this
(12369 / `378fc33c1e70`), and so are both `specs-config` files.  A 6784-ICE
regression on the primary target passed every standing bar this branch has,
because `big.c` is compiled without `-g`.

**The bars do not cover debug info at all.**  That is the transferable
finding: a `-g` arm on the codegen bar would have caught this the day it
landed, and costs one extra `cc1` invocation.
