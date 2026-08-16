# Task #185 — `AARCH64_APPROX_MODE` shifts by a union-numbering difference

Worktree `agent-a51a0e8b2b458063b`, snapshot `6bbccf3795c`, anchor **52**.

## THE BRIEF'S SCALING CLAIM IS FALSE, AND IT IS FALSE IN BOTH DIRECTIONS

The brief says the shift count is 219 at eleven bases, "grows with every back
end added", and at forty-seven bases "is far past 219". Measured from the
generated `insn-modes.h` alone, over every 47-base build dir on this host and
every smaller one (`shiftscan.sh`, in this worktree's scratchpad):

```
bases   NUM float   NUM vec-float   max shift
  2         6            71             76
  3         7            77             83
  4         7           198            204
 11        10           210            219
 47        10           210            219     <- SAME as 11
```

`max shift = (MAX_MODE_VECTOR_FLOAT - MIN_MODE_VECTOR_FLOAT) + NUM_MODE_FLOAT`.

Two corrections:

- **219 is the forty-seven-base figure, not the eleven-base one.** The number
  SATURATED at eleven bases and forty-seven added nothing: the eleven-base set
  already contains riscv (RVV modes, 145 vector-float modes standing alone) and
  aarch64 (SVE, `VNx8DF` is `MAX_MODE_VECTOR_FLOAT`), which are the two ends of
  the range. Adding thirty-six more back ends moved it by zero. So the count is
  not a function of the base COUNT, it is a function of base MEMBERSHIP —
  exactly the correction PRINCIPLES already records for the
  `type_natural_mode` ICE ("it appears at N and not at N−1 is not evidence that
  N is the cause").
- **A two-base build DOES reproduce it: 76 > 63.** The brief says "a two-base
  build cannot verify this — the bug's magnitude is a function of the base
  count". The UB is present at the smallest configuration this branch has ever
  built. The 47-base build is still required by acceptance, but not for this
  reason.

## WHAT IS ACTUALLY REACHABLE, AND IT IS NOT ADVANCED SIMD

Old shift counts for aarch64's own modes in the 47-base numbering:

```
V4HF 20   V2SF 25   V8HF 32   V4SF 35   V2DF 37      <- defined, but WRONG BIT
VNx4SF 136   VNx2DF 140   VNx8DF 219                 <- undefined behaviour
```

So a reproducer must use **SVE**. A plain `float` loop at `-Ofast` without
`+sve` reports nothing and looks exactly like a fixed compiler.

Note the first row: even where the shift is in range, the bit assigned is not
the bit a single-target aarch64 compiler assigns (`V4SF` is bit 35 here, and
would be bit 11 upstream — 5 float modes + its position among aarch64's own
vector floats). The UB is the loud half; the wrong bit numbering is the whole
of it. Both are invisible today because every in-tree `cpu_approx_modes` value
is `AARCH64_APPROX_NONE` (0) or `AARCH64_APPROX_ALL` (~0) — 9 and 3
occurrences respectively across `config/aarch64/tuning_models/`.

## THE UB, MEASURED IN A RUNNING `cc1` (PRE)

`a51a0e8b2b458063b-ubshift.sh /tmp/b-a51a0e8b2b458063b-pre pre`, 47 bases,
snapshot `6bbccf3795c`, anchor 52, `mt-aarch64/aarch64.o` rebuilt with
`-fsanitize=shift` and `cc1` relinked:

```
__ubsan_handle_shift_out_of_bounds undefined refs in the object: 1   <- ARM 1
'shift exponent' reports:                                        9   <- ARM 2

aarch64.cc:17316:11  runtime error: shift exponent 136 is too large for
                     64-bit type 'long unsigned int'      (aarch64_emit_approx_div)
aarch64.cc:17140:11  ... 136 ...                          (use_rsqrt_p)
aarch64.cc:17205:5   ... 136 ...                          (aarch64_emit_approx_sqrt)
```

**All three call sites, and 136 is `VNx4SFmode`** — the value predicted from
the generated header before any sanitized build existed. ARM 1 is what makes a
clean ARM 2 mean anything: "UBSan reported nothing" and "UBSan was never
enabled on that TU" are the same empty log, so the script refuses to score
until it has seen the handler as an undefined reference in the rebuilt object.

## THE SHAPE ELSEWHERE — SWEPT, ONE INSTANCE

`grep` for `- MIN_MODE_` over the tree finds ten other sites. Every one of them
uses the difference as an **index into an array whose bound is the same union
quantity**: `expmed.h` (`NUM_MODE_IPV_INT` and friends size the cost arrays),
`real.h:185` (`real_format_for_mode` is sized `NUM_MODE_FLOAT +
NUM_MODE_DECIMAL_FLOAT`), `tree.cc` / `tree-complex.cc` / `rs6000.cc`
(`BUILT_IN_COMPLEX_*_MIN + mode - MIN_MODE_COMPLEX_FLOAT`, against the range
`tree-core.h:194` reserves from the same two macros). Bound and index agree, so
those are union-as-SIZE used consistently and are correct as they stand.

`AARCH64_APPROX_MODE` is the only site that uses the difference as a **bit
position in a fixed-width word**, where the bound is 64 and comes from
nowhere near the mode machinery. That is what makes it the outlier rather than
one of eleven.
