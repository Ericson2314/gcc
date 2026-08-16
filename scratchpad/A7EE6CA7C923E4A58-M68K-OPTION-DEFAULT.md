# m68k: `target-specs` writes an option the m68k driver rejects, and GUARD 3b caught it

**One back end, precisely located, not fixed here.** Recorded because it blocks
m68k from being scored at all and because the fix site is exact.

## The symptom, three layers from the cause

`mtcheck.sh` GUARD 3b refused m68k:

```
FATAL[m68k-unknown-elf]: the target's own spec file is not reaching the compiler.
    FAIL[m68k-unknown-elf] ARM4: `-###' produced no cc1 line for the REAL config.
```

"No cc1 line" reads as a specs-plumbing failure. It is not. The driver dies
before it can emit one:

```
$ xgcc -ftarget-config=<m68k specs-config> -S -o /dev/null probe.c
xgcc: error: unrecognized argument in option '-mcpu=m68020'
xgcc: note: valid arguments to '-mcpu=' are: ... 68020 68030 68040 ...;
      did you mean '68020'?
```

## The cause

`<builddir>/lib/gcc/17.0.0/m68k-unknown-elf/specs` line 73:

```
*option_defaults:
%{!mcpu=*:%{!march=*:-mcpu=m68020}}
```

`-mcpu=m68020` is not a valid m68k option. `m68020` is not a valid *value*
either -- the valid value is bare `68020`, which is what the diagnostic's
"did you mean" is telling us.

Upstream `gcc/config/m68k/m68k.h:30`:

```c
#define OPTION_DEFAULT_SPECS						\
  { "cpu",   "%{!m68020-40:%{!m68020-60:\
%{!mcpu=*:%{!march=*:-%(VALUE)}}}}" },
```

Note **`-%(VALUE)`** -- a dash prepended directly to the value. With
`--with-cpu=m68020` upstream produces **`-m68020`**, which IS a valid m68k
option. `target-specs` instead applied the generic `-mcpu=` + value spelling.

## Why this is the documented hazard, not a surprise

`target-specs/configure.ac:158` already says it:

> every back end -- i386 spells the `cpu` and `tune` defaults as -mtune, most
> others spell `cpu` as -mcpu -- so the expansion has to know.

It knows about `-mtune` vs `-mcpu`. It does not know about the third form.

## How many back ends this affects: ONE

Measured over the 22 files defining `OPTION_DEFAULT_SPECS`, by the shape of
the value they expand:

```
20   -mcpu=%(VALUE)
11   -march=%(VALUE)
11   -mtune=%(VALUE)
 1   -%(VALUE)          <- m68k, and only m68k
```

**So this is a single-back-end blocker, not a shared cause**, and it is filed
that way deliberately: the interesting causes on this board are the ones many
back ends carry, and inflating a one-target defect into a family would be the
opposite of the ranking this exercise exists to produce.

## What it is worth

Unblocking m68k moves it from BLOCKED to scorable -- one back end out of 47,
and the 15th ever to have a test result. The fix belongs in whatever emits
`*option_defaults` in `target-specs`, and must reproduce the back end's own
`OPTION_DEFAULT_SPECS` expansion rather than assume a spelling. **Do not fix it
by hardcoding m68k**: the bug is that one authority is guessing another's
spelling, which is this branch's root bug, and a special case for m68k is the
same guess with an exception bolted on.
