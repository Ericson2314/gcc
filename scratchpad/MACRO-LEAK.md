# THE BACK-END MACRO LEAK: MEASURED, CLASSIFIED, AND THE DESIGN CONSEQUENCE

Nothing committed, nothing staged, no file added to the tree. All work in
`/tmp/gap/` (this session) over `/tmp/rv/` (previous session's inputs).
`git status` in the tree is unchanged.

Method is the inherited one and it is still the right one: **host compile plus
`nm -S`, no execution.** `char q[VALUE + 1]`, size IS value + 1. This session
extends it to a **64-bit-exact** form -- eight symbols per macro, each holding
one byte of the value plus one -- so negative and large values survive, which
the single-array form could not represent.

Tool guard: every run asserts `g++`, `nm`, `sed`, `awk` present and exits 9 if
not, and asserts inputs non-empty before scoring. Two runs in this session
failed loudly for a real reason (`gmp.h` missing from a `-p` set -- exactly the
DEVSHELL warning) and were re-run; neither produced a number.

---

## HEADLINE: THE "143" WAS NOT AN UPPER BOUND. IT IS AN UPPER BOUND ON THE WRONG SET

`/tmp/rv/README.md` correctly warns that 143 over-reports, because it compares
definition **text**. That warning is right and I confirmed it (116 of the 143
are not "a differing constant" at all). But the warning is **incomplete in the
opposite direction**, and this is the single most important result of the
session:

> **A text diff is structurally blind to a macro whose definition text is
> byte-identical on both bases and whose VALUE differs, because the text
> expands through a back-end-generated enum.**

The proof is not hypothetical. It is the one divergence that already ICEs
`cc1`:

```
dm-i386.txt:    #define N_REG_CLASSES ((int) LIM_REG_CLASSES)
dm-aarch64.txt: #define N_REG_CLASSES ((int) LIM_REG_CLASSES)
                                        ^ identical text
measured value:  i386 = 34      aarch64 = 20
in /tmp/rv/diffmacros ?   NO
in /tmp/rv/hits-ranked ?  NO
```

`N_REG_CLASSES` is the macro behind `init_reg_sets_1` walking 34 classes and
handing index 20..33 to aarch64's `class_max_nregs`, i.e. **the exact ICE at
`aarch64.cc:14322` that blocks the fourth arm is caused by a macro the 143 does
not contain.** Anyone who scoped this work from `hits-ranked` would have
scoped out the known blocker.

So I measured the blind spot rather than describing it. Of 9298 macros defined
by both bases, 8378 have identical text; 1956 of those are spelled by
target-independent code; 1604 of those are object-like with a non-empty body.
All 1604 were value-probed on both bases (batch compile, drop-and-retry on the
macros the compiler names, 2 rounds per base).

    identical-text macros spelled by generic code, probed   1604
    integer-constant on BOTH bases                           546
      of those, DIFFERING VALUE                                1   <- N_REG_CLASSES
    constant on i386 only (runtime on aarch64)                 2
    constant on aarch64 only (runtime on i386)                 7
    non-integer on both (strings/types/aggregates, mostly
      system.h and config.h host macros) -- NOT further
      classified, stated residual                          ~1049

The nine asymmetric ones are new and were invisible to every prior method:

| macro | i386 | aarch64 |
|---|---|---|
| `FLOAT_WORDS_BIG_ENDIAN` | constant | **runtime** (`TARGET_BIG_END`) |
| `REG_WORDS_BIG_ENDIAN` | constant | **runtime** |
| `BITS_PER_WORD` | **runtime** (`TARGET_64BIT`) | constant 64 |
| `MOVE_MAX_PIECES` | **runtime** | constant |
| `COMPARE_MAX_PIECES` | **runtime** | constant |
| `DWARF_CIE_DATA_ALIGNMENT` | **runtime** | constant |
| `STACK_CHECK_FIXED_FRAME_SIZE` | **runtime** | constant |
| `STACK_CHECK_MAX_FRAME_SIZE` | **runtime** | constant |
| `SUPPORTS_STACK_ALIGNMENT` | **runtime** | constant |

`BITS_PER_WORD` deserves its own line. It is spelled all over the middle end
and it is **not a constant on the primary** -- it is `(TARGET_64BIT ? 64 : 32)`
via `UNITS_PER_WORD`. A middle-end TU compiled against i386's `tm.h` therefore
already evaluates *the primary's* `TARGET_64BIT` at run time, under a
target-neutral name, when compiling for aarch64.

**Corrected bound statement.** The population is *at least* 8 (previous
session's value-measured lower bound) and the text-divergent candidate set is
143, but the true set is **not bounded above by 143**. Measured this session:
127 actionable names from the 143 (see below) **plus 10 from the blind spot**,
with ~1049 identical-text non-integer macros still unclassified. The honest
statement is a **lower bound of 137 actionable names and no established upper
bound.**

---

## DELIVERABLE 1: THE 143, CLASSIFIED BY WHAT A FIX WOULD HAVE TO BE

Every object-like macro compared by **value** on both bases. Function-like
macros cannot be value-compared and were classified by definition body.

| class | count | fix shape |
|---|---:|---|
| **(a) same value, no action** | **1** | none |
| **(b) differing constant -- unionable/selectable** | **28** | the landed shape works |
| **(c) not a constant expression** | **91** | *a union of values cannot fix it* |
| **(d) used on a `#if`/`#elif` arithmetic line** | **5** (11 sites) | cannot become a runtime value at all |
| **(e) sizes an allocation** | **11** | mismatch is a buffer overflow |
| **(f) driver-only spec string** | **12** | already solved by `target-specs` |

(d) and (e) overlap (b) and each other; the table is by fix shape, not a
partition. Totals: 1 + 28 + 91 + 12 = 132 by primary class, with (d) ⊂ (b) and
(e) drawing from (b) and the aggregate subclass of (c). Actionable = 143 − 1
(same value) − 12 (driver-only) = **130**, of which 3 are `targetm` hook
initialisers already solved by `f82b65386d0`, giving **127**.

### (a) same value, no action -- 1

`MAX_BITS_PER_WORD` (64 on both). Text differs, value agrees. **Exactly one**
of the 143 is in this class -- the text-diff over-reporting is real but it is
not where the noise is. The noise is class (c).

### (b) differing constant -- 28, full list with measured values

    FIRST_PSEUDO_REGISTER            92      95
    HARD_FRAME_POINTER_REGNUM         6      29
    STACK_POINTER_REGNUM              7      31
    FRAME_POINTER_REGNUM             19      64
    ARG_POINTER_REGNUM               16      65
    MAX_BITSIZE_MODE_ANY_MODE      1024    8192
    DEFAULT_SIGNED_CHAR               1       0
    MAX_SUPPORTED_STACK_ALIGNMENT  2147483648  128
    MAX_STACK_ALIGNMENT            2147483648  128
    TARGET_HAS_FMV_TARGET_ATTRIBUTE   1       0
    INDEX_REG_CLASS                  15       5
    BASE_REG_CLASS                   14       7
    FUNCTION_BOUNDARY                 8      32
    FUNCTION_MODE                    24      27
    NUM_UNSPEC_VALUES               312     730
    NUM_UNSPECV_VALUES              114      40
    PUSH_ARGS_REVERSED                1       0
    STACK_CHECK_MOVING_SP             1       0
    CASE_VECTOR_PC_RELATIVE           0       1
    SLOW_BYTE_ACCESS                  0       1
    MIN_UNITS_PER_WORD                4       8
    MAX_MOVE_MAX                     64      16
    DWARF_FRAME_REGISTERS            17      97
    HAS_LONG_UNCOND_BRANCH            1       0
    HAS_LONG_COND_BRANCH              1       0
    ENABLE_X86_64_MFENTRY             1       0
    DEFAULT_PCC_STRUCT_RETURN         1       0
    TARGET_PTRMEMFUNC_VBIT_LOCATION   0       1   (pfn vs delta)
    ------ plus, from the blind spot, invisible to the 143:
    N_REG_CLASSES                    34      20

`TARGET_PTRMEMFUNC_VBIT_LOCATION` needed a second probe with `tree-core.h`; the
first FAIL was a missing header, not a non-constant. It is a **C++ ABI**
divergence: where the virtual bit of a pointer-to-member lives. Like
`DEFAULT_SIGNED_CHAR`, language-visible, no diagnostic.

### (c) NOT A CONSTANT EXPRESSION -- 91, every member named

This is the class that decides the project. A middle-end TU compiled against
the primary's `tm.h` does not merely hold a wrong number for these: it holds
**the primary's back-end code**, and evaluates the primary's option variables
and calls the primary's functions, at run time, under a target-neutral name.
No union of values reaches them.

**(c1) function-like, expanding to back-end functions/globals -- 49 (ALL of the
function-like macros in the 143; not one is a plain constant):**

    ASM_DECLARE_FUNCTION_NAME  ASM_OUTPUT_ADDR_DIFF_ELT  ASM_OUTPUT_ALIGN
    ASM_OUTPUT_EXTERNAL  ASM_OUTPUT_FUNCTION_LABEL  ASM_OUTPUT_LABELREF
    ASM_OUTPUT_MAX_SKIP_ALIGN  ASM_PREFERRED_EH_DATA_FORMAT  BRANCH_COST
    CLEAR_RATIO  CLZ_DEFINED_VALUE_AT_ZERO  CONSTANT_ADDRESS_P
    CTZ_DEFINED_VALUE_AT_ZERO  DATA_ALIGNMENT  DEBUGGER_REGNO
    DWARF_FRAME_REGNUM  EH_RETURN_DATA_REGNO  EPILOGUE_USES
    FUNCTION_ARG_REGNO_P  FUNCTION_PROFILER  HARD_REGNO_CALLER_SAVE_MODE
    HARD_REGNO_NREGS_HAS_PADDING  HARD_REGNO_NREGS_WITH_PADDING
    HARD_REGNO_RENAME_OK  INITIAL_ELIMINATION_OFFSET  INIT_CUMULATIVE_ARGS
    LEGITIMATE_PIC_OPERAND_P  LIBCALL_VALUE  LOAD_EXTEND_OP  LOCAL_ALIGNMENT
    LOCAL_DECL_ALIGNMENT  MINIMUM_ALIGNMENT  MOVE_RATIO
    OPTIMIZE_MODE_SWITCHING  OUTGOING_REG_PARM_STACK_SPACE  PROMOTE_MODE
    REGMODE_NATURAL_SIZE  REGNO_OK_FOR_BASE_P  REGNO_OK_FOR_INDEX_P
    REGNO_REG_CLASS  RETURN_ADDR_RTX  REVERSE_CONDITION  REVERSIBLE_CC_MODE
    SELECT_CC_MODE  SETUP_FRAME_ADDRESSES  SET_RATIO  STACK_SAVEAREA_MODE
    STACK_SLOT_ALIGNMENT  VECTOR_STORE_FLAG_VALUE

Representative bodies, i386 vs aarch64, to show there is no value to union:

    REGNO_REG_CLASS(R)   (regclass_map[(R)])          aarch64_regno_regclass (R)
    SELECT_CC_MODE(O,X,Y) ix86_cc_mode (O,X,Y)        aarch64_select_cc_mode (O,X,Y)
    BRANCH_COST(s,p)     ... ix86_branch_cost         aarch64_branch_cost (s,p)
    MOVE_RATIO(s)        ix86_cost->move_ratio        ... AARCH64_CALL_RATIO ...

`regclass_map` is a real global in i386's objects. It is not in
`MULTI_TARGET_RENAME_NAMES`, so it **links** and answers i386's register
classes for every target. That is the previous session's two-stage-poison
finding, and this list is its true size: 49 names, not one.

**(c2) object-like, reading option state or calling a back-end function -- 31:**

    ACCUMULATE_OUTGOING_ARGS  ADJUST_REG_ALLOC_ORDER  ATTRIBUTE_ALIGNED_VALUE
    BIGGEST_ALIGNMENT  BYTES_BIG_ENDIAN  DWARF_FRAME_RETURN_COLUMN
    EXIT_IGNORE_STACK  HAVE_adddf3  HAVE_atomic_compare_and_swapdi
    HAVE_atomic_compare_and_swapsi  HAVE_cpymemdi  HAVE_setmemdi
    INCOMING_FRAME_SP_OFFSET  INCOMING_STACK_BOUNDARY
    JUMP_TABLES_IN_TEXT_SECTION  LONG_TYPE_SIZE  MALLOC_ABI_ALIGNMENT
    MAX_FIXED_MODE_SIZE  MOVE_MAX  PARM_BOUNDARY  PIC_OFFSET_TABLE_REGNUM
    POINTER_SIZE  PREFERRED_STACK_BOUNDARY  SHIFT_COUNT_TRUNCATED
    STACK_BOUNDARY  STORE_MAX_PIECES  STRICT_ALIGNMENT  TRAMPOLINE_ALIGNMENT
    TRAMPOLINE_SIZE  UNITS_PER_WORD  WORDS_BIG_ENDIAN

Plus the 9 asymmetric blind-spot macros above (`BITS_PER_WORD`,
`FLOAT_WORDS_BIG_ENDIAN`, `REG_WORDS_BIG_ENDIAN`, `MOVE_MAX_PIECES`,
`COMPARE_MAX_PIECES`, `DWARF_CIE_DATA_ALIGNMENT`,
`STACK_CHECK_FIXED_FRAME_SIZE`, `STACK_CHECK_MAX_FRAME_SIZE`,
`SUPPORTS_STACK_ALIGNMENT`) -> **(c2) is really 40.**

The exact failure texts, which are the evidence and not an inference:

    ACCUMULATE_OUTGOING_ARGS  'cfun' was not declared in this scope
    EXIT_IGNORE_STACK         'cfun' was not declared in this scope
    INCOMING_FRAME_SP_OFFSET  'cfun' was not declared in this scope
    PIC_OFFSET_TABLE_REGNUM   'ix86_use_pseudo_pic_reg' was not declared
    STACK_BOUNDARY            'ix86_cfun_abi' was not declared
    TRAMPOLINE_ALIGNMENT      'lang_hooks' was not declared
    ADJUST_REG_ALLOC_ORDER    'x86_order_regs_for_local_alloc' was not declared
    (the remainder) "... is not an integral constant-expression"

`UNITS_PER_WORD` and `Pmode` -- the two names `/tmp/rv/README.md` guessed would
turn out to be class (a) -- are **class (c)**. Both are `(TARGET_64BIT ? ...)`
/ `(ix86_pmode == PMODE_DI ? ...)` on i386 and plain constants on aarch64. 662
+ 263 = 925 generic use sites. The README's guess was reasonable and it was
wrong in the more dangerous direction, which is why it needed measuring.

**(c3) rtx-valued -- 3:** `EH_RETURN_HANDLER_RTX`, `EH_RETURN_STACKADJ_RTX`,
`INCOMING_RETURN_ADDR_RTX`. Each calls `gen_rtx_REG`/`gen_rtx_MEM` with a
back-end regnum.

**(c4) mode-valued -- 3:** `CASE_VECTOR_MODE`, `Pmode`, `STACK_SIZE_MODE`.

**(c5) type-name strings, language/ABI-visible -- 3:**

    PTRDIFF_TYPE   i386 (TARGET_LP64 ? "long int" : "int")     a64 "long int"
    SIZE_TYPE      i386 (TARGET_LP64 ? "long unsigned int"...)  a64 "long unsigned int"
    WCHAR_TYPE     i386 (TARGET_LP64 ? "int" : "long int")      a64 "unsigned int"

`WCHAR_TYPE` differs outright: **`int` vs `unsigned int`**. A multi-target
`cc1` compiling aarch64 would make `wchar_t` signed. Third member of the
`DEFAULT_SIGNED_CHAR` family -- language-visible, silent, ABI.

**(c6) `targetm` hook initialisers -- 2:** `TARGET_ASM_FILE_END`,
`TARGET_ASM_SELECT_SECTION`. **Already solved** by the landed `targetm`-pointer
work (`f82b65386d0`); listed for completeness, excluded from the 127.

**(c7) middle-end asm string macros -- 2, and these are NOT driver-only:**

    ASM_COMMENT_START   i386 "#"        aarch64 "//"
    GLOBAL_ASM_OP       i386 "\t.globl\t"  aarch64 "\t.global\t"

`ASM_COMMENT_START` is spelled in `final.cc dwarf2cfi.cc dwarf2out.cc
dwarf2asm.cc toplev.cc print-rtl.cc varasm.cc vmsdbgout.cc` (56 sites);
`GLOBAL_ASM_OP` in `varasm.cc`. These are emitted **into the assembly file**.
They are the cheapest possible way for the fourth arm to fail a byte
comparison, and they are also the cheapest possible way for it to *nearly*
pass -- `.globl` vs `.global` assembles identically and would survive any
check weaker than a byte diff.

### (d) USED ON A `#if`/`#elif` ARITHMETIC LINE -- 5 macros, 11 sites, complete

This is the axis that has decided every previous fix on this branch, so it was
swept exhaustively: every `#if`/`#elif` line in `gcc/*.cc gcc/*.h` that names
one of the 143 and does **not** go through `defined()`. A second sweep over
every `*.cc *.h *.c` in the whole `gcc/` tree excluding `config/`,
`testsuite/` and `ada/gcc-interface/` adds **nothing** (the only extra hit is
`config/fr30/fr30.cc:149`, a back end). The list is therefore complete for
target-independent code.

    hard-reg-set.h:45    #if FIRST_PSEUDO_REGISTER <= HOST_BITS_PER_WIDEST_FAST_INT
    hard-reg-set.h:164   #if FIRST_PSEUDO_REGISTER <= HOST_BITS_PER_WIDEST_FAST_INT
    rtl.h:3936           #if FRAME_POINTER_REGNUM == ARG_POINTER_REGNUM
    rtl.h:3944           #if FRAME_POINTER_REGNUM != ARG_POINTER_REGNUM
    rtl.h:3939           #if HARD_FRAME_POINTER_IS_FRAME_POINTER   (derived, rtl.h:3919)
    rtl.h:3945           #if HARD_FRAME_POINTER_IS_ARG_POINTER     (derived, rtl.h:3924)
    print-rtl.cc:511     #if !(NUM_UNSPECV_VALUES > 0)
    print-rtl.cc:1624    #if NUM_UNSPECV_VALUES > 0
    print-rtl.cc:1631    #if NUM_UNSPECV_VALUES > 0
    print-rtl.cc:1629    #if NUM_UNSPEC_VALUES > 0
    dwarf2out.cc:15369   #if NUM_UNSPEC_VALUES > 0

Members: `FIRST_PSEUDO_REGISTER`, `FRAME_POINTER_REGNUM`, `ARG_POINTER_REGNUM`,
`NUM_UNSPEC_VALUES`, `NUM_UNSPECV_VALUES`. **All five are also class (b)** --
they are exactly the differing constants one would most want to make runtime,
and they are exactly the ones that cannot be.

Two of these are worse than "a `#if` I must not break":

  * `hard-reg-set.h:45` selects the **representation of `HARD_REG_SET`** --
    scalar `HOST_WIDEST_FAST_INT` when `FIRST_PSEUDO_REGISTER <= 64`, a struct
    with operator overloads when not. Both bases are > 64 (92, 95) so both take
    the struct branch today and a union at 95 stays on the same branch. It is
    safe **now** and it is a landmine for any third base under 64 registers,
    and the failure mode is a silent type change, not a diagnostic.
  * `rtl.h:3936/3944` is the previous session's hazard #2 and the measurement
    confirms it: turning these regnums runtime makes the preprocessor see
    undefined identifiers and evaluate `0 == 0` as **true**, collapsing
    `GR_ARG_POINTER` onto `GR_FRAME_POINTER` in `enum global_rtl_index`.

### (e) SIZES AN ALLOCATION -- the `cl_optimization` shape, 11 names

Mismatch here is a **buffer overflow**, not a mis-read.

  * **`FIRST_PSEUDO_REGISTER` (92 vs 95)** -- 82 array-bound sites in
    `gcc/*.cc gcc/*.h`, dominated by true declarations:
    `df-scan.cc:111 static bool regs_ever_live[FIRST_PSEUDO_REGISTER]`,
    `emit-rtl.cc:6673 rtx hard_reg_clobbers[NUM_MACHINE_MODES][FIRST_PSEUDO_REGISTER]`,
    `lra-assigns.cc`, `ira-color.cc`, `caller-save.cc`, `reg-stack.cc`, and
    `HARD_REG_SET_LONGS` itself. Sized 92 by the primary, indexed to 94 by
    aarch64.
  * **`N_REG_CLASSES` (34 vs 20)** -- 73 array-bound sites, including
    `hard-reg-set.h:503-521` (`x_reg_class_contents`, and three
    `[N_REG_CLASSES][N_REG_CLASSES]` matrices) and `ira.h:48-77`. Here the
    primary is *larger*, so the overflow is the other direction: no overrun,
    but every one of those tables is initialised for 34 classes by walking
    aarch64's 20-class back end, which is the ICE.
  * **`MAX_BITSIZE_MODE_ANY_MODE` (1024 vs 8192)** -- and the site is a
    **stack** buffer with the wrong value used as its own guard:

        fold-const.cc:13088   && bitsize <= MAX_BITSIZE_MODE_ANY_MODE)
        fold-const.cc:13090   unsigned char b[MAX_BITSIZE_MODE_ANY_MODE / BITS_PER_UNIT];
        simplify-rtx.cc:8146  long el32[MAX_BITSIZE_MODE_ANY_MODE / 32];
        simplify-rtx.cc:8296  long el32[MAX_BITSIZE_MODE_ANY_MODE / 32];

    128 bytes on the stack where aarch64 SVE needs 1024, and the bounds check
    that would have caught it uses the same wrong constant.
  * **The 8 aggregate initialisers that FILL those arrays** --
    `FIXED_REGISTERS`, `REG_ALLOC_ORDER`, `REG_CLASS_CONTENTS`,
    `REG_CLASS_NAMES`, `REGISTER_NAMES`, `ELIMINABLE_REGS`,
    `ADDITIONAL_REGISTER_NAMES`, `NUM_MODES_FOR_MODE_SWITCHING`. Element
    counts are per back end; the array bound is the primary's. This is the
    `cl_optimization` shape a fifth time: **sized by one authority, written by
    another, no diagnostic.**
  * `MAX_BITS_PER_WORD` also sizes (11 sites) but is class (a) -- 64 on both,
    no action.

### (f) driver-only spec strings -- 12, no action

`ASM_SPEC CC1_SPEC CPP_SPEC DRIVER_SELF_SPECS ENDFILE_SPEC LIB_SPEC LINK_SPEC
STARTFILE_SPEC MULTILIB_DEFAULTS OPTION_DEFAULT_SPECS EXTRA_SPECS
EXTRA_SPEC_FUNCTIONS`. Verified by grep: every one is referenced only from
`gcc.cc`, `gen-target-specs.cc`, `spec-names.h`, `spec-functions*.cc`,
`defaults.h` -- the driver, never `cc1`. This branch's `target-specs`
mechanism already owns them. `TYPE_OPERAND_FMT` appears in no `.cc` at all.

---

## DELIVERABLE 2: WHAT MECHANISM COULD WORK

### The finding that constrains everything

The established move -- *union the vocabulary, keep data per configuration,
select at run time* -- has landed five times and it presumes **there is a value
to union**. Measured: of 127 actionable names, **91 have no value to union**
(class c) and **5 cannot be a runtime value at all** (class d). Only 28 are
the shape the branch knows how to fix, and 5 of those 28 are also class (d).

**The union approach covers 23 of 127 names cleanly.** That is the number.

### Sizing option A: compile the affected middle-end TUs per base

Measured from the build's own dependency files in `/tmp/b-objs/gcc/.deps`
(623 `.Po` files):

    TUs including tm.h                 521 / 623   (84%)
    TUs including insn-constants.h     474 / 623
    TUs including hard-reg-set.h       407 / 623   (65%)
    TUs including rtl.h                339 / 623
    TUs spelling a hazard macro directly (gcc/*.cc)     158 / 531
    headers spelling a hazard macro (gcc/*.h)            30
      including: coretypes.h defaults.h hard-reg-set.h machmode.h regs.h
                 rtl.h tree.h function.h expr.h emit-rtl.h optabs.h output.h

The 158 direct TUs is the tempting number and it is the wrong one. The 30
headers include `coretypes.h`, `rtl.h`, `hard-reg-set.h`, `machmode.h` and
`tree.h`, and `FIRST_PSEUDO_REGISTER` / `N_REG_CLASSES` set the **layout of
types** (`HARD_REG_SET`, `struct target_hard_regs`, `struct target_ira`) that
those headers declare. A TU that never spells the macro still holds a struct
whose size came from it, and passes it across a call boundary. **You cannot
compile a proper subset per base; ODR is violated the moment two TUs with
different `HARD_REG_SET` widths link.** The real cut is 407 TUs at minimum and
realistically the 521 that see `tm.h` -- i.e. per-base compilation of the
middle end is *substantially the whole compiler*, twice.

Cost, measured rather than asserted:

    total gcc/*.o in /tmp/b-objs      177.3 MB
      of which insn-*.o (93 files)     94.9 MB   (back-end generated, already per-base)
      remainder (middle end + shared)  82.4 MB
    cc1, one back end  (/tmp/b-ref1)   67.2 MB
    cc1, two back ends (/tmp/b-objs)   87.1 MB   (+19.9 MB for the 2nd back end)

Duplicating the middle end per base adds ~82 MB of objects per additional base
before link-time dedup, against a +20 MB current cost per back end -- i.e. it
makes each additional target roughly **5x more expensive**, and the growth is
in the part that was supposed to be shared. Build time scales with the same
407-to-521 TU count: the middle end compiles once today and would compile
*n_bases* times. STATE.md records an earlier experiment producing a **603 MB**
`cc1`; that is the empirical shape of this option and it is not a scare story,
it is what happened.

It also does not actually work. Per-base middle-end TUs give every back end its
own `fold_const`, its own `simplify_rtx`, its own `df_scan` -- and the middle
end holds cross-TU global state (`recog_data`, `crtl`, `cfun`, the GC roots).
Two copies of `regs_ever_live` is not a compiler.

### Sizing option B: route through `targetm`

This is what `targetm` is for and the branch has already proved the mechanism
works: `f82b65386d0` made `targetm` a pointer, byte-identical asm at five `-O`
levels, and the twelve back-end writes through it were shown to be visible at
run time rather than inferred.

For class (c) it is the *only* option that can work, because the thing that
must vary is code, not a number. It converts each of the 91 into a hook call.
Upstream GCC has already done this for most of the target macro list -- the 49
function-like macros here are, almost without exception, macros that upstream
kept because a single-target build inlines them to nothing.

The costs, honestly:

  * **91 hook conversions**, of which 49 are function-like macros in
    `addresses.h`/`regs.h`/`recog.h` inner loops. `REGNO_REG_CLASS` is called
    from `ira.cc`, `lra-constraints.cc`, `ira-costs.cc` inner loops; today it
    is `regclass_map[R]`, an array load. As `targetm.regno_reg_class (R)` it is
    an indirect call. This is a **real** compile-time regression on the primary
    and it is the one thing that would break the x86_64 byte-identity arm,
    which is currently the project's only trustworthy signal.
  * The previous session's `addresses.h` funnel finding cuts this: nine
    `#ifdef`-tested macros collapse into three inline bodies
    (`base_reg_class`, `index_reg_class`, `ok_for_base_p_1`). That is
    measured-good news and it applies to the register family only.
  * It does **nothing** for class (d). A hook cannot be evaluated by the
    preprocessor.

### Class (d) has no mechanism, and needs a per-site decision -- 11 sites

Nothing runtime reaches a `#if`. But 11 sites is small enough to enumerate,
and each has an answer:

  * `hard-reg-set.h:45,164` -- take the union `FIRST_PSEUDO_REGISTER` (95) and
    add a **build-time check** that every configured base exceeds 64 so the
    branch cannot flip. Fails by name the first time it would.
  * `rtl.h:3936-3945` -- the previous session's answer stands and I confirm the
    hazard is real: use the **maximal layout** (every `global_rtl_index`
    distinct) plus a build-time assertion that all three regnums are distinct
    per base. Both configured bases satisfy it (19/65/16 and 64/65/29).
  * `print-rtl.cc`, `dwarf2out.cc` (`NUM_UNSPEC*_VALUES > 0`) -- the guard is
    `> 0` and both bases are > 0 (312/730, 114/40). Replace the `#if` with a
    plain `if` over a runtime union value; the guarded code is diagnostic
    printing, not a hot path.

So (d) is **not** the blocker. (c) is.

### RECOMMENDATION

**The fourth arm needs a substantially different design from the one this
branch has been using, and I would say that plainly to the user.**

The branch's design is "one `cc1`, one middle end, unioned vocabulary,
runtime selection". Five landed commits show it works *for names that denote
data*. The measurement says 91 of 127 names denote **back-end code**, and for
those the design has no move: a union has nothing to union, and per-base
compilation destroys the single-middle-end premise that makes the project a
project.

Concretely, I recommend:

1. **Do not land the register-vocabulary commit as currently designed.** It
   fixes 23 of 127 names and would make the aarch64 arm *producible*. Once a
   `.s` exists the arm is very hard to keep honest -- and it would be wrong in
   at least `ASM_COMMENT_START`, `GLOBAL_ASM_OP`, `WCHAR_TYPE`,
   `DEFAULT_SIGNED_CHAR`, `BITS_PER_WORD` and every class (c) name. Two
   sessions have now refused on this ground; this is the third, with the reason
   quantified.
2. **Re-scope the fourth arm's acceptance before writing code.** "aarch64 asm
   byte-identical to a single-target reference" requires the whole of class (c)
   to be correct, because `ASM_COMMENT_START` alone breaks a byte diff. An
   arm that can only pass at the end of a 91-conversion programme is not a
   check, it is a milestone. Propose instead a **per-macro arm**: for each of
   the 127, a probe TU compiled in a multi-target `cc1` context asserting the
   name resolves to the selected base's value/behaviour. It is runnable today,
   it fails by name, and it turns one unreachable gate into 127 reachable ones.
3. **Then convert class (c) through `targetm`, incrementally, keeping the
   x86_64 byte-identity arm green at every step.** That arm is the project's
   only trustworthy signal and the indirect-call cost is exactly what would
   break it. Order by measured use count so the cheap ones land first; the
   `addresses.h` funnel (9 -> 3) is the best ratio available.
4. **Fix the (e) class first regardless of the above**, because it is memory
   corruption rather than wrong output, and because `MAX_BITSIZE_MODE_ANY_MODE`
   is 8 sites and `N_REG_CLASSES`/`FIRST_PSEUDO_REGISTER` are the ICE.

### WHAT I AM NOT CONFIDENT ABOUT

  * **The ~1049 unclassified identical-text macros.** They are non-integer on
    both bases and I did not characterise them. Most are certainly `system.h`
    and `config.h` host macros, but I did not prove it and my method cannot
    distinguish "identical string" from "differing string" -- I only know they
    are not integers. **The 137 is a lower bound, and this is where the next
    surprise lives.** The cheap next measurement is a string-valued probe over
    that set.
  * **Whether `targetm` indirect calls cost enough to break the byte-identity
    arm.** I reason that `REGNO_REG_CLASS` in `ira-costs.cc` inner loops is at
    risk. I did not build it and did not measure it. It could be free (the
    primary's hook table is constant-foldable in a single-target build) or it
    could be the thing that ends the approach. **This is the single most
    load-bearing unmeasured claim in this document** and it is one build away
    from being settled.
  * **The 158-vs-407-vs-521 TU cut.** I argued from dependency files and from
    the ODR/type-layout property that no proper subset works. I did not attempt
    a per-base build to falsify it. The argument is sound but it is an argument.
  * **Whether upstream GCC's existing hook for each of the 49 already exists**
    under a different name. I did not check `target.def` per macro. If many do,
    option B is far cheaper than I have sized it.

---

## DELIVERABLE 3: RE-VERIFICATION OF THE THREE INHERITED ARMS

Re-run from scratch this session, not inherited. Binaries unmodified:
`/tmp/b-objs/gcc/cc1` 87,118,288 bytes (2026-08-11 21:12:56),
`/tmp/b-ref1/gcc/cc1` 67,187,392 bytes (2026-08-11 21:21:49).

### Arm 1 -- aarch64 symbols: REPRODUCES EXACTLY

    nm -C lines      mt 149,666    ref 99,896     (both > 1000: tool asserted live)
    aarch64 symbols  mt 40,732     ref 0          <- matches recorded 40,732
    insn_i386::      mt 27,332     ref 27,332     <- matches recorded 27,332
    positive control: 'ix86' matches 713 lines in mt, so the grep is not dead

`nm` asserted present before any counting; the DEVSHELL near-miss (missing tool
counted as zero) cannot occur in this script.

### Arm 2 -- x86_64 byte-identity: REPRODUCES, AND IS **STRONGER** THAN RECORDED

    -O0 IDENTICAL  227 lines
    -O1 IDENTICAL  124 lines
    -O2 IDENTICAL  141 lines
    -O3 IDENTICAL  227 lines
    -Os IDENTICAL  108 lines      <- STATE.md records four levels; -Os also passes
    distinct md5s among the 5 outputs: 5   (not a file compared with itself)
    negative control: mt -O0 vs ref -O2 DIFFER (as required)

**But one thing recorded about it is misleading and should be corrected.** My
first run had the reference `cc1` fail at all five levels:

    cc1: fatal error: common target hook `option_init_struct' was used
         before a target was selected

`/tmp/b-ref1/gcc/cc1` **also requires `-ftarget-config=`**. It is the same
multi-target source tree configured with one target, not a stock single-target
GCC. STATE.md's "x86_64 asm vs SINGLE-TARGET ref" is therefore true in the
sense it was measured (`nm -C | grep -c aarch64` = 0) and **overclaims in
prose**: the arm proves *adding a second back end does not perturb the first*,
which is exactly the right thing to prove and is what the project needs. It
does **not** prove multi-target `cc1` matches unmodified GCC. Nothing on this
branch has ever compared against an unmodified GCC. That is a gap in the
record, not a regression, but the sentence should be fixed before anyone quotes
it.

### Arm 3 -- must-miss: REPRODUCES EXACTLY

    riscv symbols   0        sparc  0        rs6000  0
    insn_riscv:: / insn_arm:: / insn_mips::  0
    positive control on the same file: 713 'ix86' lines, so a 0 is a real 0

I did not re-run the two behavioural must-misses (unconfigured triple refused
by name; no target-config at all). The second reproduced **incidentally and
exactly** while I was running arm 2 -- the reference `cc1` invoked without
`-ftarget-config` printed the recorded `option_init_struct ... before a target
was selected` and exited non-zero with no fallback. That is a stronger
observation than a deliberate re-run, because it was not being looked for.

### Verdict on the inherited state

All three arms hold. Arm 2 is stronger than recorded (five `-O` levels, not
four) and its *prose description* is weaker than recorded (the reference is not
a stock GCC). No arm is weaker in substance. Both agents' refusals to land were
correct and this session's measurement supports a third refusal.

---

## ARTEFACTS -- all under /tmp/gap, nothing in the tree

    names.txt objlike.txt fnlike.txt defs.json   the 143, split by kind
    src/<MACRO>.cc                                94 isolated per-macro probes
    res-i386.txt res-aarch64.txt                  raw nm sizes, 8 bytes/macro
    vals.json buckets.json                        the classification
    errs.txt w-<base>/err-*.txt                   why each non-constant failed
    blind.txt blind-obj.txt                       the 1956 / 1604 blind spot
    blind-i386.txt blind-aarch64.txt              blind-spot values
    arith-if.txt arith-if-wide.txt                the complete class (d) sweep
    alloc.txt                                     class (e) sites
    asm/{mt,ref}-O{0,1,2,3,s}.s                   arm 2, re-run this session
    nm-mt.txt nm-ref.txt                          arms 1 and 3, re-run
    *.sh *.py                                     every script, re-runnable

Positive controls that make the numbers believable: the 7 previously-measured
values (`FIRST_PSEUDO_REGISTER` 92/95, `N_REG_CLASSES` 34/20, the four regnums,
`MAX_BITSIZE_MODE_ANY_MODE`, `DEFAULT_SIGNED_CHAR`) are re-derived by a
different probe encoding and **all 7 match**, asserted in `cls.py` so a
mismatch aborts rather than prints.
