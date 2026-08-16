# `avr-fuse-add` runs for EVERY back end and writes through `func->machine`

**This is the largest thing on this board and it is handed back, not chased.**
It is the branch's root bug -- one name, several authorities -- in an
un-gated RTL pass, and it is reachable with a five-token C program.

## Reproducer

```
$ printf 'int f(int x){return x+1;}\n' > mb.c
$ xgcc -B<build>/gcc/ -ftarget-config=<microblaze specs-config> -S -o /dev/null mb.c
during RTL pass: avr-fuse-add
mb.c:1:25: internal compiler error: Segmentation fault
```

No `-O`, no header, no libc, no assembler. **microblaze**, **rx** and **sh**
all die this way, on their first input, in AVR's pass.

## The cause, in six lines of `config/avr/avr-passes.cc:4268`

```c
class avr_pass_fuse_add : public rtl_opt_pass
{
  /* ... NO gate () override at all ... */
  unsigned int execute (function *func) final override
  {
    func->machine->n_avr_fuse_add_executed += 1;      // <-- unconditional
    n_avr_fuse_add_executed = func->machine->n_avr_fuse_add_executed;

    if (optimize && avropt_fuse_add > 0)              // <-- the guard, TOO LATE
      return execute1 (func);
    return 0;
  }
```

Two independent defects, and they compound:

1. **No `gate`.** `rtl_opt_pass`'s default gate is always true, so the pass is
   entered for every back end. It is inserted by
   `config/avr/avr-passes.def:27` via `INSERT_PASS_BEFORE (pass_peephole2, 1,
   ...)` -- the `PASSES_EXTRA` mechanism, which is collected once for the
   legacy single `${target}` rather than per configured back end. That is the
   **same shape as `extra_headers`**, which `TAA-BOARD.md` 4 records as worth
   62,464 results on aarch64 alone, and which PRINCIPLES already lists beside
   `tmake_file`, `extra_objs`, `c_target_objs`, `target_gtfiles` and
   `out_file`. This is a new member of a known family.

2. **The write precedes the guard.** Even with `optimize == 0` and
   `avropt_fuse_add == 0` -- i.e. every case the pass is supposed to do
   nothing in -- `func->machine->n_avr_fuse_add_executed += 1` has already
   executed. So the `if` cannot protect anything.

`func->machine` is `struct machine_function`, and **every back end declares its
own**. The pass reads it as AVR's. On microblaze, rx and sh the offset is past
the end and the process dies.

## THE 8 "OK" BACK ENDS ARE NOT PROVEN FINE, AND THIS IS THE IMPORTANT PART

A segfault needs the write to land outside the allocation. A back end whose
`machine_function` merely happens to be **large enough** takes the write
silently, into whatever member sits at AVR's offset. PRINCIPLES 4 is explicit
about this direction: *"a wall that moves may have become silent wrong code"*,
and *"'where does it ICE' is not the measurement, 'is the output right' is"*.

So the honest reading of the one-line census is:

```
segfault in avr-fuse-add          3   microblaze, rx, sh      -- LOUD
compiled without complaint        8   aarch64 arm avr mips64 or1k
                                      riscv64 s390x x86_64    -- UNVERIFIED
```

**The 8 are an upper bound on "unaffected", not a measurement of it.** Whether
any of them silently corrupts a `machine_function` member is NOT established
here and needs a both-sided arm: compare each back end's emitted assembly with
the pass removed against the same with it present. `avr` itself is in the
"OK" column and is the one back end for which the write is correct by
construction, which is exactly why it never showed up before.

## Why no previous board saw it

Only four back ends were ever scored, and **all four are in the silent
column**. The three that die are all first-time entrants. This is the concrete
answer to `AB1900D5279BA137F-BOARD.md` 7's closing claim that the era of one
defect explaining a whole board is over: it is not over, it was unobservable
at four targets.

## What to do with it -- NOT a two-line fix, and the trap is named

Adding `bool gate (function *) { return <is avr>; }` is the obvious move and it
is only half. The other AVR passes in that file (`avr_pass_casesi`,
`avr_pass_ifelse`, both at `avr-passes.cc:3326` and `:3929`) gate on
`optimize > 0` **and nothing about the target**, so they run for every back end
too -- they simply have not crashed yet. Auditing this one pass and declaring
the file healthy is PRINCIPLES 4's *"a loud break can mask a silent one"*.

The real question is a design one and belongs to whoever owns `PASSES_EXTRA`:
**a back end's passes must be registered for that back end only**, in the same
way `extra_headers` had to become per-configured-back-end. A per-pass gate is a
per-site patch for a collection defect, and there are at least three sites in
this one file.
