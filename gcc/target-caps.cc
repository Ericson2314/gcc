/* Runtime target assembler/linker capabilities.
   Copyright (C) 2026 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

GCC is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */

/* This lives in libcommon.a because every host binary that consults a
   capability has to resolve targ_caps: cc1 and the language front ends, the
   driver and the language spec programs via libcommon-target.a, and collect2,
   which links neither opts.o nor toplev.o.  cc1, the driver and collect2 all
   call read_target_caps, each off its own -ftarget-config=; the language spec
   programs see the built-in defaults.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "target-caps.h"

/* Target assembler/linker capabilities.

   These used to be initialised, as a block, to "what a modern GNU toolchain
   supports", on the stated grounds that a compiler invoked without a
   target-config file should behave like a normally-configured one.  Both
   halves of that were wrong.  A compiler invoked without a config file selects
   no target and cannot compile at all, so the premise never applied; and where
   the defaults ARE reachable -- a config file that names a target but omits
   keys, which a real build here has already produced -- "modern GNU" is a
   guess about an assembler nobody described.  Each default is now decided on
   its own evidence; see the block comment at the assembler directives below
   for the two questions that decide it, and the per-field notes for the
   answers.

   Designated rather than positional, and deliberately so: several people add
   fields to this struct, and with a positional list an insertion silently
   mis-assigns every value below it rather than failing to compile -- C++ lets
   a short initializer list value-initialise the rest.  That has already
   happened here twice.  Keep these in declaration order; C++ requires it.  */
struct target_caps targ_caps =
{
  .leb128 = true,
  .s390_excess_float_precision = false,
  .decimal_float = false,
  .decimal_bid_format = false,
  .vms_debug = false,
  .glibc_major = 0,
  .glibc_minor = 0,
  /* -1, not 0: "not configured" is the answer that means "do not force", and
     0 is a distinct answer meaning the switch was given as `=no'.  A 0 floor
     here would silently claim every target had been configured `=no'.  */
  .sjlj_exceptions = -1,
  .libc_hwcap_in_tcb = false,
  .libc_gnustack = false,
  .ld_broken_secrel32 = false,
  .as_ref = false,
  .xcoff_dwarf_extras = false,
  .as_gotoff_in_data = true,
  .as_ix86_interunit_movq = true,
  .as_ix86_got32x = true,
  .as_ix86_tls_get_addr_got = true,
  .as_r_x86_64_code_6_gottpoff = true,
  .as_ix86_tlsldmplt = false,
  .as_ix86_tlsldm = false,
  .as_ix86_sahf = true,
  .as_ix86_ud2 = true,
  .as_ix86_filds = true,
  .as_ix86_fildq = true,
  .as_ix86_hle = true,
  .as_ix86_rep_lock_prefix = true,
  .as_ix86_ffreep = true,
  .as_ix86_tlsgdplt = false,
  .as_ix86_cmov_sun_syntax = false,
  .as_relax_option = true,
  .as_offsetable_lo10 = true,
  .as_gnu_attribute = true,
  .cfi_directive = true,
  .cfi_personality = true,
  .cfi_sections = true,
  /* ASSEMBLER-DIRECTIVE DEFAULTS: TWO QUESTIONS PER FIELD, NOT ONE.
     ----------------------------------------------------------------
     These defaults are in force only when cc1 is handed a target-config file
     that NAMES A TARGET but omits the key.  That is not hypothetical: a
     truncated config file with nothing but the `target' line has already been
     produced by a real build here, and every field below sat at its built-in
     value for that build's whole life.  (A compiler given NO config file at all
     cannot compile anything -- it has no target and dies at the first target
     hook -- so these values can never be reached that way.)

     Two independent questions decide each default, and the old blanket `true'
     answered only the second:

       (1) HAZARD OF true.  If the assembler in front of us lacks the feature,
	   `true' makes cc1 emit a directive it will reject.  That hazard is
	   real for a recent or GNU-specific directive and negligible for one
	   every assembler has had for decades.
       (2) SAFETY OF false.  `false' is only an option when the fallback arm is
	   SEMANTICALLY EQUIVALENT -- worse code, never different meaning.  For
	   three fields below it is not, and there `true' has to stay whatever
	   the answer to (1).

     A field flips to `false' only when (1) is real AND (2) holds.  Flipping the
     rest as well would cost every unprobed build real code quality and buy no
     safety, which is the same targeted-not-blanket trade the mode-union work
     had to make.  */

  /* KEPT true: hazard of `true' is negligible.  `.loc ... is_stmt' and
     `.loc ... discriminator' are DWARF line-table sub-directives that gas and
     the LLVM integrated assembler have both had for well over a decade, and
     the only thing at stake either way is debug-line quality.  */
  .gas_loc_stmt = true,
  .gas_discriminator = true,
  .as_line_zero = true,

  /* KEPT true, and here `false' is UNSAFE, which decides it on its own.  The
     fallback emits `.lcomm NAME,ROUNDED' with no alignment operand at all
     (i386/bsd.h), so an over-aligned static silently comes out UNDER-aligned --
     a correctness bug, not a quality loss.  Only i386/bsd.h consults this;
     every other target takes `ASM_OUTPUT_ALIGNED_LOCAL_P true' from
     defaults.h.  */
  .gas_lcomm_with_alignment = true,

  /* FLIPPED to false: recent directives whose fallback arms are equivalent.
     `.cv_ucomp'/`.cv_scomp' and `.base64' are both new enough that an
     assembler nobody has described to us is more likely to lack them than to
     have them, and emitting either at such an assembler is a hard failure.
     dwarf2codeview.cc has a fallback encoding; varasm.cc merely drops to
     2000-byte string chunks from 16384.  Both cost size and nothing else.  */
  .gas_cv_ucomp = false,
  .gas_base64 = false,

  /* FLIPPED to false: section flags, all post-2020 in gas, all quality-only
     when absent.  `e' (exclude) is the sharpest case -- its probe in
     target-specs/configure.ac has a second arm for Solaris `as' syntax
     (`.section "foo1", #exclude'), so the feature is NOT gas-only and the
     spelling is not even uniform; varasm.cc and sparc.cc just skip the flag
     without it, and mingw/winnt.cc emits `n' instead.  `R' (SHF_GNU_RETAIN)
     and `o' (link order) both fall back to an ordinary section.  Note the same
     probe deliberately answers `no' for all of these on Solaris already, so
     `false' is a state these consumers are known to handle.  */
  .gas_section_exclude = false,
  .gas_shf_gnu_retain = false,

  /* KEPT true: hazard negligible.  `.balign'/`.p2align' are universal, and
     both readers were checked -- i386/gas.h's fallback is `.align' with the
     SAME `1 << LOG' operand (so no unit ambiguity), and m68k.h falls back to
     plain ASM_OUTPUT_ALIGN.  Nothing is gained by assuming their absence.  */
  .gas_balign_and_p2align = true,

  /* FLIPPED to false: the max-skip form `.p2align LOG,,MAX' is a GNU spelling,
     not the plain directive.  Measured, not assumed: with it, final.cc emits
     `.p2align 4,,10'; without it, `.align 16'.  Both assemble; the second just
     pads unconditionally.  Density only.  */
  .gas_max_skip_p2align = false,

  /* KEPT true, and `false' is UNSAFE.  A missing `.weak' does not make cc1
     emit less -- it makes varasm.cc warn (`weak declaration of %q+D not
     supported') and emit a STRONG symbol where a weak one was asked for, which
     surfaces as a duplicate-definition link failure or a wrong resolution far
     from here.  `.weak' is also not a gas feature: every ELF, COFF and Mach-O
     assembler has a spelling for it, so `true' rests on universality rather
     than on the "modern gas" guess that used to justify this whole block.  */
  .gas_weak = true,

  /* KEPT true, because true is what every back end already had.  The
     `AC_DEFINE(HAVE_AS_TLS, 1)' this replaces was UNCONDITIONAL -- the
     per-target assembler probe was deleted long before this -- so a `false'
     here would not be conservative, it would silently switch 19 back ends
     from real TLS to emutls.  The back end's own "do I have a TLS sequence"
     answer is the targetm hook and is unaffected either way; see
     target_have_tls_p () in target.h.  */
  .as_tls = true,
  .as_dtprel_reloc = true,

  /* FLIPPED to false.  This is the one field in the group that really IS
     GNU-specific -- `.weakref' is a gas invention with no counterpart
     elsewhere -- so it is exactly the field the old blanket default was
     guessing about.  varasm.cc's `#else' arm (the weakref_targets list,
     resolved through do_assemble_alias) is a complete alternative path.  */
  .gas_weakref = false,

  /* FLIPPED to false: `.subsection -1'/`.previous' is a gas-specific way to
     park a jump table, and sparc is the only consumer.  Without it sparc picks
     DImode case vectors instead of SImode -- correct, merely larger.  */
  .gas_subsection_ordering = false,

  .dwarf2_debug_line = true,
  .dwarf2_debug_view = true,

  /* KEPT true: SHF_MERGE is ELF gABI, not a GNU extension, and is read in
     value position by varasm.cc and dwarf2out.cc.  */
  .gas_shf_merge = true,

  /* FLIPPED to false: the `o' section flag is binutils-2.35-era and only
     enables a linker-GC refinement.  */
  .gas_section_link_order = false,

  /* KEPT true, and `false' is UNSAFE.  Without `.hidden', varasm.cc warns and
     DROPS the visibility attribute, USE_HIDDEN_LINKONCE goes off on i386, s390
     and sparc, and `__dso_handle' handling changes in ipa.cc and cp/decl.cc --
     C++ static destructor registration, not code quality.  `.hidden' is also
     universal on ELF.  */
  .gas_hidden = true,
  .ld_ro_rw_section_mixing = true,
  .ld_eh_gc_sections = true,
  .ld_ctf = false,
  .ld_sysroot = true,
  .ld_at_file = true,
  .ld_pie_copyreloc = true,
  .ld_personality_relaxation = false,
  .ld_no_dot_syms = false,
  .ld_large_toc = false,
  .ld_toc_align = false,
  .ld_ppc_attr = false,
  .ld_broken_pe_dwarf5 = false,
  .ld_avr_avrxmega3_rodata_in_flash = false,
  .ld_avr_avrxmega2_flmap = false,
  .ld_avr_avrxmega4_flmap = false,
  .ld_pie = true,
  .ld_now = true,
  .ld_relro = true,
  .lto_plugin = true,
  .ld_demangle = false,
  .as_aarch64_mabi = true,
  .as_aarch64_small_pic_relocs = true,
  .as_aarch64_aeabi_build_attributes = true,
  .as_alpha_explicit_relocs = true,
  .as_alpha_jsrdirect_relocs = true,
  .as_mips_nan = true,
  .as_mips_micromips = true,
  .as_mips_dspr1_mult = true,
  .as_mips_dot_module = true,
  .as_mips_explicit_relocs = true,
  .as_mips_explicit_relocs_pcrel = true,
  .as_ld_mips_jalr_reloc = true,
  .as_loongarch_explicit_relocs = true,
  .as_loongarch_relax = true,
  .as_loongarch_cond_branch_relax = true,
  .as_riscv_attribute = true,
  .as_riscv_misa_spec = true,
  .as_riscv_march_zifencei = true,
  .as_riscv_march_zaamo_zalrsc = true,
  .as_riscv_march_b = true,

  /* The 2026-08-11 sweep.  false, not true -- see the note in target-caps.h.
     These have been off for every build that was not configured for their own
     back end, and turning them on for an unprobed toolchain would emit
     directives its assembler has never accepted.  */
  .as_entry_markers = false,
  .as_mfcrf = false,
  .as_power10_htm = false,
  .as_rel16 = false,
  .as_pltseq = false,
  .as_mspabi_attribute = false,
  .as_mmacosx_version_min = false,
  .as_macos_build_version = false,
  .gas_literal16 = false,
  .gas_nsubspa_comdat = false,
  .gas_arm_extended_arch = false,
  .as_loongarch_support_call36 = false,
  .as_loongarch_tls_le_relaxation = false,
  .as_loongarch_16b_atomic = false,
  .as_loongarch_eh_frame_pcrel_encoding = false,
  .as_ltoffx_ldxmov_relocs = false,
  .as_s390_architecture_modifiers = false,
  .as_s390_vector_loadstore_alignment_hints = false,
  .as_s390_vector_loadstore_alignment_hints_on_z13 = false,
  .use_as_traditional_format = false,

  .solaris_ld = false,

  /* String capabilities.  Today's behaviour: every consumer of these had the
     GNU spellings compiled into it, and HAVE_LD_STATIC_DYNAMIC defaulted to 1,
     so a compiler told nothing about its linker keeps doing exactly that.  */
  .ld_static_option = "-Bstatic",
  .ld_dynamic_option = "-Bdynamic",

  /* The C++ header directories.  Defaults are the installation-relative paths
     gcc/Makefile.in computes; see target-caps.h.  This file is compiled with
     PREPROCESSOR_DEFINES for exactly these four macros, so that the default
     really is the string a normally-configured compiler used to have compiled
     into cppdefault.cc, rather than a second, separately-maintained copy of
     it.  */
  .gxx_include_dir = GPLUSPLUS_INCLUDE_DIR,
  .gxx_tool_include_dir = GPLUSPLUS_TOOL_INCLUDE_DIR,
  .gxx_backward_include_dir = GPLUSPLUS_BACKWARD_INCLUDE_DIR,
  .gxx_libcxx_include_dir = GPLUSPLUS_LIBCXX_INCLUDE_DIR,

  /* "" and NOT a path, deliberately: gcc's build no longer runs fixincludes
     and creates no include-fixed, so there is no compile-time directory to
     name here.  A default would be a search-path entry pointing at nothing.
     See target-caps.h.  */
  .fixed_include_dir = "",

  /* "" for the same reason, and this one closes a hole that was WORSE than a
     missing directory.  The compile-time -DTOOL_INCLUDE_DIR was
     $(gcc_tooldir)/include with an EMPTY target component, i.e. $(prefix)
     -- `/usr/include' by default.  Every target got the host's headers, under
     no capability's control.  See target-caps.h.  */
  .tool_include_dir = "",

  /* "" = "nothing said": collect2 does its ordinary search.  There is no
     compile-time answer because the tm.h macros these replace were gated on
     "am I a cross compiler?", which a multi-target compiler cannot ask.  */
  .real_ld_file_name = "",
  .real_nm_file_name = "",
  .real_strip_file_name = "",

  /* The site-local and system header directories, and the component of the
     latter.  NULL rather than a string, and that is deliberate: see
     target-caps.h.  The compile-time answer for these three is not a plain
     Makefile substitution -- two of them are subject to cppdefault.cc's
     `#undef' under CROSS_DIRECTORY_STRUCTURE, and the component comes from
     tm.h, which this file cannot include -- so the fallback is applied there,
     where those things are visible, and NULL here means "nobody told us".  */
  .local_include_dir = NULL,
  .native_system_header_dir = NULL,
  .native_system_header_component = NULL
};

/* No built-in default: see target-caps.h.  A compiler that has not been told
   which target it is for has not got one.  */
const char *targ_caps_target_name = NULL;

/* For reports only; see the header for why this must never be compared.  */

const char *
targ_caps_target_name_for_report (void)
{
  return targ_caps_target_name != NULL ? targ_caps_target_name : "(none)";
}

/* Read capability settings from FILE.  Format is one `name value' pair per
   line; `#' starts a comment.  Unknown names are ignored so that a newer spec
   file does not break an older compiler.  A missing or unreadable file is not
   an error -- the built-in defaults stand.  */

void
read_target_caps (const char *file)
{
  FILE *f = fopen (file, "r");
  if (f == NULL)
    return;

  char line[256];
  while (fgets (line, sizeof (line), f) != NULL)
    {
      char name[64];
      int value;

      if (line[0] == '#' || line[0] == '\n')
	continue;

      /* STRING-VALUED LINES, matched before the integer parse because that
	 parse would silently drop them: `%d' fails on `-Bstatic' and the line
	 would be skipped with no diagnostic, which is how a capability comes to
	 be written and never read.

	 One table for all of them, including `target', which used to have a
	 sscanf of its own.  Two string paths is two places to get the empty
	 case wrong, and the empty case is the one that matters -- a name with
	 no value must yield "" and never NULL, because every consumer indexes
	 or dereferences the result.  See the rules in target-caps.h.  */
      {
	static const struct { const char *name; const char **slot; } strs[] = {
	  { "target", &targ_caps_target_name },
	  { "ld_static_option", &targ_caps.ld_static_option },
	  { "ld_dynamic_option", &targ_caps.ld_dynamic_option },
	  { "gxx_include_dir", &targ_caps.gxx_include_dir },
	  { "gxx_tool_include_dir", &targ_caps.gxx_tool_include_dir },
	  { "gxx_backward_include_dir", &targ_caps.gxx_backward_include_dir },
	  { "gxx_libcxx_include_dir", &targ_caps.gxx_libcxx_include_dir },
	  { "fixed_include_dir", &targ_caps.fixed_include_dir },
	  { "tool_include_dir", &targ_caps.tool_include_dir },
	  { "real_ld_file_name", &targ_caps.real_ld_file_name },
	  { "real_nm_file_name", &targ_caps.real_nm_file_name },
	  { "real_strip_file_name", &targ_caps.real_strip_file_name },
	  { "local_include_dir", &targ_caps.local_include_dir },
	  { "native_system_header_dir", &targ_caps.native_system_header_dir },
	  { "native_system_header_component",
	    &targ_caps.native_system_header_component }
	};
	bool matched = false;
	for (unsigned i = 0; i < ARRAY_SIZE (strs); i++)
	  {
	    size_t nlen = strlen (strs[i].name);
	    if (strncmp (line, strs[i].name, nlen) != 0)
	      continue;
	    /* The name must be a whole field: `ld_static_option_extra' must not
	       match `ld_static_option'.  */
	    if (line[nlen] != ' ' && line[nlen] != '\t'
		&& line[nlen] != '\n' && line[nlen] != '\0')
	      continue;

	    const char *p = line + nlen;
	    while (*p == ' ' || *p == '\t')
	      p++;
	    const char *end = p;
	    while (*end != '\0' && *end != '\n' && *end != ' ' && *end != '\t')
	      end++;

	    /* `target' is the one whose absence is meaningful: no target line
	       means no target, and the compiler must fail loudly rather than
	       pretend to one.  A capability with an empty value means the
	       feature is absent, which is a normal answer.  */
	    if (end == p && strs[i].slot == &targ_caps_target_name)
	      ;
	    else
	      *strs[i].slot = xstrndup (p, end - p);
	    matched = true;
	    break;
	  }
	if (matched)
	  continue;
      }

      if (sscanf (line, "%63s %d", name, &value) != 2)
	continue;

      if (strcmp (name, "leb128") == 0)
	targ_caps.leb128 = value != 0;
      else if (strcmp (name, "s390_excess_float_precision") == 0)
	targ_caps.s390_excess_float_precision = value != 0;
      else if (strcmp (name, "decimal_float") == 0)
	targ_caps.decimal_float = value != 0;
      else if (strcmp (name, "decimal_bid_format") == 0)
	targ_caps.decimal_bid_format = value != 0;
      else if (strcmp (name, "vms_debug") == 0)
	targ_caps.vms_debug = value != 0;
      else if (strcmp (name, "sjlj_exceptions") == 0)
	targ_caps.sjlj_exceptions = value;
      else if (strcmp (name, "glibc_major") == 0)
	targ_caps.glibc_major = value;
      else if (strcmp (name, "glibc_minor") == 0)
	targ_caps.glibc_minor = value;
      else if (strcmp (name, "libc_hwcap_in_tcb") == 0)
	targ_caps.libc_hwcap_in_tcb = value != 0;
      else if (strcmp (name, "libc_gnustack") == 0)
	targ_caps.libc_gnustack = value != 0;
      else if (strcmp (name, "ld_broken_secrel32") == 0)
	targ_caps.ld_broken_secrel32 = value != 0;
      else if (strcmp (name, "as_ref") == 0)
	targ_caps.as_ref = value != 0;
      else if (strcmp (name, "xcoff_dwarf_extras") == 0)
	targ_caps.xcoff_dwarf_extras = value != 0;
      else if (strcmp (name, "as_ix86_sahf") == 0)
	targ_caps.as_ix86_sahf = value != 0;
      else if (strcmp (name, "as_ix86_ud2") == 0)
	targ_caps.as_ix86_ud2 = value != 0;
      else if (strcmp (name, "as_ix86_filds") == 0)
	targ_caps.as_ix86_filds = value != 0;
      else if (strcmp (name, "as_ix86_fildq") == 0)
	targ_caps.as_ix86_fildq = value != 0;
      else if (strcmp (name, "as_ix86_hle") == 0)
	targ_caps.as_ix86_hle = value != 0;
      else if (strcmp (name, "as_ix86_rep_lock_prefix") == 0)
	targ_caps.as_ix86_rep_lock_prefix = value != 0;
      else if (strcmp (name, "as_ix86_ffreep") == 0)
	targ_caps.as_ix86_ffreep = value != 0;
      else if (strcmp (name, "as_ix86_tlsgdplt") == 0)
	targ_caps.as_ix86_tlsgdplt = value != 0;
      else if (strcmp (name, "as_ix86_cmov_sun_syntax") == 0)
	targ_caps.as_ix86_cmov_sun_syntax = value != 0;
      else if (strcmp (name, "as_gotoff_in_data") == 0)
	targ_caps.as_gotoff_in_data = value != 0;
      else if (strcmp (name, "as_ix86_interunit_movq") == 0)
	targ_caps.as_ix86_interunit_movq = value != 0;
      else if (strcmp (name, "as_ix86_got32x") == 0)
	targ_caps.as_ix86_got32x = value != 0;
      else if (strcmp (name, "as_ix86_tls_get_addr_got") == 0)
	targ_caps.as_ix86_tls_get_addr_got = value != 0;
      else if (strcmp (name, "as_r_x86_64_code_6_gottpoff") == 0)
	targ_caps.as_r_x86_64_code_6_gottpoff = value != 0;
      else if (strcmp (name, "as_ix86_tlsldmplt") == 0)
	targ_caps.as_ix86_tlsldmplt = value != 0;
      else if (strcmp (name, "as_ix86_tlsldm") == 0)
	targ_caps.as_ix86_tlsldm = value != 0;
      else if (strcmp (name, "as_relax_option") == 0)
	targ_caps.as_relax_option = value != 0;
      else if (strcmp (name, "as_offsetable_lo10") == 0)
	targ_caps.as_offsetable_lo10 = value != 0;
      else if (strcmp (name, "as_gnu_attribute") == 0)
	targ_caps.as_gnu_attribute = value != 0;
      else if (strcmp (name, "cfi_directive") == 0)
	targ_caps.cfi_directive = value != 0;
      else if (strcmp (name, "cfi_personality") == 0)
	targ_caps.cfi_personality = value != 0;
      else if (strcmp (name, "cfi_sections") == 0)
	targ_caps.cfi_sections = value != 0;
      else if (strcmp (name, "gas_loc_stmt") == 0)
	targ_caps.gas_loc_stmt = value != 0;
      else if (strcmp (name, "gas_discriminator") == 0)
	targ_caps.gas_discriminator = value != 0;
      else if (strcmp (name, "as_line_zero") == 0)
	targ_caps.as_line_zero = value != 0;
      else if (strcmp (name, "gas_lcomm_with_alignment") == 0)
	targ_caps.gas_lcomm_with_alignment = value != 0;
      else if (strcmp (name, "gas_cv_ucomp") == 0)
	targ_caps.gas_cv_ucomp = value != 0;
      else if (strcmp (name, "gas_base64") == 0)
	targ_caps.gas_base64 = value != 0;
      else if (strcmp (name, "gas_section_exclude") == 0)
	targ_caps.gas_section_exclude = value != 0;
      else if (strcmp (name, "gas_shf_gnu_retain") == 0)
	targ_caps.gas_shf_gnu_retain = value != 0;
      else if (strcmp (name, "gas_balign_and_p2align") == 0)
	targ_caps.gas_balign_and_p2align = value != 0;
      else if (strcmp (name, "gas_max_skip_p2align") == 0)
	targ_caps.gas_max_skip_p2align = value != 0;
      else if (strcmp (name, "gas_weak") == 0)
	targ_caps.gas_weak = value != 0;
      else if (strcmp (name, "as_tls") == 0)
	targ_caps.as_tls = value != 0;
      else if (strcmp (name, "as_dtprel_reloc") == 0)
	targ_caps.as_dtprel_reloc = value != 0;
      else if (strcmp (name, "gas_weakref") == 0)
	targ_caps.gas_weakref = value != 0;
      else if (strcmp (name, "gas_subsection_ordering") == 0)
	targ_caps.gas_subsection_ordering = value != 0;
      else if (strcmp (name, "dwarf2_debug_line") == 0)
	targ_caps.dwarf2_debug_line = value != 0;
      else if (strcmp (name, "dwarf2_debug_view") == 0)
	targ_caps.dwarf2_debug_view = value != 0;
      else if (strcmp (name, "gas_hidden") == 0)
	targ_caps.gas_hidden = value != 0;
      else if (strcmp (name, "ld_ro_rw_section_mixing") == 0)
	targ_caps.ld_ro_rw_section_mixing = value != 0;
      else if (strcmp (name, "ld_eh_gc_sections") == 0)
	targ_caps.ld_eh_gc_sections = value != 0;
      else if (strcmp (name, "ld_ctf") == 0)
	targ_caps.ld_ctf = value != 0;
      else if (strcmp (name, "ld_sysroot") == 0)
	targ_caps.ld_sysroot = value != 0;
      else if (strcmp (name, "ld_at_file") == 0)
	targ_caps.ld_at_file = value != 0;
      else if (strcmp (name, "ld_pie_copyreloc") == 0)
	targ_caps.ld_pie_copyreloc = value != 0;
      else if (strcmp (name, "ld_personality_relaxation") == 0)
	targ_caps.ld_personality_relaxation = value != 0;
      else if (strcmp (name, "ld_no_dot_syms") == 0)
	targ_caps.ld_no_dot_syms = value != 0;
      else if (strcmp (name, "ld_large_toc") == 0)
	targ_caps.ld_large_toc = value != 0;
      else if (strcmp (name, "ld_toc_align") == 0)
	targ_caps.ld_toc_align = value != 0;
      else if (strcmp (name, "ld_ppc_attr") == 0)
	targ_caps.ld_ppc_attr = value != 0;
      else if (strcmp (name, "ld_broken_pe_dwarf5") == 0)
	targ_caps.ld_broken_pe_dwarf5 = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega3_rodata_in_flash") == 0)
	targ_caps.ld_avr_avrxmega3_rodata_in_flash = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega2_flmap") == 0)
	targ_caps.ld_avr_avrxmega2_flmap = value != 0;
      else if (strcmp (name, "ld_avr_avrxmega4_flmap") == 0)
	targ_caps.ld_avr_avrxmega4_flmap = value != 0;
      else if (strcmp (name, "ld_pie") == 0)
	targ_caps.ld_pie = value != 0;
      else if (strcmp (name, "ld_now") == 0)
	targ_caps.ld_now = value != 0;
      else if (strcmp (name, "ld_relro") == 0)
	targ_caps.ld_relro = value != 0;
      else if (strcmp (name, "lto_plugin") == 0)
	targ_caps.lto_plugin = value != 0;
      else if (strcmp (name, "ld_demangle") == 0)
	targ_caps.ld_demangle = value != 0;
      else if (strcmp (name, "as_aarch64_mabi") == 0)
	targ_caps.as_aarch64_mabi = value != 0;
      else if (strcmp (name, "as_aarch64_small_pic_relocs") == 0)
	targ_caps.as_aarch64_small_pic_relocs = value != 0;
      else if (strcmp (name, "as_aarch64_aeabi_build_attributes") == 0)
	targ_caps.as_aarch64_aeabi_build_attributes = value != 0;
      else if (strcmp (name, "as_alpha_explicit_relocs") == 0)
	targ_caps.as_alpha_explicit_relocs = value != 0;
      else if (strcmp (name, "as_alpha_jsrdirect_relocs") == 0)
	targ_caps.as_alpha_jsrdirect_relocs = value != 0;
      else if (strcmp (name, "as_mips_nan") == 0)
	targ_caps.as_mips_nan = value != 0;
      else if (strcmp (name, "as_mips_micromips") == 0)
	targ_caps.as_mips_micromips = value != 0;
      else if (strcmp (name, "as_mips_dspr1_mult") == 0)
	targ_caps.as_mips_dspr1_mult = value != 0;
      else if (strcmp (name, "as_mips_dot_module") == 0)
	targ_caps.as_mips_dot_module = value != 0;
      else if (strcmp (name, "as_mips_explicit_relocs") == 0)
	targ_caps.as_mips_explicit_relocs = value != 0;
      else if (strcmp (name, "as_mips_explicit_relocs_pcrel") == 0)
	targ_caps.as_mips_explicit_relocs_pcrel = value != 0;
      else if (strcmp (name, "as_ld_mips_jalr_reloc") == 0)
	targ_caps.as_ld_mips_jalr_reloc = value != 0;
      else if (strcmp (name, "as_loongarch_explicit_relocs") == 0)
	targ_caps.as_loongarch_explicit_relocs = value != 0;
      else if (strcmp (name, "as_loongarch_relax") == 0)
	targ_caps.as_loongarch_relax = value != 0;
      else if (strcmp (name, "as_loongarch_cond_branch_relax") == 0)
	targ_caps.as_loongarch_cond_branch_relax = value != 0;
      else if (strcmp (name, "as_riscv_attribute") == 0)
	targ_caps.as_riscv_attribute = value != 0;
      else if (strcmp (name, "as_riscv_misa_spec") == 0)
	targ_caps.as_riscv_misa_spec = value != 0;
      else if (strcmp (name, "as_riscv_march_zifencei") == 0)
	targ_caps.as_riscv_march_zifencei = value != 0;
      else if (strcmp (name, "as_riscv_march_zaamo_zalrsc") == 0)
	targ_caps.as_riscv_march_zaamo_zalrsc = value != 0;
      else if (strcmp (name, "as_riscv_march_b") == 0)
	targ_caps.as_riscv_march_b = value != 0;
      else if (strcmp (name, "as_entry_markers") == 0)
	targ_caps.as_entry_markers = value != 0;
      else if (strcmp (name, "as_mfcrf") == 0)
	targ_caps.as_mfcrf = value != 0;
      else if (strcmp (name, "as_power10_htm") == 0)
	targ_caps.as_power10_htm = value != 0;
      else if (strcmp (name, "as_rel16") == 0)
	targ_caps.as_rel16 = value != 0;
      else if (strcmp (name, "as_pltseq") == 0)
	targ_caps.as_pltseq = value != 0;
      else if (strcmp (name, "as_mspabi_attribute") == 0)
	targ_caps.as_mspabi_attribute = value != 0;
      else if (strcmp (name, "as_mmacosx_version_min") == 0)
	targ_caps.as_mmacosx_version_min = value != 0;
      else if (strcmp (name, "as_macos_build_version") == 0)
	targ_caps.as_macos_build_version = value != 0;
      else if (strcmp (name, "gas_literal16") == 0)
	targ_caps.gas_literal16 = value != 0;
      else if (strcmp (name, "gas_nsubspa_comdat") == 0)
	targ_caps.gas_nsubspa_comdat = value != 0;
      else if (strcmp (name, "gas_arm_extended_arch") == 0)
	targ_caps.gas_arm_extended_arch = value != 0;
      else if (strcmp (name, "as_loongarch_support_call36") == 0)
	targ_caps.as_loongarch_support_call36 = value != 0;
      else if (strcmp (name, "as_loongarch_tls_le_relaxation") == 0)
	targ_caps.as_loongarch_tls_le_relaxation = value != 0;
      else if (strcmp (name, "as_loongarch_16b_atomic") == 0)
	targ_caps.as_loongarch_16b_atomic = value != 0;
      else if (strcmp (name, "as_loongarch_eh_frame_pcrel_encoding") == 0)
	targ_caps.as_loongarch_eh_frame_pcrel_encoding = value != 0;
      else if (strcmp (name, "as_ltoffx_ldxmov_relocs") == 0)
	targ_caps.as_ltoffx_ldxmov_relocs = value != 0;
      else if (strcmp (name, "as_s390_architecture_modifiers") == 0)
	targ_caps.as_s390_architecture_modifiers = value != 0;
      else if (strcmp (name, "as_s390_vector_loadstore_alignment_hints") == 0)
	targ_caps.as_s390_vector_loadstore_alignment_hints = value != 0;
      else if (strcmp (name,
		       "as_s390_vector_loadstore_alignment_hints_on_z13") == 0)
	targ_caps.as_s390_vector_loadstore_alignment_hints_on_z13 = value != 0;
      else if (strcmp (name, "use_as_traditional_format") == 0)
	targ_caps.use_as_traditional_format = value != 0;
      else if (strcmp (name, "solaris_ld") == 0)
	targ_caps.solaris_ld = value != 0;
    }

  fclose (f);
}
