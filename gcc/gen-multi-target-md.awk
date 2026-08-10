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
    { cpu = ""; md = ""; tmp = ""; xmodes = ""; return }
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
  n = split("preds flags", parts, " ");
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

  # tm-<base>.h names this, so that a back end compiled against it gets its own
  # HAVE_* rather than the configured target's.  Upstream feeds genflags
  # insn-conditions.md as well, which resolves each pattern's condition to 1 or
  # 0 up front; that file comes from gencondmd, which is itself built against
  # one target and is not per-back-end yet.  Without it genflags emits the
  # condition as the body of the HAVE_* macro, which is what GCC did before
  # gencondmd existed -- correct, just not pre-evaluated.
  printf "insn-flags-%s.h: build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s\n", md;
  printf "\t$(RUN_GEN) build/genflags-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s > tmp-flags-%s.h\n", md, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-flags-%s.h $@\n", cpu;
  printf "%s-common.o: insn-flags-%s.h insn-modes-%s.h\n\n", cpu, cpu, cpu;

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

  cpu = ""; md = ""; tmp = ""; xmodes = "";
}

$1 == "cpu_type"  { cpu = $2 }
$1 == "md_file"   { md = $2 }
$1 == "extra_modes" { xmodes = $2 }
$1 == "tm_p_file" { tmp = ""; for (i = 2; i <= NF; i++) tmp = tmp $i " " }
NF == 0		  { flush() }
END		  { flush() }
