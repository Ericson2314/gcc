#  Copyright (C) 2026 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; see the file COPYING3.  If not see
# <http://www.gnu.org/licenses/>.

# THE OTHER HALF OF THE PER-BACK-END PASS LIST.
#
# gen-pass-instances.awk puts every configured back end's target passes into
# the one shared pass-instances.def, renaming each to `<pass>_mt_<base>' so
# that two back ends contributing a pass of the same name stay two passes.
# Shared passes.cc therefore calls `make_<pass>_mt_<base> (ctxt)', and this
# script emits the two things that makes possible:
#
#   mode=header   multi-target-passes.h -- one declaration per (base, pass),
#                 returning `opt_pass *', which is what pass_manager's members
#                 are declared as.  Included by passes.cc.
#
#   mode=source   mt-<base>/target-passes-<base>.cc -- one FORWARDER per pass:
#
#                   opt_pass *
#                   make_pass_insert_bti_mt_aarch64 (gcc::context *ctxt)
#                   {
#                     opt_pass *p = make_pass_insert_bti (ctxt);
#                     p->mt_base = "aarch64";
#                     return p;
#                   }
#
# WHY A FORWARDER RATHER THAN A DECLARATION IN SHARED CODE.  Three reasons,
# and each of them on its own is enough:
#
#   * `make_pass_insert_bti' is in MULTI_TARGET_RENAME_NAMES because aarch64
#     and arm both define it bare.  The bare name does not exist in the linked
#     compiler; only `make_pass_insert_bti_aarch64' and `..._arm' do.  This
#     file is compiled with that back end's MULTI_TARGET_RENAMES, so the call
#     inside it becomes the renamed symbol.  Shared code never spells a
#     renamed name, and the rename list needs no entry added or removed --
#     which is the ordering trap this design dissolves rather than trades.
#
#   * the real factories return `rtl_opt_pass *' (mostly) and are declared in
#     `config/<cpu>/<cpu>-protos.h', reached through that back end's tm_p.h.
#     A declaration in shared code would have to guess the return type and
#     would read the PRIMARY's protos header, which is the branch's own bug.
#     Here the declaration comes from the back end's own header and the
#     upcast to `opt_pass *' is done by the compiler that saw both types.
#
#   * the base tag has to come from somewhere that cannot be wrong about it.
#     This translation unit exists once per back end and knows which one it
#     is, so `p->mt_base' is set by the only object with no way to guess.
#
# `mt_base' is what gates the pass at run time: passes.cc refuses to run a
# pass whose owner is not the back end multi_target_select installed.  A pass
# with a null `mt_base' is a shared pass and always runs.  A pass whose owner
# is not selected -- including when NOTHING is selected -- does not run, which
# is the correct answer and not a fallback: there is no privileged back end
# whose passes run by default.
#
# usage:
#   awk -f gen-target-passes.awk -v mode=header \
#       -v pass_bases="<file>=<base> ..."
#   awk -f gen-target-passes.awk -v mode=source -v want_base=<base> \
#       -v pass_bases="<file>=<base> ..."

function fatal(msg) {
  print "gen-target-passes.awk: " msg > "/dev/stderr";
  exit 1;
}

# Collect TGT_PASS out of an INSERT_PASS_{AFTER,BEFORE} directive.  Deliberately
# NOT a full parse: the third comma-separated argument, whitespace-stripped, up
# to the first character that cannot be in an identifier.  A pass taking
# parameters -- `INSERT_PASS_AFTER (pass_late_combine, 1, pass_stv, false)' --
# still names the pass in that position.
function collect(line, base,	rest, n, parts, name) {
  rest = line;
  sub(/^[ \t]*INSERT_PASS_(AFTER|BEFORE)[ \t]*\(/, "", rest);
  n = split(rest, parts, ",");
  if (n < 3)
    fatal("cannot read a pass name out of: " line);
  name = parts[3];
  gsub(/[^A-Za-z0-9_]/, "", name);
  if (name == "" || name == "PASS" || name == "TGT_PASS")
    return;
  # DEDUPLICATED, and that is not cosmetic: aarch64-passes.def names
  # pass_ldp_fusion twice (before pass_early_remat and before pass_peephole2).
  # Two NEXT_PASS lines for it is correct -- they are instances 1 and 2 of the
  # SAME pass, which the middle end clones -- but two definitions of one
  # forwarder is a `redefinition of' error, and two declarations of it in the
  # header are merely redundant.  One factory, several instances.
  if (!((base SUBSEP name) in seen))
    {
      seen[base SUBSEP name] = 1;
      npass[base]++;
      passes[base, npass[base]] = name;
    }
}

BEGIN {
  if (mode != "header" && mode != "source")
    fatal("mode must be `header' or `source'");
  if (mode == "source" && want_base == "")
    fatal("mode=source needs -v want_base=<base>");

  nb = split(pass_bases, bpairs, " ");
  nbase = 0;
  for (bi = 1; bi <= nb; bi++)
    {
      beq = index(bpairs[bi], "=");
      if (beq == 0)
	fatal("pass_bases entry `" bpairs[bi] "' is not <file>=<base>");
      f = substr(bpairs[bi], 1, beq - 1);
      b = substr(bpairs[bi], beq + 1);
      if (mode == "source" && b != want_base)
	continue;
      if (!(b in npass))
	{
	  npass[b] = 0;
	  bases[++nbase] = b;
	}
      # Several triples of one back end name the same file; read it once.
      if (f in read_already)
	continue;
      read_already[f] = 1;
      while ((getline line < f) > 0)
	{
	  if (line ~ /^[ \t]*INSERT_PASS_(AFTER|BEFORE)[ \t]*\(/)
	    collect(line, b);
	  # Not the `Macros that can be used in this file' comment four back
	  # ends carry, whose text is literally `REPLACE_PASS (PASS, INSTANCE,
	  # TGT_PASS)'.  Same exclusion as gen-pass-instances.awk's.
	  else if (line ~ /^[ \t]*REPLACE_PASS[ \t]*\(/ \
		   && line !~ /REPLACE_PASS[ \t]*\([ \t]*PASS[ \t]*,/)
	    fatal("REPLACE_PASS in " f ": see gen-pass-instances.awk");
	}
      close(f);
    }

  if (mode == "source" && nbase == 0)
    fatal("no pass file is tagged for back end `" want_base "'");

  if (mode == "header")
    {
      print "/* Generated by gen-target-passes.awk.  Do not edit.";
      print "";
      print "   One declaration per (configured back end, target pass).  The";
      print "   definitions are the forwarders in mt-<base>/target-passes-<base>.cc;";
      print "   the calls are in passes.cc, through pass-instances.def.  */";
      print "";
      print "#ifndef GCC_MULTI_TARGET_PASSES_H";
      print "#define GCC_MULTI_TARGET_PASSES_H";
      print "";
      for (i = 1; i <= nbase; i++)
	{
	  b = bases[i];
	  printf "/* %s */\n", b;
	  for (j = 1; j <= npass[b]; j++)
	    printf "extern opt_pass *make_%s_mt_%s (gcc::context *);\n",
		   passes[b, j], b;
	  print "";
	}
      print "#endif /* GCC_MULTI_TARGET_PASSES_H */";
      exit 0;
    }

  b = want_base;
  print "/* Generated by gen-target-passes.awk.  Do not edit.";
  print "";
  printf "   %s's target passes, each wrapped so that shared passes.cc can\n", b;
  print "   name it without spelling a MULTI_TARGET_RENAME_NAMES symbol, and";
  print "   so that the pass carries the back end that owns it.  */";
  print "";
  print "#include \"config.h\"";
  print "#include \"system.h\"";
  print "#include \"coretypes.h\"";
  print "#include \"multi-target-base.h\"";
  print "#include BASE_HEADER (tm.h)";
  print "#include \"backend.h\"";
  print "#include \"tree.h\"";
  print "#include \"gimple.h\"";
  print "#include \"rtl.h\"";
  print "#include \"memmodel.h\"";
  print "#include BASE_HEADER (tm_p.h)";
  print "#include \"tree-pass.h\"";
  print "#include \"context.h\"";
  print "#include \"multi-target-passes.h\"";
  print "";
  if (npass[b] == 0)
    {
      # NOT silence.  A back end with a t-<cpu> fragment naming a passes.def
      # that contributes nothing is a fact worth seeing in the source, and an
      # empty .cc that compiles to an empty .o is the `absent artefact vs
      # absent mechanism' confusion this project has lost four sessions to.
      printf "#error \"%s has a passes.def but it inserts no pass\"\n", b;
    }
  for (j = 1; j <= npass[b]; j++)
    {
      p = passes[b, j];
      printf "opt_pass *\nmake_%s_mt_%s (gcc::context *ctxt)\n{\n", p, b;
      printf "  opt_pass *p = make_%s (ctxt);\n", p;
      printf "  p->mt_base = \"%s\";\n", b;
      print  "  return p;";
      print  "}";
      print  "";
    }
  exit 0;
}
