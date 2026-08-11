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

function flush(	i, n, parts, hdrs, modes, modesdep, objs, junk) {
  if (cpu == "" || seen[cpu])
    { cpu = ""; md = ""; tmp = ""; xmodes = ""; cof = ""; return }
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
    printf "include $(srcdir)/config/%s/t-%s-headers\n", cpu, cpu;
  }

  if (xmodes != "") {
    modes = "config/" xmodes;
    modesdep = " $(srcdir)/" modes;
    printf "build/genmodes-%s.o : BUILD_CPPFLAGS += -DTARGET_EXTRA_MODES_FILE='\"%s\"'\n", cpu, modes;
  } else {
    modesdep = "";
    printf "build/genmodes-%s.o : BUILD_CPPFLAGS += -DTARGET_NO_EXTRA_MODES\n", cpu;
  }
  printf "genprogerr += modes-%s\n", cpu;
  printf "build/genmodes-%s.o : genmodes.cc $(BCONFIG_H) $(SYSTEM_H) errors.h \\\n", cpu;
  printf "  $(HASHTAB_H) machmode.def%s\n", modesdep;
  printf "\n";
  printf "insn-modes-%s.h: build/genmodes-%s$(build_exeext)\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) -h > tmp-modes-%s.h\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-%s.h $@\n", cpu;
  printf "insn-modes-inline-%s.h: build/genmodes-%s$(build_exeext)\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) -i > tmp-modes-inline-%s.h\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-modes-inline-%s.h $@\n", cpu;
  printf "min-insn-modes-%s.cc: build/genmodes-%s$(build_exeext)\n", cpu, cpu;
  printf "\t$(RUN_GEN) build/genmodes-%s$(build_exeext) -m > tmp-min-modes-%s.cc\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-min-modes-%s.cc $@\n\n", cpu;

  # Everything the generators link against sees the mode enum through
  # coretypes.h, so it all has to be compiled against this back end's modes,
  # not just the one file that tabulates them.
  n = split("rtl read-rtl ggc-none vec gensupport print-rtl " \
	    "hash-table sort read-md errors", parts, " ");
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
  printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"'\n\n", cpu;

  # The programs themselves.  Each holds a main(), so they cannot share one
  # link; they share the library above instead.  genpreds.cc additionally
  # reads a target macro out of tm.h (TARGET_MEM_CONSTRAINT), and genflags.cc
  # is what makes insn-flags-<base>.h, so both want this back end's tm.h.
  # genconditions.cc wants it for the same reason and for one more: the file
  # it *writes* names four back-end headers, and which four is settled when
  # genconditions itself is compiled (see the GENCONDMD_* defines below).
  n = split("preds flags conditions codes config attr attr-common", parts, " ");
  for (i = 1; i <= n; i++) {
    printf "build/gen%s-%s.o : gen%s.cc tm-%s.h insn-modes-%s.h \\\n",
	   parts[i], cpu, parts[i], cpu, cpu;
    printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(RTL_BASE_H) $(GTM_H) \\\n";
    printf "  errors.h $(READ_MD_H) $(GENSUPPORT_H) $(OBSTACK_H)\n";
    printf "build/gen%s-%s.o : BUILD_CPPFLAGS += \\\n", parts[i], cpu;
    printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
    printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"' \\\n", cpu;
    printf "  -DTM_H_FILE='\"tm-%s.h\"'\n", cpu;
    printf "build/gen%s-%s$(build_exeext): build/gen%s-%s.o \\\n",
	   parts[i], cpu, parts[i], cpu;
    printf "  $(MULTI_TARGET_GEN_OBJS_%s) $(BUILD_LIBDEPS)\n", cpu;
    printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
    printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";
  }

  # genconditions writes a program; the program is what has to be built
  # against this back end.  The four headers it names in what it writes are
  # fixed at *its* compile time, so they are settled here rather than by any
  # flag passed when it runs.  Defaults in genconditions.cc are the plain
  # single-target names, so the single-target rules in Makefile.in are
  # untouched.
  #
  # Back ends sharing default-common.cc are skipped: tm-<base>.h and the other
  # three are generated per common-file base, not per cpu_type, and those five
  # are the only place the two keys come apart, so ft32/moxie/rl78 have no
  # tm-ft32.h &c to compile against.  Same guard as the asm-ops rules below.
  if (cof != "default-common.cc") {
    printf "build/genconditions-%s.o : BUILD_CPPFLAGS += \\\n", cpu;
    printf "  -DGENCONDMD_TM_H='\"tm-%s.h\"' \\\n", cpu;
    printf "  -DGENCONDMD_INSN_CONSTANTS_H='\"insn-constants-%s.h\"' \\\n", cpu;
    printf "  -DGENCONDMD_TM_P_H='\"tm_p-%s.h\"' \\\n", cpu;
    printf "  -DGENCONDMD_TM_CONSTRS_H='\"tm-constrs-%s.h\"'\n", cpu;
    printf "build/genconditions-%s.o : $(HASHTAB_H)\n\n", cpu;

    printf "build/gencondmd-%s.cc: s-conditions-%s; @true\n", cpu, cpu;
    printf "s-conditions-%s: build/genconditions-%s$(build_exeext) \\\n", cpu, cpu;
    printf "  $(srcdir)/common.md $(srcdir)/config/%s\n", md;
    printf "\t$(RUN_GEN) build/genconditions-%s$(build_exeext) \\\n", cpu;
    printf "\t  $(srcdir)/common.md $(srcdir)/config/%s > tmp-condmd-%s.cc\n", md, cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-condmd-%s.cc \\\n", cpu;
    printf "\t  build/gencondmd-%s.cc\n", cpu;
    printf "\t$(STAMP) s-conditions-%s\n\n", cpu;

    # As for the single-target build/gencondmd.o: tm_p-<base>.h brings in the
    # back end's predicate wrappers as inline functions, and keeping them all
    # would demand definitions this program does not link.
    printf "build/gencondmd-%s.o : build/gencondmd-%s.cc \\\n", cpu, cpu;
    printf "  tm-%s.h insn-constants-%s.h tm_p-%s.h tm-constrs-%s.h \\\n",
	   cpu, cpu, cpu, cpu;
    printf "  insn-modes-%s.h insn-modes-inline-%s.h \\\n", cpu, cpu;
    printf "  $(BCONFIG_H) $(SYSTEM_H) $(CORETYPES_H)\n";
    printf "build/gencondmd-%s.o : BUILD_CPPFLAGS += \\\n", cpu;
    printf "  -DINSN_MODES_H='\"insn-modes-%s.h\"' \\\n", cpu;
    printf "  -DINSN_MODES_INLINE_H='\"insn-modes-inline-%s.h\"'\n", cpu;
    printf "build/gencondmd-%s.o : \\\n", cpu;
    printf "  BUILD_CFLAGS := $(filter-out -fkeep-inline-functions, $(BUILD_CFLAGS))\n";
    printf "build/gencondmd-%s$(build_exeext): build/gencondmd-%s.o \\\n", cpu, cpu;
    printf "  build/errors.o $(BUILD_LIBDEPS)\n";
    printf "\t+$(LINKER_FOR_BUILD) $(BUILD_LINKERFLAGS) $(BUILD_LDFLAGS) -o $@ \\\n";
    printf "\t    $(filter-out $(BUILD_LIBDEPS), $^) $(BUILD_LIBS)\n\n";

    printf "insn-conditions-%s.md: s-condmd-%s; @true\n", cpu, cpu;
    printf "s-condmd-%s: build/gencondmd-%s$(build_exeext)\n", cpu, cpu;
    printf "\t$(RUN_GEN) build/gencondmd-%s$(build_exeext) > tmp-cond-%s.md\n", cpu, cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-cond-%s.md \\\n", cpu;
    printf "\t  insn-conditions-%s.md\n", cpu;
    printf "\t$(STAMP) s-condmd-%s\n\n", cpu;

  }
  else {
    printf "# no gencondmd-%s: no tm-%s.h (shares default-common.cc).\n\n",
	   cpu, cpu;
  }

  # tm-<base>.h names this, so that a back end compiled against it gets its own
  # HAVE_* rather than the configured target's.
  #
  # DELIBERATELY NOT FED insn-conditions-<base>.md.  Upstream passes genflags
  # the conditions file so that each pattern's condition is resolved to 1 or 0
  # up front; here that would be a bad trade, and the measurement is worth
  # keeping because the change is a two-line one and looks like a free win.
  #
  # Pre-evaluation is only as good as the tm.h it is done against, and
  # tm-<base>.h is built from whichever triple came FIRST in the manifest --
  # tm-i386.h is an i686-apple-darwin, tm-sparc.h is a 32-bit sparc.  Folding a
  # condition that turns on an OS or ABI choice rather than on the back end
  # therefore bakes that arbitrary triple's answer:
  #	-#define HAVE_adddi3_sp32 (TARGET_ARCH32)
  #	+#define HAVE_adddi3_sp32 1
  # and the symbolic form is the more nearly runtime-correct of the two.  In
  # insn-conditions-i386.md the same cause turns `!TARGET_MACHO' from -1
  # (unknown, decided later) into 0, i.e. "definitely not Mach-O" recorded for
  # a back end whose representative triple is Darwin -- wrong in both
  # directions at once.  Upstream has no such gap because there tm.h *is* the
  # configured target.
  #
  # Cost of turning it on, measured: 1124 changed lines in insn-flags-sparc.h,
  # 4270 in i386, 1423 in rs6000, 0 in aarch64.  That is 4270 lines of one
  # arbitrary target choice baked in, in the name of an optimisation, in a
  # tree whose purpose is to remove exactly that.
  #
  # Turn it back on once tm-<base>.h is keyed properly rather than by
  # first-triple-wins: append insn-conditions-<base>.md to both the
  # prerequisites and the command line below, and skip it for the back ends
  # that share default-common.cc, which have no gencondmd of their own.
  printf "insn-flags-%s.h: build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s\n", md;
  printf "\t$(RUN_GEN) build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-flags-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-flags-%s.h $@\n", cpu;
  printf "%s-common.o: insn-flags-%s.h insn-modes-%s.h\n\n", cpu, cpu, cpu;

  # The rest of the machine-description headers, same shape.  Upstream builds
  # these from the `simple_rtl_generated_h' pattern rules in Makefile.in, which
  # also pass insn-conditions.md; none of these do.
  #
  # That is a POLICY, not an oversight, and it has to be the same policy for
  # every generator or the results disagree with each other.  See the
  # insn-flags note above for why folding against tm-<base>.h is the wrong
  # trade: tm-<base>.h is whichever triple came first in the manifest, so a
  # condition that turns on an OS or ABI choice gets that arbitrary triple's
  # answer.  For a header of macros that costs a wrong constant.  For genemit
  # and genrecog it costs the pattern: gensupport.cc ELIDES patterns whose
  # condition is provably false, and only gencodes and genflags turn that off
  # (insn_elision = 0), so one triple's inability to use a pattern would delete
  # it for every triple of the back end.  That is wrong code, not a missed
  # optimisation.
  #
  # UNIFORMITY IS MANDATORY, and measurably so: gencodes consults the truth
  # value even with elision off, emitting `= CODE_FOR_nothing' for a pattern it
  # can prove dead.  Feeding it the conditions file moves NUM_INSN_CODES for
  # i386 from 15874 to 15429 and renumbers 8555 lines of CODE_FOR_.  A build
  # where some generators saw the file and others did not would disagree about
  # what every insn code means.
  #
  # Passing it to none keeps every condition deferred to run time, which is
  # what a multi-target compiler wants, and is how GCC behaved before gencondmd
  # existed.  Elision is then inert by construction rather than by our
  # restraint: condition_table is populated only by add_c_test, called only
  # from read-rtl.cc's define_conditions handler, which only an
  # insn-conditions.md contains.  With no such file every non-empty condition
  # is -1 (unknown) and nothing is ever elided.
  #
  # AUDITED, because "these generators are per back end" is only safe if their
  # output depends on the .md and not on which tm.h they were compiled with.
  # Intersecting each generator's identifiers with the 689 macros tm-i386.h
  # defines: gencodes, genconfig, genattr, genattr-common, genattrtab, genemit,
  # genopinit, genextract, genpeep, genautomata, gentarget-def, genflags and
  # genconditions reference NONE of them.  Only genpreds (SWITCHABLE_TARGET,
  # TARGET_MEM_CONSTRAINT, TARGET_SUPPORTS_WIDE_INT) and genoutput
  # (TARGET_MEM_CONSTRAINT) do, and those two are exactly the ones whose rules
  # already say they want this back end's tm.h.  (genrecog matches only
  # GENERATOR_FILE, a build-system define, which is the method's one false
  # positive.)  They all still need *a* tm.h -- rtl.h wants
  # FIRST_PSEUDO_REGISTER -- but that reaches a structure size, not the output.
  n = split("codes config attr attr-common", parts, " ");
  for (i = 1; i <= n; i++) {
    printf "insn-%s-%s.h: build/gen%s-%s$(build_exeext) $(srcdir)/common.md \\\n",
	   parts[i], cpu, parts[i], cpu;
    printf "  $(srcdir)/config/%s\n", md;
    printf "\t$(RUN_GEN) build/gen%s-%s$(build_exeext) $(srcdir)/common.md \\\n",
	   parts[i], cpu;
    printf "\t  $(srcdir)/config/%s > tmp-%s-%s.h\n", md, parts[i], cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-%s-%s.h $@\n\n",
	   parts[i], cpu;
  }

  printf "tm-preds-%s.h: build/genpreds-%s$(build_exeext) $(srcdir)/common.md $(srcdir)/config/%s\n", cpu, cpu, md;
  printf "\t$(RUN_GEN) build/genpreds-%s$(build_exeext) -h $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-preds-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-preds-%s.h $@\n\n", cpu;

  printf "tm-constrs-%s.h: build/genpreds-%s$(build_exeext) $(srcdir)/common.md $(srcdir)/config/%s\n", cpu, cpu, md;
  printf "\t$(RUN_GEN) build/genpreds-%s$(build_exeext) -c $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-constrs-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-constrs-%s.h $@\n\n", cpu;

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
  # mmix is excluded because on mmix they are not.  DATA_SECTION_ASM_OP there
  # is `mmix_data_section_asm_op ()', a call into the back end, so the table
  # cannot be statically initialised for it.  That is not a limitation of this
  # file: targetm.asm_out.data_section_asm_op is a POD `const char *' hook, so
  # mmix cannot be represented in it at all, and TARGET_INITIALIZER would
  # reject the same expression the moment config/mmix/mmix.cc were compiled.
  # Excluded loudly here rather than silently producing a wrong directive;
  # making that hook a function on mmix's behalf is the owner's call.
  #
  # Back ends that share default-common.cc are skipped as well, and for a
  # duller reason: tm-<base>.h is generated per *common file* base, not per
  # cpu_type, so ft32 and the four others in that group have no tm-ft32.h to
  # compile against.  Every other rule in this file happens to be safe because
  # cpu_type and the common-file base coincide for the 45 back ends that have
  # their own; these five are where the two keys come apart.
  if (1) {
    # Withdrawn while the asm-ops hooks move from POD strings to functions;
    # see the note in Makefile.in.  Emitting nothing rather than deleting the
    # code, so the boundary decision can turn it back on in one place.
  }
  else if (cpu == "mmix")
    printf "# target-asm-ops-mmix.o omitted: DATA_SECTION_ASM_OP is a function call.\n\n";
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

  cpu = ""; md = ""; tmp = ""; xmodes = ""; cof = "";
}

# The registry the selector includes: one declaration per back end plus a list
# naming them all.  Generated here rather than by configure because this file
# already walks the manifest and knows every cpu_type.
function emit_asm_ops_registry(	i, n, parts) {
  n = split(asm_ops_bases, parts, " ");

  printf "# MULTI_TARGET_ASM_OPS_OBJS withdrawn; see Makefile.in.\n";
  return;
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

$1 == "cpu_type"  { cpu = $2 }
$1 == "common_out_file" { cof = $2 }
$1 == "md_file"   { md = $2 }
$1 == "extra_modes" { xmodes = $2 }
$1 == "tm_p_file" { tmp = ""; for (i = 2; i <= NF; i++) tmp = tmp $i " " }
NF == 0		  { flush() }
END		  { flush(); emit_asm_ops_registry() }
