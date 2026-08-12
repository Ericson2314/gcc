# PRE-REGISTRATION: the expected value of every numeric (c-DATA) slot

Written BEFORE the plugin was extended to dump these slots, and before any of
them had been observed, so that a mismatch cannot be resolved by adjusting the
expectation to match the measurement.  That temptation is real here: unlike the
four string macros, these have **no independent oracle**.

## Why there is no oracle, and what replaces it

`ASM_COMMENT_START`/`WCHAR_TYPE`/`SIZE_TYPE`/`PTRDIFF_TYPE` could be checked
against two outside authorities: `macro-probe.sh`'s header probe, and genuine
upstream cc1's own `__SIZE_TYPE__`.  Neither is available for these eighteen:

  * The header probe extracts a value by making the macro an **array bound**
    and reading the object size.  Every macro here is class (c) precisely
    because it is *not* a constant expression in its own base's header context
    -- `BYTES_BIG_ENDIAN` is `(TARGET_BIG_END != 0)`, a load.  The INT probe
    cannot see them and never could.
  * Upstream cc1 exposes `__SIZE_TYPE__` but does not expose `PARM_BOUNDARY`.

So the oracle is a **hand derivation from the two back ends' headers**, done
here, in advance, with the derivation shown.  A hand derivation is a real
independent source -- it is not the mechanism reporting on itself -- but it is
only as good as the reading, so each line carries the expression it came from.

## The configuration these are derived for

  i386     `x86_64-pc-linux-gnu`, default flags: TARGET_64BIT=1, TARGET_X32=0,
           TARGET_IAMCU=0, so UNITS_PER_WORD=8 and BITS_PER_WORD=64.
  aarch64  `aarch64-unknown-linux-gnu`, LP64: TARGET_ILP32=0, TARGET_BIG_END=0,
           TARGET_STRICT_ALIGN=0, TARGET_SIMD=1.  UNITS_PER_WORD=8 (a literal
           in aarch64.h:75), BITS_PER_WORD=64.

## The table

| macro | i386 | expression | aarch64 | expression | relation |
|---|---:|---|---:|---|---|
| BYTES_BIG_ENDIAN             |   0 | i386.h:759 literal            |   0 | `(TARGET_BIG_END != 0)`, aarch64.h:72 | AGREE |
| WORDS_BIG_ENDIAN             |   0 | i386.h:764 literal            |   0 | `(BYTES_BIG_ENDIAN)`, aarch64.h:73 | AGREE |
| FLOAT_WORDS_BIG_ENDIAN       |   0 | defaults.h:1041 `WORDS_BIG_ENDIAN` | 0 | same default | AGREE |
| REG_WORDS_BIG_ENDIAN         |   0 | defaults.h:1045 `WORDS_BIG_ENDIAN` | 0 | same default | AGREE |
| STRICT_ALIGNMENT             |   0 | i386.h:954 literal            |   0 | `TARGET_STRICT_ALIGN`, aarch64.h:1421 | AGREE |
| SHIFT_COUNT_TRUNCATED        |   0 | i386.h:1981 leaves it undefined; defaults.h:1189 |   0 | `(!TARGET_SIMD)`, aarch64.h:1530 | AGREE |
| JUMP_TABLES_IN_TEXT_SECTION  |   0 | `flag_pic && !(TARGET_64BIT \|\| ...)`, i386.h:2315 |   0 | aarch64-elf.h:70 literal | AGREE |
| BITS_PER_WORD                |  64 | defaults.h:603 `BITS_PER_UNIT * UNITS_PER_WORD` |  64 | same, UNITS_PER_WORD=8 | AGREE |
| LONG_TYPE_SIZE               |  64 | `(TARGET_X32 ? 32 : BITS_PER_WORD)`, i386.h:742 |  64 | `(TARGET_ILP32 ? 32 : 64)`, aarch64.h:93 | AGREE |
| PARM_BOUNDARY                |  64 | `BITS_PER_WORD`, i386.h:774    |  64 | literal, aarch64.h:79 | AGREE |
| ATTRIBUTE_ALIGNED_VALUE      | 128 | `(TARGET_IAMCU ? 32 : 128)`, i386.h:854 | 128 | defaults.h:1264 `BIGGEST_ALIGNMENT` = 128, aarch64.h:87 | AGREE |
| **MALLOC_ABI_ALIGNMENT**     |  64 | i386 leaves it undefined; defaults.h:933 `BITS_PER_WORD` | **128** | aarch64.h:131 literal | **DIFFER** |
| **TRAMPOLINE_SIZE**          |  28 | `(TARGET_64BIT ? 28 : 14)`, i386.h:1781 | **40** | `(24 + (TARGET_ILP32 ? 8 : 16))`, aarch64.h:1468 | **DIFFER** |
| DWARF_CIE_DATA_ALIGNMENT     |  -8 | defaults.h:534 `(-((int) UNITS_PER_WORD))` |  -8 | same default | AGREE |
| STACK_CHECK_FIXED_FRAME_SIZE |  32 | defaults.h:1821 `(4 * UNITS_PER_WORD)` |  32 | same default | AGREE |
| STACK_CHECK_MAX_FRAME_SIZE   | 4088 | defaults.h:1815 `(1 << 12) - UNITS_PER_WORD` | 4088 | same default | AGREE |
| MAX_FIXED_MODE_SIZE          | 128 | `GET_MODE_BITSIZE (TARGET_64BIT ? TImode : DImode)`, i386.h:2039 | 128 | `GET_MODE_BITSIZE (TImode)`, aarch64.h:1362 | AGREE |
| **DWARF_FRAME_RETURN_COLUMN**|  16 | `(TARGET_64BIT ? 16 : 8)`, i386.h:2173 | **30** | `DWARF_FRAME_REGNUM (LR_REGNUM)`, aarch64.h:832; LR_REGNUM=30 | **DIFFER** |

## What this table is for, and the honest limit of it

**Fifteen of the eighteen AGREE, and that is the problem with them.**  A slot
that holds 64 for both bases is consistent with the mechanism working, and
equally consistent with the mechanism being pinned to i386 -- which is exactly
the `targetm_asm_ops` failure, where every value was right and nothing chose
between them.  Those fifteen are scored, but they must never be read as
evidence that selection happens.

**The three that DIFFER are the discrimination control**, and they are the only
lines in this table that can distinguish a working mechanism from a pinned one:

    MALLOC_ABI_ALIGNMENT       64 vs 128
    TRAMPOLINE_SIZE            28 vs 40
    DWARF_FRAME_RETURN_COLUMN  16 vs 30

If those three come back equal, the mechanism is pinned, whatever the other
fifteen say.  If any of the fifteen comes back UNEQUAL, either this derivation
is wrong or a refresh is reading the wrong base's option state -- and the
answer is to re-read the header, not to edit this file.

`DWARF_FRAME_RETURN_COLUMN` is the sharpest of the three for a second reason:
it is the only one whose aarch64 value comes from CALLING a back-end function
(`aarch64_debugger_regno`), so it also demonstrates that the refresh runs real
back-end code and not just arithmetic on option variables.

## Known limitation, stated in advance

The plugin calls **both** bases' refresh functions inside a single cc1 run, and
only one base's option variables have been through that base's
`target_option_override`.  aarch64's `TARGET_SIMD`, `TARGET_ILP32` and
`TARGET_BIG_END` are therefore at their static initialisers, not at the values
a real aarch64 compilation would give them.  For this configuration the derived
values happen not to depend on that -- the defaults and the correct values
coincide -- but the moment one does, this table's aarch64 column will be right
about aarch64 and wrong about the measurement, and that is a limitation of the
measurement, not of the table.  It is the same limitation STATE.md records as
"aarch64 cc1 ICEs before any plugin callback fires".
