# BACKLOG GROOMING 2 — 27 items re-adjudicated, and the branch they were groomed against is not the branch the work is on

Worktree `agent-a5fccbef8294a16ae`. Tree verified before any measurement:

```
git rev-parse HEAD            ab782a70607b37383bd176f035806712dd8e2246
git rev-parse multi-target-0  ab782a70607b37383bd176f035806712dd8e2246   EQUAL
grep -c MULTI_TARGET gcc/Makefile.in                52
ls scratchpad/A7D26223EEFCFA725-BOARD.md            present, Aug 16 12:44
```

**The worktree arrived at the bare-repo HEAD `7208eca60d0`, anchor 0, no
`scratchpad/` — the fifteenth occurrence.** It was also DIVERGENT, not merely
behind, exactly as the brief warned. Fixed non-destructively with
`git checkout -b groom2-a5fccbef8294a16ae multi-target-0`; the harness
`gitStatus` preamble named branch `multi-target` while `cwd` was the wrong
tree, which is the metadata-points-away defect the brief predicted.

Nothing here changes code. Every verdict carries a re-runnable command, and
every "it is gone" verdict carries a positive control.

---

## 0. THE HEADLINE, AND IT CHANGES HOW THE WHOLE LIST READS

### THE BRIEF'S PREMISES FOR `#213`, `#153` AND ALL OF GROUP B REST ON COMMITS THAT ARE NOT ON `multi-target-0`

The brief says an agent "just converted `ASM_OUTPUT_FUNCTION_PREFIX`", that the
census "is now known wrong four ways", and that `specs-config`'s md5 "is now
known to be a function of the probing toolchain's paths". All three are true
findings. **None of them is on the branch I was told to groom.**

```
$ git log --oneline HEAD | grep -E '^(87c69584b40|4530fd2d61c|8f2d31d8aa8|ba7db7d186b|0697120610d)'
ba7db7d186b the census said 408 and the answer is 296: one name, several authorities
```

One of five. The other four resolve as commits but are not ancestors:

```
$ git branch -a --contains 87c69584b40
+ agent-a4568de8f522450d3-mt
```

`git log --oneline multi-target-0..agent-a4568de8f522450d3-mt` → **16 commits**,
9 behind. They carry the census corrections, `ASM_DECLARE_FUNCTION_SIZE`,
`ASM_OUTPUT_FUNCTION_PREFIX`, `ADJUST_INSN_LENGTH`, and the harness fix for the
"22/22 bases ok while compiling nothing" instrument the brief cites.

**Two more agent branches are unmerged and carry backlog-relevant work:**

| branch | commits ahead | what it holds |
|---|---|---|
| `agent-a4568de8f522450d3-mt` | 16 | census corrections; `#213`'s fix; `ADJUST_INSN_LENGTH`; `ADDR_VEC_ALIGN` |
| `worktree-agent-abe9f294136236fc8` | 7 | **`#153`'s md5 finding**; `defaults.h` 214-fallback sweep (75 dead) |
| `worktree-agent-a95a42fd940ce4d8e` | 7 | `STACK_SAVEAREA_MODE` / `extract_insn`; `INT_TYPE_SIZE` residual |

`git rev-parse multi-target` == `multi-target-0`, so the main line has not
absorbed any of them.

This is precisely the motivating incident `TASK-TRIAGE.md` §2 reported as **not
reproducing** ("There is no parallel-branch backlog hiding behind the
documentation right now"). That was true when measured and is false now. The
finding is not that the earlier agent was wrong — it is that **this condition
recurs and the ancestry sweep must be re-run per grooming pass, not inherited.**

**Consequence for every verdict below:** where I say a thing is unconverted, I
mean *at `multi-target-0`*. Three items are "fix written, not merged", which is
a merge decision, not work.

### THE BROKEN CENSUS IS THE ONE IN THE TREE BEING GROOMED

Demonstrated live, at `multi-target-0`, with a positive control:

```
$ grep -n 'A-Z_' scratchpad/agent-a018835bbcfad2e28-leakcensus.sh
42: sed -n 's/^@defmac \([A-Z_][A-Z_0-9]*\).*/\1/p;...'      <- the truncation
$ grep -n 'NOTE:' scratchpad/agent-a018835bbcfad2e28-leakcensus.sh
58:  echo "NOTE: no TMH= given; primary chain taken as the i386 linux64 chain"

$ cd gcc && sed -n 's/^@defmac \([A-Z_][A-Z_0-9]*\).*/\1/p;s/^@defmacx \([A-Z_][A-Z_0-9]*\).*/\1/p' doc/tm.texi | sort -u | wc -l
543
$ ... | grep -xE 'P|INVOKE__|__'          ->  __  INVOKE__  P      (garbage present)
$ ... | grep -c '^Pmode$'                 ->  0                    (Pmode absent)
$ ... | grep -c '^FIRST_PSEUDO_REGISTER$' ->  1   POSITIVE CONTROL (a normal name IS found)
```

So the instrument that sizes Group B, **as it stands on `multi-target-0`**,
still holds three garbage names, still cannot see `Pmode`, and still silently
substitutes a 9-header chain for the real 16-header one.

### AND THE `#153` MD5 HAZARD IS LIVE IN `PRINCIPLES.md` AT THIS COMMIT

`scratchpad/PRINCIPLES.md:974` still presents `specs-config md5 cfbc7a65e54e`
as a **bar**. `47ac0ef42a2` (unmerged) shows the md5 is environment-sensitive —
one line of 232, `native_system_header_dir`, an absolute store path, on exactly
the four glibc targets; the four bare-metal targets are byte-identical across
environments and are the control. **Any agent following `PRINCIPLES.md` at this
commit will score a correct build as a failed bar.**

---

## GROUP A

### `#172` riscv end-to-end — **STILL LIVE; the description's figures are STALE IN BOTH DIRECTIONS**

The brief's "2,218 → 772" conflates two baselines.

```
scratchpad/AB1900D5279BA137F-BOARD.md:112   riscv64 PASS 267437 FAIL 18542   debt 2,218
scratchpad/A018835BBCFAD2E28-BOARD.md:334   board (e3fac057ae4)  267630 18329  debt 2,074
scratchpad/A018835BBCFAD2E28-BOARD.md:338   +PROMOTE d5ad77b33b3 268932 16762  debt   772
```

The **measured span on one harness is 2,074 → 772**, with `3b9f7c8f695`
reproducing `267630 / 18329` EXACTLY as the control. 2,218 is an older board's
reading of a different tree and must not be used as the start of that span.

**What is left of the item is all of it: there is still zero execution.** Both
boards are `MT_COMPILE_ONLY=1`, all-gcc only, no target libgcc. And the newest
board's riscv row is **not a debt figure at all**:

```
scratchpad/A7D26223EEFCFA725-BOARD.md:50  riscv riscv64-unknown-linux-gnu 41714 560 14
:43  "Raw PASS/FAIL. These are NOT debt figures -- no stock control was run"
```

The blocker is unchanged and is `#37`:

```
$ grep -c '^target_modules' Makefile.def                    -> 26
$ grep -n 'MT_TARGET_SUBDIRS' Makefile.in | grep -vi specs
  -> only the declaration (:310), the empty-guard (:320,:321), prose, and
     the specs rules.  NO other module uses the per-target machinery.
```

**Next agent's first move:** build a riscv64 target libgcc — it is the same
one-line-of-`Makefile.def` gap as `#37`, and every execution claim on every
board is behind it.

### `#213` s390x `.machine`/`.machinemode` — **FIX WRITTEN, NOT MERGED. Still LIVE at `multi-target-0`.**

```
$ git grep -n 'ASM_OUTPUT_FUNCTION_PREFIX' -- gcc/ | grep -v ChangeLog
gcc/config/s390/s390.h:909   #undef ASM_OUTPUT_FUNCTION_PREFIX
gcc/config/s390/s390.h:910   #define ASM_OUTPUT_FUNCTION_PREFIX s390_asm_output_function_prefix
gcc/varasm.cc:2192           #ifdef ASM_OUTPUT_FUNCTION_PREFIX      <- STILL A RAW #ifdef
gcc/varasm.cc:2193             ASM_OUTPUT_FUNCTION_PREFIX (asm_out_file, fnname);
```

POSITIVE CONTROL — the converted shape exists in this tree, so a "not
converted" reading is not the pattern failing. `ASM_DECLARE_FUNCTION_NAME` was
converted by moving the `#ifdef` into the per-base TU:

```
gcc/target-cumargs.cc:270    #ifdef ASM_DECLARE_FUNCTION_NAME     (per-base TU)
gcc/target-frame.h:1594      the descriptor slot
```

The identical conversion for `ASM_OUTPUT_FUNCTION_PREFIX` exists at
`agent-a4568de8f522450d3-mt` (`0697120610d`, +86/-4 over
`target-cumargs.cc`, `target-cumargs-select.cc`, `target-frame.h`,
`varasm.cc`). **So: the work is done, the merge is not.**

Note the conversion's own claim is UNVERIFIED BY SUITE — `A4568DE8F522450D3-BOARD.md`
§4: *"NO SUITE RUN OF ANY KIND IS REPORTED HERE."*

**The `hashtab_chk_error` half is genuinely separate and OPEN, unchanged at 60.**

```
scratchpad/AA9D4BBA0B6E950B3-S390X.md:32   reload  hashtab_chk_error  60 ICEs  OPEN
scratchpad/AA9D4BBA0B6E950B3-S390X.md:478  hashtab_chk_error  60 -> 61
$ ls scratchpad/agent-aa9d4bba0b6e950b3-hashtab.sh    -> present (reproducer + both-sided arm)
```

Its own handover says run the both-sided arm FIRST: if it fires on every
target it is upstream, not a leak.

### `#182` 43 sites / 5 causes — **ALREADY DONE. All five causes are closed, and the brief's "B and E open by design" is a CAUSE-TABLE COLLISION.**

`#182`'s actual table is `STATE.md:14436`:

| cause | recorded state | state now |
|---|---|---|
| A origin diverges | FIXED | FIXED |
| **B union ordinal in a 64-bit mask** | **OPEN — design** | **FIXED, see below** |
| C origin + bound union-derived | CHECKED CLEAN | clean |
| D ordinal range visiting holes | FIXED | FIXED |
| E same shape, non-firing | measured non-firing | **sites gone from the tree** |

**Cause B is `#185`, and `#185` has landed.**

```
$ grep -n 'AARCH64_APPROX_MODE' gcc/config/aarch64/aarch64-protos.h
534: #define AARCH64_APPROX_MODE(MODE) aarch64_approx_mode_bit (MODE)
```

`aarch64-protos.h:517-532` replaces the `1 << (MODE - MIN_MODE_FLOAT)` shift —
which reached 219 on a `uint64_t` and was undefined behaviour masked only by
every in-tree value being `0` or `~0` — with `GET_MODE_CLASS_INDEX`, aarch64's
own dense position, plus `gcc_checking_assert (bit < 64)` so growth past 64 FP
modes is loud instead of undefined. **This was the prior groom's #1
re-prioritise item; it is done.**

Cause E's sites are gone: `git grep -n 'MIN_MODE_' -- gcc/fixed-value.h` → 0
(the table named `fixed-value.h:40,41`).

**The population figure is also wrong in the description, and the error is
prose-vs-code:**

```
$ git grep -n 'MIN_MODE_' -- 'gcc/*.cc' 'gcc/*.h' 'gcc/config/**/*.cc' 'gcc/config/**/*.h' \
    | grep -v genmodes.cc | wc -l                       -> 44   raw
$ ... | grep -cE ':\s*(\*|/\*|//)'                      ->  5   PROSE
$ ... | grep -vE ':\s*(\*|/\*|//)' | wc -l              -> 39   CODE
POSITIVE CONTROL, same shape: MAX_MODE_                 -> 40   raw
```

So "43" and the prior groom's "45" both counted comment lines. **39 code
sites**, and `aarch64-protos.h` fell from 5 to 2 (both now prose) as cause B
was fixed. Recommend **close `#182` and `#185`**; if anything survives it is a
one-line reclassification of the `machmode.h` and `stor-layout.cc` sites, not a
five-cause investigation.

### `#167` `final_prescan_insn` — **REFUTED. It is not "safe because i386 is primary"; it is BROKEN, and being i386-primary is exactly why.**

The description says the site is safe because the primary decides. Measured:

```
$ grep -n 'FINAL_PRESCAN_INSN' gcc/final.cc
2666: #ifdef FINAL_PRESCAN_INSN      2667: FINAL_PRESCAN_INSN (insn, ops, insn_noperands);
2801: #ifdef FINAL_PRESCAN_INSN      2802: FINAL_PRESCAN_INSN (insn, recog_data.operand, ...)

$ git grep -n 'define FINAL_PRESCAN_INSN' -- gcc/config/i386/
   (no output -- i386 DEFINES NOTHING)
POSITIVE CONTROL, identical pattern, different outcome:
$ git grep -c 'define ASM_OUTPUT_MAX_SKIP_ALIGN' -- gcc/config/i386/i386.h   -> 1
```

**i386 does not define `FINAL_PRESCAN_INSN`, so both `#ifdef`s are false for
all 47 bases and the body runs NOWHERE.** This is a leaked ABSENCE — the
identical shape as `ADJUST_INSN_LENGTH`, which `agent-a4568de8f522450d3-mt`
converted for exactly this reason. All 14 definers are affected:

```
aarch64 alpha arc arm avr c6x epiphany frv h8300 iq2000 m68k mips rs6000 sh
```

Severity, from the bodies (`git grep -n -A2 'define FINAL_PRESCAN_INSN'`):
`arm/arm.h:2328` is `arm_final_prescan_insn`, the **conditional-execution
engine** — ARM-mode predication is silently not applied. `mips/mips.h:3469`
and `avr/avr.h:431` are hazard/delay-slot handling. These are wrong-code
classes, not missed optimisation.

**#167 should be re-prioritised sharply upward and re-worded.** Its current
description would have a reader conclude it is latent.

**Next agent's first move:** convert `final.cc:2666,2801` in the
`ADJUST_INSN_LENGTH` shape already landed on `agent-a4568de8f522450d3-mt` —
there is a worked example one commit away.

### `#153` pair-control bars — **the codegen bar HOLDS and reproduces; the `specs-config` MD5 bar is REFUTED (finding unmerged)**

Codegen bar, reproduced independently by two boards since the prior groom:

```
scratchpad/A7D26223EEFCFA725-BOARD.md  x86_64 -O2 big.c 12369 bytes / 378fc33c1e70  == recorded
scratchpad/A4568DE8F522450D3-BOARD.md  same, and all four specs-config at 232 / 224
```

The md5 half is refuted by `47ac0ef42a2` (branch
`worktree-agent-abe9f294136236fc8`, **unmerged**): a fresh cold 47-base build
reproduces `232 lines / 224 non-blank / all md5s distinct` exactly and
reproduces **none of the four recorded md5s**. Cause named: one line of 232,
`native_system_header_dir`, an absolute store path, on exactly the four glibc
targets; **the four bare-metal ELF targets take `target-specs/configure.ac:570`'s
`/usr/include` default and are byte-identical across both runs — that is the
control saying the compiler did not move and only the environment did.**

`scratchpad/PRINCIPLES.md:974` at `multi-target-0` still lists the md5s as
bars. **The bar is the LINE COUNT (232 / 224 non-blank / all distinct), not the
md5.** This correction should be merged ahead of the code on that branch; it is
documentation and it is currently costing days.

### `#100` · `#25` · `#26` · `#21` · `#69` — the `#216` group, re-adjudicated

`DESIGN-216-agent-a591145022e2f4e73.md` supersedes the prior groom's "six are
one mechanism": they are **three landed channels** (C1 per-triple compile,
C2 named spec, C3 `targ_caps`), and two members are not the mechanism at all.
Re-verified at `multi-target-0`, each with a positive control:

| item | verdict | evidence |
|---|---|---|
| **`#26` `TOOL_INCLUDE_DIR` arms** | **ALREADY DONE** | `config/linux.h:177` and `rs6000/sysv4.h:993` now read `{ targ_caps.tool_include_dir, "BINUTILS", 0, 1, 0, 0}`, **unconditional**, with the reasoning at `linux.h:153-175`. The dead `#ifdef` is gone. |
| `#26` `INCLUDE_DEFAULTS` fork | STILL LIVE | C1; the largest of the group. `NATIVE_SYSTEM_HEADER_DIR` is the same defect, still `#ifdef`-gated (`linux.h:179`). |
| `#21` `HAVE_SOLARIS_LD` | STILL LIVE, partly landed | `sol2.cc:307`, `sol2.h:282-330` converted |
| **`#21` `HAVE_SOLARIS_AS`** | **STILL LIVE, zero work** | `grep -c solaris_as target-specs/configure.ac gcc/target-caps.h` → **0, 0**. POSITIVE CONTROL `solaris_ld` → **6, 1**. |
| `#25` darwin rpath | STILL LIVE, trivial | `grep -c 'darwin.extra.rpath\|DARWIN_ADD_RPATH' target-specs/configure.ac` → **0**. POSITIVE CONTROL `grep -ci darwin` → **16**. Population of one; C2; then the last per-target `AC_ARG_WITH` leaves `gcc/configure.ac`. |
| `#69` shared libgcc | STILL LIVE, no design owed | the channel landed (`gcc.cc:1278-1296`, `1929-1955`); 5 header sites are C1, 8 `*spec.cc` sites read a named spec |
| `#100` `vxworks.h:297` | STILL LIVE, trivial, C1 | `git grep -n CONFIG_SJLJ_EXCEPTIONS -- gcc/config/` → 2 sites, both present |
| **`#100` `cygming.h:366`** | **STILL LIVE — and it is NOT this item** | a middle-end macro, not spec text; the per-base channel structurally cannot separate two triples of one back end |

**`cygming.h:366` should be re-filed under `#220`**, whose body
(DESIGN-216 §6) names it as the worked example. `#192` should be split out
likewise — it is an installed FILE, not a `#if`.

**Closable now: the `TOOL_INCLUDE_DIR` sub-item only.** Everything else in the
group stands, re-sized.

---

## GROUP B — AND THE DOUBLE-COUNTING QUESTION, MEASURED

### THE ANSWER: THE EIGHT ITEMS SPLIT THREE WAYS, AND ONLY THREE OF THEM DOUBLE-COUNT THE CENSUS

I tested membership in the census's own authority — `tm.texi`'s `@defmac` list
— which is what decides whether an item is a *named instance already inside the
296/~331* or an *additional population*:

```
$ grep -nE '^@defmac (DWARF2_UNWIND_INFO|TARGET_SUPPORTS_WIDE_INT|FINAL_PRESCAN_INSN|ASM_OUTPUT_FUNCTION_PREFIX|ADJUST_INSN_LENGTH|ADDR_VEC_ALIGN|Pmode|FIRST_PSEUDO_REGISTER)\b' gcc/doc/tm.texi
1993:  @defmac FIRST_PSEUDO_REGISTER
9999:  @defmac FINAL_PRESCAN_INSN            <- #167
10345: @defmac DWARF2_UNWIND_INFO            <- #210
12227: @defmac Pmode
13151: @defmac TARGET_SUPPORTS_WIDE_INT      <- #214
```

Five found, three not — the internal positive/negative control. So:

**(i) INSIDE the census — these are named instances, NOT additional scope.**
`#210` (`DWARF2_UNWIND_INFO`), `#214` (`TARGET_SUPPORTS_WIDE_INT`), and `#167`
are all `@defmac` names and are therefore already counted in the census's
118 LEAK-PRIMARY / 178 DEAD-DEFAULT. **Working them does not shrink the 296 by
296's worth; it shrinks it by three.** Anyone summing "296 census macros + #210
+ #214" is double-counting.

**(ii) OUTSIDE it and additive.** `#213`'s `ASM_OUTPUT_FUNCTION_PREFIX`,
`ADJUST_INSN_LENGTH` and `ADDR_VEC_ALIGN` are absent from `tm.texi` — the
~109-candidate fourth population the census cannot reach by construction.

**(iii) NOT A MACRO POPULATION AT ALL — orthogonal, no double-count possible.**
`#215` counts *call sites*; `#141` counts *headers* (5); `#147` counts *`.opt`
enumerators*; `#160` counts *channels* (5); `#220` is defined by *provenance*
(which header supplied the macro) and cuts across all buckets.

### AND A FINDING NOBODY HAS CONNECTED: `#32` ALREADY COVERS 83 OF THE ~109 UNDOCUMENTED POPULATION

The a4568 board's handover item 6 asks for "a second instrument to own" the
undocumented macros. **It exists, it is committed, and it is `#32`'s.**

```
$ cut -f2 scratchpad/t32-values.tsv | sort -u > /tmp/t32.txt          -> 413 macros
$ ... tm.texi @defmac extraction ...        > /tmp/pop.txt           -> 543 names

$ comm -12 /tmp/t32.txt /tmp/pop.txt | wc -l   -> 330   BOTH  (the double-count)
$ comm -23 /tmp/t32.txt /tmp/pop.txt | wc -l   ->  83   #32 ONLY (census-invisible)
$ comm -13 /tmp/t32.txt /tmp/pop.txt | wc -l   -> 213   census only
```

**330 of `#32`'s 413 are the same macros the census counts.** That is the
largest double-count on the list and it is between two items nobody paired.

And the 83 census-invisible ones are the right 83:

```
$ grep -xE 'ADJUST_INSN_LENGTH|ADDR_VEC_ALIGN|ASM_OUTPUT_EXTERNAL_LIBCALL|ASM_OUTPUT_ADDR_VEC|ASM_OUTPUT_ADDR_DIFF_VEC|ASM_OUTPUT_FUNCTION_PREFIX' /tmp/t32only.txt
ADDR_VEC_ALIGN
ADJUST_INSN_LENGTH
ASM_OUTPUT_ADDR_DIFF_VEC
ASM_OUTPUT_ADDR_VEC
ASM_OUTPUT_EXTERNAL_LIBCALL
```

**All five of the a4568 board's ranked undocumented macros are in `#32`'s 83.**
`ASM_OUTPUT_FUNCTION_PREFIX` is correctly ABSENT — it is defined by one back
end only, so a *value-divergence* census cannot see it either. That absence is
the negative control that says the match is not an artefact of a loose pattern.

**This is the single most actionable thing in this document:** `#32`'s
committed `t32-values.tsv` is 83/109 of the instrument the newest board asked
someone to build.

### Per-item verdicts

**`#210` `DWARF2_UNWIND_INFO` transitive readers — STILL LIVE, and it is a
named member of the census, not extra scope.**

```
$ git grep -n 'DWARF2_UNWIND_INFO' -- gcc/ | grep -v ChangeLog | grep -v doc/ | wc -l   -> 70 sites
$ ... | git grep -ln ... | wc -l                                                        -> 37 files
```

Partly converted already: `target-frame.h:809-858`, `target-cumargs.cc:662-679`,
`target-cumargs-select.cc:422`, with `dwarf2cfi.cc:49` and `dwarf2out.cc:153`
poisoning the macro in shared code. The residue is the `config/<os>.h` half,
which is `#220`. **Recommend merging `#210`'s residue into `#220`.**

**`#214` `TARGET_SUPPORTS_WIDE_INT` union setting — STILL LIVE, and the item is
BIGGER than "a setting". Partly done.**

```
$ git grep -l 'define TARGET_SUPPORTS_WIDE_INT' -- gcc/config/ | wc -l   -> 12 definers (say 1)
$ grep -n 'define TARGET_SUPPORTS_WIDE_INT' gcc/defaults.h              -> :1389 gives 0
$ git grep -nE '^# *if.*TARGET_SUPPORTS_WIDE_INT' -- gcc/ | grep -v config/ | grep -v doc/ | wc -l
  -> 22 compile-time #if sites over 12 shared files
```

12 define it 1 (`aarch64 alpha arm i386 loongarch nvptx pru riscv rs6000 s390
sparc` + `aarch64.cc`); the other 35 take `defaults.h`'s 0. The `Makefile.in:2058-2064`
note calls this *"a structural ceiling on the back-end count"*.

**The half already done:** `emit-rtl.cc:712-729` records that the
`#if TARGET_SUPPORTS_WIDE_INT == 0` around `immed_double_const`'s *definition*
was deliberately removed, fixing the `undefined reference to immed_double_const`
link failure for m68k. That is the first step of the union, already taken.

**The half still live is the hard one:** `rtl.h:814,818,888,2129,2454,3497`
condition the **rtx representation itself** (`CONST_DOUBLE` vs `CONST_WIDE_INT`
layout). Because rtl.h is shared, this cannot be per-base — it must be one
union answer, and choosing 1 means auditing 35 back ends. **Next agent's first
move:** enumerate what the 35 non-definers actually assume, before flipping
anything; the `immed_double_const` precedent shows the per-site shape.

**`#215` 26–37 `gen_rtx_REG` walkers — STILL LIVE; the figures REPRODUCE EXACTLY.**

```
$ sh scratchpad/agent-a97cff7619d3cabd9-regmaker.sh gcc
  -- scanned 546 shared .cc files in gcc        (non-vacuity floor is 100; passed)
  stderr: 0 lines
  sites @ MTW=30   -> 26        (recorded: 26)
  sites @ MTW=120  -> 37        (recorded: 37)
```

Files at the 120 window: `builtins caller-save combine cse dwarf2cfi emit-rtl
expr ira lra-constraints lra-eliminations postreload reload1 reload targhooks
var-tracking` — **15, where the doc names the 10 from the 30-window.**

The item's "lower bound" caveat is real and is the instrument's own: the one
site *measured to fire* (`peep2_find_free_register`) is 81 lines from its loop
head and is not in the 26. **This item cannot be closed by driving the number
to 0** and the acceptance bar should say so.

**`#220` per-`config/<os>.h` macros are the first triple's — STILL LIVE,
UNSIZED, and it is the right home for three other items' residue.**

The mechanism is read from the generator, not from a build, so it is not
build-confounded:

```
$ grep -n -A3 'gcc_all_cpu_bases' gcc/gen-target-manifest.sh
445:  case " ${gcc_all_cpu_bases} " in
446:    *" ${gcc_mt_cpu} "*) ;;                    <- already emitted: take the empty arm
447:    *) gcc_all_cpu_bases="${gcc_all_cpu_bases} ${gcc_mt_cpu}"
```

**First triple wins.** So `tm-<cpu>.h` is one triple's OS layer wearing a back
end's name, and every back-end fact derived from a `config/<os>.h` is that
triple's for all its siblings. DESIGN-216 §6 measured
`diff tm-i386.h tm-x86_64_pc_linux_gnu.h` as byte-identical apart from the
include guard.

**Sizing is CANNOT TELL WITHOUT A BUILD**, and precisely: it needs `cpp -dM` on
two `tm-<cpu>.h` generated from *two triples of one back end* (e.g.
`--enable-targets=x86_64-pc-linux-gnu,i686-pc-cygwin`). **A 47-triple build
cannot answer it** — it configures one triple per back end, so `cpu` and `key`
are in bijection and every discriminating case is absent.

`#100`'s `cygming.h:366` and `#210`'s residue both belong here.

**`#32` compiled-once files — STILL LIVE; the prior groom's correction was NOT applied.**

```
$ wc -l scratchpad/t32-sites.tsv     -> 2845 sites
$ cut -f4 scratchpad/t32-sites.tsv | sort -u | wc -l   -> 224 files
$ wc -l scratchpad/t32-values.tsv    -> 413 macros
$ cut -f4 scratchpad/t32-sites.tsv | grep -c '^target-'  -> 285   still over-counted
```

Identical to the prior groom's reading. The 285 sites in per-base `target-*.cc`
are still in the population; honest figure remains **~2560**. Plus the new
finding above: 330 of the 413 macros are also the census's.

**`#141` four/five headers — restate as FIVE; otherwise unchanged.**

```
$ git grep -ln 'MT_HEADER (tm\.h)' -- gcc   -> 5
  backend.h  cp/cp-tree.h  genmodes.cc  m2/gm2-gcc/gcc-consolidation.h  target.h
$ git grep -c '#include "tm\.h"' -- gcc/ | wc -l   -> 60
```

**`#147` 421 enumerators — the header half REPRODUCES EXACTLY; the enumerator count still needs a build.**

```
$ awk '/^HeaderInclude$/{getline h; print h}' gcc/config/*/*.opt | sort -u | wc -l  -> 35
```

Matching the recorded "35 `I` files". The 421 is not textually derivable and
needs `scratchpad/mtq-enumleak.sh` against a 48-base build directory.

**`#160` five channels — CONFIRMED five, unchanged.** `gcc/mkconfig.sh:193-208`
carries `insn_flags_h`, `insn_modes_h`, and the `options.h`/`insn-constants.h`
rewrite to `<base>` names. The census half is done; only the two
non-per-target channels remain.

---

## GROUP C

**`#37` target libraries beyond libgcc — STILL LIVE; "1 of 26" CONFIRMED unchanged.**
`grep -c '^target_modules' Makefile.def` → 26; the only non-`target-specs` uses
of `MT_TARGET_SUBDIRS` in `Makefile.in` are the declaration, the empty-guard
and prose. **This gates `#172` and `#75`.**

**`#39` upstreaming — STILL LIVE, still a placeholder, and it has grown ONE artefact.**
`ls scratchpad/ | grep -i 'upstream\|patch'` → `UPSTREAM-BUGS.md`,
**`gen-blockage-WIP.patch`** (new since the prior groom). Still no split plan
and no series. The prior groom's recommendation to split it into (i) file the
bugs and (ii) carve a series **stands and has not been acted on.**

**`#75` three host tools — STILL LIVE; "3 EDGES over 2 host modules" confirmed verbatim.**
`gnattools` → `libada`, `libstdc++-v3`; `gotools` → `libgo`. Blocked behind `#37`.

**`#96` per-target data location — STILL LIVE; only the `accel_dir_suffix` design question.**
The suffix is alive at `Makefile.in:74,837,839,3938` and `gcc.cc:1763,5667,8721,9302,9576`
(line numbers drifted from the prior groom's; the population is the same).
Unanswered question unchanged: are accel targets just more configured targets?

**`#140` class (c) — STILL LIVE, but MUCH further along than "~1 of 91". R1 has LANDED.**

```
$ grep -n 'define UNITS_PER_WORD\|define POINTER_SIZE\|define BIGGEST_ALIGNMENT' gcc/multi-target-macros.h
1470: #define UNITS_PER_WORD   (mt_units_per_word ())
1472: #define POINTER_SIZE     (mt_pointer_size ())
1474: #define BIGGEST_ALIGNMENT (mt_biggest_alignment ())
POSITIVE CONTROL: :773  #define Pmode (mt_pmode ())
```

All three of `CLASS-C-COSTING.md`'s R1 recommendations are converted.

```
$ grep -cE '^#define [A-Za-z_][A-Za-z_0-9]* \(mt_[a-z_0-9]+ \(\)\)' gcc/multi-target-macros.h  -> 28
$ comm -12 <class-(c) names from MACRO-LEAK.md §(c)> <the mt_* redirect list> | wc -l          -> 16
```

**At least 16 named class-(c) members converted (17 counting `Pmode`, which the
uppercase extraction misses — the census's own bug, recurring in my
instrument), not 1.** CAVEAT, stated: my class-(c) name list is a token
extraction over `MACRO-LEAK.md`'s prose section and yields 96 tokens against
the section's stated 91, so treat 16 as approximate-but-load-bearing; the four
named ones are exact.

**`#143` `host_detect_local_cpu` — STILL LIVE, unchanged, count confirmed.**

```
$ git grep -n 'host_detect_local_cpu' -- gcc/config/*/driver-*.cc | grep '^\S*:[0-9]*:.*host_detect_local_cpu ('
  -> bare name defined by aarch64 alpha arm i386 mips rs6000 sparc   = 7
$ git grep -n '_host_detect_local_cpu' -- gcc/config/    -> s390 only, prefixed
$ awk '/^MULTI_TARGET_RENAME_NAMES/,/^$/' gcc/Makefile.in | grep -c host_detect_local_cpu  -> 0
POSITIVE CONTROL: the same awk range is 81 lines and returns 1 for make_pass_insert_bti
```

The control matters: the rename-list grep *can* find things, so the 0 is real.
Still a scope decision (`is -march=native in scope?`), not work.

**`#174` `configure.ac:1621` — STILL LIVE but the residue is DOWN and two of three call-outs describe LANDED fixes.**

```
$ grep -n 'config\.gcc' gcc/configure.ac
1611: # Canonicalise ${target} before config.gcc dispatches on it.
1621: . ${srcdir}/config.gcc || exit 1                      <- still there
$ grep -n 'ONE legacy' gcc/gen-target-manifest.sh   -> :184  :210  :257   (3)
```

Reading them: `:184` (`cxx_target_objs`) is now described with its fix — and
`491713a900a` *"`MT_CXX_OBJS_<base>` was empty for 32 of 48 back ends"* is in
HEAD. `:210` (`extra_headers`) likewise names the per-back-end
`include-<cpu>/` directories that `PRINCIPLES.md:1000` shows existing. **`:257`
(`use_gcc_stdint`) is the one genuinely untouched**, and it is `#192`.

**Recommend re-writing `#174` as "`use_gcc_stdint` into the manifest" and
closing the rest** — line 1621 itself is no longer the only pass
(`configure.ac:1624-1665` + `gen-target-manifest.sh:118,128` is a per-target loop).

**`#175` pass-name vocabulary — ALREADY DONE.**

```
$ awk '/^MULTI_TARGET_RENAME_NAMES/,/^$/' gcc/Makefile.in | grep -c 'make_pass_insert_bti'  -> 1
$ ls gcc/gen-target-passes.awk        -> present, 8805 bytes
gcc/gen-target-passes.awk:32-44  documents the aarch64/arm collision and the
                                 make_pass_insert_bti_mt_<base> wrapper it emits
gcc/Makefile.in:2153             make_pass_insert_bti, in the rename list
```

The prior groom's *"Next agent's first move: resolve `make_pass_insert_bti`, it
is the one concrete named instance"* has landed, and a whole generator
(`gen-target-passes.awk`) was written for it. **Recommend close.**

**`#46` `HAVE_LD_PIE` — STILL LIVE; the instrument REPRODUCES EXACTLY, figures unchanged since the prior groom.**

```
$ sh scratchpad/t116-vacuous.sh > /tmp/v.txt 2> /tmp/v.err
  rc=0;  wc -l /tmp/v.err -> 0        (stderr asserted empty)
  head -1 -> "macros defined over targ_caps in defaults.h: 73"
  grep -c '^=== ' -> 14 macros        (item says 13)
  grep -c '^  gcc' -> 28 sites        (item says 22)
```

Scoping unchanged and still governs: only the **five `HAVE_LD_PIE` sites** are
provably vacuous (`mkconfig.sh:135-136` pre-defines it to 1 *ahead of* the
target headers). The other 23 need per-site include-order reasoning and must
not be swept.

---

## RECOMMENDED CLOSE LIST — ranked

| # | item | why |
|---|---|---|
| 1 | **`#185`** `AARCH64_APPROX_MODE` UB | **Done.** `aarch64-protos.h:517-534` is now `aarch64_approx_mode_bit`, using aarch64's own dense `GET_MODE_CLASS_INDEX` with `gcc_checking_assert (bit < 64)`. This was the prior groom's #1 re-prioritise. |
| 2 | **`#182`** 43 sites / 5 causes | **Done.** All five causes closed (B by `#185`; E's `fixed-value.h` sites gone). Population is **39 code sites**, not 43/45 — both earlier figures counted prose. |
| 3 | **`#175`** pass-name vocabulary | **Done.** `make_pass_insert_bti` is in `MULTI_TARGET_RENAME_NAMES` (`Makefile.in:2153`) and `gcc/gen-target-passes.awk` exists to emit the per-base wrappers. |
| 4 | **`#26`'s `TOOL_INCLUDE_DIR` sub-item** | **Done.** Both dead `#ifdef` arms converted to `targ_caps.tool_include_dir`, unconditional (`linux.h:177`, `rs6000/sysv4.h:993`). Keep `#26`'s `INCLUDE_DEFAULTS` fork open. |
| 5 | **`#140`'s R1** | **Done.** `UNITS_PER_WORD`, `POINTER_SIZE`, `BIGGEST_ALIGNMENT` converted. Keep `#140` open, re-sized to ~16-17 of 91. |
| 6 | **`#174`** as written | Re-write as `use_gcc_stdint` only, or fold into `#192`. Two of its three residual call-outs describe fixes now in HEAD; line 1621 is no longer the only pass. |
| 7 | **`#210`** | **Duplicate/subset.** It is one `@defmac` inside the census's 296, and its residue is `#220`'s. Fold into `#220`; do not carry as separate scope. |

**Restate rather than close:** `#141` (four → **five**), `#172` (2,218 →
**2,074** → 772, and zero execution), `#46` (13/22 → **14/28**), `#32`
(~2560 honest sites; **330 of its 413 macros are also the census's**).

## RECOMMENDED RE-PRIORITISE LIST — ranked

1. **MERGE THE THREE AGENT BRANCHES, OR EXPLICITLY DECIDE NOT TO.** 30 commits
   across `agent-a4568de8f522450d3-mt`, `worktree-agent-abe9f294136236fc8` and
   `worktree-agent-a95a42fd940ce4d8e` are stranded, including `#213`'s fix, the
   census corrections, and the `#153` md5 correction. **Merge the `#153`
   `PRINCIPLES.md` correction first** — it is documentation, it is costing days,
   and every hour it is unmerged another agent scores a good build as a failed bar.
2. **`#167` `FINAL_PRESCAN_INSN`, re-worded as a WRONG-CODE item.** i386 defines
   nothing, so it is a leaked ABSENCE on 14 back ends including arm's
   conditional-execution engine. There is a worked conversion
   (`ADJUST_INSN_LENGTH`) one commit away on `agent-a4568de8f522450d3-mt`. The
   current description says the opposite of what is true.
3. **`#32` re-framed as the undocumented-macro instrument.** Its
   `t32-values.tsv` already holds **83 of the ~109** macros the newest board
   asked someone to build a second instrument for, including all five of that
   board's ranked entries. Nothing needs writing; it needs connecting.
4. **`#214`'s `rtl.h` half.** 22 compile-time `#if`s over 12 shared files, six
   of them conditioning the rtx representation itself. 12 back ends say 1 and 35
   take `defaults.h`'s 0. `Makefile.in:2064` calls it a structural ceiling on
   the back-end count; `immed_double_const` is the precedent for the shape.
5. **`#220`, sized.** It is the correct home for `#100`'s `cygming.h:366` and
   `#210`'s residue, and it is unsized. The measurement is specific and cheap
   relative to what it settles: `cpp -dM` on two `tm-<cpu>.h` from a
   **two-triples-of-one-back-end** configure. A 47-triple build cannot answer it.

Behind those: **`#37`/`#172`** (per-target libgcc — gates every execution result
and `#75`), **`#21`'s `HAVE_SOLARIS_AS`** (still zero work, and its consumers are
`.md` insn conditions that become hard errors when sparc is enabled),
**`#215`** (reproduces at 26/37; acceptance bar must not be "drive it to 0"),
**`#143`** (a scope decision, not work), **`#39`** (still two tasks in one number).

## WHAT THIS DOCUMENT DOES NOT CLAIM

- **Nothing here is a build.** Every figure is a grep, a `git merge-base`, a
  file read, or a re-run of a committed text instrument
  (`t116-vacuous.sh`, `agent-a97cff7619d3cabd9-regmaker.sh`), each with stderr
  asserted and each with a non-vacuity floor of its own.
- **I did not re-run any suite**, so no debt figure here is mine. The 772 and
  the 47-back-end board rows are quoted with their provenance and their own
  disclaimers, including that `A7D26223EEFCFA725-BOARD.md`'s rows are raw
  PASS/FAIL with no stock control and are **not** debt.
- **The `#140` "16 of 91" is approximate** by the exact mechanism the census was
  wrong by: my class-(c) name list is an uppercase token extraction over prose
  and misses `Pmode`. The four named conversions are exact; the 16 is a floor.
- **My `#182` code-vs-prose split is a heuristic** (`grep -vE ':\s*(\*|/\*|//)'`).
  It cannot see a `MIN_MODE_` inside a multi-line comment whose continuation
  line does not start with `*`. 39 is therefore an upper bound on code sites.
- The membership test in Group B reads `tm.texi` at `multi-target-0` and so
  inherits the truncation bug for the three lowercase-bearing names. It does
  not affect any of the eight names tested, all of which are uppercase or were
  checked by hand.
