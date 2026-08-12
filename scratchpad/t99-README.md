# Task #99 / #86 — the fragment-scan instrument, and what it measured

Run from the worktree root, with an absolute `srcdir`:

    sh scratchpad/t99-frag-dump.sh <abs>/gcc > targets.txt
    awk -v srcdir=<abs>/gcc -f scratchpad/t99-frag-scan.awk targets.txt
    xargs awk -f scratchpad/t99-frag-rules.awk < <(find <abs>/gcc/config -name 't-*')

`t99-frag-dump.sh` sources `config.gcc` once per `--enable-backends=all`
target (the same `contrib/config-list.mk` list `gcc/configure.ac` reads) and
prints `triple|cpu_type|tmake_file_present|extra_objs|c_target_objs|out_file`.
188 targets, zero stderr.

`t99-frag-scan.awk` runs TWO matchers over that and prints only the
disagreements:

  * `cur()` is `frag_source_for()` transcribed verbatim from
    `gcc/gen-multi-target-md.awk:108` — physical lines, `^<obj>\.o[ \t]*:`,
    follow `\`.
  * `thorough()` joins `\` continuations into LOGICAL lines first, accepts the
    object ANYWHERE in a multi-target rule's target list, tolerates leading
    whitespace and `::`, skips `:=` assignments, and distinguishes
    "rule exists, prerequisite is an UNDECLARED generated name" from
    "rule exists, no source at all".

`t99-frag-rules.awk` is the population, not the sample: every `.o` rule target
in every `config/**/t-*`, classified by why the current matcher would or would
not score it.

## THE RESULT: THERE IS NO FRAGMENT-SCAN GAP

209 fragments, **212 `.o` rule targets**. Exactly **one** is not the first
target on its logical line — `config/avr/t-avr:67`, `avr.o avr-c.o:
$(srcdir)/config/avr/builtins.def` — and that line names a `.def`, not a
source, so it claims nothing; `avr-c.o`'s real claim is at `t-avr:54` in the
shape the current matcher already reads. Net: **212/212 matchable, gap = 0.**

Nothing in the tree exercises the `UNDECLARED` class either: zero rules name a
bare generated `.cc` that no fragment declared in `generated_files +=`. The
rs6000 shape (#82) is the only instance and it is already handled.

So the brief's premise — "the awk's notion of which fragments declare rules is
incomplete in at least two independent ways" — did not survive measurement.
It is incomplete in **zero** ways. The multi-target rule shape the brief warned
about (`a.cc a.h: s-a`) is real, but it is a hazard for the *header/generated
file* scans, not for `frag_source_for`, which only ever looks at `.o` rules.

## WHAT xtensa ACTUALLY WAS: A `config.gcc` DEFECT, UPSTREAM

`config/xtensa/t-xtensa:23` does carry the rule. The awk never saw it because
**`xtensa-unknown-elf`'s `tmake_file` is empty** — the fragment is not in it:

    xtensa-unknown-elf|xtensa||xtensa-dynconfig.o| default-c.o|xtensa/xtensa.cc
                              ^^ tmake_file_present

`config.gcc:646` sets `extra_objs="xtensa-dynconfig.o"` in the `xtensa*-*-*)`
cpu_type block — every xtensa triple — while `xtensa/t-xtensa` is added only by
`xtensa*-*-linux*` and `xtensa*-*-uclinux*`. The `-elf` case declares an object
and no fragment claiming a rule for it. **The refusal was correct**, and per
PRINCIPLES 2a relaxing it would have been the wrong move: the thing it objected
to is real.

Fixed in `config.gcc` by adding the fragment to the `-elf` case, which is where
the tree is wrong.

**This is an upstream GCC bug, not a branch artefact.** Identical at the merge
base `c31b7a09eea`. Upstream's `OBJS` contains `$(EXTRA_OBJS)`
(`Makefile.in:1873` there), and `gcc/Makefile.in` has `VPATH = @srcdir@` with
no `vpath %.cc`, so the `.cc.o` suffix rule looks for
`$(srcdir)/xtensa-dynconfig.cc` and does not find it either. A stock
single-target `xtensa-*-elf` build should therefore fail with "No rule to make
target 'xtensa-dynconfig.o'". **Argued from the makefile text, NOT built** —
that is the limit of this claim and it is worth confirming before reporting it
upstream.

## #86 — CONFIRMED, AND WORSE THAN THE BRIEF SAID

The brief suspected a depfile-name collision and offered "two agents sharing a
build dir" as an alternative explanation. The collision is **structural**, not
concurrent, and there are THREE failures, not one.

`$(COMPILE)`/`$(POSTCOMPILE)` (`Makefile.in:1499`) name the depfile
`$(@D)/$(DEPDIR)/$(*F).TPo`. In a PATTERN rule `$*` is the stem. The rules were

    insn-emit-<cpu>-%.o:  mt-<cpu>/insn-emit-<cpu>-%.cc
    insn-recog-<cpu>-%.o: mt-<cpu>/insn-recog-<cpu>-%.cc

so the stem is the shard NUMBER alone and four objects wrote `./.deps/<N>.TPo`.

But `Makefile.in:6100` READS depfiles under a different name entirely:

    DEPFILES = $(foreach obj,$(ALL_HOST_OBJS),\
                 $(dir $(obj))$(DEPDIR)/$(patsubst %.o,%.Po,$(notdir $(obj))))

i.e. `./.deps/insn-emit-i386-1.Po` — a name nothing ever wrote. So:

  1. four writers, one file, racing under `-j` (the `mv: cannot stat` symptom);
  2. `-include $(DEPFILES)` matched **nothing** for every split object of every
     back end — no header dependency tracking at all, silently, in every build;
  3. where a same-named file happened to survive from an OLDER generator, the
     `-include` read a **stale** list naming a source path that no longer
     exists — worse than nothing.

All three observed in the shared `/tmp/b-objs` (read-only; not my fixture, so
this is corroboration, not the primary evidence):

    .deps/1.Po                    Aug 12 11:58, contents:
        insn-recog-aarch64-1.o: mt-aarch64/insn-recog-aarch64-1.cc ...
      -> one of four writers won the name; DEPFILES never reads it
    .deps/insn-emit-aarch64-1.Po  Aug 11 16:08, contents:
        insn-emit-aarch64-1.o: insn-emit-aarch64-1.cc ...
      -> DEPFILES DOES read this; it is stale, from before the mt-<cpu>/ move,
         and names a build-root source that is no longer the prerequisite
    .deps/insn-emit-i386-*.Po     ABSENT ENTIRELY
      -> i386's twenty split objects had no dependency information at all

Upstream is unaffected because upstream has no pattern rule for these: they go
through the `.cc.o` SUFFIX rule, where `$*` is the target minus the suffix
(`insn-emit-1`), which is what DEPFILES expects. Every other rule
`gen-multi-target-md.awk` emits is explicit and gets the same `$*` for the same
reason (`.o` is in `.SUFFIXES`, `Makefile.in:51`). **These two rules were the
only ones in the generated makefile whose depfile name disagreed with
`Makefile.in`'s.**

Fix: emit them as explicit rules, instantiated with `$(foreach)`/`$(eval)`
because the shard list is a make variable. The generated `multi-target-md.mk`
diff is exactly two hunks, one per back end; the other 1605 of 1619 lines are
byte-identical.

Instrument blind spots, stated: `t99-frag-rules.awk` only classifies rule
targets ending in `.o`, so a rule whose target is a make variable
(`$(out_object_file):`) is invisible to it — those are prerequisite-only rules
and claim no source, but I did not prove that exhaustively. `t99-frag-scan.awk`
reads `tmake_file` as `config.gcc` computes it in THIS shell; `config.gcc`
consults ~70 `enable_*`/`with_*` variables that a real configure would have
set, so a triple whose fragment list depends on one of those could differ.
188/188 targets sourced with empty stderr, which bounds but does not eliminate
that.
