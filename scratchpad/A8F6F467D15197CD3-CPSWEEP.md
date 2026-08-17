# Sweeping `cp/` the way `final.cc` was swept

Worktree `agent-a8f6f467d15197cd3`, snapshot `e1f0cad1c2c`, anchor **52**,
cold 47-base `--enable-languages=c,c++` build, rc=0, 0 `error:`, `cc1plus`
links and executed. Instruments:
`scratchpad/agent-a8f6f467d15197cd3-cxxsurface.sh` (the ranking) and
`-macrocensus.sh` (the populations).

## 1. The list was RE-DERIVED, and the re-derivation changed the top of it

The brief supplied a ranking and said not to trust it. Right call, but not
for the reason it gave.

`agent-a260445cf27ba480a-cxxmacros.sh` scores a **hand-written list of 15
macros**. It cannot find a macro nobody thought of, so the top of its output
is necessarily the set its author was already working on. The replacement
computes an **intersection of two derived sets**: every identifier `#define`d
in a header under `config/` or in `defaults.h` (11,178 names), against every
identifier `cp/` spells outside its own `#define`/`#undef` lines. `cp/`
intersects that vocabulary in **66 names**, 39 of them with more than one
definer.

Ranked by definer count, the top of the real list is:

```
BYTES_BIG_ENDIAN                50 definers   3 cp/ uses
STRICT_ALIGNMENT                50            2
WORDS_BIG_ENDIAN                50            1
PCC_BITFIELD_TYPE_MATTERS       32            2
POINTER_SIZE                    28            2
MAX_FIXED_MODE_SIZE             24            2
REGISTER_TARGET_PRAGMAS         21            1
BITS_PER_WORD                   11            1
MALLOC_ABI_ALIGNMENT             8            2
TARGET_PTRMEMFUNC_VBIT_LOCATION  7            5
```

**Four names outrank `POINTER_SIZE` and none of them is in the brief's
list.** The brief named `POINTER_SIZE` (2 uses, 27 definers),
`MAX_FIXED_MODE_SIZE` (2, 23) and `MALLOC_ABI_ALIGNMENT` (2, 7) as the
remainder of the ranking; the first two definer counts are one short of the
measured 28 and 24 (`defaults.h` is a definer and the earlier grep did not
count it), and the three sit at ranks 5, 6 and 9 rather than at the top.

## 2. And then the ranking's own top turned out to be already done

This is the part worth carrying, because it inverts the obvious reading.
Cross-referencing the 39 against the 103 names `multi-target-macros.h`
redirects: **13 of the 39 are already converted, and they are exactly the
high-definer-count ones.** `BYTES_BIG_ENDIAN`, `WORDS_BIG_ENDIAN`,
`STRICT_ALIGNMENT`, `POINTER_SIZE`, `MAX_FIXED_MODE_SIZE`,
`MALLOC_ABI_ALIGNMENT`, `BITS_PER_WORD`, `TARGET_PTRMEMFUNC_VBIT_LOCATION`
and the two `TARGET_VTABLE_*` are all `targetm_cdata` or `mt_*()` today.

So a definer-count ranking is a ranking of *where the work was*, not of
*where the work is*. Stated as a rule: **a surface census must be
cross-referenced against the conversion layer before it is read as a queue**,
or the first thing an agent does is re-do the last agent's task. That is the
`mta7-targhook-matrix.sh` failure in a new place — an instrument that cannot
show its own project's fixes landing cannot be used to grind a population —
and this one now can, because the two sets are computed independently and
subtracted.

## 3. What is actually left in `cp/`, measured

The 26 unconverted names, minus seven that are noise (`A`, `BASE`, `C`,
`ENTRY`, `FUNCTION`, `OP`, `STR` — macro *parameters* in `rl78.cc`, `gcn.cc`
and the SVE/MVE builtins headers, which is why the vocabulary is now built
from headers only), leaves 19. Their populations over the 47 bases, from
each base's own `tm-<base>.h`:

```
macro                            VALUE-DIFF   disagreeing bases
HAVE_COMDAT_GROUP                    4/47     microblaze mmix nvptx pdp11  (0)
TARGET_HAS_FMV_TARGET_ATTRIBUTE      2/47     aarch64 riscv               (0)
MULTIPLE_SYMBOL_SPACES               1/47     mcore                       (1)
SUPPORTS_INIT_PRIORITY               1/47     avr                         (0)
SUPPORTS_ONE_ONLY                    1/47     pdp11                       (0)
PCC_BITFIELD_TYPE_MATTERS         0/47+7?     no resolvable divergence
CPLUSPLUS_CPP_SPEC                0/23+14?    a spec string, not data
NUM_POLY_INT_COEFFS                  0/47     2 everywhere (the union's)
TARGET_PECOFF                        0/47
TARGET_WEAK_NOT_IN_ARCHIVE_TOC       0/47
NO_DOLLAR_IN_LABEL  NO_DOT_IN_LABEL  PCC_STATIC_STRUCT_RETURN   NOWHERE
LIBSTDCXX  MATH_LIBRARY  TARGET_USE_LOCAL_THUNK_ALIAS_P   SHARED defines none
ASM_FORMAT_PRIVATE_NAME  DATA_ABI_ALIGNMENT  REGISTER_TARGET_PRAGMAS  see below
```

**The answer to "what else is in `cp/`" is: five macros, with populations 4,
2, 1, 1, 1.** The ptrmemfunc and vtable macros really were the ranked top of
that surface, and below them the surface falls off a cliff. Two are worth
naming because their consumers are not cosmetic:

* **`HAVE_COMDAT_GROUP`, 4 back ends.** `cp/decl2.cc` uses it to decide
  whether a vtable is emitted as a COMDAT group. The primary says 1;
  microblaze, mmix, nvptx and pdp11 say 0, and get COMDAT groups their
  assemblers were told not to expect.
* **`TARGET_HAS_FMV_TARGET_ATTRIBUTE`, 2 back ends.** 7 uses in `cp/`, and
  the leak runs the *other* way for once: the primary says 1 and aarch64 and
  riscv say 0, so function multiversioning is enabled for two back ends that
  declare they do not have that attribute form.

Neither is an ABI break of the ptrmemfunc kind and both are real, so they are
recorded as a queue rather than fixed here.

## 4. Three names this instrument cannot score, stated rather than hidden

`ASM_FORMAT_PRIVATE_NAME`, `DATA_ABI_ALIGNMENT` and
`REGISTER_TARGET_PRAGMAS` are **function-like** macros. The census probe
names them bare, so `cpp` leaves them unexpanded and every base reports the
identifier itself — `TEXTS 1`, `VALUE-DIFF 0/47`, which reads as *"no
divergence"* and is really *"not measured"*. `DATA_ABI_ALIGNMENT` in
particular is known from `target-frame.h` to be a live leak (i386 defines it,
so five shared `#ifdef`s are true for every target and `align_variable` calls
`ix86_data_alignment` while compiling for aarch64). **Their zeros in the
table above must not be read as clean.** Scoring a function-like macro needs
representative arguments per macro, which is a different instrument.

## 5. The trap the brief warned about, met and confirmed

*"Counting the back ends that spell a macro undercounts it."* It happened
again, twice, in this task, and the second one was the largest finding here:

* the census resolves `INT_TYPE_SIZE` as diverging on **3** back ends and the
  true population is **6** — `avr`, `h8300` and `pdp11` express it as option
  state (`(TARGET_INT8 ? 8 : 16)`), which no static reading can settle. See
  `scratchpad/A8F6F467D15197CD3-INTWIDTH.md`; `int` is 32 bits on every back
  end today, in both front ends, at rc=0.
* the same column reports `+7?` for `PCC_BITFIELD_TYPE_MATTERS` and `+14?`
  for `SHORT_TYPE_SIZE`, and those residues are exactly where the last
  undercount hid.

The corresponding *over*-count is new and cost one wrong version of the
instrument: `cpp -dM` prints a macro's **body**, and ranking on bodies scored
`CHAR_TYPE_SIZE` as diverging on 4 back ends (`BITS_PER_UNIT` vs `8`) and
`LONG_LONG_TYPE_SIZE` on 9 (`(BITS_PER_WORD * 2)` vs `64`) — the same number
written two ways. `TEXT-DIFF`, `VALUE-DIFF` and `UNRESOLVED` are three
columns for that reason and are never summed.
