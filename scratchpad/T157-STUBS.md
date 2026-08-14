# T157 — the stub register

The user relaxed the correctness bar for task #157: *"just get those backends
building — even if everything is busted it's OK, we'll figure it out."*
PRINCIPLES §2a's ban on stubs and floors is suspended **for link-level fixes on
this task only**, on two conditions, and this file is the second one:

1. prefer `gcc_unreachable ()` or a fail-by-name abort over a plausible wrong
   value — a stub returning the primary's answer is the one thing that will be
   genuinely hard to find later;
2. **record every stub in one committed list**, so the correctness pass gets a
   work queue instead of an archaeology problem.

## Stubs left by this task

**NONE.**

That is a real entry, not an empty section. Every change made for #157 supplies
a genuine per-base answer, and it is worth saying which kind each one is,
because "no stubs" is exactly the claim a later reader will want to re-check:

| change | what it supplies | whose answer |
|---|---|---|
| `print_operand`, `print_operand_address`, `regclass_map` renamed per base | each back end keeps its own definition | its own — no shared TU names the bare symbol at all |
| `legitimize_pic_address` renamed per base | same | its own |
| `legitimate_pic_operand_p` → 5th `target_addr` funnel | `LEGITIMATE_PIC_OPERAND_P` evaluated in each base's own preprocessor context | its own, incl. `defaults.h`'s `1` read under *its* `tm.h` |
| genpreds singular `insn-preds.cc` redirect | routes one macro out of a shared object | the selected base's |
| gengtype installer reset + name check | dispatchers null for tags this base lacks; `gt_multi_target_no_marker` fails **by name** at the point of use | fail-by-name, no value invented |
| genenums empty `unspec`/`unspecv` tables | length **0** for an md that defines no such enum | its own — counted from that md, and what upstream behaves as |
| `HAVE_BFmode` guard (`tree.cc`) | no `bfloat16_type_node` for a base without BFmode | its own — exactly upstream's behaviour for it |
| `widest_int_mode_for_target ()` | widest int mode the **selected** base has | its own; `gcc_unreachable ()` rather than a floor if a base had none |

**No fallback anywhere in the above is another back end's value.** The
suspension was available and was not needed.

## Not fixed, and NOT stubbed — the real work queue

These are open walls, left failing loudly rather than papered over. None of
them is a stub; they are listed here because this is the file the correctness
pass will read.

- **#154 — riscv driver `SIGSEGV`.** Confirmed live at `98184824b07`:
  `riscv64-unknown-linux-gnu-gcc -c fn.c` exits **139**. `-dumpspecs` and `-v`
  are fine; only a real compilation reaches `set_multilib_dir`.
  `multilib.h` is generated once, so `multilib_select` is a single shared
  authority, and `riscv_compute_multilib` (`common/config/riscv/riscv-common.cc:2135`)
  does `p = multilib_select; while (*p != '\0')` with no null check.
  Fixing it properly means `multilib.h` per base. **`cc1` is unaffected — this
  is the driver only.**
- **s390 `default_function_value_regno_p`, `targhooks.cc:1153`,
  `gcc_unreachable ()`.** Reached during RTL combine for s390x on a four-base
  `cc1`. This is the targhook DEFAULTS matrix, which another agent owns and
  which #157's brief put out of bounds — deliberately not touched.
- **`MAX_MODE_INT` read as a MODE at five more sites**, same defect as the one
  converted, not swept because nothing measured them:
  `optabs.cc:8349`, `simplify-rtx.cc:2048`, `simplify-rtx.cc:2085`,
  `simplify-rtx.cc:7239`, `combine.cc:7475`. Read as a BOUND — a different
  question, possibly fine — at `dse.cc:1745` and `rtlanal.cc:79`.
- **`type_natural_mode`, `config/i386/i386.cc:2155`.** x86_64 `-O2` on
  `scratchpad/big.c` ICEs at `v4si f_vec (v4si a, v4si b)` in a **three**-base
  and a **four**-base build, at the same commit. The recorded bar
  (12369 bytes / `378fc33c1e70`) is a **two**-base figure. Tracks base count,
  not any #157 change — every one of those is a no-op when i386 is selected —
  but the two-base control at this commit is named in the report as **not
  measured**.
