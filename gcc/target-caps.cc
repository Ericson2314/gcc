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
   which links neither opts.o nor toplev.o.  Only cc1 calls read_target_caps;
   everything else sees the built-in defaults.  */

#include "config.h"
#include "system.h"
#include "coretypes.h"
#include "target-caps.h"

/* Target assembler/linker capabilities.  Initialised to what a modern GNU
   toolchain supports, so a compiler invoked without a target-config file
   behaves like a normally-configured one.

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
  .gas_loc_stmt = true,
  .gas_discriminator = true,
  .as_line_zero = true,
  .gas_lcomm_with_alignment = true,
  .gas_cv_ucomp = true,
  .dwarf2_debug_line = true,
  .dwarf2_debug_view = true,
  .gas_shf_merge = true,
  .gas_section_link_order = true,
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
  .solaris_ld = false,

  /* String capabilities.  Today's behaviour: every consumer of these had the
     GNU spellings compiled into it, and HAVE_LD_STATIC_DYNAMIC defaulted to 1,
     so a compiler told nothing about its linker keeps doing exactly that.  */
  .ld_static_option = "-Bstatic",
  .ld_dynamic_option = "-Bdynamic"
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
	  { "ld_dynamic_option", &targ_caps.ld_dynamic_option }
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
      else if (strcmp (name, "solaris_ld") == 0)
	targ_caps.solaris_ld = value != 0;
    }

  fclose (f);
}
