# The defects no board can see — and the one that stopped every board

Worktree `agent-acf1cacfef7c17c69`, branch `agent-acf1cacfef7c17c69-work`, off
`multi-target-0` at `a5cd237d9db`, anchor **52**.

---

## 0. THE TIP DOES NOT CONFIGURE, AND HAS NOT SINCE `e02b705aeea`

Found by trying to build it, before any of the assigned work.

```
gen-target-manifest.sh: line 372: syntax error near unexpected token `('
make: *** [Makefile:4779: configure-gcc] Error 1
```

`sh -n` at each commit localises it, and the answer is not where the
diagnostic points:

| commit | `sh -n gcc/gen-target-manifest.sh` |
|---|---|
| `e1f0cad1c2c` (the four-target board's snapshot) | PARSES |
| `8061a2c85ba` | PARSES |
| **`e02b705aeea`** | **SYNTAX ERROR** |
| `36d5aa56894` (the other merge parent) | PARSES |
| `a5cd237d9db` (the tip) | **SYNTAX ERROR** |

So **no build has been possible from the tip for a day**, and the last board
was taken from `e1f0cad1c2c`, which is why nobody met it.

**The cause is 153 lines above the diagnostic.** Lines 214–222 sit inside the
multi-line command substitution assigned to `gcc_mt_data` (opens ~117, closes
at the `|| {` at ~328). *While the shell scans for that closing backquote it
does not honour `#` comments.* `e02b705aeea` added two comment lines there in
the house backquote-apostrophe style, each contributing one backquote, so the
parity of every backquote after them flipped — and the net effect landed on
line 372, an unrelated comment legal for months, whose backquote now *opens* a
substitution. `struct GTY(())` is then a command.

Two things worth carrying:

- **The diagnostic names the victim, not the cause**, and the victim is a line
  nobody touched. Bisecting the *file* with `sh -n` (five commits, seconds)
  beat reading the reported line, which is where the obvious effort goes.
- **The commit that introduced it was itself about comments that lie** — it
  corrected three source comments citing calibration scripts that had never
  been committed, and broke the build with the prose of the correction.

Fixed in `abad5d977ea`. My own first attempt at the explanatory comment
reproduced the bug exactly (I wrote the warning about backquotes *using*
backquotes, inside the block it warns about); `sh -n` caught it. **Guard
added**: `mt-conf.sh` now runs `sh -n` over every `$SRC/gcc/*.sh` before
configuring, so this class fails by file name in seconds rather than inside
`configure-gcc`.

---

## 1. ITEM 4 — `TARGET_HAS_FMV_TARGET_ATTRIBUTE`: MEASURED, AND IT MOVED

`abad5d977ea`. The `#ifndef` floor in the polarity where **the primary is
silent, so the floor fires and the dissenters read it**.

### The build

```
srcdir   /tmp/snap-abad5d977ea-agent-acf1cacfef7c17c69   (git archive, read-only)
anchor   52
targets  the 47 triples of scratchpad/backends-47.txt
make all-gcc   rc=0    error: 0    multiple definition 0    undefined reference 0
cc1            links, 231,155,760 bytes
```

### The bars

```
x86_64 -O2 big.c   12369 bytes  md5 378fc33c1e70    == THE RECORDED BAR, exact
  in=/tmp/snap-abad5d977ea-agent-acf1cacfef7c17c69/scratchpad/big.c
specs-config  all four targets   wc -l 232   grep -c . 224
  md5s NOT quoted as a bar -- they are a function of the probing toolchain's
  paths (they did in fact reproduce cfbc7a65e54e / 575aff0c188b, which is an
  observation, not a check that was applied)
```

### The reproducer, both-sided

`scratchpad/agent-acf1cacfef7c17c69-fmv.sh`:

```
ARM 0  negative control fires (the harness is reading a real cc1)   OK
ARM 1  aarch64 mv-1.c   rc=0
       foo.default=1  foo._M*=3  foo.resolver=1  (want 1 / 3 / 1)   PASS
ARM 2  x86_64 target_clones control  rc=0
       IDENTICAL to genuine stock over 42 body lines                PASS
ARM 3  riscv64 '#'-separated target_clones  rc=0, 10 version labels
```

Arm 2 is the load-bearing one: x86_64 reads the floor's `1` as its **own**
answer, so it must not move, and it is compared against genuine upstream
rather than against a remembered number.

### The movement, by name

`scratchpad/agent-acf1cacfef7c17c69-fmvdiff.sh`, over
`gcc.target/aarch64/{mv,fmv,mvc}*.c`:

```
                  OLD                NEW
PASS               47                252
FAIL               72                 16
UNRESOLVED        150                  0
                  ---                ---
                  269                268
```

**+205 PASS, −56 FAIL, −150 UNRESOLVED.** Cardinality is stable (exactly one
file moves, `mvc-symbols3.c` 9→8), so this is an outcome flip and not the
"one UNRESOLVED becomes twenty scan-assembler results" artefact that a column
total cannot distinguish from a regression.

**Two caveats, stated rather than buried:**

- The OLD side is the four-target board's own preserved aarch64 sum, at
  `e1f0cad1c2c`, **37 commits back**, three of which touch the compiler
  (`TARGET_VTABLE_ENTRY_ALIGN`, a `use_gcc_stdint` manifest key, a
  `cxx_target_objs` fix). None is FMV-shaped and no moved name lies outside
  this population — but the base differs. A clean PRE would need a 47-base
  build of the parent commit, **and the parent commit does not configure**
  (§0). The nearest buildable ancestor *is* the board's snapshot.
- `mt-namediff.sh` **refuses** both subsets with *"269 / 268 rows — one of
  these is not a full run"*. That guard is correct and was not relaxed; the
  per-test-file cardinality arm above is namediff's own load-bearing arm,
  recomputed over the subset.

Against the board's estimate: the FMV item was sized at **256** of aarch64's
443 (`mv*` 221 + `fmv*` 35, an upper bound in the `mt-debt-attribute.sh`
sense). Measured over `mv*`+`fmv*`+`mvc*`, non-PASS results go **222 → 16**.

### The 16 that remain are ONE cause, and it is a new leak

Every one of them is

```
FAIL: ... scan-assembler-times \n\t.type\tfoo, %gnu_indirect_function\n 1
```

and the directive **is** emitted — as `.type foo, @gnu_indirect_function`.
`TYPE_OPERAND_FMT`: `elfos.h:284` is `"@%s"`, **`aarch64-elf.h:149` and
`arm/elf.h:74` are `"%%%s"`**, `sparc/sysv4.h:59` is `"#%s"`. `defaults.h:261`
builds `ASM_OUTPUT_TYPE_DIRECTIVE` out of it and `varasm.cc` expands it, so all
47 get i386's `@`.

**Not fixed here, deliberately, and the reason is §2b.** It looks like a
one-line `TARGET_CDATA_FIELDS` `STR` slot, and the supply side has a real
design question: **not every back end defines `TYPE_OPERAND_FMT`**, so
`target-cdata.cc` would need either an optional-STR mechanism (which does not
exist — `TARGET_CDATA_OPT_FIELDS` is `OPTNUM` only) or an invented default.
Worse, the *consumer* guard `#if defined TYPE_ASM_OP && defined
TYPE_OPERAND_FMT` is itself answered by i386's chain, so shared code has
`ASM_OUTPUT_TYPE_DIRECTIVE` defined for back ends that should not have it —
a leaked *presence* under the leaked value. Handed over with the evidence
rather than guessed at. `TYPE_ASM_OP` is **not** divergent (three definers,
all `"\t.type\t"`), so it is only the one macro.

---

## 2. ITEMS 1, 2, 3 — and a FOURTH the repaired instrument found

`be64f6a0516` and `5d1dd487000`. All are `target_frame_desc` **calls**, not
`TARGET_CDATA_FIELDS` slots, and in each case the definer set is the argument.

| macro | class | what it did |
|---|---|---|
| `STACK_POINTER_OFFSET` | floor-fires | s390x stack args 160 bytes low, in the callee's register save area |
| `EH_RETURN_HANDLER_RTX` | floor-fires | `__builtin_eh_return` **errors** on aarch64 and s390x |
| **`EH_RETURN_STACKADJ_RTX`** | **primary defines it** | **riscv64 wrote the stack adjustment into `sp`** |
| `TRAMPOLINE_SECTION` | leaked absence | aarch64's trampoline template not in `text_section` |
| `TRAMPOLINE_ALIGNMENT` | floor-fires | `.align 2` where aarch64 asks 64 and stock emits `.align 3` |

**`EH_RETURN_STACKADJ_RTX` is the one nobody had.** It was found by repairing
`agent-a992b7e5fa4ffaaa7-ehreturn.sh`, which hardcoded **another worktree's
build dir**, had no non-vacuity arm and **no control** — it printed
multi-target's `rc` alone. Given a stock control it said, of a target the
handover note recorded as passing:

```
riscv64-unknown-linux-gnu    rc=0  DIFFERS from stock
```

```
STOCK                      MULTI-TARGET
  sd    a1,40(sp)            mv    sp,a0      <- register 2
  ...                        ...
  mv    a4,a0                (a4 never written)
  add   sp,sp,a4             add   sp,sp,a4   <- a4 is garbage
```

There is **no floor** in this one: it is a bare `#ifdef` on a name the primary
*defines*, so the guard is true for all 47 and the register inside is i386's
`CX_REG` = 2, which on riscv is `sp`. riscv's own epilogue (`riscv.cc:10806`,
per base and correct) still reads `a4`.

**And it had to land with `EH_RETURN_HANDLER_RTX`, not after it.** On aarch64
and s390x the handler leak stops compilation, which *masks* this one; fixing
the handler alone would have let those two targets through to the same wrong
`mv` — a diagnostic converted into wrong code on two further targets.

`EH_RETURN_STACKADJ_RTX` and `TRAMPOLINE_SECTION` are **`#undef`d in shared
code with no replacement**, because both are asked with `#ifdef`. That makes
the change self-verifying: a missed site is a compile error naming the macro,
rather than a site quietly still reading i386's answer.

### CORRECTION: the trampoline was NOT a W^X failure

`A992B7E5FA4FFAAA7-TRAMPOLINE.md` records item 2 as *"a trampoline is
EXECUTED, `.rodata` is not mapped executable, so a call through a nested
function's address faults at run time — a W^X failure"*, and reads `.rodata`
as *"wherever the previous section left off"*. **Both halves are false.**
`varasm.cc:3065` has an explicit `#else switch_to_section
(readonly_data_section)` with the comment *"by default, put trampoline
templates in read-only data section"* — the section is chosen, not inherited —
and what lands there is the **template**, which
`targetm.calls.trampoline_init` copies into the real writable/executable
trampoline at run time. Nothing executes out of `.rodata` and nothing faults.

What is true is that aarch64 asks for `text_section` and does not get it, so
the output diverges from genuine stock by exactly the leak mechanism this
branch exists to remove. Severity: *a divergence from the target's own
declared answer*, not *wrong code*. Fixed anyway; the claim is corrected
because overstating a finding is worse than not reporting it.

---

## 3. WHAT THESE ARE WORTH ON A BOARD — SAY IT PLAINLY

**Item 4 moves the board. Items 1, 2, 3 and the `EH_RETURN_STACKADJ_RTX` find
will not, and it would be dishonest to imply otherwise.** Every one of them
compiles, assembles, and produces a well-formed ELF object of the right
machine. The s390x ABI break has *every other instruction identical to stock*.
That is the whole point of the assignment: **a compile-only board is a lower
bound, and these are the proof.**

The one thing that would make them visible is an execution arm, or a standing
both-sided emitted-code diff against stock over a fixed corpus. The four
reproducers in `scratchpad/` are that instrument in miniature, and the
`ehreturn.sh` repair shows the cost of not having it: a genuine wrong-code bug
on riscv64 sat behind a script that could only see `rc`.

---

## 4. INSTRUMENT DEFECTS FIXED, NOT JUST REPORTED

- `scratchpad/agent-a992b7e5fa4ffaaa7-ehreturn.sh` — hardcoded another
  worktree's build dir (the FOREIGN-SRC population PRINCIPLES §4 sizes at
  485/506); no non-vacuity arm; no control. Now takes the build dir as a
  **required argument with no default**, asserts `MY-SRC`, compiles a
  must-succeed control per target first, and diffs against genuine stock.
  It found a live bug on its first run afterwards.
- `scratchpad/mt-conf.sh` — now `sh -n`s every `$SRC/gcc/*.sh` before
  configuring (§0).

## 5. FILES

```
scratchpad/agent-acf1cacfef7c17c69-build.sh    snapshot + configure + build, 47 bases
scratchpad/agent-acf1cacfef7c17c69-fmv.sh      item 4, both-sided, 4 arms
scratchpad/agent-acf1cacfef7c17c69-fmvdiff.sh  item 4's movement, by test name
scratchpad/agent-acf1cacfef7c17c69-verify.sh   all arms + bars, one command
```
