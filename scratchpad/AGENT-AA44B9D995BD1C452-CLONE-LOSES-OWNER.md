# #221 — the defect is `clone ()` losing `mt_base`, not `PASSES_EXTRA`

Measured at `3b9f7c8f695` (PRE) and `068ec8fb225` (POST), anchor **52** on
both, two cold 47-back-end builds from immutable snapshots, `make all-gcc`
rc=0 and 0 `error:` on both, `cc1` links on both.

## The brief's diagnosis is stale, and the finding it cites postdates the fix

The brief and `A7EE6CA7C923E4A58-AVR-PASS.md` both say the cause is
`PASSES_EXTRA` "collected once for the legacy single `${target}`", the same
shape as `extra_headers`. **That channel is already fixed on this tree.**
`b349257c0a2` (2026-08-14) replaced it with `MT_PASSES_DEFS`, accumulated from
the back-end list, and `gcc/Makefile.in:4443` keeps the legacy variable alive
purely as a cross-check that errors if it names a file the derived list lacks.
`config/avr/t-avr:41` says `PASSES_EXTRA +=` like the other fourteen, so avr's
passes.def IS collected, and each inserted pass IS renamed `<pass>_mt_<base>`
and given an owner.

The AVR finding is dated 2026-08-16, i.e. **after** that fix. So the crash it
reports is real and its explanation is not: it inherited a diagnosis from a
defect that had already been repaired, which is why "fix the collection" was
the wrong instruction. Fixing the collection again would have changed nothing.

## What actually happens

`pass_manager`'s `NEXT_PASS` macro (`passes.cc`) builds instance 1 from the
generated forwarder and instances 2..N from `clone ()`:

```c
if ((NUM) == 1)  m_##PASS##_1 = make_##PASS (m_ctxt);        /* forwarder */
else             m_##PASS##_##NUM = m_##PASS##_1->clone ();  /* raw factory */
```

Only the forwarder sets `p->mt_base`. Every `clone ()` override calls its back
end's **raw** factory —

```c
opt_pass *clone () final override { return make_avr_pass_fuse_add (m_ctxt); }
```

— so instance 2 comes out with `mt_base == NULL`, and
`pass_owner_selected_p ()` reads NULL as *"target-independent, always runs"*.
**The value meaning "no owner" is also the value a lost tag produces**, so the
failure is silent and in the permissive direction.

Population: every back end that inserts one of its own passes more than once.
`agent-aa44b9d995bd1c452-multiinstance.sh` scores it — three, over 47 bases:

```
aarch64   2 instances   pass_ldp_fusion
avr       2 instances   avr_pass_fuse_add
i386      2 instances   pass_stv
```

## Only one of the three ACTED — measured, and it corrects my own first write-up

`-fdump-passes`, which distinguishes ABSENT from OFF where a generated file
cannot. Compiling for **x86_64** and for **mips64**, PRE:

```
rtl-stv1 / rtl-stv2          ON for x86_64, OFF for mips64   (i386 owns them)
rtl-ldp_fusion1 / _fusion2   OFF for both
rtl-avr-fuse-add1            OFF        <- instance 1, owner works
rtl-avr-fuse-add2            ON         <- the unowned clone
```

POST: `rtl-avr-fuse-add2` **OFF** for both, and x86_64's own `stv1`/`stv2`
still **ON** — the fix removes the foreign pass without disabling owned ones.

Control, so those OFF readings are not vacuous: compiling for **aarch64**,
`ldp_fusion1` and `ldp_fusion2` both read **ON**.

I first inferred from `aarch64.opt`'s `Init (1)` on
`flag_aarch64_late_ldp_fusion` that ldp_fusion must be running for every back
end, and wrote that into a commit message. **The dump refutes it.** `pass_stv`
and `pass_ldp_fusion` are kept out of trouble by their own gates reading
option state a foreign base leaves 0 — precisely the leaked-PRESENCE story
`b349257c0a2` already tells. Recorded rather than quietly dropped.

`avr_pass_fuse_add` is the one that acts because it has **no gate at all**,
and its `execute ()` writes before its guard:

```c
func->machine->n_avr_fuse_add_executed += 1;   // unconditional
if (optimize && avropt_fuse_add > 0)           // too late
```

## THE 8 "OK" BACK ENDS: one of them was silently miscompiling

The census reads 3 LOUD / 8 UNVERIFIED and the 8 are an upper bound on
"unaffected". Settled both-sided —
`agent-aa44b9d995bd1c452-bothsided.sh`, every target with a specs-config, at
`-O0` and at `-O2`, PRE vs POST, **specs-configs byte-identical between the
two builds** so the only variable is the compiler:

```
compared=22  identical=13  changed=2  fixed=6  skipped=0
```

| target | verdict |
|---|---|
| microblaze, rx, sh | **FIXED** — ICE at both arms in PRE, rc=0 in POST |
| **mips64** | **CHANGED at BOTH arms — wrong code before this fix** |
| aarch64, arm, or1k, riscv64, s390x, x86_64 | byte-identical, both arms |
| avr | `-O0` identical; `-O2` fails **identically** in PRE and POST for an unrelated, pre-existing reason (below) |

### mips64, and the offset arithmetic closes

```
-  .frame $fp,8,$31    # vars= 4294967296, regs= 1/0, args= 0, gp= 0
+  .frame $fp,8,$31    # vars= 0,          regs= 1/0, args= 0, gp= 0
```

4294967296 is exactly 2^32. avr's `int n_avr_fuse_add_executed` sits at offset
**36** of avr's `machine_function`; mips' `frame.var_size` (`HOST_WIDE_INT`)
occupies bytes **32..39**, so offset 36 is its **high half** on this
little-endian 64-bit host and `+= 1` there adds 2^32. Predicted offset and
observed magnitude agree independently.

Same at `-O2`, on two functions. mips64 is one of the eight the census scored
**OK**.

### What the 13 IDENTICAL rows do and do not license

They say: *no observable difference on these two inputs, at these two
optimisation levels.* They do **not** say "unaffected in general" — the write
still landed in those back ends' `machine_function` before this fix, and
whether the corrupted member is observable depends on the input. This is a
stronger upper bound than the census's "compiled cleanly", and it is still an
upper bound. Stated as such deliberately.

## Bars

Every figure with the command that produced it, and with its build dir.

```
make all-gcc, 47 bases, cold, from immutable snapshot
  PRE  /tmp/b-aa44b9d995bd1c452-PRE    rc=0   0 error:   cc1 links (231026528 b)
  POST /tmp/b-aa44b9d995bd1c452-POST   rc=0   0 error:   cc1 links (231030624 b)

mt-bars.sh, in=<snap>/scratchpad/big.c
  cc1 -quiet -nostdinc -O2 -ftarget-config=<cfg> big.c -o x.s
  PRE   12369 bytes  md5 378fc33c1e70      <- the recorded bar, matched
  POST  12369 bytes  md5 378fc33c1e70      <- BOTH-SIDED: byte-identical

specs-config x86_64-pc-linux-gnu
  wc -l 232   grep -c . 224   md5 ce3e57e29397   (PRE and POST identical)

mt-bars.sh -g arm  (md5 is PATH-sensitive; quoted with its build dir)
  PRE   /tmp/b-aa44b9d995bd1c452-PRE    rc=0  78552 bytes  md5 324b64668ea1
  POST  /tmp/b-aa44b9d995bd1c452-POST   rc=0  78554 bytes  md5 12c2fd6b5fdc
  both with real .debug sections (mt-bars.sh's own non-vacuity arm)
```

**The specs-config md5 is NOT the brief's `cfbc7a65e54e`.** The line count
matches (232) and both builds agree, and all 11 targets have distinct md5s
(no host-`as` fallback signature). The difference is that these specs were
probed against cross binutils **2.46** materialised into
`/tmp/tools-aa44b9d995bd1c452`, whose paths land in the file. A specs-config
md5 is a function of the probing toolchain and its paths, so it should be
quoted with them — same family as the `-g` arm. `cfbc7a65e54e` is not
reproducible without the tools dir it was taken with.

### The `-g` difference is the path, and `gcheck` says "real" anyway

`a5764a65f9eec0063-gcheck.sh` reports **`DIFFERENT -- the change is real`**.
It is not. Its own printed diff is one string:

```
"GNU C23 ... -ftarget-config=/tmp/b-aa44b9d995bd1c452-PRE/lib/.../specs-config"
"GNU C23 ... -ftarget-config=/tmp/b-aa44b9d995bd1c452-POST/lib/.../specs-config"
```

plus the `.LASF` renumbering that one-character length change causes. Normalise
the build-dir path and drop the `.LASF` labels and the two outputs are
**identical**.

**`gcheck` controls for the SOURCE path and not for the `-ftarget-config`
path**, and the specs-config lives in the build dir, so it lands in
`DW_AT_producer` too. The script's header reasons carefully about
`DW_AT_name`/`DW_AT_comp_dir` and stops there. As written it will report a
false "real change" for any two build dirs whose names differ in length —
which is every PRE/POST pair. Worth fixing in that script; not done here
because a run of it may be in flight in another worktree.

## Anchor

**52 before and after, and it did not move.** `grep -c MULTI_TARGET
gcc/Makefile.in` counts one file, and this change is entirely in
`gcc/passes.cc`; no rule, no comment and no citation in `gcc/Makefile.in` was
touched. Both snapshots read 52. The content arm that *does* move is
`grep -c mt_clone_pass gcc/passes.cc` = **3** (one definition, two call sites)
in POST and **0** in PRE.

## Unrelated wall met on the way, reported not fixed

avr at `-O2` fails **identically in PRE and POST**:

```
during RTL pass: sched1
internal compiler error: back end 'avr' has no pipeline automaton, but shared
scheduling code compiled for a primary that has one is asking it for pipeline
hazards
```

That is a fail-by-name abort doing its job (the DFA-absent case PRINCIPLES
lists as unmeasurable with two back ends). Out of scope for #221 and untouched
by it.

## Cross assemblers: a recorded EVAL-FAIL set was a spelling problem

`INSTRUMENTS.md` lists `arm-eabi` and others as failing to evaluate, and
pass 1 (`a7ee6ca7c923e4a58-astry.sh`) gave EVAL-FAIL for 8 of the 11 census
targets. `agent-aa44b9d995bd1c452-astry3.sh` — astry2's idea, but keyed on the
**canonical** `MT_TARGET_SUBDIRS` spelling the specs rule actually looks for,
rather than the short `backends-47.txt` spelling — recovers **all 8**:

```
microblaze-xilinx-elf  <- microblaze-none-elf                 rx-unknown-elf  <- rx-none-elf
sh-unknown-elf         <- sh4-elf                             arm-unknown-eabi <- arm-none-eabi
avr-unknown-elf        <- avr-none                            mips64-unknown-elf <- mips64-unknown-linux-gnuabi64
or1k-unknown-elf       <- or1k-none-elf                       s390x-ibm-linux-gnu <- s390x-unknown-linux-gnu
```

11 of 11 with a real cross `as` 2.46, so all 11 specs-configs are probed
rather than defaulted, and none is the host-`as` fallback. astry2 installs
`$OUT/bin/<short>-as`, which **no build rule looks for** — the tools are
present and the rule still reports "cannot find `sh-unknown-elf-as`". One
name, several authorities, inside the tooling.
