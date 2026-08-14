# The ASAN `cc1`: both corruptions named, one fixed, one is design

Build: `/tmp/b-agent-ab1fcb485731b7a4d`, configured from the immutable snapshot
`/tmp/snap-agent-ab1fcb485731b7a4d`, **anchor 49**, clean tree, eleven back ends
(`t170-bases11.txt`), `CXXFLAGS='-fsanitize=address -fsanitize=undefined
-fno-sanitize=vptr -fno-omit-frame-pointer -g -O1'`, `make -k -j6 all-gcc`
**rc=0 with the `.rc` stamp written after `make` returned**, 0 `error:`,
0 `multiple definition`, 0 `undefined reference`. `cc1` is 2,155,353,152 bytes.
Scripts: `tab1-*.sh`, named after the full worktree id.

## 0. Two things the brief predicted that measured FALSE

- **"an ASAN build will not reproduce byte-identical output, so score the bars
  on a normal build."** It does. On this ASAN `cc1`, at eleven bases:

  ```
  cc1 -quiet -nostdinc -O2 -ftarget-config=<specs-config> scratchpad/big.c -o x.s
    x86_64-pc-linux-gnu   md5 378fc33c1e70   5/5 runs   <- the recorded bar
    specs-config x86_64   wc -l 230  grep -c . 222  md5 a6c4c68bdf33  <- the bar
  ```

  Both bars are met by the sanitized compiler, so no separate normal build was
  needed to score them and none was made. What ASAN changes is address layout
  and speed, not the code `cc1` emits.

- **"ia64 is the back end whose `FIRST_PSEUDO_REGISTER` is the union maximum
  (334), so anything sized by another base's value and indexed by ia64's will
  overflow — check that first, it is the most likely answer."** Right about the
  shape, wrong about the back end. The union-bound overflows all belong to
  **mips64** (188 wide, indexed to 334, and 334 is ia64's number). ia64's
  corruption is a different mechanism entirely — see §2.

## 1. mips64 — NAMED AND FIXED: `mips_hard_regno_mode_ok_p`

First run of the sanitized `cc1`, where twelve un-sanitized runs could only say
"5 emit, 7 SIGSEGV":

```
config/mips/mips.cc:13404: runtime error: index 188 out of bounds
  for type 'bool [188]'
AddressSanitizer: global-buffer-overflow, READ of size 1
0 bytes after global variable `mips_hard_regno_mode_ok_p'
  (config/mips/mips.cc:516) of size 114492
```

Five shared walks arrived there, each found by re-running after the previous
was fixed, or converted with them as siblings of the identical shape:

| walk | file |
|---|---|
| `predefined_function_abi::initialize` (3 loops) | `function-abi.cc:67, :89, :103` |
| `init_reg_modes_target` (2 loops) | `reginfo.cc:650, :659` |
| `init_expr_target` | `expr.cc:155` |
| `init_alias_target` | `alias.cc:3290` |
| `ira_init_register_move_cost`, prohibited-mode-move | `ira.cc:1634, :1816` |

All walked `0 .. FIRST_PSEUDO_REGISTER` — the union's **334**, which is ia64's
— and handed the index to `targetm.hard_regno_mode_ok`, which mips answers from
a table **188** wide. This is PRINCIPLES' "the bound is the union's, the
numbering is per base", the same shape as `simplifiable_subregs` and arm's
`ira_init` `memcpy`. Fixed by bounding each with `MT_FIRST_PSEUDO_REGISTER`
while every array they write keeps the union LAYOUT.

**Not converted, having been read**: `combine.cc:1959, :2143, :2397` and
`expr.cc:780` test `REGNO (x) < FIRST_PSEUDO_REGISTER` on a register that
exists in the insn stream — a hard-vs-pseudo test, not a walk. `recog.cc:3823`
walks but distributes through `MT_HAVE_REG_ALLOC_ORDER`; left for the sanitizer
to judge rather than converted on inspection.

**After the fix: zero ASAN reports for mips64, and the residual is §3.**

## 2. ia64 — NAMED, AND THE FIX IS DESIGN: two authorities for `state_size ()`

```
AddressSanitizer: heap-buffer-overflow, WRITE of size 116
  #2 ia64_variable_issue            config/ia64/ia64.cc:7689
  #3 schedule_block                 haifa-sched.cc:6939
0 bytes after 4-byte region, allocated by
  #2 ia64_init_dfa_pre_cycle_insn   config/ia64/ia64.cc:9661
```

6 of 6 runs, the same report every time. The 4 and the 116 are both real and
both correct for their own back end:

```
mt-ia64/insn-automata-ia64.cc:10987   struct DFA_chip { unsigned short x2; }   ->  4
mt-i386/insn-automata-i386.cc:100497  struct DFA_chip { 87 members }           -> 116
```

`ia64_init_dfa_pre_cycle_insn` sets the SHARED global `dfa_state_size`
(`haifa-sched.cc:347`) from **its own** `insn_ia64::state_size ()` = 4 and
allocates `temp_dfa_state` and `prev_cycle_state` at that size. `sched_init`
then runs `dfa_start (); dfa_state_size = state_size ();` — the **bare**
symbol, i.e. i386's — overwriting the global with **116**. The next
`ia64_variable_issue` copies 116 bytes into the 4-byte buffer, on every
scheduled insn.

This is exactly the residual `gcc/target-sched.h` already declares in its own
header comment: *"`haifa-sched.o` and the rest of shared scheduling still bind
the BARE `internal_dfa_insn_code`, `state_transition`, `insn_latency` and
`dfa_start`, i.e. they still schedule every target's insns against the
primary's automaton."* What is new here is that the family is not merely
*inaccurate* for other targets — it **smashes the heap** for any back end whose
`DFA_chip` is smaller than the primary's, which is most of them.

**Handed back as design, not fixed here** (PRINCIPLES §2b). Every local repair
available is on the §2a list: sizing ia64's buffers by the bare `state_size ()`
gives ia64 i386's state and is the primary's answer wearing a bug fix's
clothes; taking a `MAX` of the two is a floor. The real fix is a selector for
the whole `insn-automata` family — `state_size`, `state_transition`,
`state_reset`, `dfa_start`, `min_issue_delay`, `insn_latency`,
`max_insn_queue_index` — so that shared scheduling asks the SELECTED base's
automaton. `mt_init_base_sched_attrs` is the precedent for the shape; note that
one was deliberately **additive**, and this one cannot be: `dfa_state_size` has
one storage location and two writers, so the second writer must be made to
agree rather than to run afterwards.

## 3. What remains on mips64, and what the instrument cannot see

After §1, `scratchpad/big.c -O2`, ten runs:

```
5  rc=4   ICE: in as_a, at machmode.h:416   (RTL pass expand)
5  rc=1   ASAN: SEGV on unknown address 0x....8a2e0, READ,
          passes.cc:2174 in execute_function_todo
```

- The `as_a`/`machmode.h:416` half is the **shared wall the brief marks DO NOT
  TOUCH**; ia64 at `-O0` on the same input reaches it too, deterministically.
  Under `gdb` (ASLR off) mips64 hits it **3 of 3**.
- The SEGV half is still unnamed. ASAN says *"can not provide additional
  info"*: the faulting address is in no ASAN-known region, and its low bits are
  **identical across runs** while the high bits move with ASLR — a real
  pointer, into a region ASAN does not own. That points at GGC, which mmaps its
  own pages; **and the GC arms refute it as stated**: `tab1-ggc.sh` at
  `--param ggc-min-expand=0 --param ggc-min-heapsize=0` (collect always) and at
  4 GB thresholds (never collect) both reproduce the same two-outcome split.
  So: not simply "collected too soon", and no allocation is named yet.

**Blind spots of this instrument, stated:** ASAN cannot see an overflow inside
a GGC page, inside an obstack, or inside any union-sized array that is written
in bounds with another base's data — which is most of this project's bug class.
A clean ASAN run is evidence about wild addresses, not about correctness.

## 4. Controls

```
x86_64   5/5 rc=0  md5 378fc33c1e70   = the recorded bar, byte for byte
aarch64  3/3 rc=0  md5 892572cba51b   (its specs-config md5 is 1b8afb792629,
                                       not the recorded f1a5ab201d95, so the
                                       recorded aarch64 byte count is NOT
                                       comparable and is not quoted)
```

Both stable, no ASAN reports, so the mips64 and ia64 readings are properties of
those back ends and not of the sanitized build or of the machine.

`ASAN_OPTIONS=detect_leaks=0` is required to BUILD (GCC's generators leak by
design; LeakSanitizer makes `genhooks`, `genmodes` and `gengtype` exit 23), and
`handle_segv=2:allow_user_segv_handler=0` is required to RUN: GCC installs its
own `SIGSEGV` handler (`toplev.cc:329`), so without it a fault ASAN could have
described is printed as a bare "internal compiler error: Segmentation fault"
and **the ASAN log is empty** — which reads exactly like a clean run.
