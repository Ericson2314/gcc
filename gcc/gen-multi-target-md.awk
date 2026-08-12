# Copyright (C) 2026 Free Software Foundation, Inc.
#
# This file is part of GCC.
#
# GCC is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# GCC is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with GCC; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.

# Read multi-target.manifest (written by configure) and emit make rules for
# the machine-description headers that must exist once per back end rather
# than once per build:
#
#	tm-preds-<base>.h	predicate declarations	 (genpreds -h)
#	tm-constrs-<base>.h	constraint accessors	 (genpreds -c)
#	tm_p-<base>.h		the back end's private protos + the above
#	insn-flags-<base>.h	HAVE_<pattern>		 (genflags)
#	insn-conditions-<base>.md  each condition's truth value, or -1
#				(genconditions -> gencondmd-<base> -> run it)
#
# where <base> is the cpu_type.  The single-target tm-preds.h / tm-constrs.h
# / tm_p.h rules in Makefile.in stay as they are; these are additional files
# under distinct names, so nothing collides.
#
# The manifest is a sequence of blank-line separated records of "key value..."
# lines.  Several configured targets share a cpu_type (e.g. every aarch64-*
# triple); they also share md_file and tm_p_file, so the first record for a
# given cpu_type wins and the rest are skipped.

function reset() {
  trg = ""; cpu = ""; md = ""; tmp = ""; xmodes = ""; cof = ""; inc = ""; def = "";
  tmk = ""; tmkp = ""; outf = ""; xobjs = "";
}

# Record the build-directory headers a t-<...>-headers fragment generates, so
# that <cpu>-inc/s-inc can depend on them.
#
# This is not tidiness.  The rules ARE included (just above) and the headers ARE
# generatable, but a rule nothing depends on is never run: aarch64-builtins.cc
# failed on a missing aarch64-builtin-iterators.h for exactly that reason, and
# the failure reads as a missing rule rather than a missing dependency.  Absence
# of an artefact is not absence of a rule -- this file's own history has three
# instances of that confusion -- so the cure is to name the artefact.
#
# The fragment states what it generates in `generated_files +=', which is the
# form gcc/Makefile.in already reads and therefore the only claim in the tree
# about these names.  It is read rather than a list kept here, so the two
# cannot drift.  Note `generated_files' itself cannot be used at make time:
# Makefile.in assigns it with `=' at a line AFTER multi-target-md.mk is
# included, so every `+=' a fragment did is silently discarded.
function scan_hdr_frag(path,	line, i, n, parts) {
  while ((getline line < path) > 0) {
    if (line !~ /^[ \t]*generated_files[ \t]*\+=/)
      continue;
    sub(/^[ \t]*generated_files[ \t]*\+=[ \t]*/, "", line);
    n = split(line, parts, "[ \t]+");
    for (i = 1; i <= n; i++)
      if (parts[i] != "" && parts[i] != "\\" &&
	  !((cpu SUBSEP parts[i]) in seen_hdrgen)) {
	seen_hdrgen[cpu SUBSEP parts[i]] = 1;
	hdrgen[cpu] = hdrgen[cpu] " " parts[i];
      }
  }
  close(path);
}

# The source that builds <obj>.o, as claimed by this target's tmake_file
# fragments.
#
# `extra_objs' names OBJECTS, never sources, and the mapping is not derivable
# from the name: aarch-common.o is built from config/arm/aarch-common.cc by a
# rule in config/aarch64/t-aarch64, and linux.o from config/linux.cc by
# config/t-linux.  Guessing config/<cpu>/<obj>.cc gets both wrong -- and gets
# them wrong SILENTLY if some file happens to exist under the guessed name.
#
# So read the fragments, which is where the tree actually states it.  Two
# details the first version of this scan got wrong, both measured:
#
#   * Rules are written `foo.o: \' with the source on a continuation line, so
#     matching only the target's own physical line under-read by 12% (18 of 153
#     objects) and reported "no rule found" for the wrong reason.  Follow `\'.
#   * The RECIPES are not reusable and are deliberately ignored.  The 195 `.o'
#     rules across config/**/t-* reduce to two families, `$(COMPILE) $<' and an
#     older `$(COMPILER) -c ... <src>' with no `-o' at all, and the second
#     cannot name mt-<cpu>/<obj>.o even if we wanted it to.  Only the source is
#     taken from the fragment; the recipe is generated uniform.
#
# Returns "" when nothing claims the object, and the caller refuses rather than
# guesses.
function frag_source_for(obj, frags,	i, n, parts, path, line, cont, tok, j, m, toks) {
  n = split(frags, parts, " ");
  for (i = 2; i <= n; i++) {
    path = srcdir "/config/" parts[i];
    cont = 0;
    while ((getline line < path) > 0) {
      if (!cont) {
	if (line !~ ("^" obj "\\.o[ \t]*:"))
	  continue;
	cont = 1;
      }
      m = split(line, toks, "[ \t]+");
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^\$\(srcdir\)\/config\/.*\.(cc|c)$/) {
	  close(path);
	  return toks[j];
	}
      cont = (line ~ /\\$/);
      if (!cont)
	break;
    }
    close(path);
  }
  return "";
}

# Has this back end been converted to the 2-coefficient poly_int discipline?
#
# It declares that by adding -DTARGET_POLY_AWARE to its own objects in
# config/<cpu>/t-<cpu>, and that declaration is the ONLY source of truth here:
# a list in this file would be a second place to say the same thing, and the
# two would drift apart exactly once.
#
# The reason this function has to exist at all is the sentence a few lines
# below: a multi-target build includes no target's tmake_file.  Only the
# PRIMARY target's fragments are read (-include $(tmake_file)), so an opt-in
# that lives in a fragment reaches its own back end only when that back end
# happens to be the one the build was configured for.  That is not a leak --
# the per-object CFLAGS- scoping fixed the leak -- it is the opposite failure:
# the flag is WITHHELD from a converted back end, whose sources then no longer
# compile.  i386 and arm both hit it; arm is simply the first that was ever
# built as a non-primary target with a converted i386 alongside it.
#
# Only build/gencondmd-<triple>.o needs it.  genconditions.cc:74 writes
# `#define IN_TARGET_CODE 1' into the file it generates, so gencondmd is
# target code and gets ONLY_FIXED_SIZE_MODES; genconditions.o and
# genpreds-<cpu>.o are compiled from shared sources that define no such thing,
# and the compiler proper's per-back-end objects do not exist yet outside the
# primary target.  Widen this when they do.
#
# MEASURED, so that "widen this when they do" is a schedule item and not a
# worry: in an x86_64-primary + nds32 build the only compiler-proper object
# built for the non-primary back end is common/config/nds32/nds32-common.o,
# and `nm -C cc1' finds four nds32 symbols, all of them from that file,
# against 694 ix86_* ones.  config/nds32/nds32.cc is not compiled and not
# linked.  So the withheld flag currently has nowhere to land on the .cc side
# -- the code is absent, not mis-flagged -- and no build can be constructed
# that would fail for want of it.  Whoever adds the per-back-end compiler
# objects to OBJS must call this function when they do; that is the moment the
# hazard becomes reachable.
#
# A COMMENT IS NOT A DECLARATION.  This used to match anywhere on the line, so
# a fragment that merely MENTIONED the flag -- "do not add -DTARGET_POLY_AWARE
# until the .md is converted" is the obvious thing to write -- would be read
# as an opt-in, and that back end's gencondmd would be compiled poly-aware
# against unconverted conditions.  No fragment does that today, which is
# exactly why it had to be fixed today: the must-hit control for this function
# is drawn from the ten fragments that DO declare it, and by rule 20 no member
# of that population can exhibit the misclassification.  Calibrated against a
# synthetic fragment instead -- see scratchpad/pz-polyaware-selftest.sh.
function poly_aware(c,   frag, line, found) {
  if (c in poly_aware_cache)
    return poly_aware_cache[c];
  frag = srcdir "/config/" c "/t-" c;
  found = 0;
  while ((getline line < frag) > 0) {
    sub(/#.*/, "", line);
    if (index(line, "-DTARGET_POLY_AWARE") > 0)
      found = 1;
  }
  close(frag);
  poly_aware_cache[c] = found;
  return found;
}

# A few triples name a GENERATED header in their tm_file: sysroot-suffix.h or
# linux-sysroot-suffix.h, built by a tmake_file fragment.  A multi-target build
# includes no target's tmake_file, so the rule has to be reproduced here -- the
# same problem the t-<cpu>-headers fragments solve for arm-isa.h and
# gcn-device-macros.h, except that this one is per TRIPLE: of sh's four
# configured triples all four want one, of m68k's fourteen only two do.
#
# The work of deciding WHAT such a header should contain is already done, by
# gen-sysroot-suffix.sh, which configure invokes for the per-back-end
# sysroot-suffix-<base>.h.  That script takes a triple, so it serves here
# unchanged; calling it is better than reproducing its reasoning, which is
# subtle and which it documents at length:
#
#   - config/print-sysroot-suffix.sh, reached through the t-sysroot-suffix
#     fragment, is a pure transformation of MULTILIB_OSDIRNAMES / OPTIONS /
#     MATCHES / REUSE, so it gives the same answer wherever it runs.
#   - config/m68k/print-sysroot-suffix.sh and config/bfin/print-sysroot-suffix.sh
#     `test -d "$sysroot/$dir"', probing the build machine's filesystem for a
#     target sysroot a multi-target build does not have.  For those the script
#     writes an honestly empty header saying so, rather than a guess.
#
# What is per TRIPLE is WHICH triples want one at all: of sh's four configured
# triples all four do, of m68k's fourteen only two.  So the header follows tm.h
# down to the triple like everything else here.
#
# These rules run in parallel with each other, which
# config/print-sysroot-suffix.sh could not survive until recently: it wrote its
# helper scripts into the CURRENT directory under fixed names, so two copies
# clobbered each other mid-execution (`Text file busy', status 126, under
# -j12).  That is fixed in the script itself now -- it works in a directory of
# its own -- so nothing is needed here.  Recorded because the caller-side
# workaround that used to be here looked like tidiness and was not.
function emit_sysroot_suffix(key,	hdr) {
  if (inc ~ /(^| )linux-sysroot-suffix\.h( |$)/)
    hdr = "linux-sysroot-suffix.h";
  else if (inc ~ /(^| )sysroot-suffix\.h( |$)/)
    hdr = "sysroot-suffix.h";
  else
    return "";

  printf "sysroot-suffix-%s.h: multi-target.manifest multi-target.multilib \\\n", key;
  printf "  $(srcdir)/gen-sysroot-suffix.sh\n";
  printf "\t$(SHELL) $(srcdir)/gen-sysroot-suffix.sh %s \\\n", trg;
  printf "\t  multi-target.manifest multi-target.multilib $(srcdir) \\\n";
  printf "\t  > tmp-sysroot-suffix-%s.h\n", key;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-sysroot-suffix-%s.h $@\n\n", key;
  return hdr;
}

function flush(	i, n, parts, hdrs, modes, modesdep, objs, junk) {
  if (cpu == "")
    { reset(); return }

  # Which back end serves this triple.  Recorded for EVERY record, not just the
  # first for a cpu_type: several triples share a back end, and the selector is
  # asked for a triple -- the name in the target-config file -- while the
  # objects, the namespace and the mode tables are per back end.  Nothing else
  # in the tree holds that map.  See emit_backend_registry.
  if (!(trg in mt_base_of)) {
    mt_base_of[trg] = cpu;
    mt_targets = mt_targets " " trg;
  }

  # Every record gets its per-triple conditions rules; only the first record
  # for a back end gets the per-back-end ones.  The per-triple rules name
  # $(MULTI_TARGET_GEN_OBJS_<base>) as a prerequisite, and make expands
  # prerequisites as it reads the file, so they have to come AFTER the
  # assignment below -- emitting them first left the first triple of every back
  # end linking against nothing and failing on `undefined reference to
  # progname'.
  if (seen[cpu])
    { emit_triple(); reset(); return }
  seen[cpu] = 1;

  # Reading a back end's .md means knowing its machine modes: the md files
  # name modes such as CC_Z or V64SI that only that back end's *-modes.def
  # defines, and a generator built for some other target rejects them as
  # "unknown mode".  So each back end gets its own genmodes, its own
  # min-insn-modes.cc, and its own genpreds linked against that.
  #
  # Which file that is comes from the manifest's extra_modes, which configure
  # took from config.gcc -- not from the <cpu>/<cpu>-modes.def naming
  # convention, which most but not all back ends happen to follow.
  #
  # A few back ends generate headers of their own (arm-isa.h from
  # arm-cpus.in, gcn-device-macros.h from gcn-devices.def) which their config
  # headers include by name.  Those rules normally come from the target's
  # tmake_file, and a multi-target build includes no target's tmake_file, so
  # they have been factored into t-<cpu>-headers fragments that are safe to
  # include for every back end at once.  The names they generate are already
  # unique across back ends, so nothing collides.
  if ((getline junk < (srcdir "/config/" cpu "/t-" cpu "-headers")) >= 0) {
    close(srcdir "/config/" cpu "/t-" cpu "-headers");
    if (!((cpu "/t-" cpu "-headers") in seen_hdr_frag)) {
      seen_hdr_frag[cpu "/t-" cpu "-headers"] = 1;
      printf "include $(srcdir)/config/%s/t-%s-headers\n", cpu, cpu;
    }
    scan_hdr_frag(srcdir "/config/" cpu "/t-" cpu "-headers");
  }

  # ... and the same for any OTHER fragment this target uses.  Keying only on
  # cpu_type is not enough: vms generates vms-crtlmap.h from config/vms/t-vms,
  # but alpha-dec-vms has cpu_type `alpha', so a cpu-keyed include never
  # reaches config/vms/t-vms-headers and the header has no rule at all.  OS and
  # vendor fragments are as entitled to generate a header as cpu ones are.
  #
  # tmake_file_present is used rather than tmake_file because it is already
  # filtered to the fragments that exist, and it is per target, so this walks
  # every triple's list -- deduplicated here since several triples of one back
  # end name the same fragments and a second `include' would give every rule a
  # duplicate recipe.
  n = split(tmkp, parts, " ");
  for (i = 2; i <= n; i++) {
    if ((getline junk < (srcdir "/config/" parts[i] "-headers")) >= 0) {
      close(srcdir "/config/" parts[i] "-headers");
      if (!((parts[i] "-headers") in seen_hdr_frag)) {
	seen_hdr_frag[parts[i] "-headers"] = 1;
	printf "include $(srcdir)/config/%s-headers\n", parts[i];
      }
      scan_hdr_frag(srcdir "/config/" parts[i] "-headers");
    }
  }

  if (xmodes != "") {
    modes = "config/" xmodes;
    modesdep = " $(srcdir)/" modes;
    printf "build/genmodes-%s.o : BUILD_CPPFLAGS += -DTARGET_EXTRA_MODES_FILE='\"%s\"'\n", cpu, modes;
  } else {
    modesdep = "";
    printf "build/genmodes-%s.o : BUILD_CPPFLAGS += -DTARGET_NO_EXTRA_MODES\n", cpu;
  }
  # Remember this back end for the union run emitted at END.  The order is
  # the manifest's, which is configure's, so the shared numbering is stable
  # between runs of this script for one configuration.
  union_cpu[++n_union_cpu] = cpu;
  union_modes[cpu] = xmodes;

  # Every run places its tables against the SHARED numbering, and announces
  # which back end it is so that a name two back ends define and disagree
  # about is attributed correctly.  Without `-U' each back end's enum is dense
  # over its own modes and `SImode' is a different integer in each -- silently,
  # with no link error.  See MODES_UNION_FLAGS in Makefile.in.
  ufl = sprintf("-U modes-union.list -A %s", cpu);

  printf "genprogerr += modes-%s\n", cpu;
  printf "build/genmodes-%s.o : genmodes.cc $(BCONFIG_H) $(SYSTEM_H) errors.h \\\n", cpu;
  printf "  $(HASHTAB_H) machmode.def%s\n", modesdep;
  printf "\n";
  printf "insn-modes-%s.h: build/genmodes-%s$(build_exeext) modes-union.list\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) %s -h > tmp-modes-%s.h\n", cpu, ufl, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-%s.h $@\n", cpu;
  printf "insn-modes-inline-%s.h: build/genmodes-%s$(build_exeext) modes-union.list\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) %s -i > tmp-modes-inline-%s.h\n", cpu, ufl, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-inline-%s.h $@\n", cpu;
  printf "min-insn-modes-%s.cc: build/genmodes-%s$(build_exeext) modes-union.list\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) %s -m > tmp-min-modes-%s.cc\n", cpu, ufl, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-min-modes-%s.cc $@\n\n", cpu;
  # The full mode tables, as opposed to the -m subset the generators link
  # against.  This is a cc1 object, not a build/ one: it carries mode_size,
  # mode_precision and the rest for THIS back end's numbering, so it has to
  # exist once per back end for the same reason insn-modes-<base>.h does.
  #
  # It is written into mt-<cpu>/ rather than the build root, and that is not a
  # tidying choice -- see the MT_SRC comment at emit_base_objects.  This is the
  # file that exposed the reason: `#include "tm.h"' from a source sitting in
  # the build root finds the build root's OWN tm.h, which is the PRIMARY
  # target's, before any -I is consulted at all.
  printf "mt-%s/insn-modes-%s.cc: build/genmodes-%s$(build_exeext) modes-union.list\n", cpu, cpu, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) %s > tmp-modes-%s.cc\n", cpu, ufl, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-%s.cc $@\n\n", cpu;

  # Everything the generators link against sees the mode enum through
  # coretypes.h, so it all has to be compiled against this back end's modes,
  # not just the one file that tabulates them.
  # inchash is here rather than only on genrecog's link line, which is where
  # Makefile.in puts it for the single-target build: make allows one recipe per
  # target, so a per-back-end program cannot take an extra object without a
  # rule of its own.  Linking it into every generator costs an unused object
  # and keeps one list.
  n = split("rtl read-rtl ggc-none vec gensupport print-rtl " \
	    "hash-table inchash sort read-md errors", parts, " ");
  objs = "build/min-insn-modes-" cpu ".o";
  for (i = 1; i <= n; i++)
    objs = objs " build/" parts[i] "-" cpu ".o";
  printf "MULTI_TARGET_GEN_OBJS_%s = %s\n", cpu, objs;
  printf "build/min-insn-modes-%s.o : min-insn-modes-%s.cc\n", cpu, cpu;
  for (i = 1; i <= n; i++)
    printf "build/%s-%s.o : %s.cc\n", parts[i], cpu, parts[i];
  printf "$(MULTI_TARGET_GEN_OBJS_%s) : insn-modes-%s.h insn-modes-inline-%s.h \\\n", cpu, cpu, cpu;
  printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(RTL_BASE_H) $(GTM_H) \\\n";
  printf "  errors.h $(READ_MD_H) $(GENSUPPORT_H) $(HASH_TABLE_H) $(OBSTACK_H)\n";
  printf "$(MULTI_TARGET_GEN_OBJS_%s) : BUILD_CPPFLAGS += \\\n", cpu;
  printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
  printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"' \\\n", cpu;
  # gensupport.cc is where print_gen_include lives, so this shared library has
  # to see the same GEN_HDR_SUFFIX as the gen*.o that call it.  Set on only one
  # of the two and it compiles clean and emits the unsuffixed names -- a silent
  # no-op, which is the failure mode this whole knob exists to prevent.
  printf "  -DGEN_HDR_SUFFIX='\"-%s\"'\n\n", cpu;

  # The programs themselves.  Each holds a main(), so they cannot share one
  # link; they share the library above instead.  genpreds.cc additionally
  # reads a target macro out of tm.h (TARGET_MEM_CONSTRAINT), and genflags.cc
  # is what makes insn-flags-<base>.h, so both want this back end's tm.h.
  # genconditions.cc wants it for the same reason and for one more: the file
  # it *writes* names four back-end headers, and which four is settled when
  # genconditions itself is compiled (see the GENCONDMD_* defines below).
  n = split("preds flags conditions codes config attr attr-common emit recog " \
	    "output extract peep automata target-def attrtab opinit enums",
	    parts, " ");
  for (i = 1; i <= n; i++) {
    printf "build/gen%s-%s.o : gen%s.cc tm-%s.h insn-modes-%s.h \\\n",
	   parts[i], cpu, parts[i], cpu, cpu;
    printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(RTL_BASE_H) $(GTM_H) \\\n";
    printf "  errors.h $(READ_MD_H) $(GENSUPPORT_H) $(OBSTACK_H)\n";
    printf "build/gen%s-%s.o : BUILD_CPPFLAGS += \\\n", parts[i], cpu;
    printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
    printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"' \\\n", cpu;
    printf "  -DTM_H_FILE='\"tm-%s.h\"' \\\n", cpu;
    # And the suffix these programs put on the generated headers their OUTPUT
    # includes.  Without it a back end's insn-recog-<base>.cc is compiled
    # against whichever insn-config.h / insn-codes.h / tm_p.h the single-target
    # build left lying around -- it still compiles, it just describes another
    # target.  See GEN_HDR_SUFFIX in gensupport.h.
    printf "  -DGEN_HDR_SUFFIX='\"-%s\"'\n", cpu;
    printf "build/gen%s-%s$(build_exeext): build/gen%s-%s.o \\\n",
	   parts[i], cpu, parts[i], cpu;
    printf "  $(MULTI_TARGET_GEN_OBJS_%s) $(BUILD_LIBDEPS)\n", cpu;
    printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
    printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";
  }

  # THE CONDITIONS FILE.  Every one of these generators is fed
  # insn-conditions-<base>.md, as upstream feeds them insn-conditions.md, and
  # they must ALL be fed it or none: gencodes consults a condition's truth
  # value even with elision off, so passing the file to some and not others
  # would have them disagree about what every insn code means (measured on
  # i386: NUM_INSN_CODES 15874 vs 15429, 8555 renumbered CODE_FOR_ lines).
  #
  # What makes it safe to pass is that insn-conditions-<base>.md is no longer
  # one triple's answer.  It is the INTERSECTION over all of the back end's
  # configured triples -- see emit_triple and intersect-conditions.awk -- so a
  # condition is recorded constant only where every triple agrees, and anything
  # that turns on an OS or ABI choice stays -1 and is decided at run time.
  # Folding against a single first-triple-wins tm-<base>.h was tried and backed
  # out: it turned `HAVE_adddi3_sp32 (TARGET_ARCH32)' into `1' across 1124
  # lines of sparc, and `!TARGET_MACHO' from -1 into 0 for i386.
  #
  # Passing it is also not optional.  gensupport ELIDES patterns whose
  # condition is provably false, and gcn depends on that for well-formedness,
  # not for size: config/gcn/gcn-valu.md:836's
  # vec_extract<V_1REG:mode><V_1REG_ALT:mode>_nop is a cross product of two
  # mode iterators whose condition
  #	MODE_VF (<V_1REG_ALT:MODE>mode) < MODE_VF (<V_1REG:MODE>mode)
  #	&& <V_1REG_ALT:SCALAR_MODE>mode == <V_1REG:SCALAR_MODE>mode
  # IS the filter over that product, and without it genrecog rejects gcn with
  # 831 `element mode mismatch' errors.  Those conditions are mode arithmetic
  # and so are invariant across gcn's triples: the intersection keeps them.
  # That is the whole point of intersecting rather than choosing.
  printf "insn-flags-%s.h: build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t$(RUN_GEN) build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md > tmp-flags-%s.h\n", md, cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-flags-%s.h $@\n", cpu;
  printf "%s-common.o: insn-flags-%s.h insn-modes-%s.h\n\n", cpu, cpu, cpu;

  # AUDITED, because "these generators are per back end" is only safe if their
  # output depends on the .md and not on which tm.h they were compiled with.
  # Intersecting each generator's identifiers with the 689 macros tm-i386.h
  # defines: gencodes, genconfig, genattr, genattr-common, genattrtab, genemit,
  # genopinit, genextract, genpeep, genautomata, gentarget-def, genflags,
  # genenums and genconditions reference NONE of them.
  #
  # genenums was audited separately when it joined this list: it greps 0 for
  # TARGET_ and HAVE_, and its output is a function of the md files alone.  It
  # DOES now include tm.h and rtl.h, but only because gensupport.h needs them
  # (rtl.h wants FIRST_PSEUDO_REGISTER) -- the same "needs *a* tm.h, but that
  # reaches a structure size rather than the output" case as the rest.  What it
  # genuinely needs from gensupport is print_gen_include: genenums NAMES
  # insn-constants.h in what it writes, so it must carry GEN_HDR_SUFFIX even
  # though it reads no target macro.  Naming a generated header and reading a
  # target macro are two independent reasons to be per back end, and genenums
  # is the one generator that has the first without the second.
  #
  # Only genpreds (SWITCHABLE_TARGET,
  # TARGET_MEM_CONSTRAINT, TARGET_SUPPORTS_WIDE_INT) and genoutput
  # (TARGET_MEM_CONSTRAINT) do, and those two are exactly the ones whose rules
  # already say they want this back end's tm.h.  (genrecog matches only
  # GENERATOR_FILE, a build-system define, which is the method's one false
  # positive.)  They all still need *a* tm.h -- rtl.h wants
  # FIRST_PSEUDO_REGISTER -- but that reaches a structure size, not the output.
  n = split("codes config attr attr-common", parts, " ");
  for (i = 1; i <= n; i++) {
    # genconfig alone is given the SHARED insn-config answer: every macro it
    # writes lands on a #if line, an array bound or a bitfield width, so none
    # of them can become a runtime value and all of them must agree across
    # back ends.  See the long note at the top of genconfig.cc, and
    # emit_config_union below for how insn-config-union.list is built.
    ufl = (parts[i] == "config") \
	  ? sprintf(" -Uinsn-config-union.list -A%s", cpu) : "";
    udep = (parts[i] == "config") ? " insn-config-union.list" : "";

    printf "insn-%s-%s.h: build/gen%s-%s$(build_exeext) $(srcdir)/common.md \\\n",
	   parts[i], cpu, parts[i], cpu;
    printf "  $(srcdir)/config/%s insn-conditions-%s.md%s\n", md, cpu, udep;
    printf "\t$(RUN_GEN) build/gen%s-%s$(build_exeext)%s $(srcdir)/common.md \\\n",
	   parts[i], cpu, ufl;
    printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
    printf "\t  > tmp-%s-%s.h\n", parts[i], cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-%s-%s.h $@\n\n",
	   parts[i], cpu;
  }

  # This back end's contribution to the union file, from the same generator
  # and the same .md files.  Kept as a separate file per back end so that the
  # union file's rule is a concatenation and cannot half-succeed.
  printf "insn-config-%s.part: build/genconfig-%s$(build_exeext) $(srcdir)/common.md \\\n",
	 cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t$(RUN_GEN) build/genconfig-%s$(build_exeext) -l -A%s \\\n", cpu, cpu;
  printf "\t  $(srcdir)/common.md $(srcdir)/config/%s insn-conditions-%s.md \\\n",
	 md, cpu;
  printf "\t  > tmp-config-%s.part\n", cpu;
  printf "\t@grep -q '^base %s$$' tmp-config-%s.part || { \\\n", cpu, cpu;
  printf "\t  echo 'insn-config-%s.part: no \"base %s\" line;' >&2; \\\n", cpu, cpu;
  printf "\t  echo '  the union would then be taken over the OTHER back ends' >&2; \\\n";
  printf "\t  echo '  and this one would be sized for somebody else.' >&2; \\\n";
  printf "\t  exit 1; }\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-config-%s.part $@\n\n",
	 cpu;
  config_parts = config_parts " insn-config-" cpu ".part";
  config_bases = config_bases " " cpu;

  # genautomata is the one generator that needs a library the others do not.
  printf "build/genautomata-%s$(build_exeext): BUILD_LIBS += -lm\n\n", cpu;

  # The generated .cc files that do go to stdout, and gentarget-def's header.
  # genoutput belongs to the same group as genpreds: it is the second
  # generator that genuinely reads a target macro (TARGET_MEM_CONSTRAINT), so
  # being compiled against this back end's own tm.h is load-bearing for it
  # rather than incidental.
  # NOTE for the object-naming step (S4): insn-enums-<base>.cc defines
  # unspec_strings and unspecv_strings as PLAIN globals, so once two back
  # ends' insn-enums objects are both in OBJS they collide at link -- the same
  # shape as targetm, and the third thing that will need a per-base symbol
  # plus a selector.  Generating the files is safe today only because nothing
  # links them yet.
  n = split("output extract peep automata enums", parts, " ");
  for (i = 1; i <= n; i++) {
    printf "mt-%s/insn-%s-%s.cc: build/gen%s-%s$(build_exeext) $(srcdir)/common.md \\\n",
	   cpu, parts[i], cpu, parts[i], cpu;
    printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
    printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
    printf "\t$(RUN_GEN) build/gen%s-%s$(build_exeext) $(srcdir)/common.md \\\n",
	   parts[i], cpu;
    printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
    printf "\t  > tmp-%s-%s.cc\n", parts[i], cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-%s-%s.cc $@\n\n",
	   parts[i], cpu;
  }

  printf "insn-target-def-%s.h: build/gentarget-def-%s$(build_exeext) \\\n", cpu, cpu;
  printf "  $(srcdir)/common.md $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t$(RUN_GEN) build/gentarget-def-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md > tmp-target-def-%s.h\n", md, cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-target-def-%s.h $@\n\n", cpu;

  # genattrtab writes three files, genopinit two; neither uses stdout.
  printf "mt-%s/insn-attrtab-%s.cc mt-%s/insn-dfatab-%s.cc mt-%s/insn-latencytab-%s.cc: \\\n",
	 cpu, cpu, cpu, cpu, cpu, cpu;
  printf "  s-attrtab-%s; @true\n", cpu;
  printf "s-attrtab-%s: build/genattrtab-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genattrtab-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
  printf "\t  -Atmp-attrtab-%s.cc -Dtmp-dfatab-%s.cc \\\n", cpu, cpu;
  printf "\t  -Ltmp-latencytab-%s.cc\n", cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-attrtab-%s.cc mt-%s/insn-attrtab-%s.cc\n", cpu, cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-dfatab-%s.cc mt-%s/insn-dfatab-%s.cc\n", cpu, cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-latencytab-%s.cc mt-%s/insn-latencytab-%s.cc\n", cpu, cpu, cpu;
  printf "\t$(STAMP) s-attrtab-%s\n\n", cpu;

  printf "mt-%s/insn-opinit-%s.cc insn-opinit-%s.h: s-opinit-%s; @true\n", cpu, cpu, cpu, cpu;
  printf "s-opinit-%s: build/genopinit-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genopinit-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
  printf "\t  -htmp-opinit-%s.h -ctmp-opinit-%s.cc\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-opinit-%s.h insn-opinit-%s.h\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-opinit-%s.cc mt-%s/insn-opinit-%s.cc\n", cpu, cpu, cpu;
  printf "\t$(STAMP) s-opinit-%s\n\n", cpu;

  # genemit and genrecog do not write to stdout: they split their output over
  # NUM_INSNEMIT_SPLITS files named by -O, and genrecog writes a header named
  # by -H as well.  The split count is a build-parallelism knob
  # (@DEFAULT_INSNEMIT_PARTITIONS@), not target data, so every back end reuses
  # the one make already computed rather than getting a sequence of its own.
  printf "INSNEMIT_SEQ_SRC_%s = $(patsubst %%, mt-%s/insn-emit-%s-%%.cc, $(INSNEMIT_SPLITS_SEQ))\n", cpu, cpu, cpu;
  printf "INSNEMIT_SEQ_TMP_%s = $(patsubst %%, tmp-emit-%s-%%.cc, $(INSNEMIT_SPLITS_SEQ))\n", cpu, cpu;
  printf "$(INSNEMIT_SEQ_SRC_%s): s-tmp-emit-%s; @true\n", cpu, cpu;
  printf "s-tmp-emit-%s: build/genemit-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genemit-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
  printf "\t  $(addprefix -O,$(INSNEMIT_SEQ_TMP_%s))\n", cpu;
  printf "\t$(foreach id, $(INSNEMIT_SPLITS_SEQ), \\\n";
  printf "\t  $(SHELL) $(srcdir)/../move-if-change tmp-emit-%s-$(id).cc \\\n", cpu;
  printf "\t  mt-%s/insn-emit-%s-$(id).cc;)\n", cpu, cpu;
  printf "\t$(STAMP) s-tmp-emit-%s\n\n", cpu;

  printf "INSNRECOG_SEQ_SRC_%s = $(patsubst %%, mt-%s/insn-recog-%s-%%.cc, $(INSNRECOG_SPLITS_SEQ))\n", cpu, cpu, cpu;
  printf "INSNRECOG_SEQ_TMP_%s = $(patsubst %%, tmp-recog-%s-%%.cc, $(INSNRECOG_SPLITS_SEQ))\n", cpu, cpu;
  printf "$(INSNRECOG_SEQ_SRC_%s): s-tmp-recog-%s; @true\n", cpu, cpu;
  printf "insn-recog-%s.h: s-tmp-recog-%s; @true\n", cpu, cpu;
  printf "s-tmp-recog-%s: build/genrecog-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genrecog-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
  printf "\t  -Hinsn-recog-%s.h \\\n", cpu;
  printf "\t  $(addprefix -O,$(INSNRECOG_SEQ_TMP_%s))\n", cpu;
  printf "\t$(foreach id, $(INSNRECOG_SPLITS_SEQ), \\\n";
  printf "\t  $(SHELL) $(srcdir)/../move-if-change tmp-recog-%s-$(id).cc \\\n", cpu;
  printf "\t  mt-%s/insn-recog-%s-$(id).cc;)\n", cpu, cpu;
  printf "\t$(STAMP) s-tmp-recog-%s\n\n", cpu;

  printf "tm-preds-%s.h: build/genpreds-%s$(build_exeext) $(srcdir)/common.md $(srcdir)/config/%s\n", cpu, cpu, md;
  printf "\t$(RUN_GEN) build/genpreds-%s$(build_exeext) -h $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-preds-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-preds-%s.h $@\n\n", cpu;

  printf "tm-constrs-%s.h: build/genpreds-%s$(build_exeext) $(srcdir)/common.md $(srcdir)/config/%s\n", cpu, cpu, md;
  printf "\t$(RUN_GEN) build/genpreds-%s$(build_exeext) -c $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-constrs-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-constrs-%s.h $@\n\n", cpu;

  # The predicate FUNCTIONS, as against the two headers above.  Fed the same
  # inputs as tm-preds-<base>.h and NOT insn-conditions-<base>.md, matching
  # both the two rules above it and upstream's s-preds: genpreds -h/-c/<none>
  # must all see one input set, or the bodies compiled here would not be the
  # ones the prototypes above declare.
  printf "mt-%s/insn-preds-%s.cc: build/genpreds-%s$(build_exeext) $(srcdir)/common.md $(srcdir)/config/%s\n", cpu, cpu, cpu, md;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genpreds-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-preds-%s.cc\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-preds-%s.cc $@\n\n", cpu;

  # tm_p_file names headers relative to gcc/config; tm-preds comes last, the
  # way configure builds tm_p_include_list for the single-target case.
  n = split(tmp, parts, " ");
  hdrs = "";
  for (i = 1; i <= n; i++)
    if (parts[i] != "")
      hdrs = hdrs "config/" parts[i] " ";
  hdrs = hdrs "tm-preds-" cpu ".h";

  printf "tm_p-%s.h: tm-preds-%s.h $(srcdir)/mkconfig.sh Makefile\n", cpu, cpu;
  printf "\tHEADERS=\"%s\" DEFINES=\"\" \\\n", hdrs;
  printf "\t  $(SHELL) $(srcdir)/mkconfig.sh tm_p-%s.h\n\n", cpu;

  # The common object for this back end includes tm_p-<base>.h; the rule that
  # builds it lives in multi-target-common.mk, so add the prerequisite here.
  printf "%s-common.o: tm_p-%s.h tm-constrs-%s.h\n\n", cpu, cpu, cpu;

  # This back end's assembler directives, compiled from its own tm-<base>.h.
  # See target-asm-ops.h: targetm holds one target's directives because only
  # the configured target's config/<cpu>/<cpu>.cc is linked, and this is the
  # cheap part of fixing that -- the values that are plain strings.
  #
  # mmix is still excluded, but the REASON HAS CHANGED and the old one is no
  # longer true.  It used to be "the table cannot be statically initialised
  # for it", because the hook was a POD `const char *' and mmix's
  # DATA_SECTION_ASM_OP is `mmix_data_section_asm_op ()'.  The hooks are
  # function pointers now (target-asm-ops.h), GCC_TARGET_ASM_OP_WRAPPER wraps
  # each macro in a static inline, and a wrapper whose body is a call is a
  # perfectly good constant expression.  So mmix is now REPRESENTABLE.
  #
  # What excludes it is one step further out: the function that wrapper calls,
  # `mmix_data_section_asm_op', is defined in config/mmix/mmix.cc, and only
  # the PRIMARY target's back-end sources are linked -- OBJS carries a
  # singular $(out_object_file).  target-asm-ops-mmix.o would compile and then
  # fail to link with an undefined reference whenever mmix is not the primary.
  # This exclusion therefore ends when the per-back-end compiler objects go
  # into OBJS, not before, and it is one more consumer of that work.
  #
  # Back ends that share default-common.cc are skipped as well, and for a
  # duller reason: tm-<base>.h is generated per *common file* base, not per
  # cpu_type, so ft32 and the four others in that group have no tm-ft32.h to
  # compile against.  Every other rule in this file happens to be safe because
  # cpu_type and the common-file base coincide for the 45 back ends that have
  # their own; these five are where the two keys come apart.
  if (cpu == "mmix") {
    printf "# target-asm-ops-mmix.o omitted: DATA_SECTION_ASM_OP calls mmix_data_section_asm_op (),\n";
    printf "# which is defined in config/mmix/mmix.cc -- not linked unless mmix is the primary.\n\n";
  }
  else if (cof == "default-common.cc")
    printf "# target-asm-ops-%s.o omitted: no tm-%s.h (shares default-common.cc).\n\n",
	   cpu, cpu;
  else {
  printf "target-asm-ops-%s.o: $(srcdir)/target-asm-ops.cc tm-%s.h \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/target-asm-ops.h\n";
  printf "\t$(COMPILE) -DTM_H_FILE='\"tm-%s.h\"' \\\n", cpu;
  printf "\t  -DTARGETM_ASM_OPS_SYMBOL=targetm_asm_ops_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-asm-ops.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
    asm_ops_objs = asm_ops_objs " target-asm-ops-" cpu ".o";
    asm_ops_bases = asm_ops_bases " " cpu;
  }

  # The include directory described at MULTI_TARGET_INC_STEMS in BEGIN.  Put
  # `-I<base>-inc' ahead of `-I.' -- that is what MULTI_TARGET_INC in
  # Makefile.in is for -- and this back end's objects see their OWN generated
  # headers under the plain names their sources actually write.
  #
  # Skipped for the back ends that share default-common.cc, for the same reason
  # target-asm-ops-<base>.o is: tm-<base>.h, options-<base>.h and
  # insn-constants-<base>.h are generated per COMMON FILE base, not per
  # cpu_type, so those five have no tm-<base>.h for a forwarder to point at.
  # Emitting the directory anyway would give them a `tm.h' whose target has no
  # rule, i.e. a build that stops later and further from the cause.
  if (cof == "default-common.cc")
    printf "# %s-inc omitted: no tm-%s.h (shares default-common.cc).\n\n",
	   cpu, cpu;
  else {
    printf "MULTI_TARGET_INC_HDRS_%s = \\\n", cpu;
    printf "  $(patsubst %%,%%-%s.h,$(MULTI_TARGET_INC_STEMS))\n", cpu;
    printf "MULTI_TARGET_INC_DIRS += %s-inc\n", cpu;
    # Written through move-if-change so that a rebuild of, say, insn-attr-arm.h
    # does not restamp 16 forwarders and recompile the whole back end: the
    # forwarders' CONTENT never changes once written, only their timestamps
    # would.  The stamp is what the rest of the build depends on.
    # ...plus whatever this back end's t-<...>-headers fragments generate; see
    # scan_hdr_frag.  They are prerequisites of the stamp rather than of each
    # object because they are needed by the same sources for the same reason
    # the forwarders are, and one stamp is what the object rules depend on.
    printf "%s-inc/s-inc: $(MULTI_TARGET_INC_HDRS_%s)%s Makefile\n",
	   cpu, cpu, hdrgen[cpu];
    printf "\t$(mkinstalldirs) %s-inc\n", cpu;
    printf "\tfor stem in $(MULTI_TARGET_INC_STEMS); do \\\n";
    printf "\t  echo \"#include \\\"$${stem}-%s.h\\\"\" > tmp-inc-%s.h; \\\n", cpu, cpu;
    # ...and then re-establish the PLAIN include guard.  This is not tidiness:
    # a per-base header guards itself after its own name -- tm-aarch64.h says
    # `#ifndef GCC_TM_AARCH64_H' -- so a source reaching it only through this
    # forwarder never defines GCC_TM_H, and every `#ifdef GCC_TM_H' block in
    # the tree silently disappears.
    #
    # MEASURED, and it is not a corner: target.h:390 wraps get_cumulative_args
    # and pack_cumulative_args in `#ifdef GCC_TM_H', so aarch64.cc compiled
    # against aarch64-inc failed with 22 `get_cumulative_args was not declared'
    # errors -- while the other 19 aarch64 objects compiled clean, which is
    # exactly the shape that gets misread as one broken source file.  Six of
    # the sixteen stems have a guard that something in the tree TESTS rather
    # than merely defines (tm, insn-modes, insn-codes, insn-config, insn-flags,
    # tm-preds, tm-constrs), so this is not special-cased to tm.h.
    #
    # The guard is DERIVED from the per-base header rather than computed from
    # the stem, and emitted only when the two differ.  Computing it would mean
    # inventing GCC_OPTIONS_H and GCC_INSN_RECOG_H, which nothing in the tree
    # defines -- options.h and insn-recog.h carry no guard at all -- and a
    # macro this file invents is a name with no authority behind it, which is
    # the bug class this branch exists to remove.  A stem whose header has no
    # guard therefore gets no #define, and that is visible in the output.
    # `$$( )', not backticks: a backtick substitution cannot span the `\'
    # continuations a make recipe is written in -- the shell reports only
    # `unexpected EOF while looking for matching ```, naming neither the rule
    # nor the stem.  gen-target-manifest.sh made the same choice for the same
    # reason.
    printf "\t  mtguard=$$(sed -n \"1,20s/^#ifndef \\\\(GCC_[A-Z0-9_]*\\\\)$$/\\\\1/p\" $${stem}-%s.h | sed -n 1p); \\\n", cpu;
    # The infix the per-base header added, in the form mkconfig.sh writes it.
    ucpu = toupper(cpu); gsub(/[-.]/, "_", ucpu);
    printf "\t  mtplain=$$(echo \"$${mtguard}\" | sed \"s/_%s_H$$/_H/\"); \\\n",
	   ucpu;
    printf "\t  if test -n \"$${mtguard}\" && test x\"$${mtguard}\" != x\"$${mtplain}\"; then \\\n";
    printf "\t    echo \"#ifndef $${mtplain}\" >> tmp-inc-%s.h; \\\n", cpu;
    printf "\t    echo \"#define $${mtplain}\" >> tmp-inc-%s.h; \\\n", cpu;
    printf "\t    echo \"#endif\" >> tmp-inc-%s.h; \\\n", cpu;
    printf "\t  fi; \\\n";
    printf "\t  $(SHELL) $(srcdir)/../move-if-change tmp-inc-%s.h \\\n", cpu;
    printf "\t    %s-inc/$${stem}.h || exit 1; \\\n", cpu;
    printf "\tdone\n";
    printf "\t$(STAMP) %s-inc/s-inc\n\n", cpu;

    emit_base_objects();
  }

  emit_triple();

  reset();
}

# EXPECT A CASCADE.  Once one generated header goes per triple, everything it
# transitively feeds has to follow, or the two disagree.  That is not a series
# of surprises, it is the shape of the problem: a per-base header is a claim
# that all of a back end's triples agree about its contents, and moving tm.h
# down to the triple is precisely the discovery that they do not.
#
# The known live instance, and it is NOT the one first guessed (tm-constrs and
# insn-constants were the suspects; they are innocent, their content is
# md-derived and the same for every triple):
#
#   options-<base>.h is generated from the FIRST triple's extra_options.  For
#   rs6000 that is the DARWIN triple, whose list has no rs6000/sysv4.opt, so
#   TARGET_LITTLE_ENDIAN -- `Mask(LITTLE_ENDIAN)' in that .opt -- is absent.
#   Every rs6000 triple whose tm.h chain reaches config/rs6000/sysv4.h then
#   fails to compile, because sysv4.h:50 has
#	#define TARGET_BIG_ENDIAN (! TARGET_LITTLE_ENDIAN)
#   and tm-constrs-rs6000.h expands it.  2394 errors, one back end, one missing
#   .opt file.
#
#   So options-<base>.h is the next header to follow tm.h down to the triple.
#   It is NOT a mechanical repeat of this file's work: the OPT_* codes it
#   declares have to stay consistent with the single shared options.cc table,
#   which is generated from ALL targets' .opt files at once.  Per-triple
#   options.h with per-triple numbering would silently disagree with it.  That
#   needs its own design, not a copy of emit_triple.
#
# Everything that has to exist once per configured TRIPLE rather than once per
# back end: the conditions of a machine description are evaluated against a
# tm.h, and a back end serving 31 triples the way i386 does has no single one.
# So each triple gets its own tm.h, its own gencondmd, and its own conditions
# file; emit_condition_intersections then reduces a back end's triples to what
# they agree on.  See intersect-conditions.awk for why that is the right
# answer rather than picking one triple.
#
# Skipped for the back ends that share default-common.cc: they have no
# options-<base>.h or insn-constants-<base>.h to build a tm.h against.
function emit_triple(	key, hdrs, i, n, parts, ssh, ssdep) {
  if (cof == "default-common.cc")
    return;

  key = trg;
  gsub(/[^A-Za-z0-9_]/, "_", key);

  # tm_include_list names options.h and insn-constants.h generically; those two
  # are per back end, not per triple, so they resolve to the <base> names.  The
  # rest of the list is this triple's own header chain, which is the whole
  # point.
  hdrs = inc;
  sub(/(^| )options\.h( |$)/, " options-" cpu ".h ", hdrs);
  sub(/(^| )insn-constants\.h( |$)/, " insn-constants-" cpu ".h ", hdrs);

  # A generated sysroot-suffix header, where this triple has one and we can
  # honestly produce it.  It goes per triple like everything else here, so the
  # name in the include list has to be rewritten to match.
  ssh = emit_sysroot_suffix(key);
  if (ssh != "") {
    sub("(^| )" ssh "( |$)", " sysroot-suffix-" key ".h ", hdrs);
    ssdep = " sysroot-suffix-" key ".h";
  }
  else
    ssdep = "";

  printf "tm-%s.h: options-%s.h insn-constants-%s.h%s Makefile\n",
	 key, cpu, cpu, ssdep;
  # INSN_BASE is the BACK END, not the triple: insn-flags and insn-modes come
  # from the machine description and so exist once per back end, exactly like
  # the options-<cpu>.h and insn-constants-<cpu>.h rewritten just above.
  # mkconfig.sh cannot infer it from `tm-<triple>.h'.
  printf "\tTARGET_CPU_DEFAULT=\"\" HEADERS=\"%s\" DEFINES=\"%s\" \\\n", hdrs, def;
  printf "\t  INSN_BASE=\"%s\" $(SHELL) $(srcdir)/mkconfig.sh tm-%s.h\n\n", cpu, key;

  n = split(tmp, parts, " ");
  hdrs = "";
  for (i = 1; i <= n; i++)
    if (parts[i] != "")
      hdrs = hdrs "config/" parts[i] " ";
  hdrs = hdrs "tm-preds-" cpu ".h";
  printf "tm_p-%s.h: tm-preds-%s.h $(srcdir)/mkconfig.sh Makefile\n", key, cpu;
  printf "\tHEADERS=\"%s\" DEFINES=\"\" \\\n", hdrs;
  printf "\t  $(SHELL) $(srcdir)/mkconfig.sh tm_p-%s.h\n\n", key;

  printf "build/genconditions-%s.o : genconditions.cc tm-%s.h insn-modes-%s.h \\\n",
	 key, key, cpu;
  printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(RTL_BASE_H) $(GTM_H) \\\n";
  printf "  errors.h $(READ_MD_H) $(GENSUPPORT_H) $(OBSTACK_H) $(HASHTAB_H)\n";
  printf "build/genconditions-%s.o : BUILD_CPPFLAGS += \\\n", key;
  printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
  printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"' \\\n", cpu;
  printf "  -DTM_H_FILE='\"tm-%s.h\"' \\\n", key;
  printf "  -DGENCONDMD_TM_H='\"tm-%s.h\"' \\\n", key;
  printf "  -DGENCONDMD_INSN_CONSTANTS_H='\"insn-constants-%s.h\"' \\\n", cpu;
  printf "  -DGENCONDMD_TM_P_H='\"tm_p-%s.h\"' \\\n", key;
  printf "  -DGENCONDMD_TM_CONSTRS_H='\"tm-constrs-%s.h\"'\n", cpu;
  printf "build/genconditions-%s$(build_exeext): build/genconditions-%s.o \\\n", key, key;
  printf "  $(MULTI_TARGET_GEN_OBJS_%s) $(BUILD_LIBDEPS)\n", cpu;
  printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
  printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";

  printf "build/gencondmd-%s.cc: s-conditions-%s; @true\n", key, key;
  printf "s-conditions-%s: build/genconditions-%s$(build_exeext) \\\n", key, key;
  printf "  $(srcdir)/common.md $(srcdir)/config/%s\n", md;
  printf "\t$(RUN_GEN) build/genconditions-%s$(build_exeext) \\\n", key;
  printf "\t  $(srcdir)/common.md $(srcdir)/config/%s > tmp-condmd-%s.cc\n", md, key;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-condmd-%s.cc \\\n", key;
  printf "\t  build/gencondmd-%s.cc\n", key;
  printf "\t$(STAMP) s-conditions-%s\n\n", key;

  printf "build/gencondmd-%s.o : build/gencondmd-%s.cc \\\n", key, key;
  printf "  tm-%s.h insn-constants-%s.h tm_p-%s.h tm-constrs-%s.h \\\n",
	 key, cpu, key, cpu;
  printf "  insn-modes-%s.h insn-modes-inline-%s.h \\\n", cpu, cpu;
  printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H)\n";
  printf "build/gencondmd-%s.o : BUILD_CPPFLAGS += \\\n", key;
  printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
  if (poly_aware(cpu))
    printf "  -DTARGET_POLY_AWARE \\\n";
  printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"'\n", cpu;
  printf "build/gencondmd-%s.o : \\\n", key;
  printf "  BUILD_CFLAGS := $(filter-out -fkeep-inline-functions, $(BUILD_CFLAGS))\n";
  printf "build/gencondmd-%s$(build_exeext): build/gencondmd-%s.o \\\n", key, key;
  printf "  build/errors.o $(BUILD_LIBDEPS)\n";
  printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
  printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";

  printf "insn-conditions-%s.md: s-condmd-%s; @true\n", key, key;
  printf "s-condmd-%s: build/gencondmd-%s$(build_exeext)\n", key, key;
  printf "\t$(RUN_GEN) build/gencondmd-%s$(build_exeext) > tmp-cond-%s.md\n", key, key;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-cond-%s.md \\\n", key;
  printf "\t  insn-conditions-%s.md\n", key;
  printf "\t$(STAMP) s-condmd-%s\n\n", key;

  # This triple's source-derived spec file: the spec macros its own tm.h chain
  # defines, printed in read_specs() format.  Per TRIPLE and not per back end,
  # which is the whole reason it is emitted here: LINK_SPEC, STARTFILE_SPEC and
  # the rest are exactly the macros that differ between x86_64-linux-gnu and
  # x86_64-elf while both are the i386 back end.
  #
  # gen-target-specs.cc is a generator in the ordinary sense -- BUILD_CXXFLAGS
  # carries -DGENERATOR_FILE, which is what lets tm-<key>.h skip the
  # insn-flags-<key>.h and insn-modes-<key>.h it would otherwise include and
  # which are not built for a non-primary target.  Nothing about a spec string
  # needs them.
  #
  # It links against nothing but libiberty: no errors.o, no read-md, because it
  # only expands macros and prints them.
  printf "build/gen-target-specs-%s.o : $(srcdir)/gen-target-specs.cc \\\n", key;
  printf "  tm-%s.h $(srcdir)/spec-names.h \\\n", key;
  printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H)\n";
  printf "build/gen-target-specs-%s.o : BUILD_CPPFLAGS += \\\n", key;
  printf "  -DTM_HEADER='\"tm-%s.h\"' -DTARGET_TRIPLE='\"%s\"'\n", key, trg;
  printf "build/gen-target-specs-%s.o : $(srcdir)/gen-target-specs.cc\n", key;
  printf "\t$(COMPILER_FOR_BUILD) -c $(BUILD_COMPILERFLAGS) $(BUILD_CPPFLAGS) \\\n";
  printf "\t  -o $@ $<\n\n";
  printf "build/gen-target-specs-%s$(build_exeext): \\\n", key;
  printf "  build/gen-target-specs-%s.o $(BUILD_LIBDEPS)\n", key;
  printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
  printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";

  # Named for the triple as the manifest spells it, because that is the name
  # the target-specs rule in Makefile.in looks for.
  printf "specs-src-%s: build/gen-target-specs-%s$(build_exeext)\n", trg, key;
  printf "\t$(RUN_GEN) build/gen-target-specs-%s$(build_exeext) > tmp-specs-src-%s\n", key, key;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-specs-src-%s specs-src-%s\n\n", key, trg;

  srcspecs = srcspecs " specs-src-" trg;

  condfiles[cpu] = condfiles[cpu] " insn-conditions-" key ".md";
  ntriples[cpu]++;
}

# One insn-conditions-<base>.md per back end, holding what all of that back
# end's triples agree on.  A back end with a single configured triple still
# goes through the merge: the script is the identity on one file, and having
# one code path is worth more than skipping an awk run.
function emit_condition_intersections(	c) {
  for (c in condfiles) {
    printf "insn-conditions-%s.md:%s $(srcdir)/intersect-conditions.awk\n",
	   c, condfiles[c];
    printf "\t$(AWK) -f $(srcdir)/intersect-conditions.awk%s \\\n", condfiles[c];
    printf "\t  > tmp-cond-%s.md\n", c;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-cond-%s.md $@\n\n", c;
    printf "# %s: merged from %d configured triple(s).\n\n", c, ntriples[c];
  }
}

# The registry the selector includes: one declaration per back end plus a list
# naming them all.  Generated here rather than by configure because this file
# already walks the manifest and knows every cpu_type.
function emit_asm_ops_registry(	i, n, parts) {
  n = split(asm_ops_bases, parts, " ");

  printf "MULTI_TARGET_ASM_OPS_OBJS =%s\n", asm_ops_objs;
  printf "multi-target-asm-ops.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_asm_ops targetm_asm_ops_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_ASM_OPS_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_ASM_OPS_ENTRY (\"%s\", targetm_asm_ops_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-asm-ops.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-asm-ops.h $@\n\n";
  printf "target-asm-ops-select.o: multi-target-asm-ops.h\n\n";
}

# The registry multi-target-select.cc includes: every back end that has
# objects, and the triple-to-back-end map.
#
# Two lists rather than one, because they answer two different questions and
# conflating them is what made the earlier selector wrong.  MT_BACKENDS is the
# set of back ends whose objects are in the archive -- what may be selected.
# MT_TARGET_BASES maps the NAME a target-config file uses (a triple) to the
# back end serving it; several triples share one back end, so it is many-to-one
# and cannot be derived from MT_BACKENDS.
#
# Emitted only when MULTI_TARGET_OBJS is non-empty, i.e. when there is anything
# to select between; a build with no back ends gets a header with no entries
# and multi-target-select.cc refuses to compile against it, rather than one
# that quietly selects nothing.
function emit_backend_registry(	i, n, parts, m, tp, seenb) {
  n = split(mt_bases, parts, " ");
  m = split(mt_targets, tp, " ");

  printf "multi-target-backends.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  printf "\t  echo '#define MT_BACKENDS \\'; \\\n";
  for (i = 1; i <= n; i++) {
    if (parts[i] in seenb)
      continue;
    seenb[parts[i]] = 1;
    printf "\t  echo '  MT_BACKEND (%s, insn_%s) \\'; \\\n", parts[i], parts[i];
  }
  printf "\t  echo '  /* end */'; \\\n";
  printf "\t  echo '#define MT_TARGET_BASES \\'; \\\n";
  for (i = 1; i <= m; i++)
    printf "\t  echo '  MT_TARGET_BASE (\"%s\", %s) \\'; \\\n",
	   tp[i], mt_base_of[tp[i]];
  printf "\t  echo '  /* end */'; \\\n";
  printf "\t} > tmp-multi-target-backends.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-backends.h $@\n\n";
  printf "multi-target-select.o: multi-target-backends.h\n\n";
}

BEGIN {
  # Each target's MULTILIB_* set, written by gen-multilib-data.sh.  Only the
  # handful of triples whose tm_file names a generated sysroot-suffix header
  # need it; see emit_sysroot_suffix.
  if (multilib != "")
    while ((getline line < multilib) > 0) {
      if (line ~ /^target /)		 { sub(/^target /, "", line); mlt = line }
      else if (line ~ /^multilib_options /)
	{ sub(/^multilib_options */, "", line); ml_opt[mlt] = line }
      else if (line ~ /^multilib_matches /)
	{ sub(/^multilib_matches */, "", line); ml_match[mlt] = line }
      else if (line ~ /^multilib_reuse /)
	{ sub(/^multilib_reuse */, "", line); ml_reuse[mlt] = line }
      else if (line ~ /^multilib_osdirnames /)
	{ sub(/^multilib_osdirnames */, "", line); ml_osdir[mlt] = line }
    }
  close(multilib);

  # THE PER-BACK-END INCLUDE DIRECTORY.
  #
  # 90 back-end sources include a generated per-base header under its PLAIN
  # name -- `#include "insn-attr.h"', not through tm.h -- so in a multi-target
  # build they resolve, via `-I.', to the PRIMARY target's copy.  Measured:
  # config/arm/aarch-common.cc fails with `CC_Cmode was not declared; did you
  # mean CCGCmode' -- an i386 mode suggested for an arm file -- because its
  # bare `#include "insn-modes.h"' bypasses the tm.h it was given.
  #
  # The tree's existing idiom for this is macro indirection (-DTM_H_FILE=,
  # -DINSN_MODES_H=).  That is right for the ~10 generators, which name a
  # handful of headers each, and it does not scale here: every one of the 90
  # sources would need an `#ifndef X / #include X' edit, and it CANNOT catch a
  # TRANSITIVE include, which is most of them.
  #
  # So each back end gets a directory of forwarding headers instead, put ahead
  # of `-I.' on the include path.  A source saying `insn-attr.h' then gets
  # <base>-inc/insn-attr.h, which is one line including insn-attr-<base>.h.  No
  # source edits, works transitively, works for all 90.
  #
  # The plain-to-per-base transform is uniform for every header in the family
  # -- strip `.h', append `-<base>.h' -- which is why a stem list is enough:
  # tm.h/tm-<base>.h, tm_p.h/tm_p-<base>.h, insn-modes-inline.h/
  # insn-modes-inline-<base>.h all follow it.
  #
  # A stem is listed here ONLY if some rule in this file (or in Makefile.in)
  # generates <stem>-<base>.h.  There is deliberately no fallback to the plain
  # name for a stem that has no per-base rule: a forwarder pointing at the
  # primary's copy is exactly the bug being fixed, and it would be silent.
  # Instead the stamp rule below names every per-base header as a prerequisite,
  # so a stem with no rule stops the build with `No rule to make target
  # <stem>-<base>.h' -- refuse rather than guess, as INSN_BASE does in
  # mkconfig.sh.
  printf "MULTI_TARGET_INC_STEMS = tm tm_p tm-preds tm-constrs options \\\n";
  printf "  insn-constants insn-attr insn-attr-common insn-codes insn-config \\\n";
  printf "  insn-flags insn-modes insn-modes-inline insn-opinit insn-recog \\\n";
  printf "  insn-target-def\n\n";
}

$1 == "target"	  { trg = $2 }
$1 == "tmake_file" { tmk = $0 }
# Already filtered to the fragments that exist; see the t-<...>-headers loop.
$1 == "tmake_file_present" { tmkp = $0 }
$1 == "cpu_type"  { cpu = $2 }
$1 == "common_out_file" { cof = $2 }
$1 == "md_file"   { md = $2 }
$1 == "out_file"  { outf = $2 }
$1 == "extra_objs" { xobjs = ""; for (i = 2; i <= NF; i++) xobjs = xobjs $i " " }
$1 == "extra_modes" { xmodes = $2 }
$1 == "tm_p_file" { tmp = ""; for (i = 2; i <= NF; i++) tmp = tmp $i " " }
$1 == "tm_include_list" { inc = ""; for (i = 2; i <= NF; i++) inc = inc $i " " }
$1 == "tm_defines" { def = ""; for (i = 2; i <= NF; i++) def = def $i " " }
NF == 0		  { flush() }
END		  { flush(); emit_condition_intersections();
		    emit_asm_ops_registry(); emit_backend_registry();
		    emit_source_specs();
		    emit_modes_union(); emit_config_union();
		    emit_inc_dirs() }

# THE SHARED insn-config ANSWER.  Same shape as the mode numbering below, and
# for the same reason: `insn-config.h' is included by 90 non-config/ files and
# was byte-identical to the PRIMARY's, so the middle end was compiled believing
# whatever the primary happens to say.  Measured in a two-target build dir:
# NUM_REGISTER_FILTERS 0 for i386 and 4 for aarch64, MAX_DUP_OPERANDS 14 vs 6,
# MAX_INSNS_PER_SPLIT 5 vs 4, MAX_INSNS_PER_PEEP2 6 vs 4, HAVE_lo_sum 0 vs 1.
#
# Unlike the modes this cannot be a selector, ever.  ira-int.h:356 reads
# NUM_REGISTER_FILTERS with `#ifndef'/`#elif' AND sizes a bitfield with it, and
# recog.h:69 sizes another; regrename.cc:71 has MAX_RECOG_OPERANDS on a `#if'
# line.  A preprocessor line cannot read a targ_caps field.  So the six maxima
# get ONE value, the union over every configured back end, and genconfig fails
# loudly rather than defaulting -- see apply_union_list in genconfig.cc.
#
# Check it is wired up against the GENERATED fragment, never against this file:
#
#	grep -c ' -Uinsn-config-union.list ' multi-target-md.mk
function emit_config_union(   nb, tmp_bases) {
  nb = split(config_bases, tmp_bases, " ");
  if (nb == 0) {
    print "gen-multi-target-md.awk: no back ends for insn-config-union.list" \
	  > "/dev/stderr";
    exit 1;
  }

  printf "# The shared insn-config answer; see emit_config_union in\n";
  printf "# $(srcdir)/gen-multi-target-md.awk.\n";
  printf "insn-config-union.list:%s\n", config_parts;
  printf "\tcat%s > tmp-insn-config-union.list\n", config_parts;
  # A short list is the failure mode that would otherwise be silent: the union
  # would be taken over fewer back ends and every insn-config.h would come out
  # undersized, with nothing said.  genconfig's -U catches the case where the
  # MISSING base is the one being generated; this catches the rest.
  printf "\t@test `grep -c '^base ' tmp-insn-config-union.list` -eq %d || { \\\n", nb;
  printf "\t  echo 'insn-config-union.list: expected %d base lines, got' \\\n", nb;
  printf "\t       `grep -c '^base ' tmp-insn-config-union.list`; \\\n";
  printf "\t  echo '  a short list makes the union too small and every'; \\\n";
  printf "\t  echo '  insn-config.h silently undersized.'; \\\n";
  printf "\t  exit 1; } >&2\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-insn-config-union.list $@\n\n";
}

# THE SHARED MODE NUMBERING.
#
# genmodes.cc has carried this machinery since f7c4d1aed68 and nothing invoked
# it: there was no `-l' and no `-U' anywhere in the build, so every back end's
# mode enum stayed dense over its own modes.  Measured in a two-target build
# dir before this function existed: `E_SImode' was ordinal 18 for i386 and 17
# for aarch64, NUM_MACHINE_MODES 124 against 192.  Two objects that disagree
# about which integer `SImode' is link cleanly and miscompile silently, which
# is the exact bug class this branch exists to remove -- and it sat upstream
# of every symbol the selector was being sized for.
#
# `absence of an artefact is not absence of a mechanism' has bitten this
# project repeatedly; this is the mirror of it.  The mechanism was present in
# genmodes.cc and its comments described a wiring that did not exist.  The
# check that settles it is one command against the GENERATED fragment, not
# against genmodes.cc:
#
#	grep -c ' -U modes-union.list ' multi-target-md.mk
#
# and the check that it WORKS is that two back ends' insn-modes-<base>.h agree
# on the ordinal of every mode they both define.
function emit_modes_union(   i, c, m, deps, seen_modes) {
  if (n_union_cpu == 0)
    return;

  # The union input: one #include per back end, each announced so that a name
  # it defines can be attributed to it, and each reporting the bitsize maxima
  # before they are #undef'd.  Reading all the files and then looking at
  # MAX_BITSIZE_MODE_ANY_INT once would give whichever file came last, not the
  # largest -- genmodes.cc:1000 records that trap; this is the code it asks
  # for.
  deps = "";
  for (i = 1; i <= n_union_cpu; i++) {
    c = union_cpu[i];
    if (union_modes[c] != "" && !(union_modes[c] in seen_modes)) {
      seen_modes[union_modes[c]] = 1;
      deps = deps " $(srcdir)/config/" union_modes[c];
    }
  }

  printf "# The union genmodes input.  Generated; see emit_modes_union in\n";
  printf "# gen-multi-target-md.awk.\n";
  printf "modes-union.def:%s\n", deps;
  printf "\t@rm -f tmp-modes-union.def\n";
  printf "\t@printf '/* Generated by gen-multi-target-md.awk.  Do not edit.  */\\n' > tmp-modes-union.def\n";
  for (i = 1; i <= n_union_cpu; i++) {
    c = union_cpu[i];
    m = union_modes[c];
    if (m == "")
      continue;
    # One printf per back end.  `%' never appears in what is written, so
    # nothing here needs escaping for printf(1) beyond the newlines.
    printf "\t@printf 'union_note_arch (\"%s\");\\n", c;
    printf "#include \"config/%s\"\\n", m;
    printf "#ifdef MAX_BITSIZE_MODE_ANY_INT\\n";
    printf "union_note_max_bitsize (MAX_BITSIZE_MODE_ANY_INT, 0);\\n";
    printf "#undef MAX_BITSIZE_MODE_ANY_INT\\n";
    printf "#endif\\n";
    printf "#ifdef MAX_BITSIZE_MODE_ANY_MODE\\n";
    printf "union_note_max_bitsize (0, MAX_BITSIZE_MODE_ANY_MODE);\\n";
    printf "#undef MAX_BITSIZE_MODE_ANY_MODE\\n";
    printf "#endif\\n";
    # Back to null before the next file, and before the rest of machmode.def:
    # a name defined by COMPLEX_MODES/VECTOR_MODES after the include belongs to
    # nobody and must not be qualified with the last back end read.
    printf "union_note_arch (0);\\n' >> tmp-modes-union.def\n";
  }
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-union.def $@\n\n";

  # The union genmodes.  -DGENMODES_UNION turns on the announcement hooks and
  # the running bitsize maxima; the extra-modes file is the generated union
  # input, which lives in the BUILD directory -- `config/<cpu>/...' inside it
  # is then resolved through -I$(srcdir), because the build directory has no
  # config/ of its own.
  printf "genprogerr += modes-union\n";
  printf "build/genmodes-union.o : BUILD_CPPFLAGS += -DGENMODES_UNION -DTARGET_EXTRA_MODES_FILE='\"modes-union.def\"'\n";
  printf "build/genmodes-union.o : genmodes.cc $(BCONFIG_H) $(SYSTEM_H) errors.h \\\n";
  printf "  $(HASHTAB_H) machmode.def modes-union.def\n\n";

  printf "modes-union.list: build/genmodes-union$(build_exeext)\n";
  printf "\t$(RUN_GEN) build/genmodes-union$(build_exeext) -l > tmp-modes-union.list\n";
  printf "\t@test -s tmp-modes-union.list || { \\\n";
  printf "\t  echo 'modes-union.list: the union run emitted no modes;' >&2; \\\n";
  printf "\t  echo '  every genmodes run would then be numbered against nothing.' >&2; \\\n";
  printf "\t  exit 1; }\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-union.list $@\n\n";
}

# One .o rule per back-end object, for every configured back end.
#
# This is what the per-base generated sources and the per-base include
# directory were for.  The mechanism is not new here: it was spiked three times
# in the build directory (spike4/5/6.mk) over aarch64's 20 config sources and
# its 30 generated ones, 50/50 clean with NO source edits, and this function
# only writes down what those spikes ran.
#
# Three things make one uniform recipe enough, and all three were measured
# rather than assumed:
#
#   * `-I<cpu>-inc' supplies every generated header under the plain name the
#     sources actually write, transitively.  That is MULTI_TARGET_INC, and it
#     must be reached through a target-specific variable inside a RECURSIVE
#     assignment -- an `INCLUDES := $(MULTI_TARGET_INC) ...' expands before the
#     target-specific value exists and both arms of the test then fail
#     identically, which reads as "the mechanism does not work".
#   * `$(COMPILE) $<' is the whole recipe.  See frag_source_for for why the
#     fragments' own recipes are ignored.
#   * `<cpu>-inc/s-inc' covers the headers this back end generates: it already
#     names all 16 forwarders and, since scan_hdr_frag, the t-<...>-headers
#     outputs too.
#   * `s-gtype' is the second and last prerequisite.  A back end's main source
#     and several of its extra_objs sources `#include "gt-<file>.h"', and those
#     headers are NOT per-base: gengtype names its output after the source
#     scanned with the directory stripped, parses the source text without ever
#     preprocessing it against a tm.h, and no two back ends have a gt--using
#     source with the same basename.  So one build-root copy is correct -- the
#     `mt-<cpu>/' hazard does NOT apply here -- and ORDER is all that is
#     wanted.  Depending on the stamp rather than on $(ALL_GTFILES_H) keeps
#     this to one name and matches how every other consumer of gengtype's
#     output in Makefile.in is written.
#
#     Necessary, not yet sufficient: until configure's all_gtfiles is the union
#     over every back end (see the long note at that line), gengtype is never
#     ASKED to scan a non-primary source, so aarch64.o, aarch64-builtins.o and
#     aarch64-acle-builtins.o still fail on `gt-<file>.h: No such file'.
#     Flipping that one line makes all 94 objects compile and breaks the cc1
#     link; it belongs with OBJS + the selector.
#
# The config objects go in `mt-<cpu>/' rather than being renamed.  Measured
# over all 188 targets: 153 distinct object names, and the number with more
# than one distinct source is ZERO -- there is no rename problem in this space.
# 123 names are wanted by more than one target and 9 by more than one back end,
# so what the directory buys is that `linux.o' wanted by 37 targets needs no
# scheme at all.  Compiling it per back end rather than once is a cost, not a
# correctness question: its `.text' was byte-identical across x86_64-linux,
# s390x-linux and arm-linux-androideabi, so a later dedupe is available and is
# deliberately not taken here, where it would be a second mechanism to get
# wrong.
#
# NOT YET IN `OBJS'.  These objects compile but cannot all be linked into one
# compiler yet: `targetm' alone has 47 definitions under that one name, and the
# selector that chooses between them is a separate piece of work.  Emitting the
# rules first is deliberate -- it is the half that can be verified on its own,
# by `make multi-target-objs'.
function emit_base_objects(	i, n, parts, objs, src, obj, poly) {
  objs = "";

  # The ONE flag a fragment's recipe carries that the uniform recipe cannot do
  # without.  `-DTARGET_POLY_AWARE' says this back end's sources are written to
  # the 2-coefficient poly_int discipline, and it is per back end by
  # construction, so dropping it produces 223 errors of the form `request for
  # member to_constant in ... poly_int<1, short unsigned int>' -- in the back
  # end's own sources, which reads as a source bug and is not one.
  #
  # It is read out of config/<cpu>/t-<cpu> rather than listed here for the
  # reason poly_aware() gives: the fragment is where a back end DECLARES the
  # conversion, and a second list would drift from it exactly once.  Note that
  # this is not a reversal of "ignore the fragments' recipes": the recipes are
  # still ignored, and this is the one FLAG lifted out of them, deliberately
  # and by name.
  poly = poly_aware(cpu) ? " -DTARGET_POLY_AWARE" : "";

  # *** MT_SRC: WHY EVERY PER-BASE SOURCE LIVES IN mt-<cpu>/ ***
  #
  # `-I<cpu>-inc' is NOT enough on its own, and the reason is a rule of the
  # preprocessor rather than anything about this build.  `#include "tm.h"'
  # searches the directory OF THE FILE CONTAINING THE DIRECTIVE first, before
  # any -I at all.  A generated source sitting in the build root therefore
  # finds the build root's own tm.h -- the PRIMARY target's -- and no -I can
  # outrank it.
  #
  # This was live and it was nearly silent.  Only insn-modes-aarch64.cc failed,
  # with `aarch64_sve_vg was not declared', because its ADJUST_NUNITS text
  # happens to name an aarch64 symbol that i386's tm.h does not have.  Every
  # other per-base generated source compiled CLEAN against i386's tm.h.  That
  # is the branch's own bug class -- right on the build's triple, wrong
  # everywhere else -- reproduced inside the machinery meant to remove it.
  #
  # It also explains why the earlier spikes read as proof and were not: they
  # compiled sources from $(srcdir)/config/<cpu>/, where the same rule works
  # FOR us (no tm.h next to them), and generated sources whose first tm.h comes
  # transitively through a $(srcdir) header, which likewise resolves by -I.
  # The failing case is exactly a build-root source whose own `#include "tm.h"'
  # is the first one reached.
  #
  # Three arms, all run, with -H to name the file actually opened:
  #   ./insn-modes-aarch64.cc      + -Iaarch64-inc   -> 57 errors
  #   mt-aarch64/insn-modes-...cc  + -Iaarch64-inc   -> 0, via aarch64-inc/tm.h
  #   mt-aarch64/insn-modes-...cc  withOUT it        -> 499 errors
  # The third arm matters: without it a pass is consistent with the directory
  # doing nothing.
  n = split("attrtab automata dfatab extract latencytab modes opinit output " \
	    "peep preds enums", parts, " ");
  for (i = 1; i <= n; i++) {
    printf "insn-%s-%s.o: mt-%s/insn-%s-%s.cc %s-inc/s-inc\n",
	   parts[i], cpu, cpu, parts[i], cpu, cpu;
    printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
    objs = objs " insn-" parts[i] "-" cpu ".o";
  }

  # insn-emit and insn-recog are the two that are SPLIT, so their names are
  # two-axis.  The split count is a build-parallelism knob shared by every back
  # end (INSNEMIT_SPLITS_SEQ), not target data, so the rule list and the
  # generator's own -O list are the same list and cannot disagree.
  printf "insn-emit-%s-%%.o: mt-%s/insn-emit-%s-%%.cc %s-inc/s-inc\n", cpu, cpu, cpu, cpu;
  printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
  printf "insn-recog-%s-%%.o: mt-%s/insn-recog-%s-%%.cc %s-inc/s-inc\n", cpu, cpu, cpu, cpu;
  printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
  objs = objs " $(patsubst %,insn-emit-" cpu "-%.o,$(INSNEMIT_SPLITS_SEQ))";
  objs = objs " $(patsubst %,insn-recog-" cpu "-%.o,$(INSNRECOG_SPLITS_SEQ))";

  # The hand-written back-end sources: this back end's main file plus its
  # extra_objs.
  #
  # Written as one whole rule per object rather than a pattern rule plus a
  # prerequisite-only rule.  The pattern-rule form is shorter and wrong: with
  # both rules matching, `$<' is whichever prerequisite make happens to put
  # first, so the recipe can compile the STAMP instead of the source -- and it
  # does so for some objects and not others, which reads as a broken source
  # file.
  n = split(outf " " xobjs, parts, " ");
  for (i = 1; i <= n; i++) {
    if (i == 1) {
      # out_file is a PATH under config/, not an object name.
      src = "$(srcdir)/config/" parts[i];
      obj = parts[i];
      sub(/.*\//, "", obj);
      sub(/\.cc$/, "", obj);
    } else {
      obj = parts[i];
      sub(/\.o$/, "", obj);
      src = frag_source_for(obj, tmkp);
      if (src == "") {
	# Refuse rather than guess.  A guessed config/<cpu>/<obj>.cc that
	# happens to exist would compile the wrong file without a word; a
	# guessed one that does not exist would fail three steps away, at a
	# missing prerequisite whose name nothing in the tree explains.
	printf "$(error multi-target: nothing in %s's tmake_file claims a rule for %s.o,\n",
	       cpu, obj;
	printf "  so gen-multi-target-md.awk cannot tell which source builds it.\n";
	printf "  Add the rule to the fragment that puts %s.o in extra_objs.)\n\n",
	       obj;
	continue;
      }
    }
    printf "mt-%s/%s.o: %s %s-inc/s-inc s-gtype\n", cpu, obj, src, cpu;
    printf "\t@$(mkinstalldirs) mt-%s/$(DEPDIR)\n", cpu;
    printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
    objs = objs " mt-" cpu "/" obj ".o";
  }

  printf "MULTI_TARGET_OBJS_%s =%s\n", cpu, objs;
  printf "$(MULTI_TARGET_OBJS_%s): MULTI_TARGET_INC = -I%s-inc\n", cpu, cpu;
  # The bare names this back end's HAND-WRITTEN sources define; see
  # MULTI_TARGET_RENAME_NAMES in Makefile.in for the list and why it exists.
  # The list lives there, not here, so that the names have one authority.
  printf "$(MULTI_TARGET_OBJS_%s): MULTI_TARGET_RENAMES = \\\n", cpu;
  # $(foreach), not $(patsubst): make substitutes only the FIRST `%%' in a
  # patsubst replacement, so `-D%%=%%_i386' expands to `-Dtargetm=%%_i386' and
  # the compiler is handed a literal per cent.  Which it reports as
  # `<command-line>: expected primary-expression before %% token', naming
  # neither the variable nor this file.
  printf "  $(foreach n,$(MULTI_TARGET_RENAME_NAMES),-D$(n)=$(n)_%s) \\\n", cpu;
  # The companion to -Dtargetm=.  target.h #errors by name if either of the
  # two appears without the other, because the half that is easy to lose is
  # the -D: a middle-end object built with the rename would silently bind to
  # ONE back end's hook table in a compiler holding several, and nothing
  # about that is a link error.  The marker says "this translation unit is a
  # back end's own", which is a thing no rule can infer from the name alone.
  printf "  -DMULTI_TARGET_TARGETM_BASE=%s\n", cpu;
  printf "MULTI_TARGET_OBJS += $(MULTI_TARGET_OBJS_%s)\n", cpu;
  mt_bases = mt_bases " " cpu;
  # One back end at a time, by name.  Needed for more than convenience: the
  # control that shows these objects read THEIR OWN headers rather than the
  # primary's poisons one base's tm.h and requires the other base still to
  # build, and that arm cannot be expressed without building one base alone.
  printf ".PHONY: multi-target-objs-%s\n", cpu;
  printf "multi-target-objs-%s: $(MULTI_TARGET_OBJS_%s)\n\n", cpu, cpu;
}

# One target that materialises every back end's forwarding-header directory, so
# that anything wanting per-back-end compilation can depend on it by name
# rather than on 48 stamps.  MULTI_TARGET_INC_DIRS is accumulated with `+=' as
# each back end is emitted above.
function emit_inc_dirs() {
  printf ".PHONY: multi-target-incdirs\n";
  printf "multi-target-incdirs: $(patsubst %%,%%/s-inc,$(MULTI_TARGET_INC_DIRS))\n\n";

  # Every configured back end's objects, by name.  This is the handle the
  # OBJS work is verified through while MULTI_TARGET_OBJS is not yet in OBJS:
  # `make multi-target-objs' compiles every back end there is, and a back end
  # whose sources do not survive per-base compilation says so here rather than
  # inside a link of 24k symbols.
  printf ".PHONY: multi-target-objs\n";
  printf "multi-target-objs: $(MULTI_TARGET_OBJS)\n\n";
}

# The list every source-derived spec file is reachable from, so that one make
# target builds them all and the target-specs rule can depend on it.
function emit_source_specs() {
  printf "MULTI_TARGET_SOURCE_SPECS =%s\n\n", srcspecs;
  printf ".PHONY: source-specs\n";
  printf "source-specs: $(MULTI_TARGET_SOURCE_SPECS)\n\n";
}
