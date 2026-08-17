/*
 * Copyright (c) 2021-2026 Symas Corporation
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above
 *   copyright notice, this list of conditions and the following disclaimer
 *   in the documentation and/or other materials provided with the
 *   distribution.
 * * Neither the name of the Symas Corporation nor the names of its
 *   contributors may be used to endorse or promote products derived from
 *   this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef COBOL_ENDIAN_H
#define COBOL_ENDIAN_H

/*
   COBOL_TARGET_BIG_ENDIAN answers:
     "Should this code treat COBOL target storage as big-endian?"

   In the compiler front end, that means the GCC target.
   In libgcobol, that means the actual runtime machine/library build.
*/

#if defined(IN_GCC_FRONTEND)

/* Front-end / compiler build.  This is compiler run time,
   but target endianness. */

/* INCLUDE WHAT YOU USE, AND SAY WHY.  `BYTES_BIG_ENDIAN' is not a
   preprocessor constant on the multi-target branch: it is
   `(targetm_cdata.bytes_big_endian)' (multi-target-macros.h), a read of the
   SELECTED target's data, reached only through `target.h' -> `tm.h' ->
   `defaults.h'.  Upstream this header could rely on whatever the including
   `.cc' had already pulled in; here the include that used to supply the name
   was removed from a shared header, so `cobol/genmath.cc', `cobol/symbols.cc'
   and `cobol/util.cc' each failed with

     cobol-endian.h:50:10: error: 'BYTES_BIG_ENDIAN' was not declared in this
       scope; did you mean 'SSO_BIG_ENDIAN'?
     note: the macro 'BYTES_BIG_ENDIAN' had not yet been defined
     note: it was later defined here   <- multi-target-macros.h:380

   -- three compilations of the same header, each deciding by INCLUDE ORDER
   whether the name existed.  Note the shape of the near miss: the compiler
   offered `SSO_BIG_ENDIAN', a real and entirely unrelated identifier, so the
   obvious repair is a plausible wrong answer.  Naming the dependency here
   fixes it once for every includer, present and future, rather than making
   three `.cc' files carry an ordering rule nothing states.  */
#include "target.h"

static inline bool
cobol_target_big_endian()
  {
  return BYTES_BIG_ENDIAN;
  }

#else

/* Runtime library build.  This is target-program run time,
   so it must be decided from the runtime library's build config. */

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
# define COBOL_BIG_ENDIAN 1
# define COBOL_LITTLE_ENDIAN 0
#elif defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
# define COBOL_BIG_ENDIAN 0
# define COBOL_LITTLE_ENDIAN 1

#elif defined(__BIG_ENDIAN__) || defined(_BIG_ENDIAN)
# define COBOL_BIG_ENDIAN 1
# define COBOL_LITTLE_ENDIAN 0
#elif defined(__LITTLE_ENDIAN__) || defined(_LITTLE_ENDIAN)
# define COBOL_BIG_ENDIAN 0
# define COBOL_LITTLE_ENDIAN 1

#endif

static inline bool
cobol_target_big_endian()
  {
  return COBOL_BIG_ENDIAN != 0;
  }

static inline bool
cobol_target_little_endian()
  {
  return COBOL_BIG_ENDIAN == 0;
  }


#endif

#endif /* COBOL_ENDIAN_H */