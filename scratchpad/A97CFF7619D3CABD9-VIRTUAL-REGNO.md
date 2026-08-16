# x86_64's top ICE was NOT a classifier — it was TWO PRODUCERS, and the queue's own rule found both

`internal compiler error: in in_hard_reg_set_p, at regs.h:312`, reached from
`recog.cc:1598`, was **1,756 ICE FAILs on x86_64 at 47 bases, bounding 2,480 of
its 2,971-result debt** (`AB1900D5279BA137F-BOARD.md` §3). It is now **2**, and
`recog.cc:1598` was **not converted**.

## PROVENANCE — quote this with any row

```
srcdir      /tmp/snap-agent-a97cff7619d3cabd9        2a1c81a21bb   (baseline)
            /tmp/snap-agent-a97cff7619d3cabd9-fix2  118c9ff5005   (both fixes)
            git archive, read-only, SNAP-SHA stamped; anchor MEASURED = 52 both
build       /tmp/b-a97cff7619d3cabd9  and  -fix2
            --enable-targets = the 47 triples of scratchpad/backends-47.txt
            make all-gcc rc=0; `error:' 0; multiple definition 0;
            undefined reference 0; Killed 0; cc1 links
bars (fix2) x86_64 -O2 big.c   12369 bytes / md5 378fc33c1e70   (== recorded)
            x86_64 -O2 -g      rc=0, 78540 bytes, md5 eb6df404b05d, real
              .debug sections -- PATH-SENSITIVE, only meaningful with
              in=/tmp/snap-agent-a97cff7619d3cabd9-fix2/scratchpad/big.c AND
              builddir=/tmp/b-a97cff7619d3cabd9-fix2
            specs-config x4, wc -l 232 / grep -c . 224, md5s ALL as recorded:
              x86_64 cfbc7a65e54e  aarch64 575aff0c188b
              riscv64 9af7409ac460 s390x 37901805bf3c
mode        MT_COMPILE_ONLY=1, all-gcc only, no target libgcc
tools       taa-tools.sh: real cross binutils + each target's own glibc headers
guards      every mtcheck.sh guard green, GUARD 3c reporting the target's OWN
            assembler; `.rc' stamp asserted on every run
load        HIGH -- 20..37 during these runs, because two builds, two testsuite
            runs and ANOTHER AGENT's aarch64 runs overlapped.  Above the ~25
            line, so **these rows are PROVISIONAL by the board's own rule**.
            KILLED counted, never subtracted.
```

## CAUSE 1 — the virtual register numbering had two authorities

`rtl.h:4232` was `#define FIRST_VIRTUAL_REGISTER (FIRST_PSEUDO_REGISTER)`, and
that name is **not one number on this branch**: `multi-target-macros.h:322`
redirects it to the union's width for a SHARED translation unit and
deliberately leaves a back end's own TU with its own.

Measured with each object's OWN compile command
(`agent-a97cff7619d3cabd9-vregno.sh`; it reads two numbers and compares them, so
it cannot pass without having read both):

```
                     FIRST_PSEUDO_REGISTER   LAST_VIRTUAL_REGISTER
shared recog.o                         677                     682
i386   i386-expand.o                    92                      97
```

`i386-expand.cc:27096` builds `gen_raw_REG (mode, LAST_VIRTUAL_REGISTER + 1)`
= **98**, hands it to shared `recog.cc:1598`, where 98 < 677 reads as a HARD
register. Backtrace, `gcc.c-torture/compile/pr118362.c -O2`:

```
fancy_abort <- in_hard_reg_set_p <- general_operand <- nonimmediate_operand
  <- insn_i386::recog_338 <- expand_vselect <- expand_vec_perm_1
  <- ix86_expand_vec_perm_const_1 <- ix86_vectorize_vec_perm_const
  <- can_vec_perm_const_p
```

Fixed by spelling the numbering `MULTI_TARGET_UNION_FIRST_PSEUDO_REGISTER` —
a LAYOUT use of the union bound, since shared `emit-rtl.cc` creates the virtual
rtxes at these numbers and starts pseudos at `LAST_VIRTUAL_REGISTER + 1`.
Instrument after: `VERDICT: EQUAL (682)`, and `FIRST_PSEUDO_REGISTER` still 92
in the back end's TU, which is what must not move.

**The same defect with the opposite symptom, silent:** `riscv.cc:3486`/`:9405`
compare `REGNO (x) == VIRTUAL_STACK_VARS_REGNUM` — a real 678 against riscv's
66 — and were simply never true. `aarch64.cc:11671`'s `virt_or_elim_regno_p`
likewise never recognised a virtual pointer register, which is why aarch64's
`big.c` codegen CHANGES with this fix (76 lines, in `f_va`; the fixed form folds
the va_arg address instead of branching on a runtime sign test).

## CAUSE 2 — `peep2_find_free_register` walked to the union bound and MADE a REG

1,756 -> 191 is not 1,756 -> 0, and **the 191 were a different producer**:

```
cc1 -O2 -w -std=gnu89 gcc.c-torture/compile/920625-1.c
  during RTL pass: peephole2
  ... <- general_operand <- insn_i386::peephole2_12 <- peep2_find_free_register
```

`recog.cc:3823` is `for (i = 0; i < FIRST_PSEUDO_REGISTER; i++)` in a shared TU
and the index it settles on goes to `gen_rtx_REG`. `MT_FIRST_PSEUDO_REGISTER`
is the selected base's own count. This is the "union bound as a LOOP bound"
shape PRINCIPLES already records twice.

## WHY `recog.cc:1598` IS STILL SPELLED WITH THE UNION, DELIBERATELY

`A57163422943AAA57-REGNO-CLASSIFIER-QUEUE.md` asks for the producer to be
established before a consumer's classifier is touched. Established:
`operand_reg_set` is produced by `reginfo.cc:543`, which walks the UNION's
bound and clears every bit whose `REGNO_REG_CLASS` is `NO_REGS` — and the
fenced `regno_reg_class` answers `NO_REGS` outside the base's range. So the
consumer's data is correct at the union's width; what was wrong was that regnos
in `[92, 677)` existed at all. With the two producers fixed they do not, and
the union comparison at `recog.cc:1598` classifies correctly with no change.
**Converting it would have been wrong**: regnos 92..676 would then have taken
the *pseudo* branch and `general_operand` would have accepted a nonexistent
register as if it were a pseudo — a quiet wrong answer replacing a loud one.

## RESULT — x86_64, by name, 47 bases

```
                      PASS      FAIL   in_hard_reg_set_p ICEs   DEBT vs stock
baseline (2a1c81a)  159267     20882                    1756           2,971
+ cause 1           161399     17458                     191             839
+ cause 2 (fix2)    161826     16843                       2             412
```

`mt-namediff.sh` baseline -> fix2, by (name, occurrence):

```
REAL PROGRESS (NOT PASS -> PASS):  2,559
REAL REGRESSIONS (PASS -> NOT PASS):   0
cardinality: 0 results come from tests that produced fewer before
top progress directories: gcc.dg/vect 1134, gcc.target/i386 255,
  gcc.dg/params 247 (ALL of it), gcc.dg/torture 195, gcc.dg/gomp 191,
  gcc.dg/tree-ssa 115, gcc.c-torture/compile 78
```

The baseline row **reproduces `AB1900D5279BA137F-BOARD.md`'s x86_64 row exactly**
(159267 / 20882), which is what makes the deltas comparable with that board.

## BOTH-SIDED — AND aarch64 MOVED AWAY FROM STOCK BY 505. STATED FIRST.

```
target    base PASS/FAIL     fix2 PASS/FAIL    DEBT base -> fix2   by-name
x86_64    159267/20882       161826/16843       2,971 ->   412     +2559 / -0
aarch64   338728/26294       338215/27352       3,675 -> 4,180     +271 / -776
riscv64   267535/18493       267551/18477       2,169 -> 2,153       +16 / -0
s390x     see board doc      (run pending at time of writing)
```

**The 776 aarch64 regressions are ALL `gcc.target/aarch64`, and every one of
them is the board's item #1 — not a new defect.** Named reproducer, compiled
with both compilers from the same command
(`agent-a97cff7619d3cabd9-aa.sh`):

```
gcc.target/aarch64/sme/acle-asm/addha_za32.c -std=c90 -O0 -g -DTEST_FULL
                                             -march=armv8.5-a+sve2+sme
base  rc=0
fix2  rc=1  error: could not split insn
      (insn 21 (set (reg:DI 1 x1 [689])
               (plus:DI (reg/f:DI 31 sp)
                        (const_poly_int:DI [-48, -40]))) 160 {*adddi3_poly_1}
      during RTL pass: final
      internal compiler error: in final_scan_insn_1, at final.cc:2846
```

Sized at file level (`mt-debt-attribute.sh`, an UPPER bound):

```
aarch64 `final_scan_insn_1'   base  806 files / 2,899 debt (78%)
                              fix2 1026 files / 3,455 debt (82%)
```

The mechanism is the *other* half of cause 1. `aarch64.cc:11671`
`virt_or_elim_regno_p` was comparing a real virtual regno (677..681) against
aarch64's own 96..100 and was therefore **always false**, so
`aarch64_classify_address` declined an addressing form it should have accepted.
With one numbering it accepts it, forms `plus (sp, const_poly_int)`, and that
insn meets `*adddi3_poly_1`'s missing splitter — the single highest-value item
on `AB1900D5279BA137F-BOARD.md`, owned by another worktree and in flight.

**So this is a leaked ABSENCE becoming visible, not new breakage**, and the
honest statement is both halves at once: net across the three targets measured
is **−2,070 debt**, and aarch64 alone is **+505 until the `const_poly_int`
split lands**. If the coordinator wants no aarch64 regression at any point,
land the split first; the two changes are independent and commute.
Deliberately NOT mitigated here: gating `virt_or_elim_regno_p` back off would
be re-introducing the leak to keep a number down, which §2a names.

## THE TWO RESIDUAL ICEs, NAMED

```
FAIL: gcc.target/i386/pr55934.c  (internal compiler error: in in_hard_reg_set_p, at regs.h:312)
FAIL: gcc.target/i386/pr58048.c  (internal compiler error: in in_hard_reg_set_p, at regs.h:312)
```

A third producer, unlocated. It is 2 results, not 1,756.

## THE HANDOVER LIST, WITH ITS OWN BLIND SPOT STATED

`agent-a97cff7619d3cabd9-regmaker.sh` greps shared `.cc` for a walk to
`FIRST_PSEUDO_REGISTER` followed by `gen_rtx_REG`/`gen_raw_REG`: **26 sites at a
30-line window, 37 at 120**, in `builtins.cc`, `caller-save.cc`, `combine.cc`,
`cse.cc`, `dwarf2cfi.cc`, `ira.cc`, `lra-constraints.cc`, `reload.cc`,
`reload1.cc`, `targhooks.cc`. **The one site measured to fire is NOT in the
30-line list** — `peep2_find_free_register`'s loop head is 81 lines above its
`gen_rtx_REG`. A hit list from this instrument is a lower bound; it can
nominate, never authorise.

## TWO METHOD NOTES PAID FOR HERE

- **A `-ftarget-config=` pointing at a NONEXISTENT file was read as a
  reproduction.** A gdb arm used `lib/gcc/16.0.0/...` where the tree is
  `17.0.0`; `cc1` died with *"no target configuration was selected"* and the
  transcript's tail looked like the ICE being chased. Checked afterwards: the
  flag DOES fail by name (rc=4, no object), so the arm was recoverable — but
  the reading was wrong for ten minutes and only re-running it settled it.
- **The agent harness kills long background tasks.** Two aarch64 `mtcheck.sh`
  runs were stopped an hour in with status `killed`, and a killed run leaves no
  `.rc` — which is the same observation as "still running".
  `agent-a97cff7619d3cabd9-detach.sh` runs them under `setsid` for that reason.
