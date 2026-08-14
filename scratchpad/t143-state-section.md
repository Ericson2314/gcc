
---

# #143 / #154 / #49 -- THREE "COMPILED ONCE AND SHARED" ITEMS, RE-MEASURED

Worktree `agent-ad1798a2b26398cc6`, anchor **48**, built from the immutable
snapshot `/tmp/snap-ad1798a2` (`8b126bdce7d`, `git diff --quiet` asserted).
Build dirs `/tmp/b-ad1798a2b26398cc6-48` (all 48 back ends, `make all-gcc`
**rc=2** stamped -- the pre-existing failing set) and
`/tmp/b-ad1798a2b26398cc6-rv` (i386 + aarch64 + riscv).

**Two of the three briefs' stated mechanisms are wrong, and in both cases the
real mechanism is either worse or already fixed.  Read the corrections, not the
premises.**

## 1. #49 -- THE CONVERSIONS ARE PRESENT, CORRECT, AND TWO OF THEM LAND TOO LATE

This is the only one of the three that produced a code change
(`6828710f385`).

`defaults.h:1550+` redirects **60** `HAVE_{AS,GAS,LD}_*` names to `targ_caps`
fields.  So a reader grepping for "was this converted?" finds every one of them
converted.  **That is not the whole question: WHEN the macro is read matters,
and `mkconfig.sh` appends `defaults.h` LAST.**

Three populations, measured by `scratchpad/t49-caps.sh` / `t49-defined.sh` /
`t49-shape.sh` on the source, then confirmed by `t49-preproc.sh` on the REAL
generated chains:

  * **108** `HAVE_{AS,GAS,LD}_*` names are still spelled in `gcc/`.
  * **3** can still be defined by any build -- `HAVE_AS_TLS`,
    `HAVE_AS_DTPREL_RELOC`, `HAVE_LD_RO_RW_SECTION_MIXING`, all from
    `auto-host.h`, i.e. **still probed from the BUILD machine's binutils and
    shared by all 48 back ends.**  These are unconverted, not mis-converted,
    and are the largest remaining item here.

    `HAVE_AS_TLS` is the big one: **59 uses across 19 back ends** (aarch64
    alpha arc arm frv i386 ia64 loongarch m68k microblaze mips or1k pa riscv
    rs6000 s390 sh sparc xtensa), `#define HAVE_AS_TLS 1` in this build's
    `auto-host.h` purely because the BUILD host's `as` has TLS.  It has **no
    `targ_caps` redirect at all**.  Converting it is harder than the ones
    already done, and in exactly the way section 1 is about: `defaults.h:127`
    is `#if defined (HAVE_AS_TLS) && !defined (ASM_OUTPUT_TLS_COMMON)`, gating
    a macro DEFINITION -- a preprocessor line, which no `targ_caps` field can
    satisfy.  Whoever takes it should expect the `mkconfig.sh`-prologue shape
    rather than the `defaults.h`-redirect shape, or a union.
  * **22** have a live preprocessor conditional.  The exactness arm
    (`t49-defined.sh`, written eager-to-revoke because it GRANTS a finding)
    struck **12** as legitimately redirected, leaving **10**.

`t49-shape.sh` then separated a dead `#ifndef X / #define X 0` floor (benign --
`defaults.h` `#undef`s and redirects afterwards, so value sites read the runtime
field; `mips.h:250` is this shape and its comment says so) from a live `#ifdef`
guard.

### THE DEFECT, MEASURED ON THE REAL CHAIN

`cpp -dM -DIN_GCC` on the generated `tm-rs6000.h`, in the 48-back-end build:

    #define TARGET_CMODEL RS6000_CMODEL_SMALL        <- the #else branch
    #define SET_CMODEL(opt) do {} while (0)          <- the #else branch
    #define DOT_SYMBOLS 1                            <- the #else branch
    #define HAVE_LD_LARGE_TOC (targ_caps.ld_large_toc)
    #define HAVE_LD_NO_DOT_SYMS (targ_caps.ld_no_dot_syms)

The last two lines are the trap.  The redirect **is** there, and it arrived
after `config/rs6000/linux64.h:66` had already taken `#ifdef HAVE_LD_LARGE_TOC`
the other way.  Consequence on powerpc64: **`-mcmodel=` is silently a no-op**
(`SET_CMODEL` discards its argument), `TARGET_CMODEL` is frozen at
`RS6000_CMODEL_SMALL`, and `rs6000_current_cmodel` -- a real option variable,
`global_options.x_rs6000_current_cmodel` -- is neither written nor read.
`DOT_SYMBOLS` likewise loses the ELFv2 local entry-point form.

**Exactly the "correct by luck on i386 + aarch64" class.**  `tm-i386.h`
contains **zero** occurrences of either macro, and aarch64 none, so the
configured pair cannot express it.  It took preprocessing a third back end that
has the guard.

The fix extends the `mkconfig.sh` prologue that already carries four such names
(`HAVE_LD_EH_FRAME_HDR`, `_AS_NEEDED`, `_PIE`, `_PUSHPOPSTATE_SUPPORT` -- found
the same way, by an earlier agent whose comment predicted the rest of the
population).  **The runtime redirect survives**, measured unchanged on both
sides, exactly as `HAVE_LD_PIE`'s already does: the prologue answers the
`#ifdef` sites that run too early, `defaults.h` answers the value sites, and
`target-specs` still overrides those against the real linker.

Whose answer is the floor (PRINCIPLES section 2a): upstream's own for rs6000
standing alone.  **Not** the primary's -- i386 never tests either macro.

Both-sided (`t49-verify.sh`): rs6000 moves as above; the i386 control
preprocesses to a macro set **identical apart from the two new names**, total
macro count **8358 on all four readings**.

### STILL OPEN, NOT FIXED HERE -- and why each was left

  * `sol2.h:373` `#ifdef HAVE_LD_CTF` is silently false, so `SCTF_CC1_SPEC`
    becomes `%e-gsctf is not supported in this configuration` -- a hard
    user-facing error.  **Deliberately not floored to 1:** claiming CTF support
    the linker may lack is worse than refusing, and `ld -z ctflabel` is
    genuinely not universal.  A design question, not a floor.
  * `darwin.h:707` `HAVE_AS_MMACOSX_VERSION_MIN_OPTION` silently false, so
    `ASM_MMACOSX_VERSION_MIN_SPEC` drops `-mmacosx-version-min=`.
  * `avr/gen-avr-mmcu-specs.cc:114,120` is the OPPOSITE direction: it includes
    the shared `tm.h` (line 37), so `defaults.h` HAS been read, the `#ifdef` is
    unconditionally TRUE, and `have_avrxmega{2,4}_flmap` are hardcoded `true`.
  * Neither solaris nor darwin is in `scratchpad/all-backends.txt`, so those two
    are **source-level readings only** -- no object-level confirmation.

## 2. #154 -- ALREADY FIXED, AND THE STATED MECHANISM IS NOT THE REAL ONE

**No change made.  The root cause is fixed on the branch by `5e54a43ab18`
(2026-08-11), "driver: every target was given i386's multilib set, and searched
its directories".**  Per the brief's own instruction, not duplicated.

**The brief says `multilib_select` "is NULL for riscv".  It is not, and cannot
be.**  `driver::build_multilib_strings()` (`gcc.cc:9054`) is called
unconditionally at `gcc.cc:8924`, **before** `set_up_specs()`, and fills
`multilib_select` from `multilib.h`'s `multilib_raw`.  Read directly out of the
48-back-end build dir, `gcc/multilib.h` is:

    ". !m64 !m32;", "64:../lib64 m64 !m32;", "32:../lib !m64 m32;"

-- **i386's** multilib set, one file, shared by all 48 back ends.  So the bug
was a *wrong value*, not a null pointer: every target searched i386's library
directories.  A NULL would in any case have crashed `gcc.cc`'s own
`set_multilib_dir` (`while (*p != '\0')` on the same variable, no guard) long
before reaching riscv's hook.

Also worth stating: `riscv_compute_multilib` early-returns
(`select_kind == select_by_builtin`, the default) before touching
`multilib_select` at all, so it is not the natural crash site either.

**The landed fix verified for riscv specifically**, by running
`gen-multilib-specs.sh` for `riscv64-unknown-linux-gnu` against the
48-back-end build's `multi-target.multilib` (48 target records): it emits
riscv's own five multilibs -- `.`, `lib32/ilp32`, `lib32/ilp32d`, `lib64/lp64`,
`lib64/lp64d`, keyed on real `-march=rv*` / `-mabi=*` options -- not
`m64`/`m32`.  Both-sided: i386's shared `multilib.h` says `m64`/`m32`, riscv's
generated stanza says `march`/`mabi`.

**I could not reproduce a segfault**, and I did not run a driver for riscv (see
section 4).  "The mechanism is fixed" is as far as the evidence goes; **"the
reported segfault is gone" is NOT claimed.**

## 3. #143 -- THE PREMISE IS HALF FALSE, AND THE REAL ITEM IS A LATENT COLLISION

**No change made; this is a design decision, with a route chosen.**

`EXTRA_GCC_OBJS` in the 48-back-end build's `gcc/Makefile`:

    EXTRA_GCC_OBJS = driver-i386.o  $(MT_GCC_OBJS)

and `multi-target-md.mk` supplies the second half **per back end** -- arc, avr,
loongarch and msp430 all contribute `mtd-<cpu>/` objects (commit
`ba2e480125d`).  So "driver objects are compiled once and shared" is **no longer
true of the target half**.

`driver-i386.o` is **host-side**: it comes from `config.host`'s
`host_extra_gcc_objs`, keyed by the HOST triple, and answers about the machine
the driver RUNS on.  The host is singular, so one such object is correct by the
branch's own rules.  "Only `driver-i386.o` is built" is explained by that, not
by a bug -- as this file already recorded once and the brief did not carry.

### WHAT THEY DECIDE, AND IT IS COHERENT TODAY (`scratchpad/t143-native.sh`)

Read from each base's real chain in the 48-back-end build:

    BASE      HAVE_LOCAL_CPU_DETECT   native spec text calls local_cpu_detect?
    i386      yes                     yes
    aarch64   no                      no
    alpha     no                      no
    arm       no                      no
    mips      no                      no
    rs6000    no                      no
    s390      no                      no
    sparc     no                      no
    riscv     no                      no

Only the back end matching the host publishes a native detector, and the others
publish **neither** half.  The guard is a HOST predefine -- `aarch64.h:1576` is
`#if defined(__aarch64__)`.

**A FALSE ALARM WORTH RECORDING.**  A first pass counted
`#define MCPU_MTUNE_NATIVE_SPECS` and scored aarch64 as "spec text present, spec
function absent" -- the exact two-halves defect `spec-functions.cc` documents.
Reading the VALUE instead of its presence gives `MCPU_MTUNE_NATIVE_SPECS ""`,
the `#else` branch: both halves absent together, no defect.  PRINCIPLES
section 7's "a count is the weakest evidence available" fired on a live case;
the instrument now reads the value.

### THE ACTUAL FINDING: EIGHT BARE DEFINERS, NOT IN THE RENAME LIST

**Eight back ends define a bare `host_detect_local_cpu`** -- aarch64, alpha,
arm, i386, mips, rs6000, s390, sparc -- and it is **not** in
`MULTI_TARGET_RENAME_NAMES` (measured: 0 hits).  This is the
`extract_base_offset_in_addr` shape with 8 definers instead of 3.  It cannot
fire today only because `config.host` links exactly one of them.

That inverts the framing: **"only `driver-i386.o` is built" is what is currently
preventing a hard link failure**, not a symptom of one.

### ROUTE CHOSEN: MOVE THE CAPABILITY INTO `target-specs`

Against the three options the brief named:

  * **Per-base compilation** would trigger the 8-way collision immediately and,
    worse, **would not remove the freeze**: `config.host` still decides at GCC
    build time which host the detector is for.  More objects, same bug.
  * **A selector** has the same problem, and needs the rename first.
  * **`target-specs`** passes PRINCIPLES section 2's test unambiguously: *could
    this differ between two installations of the same compiler serving the same
    target?*  **Yes** -- it is a fact about the deployed machine's CPU, so it is
    a capability, not a hook.  It is also the only route under which a compiler
    built on x86_64 can answer `-march=native` when deployed on an aarch64
    machine.  And it **removes** the collision rather than triggering it: no
    `driver-<cpu>.o` need be linked into the driver at all, so
    `host_detect_local_cpu` never has to be renamed or selected.

The channel already exists and already carries this exact shape of answer:
`target-specs/configure.ac:823-835` turns `--with-cpu-type` into
`%{!march=*:-march=<value>}`, an OPTION_DEFAULT spec in the target's own spec
file.  `-march=native` becomes one more probed key in a file the driver already
reads.

**THE HONEST COST, which must not be dropped when this is implemented:**
`target-specs` freezes the answer at post-install-configure time, whereas
upstream re-runs CPUID on every invocation.  For a per-machine install these are
identical.  For a shared install used from heterogeneous machines they are not
-- though such an install already has one spec file per target and is already
frozen in every other respect.  If that difference is judged unacceptable, the
answer is still not per-base compilation; it is a probe the driver runs at
invocation time using a *method* target-specs supplies, and that is a larger
design than any of the three options offered.

## 4. WHAT THIS DOES NOT CLAIM

  * **No driver and no `cc1` was ever run.**  `make all-gcc` at 48 back ends is
    **rc=2** (stamped `b48.rc`; 4 `make ... Error` lines, 4560 objects) -- the
    pre-existing failing set, with my change NOT in the snapshot, so it is a
    clean baseline and not a regression reading.  Every #143 and #154 statement
    above comes from generated artefacts and preprocessed chains, never from
    `xgcc` behaviour.
  * **No bar is quoted.**  `12369 bytes / 378fc33c1e70`, `specs-config` 230
    lines and `stock-compare` 5/5 all need a linked `cc1`/`xgcc`, which neither
    build dir produced.  Per PRINCIPLES, `stock-compare` selects x86_64 and is
    unscorable beyond two bases (#153) in any case.  **The `mkconfig.sh` change
    is therefore verified by both-sided preprocessing of the generated headers
    and NOT by codegen** -- a real gap, since it changes `TARGET_CMODEL`, which
    is a codegen input.  A two-base build cannot close it either: neither
    configured base has the guard.  Closing it needs a rs6000-capable `cc1`.
  * `HAVE_AS_TLS` and the other two `auto-host.h` survivors are reported, not
    converted.
  * The darwin/solaris `#ifdef` findings are source-level only.
  * `MT_GCC_OBJS_UNHANDLED` (the darwin/vxworks OS-side fork recorded earlier in
    this file) emits **0** lines at 48 back ends, because none of those 48
    triples is a darwin or vxworks target.  The fork is untouched and
    unexercised, not closed.
  * A harness bug of my own is worth recording because it is the file's own
    named shape: `t143-build.sh` first wrote `make ... || true; rc=$?`, which
    captures the status of `true` and **stamped rc=0 on a make that had printed
    "Target 'multi-target-objs' not remade because of errors"**.  A stamped
    exit code is only as good as the capture.
