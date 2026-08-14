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
  tmk = ""; tmkp = ""; outf = ""; xobjs = ""; xgobjs = "";
  # Cleared per record like the rest: `cobjs' is deliberately NOT in this list
  # (it is read only on the first record for a back end), but extra_headers is
  # unioned over every record, so a stale value here would attribute one
  # triple's headers to the next triple's back end.
  xhdrs = ""; tgmath = "";
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
#   * A prerequisite need not live under $(srcdir)/config.  rs6000-builtins.o's
#     rule is `rs6000-builtins.o: rs6000-builtins.cc' -- a source GENERATED into
#     the build root by config/rs6000/t-rs6000-headers.  That shape scored 0
#     here, and the "refuse rather than guess" path it fell into is what blocked
#     every rs6000 build.  A bare name is accepted only when some fragment this
#     target includes DECLARED it in `generated_files +=' (scan_hdr_frag has
#     already run for this cpu by the time this is called), so the claim is
#     still the tree's and not this file's.  The caller can tell the two apart
#     by the `/': a returned name with no slash is a build-directory file.
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
      # ... and the generated-source shape, second so that a rule naming both
      # still prefers the checked-in file.
      for (j = 1; j <= m; j++)
	if (toks[j] ~ /^[A-Za-z0-9_.+-]+\.(cc|c)$/ &&
	    ((cpu SUBSEP toks[j]) in seen_hdrgen)) {
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

# The `<cpu>-passes.def' files a back end contributes, read out of its tmake
# fragments' `PASSES_EXTRA +=' lines.
#
# ASKED OF THE FRAGMENT RATHER THAN GUESSED FROM THE NAME.  Every in-tree back
# end that has one calls it `config/<cpu>/<cpu>-passes.def', so
# `test -f config/$cpu/$cpu-passes.def' would give the same answer today, and
# it would be a SECOND authority for a fact the fragment already states.  The
# fragment is where a back end declares this, in the same place and the same
# form upstream reads it from, and it is what upstream's `-include
# $(tmake_file)' would have picked up had the tmake_file been the back end's.
#
# THE VARIABLE THIS REPLACES IS THE WHOLE BUG.  `PASSES_EXTRA' reaches
# gcc/Makefile.in only through `-include $(tmake_file)', and `tmake_file' is
# @tmake_file@ -- substituted from the single legacy `${target}' pass through
# config.gcc, i.e. i386's fragments alone in every build here.  So
# pass-instances.def held i386's target passes and nobody else's, however many
# back ends were configured.  This function reads the BACK-END LIST instead,
# which is the list that is actually in the compiler.
#
# The tmake fragments are scanned in their own right; the `-include' of a
# target's tmake_file stays where it is, and the pass-instances.def rule no
# longer looks at $(PASSES_EXTRA).  gcc/Makefile.in cross-checks the two.
function passes_defs_for(c, frags,	i, n, parts, frag, line, cont, out, tok, j, m, toks) {
  if (c in passes_def_cache)
    return passes_def_cache[c];
  out = "";
  n = split(frags, parts, " ");
  for (i = 2; i <= n; i++) {
    frag = srcdir "/config/" parts[i];
    cont = 0;
    while ((getline line < frag) > 0) {
      sub(/#.*/, "", line);
      if (cont) {
	# A continued value line; keep taking tokens.
      } else if (line ~ /^[ \t]*PASSES_EXTRA[ \t]*\+?=/) {
	sub(/^[ \t]*PASSES_EXTRA[ \t]*\+?=/, "", line);
      } else {
	continue;
      }
      cont = (line ~ /\\[ \t]*$/);
      sub(/\\[ \t]*$/, "", line);
      m = split(line, toks, " ");
      for (j = 1; j <= m; j++) {
	tok = toks[j];
	# The fragments spell these `$(srcdir)/config/<cpu>/<cpu>-passes.def'.
	# Resolve $(srcdir) here, because this script has to OPEN the file
	# (gen-target-passes.awk reads it) as well as name it to make.
	gsub(/\$\(srcdir\)/, srcdir, tok);
	if (tok == "")
	  continue;
	if (index(" " out " ", " " tok " ") == 0)
	  out = out tok " ";
      }
    }
    close(frag);
  }
  passes_def_cache[c] = out;
  return out;
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

  # The DRIVER's extra objects for this back end, accumulated over EVERY record
  # and not just the first for a cpu_type, because `extra_gcc_objs' is set by
  # triple and not by back end: config.gcc gives `x86_64-*-darwin*'
  # darwin-driver.o and `x86_64-*-linux*' nothing, and both are cpu_type i386.
  # Taking the first record's value would make the driver's contents depend on
  # the order the targets were named on the command line -- one name, several
  # authorities, no diagnostic.  So it is a union, keyed by back end, built
  # here and emitted by emit_gcc_driver_objs at END.
  #
  # The tmake fragments are unioned along with it for the same reason: the rule
  # that says which source builds `driver-avr.o' lives in avr/t-avr, which is in
  # avr-elf's tmake_file and need not be in the first avr record seen.
  accumulate_gcc_driver_objs();

  # The user-visible intrinsics headers, unioned per back end over EVERY
  # record for exactly the reason the driver objects above are: `extra_headers'
  # is set by TRIPLE, not by back end.  config.gcc gives `rs6000-*-*' a base
  # list and then adds `ppc-asm.h' again for one further triple, and the
  # vxworks block appends seven `../vxworks/*' headers to whatever back end is
  # underneath it.  Taking the first record's value would make the installed
  # header set depend on the order targets were named -- one name, several
  # authorities, no diagnostic.
  accumulate_extra_headers();

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
  # file that exposed the reason: a `tm.h' include from a source sitting in
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
  # gen-target-ns is separate from gensupport for the reason set out at the
  # top of gen-target-ns.cc -- it is the half that reaches no target header,
  # so build/genconstants can link it -- but the PER-BACK-END generators need
  # both halves exactly as before, and they need this one compiled with THIS
  # back end's GEN_HDR_SUFFIX, which is what putting it on this list does.
  # Leaving it off would not fail here: build/gensupport-<cpu>.o no longer
  # defines gen_target_ns, so every per-back-end generator would fail to link
  # by name, which is the correct way for this to go wrong.
  n = split("rtl read-rtl ggc-none vec gensupport gen-target-ns print-rtl " \
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
    #
    # gencodes takes the same treatment for ONE of the things it writes.  Its
    # CODE_FOR_ enumerators are per back end and must stay so -- two back ends
    # spell the same name for two different patterns -- but NUM_INSN_CODES is
    # an array bound inside `struct target_recog' (recog.h:578) and in
    # lra.cc:631, both indexed by INSN_CODE (insn) in SHARED code.  Measured
    # in a two-target build dir: 15429 for i386 (and so for the shared header)
    # against 20512 for aarch64, so recog.cc indexed a .bss object sized for
    # 15429 with aarch64 codes running to 20511.  See gencodes.cc's note.
    #
    # Note the per-base insn-codes-<cpu>.h gets the union bound too, not just
    # the shared one.  A per-base header keeping its own count would put two
    # different sizes of `struct target_recog' in one link, which is the
    # layout-disagreement bug this branch has already paid for once.
    ufl = (parts[i] == "config") \
	  ? sprintf(" -Uinsn-config-union.list -A%s", cpu) : "";
    udep = (parts[i] == "config") ? " insn-config-union.list" : "";
    if (parts[i] == "codes") {
      ufl = sprintf(" -Uinsn-codes-union.list -A%s", cpu);
      udep = " insn-codes-union.list";
    }

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

  # And the same for gencodes' one unioned value.  Written out rather than
  # folded into a loop with the genconfig case above: the two generators take
  # different .md inputs in principle and sharing the emitter here would be a
  # second authority for the argument list.
  printf "insn-codes-%s.part: build/gencodes-%s$(build_exeext) $(srcdir)/common.md \\\n",
	 cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t$(RUN_GEN) build/gencodes-%s$(build_exeext) -l -A%s \\\n", cpu, cpu;
  printf "\t  $(srcdir)/common.md $(srcdir)/config/%s insn-conditions-%s.md \\\n",
	 md, cpu;
  printf "\t  > tmp-codes-%s.part\n", cpu;
  printf "\t@grep -q '^base %s$$' tmp-codes-%s.part || { \\\n", cpu, cpu;
  printf "\t  echo 'insn-codes-%s.part: no \"base %s\" line;' >&2; \\\n", cpu, cpu;
  printf "\t  echo '  the union would then be taken over the OTHER back ends' >&2; \\\n";
  printf "\t  echo '  and this one would be sized for somebody else.' >&2; \\\n";
  printf "\t  exit 1; }\n";
  # ASSERT ON THE CONTENT, BY NAME.  A part file with a `base' line and no
  # NUM_INSN_CODES line parses, contributes a base, and makes genconfig-style
  # `seen_max != nbases' the only thing standing between here and a bound of
  # zero.  Check the key is present rather than trusting the exit status: a
  # generator that runs, exits 0 and writes nothing useful is this branch's
  # most expensive recurring failure.
  printf "\t@grep -q '^NUM_INSN_CODES [0-9]' tmp-codes-%s.part || { \\\n", cpu;
  printf "\t  echo 'insn-codes-%s.part: no NUM_INSN_CODES line;' >&2; \\\n", cpu;
  printf "\t  echo '  gencodes -l ran and produced no bound to union.' >&2; \\\n";
  printf "\t  exit 1; }\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-codes-%s.part $@\n\n",
	 cpu;
  codes_parts = codes_parts " insn-codes-" cpu ".part";
  codes_bases = codes_bases " " cpu;

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

  # genopinit takes the union flags for the same reason genconfig does:
  # `NUM_OPTAB_PATTERNS' sizes `pat_enable[]' inside the SHARED `struct
  # target_optabs', so it cannot be per back end.  See the long note at the
  # top of genopinit.cc, and emit_opinit_union below.
  printf "mt-%s/insn-opinit-%s.cc insn-opinit-%s.h: s-opinit-%s; @true\n", cpu, cpu, cpu, cpu;
  printf "s-opinit-%s: build/genopinit-%s$(build_exeext) $(srcdir)/common.md \\\n", cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md insn-opinit-union.list\n", md, cpu;
  printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
  printf "\t$(RUN_GEN) build/genopinit-%s$(build_exeext) \\\n", cpu;
  printf "\t  -Uinsn-opinit-union.list -A%s $(srcdir)/common.md \\\n", cpu;
  printf "\t  $(srcdir)/config/%s insn-conditions-%s.md \\\n", md, cpu;
  printf "\t  -htmp-opinit-%s.h -ctmp-opinit-%s.cc\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-opinit-%s.h insn-opinit-%s.h\n", cpu, cpu;
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-opinit-%s.cc mt-%s/insn-opinit-%s.cc\n", cpu, cpu, cpu;
  printf "\t$(STAMP) s-opinit-%s\n\n", cpu;

  # This back end's contribution to the opinit union file.  Same shape as
  # insn-config-<cpu>.part, including the `base' assertion: a part file with
  # no `base' line would make the union silently narrower.
  printf "insn-opinit-%s.part: build/genopinit-%s$(build_exeext) $(srcdir)/common.md \\\n",
	 cpu, cpu;
  printf "  $(srcdir)/config/%s insn-conditions-%s.md\n", md, cpu;
  printf "\t$(RUN_GEN) build/genopinit-%s$(build_exeext) -l -A%s \\\n", cpu, cpu;
  printf "\t  $(srcdir)/common.md $(srcdir)/config/%s insn-conditions-%s.md \\\n",
	 md, cpu;
  printf "\t  > tmp-opinit-%s.part\n", cpu;
  # `grep -c ... -eq 1' rather than `grep -q': under a pipeline `grep -q'
  # exits 141 on SIGPIPE, which scores a MATCH as a miss.
  printf "\t@test `grep -c '^base %s$$' tmp-opinit-%s.part` -eq 1 || { \\\n", cpu, cpu;
  printf "\t  echo 'insn-opinit-%s.part: no \"base %s\" line;' >&2; \\\n", cpu, cpu;
  printf "\t  echo '  the union would then be taken over the OTHER back ends' >&2; \\\n";
  printf "\t  echo '  and struct target_optabs sized for somebody else.' >&2; \\\n";
  printf "\t  exit 1; }\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-opinit-%s.part $@\n\n",
	 cpu;
  opinit_parts = opinit_parts " insn-opinit-" cpu ".part";

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
  # Back ends that share default-common.cc are NOT skipped any more.  They used
  # to be, because tm-<base>.h was generated per *common file* base rather than
  # per cpu_type, so ft32, moxie and rl78 -- the three back ends where those two
  # keys come apart -- had no tm-ft32.h to compile against.  That was a property
  # of gen-target-manifest.sh, not of the back ends: sharing default-common.cc
  # means only that a back end has no common-hook overrides of its own.  The
  # manifest loop now deduplicates the per-back-end headers on cpu_type, so all
  # 48 have tm-<base>.h, options-<base>.h and insn-constants-<base>.h.
  if (cpu == "mmix") {
    printf "# target-asm-ops-mmix.o omitted: DATA_SECTION_ASM_OP calls mmix_data_section_asm_op (),\n";
    printf "# which is defined in config/mmix/mmix.cc -- not linked unless mmix is the primary.\n\n";
  }
  else {
  printf "target-asm-ops-%s.o: $(srcdir)/target-asm-ops.cc tm-%s.h \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/target-asm-ops.h\n";
  printf "\t$(COMPILE) -DTM_H_FILE='\"tm-%s.h\"' \\\n", cpu;
  printf "\t  -DTARGETM_ASM_OPS_SYMBOL=targetm_asm_ops_%s \\\n", cpu;
  # This TU is on the SUPPLY side of defaults.h's (c-DATA) redirection: it is
  # compiled against one base's tm.h in order to capture that base's own macro
  # values, so it must see the real macros and not the per-config slots.
  # MULTI_TARGET_TARGETM_BASE cannot be used to say so -- target.h:392 requires
  # it to be paired with -Dtargetm=, and this TU is not renamed -- and it is
  # built for all 45 bases rather than only the MULTI_TARGET_OBJS ones, so it
  # is genuinely a third category and needs its own name.
  printf "\t  -DMULTI_TARGET_SUPPLY_TU=1 \\\n";
  printf "\t  $(srcdir)/target-asm-ops.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
    asm_ops_objs = asm_ops_objs " target-asm-ops-" cpu ".o";
    asm_ops_bases = asm_ops_bases " " cpu;
  }

  # The forwarding-header directory described at MULTI_TARGET_INC_STEMS in
  # BEGIN.  This back end's objects reach their own generated headers by
  # naming this directory, through BASE_HEADER.
  #
  # Emitted for every back end, including the three that share
  # default-common.cc: their tm-<base>.h, options-<base>.h and
  # insn-constants-<base>.h now have rules like everyone else's, so a
  # forwarder here points at something that is built.
  {
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
    # THE SAME HEADERS, ALSO NEEDED BEFORE THE SHARED options.h EXISTS.
    #
    # <cpu>-inc/s-inc is the right place for the objects that are compiled per
    # back end, but it is far too late for the UNION options.h: that header
    # #includes every back end's <cpu>-opts.h through the `I' records, and
    # config/arm/arm-opts.h opens with `#include "arm-isa.h"' -- a header
    # generated into the build root by config/arm/t-arm-headers.  So every
    # translation unit that reaches options.h, INCLUDING the generator
    # objects (gencheck.cc gets there via tm.h), needs arm-isa.h to exist,
    # and none of them has any reason to depend on arm-inc/s-inc.
    #
    # Measured with 47 back ends configured: build/gencheck.o failed with
    # `arm-isa.h: No such file or directory' while the RULE for arm-isa.h was
    # present in multi-target-md.mk the whole time.  Absence of an artefact is
    # not absence of a rule -- a rule nothing depends on is never run -- which
    # is the same confusion scan_hdr_frag was written to fix, met again one
    # level up.
    #
    # This accumulates across back ends and is attached to s-options-h in
    # Makefile.in.  It is deliberately the SAME hdrgen[] list rather than a
    # second one kept here, so the two cannot drift.
    # EMITTED BEFORE THE s-inc RULE, not after it.  A variable assignment
    # between a target line and its recipe is not a stray line make ignores:
    # it ENDS the rule, and the tab-indented recipe that follows then belongs
    # to no target at all --
    #     multi-target-md.mk:484: *** recipe commences before first target.
    # which names the assignment's line number and says nothing about s-inc.
    if (hdrgen[cpu] != "")
      printf "MULTI_TARGET_GEN_HDRS +=%s\n", hdrgen[cpu];
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
    # THE WITNESS TAG, which makes the two `-D's that say which back end an
    # object is compiled for check each other.  See multi-target-base.h: it
    # builds the directory from MT_BASE and the file name from
    # MULTI_TARGET_TARGETM_BASE, and this file exists in exactly one base's
    # directory, so a disagreement is a fatal error naming both halves.
    #
    # Written through move-if-change like the forwarders, and for the same
    # reason: its content never changes once written, only its timestamp
    # would, and the stamp below is what every object rule depends on.
    printf "\techo \"/* Generated; see gcc/multi-target-base.h.  */\" \\\n";
    printf "\t  > tmp-inc-%s.h\n", cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-inc-%s.h \\\n", cpu;
    printf "\t  %s-inc/mt-inc-tag-%s.h\n", cpu, cpu;
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
# Run for EVERY triple.  This used to return early for the back ends sharing
# default-common.cc, on the ground that they had no options-<base>.h or
# insn-constants-<base>.h to build a tm.h against -- true at the time, and the
# reason was a key confusion in gen-target-manifest.sh rather than anything
# about those back ends.  While it stood, five triples (ft32-unknown-elf, the
# three moxie ones and rl78-unknown-elf) got no tm-<triple>.h and no
# generators, yet were still listed in the manifest and still mapped to their
# bases in MT_OPTION_TARGET_BASES -- so multi_target_options_select would find
# the triple, look up base `ft32, and find no tables, which the comment beside
# that loop calls impossible.
function emit_triple(	key, hdrs, i, n, parts, ssh, ssdep) {
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

# The same registry for the addressing tables.  Keyed on mt_bases -- the back
# ends whose objects are in the archive -- rather than on asm_ops_bases, for
# the reason given where target-addr-<cpu>.o is emitted: a table for a back end
# whose <cpu>.cc is not linked would not link.
#
# So the two registries are deliberately over DIFFERENT sets, and that is worth
# stating because the obvious tidy-up -- one shared list -- would be wrong in
# whichever direction it was resolved: it would either drop the 43 asm-ops
# tables that legitimately exist for unbuilt back ends, or invent addr tables
# that cannot link.
function emit_addr_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "multi-target-addr.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_addr targetm_addr_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_ADDR_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_ADDR_ENTRY (\"%s\", targetm_addr_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-addr.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-addr.h $@\n\n";
  printf "target-addr-select.o: multi-target-addr.h\n\n";
}

# And the same for the (c-DATA) refresh functions.  A FUNCTION per base, not a
# table: these values depend on option state, so there is nothing to
# constant-initialise.  See target-cdata.h.
function emit_cdata_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "multi-target-cdata.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern void targetm_cdata_refresh_%s (struct target_cdata *);'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_CDATA_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_CDATA_ENTRY (\"%s\", targetm_cdata_refresh_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-cdata.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-cdata.h $@\n\n";
  printf "target-cdata-select.o: multi-target-cdata.h\n\n";
}

# And the same for the C-family entry points.  See target-c-ops.h.
#
# Keyed on mt_bases -- the back ends whose objects are in the archive -- and
# NOT on every back end in the manifest, for the same reason target-addr
# records: the table's members are calls INTO the back end (i386's expansion is
# `ix86_target_macros ()', defined in this back end's own <cpu>-c.o), so a
# table for a back end whose sources are not linked would compile and then fail
# to link.
function emit_c_ops_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "MT_C_OBJS_MOVED = %s\n", c_moved_objs;
  printf "MT_C_TARGET_OBJS =%s target-c-ops-select.o\n", c_target_objs_list;
  # A non-vacuity check, in the generated fragment rather than here: an empty
  # MT_C_TARGET_OBJS would take TARGET_CPU_CPP_BUILTINS out of cc1 altogether
  # and the only symptom would be a link error three steps away.
  if (c_target_objs_list == "") {
    print "gen-multi-target-md.awk: no back end contributed a C-family object;" \
	  " TARGET_CPU_CPP_BUILTINS would have no implementation" \
	  > "/dev/stderr";
    exit 1;
  }
  printf "multi-target-c-ops.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_c_ops targetm_c_ops_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_C_OPS_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_C_OPS_ENTRY (\"%s\", targetm_c_ops_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-c-ops.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-c-ops.h $@\n\n";
  printf "target-c-ops-select.o: multi-target-c-ops.h\n\n";
}

# And the same for the register vocabularies -- a TABLE per base, like the
# addressing one and unlike the (c-DATA) refresh functions, because none of
# these values depends on option state: FIXED_REGISTERS and REG_CLASS_CONTENTS
# are settled by the back end's headers alone.  target-regs.cc constant-
# initialises the table with `constexpr' precisely so that a back end whose
# ALL_REGS somehow did read an option would be a compile error naming it.
#
# Also emits the rule for the UNION WIDTHS, which is the one input on this
# branch that cannot come from a generator: FIRST_PSEUDO_REGISTER and
# N_REG_CLASSES are enum-derived, so the preprocessor cannot read them, and
# `-DIN_GCC' is host-only (Makefile.in:1258) so no build/gen* program sees
# config/<cpu>/<cpu>.h at all.  A host compile plus `nm -S' is the probe that
# works, and it executes nothing, so it stays correct when cross-building.
function emit_regs_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "multi-target-regs.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_regs_desc targetm_regs_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_REGS_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_REGS_ENTRY (\"%s\", targetm_regs_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-regs.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-regs.h $@\n\n";
  printf "target-regs-select.o: multi-target-regs.h\n\n";

  # The widths.  gen-reg-widths.sh refuses every way of learning nothing --
  # no probe objects, a symbol nm did not print, a size of zero -- because a
  # width that came back empty would size the HARD_REG_SET vocabulary of the
  # whole compiler, and would do so in the direction that makes the build
  # succeed.
  printf "multi-target-reg-widths.h: $(MULTI_TARGET_REG_PROBES) \\\n";
  printf "  $(srcdir)/gen-reg-widths.sh\n";
  printf "\t$(SHELL) $(srcdir)/gen-reg-widths.sh \"$(NM)\" $@ \\\n";
  printf "\t  $(MULTI_TARGET_REG_PROBES)\n\n";
}

# And the same for the argument accumulators; see target-cumargs.h.  A TABLE
# per base, like the register vocabulary: INIT_CUMULATIVE_ARGS and its four
# companions are plain macros in config/<cpu>/<cpu>.h, settled by that back
# end's headers and by nothing else.
#
# The bound on `CUMULATIVE_ARGS' -- the SIZE of what these functions write --
# rides along in multi-target-reg-widths.h above, because it comes from the
# same probe object.  Two files would mean two authorities for one measurement.
function emit_cumargs_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "multi-target-cumargs.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_cumargs_desc targetm_cumargs_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_CUMARGS_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_CUMARGS_ENTRY (\"%s\", targetm_cumargs_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-cumargs.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-cumargs.h $@\n\n";
  printf "target-cumargs-select.o: multi-target-cumargs.h\n\n";
}

# And the same for the register stack; see target-regstack.h.  A table per
# base for a reason the other registries do not have: what varies here is not
# a VALUE but whether a whole 3,265-line pass body EXISTS at all.  `STACK_REGS'
# is defined by two back ends of ~50, so the shared compilation of
# reg-stack.cc answered "does this target have a register stack" with i386's
# yes, for every target.
function emit_regstack_registry(	i, n, parts) {
  n = split(mt_bases, parts, " ");

  printf "multi-target-regstack.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo 'extern const struct target_regstack_desc targetm_regstack_%s;'; \\\n",
	   parts[i];
  printf "\t  echo '#define TARGETM_REGSTACK_TABLES \\'; \\\n";
  for (i = 1; i <= n; i++)
    printf "\t  echo '  TARGETM_REGSTACK_ENTRY (\"%s\", targetm_regstack_%s) \\'; \\\n",
	   parts[i], parts[i];
  printf "\t  echo ''; \\\n";
  printf "\t} > tmp-multi-target-regstack.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-regstack.h $@\n\n";
  printf "target-regstack-select.o: multi-target-regstack.h\n\n";
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

# The registry multi-target-options-select.cc includes: every back end's
# command-line option TABLES, and the same many-to-one triple map.
#
# A SEPARATE HEADER FROM multi-target-backends.h, and that is not tidiness.
# multi-target-backends.h names `insn_<base>::recog' and `targetm_<base>' --
# symbols that live in libbackend.a, which the DRIVER does not link.  The
# option tables are exactly the thing the driver needs (it is where `-mabi='
# is validated), so they are declared where a driver object can include them
# and defined in objects that go into libcommon-target.a.  Merging the two
# headers would make xgcc fail to link on `targetm_aarch64'.
function emit_options_registry(	i, n, parts, m, tp, seenb, nu, uniq) {
  n = split(mt_bases, parts, " ");
  m = split(mt_targets, tp, " ");

  # Dedup ONCE, into a list, and use that list for both blocks below.  Two
  # independently-deduplicated loops over the same input is how a declaration
  # and its table entry come to disagree about which back ends exist.
  nu = 0;
  for (i = 1; i <= n; i++)
    if (!(parts[i] in seenb)) {
      seenb[parts[i]] = 1;
      uniq[++nu] = parts[i];
    }

  printf "multi-target-options.h: multi-target.manifest\n";
  printf "\t{ echo '/* Generated from multi-target.manifest; do not edit. */'; \\\n";
  for (i = 1; i <= nu; i++) {
    printf "\t  echo 'extern const struct cl_option cl_options_%s[];'; \\\n",
	   uniq[i];
    printf "\t  echo 'extern const struct cl_enum cl_enums_%s[];'; \\\n",
	   uniq[i];
    printf "\t  echo 'extern const unsigned int cl_enums_%s_count;'; \\\n",
	   uniq[i];
  }
  printf "\t  echo '#define MT_OPTION_TABLES \\'; \\\n";
  for (i = 1; i <= nu; i++)
    printf "\t  echo '  MT_OPTION_TABLE (%s) \\'; \\\n", uniq[i];
  printf "\t  echo '  /* end */'; \\\n";
  printf "\t  echo '#define MT_OPTION_TARGET_BASES \\'; \\\n";
  for (i = 1; i <= m; i++)
    printf "\t  echo '  MT_OPTION_TARGET_BASE (\"%s\", %s) \\'; \\\n",
	   tp[i], mt_base_of[tp[i]];
  printf "\t  echo '  /* end */'; \\\n";
  printf "\t} > tmp-multi-target-options.h\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-multi-target-options.h $@\n\n";
  printf "multi-target-options-select.o: multi-target-options.h\n\n";
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
$1 == "c_target_objs" { cobjs = ""; for (i = 2; i <= NF; i++) cobjs = cobjs $i " " }
$1 == "extra_gcc_objs" { xgobjs = ""; for (i = 2; i <= NF; i++) xgobjs = xgobjs $i " " }
$1 == "extra_modes" { xmodes = $2 }
$1 == "extra_headers" { xhdrs = ""; for (i = 2; i <= NF; i++) xhdrs = xhdrs $i " " }
$1 == "use_gcc_tgmath" { tgmath = $2 }
$1 == "tm_p_file" { tmp = ""; for (i = 2; i <= NF; i++) tmp = tmp $i " " }
$1 == "tm_include_list" { inc = ""; for (i = 2; i <= NF; i++) inc = inc $i " " }
$1 == "tm_defines" { def = ""; for (i = 2; i <= NF; i++) def = def $i " " }
NF == 0		  { flush() }
END		  { flush(); emit_condition_intersections();
		    emit_asm_ops_registry(); emit_addr_registry();
		    emit_cdata_registry();
		    emit_c_ops_registry();
		    emit_regs_registry();
		    emit_cumargs_registry();
		    emit_regstack_registry();
		    emit_backend_registry();
		    emit_options_registry();
		    emit_source_specs();
		    emit_modes_union(); emit_config_union();
		    emit_codes_union();
		    emit_opinit_union();
		    emit_gcc_driver_objs();
		    emit_extra_headers();
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

# THE SHARED `NUM_INSN_CODES' ANSWER.  Same shape as emit_config_union above.
# NUM_INSN_CODES sizes `x_bool_attr_masks[]' and `x_op_alt[]' inside
# `struct target_recog' (recog.h:578) and `insn_code_data[]' (lra.cc:631),
# and shared code indexes all three with `INSN_CODE (insn)' -- i.e. with the
# SELECTED back end's numbering, not the primary's.  Measured in a two-target
# build dir before this: 15429 for i386, which is what the shared header said,
# against 20512 for aarch64.  `default_target_recog' is 0x788a8 bytes of .bss
# sized from 15429 and recog.cc:2707 writes into it at aarch64 codes up to
# 20511.  No link error, no warning.
#
# Only the BOUND is unioned; the CODE_FOR_ enumerators stay per back end,
# because a union of them is not a thing that exists -- two back ends give the
# same name to different patterns.  Shared code spells no enumerator but
# CODE_FOR_nothing, which is 0 everywhere.  See gencodes.cc.
#
# Check it is wired up against the GENERATED fragment, never against this file:
#
#	grep -c ' -Uinsn-codes-union.list ' multi-target-md.mk
function emit_codes_union(   nb, tmp_bases) {
  nb = split(codes_bases, tmp_bases, " ");
  if (nb == 0) {
    print "gen-multi-target-md.awk: no back ends for insn-codes-union.list" \
	  > "/dev/stderr";
    exit 1;
  }

  printf "# The shared NUM_INSN_CODES answer; see emit_codes_union in\n";
  printf "# $(srcdir)/gen-multi-target-md.awk.\n";
  printf "insn-codes-union.list:%s\n", codes_parts;
  printf "\tcat%s > tmp-insn-codes-union.list\n", codes_parts;
  printf "\t@test `grep -c '^base ' tmp-insn-codes-union.list` -eq %d || { \\\n", nb;
  printf "\t  echo 'insn-codes-union.list: expected %d base lines, got' \\\n", nb;
  printf "\t       `grep -c '^base ' tmp-insn-codes-union.list`; \\\n";
  printf "\t  echo '  a short list makes the union too small and every'; \\\n";
  printf "\t  echo '  insn-codes.h silently undersized.'; \\\n";
  printf "\t  exit 1; } >&2\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-insn-codes-union.list $@\n\n";
}

# THE SHARED `NUM_OPTAB_PATTERNS' ANSWER.  Same shape as emit_config_union
# above, and for a sharper reason: `NUM_OPTAB_PATTERNS' is the length of
# `pat_enable[]' inside `struct target_optabs', which is ONE object
# (`default_target_optabs' in optabs-query.cc) shared by the whole compiler.
# Measured in a two-target build dir before this: 2975 for i386 (and so for
# the shared header, the primary's) against 3328 for aarch64, so
# `insn_aarch64::init_all_optabs' wrote 353 bools past the end of an object
# the middle end had sized at 3465 bytes.  Not a link error, not a warning.
#
# Check it is wired up against the GENERATED fragment, never against this file:
#
#	grep -c ' -Uinsn-opinit-union.list ' multi-target-md.mk
function emit_opinit_union(   nb, tmp_bases) {
  nb = split(config_bases, tmp_bases, " ");
  if (nb == 0) {
    print "gen-multi-target-md.awk: no back ends for insn-opinit-union.list" \
	  > "/dev/stderr";
    exit 1;
  }

  printf "# The shared NUM_OPTAB_PATTERNS answer; see emit_opinit_union in\n";
  printf "# $(srcdir)/gen-multi-target-md.awk.\n";
  printf "insn-opinit-union.list:%s\n", opinit_parts;
  printf "\tcat%s > tmp-insn-opinit-union.list\n", opinit_parts;
  printf "\t@test `grep -c '^base ' tmp-insn-opinit-union.list` -eq %d || { \\\n", nb;
  printf "\t  echo 'insn-opinit-union.list: expected %d base lines, got' \\\n", nb;
  printf "\t       `grep -c '^base ' tmp-insn-opinit-union.list`; \\\n";
  printf "\t  echo '  a short list makes the union too small and every'; \\\n";
  printf "\t  echo '  struct target_optabs silently undersized.'; \\\n";
  printf "\t  exit 1; } >&2\n";
  printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-insn-opinit-union.list $@\n\n";
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
#   * the per-back-end forwarding directory supplies every generated header
#     this back end's sources reach.  It must be reached through a
#     target-specific variable inside a RECURSIVE assignment: an immediate
#     `:=' expands before the target-specific value exists and both arms of
#     the test then fail identically, which reads as "the mechanism does not
#     work".
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
function emit_base_objects(	i, n, parts, objs, src, obj, poly, gen,
				pdefs, ptags, pdeps) {
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
  # A `tm.h' include searches the directory OF THE FILE CONTAINING THE
  # DIRECTIVE first.  A generated source sitting in the build root therefore
  # finds the build root's own tm.h -- the PRIMARY target's.
  #
  # This was live and it was nearly silent.  Only insn-modes-aarch64.cc failed,
  # with `aarch64_sve_vg was not declared', because its ADJUST_NUNITS text
  # happens to name an aarch64 symbol that i386's tm.h does not have.  Every
  # other per-base generated source compiled CLEAN against i386's tm.h.  That
  # is the branch's own bug class -- right on the build's triple, wrong
  # everywhere else -- reproduced inside the machinery meant to remove it.
  #
  # The failing case is exactly a build-root source whose own `tm.h' include
  # is the first one reached.  Measured with -H, naming the
  # file actually opened: a build-root insn-modes-aarch64.cc gave 57 errors,
  # the same source under mt-aarch64/ gave 0 and opened aarch64's tm.h.
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
  #
  # *** WHY THESE ARE $(eval)ed EXPLICIT RULES AND NOT PATTERN RULES ***
  #
  # They WERE pattern rules -- `insn-emit-<cpu>-%.o: mt-<cpu>/insn-emit-<cpu>-%.cc'
  # -- and that is a dependency-tracking bug, not a style question.  In a
  # pattern rule `$*' is the STEM, and the stem here is the shard number alone.
  # $(COMPILE)/$(POSTCOMPILE) name the depfile `$(@D)/$(DEPDIR)/$(*F).TPo', so
  # every one of those objects wrote `./.deps/<N>.TPo':
  #
  #   insn-emit-i386-1.o     -> ./.deps/1.TPo      (stem "1")
  #   insn-recog-i386-1.o    -> ./.deps/1.TPo
  #   insn-emit-aarch64-1.o  -> ./.deps/1.TPo
  #   insn-recog-aarch64-1.o -> ./.deps/1.TPo
  #
  # Two failures, and the SECOND is the serious one.
  #
  #   * Four objects race for one file under -j.  That is the intermittent
  #     `mv: cannot stat ./.deps/<N>.TPo' -- one recipe's POSTCOMPILE moves the
  #     file out from under another's.  Loud, but only sometimes.
  #   * Makefile.in READS depfiles under a different name entirely.  DEPFILES
  #     is built as $(dir obj)$(DEPDIR)/$(notdir obj:%.o=%.Po), i.e.
  #     `./.deps/insn-emit-i386-1.Po' -- which nothing ever wrote.  So the
  #     `-include $(DEPFILES)' matched NOTHING for every split object, for
  #     every back end: they had no header dependencies at all and were not
  #     rebuilt when their prerequisites changed.  Silent, and total, and it
  #     survives every clean build.
  #
  # Upstream does not have this because upstream has no pattern rule for them:
  # insn-emit-<N>.o is built by the `.cc.o' SUFFIX rule, where `$*' is the
  # target minus the suffix (`insn-emit-1'), which is exactly what DEPFILES
  # expects.  Every other rule this file emits is explicit and gets the same
  # `$*' for the same reason -- `.o' is in .SUFFIXES -- so these two were the
  # only rules in the generated makefile whose depfile name disagreed with
  # Makefile.in's, and making them explicit puts them back with the others.
  #
  # The shard list is a make variable (@NUM_INSNEMIT_SPLITS@ reaches us only at
  # make time), so the explicit rules are instantiated with $(foreach)/$(eval)
  # rather than written out here.  Note `$$' throughout the define: the body is
  # expanded once by $(eval) and must still contain `$(COMPILE)' and `$<' when
  # make stores the recipe.
  printf "define mt_insn_split_rule_%s\n", cpu;
  printf "insn-$(1)-%s-$(2).o: mt-%s/insn-$(1)-%s-$(2).cc %s-inc/s-inc\n",
	 cpu, cpu, cpu, cpu;
  printf "\t$$(COMPILE)%s $$<\n\t$$(POSTCOMPILE)\n", poly;
  printf "endef\n";
  printf "$(foreach n,$(INSNEMIT_SPLITS_SEQ),$(eval $(call mt_insn_split_rule_%s,emit,$(n))))\n", cpu;
  printf "$(foreach n,$(INSNRECOG_SPLITS_SEQ),$(eval $(call mt_insn_split_rule_%s,recog,$(n))))\n\n", cpu;
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
  # ... and this back end's OWN C-family object.  `c_target_objs' for
  # x86_64-linux is `i386-c.o glibc-c.o': the first is the back end's
  # (config/i386/i386-c.cc, where `ix86_target_macros' lives), the second is
  # the OS's and is shared by every glibc target.  Only the back end's own is
  # moved per base here, and it is selected by asking the tmake fragments where
  # the source lives rather than by matching the name -- `i386-c.o' would match
  # a prefix test, `winnt-c.o' and `msformat-c.o' would not, and both of those
  # belong to the OS side too.
  #
  # glibc-c.o STAYS SHARED, and that is a remaining leak, not a decision that
  # it is fine: it defines `targetcm', whose TARGETCM_INITIALIZER is filled
  # from the primary's tm.h.  Making it per base needs `targetcm' to become a
  # pointer the way `targetm' already has, which is a separate change.
  cobjs_own = ""; cobjs_this = "";
  n = split(cobjs, parts, " ");
  for (i = 1; i <= n; i++) {
    obj = parts[i];
    sub(/\.o$/, "", obj);
    src = frag_source_for(obj, tmkp);
    # A c_target_obj NO FRAGMENT CLAIMS IS A DEFECT, NOT A NON-BACK-END OBJECT,
    # AND IT USED TO LEAVE THIS LOOP SILENTLY.
    #
    # The refusal in the second loop below cannot catch it: that loop iterates
    # over cobjs_own, and an object with src == "" fails the `^config/<cpu>/'
    # test here and is therefore never put in cobjs_own to be refused.  The
    # exclusion runs BEFORE the check, so the check cannot fire -- the
    # `mitigation that cannot fire' shape in PRINCIPLES section 4.
    #
    # Measured: `v850e1-elf' set `c_target_objs="v850-c.o"' while its
    # tmake_file omitted `v850/t-v850', the only fragment carrying the rule.
    # v850-c.o disappeared from MT_C_OBJS_v850 with no word anywhere, and the
    # link failed 8 symbols later at `ghs_pragma_*' -- a name that does not
    # mention v850-c.o, config.gcc, or this loop.
    #
    # $(warning) rather than $(error): the point is that the operator SEES it.
    # An $(error) here would also be defensible, and is deliberately not used
    # yet because this generator runs for all 48 back ends at once and one
    # unfixed fragment would block every one of them.
    #
    # SCOPED TO `<cpu>-c.o', AND THE FIRST DRAFT WAS NOT -- WHICH IS THE
    # LESSON.  Unscoped it fired 48 times on a 48-back-end build, every one of
    # them a FALSE POSITIVE: `default-c.o', `glibc-c.o', `sol2-c.o',
    # `winnt-c.o' and friends are the OS side, built by generic rules in
    # gcc/Makefile.in rather than by any tmake fragment, so src == "" is their
    # NORMAL state.  A warning that fires once per back end on correct input is
    # not a check, it is 48 lines nobody reads -- and it would have buried the
    # one line that mattered.
    #
    # Only `<cpu>-c.o' is the back end's own, only it is expected to live under
    # `config/<cpu>/', and only for it is a missing fragment a defect.  With
    # this scope the warning reads ZERO on a correct 48-base tree; `v850' is
    # its negative control, and reverting the `config.gcc' hunk that added
    # `v850/t-v850' makes it fire by name.
    if (src == "" && obj == (cpu "-c")) {
      printf "$(warning multi-target: %s lists %s in c_target_objs but no" \
	     " tmake fragment claims a rule for it -- it will NOT be built" \
	     " and anything referencing its symbols will fail at link time)\n\n", \
	     cpu, parts[i];
      continue;
    }
    if (src ~ ("^\\$\\(srcdir\\)/config/" cpu "/")) {
      cobjs_own = cobjs_own parts[i] " ";
      # ... and record it so gcc/Makefile.in can take it OUT of C_TARGET_OBJS.
      # C_TARGET_OBJS is @c_target_objs@, the PRIMARY target's list, and the
      # primary's <cpu>-c.o is now built per base in mt-<cpu>/.  Leaving it in
      # both places is not a harmless duplicate: the two objects define the
      # same `ix86_target_macros' and the link would keep one of them by
      # accident of order, which is the COMDAT-body disguise of this bug.
      if (index(" " c_moved_objs " ", " " parts[i] " ") == 0)
	c_moved_objs = c_moved_objs parts[i] " ";
    }
  }

  # Objects at index > nback are the C-family ones.  They are built by the same
  # rules -- same include directory, same renames -- but they must NOT join
  # MULTI_TARGET_OBJS_<cpu>, which goes into libbackend.a and therefore into
  # lto1: <cpu>-c.cc calls `c_register_pragma' and `builtin_define_with_value',
  # which exist only in cc1.  They go to MT_C_TARGET_OBJS instead, which
  # gcc/Makefile.in appends to C_TARGET_OBJS.
  nback = split(outf " " xobjs, parts, " ");
  n = split(outf " " xobjs " " cobjs_own, parts, " ");
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
	#
	# ON ONE LINE, and with no comma in the text.  `$(error ...)' is a make
	# FUNCTION call: a newline inside it ends the logical line before the
	# closing paren and make reports `unterminated call to function error'
	# at the opening line -- so the parse dies and THE MESSAGE IS NEVER
	# PRINTED.  A generator whose refusal path produces an unparseable
	# makefile has refused nothing; it has only changed which diagnostic
	# lies to you.  (Commas would be split into further arguments, which
	# $(error) drops.)
	printf "$(error multi-target: nothing in %s's tmake_file claims a rule for %s.o" \
	       " -- gen-multi-target-md.awk cannot tell which source builds it;" \
	       " add the rule to the fragment that puts %s.o in extra_objs)\n\n",
	       cpu, obj, obj;
	continue;
      }
    }
    # A build-directory source -- one a t-<...>-headers fragment generates --
    # is copied into mt-<cpu>/ before it is compiled, exactly as the generated
    # insn-*.cc are, and for the identical reason: `#include "insn-codes.h"'
    # from a file sitting in the build root finds the build ROOT's copy, which
    # is the PRIMARY target's, whatever the include path says.
    # rs6000-builtins.cc includes insn-codes.h by plain name, so compiling it
    # in place would bind rs6000's builtin table to another target's insn codes.
    #
    # MEASURED, both directions, in an x86_64-primary + powerpc64le build.  The
    # copy in mt-rs6000/ compiles clean and its .deps names
    # `rs6000-inc/insn-codes.h'; the SAME command line pointed at
    # `./rs6000-builtins.cc' opens `./insn-codes.h' (i386's) and stops with 1039
    # `CODE_FOR_altivec_abss_v16qi was not declared' errors.  That it is loud
    # here is luck -- the two targets' CODE_FOR_ sets barely overlap -- and not
    # a reason to rely on it: what the include path decides is which machine the
    # object describes, and a pair of back ends with more names in common would
    # get a quiet wrong answer instead.
    if (src !~ /\//) {
      gen = src;
      printf "mt-%s/%s: %s\n", cpu, gen, gen;
      printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
      # cp to a temporary and then move-if-change: move-if-change RENAMES its
      # first argument, so handing it $< directly would delete the build root's
      # copy that every other consumer of the fragment still depends on.
      printf "\tcp $< tmp-mt-%s-%s\n", cpu, gen;
      printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-mt-%s-%s $@\n\n", cpu, gen;
      src = "mt-" cpu "/" gen;
    }
    printf "mt-%s/%s.o: %s %s-inc/s-inc s-gtype\n", cpu, obj, src, cpu;
    printf "\t@$(mkinstalldirs) mt-%s/$(DEPDIR)\n", cpu;
    printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
    if (i > nback)
      cobjs_this = cobjs_this " mt-" cpu "/" obj ".o";
    else
      objs = objs " mt-" cpu "/" obj ".o";
  }

  # This back end's addressing register-class predicates -- the `addresses.h'
  # funnels, compiled against ITS headers.  See target-addr.h.
  #
  # Emitted HERE, in the loop over back ends that have objects, and NOT in the
  # loop that emits target-asm-ops-<base>.o for all 45.  The difference is not
  # tidiness.  target-asm-ops.cc's initialisers are strings out of tm.h and
  # link against nothing; target-addr.cc's expand to BACK-END FUNCTIONS --
  # aarch64_regno_ok_for_base_p, riscv_index_reg_class, pru_regno_ok_for_base_p
  # and so on -- which exist only if that back end's own .cc files are linked.
  # For a base outside this loop the object would compile and then fail to
  # link, which is exactly the trap target-asm-ops.cc records for mmix.
  #
  # No -DTM_H_FILE: this object is in MULTI_TARGET_OBJS_<cpu>, so it inherits
  # the target-specific assignments below and its BASE_HEADER (tm.h) already
  # names this back end's.  Naming the file twice would be a second authority
  # for the same fact.
  printf "target-addr-%s.o: $(srcdir)/target-addr.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(RTL_H) $(REGS_H) \\\n";
  printf "  $(srcdir)/target-addr.h\n";
  printf "\t$(COMPILE) -DTARGETM_ADDR_SYMBOL=targetm_addr_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-addr.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  objs = objs " target-addr-" cpu ".o";

  # This back end's (c-DATA) refresh function; see target-cdata.h.  Same loop
  # and the same reason as target-addr-<cpu>.o above -- it must be compiled
  # against this back end's headers, and it must carry
  # -DMULTI_TARGET_TARGETM_BASE (which the target-specific assignment below
  # supplies) so that defaults.h leaves it the REAL macros rather than the
  # redirected ones it exists to fill.
  printf "target-cdata-%s.o: $(srcdir)/target-cdata.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(srcdir)/target-cdata.h\n";
  printf "\t$(COMPILE) -DTARGETM_CDATA_SYMBOL=targetm_cdata_refresh_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-cdata.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  objs = objs " target-cdata-" cpu ".o";

  # This back end's C-family entry points; see target-c-ops.h.  Same loop and
  # the same reason once more, and here the link argument is not hypothetical:
  # the table's members expand to `ix86_target_macros ()' and
  # `ix86_register_pragmas ()', which live in mt-<cpu>/<cpu>-c.o -- an object
  # that exists only for the back ends this loop runs over.
  #
  # It needs tm_p.h, not just tm.h: the expansion is a call, and the prototype
  # for it is in config/<cpu>/<cpu>-protos.h, which tm_p.h is what includes.
  printf "target-c-ops-%s.o: $(srcdir)/target-c-ops.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(srcdir)/target-c-ops.h\n";
  printf "\t$(COMPILE) -DTARGET_C_OPS_SYMBOL=targetm_c_ops_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-c-ops.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  # Same reasoning as mt-<cpu>/<cpu>-c.o above: this table calls into that
  # object, so it belongs to cc1 and not to libbackend.a.
  cobjs_this = cobjs_this " target-c-ops-" cpu ".o";

  # This back end's register vocabulary; see target-regs.h.  Same loop and the
  # same reason again -- the six data macros are plain macros in
  # config/<cpu>/<cpu>.h and the only way to read THIS back end's is to
  # compile against its headers.  It carries -DMULTI_TARGET_TARGETM_BASE from
  # the assignment below, which is what keeps defaults.h from redirecting
  # ALL_REGS and REGNO_REG_CLASS in the one file whose job is to supply them:
  # without it this table would report the poison back to itself.
  printf "target-regs-%s.o: $(srcdir)/target-regs.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(RTL_H) \\\n";
  printf "  $(srcdir)/target-regs.h multi-target-reg-widths.h\n";
  printf "\t$(COMPILE) -DTARGETM_REGS_SYMBOL=targetm_regs_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-regs.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  objs = objs " target-regs-" cpu ".o";

  # This back end's argument-accumulator entry points; see target-cumargs.h.
  # Same loop and the same reason a fourth time: INIT_CUMULATIVE_ARGS is
  # `init_cumulative_args' for i386 and `aarch64_init_cumulative_args' for
  # aarch64, and the only way to get THIS back end's is to compile against its
  # headers.  It also measures this base's `sizeof (CUMULATIVE_ARGS)' against
  # the union bound, which is the check that turns an 88-byte stack overflow
  # into a compile error naming the base.
  #
  # It needs tm_p.h for the same reason target-c-ops-<cpu>.o does: the macros
  # expand to CALLS, and the prototypes are in config/<cpu>/<cpu>-protos.h.
  #
  # MULTI_TARGET_OBJS_<cpu>, deliberately, and NOT the c-family list:
  # function.o, calls.o, expr.o, dse.o and var-tracking.o are all in
  # libbackend.a and therefore in lto1 as well as cc1, and everything this
  # table calls (`aarch64_init_cumulative_args', `ix86_call_abi_override') is
  # a back-end function already in that same archive.  The opposite placement
  # was right for target-c-ops-<cpu>.o only because THAT table calls into
  # c-family, which lto1 does not link.
  printf "target-cumargs-%s.o: $(srcdir)/target-cumargs.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(RTL_H) $(TREE_H) \\\n";
  # target-frame.h and target-insn.h are named EXPLICITLY even though
  # target-cumargs.h includes both.  make does not follow includes, and the
  # `$(POSTCOMPILE)' .deps file only exists after a first successful compile --
  # so on a fresh tree a change to either header would not rebuild these
  # objects, and the symptom is a table whose layout disagrees with the
  # selector's idea of it: silent, and indistinguishable from a stale object.
  printf "  $(TM_P_H) $(TARGET_H) $(srcdir)/target-cumargs.h \\\n";
  printf "  $(srcdir)/target-frame.h $(srcdir)/target-insn.h \\\n";
  printf "  $(srcdir)/target-preds.h $(srcdir)/target-attr.h \\\n";
  printf "  multi-target-reg-widths.h\n";
  printf "\t$(COMPILE) -DTARGETM_CUMARGS_SYMBOL=targetm_cumargs_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-cumargs.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  objs = objs " target-cumargs-" cpu ".o";

  # This back end's REGISTER STACK; see target-regstack.h.  Not a table of
  # values like the four above but a whole pass body, compiled per base
  # because the question it answers -- `#ifdef STACK_REGS' -- is one only this
  # back end's headers can answer, and answering it once for everybody gave
  # every target i386's yes.
  #
  # It needs the same prerequisites as any middle-end object because it IS
  # one: the body calls into df, cfgrtl, recog and emit-rtl.  What it also
  # needs, and what shared compilation could not give it, is THIS base's
  # insn-flags-<cpu>.h: reg-stack.cc:1170 spells `gen_movxf', and only a back
  # end with an XFmode move pattern has it.  Compiled per base the name is
  # inside `#ifdef STACK_REGS' and therefore only in a translation unit whose
  # own insn-flags has it -- which is why no forwarder for `gen_movxf' is
  # needed here, or anywhere.
  printf "target-regstack-%s.o: $(srcdir)/target-regstack.cc %s-inc/s-inc \\\n", cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h $(BACKEND_H) $(RTL_H) \\\n";
  printf "  $(TREE_H) $(DF_H) $(TM_P_H) $(TARGET_H) $(RECOG_H) $(REGS_H) \\\n";
  # Named by PATH, not through a `$(FOO_H)' variable, for the ones Makefile.in
  # has no variable for.  An undefined make variable expands to the empty
  # string, so `$(CFGRTL_H)' would be a dependency silently not taken -- the
  # stale-object failure target-cumargs-<cpu>.o's comment describes, with no
  # diagnostic at all.
  printf "  $(EMIT_RTL_H) insn-config.h $(srcdir)/rtl-error.h \\\n";
  printf "  $(srcdir)/cfgrtl.h $(srcdir)/cfganal.h $(srcdir)/cfgbuild.h \\\n";
  printf "  $(srcdir)/cfgcleanup.h $(srcdir)/reload.h $(srcdir)/varasm.h \\\n";
  printf "  $(srcdir)/rtl-iter.h $(srcdir)/function-abi.h \\\n";
  printf "  $(TREE_PASS_H) $(srcdir)/target-regstack.h\n";
  printf "\t$(COMPILE) -DTARGETM_REGSTACK_SYMBOL=targetm_regstack_%s \\\n", cpu;
  printf "\t  $(srcdir)/target-regstack.cc\n";
  printf "\t$(POSTCOMPILE)\n\n";
  objs = objs " target-regstack-" cpu ".o";

  # And this back end's WIDTH PROBE.  Deliberately NOT in
  # MULTI_TARGET_OBJS_<cpu>: it is never linked, it is compiled so that `nm -S'
  # can read two array sizes back out of it, and -DMULTI_TARGET_REG_PROBE is
  # what stops defaults.h overriding the very widths it exists to measure.
  # See multi-target-reg-probe.cc for why this is not a generator.
  printf "mt-%s/reg-probe.o: $(srcdir)/multi-target-reg-probe.cc %s-inc/s-inc \\\n",
	 cpu, cpu;
  printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h\n";
  printf "\t@$(mkinstalldirs) mt-%s/$(DEPDIR)\n", cpu;
  printf "\t$(COMPILE) -DMULTI_TARGET_REG_PROBE $<\n";
  printf "\t$(POSTCOMPILE)\n";
  # The base by NAME; see multi-target-base.h.
  printf "mt-%s/reg-probe.o: MULTI_TARGET_BASE_DEF = -DMT_BASE=%s-inc\n\n",
	 cpu, cpu;
  printf "MULTI_TARGET_REG_PROBES += mt-%s/reg-probe.o\n\n", cpu;

  # THIS BACK END'S TARGET PASSES.
  #
  # Two things come out of `<cpu>-passes.def' and they go in opposite
  # directions.  The DIRECTIVES go to gen-pass-instances.awk, which puts them
  # in the one shared pass-instances.def with each inserted pass renamed
  # `<pass>_mt_<cpu>' -- that is the tag list below.  The FACTORIES go here,
  # into a forwarder translation unit compiled with THIS back end's headers
  # and THIS back end's renames, because `make_pass_insert_bti' is a
  # MULTI_TARGET_RENAME_NAMES symbol (aarch64 and arm both define it) and no
  # bare name for it exists in the linked compiler for shared code to call.
  #
  # Same shape and the same argument as target-addr-<cpu>.o and
  # target-c-ops-<cpu>.o above: a shared source cannot read a back end's own
  # protos header, so the object that does is built once per back end.  The
  # difference is only that this one's body is generated, because its contents
  # are a function of that back end's passes.def rather than of a fixed
  # template.
  pdefs = passes_defs_for(cpu, tmkp);
  if (pdefs != "") {
    ptags = ""; pdeps = "";
    n = split(pdefs, parts, " ");
    for (i = 1; i <= n; i++) {
      printf "MT_PASSES_DEFS += %s\n", parts[i];
      printf "MT_PASSES_TAGS += %s=%s\n", parts[i], cpu;
      ptags = ptags parts[i] "=" cpu " ";
      pdeps = pdeps " " parts[i];
    }
    printf "\n";

    printf "mt-%s/target-passes-%s.cc: $(srcdir)/gen-target-passes.awk%s\n",
	   cpu, cpu, pdeps;
    printf "\t@$(mkinstalldirs) mt-%s\n", cpu;
    printf "\t$(AWK) -f $(srcdir)/gen-target-passes.awk -v mode=source \\\n";
    printf "\t  -v want_base=%s -v pass_bases='%s' \\\n", cpu, ptags;
    printf "\t  > tmp-target-passes-%s.cc\n", cpu;
    printf "\t$(SHELL) $(srcdir)/../move-if-change tmp-target-passes-%s.cc $@\n\n",
	   cpu;

    printf "mt-%s/target-passes-%s.o: mt-%s/target-passes-%s.cc \\\n",
	   cpu, cpu, cpu, cpu;
    printf "  %s-inc/s-inc multi-target-passes.h s-gtype \\\n", cpu;
    printf "  $(CONFIG_H) $(SYSTEM_H) $(CORETYPES_H) $(srcdir)/multi-target-base.h \\\n";
    printf "  $(TREE_H) $(GIMPLE_H) $(RTL_H) $(TREE_PASS_H) $(CONTEXT_H)\n";
    printf "\t@$(mkinstalldirs) mt-%s/$(DEPDIR)\n", cpu;
    printf "\t$(COMPILE)%s $<\n\t$(POSTCOMPILE)\n\n", poly;
    objs = objs " mt-" cpu "/target-passes-" cpu ".o";
  }

  printf "MULTI_TARGET_OBJS_%s =%s\n", cpu, objs;
  # The base by NAME; see multi-target-base.h.
  printf "$(MULTI_TARGET_OBJS_%s): MULTI_TARGET_BASE_DEF = -DMT_BASE=%s-inc\n",
	 cpu, cpu;
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

  # This back end's C-family objects.  A SECOND list with the SAME two
  # target-specific assignments, because they need the identical treatment --
  # their own include directory and their own renames -- and differ only in
  # which link they belong to.  Folding them into MULTI_TARGET_OBJS_<cpu> to
  # get the assignments for free is the obvious tidy-up and it breaks lto1;
  # leaving them OUT of the assignments is the other obvious shortcut and it
  # compiles config/aarch64/aarch64-c.cc against i386-inc, which fails with 40
  # `TARGET_SIMD was not declared in this scope' -- loudly here, but only
  # because the two back ends happen to spell their feature macros
  # differently.
  printf "MT_C_OBJS_%s =%s\n", cpu, cobjs_this;
  printf "$(MT_C_OBJS_%s): MULTI_TARGET_BASE_DEF = -DMT_BASE=%s-inc\n", cpu, cpu;
  printf "$(MT_C_OBJS_%s): MULTI_TARGET_RENAMES = \\\n", cpu;
  printf "  $(foreach n,$(MULTI_TARGET_RENAME_NAMES),-D$(n)=$(n)_%s) \\\n", cpu;
  printf "  -DMULTI_TARGET_TARGETM_BASE=%s\n\n", cpu;
  c_target_objs_list = c_target_objs_list " $(MT_C_OBJS_" cpu ")";

  mt_bases = mt_bases " " cpu;
  # One back end at a time, by name.  Needed for more than convenience: the
  # control that shows these objects read THEIR OWN headers rather than the
  # primary's poisons one base's tm.h and requires the other base still to
  # build, and that arm cannot be expressed without building one base alone.
  printf ".PHONY: multi-target-objs-%s\n", cpu;
  printf "multi-target-objs-%s: $(MULTI_TARGET_OBJS_%s)\n\n", cpu, cpu;
}

# Record one manifest record's `extra_headers' against its back end.
#
# The path is built here, from THIS record's cpu_type, and that is the half
# gcc/configure.ac got wrong: it prepends `$(srcdir)/config/${cpu_type}/' using
# the ONE legacy ${target}'s cpu_type, so every entry in @extra_headers_list@
# names a file under config/i386/ whatever back end asked for it.  A relative
# entry (`../vxworks/math.h') is resolved against the back end's own directory,
# which is what config.gcc means by it.
function accumulate_extra_headers(	i, n, parts, p) {
  n = split(xhdrs, parts, " ");
  for (i = 1; i <= n; i++) {
    if (parts[i] == "")
      continue;
    p = "$(srcdir)/config/" cpu "/" parts[i];
    if (index(" " mthdrs[cpu] " ", " " p " ") == 0) {
      mthdrs[cpu] = mthdrs[cpu] p " ";
      if (index(" " mthdr_bases " ", " " cpu " ") == 0)
	mthdr_bases = mthdr_bases cpu " ";
    }
  }
  # <tgmath.h> is gcc's own, not the back end's, but WHETHER a target gets it
  # is per target, so it is unioned into that back end's set rather than into
  # the shared USER_H list.
  if (tgmath == "yes") {
    p = "$(srcdir)/ginclude/tgmath.h";
    if (index(" " mthdrs[cpu] " ", " " p " ") == 0) {
      mthdrs[cpu] = mthdrs[cpu] p " ";
      if (index(" " mthdr_bases " ", " " cpu " ") == 0)
	mthdr_bases = mthdr_bases cpu " ";
    }
  }
}

# THE INTRINSICS HEADERS OF EVERY CONFIGURED BACK END, EACH IN ITS OWN
# DIRECTORY.
#
# `EXTRA_HEADERS' in gcc/Makefile.in is `@extra_headers_list@', substituted by
# gcc/configure.ac:2252 from the single legacy ${target} pass through
# config.gcc.  So in a build holding 47 back ends it is i386's 118 headers and
# nobody else's, `<builddir>/gcc/include/' contained cpuid.h and the mmintrin
# family alone, and compiling anything for aarch64 that says
#
#     #include <arm_neon.h>
#
# failed with `No such file or directory' -- 62,464 aarch64 testsuite failures,
# 2,900 of them arm_neon.h, 571 arm_sve.h, and arm_neon_sve_bridge.h the single
# largest line on the board.  Leaked ABSENCE for 13 back ends; leaked PRESENCE
# for i386, whose headers were on every target's search path.
#
# WHY THIS IS NOT THE PASSES_EXTRA SHAPE, THOUGH IT IS THE SAME ROOT.  For
# PASSES_EXTRA (b349257c0a2) it was enough to derive the list from the back-end
# list and tag each file with its owner, because the consumer -- one
# pass-instances.def -- can hold every back end's entries side by side once
# they are distinguishable.  A header search path cannot: the name IS the
# lookup key.  Measured over all 47 back ends, 18 basenames are claimed by more
# than one back end and are different files in each --
#
#   mmintrin.h                              arm, i386, rs6000
#   arm_neon.h arm_acle.h arm_fp16.h arm_bf16.h        aarch64, arm
#   htmintrin.h htmxlintrin.h                          rs6000, s390
#   {x,e,p,t,s,n,i}mmintrin.h x86intrin.h x86gprintrin.h
#   bmiintrin.h bmi2intrin.h                           i386, rs6000
#
# -- so a union into one `include/' is not a union at all, it is 18 silent
# overwrites whose winner is decided by the order of a shell `for' loop.  aarch64
# users would get arm's arm_neon.h.  Hence one directory per back end,
# `include-<cpu_type>/', and the search path picks the selected base's.
#
# Keyed on cpu_type and not on the triple because that is the granularity of
# the fact: extra_headers is a property of the back end (all 188 triples of a
# back end install the same intrinsics), while the per-target directory
# $(libsubdir)/<target>/ holds facts that really are per triple -- specs-config
# and include-fixed, both probed on the deployed machine.
function emit_extra_headers(	i, n, parts, c) {
  n = split(mthdr_bases, parts, " ");

  # A non-vacuity check in the generated fragment's own terms.  14 of the 47
  # in-tree back ends set extra_headers; zero means the manifest carries no
  # `extra_headers' key at all -- i.e. gen-target-manifest.sh was not updated
  # alongside this -- and the symptom would otherwise be an empty include-<cpu>
  # tree, which looks exactly like a back end that legitimately has no
  # intrinsics.  Absent artefact and absent mechanism again.
  if (n == 0) {
    print "gen-multi-target-md.awk: not one configured back end contributed" \
	  " extra_headers; i386, aarch64, arm, rs6000, s390, riscv, mips," \
	  " sparc, nds32, ia64, m68k, arc, c6x and epiphany all set it," \
	  " so zero means the manifest has no `extra_headers' record" \
	  > "/dev/stderr";
    exit 1;
  }

  printf "MT_HEADER_BASES =%s\n", " " mthdr_bases;
  printf "MT_EXTRA_HEADERS =";
  for (i = 1; i <= n; i++)
    printf " $(MT_EXTRA_HEADERS_%s)", parts[i];
  printf "\n\n";

  for (i = 1; i <= n; i++) {
    c = parts[i];
    printf "MT_EXTRA_HEADERS_%s = %s\n", c, mthdrs[c];
    # The stamp, one per back end, so a back end whose header set changed is
    # the only one re-copied.  `include-<cpu>' is created by the recipe rather
    # than being an order-only prerequisite because make would then treat the
    # directory's mtime as the stamp and never re-run.
    printf "include-%s/s-hdrs: $(MT_EXTRA_HEADERS_%s)\n", c, c;
    printf "\t$(mkinstalldirs) include-%s\n", c;
    # The /././ marker is copied from stmp-int-hdrs and means the same thing:
    # install under the name AFTER the marker, subdirectories included.  Only
    # the vxworks block uses it (../vxworks/././base/b_NULL.h), and dropping it
    # here would install that header as b_NULL.h -- a wrong name, not a missing
    # file, so nothing would report it.
    printf "\tfor file in $(MT_EXTRA_HEADERS_%s); do \\\n", c;
    printf "\t  case $$file in \\\n";
    printf "\t    */././*) \\\n";
    printf "\t      realfile=`echo $$file | sed -e 's|^.*/\\./\\./||'`; \\\n";
    printf "\t      case $$realfile in \\\n";
    printf "\t        */*) $(mkinstalldirs) include-%s/`echo $$realfile | sed -e 's|/[^/]*$$||'`;; \\\n", c;
    printf "\t      esac;; \\\n";
    printf "\t    *) realfile=`echo $$file | sed -e 's|.*/\\([^/]*\\)$$|\\1|'`;; \\\n";
    printf "\t  esac; \\\n";
    printf "\t  rm -f include-%s/$$realfile; \\\n", c;
    printf "\t  cp $$file include-%s/$$realfile || exit 1; \\\n", c;
    printf "\t  chmod a+r include-%s/$$realfile; \\\n", c;
    printf "\tdone\n";
    printf "\t$(STAMP) $@\n\n";
  }

  printf "MT_HEADER_STAMPS =";
  for (i = 1; i <= n; i++)
    printf " include-%s/s-hdrs", parts[i];
  printf "\n\n";
  printf ".PHONY: multi-target-headers\n";
  printf "multi-target-headers: $(MT_HEADER_STAMPS)\n\n";
}

# Record one manifest record's `extra_gcc_objs' against its back end, unioning
# both the object list and the tmake fragments that hold the rules naming their
# sources.  Called for EVERY record; see the comment at the call site in
# flush() for why the first record for a cpu_type is not enough.
function accumulate_gcc_driver_objs(	i, n, parts, j, m, fp) {
  n = split(xgobjs, parts, " ");
  for (i = 1; i <= n; i++) {
    if (parts[i] == "")
      continue;
    if (index(" " mtgcc_objs[cpu] " ", " " parts[i] " ") == 0) {
      mtgcc_objs[cpu] = mtgcc_objs[cpu] parts[i] " ";
      if (index(" " mtgcc_bases " ", " " cpu " ") == 0)
	mtgcc_bases = mtgcc_bases cpu " ";
    }
  }
  # Field 1 of a manifest line is its key, which frag_source_for skips, so the
  # accumulated list is re-given that shape at the point of use rather than
  # carrying a stray token here.
  m = split(tmkp, fp, " ");
  for (j = 2; j <= m; j++)
    if (index(" " mtgcc_frags[cpu] " ", " " fp[j] " ") == 0)
      mtgcc_frags[cpu] = mtgcc_frags[cpu] fp[j] " ";
}

# THE DRIVER'S PER-BACK-END OBJECTS.
#
# `extra_gcc_objs' is config.gcc's list of objects that must be linked into the
# DRIVER rather than into cc1 -- config/avr/driver-avr.cc, which defines the
# `double-lib' and `device-specs-file' spec functions, config/arc/driver-arc.cc,
# which defines `cpu_to_as', and so on.  Six back ends or OS shims set it.
#
# gcc/Makefile.in gets `@extra_gcc_objs@' from gcc/configure, and on this branch
# that substitution carries the HOST half alone -- config.host's
# `host_extra_gcc_objs', i.e. driver-i386.o on an x86_64 host, for -march=native.
# The target half comes from config.gcc, which gcc/configure.ac no longer runs
# for a target, so it reached the build as the empty string for every configured
# back end.  A multi-target driver needs the UNION over the back ends it serves:
# spec-functions-<base>.o expands that base's EXTRA_SPEC_FUNCTIONS and therefore
# names those functions, and nothing else in the link defines them.
#
# ONE OBJECT PER BACK END, in mtd-<cpu>/, and NOT the mt-<cpu>/ object of the
# same name where one exists.  avr-devices.o and msp430-devices.o are in BOTH
# `extra_objs' and `extra_gcc_objs' -- upstream compiles them once and links the
# one object into cc1 and into the driver -- but on this branch the mt-<cpu>/
# copy is compiled with MULTI_TARGET_RENAMES, so it refers to `targetm_avr',
# which exists only in libbackend.a.  Linking that object into the driver would
# be an undefined reference; recompiling it for the driver without the renames
# is the honest answer, because these really are two different links.
#
# No MULTI_TARGET_RENAMES and no -DMULTI_TARGET_TARGETM_BASE for the same
# reason: the driver holds no hook table at all, so a marker saying "this
# translation unit is a back end's own" would be false here.
function emit_gcc_driver_objs(	n, bases, i, b, m, parts, j, obj, src, list) {
  n = split(mtgcc_bases, bases, " ");
  for (i = 1; i <= n; i++) {
    b = bases[i];
    list = "";
    m = split(mtgcc_objs[b], parts, " ");
    for (j = 1; j <= m; j++) {
      obj = parts[j];
      sub(/\.o$/, "", obj);
      src = frag_source_for(obj, "tmake_file_present " mtgcc_frags[b]);
      if (src == "") {
	# Refuse rather than guess, in the one-line no-comma form $(error)
	# requires; see the identical refusal in the extra_objs loop for why a
	# newline here would suppress the message it exists to print.
	printf "$(error multi-target: nothing in %s's tmake_file claims a rule for %s.o" \
	       " -- gen-multi-target-md.awk cannot tell which source builds it;" \
	       " it is in %s's extra_gcc_objs)\n\n", b, obj, b;
	continue;
      }
      # THE OS-SIDE HALF IS A DESIGN FORK AND IS NOT EMITTED.
      #
      # Four of the six `extra_gcc_objs' settings are on a CPU case in
      # config.gcc -- loongarch, arc, avr, msp430 -- and their sources live in
      # config/<cpu>/.  For those, "the back end's own tm.h" is exactly the
      # right header and the per-base rule below is correct.
      #
      # The other two are on an OS case: `*-*-darwin*' sets darwin-driver.o and
      # `*vxworks*' sets vxworks-driver.o, and both sources live directly in
      # config/.  Those objects want the TARGET's header chain, not the back
      # end's: darwin-driver.cc spells DEF_MIN_OSX_VERSION and switches on
      # `#if DARWIN_X86', names that x86_64-linux's tm-i386.h does not have --
      # and `#if' on an undefined name does not error, it quietly evaluates
      # false.  This branch has a tm-<base>.h per back end and no tm-<target>.h
      # at all, so there is no per-base answer to give here and inventing one
      # would be a primary by another name.
      #
      # Emitting nothing for them preserves exactly today's behaviour -- the
      # target half of @extra_gcc_objs@ is empty, so these are not linked now
      # either -- while naming the gap so it is greppable rather than absent.
      # See STATE.md.
      if (src !~ ("^\\$\\(srcdir\\)/config/" b "/")) {
	printf "# MT_GCC_OBJS_UNHANDLED: %s needs %s.o (%s), which wants its\n", b, obj, src;
	printf "# TARGET's headers and not this back end's.  Design fork; not emitted.\n";
	printf "MT_GCC_OBJS_UNHANDLED += %s:%s.o\n\n", b, obj;
	continue;
      }
      printf "mtd-%s/%s.o: %s %s-inc/s-inc s-gtype\n", b, obj, src, b;
      printf "\t@$(mkinstalldirs) mtd-%s/$(DEPDIR)\n", b;
      # -DMULTI_TARGET_SUPPLY_TU, exactly as spec-functions.cc is compiled and
      # for the identical reason.  Without it defaults.h treats this as a
      # CONSUMER translation unit and redirects the (c-DATA) macros to
      # `targetm_cdata' and `targetm_regs' -- objects that live in
      # libbackend.a, which the driver does not link.  The marker is true here
      # rather than convenient: this object IS compiled against one back end's
      # own tm.h, so the real macros are the right ones.  On arc the missing
      # marker fails by name -- defaults.h:2045 on MAX_BITS_PER_WORD -- rather
      # than at the link, which is the only reason it is stated here and not
      # discovered later as an undefined `targetm_cdata' in xgcc.
      printf "\t$(COMPILE) -DMULTI_TARGET_SUPPLY_TU=1 $<\n\t$(POSTCOMPILE)\n\n";
      list = list " mtd-" b "/" obj ".o";
    }
    if (list == "")
      continue;
    printf "MT_GCC_OBJS_%s =%s\n", b, list;
    printf "$(MT_GCC_OBJS_%s): MULTI_TARGET_BASE_DEF = -DMT_BASE=%s-inc\n", b, b;
    printf "MT_GCC_OBJS += $(MT_GCC_OBJS_%s)\n\n", b;
  }
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
