# `TARGET_PTRMEMFUNC_VBIT_LOCATION` — the ABI break, closed and measured

Worktree `agent-ad6a5c1d2539f5e18`.  Three cold 47-back-end builds,
`--enable-languages=c,c++`, `-j12`, each from its own immutable `git archive`
snapshot named for worktree id AND sha.  Anchor **52** in all three, unmoved —
nothing here touches `gcc/Makefile.in`.

| build | snapshot | contents |
|---|---|---|
| `/tmp/b-ad6a5c1d2539f5e18-PRE`   | `ad72b905cb4` | branch tip, no fix |
| `/tmp/b-ad6a5c1d2539f5e18-POST`  | `80a76ff45c6` | + the vbit cdata field |
| `/tmp/b-ad6a5c1d2539f5e18-POST2` | `d9214325941` | + the two `TARGET_VTABLE_*` fields |

## 1. All three build, and `cc1plus` links

```
             rc  error:  multdef  undefref  Killed  stderr  warning:  cc1plus bytes
PRE           0       0        0         0       0    4779      1018      236178256
POST          0       0        0         0       0    8486      1576      236178248
POST2         0       0        0         0       0    4779      1018      236182552
```

`POST`'s extra 3707 stderr lines are **one warning of mine**, emitted once per
object that opens the header: `cp/*.o` written inside a `/* ... */` block is a
`-Wcomment`.  Fixed in `POST2`, and **`POST2` matches `PRE` exactly at 4779 /
1018** — which is the check that the conversion adds no warnings, not a claim
that I remembered to look.  Zero warnings are emitted *at* `target-cdata.*` or
`multi-target-macros.h` in any of the three.

`cc1plus` was asserted present and executed before any C++ figure below was
quoted.  A language never enabled and a language passing everything give the
same empty failure list.

## 2. The 47-base census — what each back end's OWN headers ask for

`agent-ad6a5c1d2539f5e18-vbitcensus.sh`, asked of the real preprocessor over
each base's real `tm-<base>.h`, **not** a directory grep — because 41 of the 47
answer through `defaults.h:1023`'s `FUNCTION_BOUNDARY` fallback, and a grep for
who *spells* the macro cannot see that.  Identical at PRE and POST, as it must
be: the fix changes who answers, not what is asked.

```
bases=47   pfn=39   delta=8   unclassified=0   unreadable=0
control ok: both conventions present, so the matcher can tell them apart
```

**THE BRIEF SAYS FIVE BACK ENDS AND IT IS EIGHT, AND IT NAMES ONE THAT WAS
NEVER AFFECTED.**  Both corrections point the same way — the brief counted the
back ends that SPELL the macro and stopped.

```
delta, spelled outright   aarch64  arm  mips
delta, via defaults.h     avr  mn10300  pru  rl78   (FUNCTION_BOUNDARY 8)
                          rx                        (FUNCTION_BOUNDARY 4 or 8)
pfn,   spelled outright   i386  arc
pfn,   via defaults.h     the other 37
```

* **`arc` is `ptrmemfunc_vbit_in_pfn`, not "conditional".**  `arc.h:1541` is
  the enumerator in parentheses over a line continuation.  It agrees with i386
  and was never broken.
* **`loongarch` is not in the 47-base set at all** — it was dropped from the
  build — so it is a source-level definer with no measurement behind it.
* **i386's own `FUNCTION_BOUNDARY` is 8**, so `i386.h:832` is overriding what
  the default would have given *it*.  The primary is the one back end whose
  explicit answer contradicts its own fallback, and that is precisely why the
  leak was invisible: shared code got a value no fallback would have produced.

**Eight back ends have an option-dependent `FUNCTION_BOUNDARY`** (csky, mcore,
nds32, riscv, rx, sh, v850, and arm's `FUNCTION_BOUNDARY_P`), and the census
decides them rather than skipping them: the macro's VALUE varies, but every
arm lands on the same side of `2 * BITS_PER_UNIT`, so **the vbit answer is
invariant even where the boundary is not** — which is the precondition
`target-cdata.h` requires of a field, established rather than assumed.

A note on that arm, because it is a substring trap: scraping digits with
`tr -cs 0-9` pulls `100`/`200` out of rx's `RX100`/`RX200` and drags its real
arms (4 and 8, both `delta`) across the 16 boundary.  The literals are
word-anchored.

## 3. Both-sided over 45 targets with REAL cross assemblers

`agent-ad6a5c1d2539f5e18-vbitsweep.sh`.  45 of 47 targets have a verified
cross `as` (gathered per `INSTRUMENTS.md`; amdgcn and nvptx have none and are
**skipped by name, never defaulted to the host `as`**).  `target-specs` ran per
target in every build dir: **OK=45, SPECS-FAIL=0, every `specs-config`
232 lines / 224 non-blank.**

### PRE → POST, the vbit

```
targets scored: 45   changed=7   byte-identical=36   differ(cc1plus failed)=2
unreadable=0   control moved=0   census disagrees with emitted=0
```

* **changed = 7**: `aarch64 arm avr mips64 mn10300 rl78 rx` — every one of the
  eight `delta` bases except `pru`, and **each emits the convention its own
  header asks for**, checked against the census rather than against "it moved".
* **byte-identical = 36**: every `pfn` base that compiles, x86_64 included.
* **cc1plus failed = 2**, identically at PRE and POST, both PRE-EXISTING and
  unrelated: `mmix` — *"back end 'mmix' has no assembler-directive table"*;
  `pru` — ICE in `pru_hard_regno_mode_ok`, `pru.cc:547`.
  **`pru` is the eighth `delta` base, so its answer is verified in the census
  and NOT at the compiler**, and that is stated rather than folded into the 7.
* **the non-virtual control is identical PRE and POST on all 45.**  Its vbit is
  clear under either convention, so a move there would mean the comparison was
  measuring something else — the script declares the run VOID, not green, if it
  does.

The shape, verbatim: `x86_64 .quad 1 / .quad 0` unchanged; `aarch64 .xword 1 /
.xword 0` → `.xword 0 / .xword 1`; `_ZN1D1hEv / 0` identical on both.

### POST → POST2, the vtable pair

```
targets scored: 45   changed=1   byte-identical=42   differ(cc1plus failed)=2
unreadable=0   control moved=0   census disagrees with emitted=0
```

**Exactly one target changed, and it is `ia64` — the only back end that defines
either macro.**  The observable:

```
ia64  mt_pmf_second   data8 9   ->   data8 17
```

The second virtual function moves from vtable index 1 to index 2, which is what
`TARGET_VTABLE_USES_DESCRIPTORS = 2` means: `9 = 1*8+1`, `17 = 2*8+1`.  Every
other back end is byte-identical and the vbit column does not move — so the
vtable change is isolated from the vbit change by construction rather than by
argument.

## 4. Bars

```
cc1 -quiet -nostdinc -O2 -ftarget-config=<cfg> big.c -o x.s
  x86_64   12369 bytes  md5 378fc33c1e70     PRE, POST and POST2
specs-config  232 lines / 224 non-blank      all 45 targets, all three builds
```

The `specs-config` **md5 is not quoted as a bar** — it is a function of the
probing toolchain's paths.  Standing guards, on POST2: `mt-specsread.sh`
PASSES (both targets, all four arms incl. the negative control),
`mt-rename-sweep.sh` PASSES (0 base-vs-base, 0 base-vs-shared),
`mt-cite-check.sh` PASSES (23 citations).

## 5. What the fix is, and what it is not

A `NUM` entry in `TARGET_CDATA_FIELDS`, evaluated once per base in
`target-cdata.cc` against that base's own `tm.h`.  The 41 back ends that spell
nothing get `defaults.h`'s `FUNCTION_BOUNDARY`-derived answer computed against
*their* `FUNCTION_BOUNDARY` — the answer a single-target build of each would
have given, i.e. **a real per-base answer, not a floor**.

`target-cdata-select.cc`'s post-refresh poison check is unconditional and names
the field, so **45 successful compilations are positive evidence that all three
new fields are written by each selected base's own refresh function** — not
merely that they exist.

The corrected claim: `target-cdata.h`'s `FUNCTION_BOUNDARY` comment asserted
that leak reached the ptrmemfunc ABI *via `defaults.h:1024`*.  The reasoning
about the fallback is right and **the fallback is never taken** — `i386.h:832`
defines the name first — so converting `FUNCTION_BOUNDARY` did nothing here.
The sentence read as though the question had been asked.

## 6. The vtable neighbourhood: two share the fix, one does not

* `TARGET_VTABLE_USES_DESCRIPTORS` — **shares it.**  Leaked ABSENCE: i386
  defines nothing, so `defaults.h:1884` fires and hands everyone 0.  Right for
  46, wrong for ia64, and 0 vs 2 is vtable layout, i.e. ABI.  Landed, measured
  above.
* `TARGET_VTABLE_DATA_ENTRY_DISTANCE` — **shares it**, and is **correct by
  luck** on this configuration: `ilp32.opt` reaches only hpux, so `ia64-elf`
  takes `ia64.h:85`'s `TARGET_ILP32 0` and wants 1, which is what the leak
  already gave it.  Converted anyway — correct-by-luck is what
  `ARG_POINTER_CFA_OFFSET` was.
* `TARGET_VTABLE_ENTRY_ALIGN` — **does NOT share it, and converting it would be
  a regression.**  `defaults.h:972` defines it as `POINTER_SIZE`, which this
  branch deliberately keeps a per-base CALL; a macro body is expanded at the
  use site, and `target-frame.h` already lists this macro among the eleven its
  redirect converts for free.  A cdata slot would FREEZE a currently-correct
  dynamic answer for 44 back ends in order to fix 3.

  The residual 3 are real and unfixed: `ia64.h:236` (64), `avr.h:139` (8),
  `msp430.h:205` (16) define it and `defaults.h:971`'s `#ifndef` is answered by
  the primary, so their values never reach shared code.  **msp430's own comment
  states the symptom before the fact** — *"defaults to POINTER_SIZE, which is
  20 for TARGET_LARGE"* — and 20 is not an alignment.  Home:
  `target_frame_desc`, beside `POINTER_SIZE`.  Recorded there, not done here.

## 7. Instruments repaired, and what they cost

**`tab-probe.sh` was dead and had been for some time** — four independent
stalenesses, each hidden behind the one before it, so each was invisible until
the previous was fixed.  See the commits for detail; the shape is one species:
*a value this project moves, written down as a literal beside the thing that
moves it.*

1. `redirected()` / `reg_redirected()` grepped `defaults.h`, which carries
   **zero** of the redirects — all 25 cdata and all 3 register redirects live
   in `multi-target-macros.h`.  Both answered NO for every macro and the script
   died at its own control **before probing anything.**
2. `-ftarget-config=` named the pre-#163 specs path; cc1 selected no target.
3. `SLOTS_PER_BASE=37` — already two behind before this task.  Replaced with an
   identity over the bases rather than bumped to 42, and the identity catches
   strictly more: an arm dropped for ONE base is invisible to a total.
4. The discrimination control was anchored on `DWARF_FRAME_RETURN_COLUMN`,
   which this project moved out of cdata — **a control anchored on a macro this
   project is converting is a control with an expiry date**, for the second
   recorded time.  Re-anchored to `FUNCTION_BOUNDARY` (8 vs 32, not 0/1-valued).

**It still does not produce a scoreboard, and no figure should be quoted from
it.**  It now passes every control and stops by name at `/tmp/b-stock/gcc/cc1`,
which does not exist here — refusing rather than scoring against its own guess.

**`vbitsweep.sh`'s own reader was wrong four ways**, and every one presented as
an ALARM rather than a wrong green, which is the only reason they were
investigated.  Directive names are not a closed set and do not always start
with a dot (`data8`); one field is not one line (sparc64 emits eight `.byte`s
per field); **the two fields are not the same size** (avr and xstormy16 are
2 + 4, so "split the operands in half" fails exactly where it is load-bearing);
and **an apostrophe in a comment inside a single-quoted `awk` program closes
the quote** — `sh -n` still passed, every later shell function silently ceased
to exist, and 43 of 45 targets came back `pfn_width: command not found`.

## 8. What was NOT measured

* **No testsuite run.**  No `g++` board was taken, so nothing here is a debt or
  regression figure against the corpus.
* **`pru`'s vbit is unverified at the compiler** — census only — because
  `cc1plus` ICEs on it in `pru_hard_regno_mode_ok` at PRE and POST alike.
* **`mmix` compiles no C++ at all** here (no assembler-directive table), so it
  contributes nothing to either sweep.
* **`amdgcn` and `nvptx`** have no cross assembler, so they have no
  `specs-config` and appear only in the 47-base census, never in the 45-target
  sweep.
* **`loongarch`** is not configured in this base set; its `delta` is read from
  source only.
* `TARGET_VTABLE_ENTRY_ALIGN` is diagnosed, not fixed.
* No language other than C and C++ was built.
