# T159 — `TARGET_POLY_AWARE` is delivered; `IN_TARGET_CODE` is not

## WITHDRAWN (task #181). THE CONCLUSION BELOW IS WRONG, AND THE COUNT THAT PRODUCED IT IS CORRECT.

`scratchpad/tb1-itc.sh`, run against a cold three-base build
(`i386 aarch64 xstormy16`, `make all-gcc` **rc=0**, `error:` 0, `cc1` links,
snapshot `ba415463e56`, anchor 49). It reads the macro state each object's OWN
recipe arrives at, with `-E -dM`, so `<ABSENT>` and `0` are distinguishable:

```
                            IN_TARGET_CODE  TARGET_POLY_AWARE  ONLY_FIXED_SIZE_MODES  POLY_INT_CONVERSION  MACRO_MODE(MODE)
mt-xstormy16/xstormy16.o          1            <ABSENT>                 1                      1           (as_a <fixed_size_mode> (MODE))
mt-aarch64/aarch64.o              1                1                    0                      0           (MODE)
insn-output-xstormy16.o           1            <ABSENT>                 1                      1           (as_a <fixed_size_mode> (MODE))
insn-output-aarch64.o             1                1                    0                      0           (MODE)
target-regs-xstormy16.o       <ABSENT>         <ABSENT>                 0                      0           (MODE)
expr.o                        <ABSENT>         <ABSENT>                 0                      0           (MODE)
```

**The shorthand is live in `cc1`'s own objects, and it is already both-sided.**
xstormy16 — a back end that has NOT been converted, and therefore wants the
shorthand — gets `ONLY_FIXED_SIZE_MODES 1`, `POLY_INT_CONVERSION 1` and the
`as_a <fixed_size_mode>` / `.to_constant ()` re-key of `3715ed1ec91`, in both
its hand-written and its generated target sources. aarch64 — converted, and
declaring so — gets the identity. Shared `expr.o` gets the identity. Nothing
is inert and nothing needs widening.

**WHY THE COUNT WAS RIGHT AND THE INFERENCE WAS WRONG: `IN_TARGET_CODE` HAS
NEVER BEEN A COMMAND-LINE FLAG, HERE OR UPSTREAM.** Every back-end source
spells `#define IN_TARGET_CODE 1` as its own first line — 186 files under
`gcc/config/` — and nine generators (`genattrtab`, `genautomata`, `genemit`,
`genextract`, `genopinit`, `genoutput`, `genpeep`, `genpreds`, `genrecog`)
write that same line into the sources they emit. `-DTARGET_POLY_AWARE` needs a
`-D` because it is an *opt-in with no in-source spelling*; `IN_TARGET_CODE`
needs none because the source says it. So `0` compile lines is the correct and
expected reading for a flag that does not exist, in this tree and in upstream's
— and the two names look symmetric only from the makefile.

The trap is the one PRINCIPLES section 4 already names in the other direction:
**a zero from a name-matching instrument is a claim about the instrument.** The
census counted `-D` occurrences, which is a complete measurement of a channel
`IN_TARGET_CODE` does not travel through.

Two residual facts the same run establishes, neither of them the reported bug:

- `target-{regs,addr,cdata,c-ops,cumargs}-<cpu>.o` and
  `mt-<cpu>/target-passes-<cpu>.o` are per-base objects compiled from SHARED
  sources, so they carry no `IN_TARGET_CODE` and take the poly-general arm.
  That is the safe direction and matches what those sources are.
- `insn-modes-<cpu>.cc` and `insn-enums-<cpu>.cc` are the two generated
  per-base sources whose generators do NOT write the line. Upstream's do not
  either, so they match upstream rather than diverging from it.

**`gen-multi-target-md.awk`'s "widen this when they do" comment is about
`-DTARGET_POLY_AWARE`, which HAS been widened** — 61 compile lines carry it,
and the table above shows it landing on exactly the objects it should. Nothing
in that comment schedules an `IN_TARGET_CODE` flag.

Everything below is the original text, kept because its measurements are all
reproducible and only its conclusion is not.

---

**Measured, four-base build (i386, aarch64, riscv, xstormy16) at
`1937e74ec05`, full cold build log:**

    compile lines carrying -DTARGET_POLY_AWARE   61
    compile lines carrying -DIN_TARGET_CODE       0

Every per-back-end switch in the poly migration is conjoined on
`defined (IN_TARGET_CODE)`:

    coretypes.h:621  POLY_INT_CONVERSION   defined (IN_TARGET_CODE) && (USE_ENUM_MODES || !TARGET_POLY_AWARE)
    machmode.h:107   ONLY_FIXED_SIZE_MODES defined (IN_TARGET_CODE) && !defined (TARGET_POLY_AWARE)

So with `IN_TARGET_CODE` never defined, **both are 0 for every object in the
compiler proper**, and the `-DTARGET_POLY_AWARE` opt-in that IS delivered
selects nothing there. The mechanism is present and, for `cc1`'s objects,
never invoked.

The one place it does work is `build/gencondmd-<triple>.o`:
`genconditions.cc:74` writes `#define IN_TARGET_CODE 1` into the source it
generates, and `gen-multi-target-md.awk:1129` adds `-DTARGET_POLY_AWARE` per
back end. That is why the awk's own comment (lines 155-175) scopes itself to
gencondmd and says:

> Only `build/gencondmd-<triple>.o` needs it. ... the compiler proper's
> per-back-end objects do not exist yet outside the primary target.
> **Widen this when they do.** ... Whoever adds the per-back-end compiler
> objects to `OBJS` must call this function when they do; that is the moment
> the hazard becomes reachable.

**That moment has arrived.** The per-base compiler objects now exist and link
— `mt-<cpu>/*.o`, `target-addr-<cpu>.o`, `insn-*-<cpu>.o` are built for all
four bases and `cc1` is 145 MB — and `IN_TARGET_CODE` is not being delivered
to any of them. The scheduled widening is due.

## Consequence for the `MACRO_MODE`/`MACRO_INT` re-key (`3715ed1ec91`)

That commit is correct in shape and is **live only in
`gencondmd-<triple>.o`** today, where `IN_TARGET_CODE` is defined and
xstormy16 (not poly-aware) now correctly gets `as_a <fixed_size_mode>` /
`.to_constant ()` while the poly-aware three keep the identity. It is
**inert in the compiler proper**, for exactly the same reason
`POLY_INT_CONVERSION` and `ONLY_FIXED_SIZE_MODES` are inert there. Stated
plainly so nobody scores it as a completed conversion.

## Why `-DIN_TARGET_CODE` goes missing

It is set only in the tmake fragments (`config/<cpu>/t-<cpu>`), and a
multi-target build reads **no** target's `tmake_file` — only the primary's,
via `-include $(tmake_file)`. `gen-multi-target-md.awk` deliberately ignores
the fragments' recipes and lifts exactly one flag out of them by name,
`-DTARGET_POLY_AWARE` (see `poly_aware()`). `IN_TARGET_CODE` was not lifted.

## The next step, and why it is not taken here

Adding `-DIN_TARGET_CODE` to the per-base objects flips `POLY_INT_CONVERSION`
and `ONLY_FIXED_SIZE_MODES` on for the 37 unconverted back ends at once. That
is the migration switch finally doing its job, and it is also exactly the
kind of change that produces a large diagnostic count in one step (the
comparable flip was measured at 3060 `error:` lines over 39 back ends). It
wants its own task with a before/after count, not a tail-end landing.

Note the second flag must travel with it: the per-object `-DTARGET_POLY_AWARE`
is already correct, so the only missing half is `IN_TARGET_CODE` — and adding
it WITHOUT the poly-aware flag reaching the same objects would give the ten
converted back ends the shorthand they have already been converted away from.
Both are per object; `poly_aware()` already answers the second.
