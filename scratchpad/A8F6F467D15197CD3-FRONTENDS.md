# The front-end census — which languages have ZERO multi-target coverage

Worktree `agent-a8f6f467d15197cd3`, snapshot `e1f0cad1c2c`, anchor **52**.
Instrument: `scratchpad/agent-a8f6f467d15197cd3-fecensus.sh`.

**This census is the deliverable even though it converts nothing.** C++ had
never been built on this branch until three agents ago, and the first look
found an ABI-incompatible pointer-to-member-function on eight back ends at
rc=0. The question this answers is what else is in that state.

## 1. The table

`TM-CHANNEL` counts files in the directory that reach `tm.h` — spelled
directly, or through `MT_HEADER`/`BASE_HEADER`, which a grep for the quoted
string cannot see. `SURFACE` is how many names from the 11,178-name
target-macro vocabulary (every `#define` in a header under `config/`, plus
`defaults.h`) the directory spells.

```
DIR         files TM-CHANNEL    surface ENABLED-EVER
c              16 0 file(s)          21 yes
c-family       37 1 file(s)         111 n/a  (always built)
cp             57 1 file(s)          66 yes  (since three agents ago)
objc           15 0 file(s)          12 NO
objcp           4 0 file(s)           1 NO
lto            15 2 file(s)          13 yes
d              79 2 file(s)          33 NO
fortran        67 2 file(s)          38 NO
rust          452 2 file(s)          24 NO
go             53 1 file(s)          27 NO
ada            71 4 file(s)          70 NO
m2            339 2 file(s)          22 NO
jit            33 1 file(s)          21 NO
analyzer      110 0 file(s)          21 n/a  (always built)
```

**Nine front ends have never been built multi-target on this branch: `objc`,
`objcp`, `d`, `fortran`, `rust`, `go`, `ada`, `m2`, `jit`.** Only `c`, `c++`
and `lto` have ever been configured.

## 2. How ENABLED-EVER was measured, and what it is NOT

Two independent arms, because the obvious one is a lower bound.

**Arm 1 — the build dirs' own testimony.** 94 `/tmp/b-*/config.log` are
readable on this host; each records the `--enable-languages` its `configure`
actually ran with. Union over all 94: **`c`, `c++`, `lto`, and nothing
else.** That instrument is independent of any script by construction, which
is the argument `PRINCIPLES` makes for `built-tree-audit.sh`. Its limit is
that a deleted build dir testifies to nothing, so **absence here is a lower
bound on coverage, not a proof of zero.**

**Arm 2 — the committed harness**, which survives the build dirs:

```
102  --enable-languages=c,lto        <- mt-conf.sh's default, through which
  6  --enable-languages=c               every board on this branch is
  5  --enable-languages=                 configured
  3  --enable-languages=c,c++
  2  --enable-languages=c,lto,
  1  --enable-languages=objc
  1  --enable-languages=d
  1  --enable-languages=c,c++,lto
  1  --enable-languages=c++
  1  --enable-languages=ada
  1  --enable-languages=${MT_LANGUAGES:-c,lto}
```

The single `objc`, `d` and `ada` spellings are worth reading rather than
counting: they are the only evidence that anyone ever *tried*, and no build
dir on this host corresponds to any of them. **The two arms agree**, which
is the point of running both — one says "no surviving build did it", the
other says "the harness that configures every board asks for `c,lto`".

`c-family` and `analyzer` are marked `n/a`: they are not `--enable-languages`
values, they are always compiled in. Note that `c-family` has the **largest
target-macro surface in the tree at 111 names** and is built in every
configuration, so it is the opposite case — maximum exposure, always on.

## 3. Why zero coverage is not the same as zero defects

**`d/` is the one that is provably already broken, and it takes the residual
this task fixed.** `d/decl.cc:2245` is

```c
  SET_DECL_ALIGN (vtblsym->csym, TARGET_VTABLE_ENTRY_ALIGN);
```

— the *same* macro as `cp/class.cc:840`, the one that was reaching ia64, avr
and msp430 as the primary's `POINTER_SIZE`. So the D front end carries a
vtable-alignment defect identical to the C++ one, and has carried it for as
long as the C++ one existed, with nobody able to see it because `d` has never
been configured. (Fixed by the same change; see
`scratchpad/A8F6F467D15197CD3-VTALIGN.md`.)

**And `d/` and `ada/` are the only readers of a second unconverted macro.**
`WCHAR_TYPE_SIZE` has a **VALUE-DIFF of 8 over the 47 bases** — avr, h8300,
m32r, msp430, pdp11, visium and xtensa want 16, rl78 wants 8, the primary
says 32 — and it is not redirected. Its only consumers in the whole tree are

```
d/d-target.cc:167     this->c.wchar_tsize = (WCHAR_TYPE_SIZE / BITS_PER_UNIT);
d/types.cc:1091       build_frontend_type (make_unsigned_type (WCHAR_TYPE_SIZE));
ada/gcc-interface/targtyps.cc:67   return MAX (SHORT_TYPE_SIZE, WCHAR_TYPE_SIZE);
```

so the leak is **latent**: it is real, it is measured, and it fires on the day
somebody enables `d` or `ada`. That is the exact shape the C++ ptrmemfunc
defect had the day before C++ was enabled.

## 4. What this census does NOT say

* **It does not say the other nine would build.** Nothing here compiled
  `gdc`, `gnat1`, `f951`, `cc1obj`, `crab1`, `go1`, `gm2` or `jit`. The
  surface column is a source-level intersection and is an **upper bound on
  what is asked** and says nothing about what is reached at run time.
* **It cannot see a macro reached through another macro** (the `mode_ibit`
  shape) nor one reached through a header the front end includes rather than
  spells. All its blind spots are in the over-broad direction, so it can add
  suspects and never clear one.
* **`ada/` has four `tm.h` includers and one of them is a `.c` file**
  (`ada/targext.c`), i.e. a C translation unit reaching the conversion layer
  — which `multi-target-macros.h`'s `!defined (__cplusplus)` arm deliberately
  exempts, for `libgcc`'s sake. Whether that exemption is right for `ada` is
  not settled here and is flagged rather than assumed: it is the one place the
  census found where an existing guard's justification (a runtime library is
  single-host by ruling) does not obviously transfer.
* **`jit` reads `MULTILIB_DEFAULTS` and `OPTION_DEFAULT_SPECS`**, which are
  spec strings rather than data — a different conversion channel from either
  `target_cdata` or `target_frame_desc`, and one nothing on this branch has
  looked at.

## 5. The recommendation, stated as a measurement rather than a plan

The cheapest next measurement is **`--enable-languages=c,c++,d`**, because
`d` is the only front end with a *known, already-measured* defect
(`WCHAR_TYPE_SIZE`, 8 back ends) and a *known observable* for it — and because
building it settles the "would it even build" question that the surface column
cannot. `fortran` and `ada` are the largest surfaces after `c-family` and are
the obvious second and third.

**Do not read a clean board from any of them as coverage until the front end
binary is asserted to have executed.** A language never enabled and a language
passing everything give the same empty failure list; that sentence is why this
census exists.
