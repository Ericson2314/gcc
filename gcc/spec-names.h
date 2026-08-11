/* Spec-language option-name fragments shared by the driver and target headers.
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

/* These are not specs.  They are the option-name fragments that spec strings
   are spelled with -- "pie", "fPIC" and so on -- and they are shared
   vocabulary: thirty-odd target headers under config/ build their
   STARTFILE_SPEC / ENDFILE_SPEC / LINK_SPEC out of them, while gcc.cc builds
   LINK_PIE_SPEC out of them.

   They lived in gcc.cc until the driver stopped including tm.h.  That was
   workable only as long as the driver was the single place a target's spec
   macros were ever expanded.  It is not any more: gen-target-specs.cc expands
   the same macros from the same target headers, so the fragments have to be
   reachable from both.  Duplicating them in the generator would create exactly
   the failure this project exists to remove -- one name, two definitions, no
   diagnostic -- so they get a header instead.

   Nothing here depends on the target.  Anything that does belongs in a spec
   file, not in this file.  */

#ifndef GCC_SPEC_NAMES_H
#define GCC_SPEC_NAMES_H

#define PIE_SPEC		"pie"
#define FPIE1_SPEC		"fpie"
#define NO_FPIE1_SPEC		FPIE1_SPEC ":;"
#define FPIE2_SPEC		"fPIE"
#define NO_FPIE2_SPEC		FPIE2_SPEC ":;"
#define FPIE_SPEC		FPIE1_SPEC "|" FPIE2_SPEC
#define NO_FPIE_SPEC		FPIE_SPEC ":;"
#define FPIC1_SPEC		"fpic"
#define NO_FPIC1_SPEC		FPIC1_SPEC ":;"
#define FPIC2_SPEC		"fPIC"
#define NO_FPIC2_SPEC		FPIC2_SPEC ":;"
#define FPIC_SPEC		FPIC1_SPEC "|" FPIC2_SPEC
#define NO_FPIC_SPEC		FPIC_SPEC ":;"
#define FPIE1_OR_FPIC1_SPEC	FPIE1_SPEC "|" FPIC1_SPEC
#define NO_FPIE1_AND_FPIC1_SPEC	FPIE1_OR_FPIC1_SPEC ":;"
#define FPIE2_OR_FPIC2_SPEC	FPIE2_SPEC "|" FPIC2_SPEC
#define NO_FPIE2_AND_FPIC2_SPEC	FPIE1_OR_FPIC2_SPEC ":;"
#define FPIE_OR_FPIC_SPEC	FPIE_SPEC "|" FPIC_SPEC
#define NO_FPIE_AND_FPIC_SPEC	FPIE_OR_FPIC_SPEC ":;"

#endif /* GCC_SPEC_NAMES_H */
