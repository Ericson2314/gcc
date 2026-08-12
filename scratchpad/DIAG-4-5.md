# DIAG 4 and 5 -- diagnosis only, NOTHING COMMITTED, NOTHING STAGED

Private tree `/tmp/mt-diag-src` (git worktree, detached at `2fe6d3b47d5`,
`selector-wip.patch` applied + the two untracked selector files copied in).
Private build dir `/tmp/b-diag`.  `/tmp/b-objs` was read with `nm`/`objdump`
only and never written.  The user's tree at
`/home/jcericson/src/gnu/gcc/multi-target` was not touched at all.

Reproduced the brief's premise first: `make -j12 all-gcc` in `/tmp/b-diag`
links a `cc1` of 603,463,752 bytes holding both back ends --

    42289 symbols matching `aarch64'          (single-target baseline 0)
    37405 symbols in `insn_aarch64::'
    raw_optab_handler, insn_i386::raw_optab_handler,
    insn_aarch64::raw_optab_handler  -- all three present

-- and the only failure in the whole build is the known pre-existing
`target-specs`/`check-target-caps` FATAL at the very end.  See
"Cold-build defects in the WIP patch" at the bottom: the patch does NOT
build from a cold directory, and that cost most of the session.

---

# DEFECT 4 -- the mechanism is CONFIRMED; the named suspect is NOT the cause

## Short version

  * The hazard class is real and is now proven at the object level, not
    argued: **COMDAT inlines with the same mangled name and different
    bodies**, kept one-of-N by the linker.
  * **`optab_handler` is genuinely one of them** -- three distinct bodies,
    all `W`, all named `_Z13optab_handler...`.
  * **But `optab_handler` is NOT what breaks the primary.**  In the `cc1`
    that actually links, the surviving copy calls the *global*
    `raw_optab_handler`, i.e. the primary's own table, so the primary is
    served correctly by it.  The prime suspect is REFUTED as the cause of
    the primary's failure, while being CONFIRMED as a member of the class.
  * The primary's first failure is a **different member of the same
    class**: `get_cumulative_args` / `pack_cumulative_args` in `target.h`,
    via `CUMULATIVE_ARGS_MAGIC`.  Traced end to end, in the linked binary,
    to the exact compared constants.
  * The general sweep (task #52) is built and run.  Of **2639** candidate
    COMDAT names, **8** have genuinely differing bodies, of which **4** are
    real per-back-end hazards.

## What `optab_handler` actually is -- confirmed, with the numbers

`optabs-query.h` defines `optab_handler`, `convert_optab_handler` and
`direct_optab_handler` as plain `inline` functions at **global** scope.
Each calls `raw_optab_handler`, which `genopinit.cc` emits as an
**out-of-line, namespaced** function inside `namespace insn_<base>`
(`print_ns_open` at genopinit.cc:322, definition at :502).  So the callee
that `optab_handler`'s body names depends on which `insn-opinit-*.h` the
translation unit included, while the caller's own mangled name does not
change.  Same symbol, three bodies:

    nm -C, over the object sets in /tmp/b-objs  (HEAD, not even the patch)

    expr.o                     W optab_handler(...)   U raw_optab_handler
    mt-i386/i386.o             W optab_handler(...)   U insn_i386::raw_optab_handler
    mt-aarch64/aarch64.o       W optab_handler(...)   U insn_aarch64::raw_optab_handler

`W`, not `T D B R` -- which is exactly why five sessions of strong-symbol
sweeps could not see it.

### Symmetric proof that the linker picks one arbitrarily

`ld -r` over two objects, both orders, `objdump -dr` on the result
(`/tmp/cmdt/A.dis`, `B.dis`).  Exactly **one** definition of
`optab_handler` survives in each arm (`grep -c` = 1), and its callee flips
with the order:

    expr.o    then aarch64.o  ->  call raw_optab_handler              (i386 table)
    aarch64.o then expr.o     ->  call insn_aarch64::raw_optab_handler (aarch64 table)

Whichever wins, the other two thirds of the call sites in the program are
silently reading the wrong optab table.  That is the mechanism, measured.

### ...and in the real `cc1`, the primary wins

    nm -C cc1 | grep optab_handler
      0000000001b56890 W optab_handler(optab_tag, machine_mode)   <- one copy
      (plus 5 file-local `.part.0' clones, which are per-TU and harmless)

    objdump -d --start-address=0x1b56890
      1b5689c: jmp 3124b00 <raw_optab_handler(unsigned int)>

The surviving body calls the **global** `raw_optab_handler`.  So:

  * the middle end and the i386 back end get i386 icodes -- CORRECT;
  * **the aarch64 back end gets i386 icodes** -- a real latent wrong-code
    bug, but one that cannot fire yet because aarch64 dies in defect 5
    before any RTL exists.

**Therefore the previous session's leading hypothesis for the primary's ICE
is refuted.**  It was a plausible story that happened not to be true, which
is the failure mode the brief warned about.  It remains a must-fix.

Caveat stated plainly: I did **not** reproduce the previously reported
`maybe_gen_insn, at optabs.cc:8594`.  My build of the same patch fails
earlier, below, so `maybe_gen_insn` may still be waiting behind it.  I have
not shown it is gone -- only that `optab_handler` is not routing the
primary to the wrong table in this binary.

## What DOES break the primary: `CUMULATIVE_ARGS_MAGIC`

    ./cc1 -quiet -nostdinc -O1 -ftarget-config=specs-x86_64-pc-linux-gnu-config
    int f(int *p, int i) { return p[i]; }
    -> internal compiler error: in get_cumulative_args, at target.h:400
       get_cumulative_args -> ix86_pass_by_reference -> pass_by_reference
       -> apply_pass_by_reference_rules -> assign_parm_find_data_types

`target.h`:

    #define CUMULATIVE_ARGS_MAGIC ((void *) &targetm.calls)
    inline CUMULATIVE_ARGS *get_cumulative_args (cumulative_args_t arg)
    { gcc_assert (arg.magic == CUMULATIVE_ARGS_MAGIC); ... }

The magic is an **address used as an identity token**, and `targetm` is
renamed per back end by the patch (`-Dtargetm=targetm_<base>`,
`MULTI_TARGET_RENAME_NAMES`), while the singular `targetm` that the middle
end sees is a **separate object that `multi-target-select.cc` copies the
selected back end's `targetm` into** (`multi-target-select.cc:118`
`struct gcc_target targetm;` and `:252` `::targetm = targetm_ ## BASE;`).
A copy has the same contents and a different address, so the token minted
by the middle end can never equal the token checked by a back end.

The selector already knows the copy is exceptional -- its own comment at
`:243` says "targetm is a COPY, and it is the one thing here that is" --
but the consequence it anticipated was *mutation* (a back end's
`TARGET_OPTION_OVERRIDE` writing through `targetm.`), not *address
identity*.  The identity consequence is the one that fires.

Measured in the linked `cc1`, not inferred:

    nm:       targetm         B  0x4b64220     offsetof(gcc_target,calls) = 0xb60
              targetm_i386    D  0x4b09880
              targetm_aarch64 D  0x4b0eb00

    assign_parm_find_data_types (function.cc, middle end), packing side:
      14fff53:  mov  $0x4b64d80,%eax          = &targetm.calls
      14fff62:  call apply_pass_by_reference_rules

    ix86_pass_by_reference (i386.cc), checking side:
       f34fe4:  cmp  $0x4b0a3e0,%rdi          = &targetm_i386.calls   -> MISMATCH

    aarch64_pass_by_reference, checking side:
      10105fb:  cmp  $0x4b0f660,%rdi          = &targetm_aarch64.calls

Three magics, one token.  Note this one is not even a COMDAT *dedup*
problem -- both bodies survived, inlined into their own callers.  It is the
same root pattern one level up: **one name, several authorities**, where
the "name" is an address and the authorities are `targetm`,
`targetm_i386`, `targetm_aarch64`.

### Scope of it, measured rather than assumed

    int g(void)      { return 1; }        -> rc=0, correct x86: `movl $1,%eax; ret'
    int h(int a)     { return a + 1; }    -> ICE
    int f(int*p,int i){ return p[i]; }    -> ICE

**Any function with a parameter** ICEs, because the packing site is
`assign_parm_find_data_types`.  A function with none compiles correctly.

That is a discrepancy with the previous session's report, and I am not
papering over it: they observed `f1`/`f2` emitting correct x86 for functions
that plainly took parameters (`leal 1(%rdi),%eax`), and an ICE only at
`maybe_gen_insn`.  My build of `selector-wip.patch` at `2fe6d3b47d5`, plus
the two scratchpad selector files, cannot compile `int h(int a)` at all.
So **their tree was not exactly what the patch file reproduces** -- most
likely it carried further uncommitted work than the patch captures.  I
cannot reconcile the two without their binary, and I would not trust a
reconciliation I invented.  What I can say is that `maybe_gen_insn` is not
disproven -- it may simply be behind this.

It is guarded by `#if CHECKING_P`.  A `--disable-checking` build would pass
silently, and the subsequent pointer cast is harmless, so this is a false
ICE rather than wrong code.  That makes it *cheap to fix* and also means it
was masking whatever comes next.

### Confirming experiment

One line, in my private tree only:

    -#define CUMULATIVE_ARGS_MAGIC ((void *) &targetm.calls)
    +#define CUMULATIVE_ARGS_MAGIC ((void *) (size_t) 0x4d41474943ULL)

Full rebuild, relink.  **Marker asserted present in the compiled binary**
before believing anything -- `objdump -d` over `ix86_pass_by_reference`
finds `0x4d41474943`, so the probe took and is not a stale object:

    objdump -d --start-address=0xf34f00 --stop-address=0xf35100 cc1 |
      grep -c 4d41474943   ->  1

Then, primary, `-ftarget-config=specs-x86_64-pc-linux-gnu-config`:

    int g(void)              -> rc=0, stderr empty   (was rc=0)
    int h(int a)             -> rc=0, stderr empty   (was ICE)
    int f(int*p,int i){p[i];}-> rc=0, stderr empty   (was ICE)   <- the brief's reproducer
    /tmp/acc/t.c, 6 functions, -O0 -O1 -O2 -O3
                             -> rc=0, stderr empty at all four   (was ICE)

and the emitted code is right, not merely produced:

    f:  movslq %esi,%rsi ; movl (%rdi,%rsi,4),%eax ; ret

**`maybe_gen_insn` does not reappear.**  The one-line change is sufficient
to make the primary work in a `cc1` that contains both back ends.

### ...and the byte-identical-asm arm now PASSES for the primary

This is the acceptance arm the previous session correctly refused to run,
on the grounds that its left-hand side could not be produced.  It can be
produced now.  Reference: the unpatched HEAD `cc1` from `/tmp/b-objs`
(copied to `/tmp/cmdt/cc1-ref`, 93,174,656 bytes, against the patched
603,463,752-byte two-back-end one), same six-function input, same flags:

    -O0  BYTE-IDENTICAL   204 lines
    -O1  BYTE-IDENTICAL   134 lines
    -O2  BYTE-IDENTICAL   149 lines   (127 instruction lines -- not vacuous)
    -O3  BYTE-IDENTICAL   149 lines

The four outputs are not all the same file (134 vs 149 vs 204 lines), and
the two compilers are plainly different binaries, so this is not a
comparison of something with itself.

Note this holds **despite** the patch raising `NUM_POLY_INT_COEFFS` from 1
to 2 for the primary, which blocker 2 flagged as wanting its own asm-identity
arm.  That arm is hereby run, for the primary, and it passes.

**The primary is no longer a blocker.  aarch64 -- defect 5 -- is the only
remaining gate, and it still fails identically after this fix** (verified:
same `xstrdup`/`aarch_validate_mbranch_protection` segfault, unchanged).

## The general sweep -- task #52, built and run

`/tmp/cmdt/comdat-sweep4.py` (and the narrower `comdat-sweep.py`).  `nm -C`
for classes `W V u` over three object sets -- the middle end's 635 objects,
`mt-i386`'s 11, `mt-aarch64`'s 21 -- then, for every name defined in the
middle end and in at least one back end, a **content comparison of the
actual bodies**: `objdump -dr`, keeping the relocation targets that name
global symbols.  It does not guess what "different body" means.

Guards, given thirteen false greens on this project: it exits non-zero on an
empty object set, on a set with no `W/V/u` definitions at all, and if it
would report `0` without having compared anything.

    middle-end   635 objects,  38354 distinct W/V/u definitions
    i386          11 objects,   1181
    aarch64       21 objects,   4362

    candidates (W/V/u in the middle end and >=1 back end):  2639
    compared with >=2 disassemblable copies:                1822
    bodies that genuinely DIFFER:                              8

The 8, classified by what the relocation sets actually differ in
(`/tmp/cmdt/classify8.py`):

    REAL -- per-back-end table:
      optab_handler(optab, machine_mode)
          raw_optab_handler | insn_i386::raw_optab_handler | insn_aarch64::raw_optab_handler
      convert_optab_handler(optab, machine_mode, machine_mode)
          raw_optab_handler | insn_aarch64::raw_optab_handler
      get_cumulative_args(cumulative_args_t)          <- the one that fires
          targetm | targetm_aarch64      (and targetm_i386 once the patch's rename applies)
      estimated_poly_value(poly_int<2u,long>, poly_value_estimate_kind)
          targetm | targetm_aarch64

    MARGINAL -- codegen, not semantics:
      create_address_operand(expand_operand*, rtx_def*)
          middle-end copy reads global_options, aarch64's optimised the test away

    BENIGN -- C++ template/library instantiations, no per-back-end name:
      format_helper::format_helper<scalar_float_mode>(...)
      hash_table<hash_map<char*, json::value*, ...>>::...
      void std::__cxx11::basic_string<...>::_M_construct<...>(...)

**So `optab_handler` is one of four, not one of many.**

I checked whether `direct_optab_handler` is a fifth, since it is in the same
header -- it is **not**.  Its body is a bare tail call to `optab_handler`,
identical in both object sets (`objdump -dr`: one relocation,
`R_X86_64_PLT32 optab_handler`, in `expr.o` and in
`mt-aarch64/aarch64-acle-builtins.o` alike).  It inherits the hazard rather
than adding one, and is fixed by fixing `optab_handler`.

Two honest limits on the instrument:

  1. It is a **relocation-target** comparison.  A body that differs only by
     an inlined per-back-end *integer constant* (a mode number,
     `MAX_RECOG_OPERANDS`) has no relocation to differ in and would be
     missed.  The raw-instruction-byte variant catches those, but it also
     catches register allocation and `__FILE__/__LINE__` differences in
     `gcc_assert`, and reports 362 -- an upper bound with a high false
     positive rate, not a count.  Both numbers are in
     `/tmp/cmdt/sweep2.out` and `sweep4.out`.
  2. It swept the **HEAD** object sets in `/tmp/b-objs`, where the patch's
     `-Dtargetm=targetm_<base>` rename is not yet applied.  That makes it
     *under*-report: with the patch, the i386 copies diverge too.
  3. `test_register_filters` in `tm-preds.h`, the brief's other known-bare
     name, did not appear, and I checked why rather than assuming.  It is
     `W` in exactly **one** object in the whole build --
     `mt-aarch64/aarch64-early-ra.o` -- and it does not appear in the linked
     `cc1` at all (fully inlined).  So it is **not a live hazard in this
     two-target configuration**: only one configured back end emits it.  It
     is still bare and unnamespaced, and it collides the moment a second
     back end that uses register filters is configured.  A sweep over
     object sets cannot see a hazard that needs a third target to exist --
     that is a real limit of every instrument this project has built,
     including this one.

## The fix, and what it costs

**Do not reach for namespacing first.**  These are middle-end header
inlines, and for anything the middle end calls by name, namespacing turns a
link error into a wrong answer -- the `gen_blockage` / `get_attr_length`
escape-list reasoning applies with full force here.  The three cases want
three different fixes:

  1. **`CUMULATIVE_ARGS_MAGIC` -- fix this one first, it is nearly free.**
     Stop using an address as an identity token.  Any back-end-independent
     constant works (`((void *) (size_t) 0x4d41474943ULL)`), because the
     token's only job is to catch a raw `CUMULATIVE_ARGS *` being packed by
     the wrong route -- it never needed to identify *which* target.
     One line in `target.h`.  It weakens the check slightly (it no longer
     distinguishes targets, only packed-vs-unpacked), which in a
     multi-target compiler it cannot do anyway.  Cost: a full rebuild,
     nothing else.  This is upstream-shaped and separable, like blocker 3.

  2. **`optab_handler` and `convert_optab_handler`** (and `direct_optab_handler`
     for free, since it only tail-calls `optab_handler`).
     The body must stop being fixed at compile time.  The cheapest correct
     shape is the one `genopinit` already has for the tables: make
     `raw_optab_handler` a **selected function pointer** that
     `multi_target_select` assigns from the chosen base, and leave the
     three inlines calling it by that one name.  Then all three bodies are
     identical again and COMDAT dedup is harmless -- which is the real
     goal, not moving the collision somewhere else.  Cost: one indirect
     call on a hot path (`optab_handler` is called constantly), and a
     `genopinit.cc` change.  Namespacing the inlines instead would require
     every middle-end caller to name a base, which is thousands of call
     sites and is the wrong answer.

  3. **`estimated_poly_value`.**  Falls out of `targetm` selection and
     needs nothing of its own once `targetm` is a real selection rather
     than a copy -- see below.

**The `targetm`-copy shape is worth reconsidering on its own.**  Copying
the selected back end's `targetm` into a separate singular object is what
made the magic mismatch possible, and it will make every other
address-of-`targetm` comparison wrong too.  Making the singular `targetm` a
*reference/pointer* to the selected `targetm_<base>`, rather than a copy of
it, removes this whole sub-family at the root.  That is a bigger change --
`targetm.` is spelled as a member access in thousands of places -- so it is
a decision to take deliberately, not a drive-by.

---

# DEFECT 5 -- `global_options` / `struct gcc_options`

## Reproduced

    ./cc1 -quiet -nostdinc -O0 -ftarget-config=specs-aarch64-unknown-linux-gnu-config
    int g(void){return 1;}
    -> Segmentation fault
       xstrdup / aarch_validate_mbranch_protection (aarch-common.cc:693)
       aarch64_override_options (aarch64.cc:20437) / process_options (toplev.cc:1302)

Disassembly of `aarch64_override_options` in the linked `cc1`:

    1004010:  mov 0x3df54b1(%rip),%rsi   # global_options+0x19e8
    100402b:  mov 0x3df54a6(%rip),%rdi   # global_options+0x19f8

`nm -S` says the single `global_options` in the binary is **0x1c48 = 7240
bytes**, so `+0x19e8` is *in bounds*.  Nothing traps; it loads an
`int`-or-pointer sized i386 field, treats it as `const char *`, and
`xstrdup`s it.  There is no diagnostic available for this shape -- the
read is valid, only the meaning is wrong.

## The layout divergence, measured

Per-base `options-<base>.h` **already exist** (`options-i386.h`,
`options-aarch64.h` in the build dir; they are on the `MULTI_TARGET_INC_STEMS`
list).  Only the singular `options.h` -- which is byte-identical to
`options-i386.h` in the `struct gcc_options` body -- reaches the middle end.
So the divergence can be measured directly, and it is total:

    struct gcc_options members       i386  1709      aarch64  1861
    identical leading run of names          0        (of 1709)
      i386[0]    = x_ix86_stack_protector_guard_offset
      aarch64[0] = x_selected_arch

    shared member names                    1593
      ...of which the declared TYPE differs:  0
    i386-only members                       116   (42 x_VAR_, 74 typed)
    aarch64-only members                    268   (208 x_VAR_, 60 typed)

    union of both                          1977 members
      = +268 over i386 (+15.7%), +116 over aarch64 (+6.2%)

**Not one field offset is shared** -- the very first member already differs
-- so nothing in this family can accidentally work today, and no partial
fix can be half-right in a way that hides.

I did **not** resolve which i386 member sits at `+0x19e8`.  The multi-target
objects are built without `-g` so there is no DWARF for either layout, and a
hand-rolled C layout model computed `sizeof` = 7216 against the linker's
actual 7240 -- 24 bytes out, so its per-field answer is not trustworthy and
is not reported.  It does not change the sizing.

## What is already built, and what is missing

This matters for sizing, because half the machinery exists:

  * `optionlist-vocab` + `opt-stub.awk` (Makefile.in ~3404) already union
    the option-name **vocabulary** across every configured back end, so
    `enum opt_code` ordinals and the `cl_options[]` indices already agree
    between bases.  That was the harder half.
  * The stubbing already injects a good deal of the other base's `Var()`
    storage: 208 of aarch64's 268 exclusive members and 42 of i386's 116
    are `x_VAR_*`.
  * What is missing is the `struct gcc_options` **member list and its
    order**, plus a per-base `options.cc` / `options-save.cc` / `cl_options`
    and any selection at all.  `options.cc`, `options-save.cc` and
    `options-urls.cc` are singular today -- the primary's.

## Shape of a fix, sized.  NOT IMPLEMENTED

**Option A -- union the struct (recommended).**  Make `opth-gen.awk` emit
the members for the *union* vocabulary in a *base-independent order*, so
every base's `gcc_options` has identical layout and the singular
`global_options` is simply correct for all of them.  This is the same move
already made for `insn-config.h` (`326a155008a`) and the mode numbering,
and it reuses `optionlist-vocab` which exists.

  * Cost, measured: +268 members / +15.7% on the primary's struct; roughly
    +600 bytes per `gcc_options`, and there are several
    (`global_options`, `global_options_set`, `global_options_init`, plus
    every `cl_optimization`/`cl_target_option` save/restore buffer).
  * The real work is the **134 typed target members** (74 i386-only, 60
    aarch64-only) -- `enum aarch64_arch`, `enum aarch64_code_model`,
    `uint64_t x_aarch64_asm_isa_flags_0`, ... .  A single struct
    declaration needs all of those types visible at once, which means the
    per-base `<cpu>-opts.h` enums have to be includable together.  Name
    collisions between two back ends' option enums are the risk to check
    first; there are none today between i386 and aarch64 (0 shared member
    names with differing types), but that is a two-target sample.
  * `options-save.cc` and `cl_options[]` follow the same union and stay
    singular, which is a saving: no selector needed for them.

**Option B -- per-base struct plus a selector.**  Generate
`gcc_options_<base>` and have the middle end reach it through a selected
pointer.  Rejected on sizing: `global_options.x_flag_*` is spelled as a
direct member access in the middle end in the low thousands of places, and
every one of them would have to become base-agnostic.  It also does not
compose with `cl_optimization_save`/`restore`, which serialise the struct
by layout.  Strictly more work than A for a smaller struct.

**Option C -- leave the struct alone, select only the target fields.**
Not viable: the divergence starts at member 0, so "only the target fields"
is not a suffix that can be isolated -- the two layouts interleave target
and common members throughout.

**Recommendation: Option A**, and note that it is a *prerequisite* for the
byte-identical-asm arm on aarch64, and independent of defect 4.  Defect 4's
`CUMULATIVE_ARGS_MAGIC` one-liner should land first because it is a
one-line upstream-shaped fix that unblocks the primary, and it does not
interact with this at all.

---

# Cold-build defects in the WIP patch -- found the hard way, worth recording

`selector-wip.patch` **does not build from a cold directory.**  It built for
the previous session because that build dir already contained files that
the patch's dependency graph does not know how to create.  Three failures,
each of which reads as an unrelated source bug:

  1. **`insn-constants.h` bootstrap cycle.**  `make` prints
     `Circular build/rtl.o <- insn-constants.h dependency dropped`, drops
     the edge, and `build/genconstants.o` then fails with
     `./tm.h:41:11: fatal error: insn-constants.h: No such file or directory`.
     Only survivable if the file already exists.
  2. **`insn-config-<base>.h` bootstrap cycle.**  `tm-preds-aarch64.h:246`
     includes `insn-config-aarch64.h`, which is generated by a run that
     needs `gencondmd-<base>`, which needs `tm-preds-aarch64.h`.  Same
     shape, same "only works warm".
  3. **`build/gensupport.o` acquired `-DGEN_HDR_SUFFIX='"-aarch64"'` under
     `-j12`**, so the *singular* `build/genpreds` generated a `tm-constrs.h`
     from `i386.md` that opens `namespace insn_aarch64`.  The visible
     symptom was 58 x `'satisfies_constraint_BF' was not declared in this
     scope` in `insn-preds.o` -- which reads exactly like a broken
     `predicates.md`.  Deleting `build/gensupport.o build/genpreds.o
     build/genpreds` and rebuilding serially produced the correct file.
     This one is a **wrong-output race, not a build failure**, and it is
     the dangerous one: it can produce a compiler rather than an error.

I worked around all three by hand (seeding the two headers from
`/tmp/b-objs`, then a serial regeneration).  None is diagnosed to root
cause; they are recorded because the next person to build this cold will
lose the same hours, and because (3) can silently mis-generate.

# Artefacts

    /tmp/mt-diag-src              private worktree, patch applied  (detached, no commits)
    /tmp/b-diag                   private build dir, cc1 links
    /tmp/cmdt/cc1-magicbug        the cc1 that reproduces both defects
    /tmp/cmdt/comdat-sweep.py     narrow sweep: W/V/u + per-back-end reloc regex (6 hits)
    /tmp/cmdt/comdat-sweep2.py    raw instruction-byte compare (362, upper bound + noise)
    /tmp/cmdt/comdat-sweep4.py    reloc-target compare, the reportable one (8)
    /tmp/cmdt/classify8.py        per-set relocation targets for the 8
    /tmp/cmdt/sweep*.out          the runs
    /tmp/cmdt/A.dis  B.dis        the symmetric ld -r link-order arms
    /tmp/cmdt/cc1.nm              nm -C of the linked cc1
    /tmp/cmdt/ice.err  a64.err    the two reproduced failures

---

# STATUS CORRECTION -- BOTH DEFECTS LANDED WHILE THIS WAS BEING WRITTEN

Everything above describes defects 4 and 5 as OPEN and proposes fixes.  That
is now stale.  The concurrently-working agent landed both.  `HEAD` moved from
`2fe6d3b47d5` to `642e63adc6c` during this session:

    8cd2e85cdf8  genmodes: put `NUM_POLY_INT_COEFFS' in the shared numbering
    27760d3947c  calls: take `cumulative_args_t' in the pass-by-reference predicates
    be32badfb60  target, optabs-query: stop minting per-back-end bodies in
                 shared header inlines                       <- DEFECT 4
    642e63adc6c  opth-gen: give `struct gcc_options' one layout shared by
                 every back end                              <- DEFECT 5

`be32badfb60` covers all four of the real hazards this diagnosis found, in
the shape recommended here: `CUMULATIVE_ARGS_MAGIC` becomes a fixed constant
(the same `0x4d41474943ULL`), `estimated_poly_value`'s hook call moves to
`estimated_poly_value_1` in targhooks.cc, and `optab_handler` /
`convert_optab_handler` go through one out-of-line
`selected_raw_optab_handler`, with `direct_optab_handler` free as a tail
call.  It also declines namespacing for the `gen_blockage`/`get_attr_length`
reason.  `642e63adc6c` is Option A.

**On attribution I am not going to guess.**  These commits match this
diagnosis closely, including the arbitrary probe constant, but whether that
is because the diagnosis was read or because two people converged is not
something I can establish from the filesystem, and this project has had
recall get "who did this" wrong three times.  The commits are what they are.

## WHAT IS STILL OWED, AND IS NOT DONE HERE

I did **not** verify either landed commit.  My build dir `/tmp/b-diag` is at
`2fe6d3b47d5` + `selector-wip.patch` + my one-line probe, which is *not* what
landed.  Concretely still unverified:

  1. **Re-run the COMDAT sweep against the new HEAD.**
     `scratchpad/comdat-sweep4.py` is the instrument; it should now report
     **0 real hazards** where it reported 4.  That is a cheap, specific arm
     and it is the only thing that shows `be32badfb60` actually closed the
     class rather than moving it.  Note the sweep needs a two-back-end
     object set to exist, so it must run after a `multi-target-objs` build.
  2. **Check the unioned `gcc_options` against the numbers measured here.**
     The union of i386 and aarch64 is **1977 members** (1593 shared + 116
     i386-only + 268 aarch64-only, with 0 type disagreements).  If
     `642e63adc6c`'s struct does not have 1977 members, either it is not a
     full union or the vocabulary changed -- and the difference is the
     interesting number.  Divergence started at member ZERO before, so the
     new layout must also be checked to be *ordered* base-independently,
     not merely to contain the right set.
  3. **aarch64 still has to actually emit code.**  Defect 5's segfault was
     the gate on the aarch64 asm arm; clearing the gate is not the same as
     passing the arm.  The primary's asm arm passes (measured above); the
     aarch64 one has still never been run.
  4. `test_register_filters` remains bare.  Not live in a two-target build;
     it collides the moment a second back end with register filters is
     configured.
  5. The three cold-build defects at the bottom of this file are **not**
     addressed by either commit, and (3), the `-j12` `GEN_HDR_SUFFIX` race,
     can silently mis-generate `tm-constrs.h`.
