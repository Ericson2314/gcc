/* Naming a back end's own headers at the point of inclusion.
   Copyright (C) 2025 Free Software Foundation, Inc.

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

/* *** WHY THIS FILE EXISTS ***

   Rationale and current state: scratchpad/T173-BASE-HEADER.md.

   Each configured back end gets a `<base>-inc/' directory holding its own
   tm.h, tm_p.h, tm-preds.h, tm-constrs.h and generated insn-*.h.  Objects
   compiled for that back end are given `-I<base>-inc' ahead of `-I.', so a
   plain `#include "tm.h"' resolves to that back end's copy.

   That works, and it fails in the one way this branch exists to remove: if
   the `-I' is missing, or ordered after `-I.', the SAME source compiles
   perfectly well against the build root's tm.h -- the PRIMARY target's --
   with no diagnostic at all.  It has already happened once here; see commit
   d7a12b9d5c4, whose subject is `the include directory did not reach them'.

   So: a source that is compiled once per back end names the back end AT THE
   POINT OF INCLUSION, rather than leaving it to a flag.

       #include BASE_HEADER (tm.h)

   The base is `-DMT_BASE=<cpu>-inc', emitted per object next to `-I<cpu>-inc'.
   Both wrong answers are now fatal and name the path:

       MT_BASE undefined    fatal error: MT_BASE/tm.h: No such file or directory
       MT_BASE wrong	    fatal error: aarch64-inc/tm.h: No such file ...

   Neither can degrade to the primary, which is the whole point.  Note the
   second: the `-I' scheme could not distinguish a wrong base from success at
   all, because every base's directory holds the same sixteen names.

   ONE `-D' SERVES EVERY HEADER.  BASE_HEADER (tm_p.h), BASE_HEADER
   (insn-attr.h) and the rest all follow from the single `-DMT_BASE'.  A
   separate `-D' per header would be N more chances for exactly one to go
   missing, and a single missing one is precisely the silent-primary failure
   being removed.

   THE FORM IS STRINGIFICATION, AND IT YIELDS THE QUOTED INCLUDE "..." RATHER
   THAN THE ANGLE-BRACKET ONE.  That is a user preference, stated as *"I like
   the version that results in "..." not <...> better"*.  It is also the
   spelling of the original ruling -- `#include "<base>/tm.h"'.

   The call sites are unchanged by it: BASE_HEADER (tm.h), argument unquoted.
   Only the expansion moved, from <MT_BASE/tm.h> to "i386-inc/tm.h".

   Five other spellings were tried and three are traps:

       #include MT_BASE "/tm.h"       WARNS ONLY and drops "/tm.h" -- a
				      warning in a build that emits hundreds
       #include <MT_BASE/tm.h>	      no expansion happens in the literal form
       #include CAT (<, MT_BASE/tm.h) `##' cannot express this: a paste must
				      yield ONE valid preprocessing token and a
				      path is many
       #define BASE_HEADER(f) <MT_BASE/f>
				      plain substitution into <>; works, and is
				      what this file carried before
       #include BASE_HEADER ("tm.h")  i386-inc/"tm.h": No such file

   TWO CONSEQUENCES OF "..." OVER <>, BOTH CHECKED RATHER THAN ASSUMED.
   First, "..." is searched in the INCLUDING FILE'S OWN DIRECTORY before any
   `-I'.  A shadow would take a directory literally named `<cpu>-inc' sitting
   beside one of these sources, i.e. in gcc/ or in the build root; there is
   none in the tree, and the fall-through to `-I' is graceful in any case.
   Second, the quoted form is a different lookup for dependency generation:
   the twenty `.deps' entries for these objects were compared before and after
   by content and are byte-identical (and their mtimes confirm they were
   regenerated, not merely left alone).  That matters here because a broken
   depfile on this branch has already caused a class of silent staleness.

   THE HELPERS ARE `MT_HDR_STR'/`MT_HDR_XSTR' AND NOT `STR'/`XSTR'.  `XSTR' is
   the rtl.h accessor, and `MT_STR' is already defined -- differently -- in
   target-cumargs.cc and target-regs.cc, both AFTER this header is included.
   Either name would have been a redefinition.  `MT_HDR_STR' and `MT_HDR_XSTR'
   were counted with `wc -l' and no `head': 0 hits each.

   THE `-D' IS `MT_BASE' AND NOT `BASE', AND THAT IS NOT FASTIDIOUSNESS.  `BASE'
   was tried first and the build failed: `-DBASE=aarch64-inc' goes on every one
   of that back end's objects, and `BASE' is already a template parameter at
   config/aarch64/aarch64-sve-builtins-shapes.cc:1154 and a macro parameter at
   aarch64-builtins.cc:1447 and aarch64-acle-builtins.cc:129.  The diagnostic
   is `<command-line>: error: expected nested-name-specifier before aarch64',
   which names neither the flag nor this file.  A grep for the bare word before
   settling on the name missed it because the output was piped through `head'.
   BASE_HEADER itself is unused elsewhere in the tree and is kept, so the
   include sites read as the user asked for them.

   NOT `-DMULTI_TARGET_TARGETM_BASE=<cpu>', which is already passed to most of
   these objects and carries the bare cpu name.  Two reasons.  It is
   contractually paired with `-Dtargetm=' -- target.h #errors if either
   appears without the other -- and it means `this translation unit is a back
   end's own', which is not the same claim as `this is where my headers are'.
   And mt-<cpu>/reg-probe.o needs the include path while it must NOT be
   renamed.  One name, one authority.  */

#ifndef GCC_MULTI_TARGET_BASE_H
#define GCC_MULTI_TARGET_BASE_H

#ifndef MT_BASE
#error "MT_BASE is not defined: this source is compiled once per back end and \
must be given -DMT_BASE=<cpu>-inc.  See gcc/multi-target-base.h."
#endif

/* This back end's copy of the header F.  F is UNQUOTED: BASE_HEADER (tm.h).

   THE DOUBLE INDIRECTION IS LOAD-BEARING, NOT DECORATION.  `#' suppresses
   macro expansion of its operand, so MT_HDR_STR alone would stringify the
   spelling `MT_BASE/tm.h' and yield the literal "MT_BASE/tm.h" -- a
   plausible-looking WRONG PATH, which is exactly the silent-failure shape this
   file exists to remove.  MT_HDR_XSTR exists solely to force one round of
   expansion first, so MT_BASE becomes `i386-inc' BEFORE the `#' sees it.
   ARM 6 of scratchpad/t140-inject.sh is the arm that catches its removal: it
   asserts the expansion contains the actual base name, and its own negative
   control is a hand-rolled single-indirection macro spelt in the same TU.

   MEASURED, by stripping MT_HDR_XSTR from a copy of this file: the WITNESS
   catches it too, and first --
   `mt-inc-witness.h:1:40: fatal error: MT_BASE/mt-inc-tag-i386.h: No such
   file or directory'.  So the mistake is fatal and names the flag rather than
   silently opening another target's headers.  That is a second authority
   agreeing, not a reason to drop ARM 6: the witness only fires because it is
   reached through BASE_HEADER, and ARM 6 is what reads the expansion itself
   and so can say WHICH way it went wrong.  */
#define MT_HDR_STR(f) #f
#define MT_HDR_XSTR(f) MT_HDR_STR (f)
#define BASE_HEADER(f) MT_HDR_XSTR (MT_BASE/f)

/* THE WITNESS, AND WHY IT IS NOT REDUNDANT.

   BASE_HEADER () makes the base explicit for the headers a source names
   itself.  It deliberately does NOT make `-I<base>-inc' unnecessary: every
   header those headers pull in transitively -- rtl.h reaching insn-modes.h,
   and so on -- is still resolved by the `-I', and would still fall back to
   the build root's primary copies without a word if the flag went missing.

   So `-DMT_BASE' and `-I<base>-inc' are two statements of the same fact, and the
   bug this branch hunts is exactly two authorities for one fact with no
   diagnostic.  The witness makes them check each other.  Two files are
   generated into every `<base>-inc/':

       mt-inc-witness.h	  found ONLY through -I<base>-inc, and containing
			  #include BASE_HEADER (mt-inc-tag-<that base>.h)
       mt-inc-tag-<base>.h	  the tag it names

   which gives, by construction and always by name:

       -I missing	  fatal: mt-inc-witness.h: No such file
       -I wrong base	  fatal: i386-inc/mt-inc-tag-aarch64.h: No such file
       MT_BASE wrong	  fatal: aarch64-inc/mt-inc-tag-i386.h: No such file
       MT_BASE undefined  fatal: MT_BASE/tm.h: No such file

   Note the third and fourth are what the `-I' scheme could never report: with
   several back ends configured, EVERY base's directory holds the same sixteen
   names, so a wrong directory is a perfectly successful compilation of the
   wrong target's headers.  That is the failure, and until now nothing in the
   build could see it.

   `mt-inc-witness.h' is included by its PLAIN name on purpose -- spelling it
   BASE_HEADER (mt-inc-witness.h) would resolve it through `-I.' and the first
   arm would test nothing.  */
#include "mt-inc-witness.h"

#endif /* GCC_MULTI_TARGET_BASE_H */
