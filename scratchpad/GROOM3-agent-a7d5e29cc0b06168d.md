# BACKLOG GROOMING 3 — the stranding is 80% resolved, `#167`/`#232` LANDED, and the merge candidate has moved

Worktree `agent-a7d5e29cc0b06168d`. Tree verified before any measurement:

```
git rev-parse HEAD            7208eca60d0caf9058ec285527089791b54096b3   <- WRONG (2022 bare-repo HEAD)
git rev-parse multi-target-0  a5cd237d9db99d2be1fbd4bdbbc7c876e52574ff
grep -c MULTI_TARGET gcc/Makefile.in   -> 0
ls scratchpad/                          -> does not exist
```

**The twentieth occurrence, and it was DIVERGENT.** Fixed non-destructively:

```
git checkout -b groom3-a7d5e29cc0b06168d multi-target-0
git rev-parse HEAD  == git rev-parse multi-target-0  == a5cd237d9db   EQUAL
grep -c MULTI_TARGET gcc/Makefile.in                 -> 52
ls scratchpad/A992B7E5FA4FFAAA7-BOARD.md             -> present
ls scratchpad/ | wc -l                               -> 1170
```

Nothing here changes code and **nothing here is a build**. Every figure is a
grep, a `git rev-list`, or a re-run of a committed text instrument. Every
"it is gone" verdict carries a positive control from the same command.

---

## 0. THE HEADLINE — THE BRANCH SITUATION HAS CHANGED, IN BOTH DIRECTIONS

GROOM2 (16 Aug) found three stranded branches holding 30 commits. **Three of
those are now merged. One grew and was superseded. One NEW one appeared.**

### 0(a) The branch-merge status table

Measured with `scratchpad/` script `br.sh`-equivalent:
`git rev-list --count multi-target-0..<b>` and `git merge-base --is-ancestor`.

| branch | ahead | behind | status |
|---|---|---|---|
| **`mt-ae59966cf819d72ef`** | **26** | 35 | **LIVE — THE MERGE CANDIDATE.** Superset: it merged `agent-a4568de8f522450d3-mt` at `9adf8ca6ae6` and adds 5 commits including **`ASM_OUTPUT_ADDR_VEC_ELT` / `ASM_OUTPUT_ADDR_DIFF_ELT` — "every jump table's contents were i386's", WRONG CODE on aarch64 and riscv64**. |
| **`agent-acf1cacfef7c17c69-work`** | **9** | 1 | **LIVE — NEW since GROOM2.** `MULTI_TARGET_MD_TU` (anchor 52 → 55); `EH_RETURN_STACKADJ_RTX` (riscv64 wrote the stack adjustment into `sp`); `STACK_POINTER_OFFSET`; `EH_RETURN_HANDLER_RTX`; the trampoline pair; `TARGET_HAS_FMV_TARGET_ATTRIBUTE`. Also records **"THE TIP DOES NOT CONFIGURE, and it has not since `e02b705aeea`"** — that claim needs adjudicating on its own. |
| `agent-a4568de8f522450d3-mt` | 21 | 88 | **SUPERSEDED** by `mt-ae59966cf819d72ef`, which contains all 21. Merge the superset, not this. |
| `worktree-agent-abe9f294136236fc8` | **0** | 113 | **MERGED.** GROOM2's #1 re-prioritise (the `#153` md5 correction) is in. |
| `worktree-agent-a95a42fd940ce4d8e` | **0** | 81 | **MERGED.** |
| `mt0-a25b899a4a184c923` | **0** | 50 | **MERGED** at `ad72b905cb4`. This is what closes `#167` and most of `#232`. |
| `mt0-cxx-a260445cf27ba480a` | 0 | 54 | MERGED |
| `worktree-agent-a018835bbcfad2e28` · `a591145022e2f4e73` · `a7d26223eefcfa725` · `aa44b9d995bd1c452` · `acda89931a903ec27` · `a98009045f7229938-dfa` · `agent-a992b7e5-board` · `agent-a8f6f467d15197cd3-work` · `agent-ad6a5c1d2539f5e18-work` · `agent-a13057f203eb4821c-fe` | **0** | 7–130 | **MERGED — nothing stranded.** |
| `worktree-agent-{a13057f203eb4821c, a25b899a4a184c923, a260445cf27ba480a, a4568de8f522450d3, a5fccbef8294a16ae, a7d5e29cc0b06168d, a8f6f467d15197cd3, a98009045f7229938, a992b7e5fa4ffaaa7, acf1cacfef7c17c69, ad6a5c1d2539f5e18, ae59966cf819d72ef}` | — | — | **STALE-HEAD NOISE.** All sit at `7208eca60d0`, the 2022 bare-repo HEAD. They hold nothing; every one of these agents did its real work on a differently-named branch. |
| `t193` (4) · `nsc-work` (1) · `mu-mode-union` (1) | 1–4 | 281–820 | **PRE-EXISTING TOPIC BRANCHES**, 281–820 behind. Not agent results; out of scope for this list. |

**Net: 30 stranded commits became 35, but the composition improved** — the
documentation correction that was costing days is merged, and what remains is
two branches with one clear merge order:

1. `agent-acf1cacfef7c17c69-work` — only **1 behind**, so it is a fast merge, and it carries a wrong-code fix (`EH_RETURN_STACKADJ_RTX`).
2. `mt-ae59966cf819d72ef` — 26 ahead / 35 behind, carries `#213`'s fix, the census corrections, `ADDR_VEC_ALIGN`, `ADJUST_INSN_LENGTH`, and the jump-table wrong-code fix.

---

## GROUP A

### `#213` s390x `.machine`/`.machinemode` — **STILL LIVE at `multi-target-0`. The fix is written and STILL UNMERGED.**

```
$ git grep -n 'ASM_OUTPUT_FUNCTION_PREFIX' -- gcc | grep -v ChangeLog
gcc/config/s390/s390.h:909:#undef ASM_OUTPUT_FUNCTION_PREFIX
gcc/config/s390/s390.h:910:#define ASM_OUTPUT_FUNCTION_PREFIX s390_asm_output_function_prefix
gcc/varasm.cc:2192:#ifdef ASM_OUTPUT_FUNCTION_PREFIX          <- raw #ifdef, UNCONVERTED
gcc/varasm.cc:2193:  ASM_OUTPUT_FUNCTION_PREFIX (asm_out_file, fnname);
```

The conversion is `0697120610d` on `mt-ae59966cf819d72ef` (touches
`varasm.cc`, `target-frame.h`, `target-cumargs.cc`, `target-cumargs-select.cc`).
The brief's premise "an agent converted it" is **true of the commit, false of
this branch** — the same defect GROOM2 reported, one branch further along.

**Its other half `hashtab_chk_error` is confirmed separate and untouched:**
`gcc/hash-table.h:309`, `gcc/hash-table.cc:121`, call site `hash-table.h:1122`.
Nothing target-related; do not carry it under `#213`.

**Next agent's first move:** merge `mt-ae59966cf819d72ef`; `#213` closes as a
side effect. Do not re-implement.

### `#232` `DELAY_SLOTS` / `GO_IF_LEGITIMATE_ADDRESS` / the matched pair — **PARTLY DONE. Nine of ten sites landed; ONE named residual remains, and it is a LINK boundary, not an oversight.**

Landed at `d1ae5fb5969` ("Three leaked ABSENCES in `final.cc` and its
neighbours"), merged into `multi-target-0` at `ad72b905cb4`.

```
$ git grep -n 'mt_delay_slots\|mt_go_if_legitimate_address' -- gcc | grep -v '\.h:' | grep -v ChangeLog | grep -v po/
gcc/cfgrtl.cc:496:  if (mt_delay_slots () && optimize > 0 && flag_delayed_branch)
gcc/final.cc:1069:	  if (mt_delay_slots ())
gcc/function.cc:6774:      gcc_assert (!mt_delay_slots ());
gcc/lra-constraints.cc:360:  if (mt_go_if_legitimate_address (mode, addr, false, &win))
gcc/recog.cc:1899:  if (mt_go_if_legitimate_address (mode, addr, false, &win))
gcc/reload.cc:2172:  if (mt_go_if_legitimate_address (mode, addr, true, &win))
```

`GO_IF_LEGITIMATE_ADDRESS` — **fully done**, three sites, and the strict /
non-strict pair is respected (`reload.cc` passes `true`, the other two `false`).
`DELAY_SLOTS` — five consumers plus the `toplev.cc` warning are converted.

**THE ONE RESIDUAL, precisely:**

```
$ git grep -n 'DELAY_SLOTS' -- gcc/opts.cc
gcc/opts.cc:644:#if DELAY_SLOTS
    { OPT_LEVELS_1_PLUS_NOT_DEBUG, OPT_fdelayed_branch, NULL, 1 },
```

`opts.cc:618-644`'s own comment states the mechanism: `opts.o` is in
`libcommon-target.a`, which does not contain `targetm_automata`, so
`mt_delay_slots ()` **cannot link there**. Consequence, unhedged in the tree:
`-fdelayed-branch` is **not enabled at `-O1` for the twelve back ends that have
delay slots** (arc, cris, fr30, h8300, iq2000, microblaze, mips, or1k, pa, sh,
sparc, visium). Explicit `-fdelayed-branch` now works on all twelve; default
enablement does not. The named route is
`TARGET_OPTION_OPTIMIZATION_TABLE` in `common/config/<cpu>/<cpu>-common.cc`.

**Next agent's first move:** that is a *second authority* for a fact
`genattr-common` already derives from the `.md`, so it needs an agreement check
against `mt_delay_slots ()` — file it as its own item rather than leaving
`#232` open for it.

### `#167` `FINAL_PRESCAN_INSN` — **ALREADY DONE. Both sites.**

```
gcc/final.cc:2674:	    mt_final_prescan_insn (insn, ops, insn_noperands);
gcc/final.cc:2809:	mt_final_prescan_insn (insn, recog_data.operand, ...);
gcc/final.cc:2669: /* ... This was `#ifdef FINAL_PRESCAN_INSN', i.e. a fact ... */
gcc/target-frame.h:1751: /* FINAL_PRESCAN_INSN -- TWO DEAD `#ifdef's IN `final.cc', AND THE RECORDED ... */
```

The two `#ifdef` sites the corrected description names (`final.cc:2666` and
`:2801`, now `:2669`/`:2809` after the conversion grew the file) are both gone.
GROOM2's correction — that the item's **original** text said the opposite of
the truth ("safe because i386 is primary" when i386 defining *nothing* is
exactly what made it a leaked ABSENCE on 14 back ends including arm's
conditional-execution engine) — held, was acted on, and is now discharged.
**Recommend close.**

### `#218` m68k `-%(VALUE)` — **STILL LIVE, unchanged, and it is a BLOCKER not a nuisance.**

```
$ git grep -n '%(VALUE)' -- gcc/config/m68k/m68k.h
gcc/config/m68k/m68k.h:32:%{!mcpu=*:%{!march=*:-%(VALUE)}}}}" },
```

Still the only `-%(VALUE)` in any back end
(`scratchpad/A7EE6CA7C923E4A58-M68K-OPTION-DEFAULT.md:68` — "1 `-%(VALUE)` <-
m68k, and only m68k"). Its cost is recorded in two boards:
`A7D26223EEFCFA725-BOARD.md:226` — **"m68k (#218) fails in the middle, so 23
targets were never [reached]"**, and `agent-acda89931a903ec27-specs.sh:35`
codes around it. **Re-prioritise up:** one back end's driver is truncating
board runs at less than half coverage.

### `#172` riscv end-to-end · `#75` host-tools edges — **STILL LIVE, both blocked behind `#37`, unchanged.**

```
$ git grep -n 'MT_TARGET_SUBDIRS' -- Makefile.in | head -3
Makefile.in:310:MT_TARGET_SUBDIRS = @mt_target_subdirs@
Makefile.in:70496:$(foreach mt_t,$(MT_TARGET_SUBDIRS),\           <- target-specs only
Makefile.in:70502:configure-target-specs: ...
```

The only non-prose uses remain `target-specs`, the empty-guard and the
`MT_SPECS_EMITTED` count check — GROOM's "1 of 26" holds verbatim.

### `#100` · `#25` · `#26` · `#21` · `#69` (the `#216` group) — **unchanged since GROOM2; `#21` still ZERO work.**

```
$ git grep -n 'HAVE_SOLARIS_AS' -- gcc | grep -v ChangeLog | head
gcc/config/i386/i386.cc:25715:#if HAVE_SOLARIS_AS
gcc/config/i386/sol2.h:47,55,114,144
```

Still `#if`-conditioned in back-end code, still 0 for everyone. GROOM2's note
that its consumers become **hard errors when sparc is enabled** is the reason
this one should not stay at the bottom.

### `#96` per-target data in libdir — **PARTLY DONE (driver half landed); only the `accel_dir_suffix` design question remains.**

```
gcc/Makefile.in:74,837,839,3938   accel_dir_suffix, libsubdir, libexecsubdir, -DACCEL_DIR_SUFFIX
```

Unanswered question unchanged and it is a **decision, not work**: are accel
targets just more configured targets? Belongs in Group C.

### `#46` `HAVE_LD_PIE` — **STILL LIVE, 14 macros / 28 sites, scoping unchanged.** Only the five `HAVE_LD_PIE` sites are provably vacuous (`mkconfig.sh:135-136` pre-defines it ahead of the target headers); the other 23 need per-site include-order reasoning and must not be swept.

---

## GROUP B — THE LEAK/CENSUS FAMILY, AND THE DOUBLE-COUNT QUESTION

### The census, re-run at `multi-target-0` — **292, not 296**

```
$ O=<scratch> sh scratchpad/agent-a018835bbcfad2e28-leakcensus.sh
tm.texi documents 543 target macros
TOTAL leaking macros: 292
  LEAK-PRIMARY (x86's answer served to all): 87
  DEAD-DEFAULT (fallback served to all):     205
already handled: REDIRECT 92, DESCRIPTOR 94
NON-VACUITY: ok: ASM_OUTPUT_ALIGN / HAVE_POST_MODIFY_DISP / PROMOTE_MODE / REG_ALLOC_ORDER  (4/4 classified)
```

The non-vacuity arm is the positive control and it passes 4/4 — a name that
falls out of both buckets would print FATAL, so the 292 is not an empty pipe.

**The four known wrongnesses, re-checked at this commit:**

| defect | status at `multi-target-0` |
|---|---|
| assumed 9-header primary chain (real one is 16) | **STILL PRESENT.** The `printf` fallback in the script lists 9 headers; the 16-header correction is `4530fd2d61c`, unmerged. |
| extraction matched `P` not `Pmode` | **STILL PRESENT** here; corrected in `87c69584b40`, unmerged. |
| DESCRIPTOR subtracts live leaks | **STILL PRESENT.** DESCRIPTOR is now **94** (the script's own comment concedes those headers "also DISCUSS macros they have not converted"). With the recorded ~35 live, the honest leak population is **≈327**, not 292. |
| ~109 undocumented macros invisible | **CONFIRMED, with a positive control.** |

**The blind-spot proof — this is the control the brief asked for:**

```
$ grep -cxw ASM_OUTPUT_ALIGN          macros.all -> 1     (control finds things)
$ grep -cxw FINAL_PRESCAN_INSN        macros.all -> 1     (control finds things)
$ grep -cxw ASM_OUTPUT_FUNCTION_PREFIX macros.all -> 0    <- the real blind spot
$ grep -cxw DELAY_SLOTS               macros.all -> 0
$ grep -cxw GO_IF_LEGITIMATE_ADDRESS  macros.all -> 0
$ grep -cxw ADDR_VEC_ALIGN            macros.all -> 0
$ grep -cxw ADJUST_INSN_LENGTH        macros.all -> 0
```

A zero here is discriminating because the same command returns 1 twice.

### THE ANSWER: they double-count the census **selectively**, and only two of the eight do

Membership tested by name against the census's three buckets
(`macros.all` = documented population, `report` = leaking, `report.conv` = handled):

| item | its unit | census overlap |
|---|---|---|
| **`#214`** `TARGET_SUPPORTS_WIDE_INT` | one macro | **DOUBLE-COUNTS.** `tm.texi=1 leaking=1` — it **IS one of the 292 rows**, promoted to its own item because of its size. Do not add it to the census total. |
| **`#220`** per-`config/<os>.h` macros | macros, but keyed on *triple*, not back end | **PARTIAL / UNSIZEABLE.** Its population is a slice of the same `@defmac` names, but the census's discriminator is "does the primary chain define it", which is blind to *which triple's* OS layer wrote `tm-<cpu>.h`. Overlap real, cardinality unknown. |
| **`#32`** compiled-once files | macros (413) | **330 of 413 overlap** (GROOM2's `comm -12`, unchanged), **83 census-invisible.** Largest double-count on the list. |
| **`#215`** `gen_rtx_REG` walkers | *sites* (26 @ MTW=30 / 37 @ MTW=120) | **DISJOINT.** Not a macro population at all. |
| **`#141`** headers / TUs | *headers* (5) and *TUs* | **DISJOINT.** |
| **`#147`** `.opt` enumerators | *enumerators* (421) over 35 `HeaderInclude` files | **DISJOINT.** A different vocabulary; `tm.texi` does not document `.opt` enumerators. |
| **`#160`** five channels | *channels* in `mkconfig.sh:193-208` | **DISJOINT.** |
| **`#234`** | — | **CANNOT TELL** (see §D). |

**So the answer to the question you most wanted:** the eight do **not** form a
mutually double-counting cluster. There is exactly **one clean duplicate**
(`#214` ⊂ census), **one large partial** (`#32`, 330/413), **one unsizeable
partial** (`#220`), and **four that are disjoint by unit** — they look like
they overlap only because they are all described in the same vocabulary
("macros leaking from the primary"). Summing their headline figures is wrong
by construction; treating them as one item is also wrong.

### The unmerged branch is closing census rows, and nobody has said so

```
STACK_POINTER_OFFSET     tm.texi=1 leaking=1 handled=0
EH_RETURN_STACKADJ_RTX   tm.texi=1 leaking=1 handled=0
EH_RETURN_HANDLER_RTX    tm.texi=1 leaking=0 handled=1
TRAMPOLINE_ALIGNMENT     tm.texi=1 leaking=0 handled=1
```

The first two are **named rows of the 292** and are exactly what
`agent-acf1cacfef7c17c69-work` fixes. Merging that branch is a measurable
census decrement, not just a bug fix.

### `#32` — **STILL LIVE; the prior groom's correction is STILL not applied** (285 sites in per-base `target-*.cc` still in the population; honest figure ~2560 of 2845). And its `t32-values.tsv` is still **83/109 of the undocumented-macro instrument** the newest board asked someone to build. Unchanged; still the best value-per-effort item on the list.

### `#141` — **restate as FIVE headers** (`MT_HEADER (tm.h)` → 5). TU count needs a build.
### `#147` — header half reproduces (35 `HeaderInclude` files); the 421 needs `mtq-enumleak.sh` against a 48-base build. **CANNOT TELL WITHOUT A BUILD.**
### `#160` — **CONFIRMED five**, `mkconfig.sh:193-208`; census half done, two non-per-target channels remain.
### `#215` — reproduces at 26/37. **The acceptance bar must not be "drive it to 0"** — the one site measured to fire (`peep2_find_free_register`) is not in the 26.
### `#220` — **STILL LIVE, UNSIZED.** Sizing needs `cpp -dM` on two `tm-<cpu>.h` from **two triples of one back end**; a 47-triple build cannot answer it. Right home for `#100`'s `cygming.h:366` and `#210`'s residue.

**`#210` note, corrected since GROOM2:** `DWARF2_UNWIND_INFO` now reads
`tm.texi=1 leaking=0 handled=1` — it has moved from the leaking bucket to the
handled one. GROOM2 called it "a named member of the census"; that is no longer
true of the *leaking* set. Its residue is still `#220`'s. **Fold and close.**

---

## GROUP C — DECISIONS

- **`#37`** target libraries beyond libgcc — **STILL LIVE, "1 of 26" confirmed at `Makefile.in:310,70496,70502`.** Gates `#172` and `#75`. This is the largest single unblocking decision on the board.
- **`#39`** upstreaming — **STILL LIVE, still a placeholder.** Two tasks in one number: (i) file the bugs (`scratchpad/UPSTREAM-BUGS.md` exists), (ii) carve a series (`gen-blockage-WIP.patch` is the only artefact). Split it or it will never move.
- **`#140`** class (c) — **PARTLY DONE, much further than "~1 of 91".** R1 landed (`multi-target-macros.h:1470,1472,1474`; positive control `:773 Pmode`); ≥16-17 of 91 converted. **Re-size, keep open.**
- **`#143`** 8 bare `host_detect_local_cpu` — **STILL LIVE; count confirmed (7 bare + s390 prefixed).** It is a **scope decision** ("is `-march=native` in scope?"), not work. Move to a decisions list, off the work backlog.
- **`#174`** `configure.ac:1621` — **mostly OBSOLETE.** Two of its three call-outs describe landed fixes; only `:257` (`use_gcc_stdint`) is untouched, and that is `#192`. **Re-write as `use_gcc_stdint`, or fold into `#192` and close.**
- **`#229`**, **`#236`** — **CANNOT TELL.** See §D.
- **`#96`** (listed in A, belongs here) — the `accel_dir_suffix` question is a decision, not work.

---

## GROUP D — THE RECORDS, AND A LIMIT ON THIS DOCUMENT

**A limit I have to state, because it changes how the rest reads.** The
backlog's item *text* is **not in the tree**. `git grep '#21[4-9]\|#22[0-9]\|#23[0-9]' -- scratchpad`
returns exactly one hit (`DESIGN-216-...md:1`) plus three incidental mentions
of `#218` in boards. Every groom pass so far has reconstructed item text from
its brief and from the previous groom document. That means:

- Items my brief described (Group A, and the Group B/C names GROOM/GROOM2 already characterised) I could adjudicate against the tree.
- **`#217`, `#229`, `#234`, `#236`, `#237`, `#238` I cannot adjudicate**, because no text for them exists in the tree or in either prior groom. **CANNOT TELL — and what would settle it is not a build, it is one commit putting the item list in `scratchpad/`.**

**That is my strongest Group D recommendation:** commit the backlog. The
project's most expensive recurring defect is *one name, several authorities*;
an item list that lives only in briefs is exactly that shape, and it has now
cost three grooming passes their precision.

**On the general question — which items are records, not work:** the criterion
that works in this tree is *does the item's deliverable already exist as a
committed document?* By that test the following are records and should be
closed as recorded, on the evidence that their artefact is in `scratchpad/`
and current:

- **`#182`** (43 sites / 5 causes) — closed by GROOM2, artefact present.
- **`#169`** the guard census — `scratchpad/T169-GUARD-CENSUS.txt`.
- **`#168`** triple map — complete per GROOM.
- **`#89`** the 32-line stderr floor — documented with its composition; upstream noise.
- Every `*-BOARD.md` filed as a task. There are **eight** committed boards
  (`A018835BBCFAD2E28`, `A01E6C604F26604A7`, `A7D26223EEFCFA725`,
  `A7EE6CA7C923E4A58`, `A95A42FD940CE4D8E`, `A98009045F7229938`,
  `A992B7E5FA4FFAAA7`, `AB1900D5279BA137F`). A board is a measurement; it is
  discharged the moment it is committed, and carrying it as pending inflates
  the count without naming any work.

`#237`/`#238`/`#217` are, per the brief, of this kind. **Recommend closing them
as recorded**, with the caveat that I could not read their text — if any of
them names an *unbuilt* instrument rather than a filed measurement, that one
should stay open.

---

## RECOMMENDED CLOSE LIST — ranked

| # | item | why | evidence |
|---|---|---|---|
| 1 | **`#167`** `FINAL_PRESCAN_INSN` | **DONE.** Both `#ifdef` sites converted. | `final.cc:2674`, `:2809`, `target-frame.h:1751`; merged `ad72b905cb4` |
| 2 | **`#232`**'s `GO_IF_LEGITIMATE_ADDRESS` half | **DONE.** Three sites, strict/non-strict pair respected. | `recog.cc:1899`, `reload.cc:2172` (strict), `lra-constraints.cc:360` |
| 3 | **`#232`**'s `DELAY_SLOTS` half | **DONE except `opts.cc:644`.** Close the item; **re-file the residual** as "`-fdelayed-branch` default enablement via `TARGET_OPTION_OPTIMIZATION_TABLE`, with an agreement check against `mt_delay_slots ()`". | `cfgrtl.cc:496`, `final.cc:1069`, `function.cc:6774`, `reorg.cc:3838/3878`, `toplev.cc:1439`; residual `opts.cc:644` |
| 4 | **`#210`** | **Duplicate.** `DWARF2_UNWIND_INFO` has moved to the census's *handled* bucket; residue is `#220`'s. | membership test: `leaking=0 handled=1` |
| 5 | **`#174`** as written | **OBSOLETE.** Re-write as `use_gcc_stdint` or fold into `#192`. | `gen-target-manifest.sh:184,210` describe landed fixes; only `:257` open |
| 6 | **`#237`, `#238`, `#217`** and the eight `*-BOARD.md` items | **Records, not work.** Artefact committed = discharged. | `ls scratchpad/*BOARD.md` → 8 |
| 7 | **`#213`** — **conditionally** | Closes the moment `mt-ae59966cf819d72ef` merges. Do not re-implement; do not close before the merge. | `varasm.cc:2192` still raw at `multi-target-0` |
| 8 | **`#143`** | Move to a **decisions** list, off the work backlog. It is "is `-march=native` in scope?", not work. | 7 bare definers + s390 prefixed; rename list = 0 with a working positive control |

**Restate rather than close:** `#141` (four → **five**), `#32` (**~2560** honest
sites; 330 of its 413 macros are the census's), `#46` (13/22 → **14/28**),
`#140` (~1 → **≥16 of 91**), the census itself (296 → **292 measured, ≈327 honest**).

## RECOMMENDED RE-PRIORITISE LIST — ranked

1. **MERGE THE TWO REMAINING BRANCHES.** `agent-acf1cacfef7c17c69-work` first —
   it is **1 commit behind**, so it is nearly a fast-forward, and it holds a
   wrong-code fix (`EH_RETURN_STACKADJ_RTX`: riscv64 wrote the stack adjustment
   into `sp`) plus two named census rows. Then `mt-ae59966cf819d72ef`, which
   closes `#213` and carries **`ASM_OUTPUT_ADDR_VEC_ELT` — every jump table's
   contents were i386's, wrong code on aarch64 and riscv64.** GROOM2 made this
   its #1 and it was 60% acted on; the remaining 40% is two commands.
2. **ADJUDICATE "THE TIP DOES NOT CONFIGURE, and it has not since `e02b705aeea`"**
   (`abad5d977ea` on `agent-acf1cacfef7c17c69-work`). If true at
   `multi-target-0` this dominates everything else on this list. It is the one
   thing I could not settle without a build, and settling it is `configure`
   alone, not a compile.
3. **`#218` m68k.** One driver truncating board runs at less than half the
   targets (`A7D26223EEFCFA725-BOARD.md:226` — 23 targets never reached). Cheap,
   and it unblocks every subsequent measurement.
4. **`#32` re-framed as the undocumented-macro instrument.** 83 of ~109 already
   in a committed `t32-values.tsv`. Nothing needs writing; it needs connecting.
5. **`#37`.** Gates `#172` and `#75`, and every execution result. Still 1 of 26.

Behind those: **`#214`'s `rtl.h` half** (22 `#if`s over 12 shared files; and
note it is *already counted* in the census, so it is not extra population),
**`#220` sized** (two triples of one back end), **`#21`'s `HAVE_SOLARIS_AS`**
(becomes hard errors when sparc is enabled), **`#39`** (split it).

## WHAT THIS DOCUMENT DOES NOT CLAIM

- **No build, no suite run.** Nothing here is a debt figure of mine.
- **I could not read six items' text** (`#217 #229 #234 #236 #237 #238`); their
  verdicts are CANNOT TELL, not closures, and the fix is a commit not a build.
- **The census I re-ran is the UNCORRECTED one** — that is deliberate, because
  it is the one on `multi-target-0`. 292 is what this branch's instrument says;
  ≈327 is the honest population once DESCRIPTOR's ~35 live leaks are added back.
- **`DESCRIPTOR` at 94 is a weak bucket by its own admission** and I did not
  re-audit it; the ~35 figure is inherited, not re-measured.
- The `#32` ∩ census figures (330/83/213) are **GROOM2's**, re-quoted, not
  re-run; the underlying `t32-values.tsv` and `macros.all` are both unchanged
  at this commit (543 names reproduced exactly), so they carry over.
