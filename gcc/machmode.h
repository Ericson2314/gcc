/* Machine mode definitions for GCC; included by rtl.h and tree.h.
   Copyright (C) 1991-2026 Free Software Foundation, Inc.

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

#ifndef HAVE_MACHINE_MODES
#define HAVE_MACHINE_MODES

typedef opt_mode<machine_mode> opt_machine_mode;

/* Every mode table below is declared through GCC_TARGET_TABLE, which
   insn-modes.h defines.  On a single-target build it expands to the array
   these have always been.  On a multi-target build it expands to a POINTER:
   each configured back end has its own table, in its own namespace, and
   multi-target-select.cc aims these names at the back end in force.

   Indexing is written the same way either way, which is the point -- not one
   of the several thousand `mode_size[m]' call sites has to know.  What DOES
   change is that `sizeof mode_size' and any use of one of these in a constant
   expression stop compiling, and that is wanted: both are answers about one
   particular back end being given to code that serves all of them.  */

extern GCC_TARGET_TABLE (CONST_MODE_SIZE poly_uint16, mode_size,
		       NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (CONST_MODE_PRECISION poly_uint16, mode_precision,
		       NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (const unsigned short, mode_inner, NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (CONST_MODE_NUNITS poly_uint16, mode_nunits,
		       NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (CONST_MODE_UNIT_SIZE unsigned char, mode_unit_size,
		       NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (const unsigned short, mode_unit_precision,
		       NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (const unsigned short, mode_next, NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (const unsigned short, mode_wider, NUM_MACHINE_MODES);
extern GCC_TARGET_TABLE (const unsigned short, mode_2xwider, NUM_MACHINE_MODES);

template<typename T>
struct mode_traits
{
  /* For use by the machmode support code only.

     There are cases in which the machmode support code needs to forcibly
     convert a machine_mode to a specific mode class T, and in which the
     context guarantees that this is valid without the need for an assert.
     This can be done using:

       return typename mode_traits<T>::from_int (mode);

     when returning a T and:

       res = T (typename mode_traits<T>::from_int (mode));

     when assigning to a value RES that must be assignment-compatible
     with (but possibly not the same as) T.  */
#ifdef USE_ENUM_MODES
  /* Allow direct conversion of enums to specific mode classes only
     when USE_ENUM_MODES is defined.  This is only intended for use
     by gencondmd, so that it can tell more easily when .md conditions
     are always false.  */
  typedef machine_mode from_int;
#else
  /* Here we use an enum type distinct from machine_mode but with the
     same range as machine_mode.  T should have a constructor that
     accepts this enum type; it should not have a constructor that
     accepts machine_mode.

     We use this somewhat indirect approach to avoid too many constructor
     calls when the compiler is built with -O0.  For example, even in
     unoptimized code, the return statement above would construct the
     returned T directly from the numerical value of MODE.  */
  enum from_int { dummy = MAX_MACHINE_MODE };
#endif
};

template<>
struct mode_traits<machine_mode>
{
  /* machine_mode itself needs no conversion.  */
  typedef machine_mode from_int;
};

/* Always treat machine modes as fixed-size while compiling code specific
   to targets that have no variable-size modes.

   A back end opts out by defining TARGET_POLY_AWARE, saying its sources have
   been converted and no longer want the fixed-size shorthand.  See
   coretypes.h, which carries the other half of the same switch and the
   explanation of what the opt-in is for -- including why `NUM_POLY_INT_COEFFS
   == 1' is no longer a conjunct here: whether a back end wants the shorthand
   is a per-back-end question, and this branch's build-wide constant is 2
   while 37 of 47 back ends are still unconverted.  */
#if defined (IN_TARGET_CODE) && !defined (TARGET_POLY_AWARE)
#define ONLY_FIXED_SIZE_MODES 1
#else
#define ONLY_FIXED_SIZE_MODES 0
#endif

/* Get the name of mode MODE as a string.  */

extern GCC_TARGET_TABLE (const char *const, mode_name, NUM_MACHINE_MODES);
#define GET_MODE_NAME(MODE)  mode_name[MODE]

/* Mode classes.  */

#include "mode-classes.def"
#define DEF_MODE_CLASS(M) M
enum mode_class { MODE_CLASSES, MAX_MODE_CLASS };
#undef DEF_MODE_CLASS
#undef MODE_CLASSES

/* Get the general kind of object that mode MODE represents
   (integer, floating, complex, etc.)  */

extern GCC_TARGET_TABLE (const unsigned char, mode_class, NUM_MACHINE_MODES);
#define GET_MODE_CLASS(MODE)  ((enum mode_class) mode_class[MODE])

/* Nonzero if MODE is an integral mode.  */
#define INTEGRAL_MODE_P(MODE)			\
  (GET_MODE_CLASS (MODE) == MODE_INT		\
   || GET_MODE_CLASS (MODE) == MODE_PARTIAL_INT \
   || GET_MODE_CLASS (MODE) == MODE_COMPLEX_INT \
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_BOOL \
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_INT)

/* Nonzero if MODE is a floating-point mode.  */
#define FLOAT_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_FLOAT	\
   || GET_MODE_CLASS (MODE) == MODE_DECIMAL_FLOAT \
   || GET_MODE_CLASS (MODE) == MODE_COMPLEX_FLOAT \
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_FLOAT)

/* Nonzero if MODE is a complex mode.  */
#define COMPLEX_MODE_P(MODE)			\
  (GET_MODE_CLASS (MODE) == MODE_COMPLEX_INT	\
   || GET_MODE_CLASS (MODE) == MODE_COMPLEX_FLOAT)

/* Nonzero if MODE is a vector mode.  */
#define VECTOR_MODE_P(MODE)				\
  (GET_MODE_CLASS (MODE) == MODE_VECTOR_BOOL		\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_INT		\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_FLOAT	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_FRACT	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_UFRACT	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_ACCUM	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_UACCUM)

/* Nonzero if MODE is a scalar integral mode.  */
#define SCALAR_INT_MODE_P(MODE)			\
  (GET_MODE_CLASS (MODE) == MODE_INT		\
   || GET_MODE_CLASS (MODE) == MODE_PARTIAL_INT)

/* Nonzero if MODE is a scalar floating point mode.  */
#define SCALAR_FLOAT_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_FLOAT		\
   || GET_MODE_CLASS (MODE) == MODE_DECIMAL_FLOAT)

/* Nonzero if MODE is a decimal floating point mode.  */
#define DECIMAL_FLOAT_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_DECIMAL_FLOAT)

/* Nonzero if MODE is a scalar fract mode.  */
#define SCALAR_FRACT_MODE_P(MODE)	\
  (GET_MODE_CLASS (MODE) == MODE_FRACT)

/* Nonzero if MODE is a scalar ufract mode.  */
#define SCALAR_UFRACT_MODE_P(MODE)	\
  (GET_MODE_CLASS (MODE) == MODE_UFRACT)

/* Nonzero if MODE is a scalar fract or ufract mode.  */
#define ALL_SCALAR_FRACT_MODE_P(MODE)	\
  (SCALAR_FRACT_MODE_P (MODE) || SCALAR_UFRACT_MODE_P (MODE))

/* Nonzero if MODE is a scalar accum mode.  */
#define SCALAR_ACCUM_MODE_P(MODE)	\
  (GET_MODE_CLASS (MODE) == MODE_ACCUM)

/* Nonzero if MODE is a scalar uaccum mode.  */
#define SCALAR_UACCUM_MODE_P(MODE)	\
  (GET_MODE_CLASS (MODE) == MODE_UACCUM)

/* Nonzero if MODE is a scalar accum or uaccum mode.  */
#define ALL_SCALAR_ACCUM_MODE_P(MODE)	\
  (SCALAR_ACCUM_MODE_P (MODE) || SCALAR_UACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar fract or accum mode.  */
#define SIGNED_SCALAR_FIXED_POINT_MODE_P(MODE)	\
  (SCALAR_FRACT_MODE_P (MODE) || SCALAR_ACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar ufract or uaccum mode.  */
#define UNSIGNED_SCALAR_FIXED_POINT_MODE_P(MODE)	\
  (SCALAR_UFRACT_MODE_P (MODE) || SCALAR_UACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar fract, ufract, accum or uaccum mode.  */
#define ALL_SCALAR_FIXED_POINT_MODE_P(MODE)	\
  (SIGNED_SCALAR_FIXED_POINT_MODE_P (MODE)	\
   || UNSIGNED_SCALAR_FIXED_POINT_MODE_P (MODE))

/* Nonzero if MODE is a scalar/vector fract mode.  */
#define FRACT_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_FRACT	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_FRACT)

/* Nonzero if MODE is a scalar/vector ufract mode.  */
#define UFRACT_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_UFRACT	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_UFRACT)

/* Nonzero if MODE is a scalar/vector fract or ufract mode.  */
#define ALL_FRACT_MODE_P(MODE)		\
  (FRACT_MODE_P (MODE) || UFRACT_MODE_P (MODE))

/* Nonzero if MODE is a scalar/vector accum mode.  */
#define ACCUM_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_ACCUM	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_ACCUM)

/* Nonzero if MODE is a scalar/vector uaccum mode.  */
#define UACCUM_MODE_P(MODE)		\
  (GET_MODE_CLASS (MODE) == MODE_UACCUM	\
   || GET_MODE_CLASS (MODE) == MODE_VECTOR_UACCUM)

/* Nonzero if MODE is a scalar/vector accum or uaccum mode.  */
#define ALL_ACCUM_MODE_P(MODE)		\
  (ACCUM_MODE_P (MODE) || UACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar/vector fract or accum mode.  */
#define SIGNED_FIXED_POINT_MODE_P(MODE)		\
  (FRACT_MODE_P (MODE) || ACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar/vector ufract or uaccum mode.  */
#define UNSIGNED_FIXED_POINT_MODE_P(MODE)	\
  (UFRACT_MODE_P (MODE) || UACCUM_MODE_P (MODE))

/* Nonzero if MODE is a scalar/vector fract, ufract, accum or uaccum mode.  */
#define ALL_FIXED_POINT_MODE_P(MODE)		\
  (SIGNED_FIXED_POINT_MODE_P (MODE)		\
   || UNSIGNED_FIXED_POINT_MODE_P (MODE))

/* Nonzero if MODE is opaque.  */
#define OPAQUE_MODE_P(MODE)                     \
    (GET_MODE_CLASS (MODE) == MODE_OPAQUE)

/* Nonzero if CLASS modes can be widened.  */
#define CLASS_HAS_WIDER_MODES_P(CLASS)         \
  (CLASS == MODE_INT                           \
   || CLASS == MODE_PARTIAL_INT                \
   || CLASS == MODE_FLOAT                      \
   || CLASS == MODE_DECIMAL_FLOAT              \
   || CLASS == MODE_COMPLEX_FLOAT              \
   || CLASS == MODE_FRACT                      \
   || CLASS == MODE_UFRACT                     \
   || CLASS == MODE_ACCUM                      \
   || CLASS == MODE_UACCUM)

/* The MACHINE_MODE_BITSIZE should be exactly aligned with the type of the
   machine_mode array in the machmode.h and genmodes.cc.  For example as below.
   +------------------------+-------+
   | MACHINE_MODE_BITSIZE   |    16 |
   +------------------------+-------+
   | mode_inter[]           | short |
   | mode_next[]            | short |
   | mode_wider[]           | short |
   | mode_2xwider[]         | short |
   | mode_complex[]         | short |
   | class_narrowest_mode[] | short |
   +------------------------+-------+
   */
#define MACHINE_MODE_BITSIZE 16

/* An optional T (i.e. a T or nothing), where T is some form of mode class.  */
template<typename T>
class opt_mode
{
public:
  enum from_int { dummy = MAX_MACHINE_MODE };

  ALWAYS_INLINE constexpr opt_mode () : m_mode (E_VOIDmode) {}
  ALWAYS_INLINE constexpr opt_mode (const T &m) : m_mode (m) {}
  template<typename U>
  ALWAYS_INLINE constexpr opt_mode (const U &m) : m_mode (T (m)) {}
  template<typename U>
  ALWAYS_INLINE constexpr opt_mode (const opt_mode<U> &);
  ALWAYS_INLINE constexpr opt_mode (from_int m) : m_mode (machine_mode (m)) {}

  machine_mode else_void () const;
  machine_mode else_blk () const { return else_mode (BLKmode); }
  machine_mode else_mode (machine_mode) const;
  T require () const;

  bool exists () const;
  template<typename U> bool exists (U *) const;

  bool operator== (const T &m) const { return m_mode == m; }
  bool operator!= (const T &m) const { return m_mode != m; }

private:
  machine_mode m_mode;
};

template<typename T>
template<typename U>
ALWAYS_INLINE constexpr
opt_mode<T>::opt_mode (const opt_mode<U> &m)
  : m_mode (m.exists () ? T (m.require ()) : E_VOIDmode)
{
}

/* If the object contains a T, return its enum value, otherwise return
   E_VOIDmode.  */

template<typename T>
ALWAYS_INLINE machine_mode
opt_mode<T>::else_void () const
{
  return m_mode;
}

/* If the T exists, return its enum value, otherwise return FALLBACK.  */

template<typename T>
inline machine_mode
opt_mode<T>::else_mode (machine_mode fallback) const
{
  return m_mode == E_VOIDmode ? fallback : m_mode;
}

/* Assert that the object contains a T and return it.  */

template<typename T>
inline T
opt_mode<T>::require () const
{
  gcc_checking_assert (m_mode != E_VOIDmode);
  return typename mode_traits<T>::from_int (m_mode);
}

/* Return true if the object contains a T rather than nothing.  */

template<typename T>
ALWAYS_INLINE bool
opt_mode<T>::exists () const
{
  return m_mode != E_VOIDmode;
}

/* Return true if the object contains a T, storing it in *MODE if so.  */

template<typename T>
template<typename U>
inline bool
opt_mode<T>::exists (U *mode) const
{
  if (m_mode != E_VOIDmode)
    {
      *mode = T (typename mode_traits<T>::from_int (m_mode));
      return true;
    }
  return false;
}

/* A POD version of mode class T.  */

template<typename T>
struct pod_mode
{
  typedef typename mode_traits<T>::from_int from_int;
  typedef typename T::measurement_type measurement_type;

  machine_mode m_mode;
  ALWAYS_INLINE constexpr
  operator machine_mode () const { return m_mode; }

  ALWAYS_INLINE constexpr
  operator T () const { return from_int (m_mode); }

  ALWAYS_INLINE pod_mode &operator = (const T &m) { m_mode = m; return *this; }
};

/* Return true if mode M has type T.  */

template<typename T>
inline bool
is_a (machine_mode m)
{
  return T::includes_p (m);
}

template<typename T, typename U>
inline bool
is_a (const opt_mode<U> &m)
{
  return T::includes_p (m.else_void ());
}

/* Assert that mode M has type T, and return it in that form.  */

template<typename T>
inline T
as_a (machine_mode m)
{
  gcc_checking_assert (T::includes_p (m));
  return typename mode_traits<T>::from_int (m);
}

template<typename T, typename U>
inline T
as_a (const opt_mode<U> &m)
{
  return as_a <T> (m.else_void ());
}

/* Convert M to an opt_mode<T>.  */

template<typename T>
inline opt_mode<T>
dyn_cast (machine_mode m)
{
  if (T::includes_p (m))
    return T (typename mode_traits<T>::from_int (m));
  return opt_mode<T> ();
}

template<typename T, typename U>
inline opt_mode<T>
dyn_cast (const opt_mode<U> &m)
{
  return dyn_cast <T> (m.else_void ());
}

/* Return true if mode M has type T, storing it as a T in *RESULT
   if so.  */

template<typename T, typename U>
inline bool
is_a (machine_mode m, U *result)
{
  if (T::includes_p (m))
    {
      *result = T (typename mode_traits<T>::from_int (m));
      return true;
    }
  return false;
}

/* Represents a machine mode that is known to be a SCALAR_INT_MODE_P.  */
class scalar_int_mode
{
public:
  typedef mode_traits<scalar_int_mode>::from_int from_int;
  typedef unsigned short measurement_type;

  ALWAYS_INLINE scalar_int_mode () {}

  ALWAYS_INLINE constexpr
  scalar_int_mode (from_int m) : m_mode (machine_mode (m)) {}

  ALWAYS_INLINE constexpr operator machine_mode () const { return m_mode; }

  static bool includes_p (machine_mode);

protected:
  machine_mode m_mode;
};

/* Return true if M is a scalar_int_mode.  */

inline bool
scalar_int_mode::includes_p (machine_mode m)
{
  return SCALAR_INT_MODE_P (m);
}

/* Represents a machine mode that is known to be a SCALAR_FLOAT_MODE_P.  */
class scalar_float_mode
{
public:
  typedef mode_traits<scalar_float_mode>::from_int from_int;
  typedef unsigned short measurement_type;

  ALWAYS_INLINE scalar_float_mode () {}

  ALWAYS_INLINE constexpr
  scalar_float_mode (from_int m) : m_mode (machine_mode (m)) {}

  ALWAYS_INLINE constexpr operator machine_mode () const { return m_mode; }

  static bool includes_p (machine_mode);

protected:
  machine_mode m_mode;
};

/* Return true if M is a scalar_float_mode.  */

inline bool
scalar_float_mode::includes_p (machine_mode m)
{
  return SCALAR_FLOAT_MODE_P (m);
}

/* Represents a machine mode that is known to be scalar.  */
class scalar_mode
{
public:
  typedef mode_traits<scalar_mode>::from_int from_int;
  typedef unsigned short measurement_type;

  ALWAYS_INLINE scalar_mode () {}

  ALWAYS_INLINE constexpr
  scalar_mode (from_int m) : m_mode (machine_mode (m)) {}

  ALWAYS_INLINE constexpr
  scalar_mode (const scalar_int_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  scalar_mode (const scalar_float_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  scalar_mode (const scalar_int_mode_pod &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr operator machine_mode () const { return m_mode; }

  static bool includes_p (machine_mode);

protected:
  machine_mode m_mode;
};

/* Return true if M represents some kind of scalar value.  */

inline bool
scalar_mode::includes_p (machine_mode m)
{
  switch (GET_MODE_CLASS (m))
    {
    case MODE_INT:
    case MODE_PARTIAL_INT:
    case MODE_FRACT:
    case MODE_UFRACT:
    case MODE_ACCUM:
    case MODE_UACCUM:
    case MODE_FLOAT:
    case MODE_DECIMAL_FLOAT:
      return true;
    default:
      return false;
    }
}

/* Represents a machine mode that is known to be a COMPLEX_MODE_P.  */
class complex_mode
{
public:
  typedef mode_traits<complex_mode>::from_int from_int;
  typedef unsigned short measurement_type;

  ALWAYS_INLINE complex_mode () {}

  ALWAYS_INLINE constexpr
  complex_mode (from_int m) : m_mode (machine_mode (m)) {}

  ALWAYS_INLINE constexpr operator machine_mode () const { return m_mode; }

  static bool includes_p (machine_mode);

protected:
  machine_mode m_mode;
};

/* Return true if M is a complex_mode.  */

inline bool
complex_mode::includes_p (machine_mode m)
{
  return COMPLEX_MODE_P (m);
}

/* Return the base GET_MODE_SIZE value for MODE.  */

ALWAYS_INLINE poly_uint16
mode_to_bytes (machine_mode mode)
{
#if GCC_VERSION >= 4001
  return (__builtin_constant_p (mode)
	  ? mode_size_inline (mode) : mode_size[mode]);
#else
  return mode_size[mode];
#endif
}

/* Return the base GET_MODE_BITSIZE value for MODE.  */

ALWAYS_INLINE poly_uint16
mode_to_bits (machine_mode mode)
{
  return mode_to_bytes (mode) * BITS_PER_UNIT;
}

/* Return the base GET_MODE_PRECISION value for MODE.  */

ALWAYS_INLINE poly_uint16
mode_to_precision (machine_mode mode)
{
  return mode_precision[mode];
}

/* Return the base GET_MODE_INNER value for MODE.  */

ALWAYS_INLINE scalar_mode
mode_to_inner (machine_mode mode)
{
#if GCC_VERSION >= 4001
  return scalar_mode::from_int (__builtin_constant_p (mode)
				? mode_inner_inline (mode)
				: mode_inner[mode]);
#else
  return scalar_mode::from_int (mode_inner[mode]);
#endif
}

/* Return the base GET_MODE_UNIT_SIZE value for MODE.  */

ALWAYS_INLINE unsigned char
mode_to_unit_size (machine_mode mode)
{
#if GCC_VERSION >= 4001
  return (__builtin_constant_p (mode)
	  ? mode_unit_size_inline (mode) : mode_unit_size[mode]);
#else
  return mode_unit_size[mode];
#endif
}

/* Return the base GET_MODE_UNIT_PRECISION value for MODE.  */

ALWAYS_INLINE unsigned short
mode_to_unit_precision (machine_mode mode)
{
#if GCC_VERSION >= 4001
  return (__builtin_constant_p (mode)
	  ? mode_unit_precision_inline (mode) : mode_unit_precision[mode]);
#else
  return mode_unit_precision[mode];
#endif
}

/* Return the base GET_MODE_NUNITS value for MODE.  */

ALWAYS_INLINE poly_uint16
mode_to_nunits (machine_mode mode)
{
#if GCC_VERSION >= 4001
  return (__builtin_constant_p (mode)
	  ? mode_nunits_inline (mode) : mode_nunits[mode]);
#else
  return mode_nunits[mode];
#endif
}

/* Get the size in bytes of an object of mode MODE.  */

/* The four fixed-size accessors below say `.to_constant ()' and not
   `.coeffs[0]'.  At NUM_POLY_INT_COEFFS == 1 the two are the same expression
   -- is_constant () is `return true' for N == 1 -- so this is free, and no
   single-target build changes.  At 2, which is what a multi-target build
   with aarch64 configured has, they differ in the way that matters: coeffs[0]
   DISCARDS a non-zero coefficient 1 with no diagnostic, while to_constant ()
   asserts is_constant () first.  Unconverted target code never legitimately
   sees a variable-size mode -- only aarch64 and riscv have any, and both are
   TARGET_POLY_AWARE -- so the assert is the statement of that invariant
   rather than a cost, and if the shared mode vocabulary ever does hand one of
   these back ends an SVE mode the build says so by name instead of quietly
   computing with half a value.  */
#if ONLY_FIXED_SIZE_MODES
#define GET_MODE_SIZE(MODE) ((unsigned short) mode_to_bytes (MODE).to_constant ())
#else
ALWAYS_INLINE poly_uint16
GET_MODE_SIZE (machine_mode mode)
{
  return mode_to_bytes (mode);
}

template<typename T>
ALWAYS_INLINE typename if_poly<typename T::measurement_type>::type
GET_MODE_SIZE (const T &mode)
{
  return mode_to_bytes (mode);
}

template<typename T>
ALWAYS_INLINE typename if_nonpoly<typename T::measurement_type>::type
GET_MODE_SIZE (const T &mode)
{
  return mode_to_bytes (mode).coeffs[0];
}
#endif

/* Get the size in bits of an object of mode MODE.  */

#if ONLY_FIXED_SIZE_MODES
#define GET_MODE_BITSIZE(MODE) ((unsigned short) mode_to_bits (MODE).to_constant ())
#else
ALWAYS_INLINE poly_uint16
GET_MODE_BITSIZE (machine_mode mode)
{
  return mode_to_bits (mode);
}

template<typename T>
ALWAYS_INLINE typename if_poly<typename T::measurement_type>::type
GET_MODE_BITSIZE (const T &mode)
{
  return mode_to_bits (mode);
}

template<typename T>
ALWAYS_INLINE typename if_nonpoly<typename T::measurement_type>::type
GET_MODE_BITSIZE (const T &mode)
{
  return mode_to_bits (mode).coeffs[0];
}
#endif

/* Get the number of value bits of an object of mode MODE.  */

#if ONLY_FIXED_SIZE_MODES
#define GET_MODE_PRECISION(MODE) \
  ((unsigned short) mode_to_precision (MODE).to_constant ())
#else
ALWAYS_INLINE poly_uint16
GET_MODE_PRECISION (machine_mode mode)
{
  return mode_to_precision (mode);
}

template<typename T>
ALWAYS_INLINE typename if_poly<typename T::measurement_type>::type
GET_MODE_PRECISION (const T &mode)
{
  return mode_to_precision (mode);
}

template<typename T>
ALWAYS_INLINE typename if_nonpoly<typename T::measurement_type>::type
GET_MODE_PRECISION (const T &mode)
{
  return mode_to_precision (mode).coeffs[0];
}
#endif

/* True when the back end IN FORCE actually defines MODE.

   `HAVE_XFmode' and the rest of the `HAVE_<mode>mode' predicates come from
   the SHARED mode enum, so what they answer is "SOME configured back end
   has this mode" -- the union's answer, not this target's.  Target-
   independent code that writes

     #ifdef HAVE_XFmode
       cand = XFmode;
     #endif

   is asking the second question and getting the first, and on a single-
   target build those two questions had the same answer, which is why the
   code has always been written this way.

   A mode belonging to another back end is a HOLE in this one's tables:
   the class comes from the shared numbering so it lands in the right run
   of the enum, and size, precision, nunits and real format are all zero.
   That zero format is what makes this more than a tidiness point --
   `REAL_MODE_FORMAT (XFmode)->ieee_bits' on aarch64 is a null dereference,
   not a wrong answer.

   Only meaningful once a target is selected; before that, reading
   `mode_precision' is itself a null dereference, deliberately.  */

inline bool
mode_exists_p (machine_mode mode)
{
  /* These two are vocabulary rather than machine description: every back
     end has them and neither has a precision to test.  */
  if (mode == E_VOIDmode || mode == E_BLKmode)
    return true;
  return maybe_ne (mode_precision[mode], (unsigned short) 0);
}

/* Get the number of integral bits of an object of mode MODE.  */
extern GCC_TARGET_TABLE (CONST_MODE_IBIT unsigned char, mode_ibit,
		       NUM_MACHINE_MODES);
#define GET_MODE_IBIT(MODE) mode_ibit[MODE]

/* Get the number of fractional bits of an object of mode MODE.  */
extern GCC_TARGET_TABLE (CONST_MODE_FBIT unsigned char, mode_fbit,
		       NUM_MACHINE_MODES);
#define GET_MODE_FBIT(MODE) mode_fbit[MODE]

/* Get a bitmask containing 1 for all bits in a word
   that fit within mode MODE.  */

extern GCC_TARGET_TABLE (CONST_MODE_MASK unsigned HOST_WIDE_INT,
		       mode_mask_array, NUM_MACHINE_MODES);

#define GET_MODE_MASK(MODE) mode_mask_array[MODE]

/* Return the mode of the basic parts of MODE.  For vector modes this is the
   mode of the vector elements.  For complex modes it is the mode of the real
   and imaginary parts.  For other modes it is MODE itself.  */

#define GET_MODE_INNER(MODE) (mode_to_inner (MODE))

/* Get the size in bytes or bits of the basic parts of an
   object of mode MODE.  */

#define GET_MODE_UNIT_SIZE(MODE) mode_to_unit_size (MODE)

#define GET_MODE_UNIT_BITSIZE(MODE) \
  ((unsigned short) (GET_MODE_UNIT_SIZE (MODE) * BITS_PER_UNIT))

#define GET_MODE_UNIT_PRECISION(MODE) (mode_to_unit_precision (MODE))

/* Get the number of units in an object of mode MODE.  This is 2 for
   complex modes and the number of elements for vector modes.  */

#if ONLY_FIXED_SIZE_MODES
#define GET_MODE_NUNITS(MODE) (mode_to_nunits (MODE).to_constant ())
#else
ALWAYS_INLINE poly_uint16
GET_MODE_NUNITS (machine_mode mode)
{
  return mode_to_nunits (mode);
}

template<typename T>
ALWAYS_INLINE typename if_poly<typename T::measurement_type>::type
GET_MODE_NUNITS (const T &mode)
{
  return mode_to_nunits (mode);
}

template<typename T>
ALWAYS_INLINE typename if_nonpoly<typename T::measurement_type>::type
GET_MODE_NUNITS (const T &mode)
{
  return mode_to_nunits (mode).coeffs[0];
}
#endif

/* Get the next natural mode (not narrower, eg, QI -> HI -> SI -> DI -> TI
   or HF -> BF -> SF -> DF -> XF -> TF).  */

template<typename T>
ALWAYS_INLINE opt_mode<T>
GET_MODE_NEXT_MODE (const T &m)
{
  return typename opt_mode<T>::from_int (mode_next[m]);
}

/* Get the next wider mode (eg, QI -> HI -> SI -> DI -> TI
   or { HF, BF } -> SF -> DF -> XF -> TF).
   This is similar to GET_MODE_NEXT_MODE, but while GET_MODE_NEXT_MODE
   can include mode that have the same precision (e.g.
   GET_MODE_NEXT_MODE (HFmode) can be BFmode even when both have the same
   precision), this one will skip those.  And always VOIDmode for
   modes whose class is !CLASS_HAS_WIDER_MODES_P.  */

template<typename T>
ALWAYS_INLINE opt_mode<T>
GET_MODE_WIDER_MODE (const T &m)
{
  return typename opt_mode<T>::from_int (mode_wider[m]);
}

/* For scalars, this is a mode with twice the precision.  For vectors,
   this is a mode with the same inner mode but with twice the elements.  */

template<typename T>
ALWAYS_INLINE opt_mode<T>
GET_MODE_2XWIDER_MODE (const T &m)
{
  return typename opt_mode<T>::from_int (mode_2xwider[m]);
}

/* Get the complex mode from the component mode.  */
extern GCC_TARGET_TABLE (const unsigned short, mode_complex,
		       NUM_MACHINE_MODES);
#define GET_MODE_COMPLEX_MODE(MODE) ((machine_mode) mode_complex[MODE])

/* Represents a machine mode that must have a fixed size.  The main
   use of this class is to represent the modes of objects that always
   have static storage duration, such as constant pool entries.
   (No current target supports the concept of variable-size static data.)  */
class fixed_size_mode
{
public:
  typedef mode_traits<fixed_size_mode>::from_int from_int;
  typedef unsigned short measurement_type;

  ALWAYS_INLINE fixed_size_mode () {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (from_int m) : m_mode (machine_mode (m)) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const scalar_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const scalar_int_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const scalar_float_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const scalar_mode_pod &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const scalar_int_mode_pod &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr
  fixed_size_mode (const complex_mode &m) : m_mode (m) {}

  ALWAYS_INLINE constexpr operator machine_mode () const { return m_mode; }

  static bool includes_p (machine_mode);

protected:
  machine_mode m_mode;
};

/* Return true if MODE has a fixed size.  */

inline bool
fixed_size_mode::includes_p (machine_mode mode)
{
  return mode_to_bytes (mode).is_constant ();
}

/* Wrapper for mode arguments to target macros, so that if a target
   doesn't need polynomial-sized modes, its header file can continue
   to treat everything as fixed_size_mode.  This should go away once
   macros are moved to target hooks.  It shouldn't be used in other
   contexts.

   KEYED ON ONLY_FIXED_SIZE_MODES, NOT ON `NUM_POLY_INT_COEFFS == 1', for the
   reason given at that macro's definition above and at POLY_INT_CONVERSION in
   coretypes.h: whether a back end wants the fixed-size shorthand is a
   PER-BACK-END question, and this branch's build-wide constant is 2 for
   everyone because the mode vocabulary is shared.  Conjoining on the constant
   therefore made this the identity for ALL 47 back ends -- including the 37
   that have not been converted -- so a target macro in an unconverted back
   end's header received a `machine_mode' where it expects a
   `fixed_size_mode'.  That is the same inertness `POLY_INT_CONVERSION' and
   `ONLY_FIXED_SIZE_MODES' were already re-keyed to fix; these two wrappers
   were simply not re-keyed with them.

   Both halves are unchanged for the ten TARGET_POLY_AWARE back ends (identity,
   as now) and for shared code, which defines no IN_TARGET_CODE and so keeps
   the identity that N == 2 requires.  Of the back ends that actually spell
   MACRO_MODE, mips, s390 and rs6000 are poly-aware and see no change.  */
#if ONLY_FIXED_SIZE_MODES
#define MACRO_MODE(MODE) (as_a <fixed_size_mode> (MODE))
#else
#define MACRO_MODE(MODE) (MODE)
#endif

extern opt_machine_mode mode_for_size (poly_uint64, enum mode_class, int);

/* Return the machine mode to use for a MODE_INT of SIZE bits, if one
   exists.  If LIMIT is nonzero, modes wider than MAX_FIXED_MODE_SIZE
   will not be used.  */

inline opt_scalar_int_mode
int_mode_for_size (poly_uint64 size, int limit)
{
  return dyn_cast <scalar_int_mode> (mode_for_size (size, MODE_INT, limit));
}

/* Return the machine mode to use for a MODE_FLOAT of SIZE bits, if one
   exists.  */

inline opt_scalar_float_mode
float_mode_for_size (poly_uint64 size)
{
  return dyn_cast <scalar_float_mode> (mode_for_size (size, MODE_FLOAT, 0));
}

/* Likewise for MODE_DECIMAL_FLOAT.  */

inline opt_scalar_float_mode
decimal_float_mode_for_size (unsigned int size)
{
  return dyn_cast <scalar_float_mode>
    (mode_for_size (size, MODE_DECIMAL_FLOAT, 0));
}

extern opt_machine_mode smallest_mode_for_size (poly_uint64, enum mode_class);

/* Find the narrowest integer mode that contains at least SIZE bits,
   if such a mode exists.  */

inline opt_scalar_int_mode
smallest_int_mode_for_size (poly_uint64 size)
{
  return dyn_cast <scalar_int_mode> (smallest_mode_for_size (size, MODE_INT));
}

extern opt_scalar_int_mode int_mode_for_mode (machine_mode);
extern opt_machine_mode bitwise_mode_for_mode (machine_mode);
extern opt_machine_mode mode_for_vector (scalar_mode, poly_uint64);
extern opt_machine_mode related_vector_mode (machine_mode, scalar_mode,
					     poly_uint64 = 0);
extern opt_machine_mode related_int_vector_mode (machine_mode);

/* A class for iterating through possible bitfield modes.  */
class bit_field_mode_iterator
{
public:
  bit_field_mode_iterator (HOST_WIDE_INT, HOST_WIDE_INT,
			   poly_int64, poly_int64,
			   unsigned int, bool);
  bool next_mode (scalar_int_mode *);
  bool prefer_smaller_modes ();

private:
  opt_scalar_int_mode m_mode;
  /* We use signed values here because the bit position can be negative
     for invalid input such as gcc.dg/pr48335-8.c.  */
  HOST_WIDE_INT m_bitsize;
  HOST_WIDE_INT m_bitpos;
  poly_int64 m_bitregion_start;
  poly_int64 m_bitregion_end;
  unsigned int m_align;
  bool m_volatilep;
  int m_count;
};

/* Find the best mode to use to access a bit field.  */

extern bool get_best_mode (HOST_WIDE_INT, HOST_WIDE_INT,
			   poly_uint64, poly_uint64, unsigned int,
			   unsigned HOST_WIDE_INT, bool, scalar_int_mode *);

/* Determine alignment, 1<=result<=BIGGEST_ALIGNMENT.  */

extern GCC_TARGET_TABLE (CONST_MODE_BASE_ALIGN unsigned short, mode_base_align,
		       NUM_MACHINE_MODES);

extern unsigned get_mode_alignment (machine_mode);

#define GET_MODE_ALIGNMENT(MODE) get_mode_alignment (MODE)

/* For each class, get the narrowest mode in that class.  */

extern GCC_TARGET_TABLE (const unsigned short, class_narrowest_mode,
		       MAX_MODE_CLASS);
#define GET_CLASS_NARROWEST_MODE(CLASS) \
  ((machine_mode) class_narrowest_mode[CLASS])

/* MODE'S DENSE 0-BASED POSITION AMONG THE SELECTED BACK END'S OWN MODES OF
   MODE'S CLASS, and the number of the selected back end's own modes in a
   class.

   `MODE - MIN_MODE_<CLASS>' is NOT that number here, and the difference is the
   union-bound-as-SIZE versus as-PREDICATE distinction again.  `MIN_MODE_FLOAT'
   and `MAX_MODE_FLOAT' are the shared numbering's -- they have to be, the enum
   is the vocabulary every back end shares -- so their difference counts EVERY
   configured back end's float modes.  A back end wanting one bit per mode of a
   class wants its own count, which is what these two answer.  Measured at
   forty-seven bases: 10 float and 210 vector-float modes in the numbering
   against aarch64's own 5 and 55.

   `GET_CLASS_NARROWEST_MODE' just above is the same split for the same reason:
   the numbering is shared, the answer is per base.  A hole -- a mode this back
   end does not define -- reports 0xffff, because it is a mode of no class here
   and must not be handed back a usable index.  See genmodes.cc.  */

extern GCC_TARGET_TABLE (const unsigned short, mode_class_index,
		       NUM_MACHINE_MODES);
#define GET_MODE_CLASS_INDEX(MODE) ((unsigned int) mode_class_index[MODE])

extern GCC_TARGET_TABLE (const unsigned short, class_num_modes,
		       MAX_MODE_CLASS);
#define GET_CLASS_NUM_MODES(CLASS) ((unsigned int) class_num_modes[CLASS])

/* The narrowest full integer mode available on the target.  */

#define NARROWEST_INT_MODE \
  (scalar_int_mode \
   (scalar_int_mode::from_int (class_narrowest_mode[MODE_INT])))

/* Return the narrowest mode in T's class.  */

template<typename T>
inline T
get_narrowest_mode (T mode)
{
  return typename mode_traits<T>::from_int
    (class_narrowest_mode[GET_MODE_CLASS (mode)]);
}

/* Define the integer modes whose sizes are BITS_PER_UNIT and BITS_PER_WORD
   and the mode whose class is Pmode and whose size is POINTER_SIZE.  */

extern scalar_int_mode byte_mode;
extern scalar_int_mode word_mode;
extern scalar_int_mode ptr_mode;

/* Target-dependent machine mode initialization - in insn-modes.cc.  */
extern void init_adjust_machine_modes (void);

#define TRULY_NOOP_TRUNCATION_MODES_P(MODE1, MODE2) \
  (targetm.truly_noop_truncation (GET_MODE_PRECISION (MODE1), \
				  GET_MODE_PRECISION (MODE2)))

/* Return true if MODE is a scalar integer mode that fits in a
   HOST_WIDE_INT.  */

inline bool
HWI_COMPUTABLE_MODE_P (machine_mode mode)
{
  machine_mode mme = mode;
  return (SCALAR_INT_MODE_P (mme)
	  && mode_to_precision (mme).coeffs[0] <= HOST_BITS_PER_WIDE_INT);
}

inline bool
HWI_COMPUTABLE_MODE_P (scalar_int_mode mode)
{
  return GET_MODE_PRECISION (mode) <= HOST_BITS_PER_WIDE_INT;
}

struct int_n_data_t {
  /* These parts are initialized by genmodes output */
  unsigned int bitsize;
  scalar_int_mode_pod m;
  /* RID_* is RID_INTN_BASE + index into this array */
};

/* This is also in tree.h.  genmodes.cc guarantees the're sorted from
   smallest bitsize to largest bitsize.

   THE BOUND IS THE UNION'S AND THE COUNT IS THE SELECTED BASE'S, and they are
   different numbers here: 45 of 47 back ends have one __intN (TI 128) while
   avr has two (PSI 24, TI 128) and msp430 two (PSI 20, TI 128), so the shared
   numbering counts three and no back end has more than two.

   `int_n_enabled_p' is STORAGE in tree.cc, a shared translation unit, so its
   bound must be one number for the whole compiler -- the union's -- exactly
   like every other MULTI_TARGET_UNION_* layout on this branch.  `int_n_data'
   is a per-back-end table selected at run time, so the SIZE argument is not
   used on a multi-target build at all (GCC_TARGET_TABLE makes it a pointer);
   it is spelled with the same name so the single-target build, where the two
   numbers coincide, gets the array it always had.

   Neither of them is the bound for a LOOP.  See MT_NUM_INT_N_ENTS below.  */
extern bool int_n_enabled_p[MULTI_TARGET_UNION_NUM_INT_N_ENTS];
extern GCC_TARGET_TABLE (const int_n_data_t, int_n_data,
			 MULTI_TARGET_UNION_NUM_INT_N_ENTS);

/* HOW MANY __intN ENTRIES THE SELECTED BACK END ACTUALLY HAS.

   Spelled differently from NUM_INT_N_ENTS on purpose, the same way
   target-regs.h spells MT_N_REG_CLASSES apart from N_REG_CLASSES: a site that
   wants "how many are there really" says so, and a site that wants "how big
   is the array" says that.  Making one name mean both is what left avr's and
   msp430's second entry unregistered -- every shared registration loop was
   bounded by the PRIMARY's 1 -- while avr.cc, compiled against its own
   header, looped to 2 over a one-element `int_n_trees'.

   `num_int_n_ents' is defined by genmodes beside `int_n_data' and installed
   with it by multi-target-select.cc, so the count cannot drift from the table
   it counts.  In a single-target build it is that build's own number, i.e.
   NUM_INT_N_ENTS, and every use site keeps one spelling.  */
#define MT_NUM_INT_N_ENTS num_int_n_ents

/* Return true if MODE has class MODE_INT, storing it as a scalar_int_mode
   in *INT_MODE if so.  */

template<typename T>
inline bool
is_int_mode (machine_mode mode, T *int_mode)
{
  if (GET_MODE_CLASS (mode) == MODE_INT)
    {
      *int_mode = scalar_int_mode (scalar_int_mode::from_int (mode));
      return true;
    }
  return false;
}

/* Return true if MODE has class MODE_FLOAT, storing it as a
   scalar_float_mode in *FLOAT_MODE if so.  */

template<typename T>
inline bool
is_float_mode (machine_mode mode, T *float_mode)
{
  if (GET_MODE_CLASS (mode) == MODE_FLOAT)
    {
      *float_mode = scalar_float_mode (scalar_float_mode::from_int (mode));
      return true;
    }
  return false;
}

/* Return true if MODE has class MODE_COMPLEX_INT, storing it as
   a complex_mode in *CMODE if so.  */

template<typename T>
inline bool
is_complex_int_mode (machine_mode mode, T *cmode)
{
  if (GET_MODE_CLASS (mode) == MODE_COMPLEX_INT)
    {
      *cmode = complex_mode (complex_mode::from_int (mode));
      return true;
    }
  return false;
}

/* Return true if MODE has class MODE_COMPLEX_FLOAT, storing it as
   a complex_mode in *CMODE if so.  */

template<typename T>
inline bool
is_complex_float_mode (machine_mode mode, T *cmode)
{
  if (GET_MODE_CLASS (mode) == MODE_COMPLEX_FLOAT)
    {
      *cmode = complex_mode (complex_mode::from_int (mode));
      return true;
    }
  return false;
}

/* Return true if MODE is a scalar integer mode with a precision
   smaller than LIMIT's precision.  */

inline bool
is_narrower_int_mode (machine_mode mode, scalar_int_mode limit)
{
  scalar_int_mode int_mode;
  return (is_a <scalar_int_mode> (mode, &int_mode)
	  && GET_MODE_PRECISION (int_mode) < GET_MODE_PRECISION (limit));
}

namespace mode_iterator
{
  /* Start mode iterator *ITER at the first mode in class MCLASS, if any.  */

  template<typename T>
  inline void
  start (opt_mode<T> *iter, enum mode_class mclass)
  {
    if (GET_CLASS_NARROWEST_MODE (mclass) == E_VOIDmode)
      *iter = opt_mode<T> ();
    else
      *iter = as_a<T> (GET_CLASS_NARROWEST_MODE (mclass));
  }

  inline void
  start (machine_mode *iter, enum mode_class mclass)
  {
    *iter = GET_CLASS_NARROWEST_MODE (mclass);
  }

  /* Return true if mode iterator *ITER has not reached the end.  */

  template<typename T>
  inline bool
  iterate_p (opt_mode<T> *iter)
  {
    return iter->exists ();
  }

  inline bool
  iterate_p (machine_mode *iter)
  {
    return *iter != E_VOIDmode;
  }

  /* Set mode iterator *ITER to the next mode in the same class,
     if any.  */

  template<typename T>
  inline void
  get_next (opt_mode<T> *iter)
  {
    *iter = GET_MODE_NEXT_MODE (iter->require ());
  }

  inline void
  get_next (machine_mode *iter)
  {
    *iter = GET_MODE_NEXT_MODE (*iter).else_void ();
  }

  /* Set mode iterator *ITER to the next mode in the same class.
     Such a mode is known to exist.  */

  template<typename T>
  inline void
  get_known_next (T *iter)
  {
    *iter = GET_MODE_NEXT_MODE (*iter).require ();
  }

  /* Set mode iterator *ITER to the next wider mode in the same class,
     if any.  */

  template<typename T>
  inline void
  get_wider (opt_mode<T> *iter)
  {
    *iter = GET_MODE_WIDER_MODE (iter->require ());
  }

  inline void
  get_wider (machine_mode *iter)
  {
    *iter = GET_MODE_WIDER_MODE (*iter).else_void ();
  }

  /* Set mode iterator *ITER to the next wider mode in the same class.
     Such a mode is known to exist.  */

  template<typename T>
  inline void
  get_known_wider (T *iter)
  {
    *iter = GET_MODE_WIDER_MODE (*iter).require ();
  }

  /* Set mode iterator *ITER to the mode that is two times wider than the
     current one, if such a mode exists.  */

  template<typename T>
  inline void
  get_2xwider (opt_mode<T> *iter)
  {
    *iter = GET_MODE_2XWIDER_MODE (iter->require ());
  }

  inline void
  get_2xwider (machine_mode *iter)
  {
    *iter = GET_MODE_2XWIDER_MODE (*iter).else_void ();
  }
}

/* Make ITERATOR iterate over all the modes in mode class CLASS,
   from narrowest to widest.  */
#define FOR_EACH_MODE_IN_CLASS(ITERATOR, CLASS)  \
  for (mode_iterator::start (&(ITERATOR), CLASS); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_next (&(ITERATOR)))

/* Make ITERATOR iterate over all the modes in the range [START, END),
   in order of increasing width.  */
#define FOR_EACH_MODE(ITERATOR, START, END) \
  for ((ITERATOR) = (START); \
       (ITERATOR) != (END); \
       mode_iterator::get_known_next (&(ITERATOR)))

/* Make ITERATOR iterate over START and all non-narrower modes in the same
   class, in order of increasing width.  */
#define FOR_EACH_MODE_FROM(ITERATOR, START) \
  for ((ITERATOR) = (START); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_next (&(ITERATOR)))

/* Make ITERATOR iterate over START and all wider modes in the same
   class, in order of strictly increasing width.  */
#define FOR_EACH_WIDER_MODE_FROM(ITERATOR, START) \
  for ((ITERATOR) = (START); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_wider (&(ITERATOR)))

/* Make ITERATOR iterate over modes in the range [NARROWEST, END)
   in order of increasing width, where NARROWEST is the narrowest mode
   in END's class.  */
#define FOR_EACH_MODE_UNTIL(ITERATOR, END) \
  FOR_EACH_MODE (ITERATOR, get_narrowest_mode (END), END)

/* Make ITERATOR iterate over modes in the same class as MODE, in order
   of non-decreasing width.  Start at next such mode after START,
   or don't iterate at all if there is no such mode.  */
#define FOR_EACH_NEXT_MODE(ITERATOR, START) \
  for ((ITERATOR) = (START), mode_iterator::get_next (&(ITERATOR)); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_next (&(ITERATOR)))

/* Make ITERATOR iterate over modes in the same class as MODE, in order
   of increasing width.  Start at the first mode wider than START,
   or don't iterate at all if there is no wider mode.  */
#define FOR_EACH_WIDER_MODE(ITERATOR, START) \
  for ((ITERATOR) = (START), mode_iterator::get_wider (&(ITERATOR)); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_wider (&(ITERATOR)))

/* Make ITERATOR iterate over modes in the same class as MODE, in order
   of increasing width, and with each mode being twice the width of the
   previous mode.  Start at the mode that is two times wider than START,
   or don't iterate at all if there is no such mode.  */
#define FOR_EACH_2XWIDER_MODE(ITERATOR, START) \
  for ((ITERATOR) = (START), mode_iterator::get_2xwider (&(ITERATOR)); \
       mode_iterator::iterate_p (&(ITERATOR)); \
       mode_iterator::get_2xwider (&(ITERATOR)))

template<typename T>
void
gt_ggc_mx (pod_mode<T> *)
{
}

template<typename T>
void
gt_pch_nx (pod_mode<T> *)
{
}

template<typename T>
void
gt_pch_nx (pod_mode<T> *, gt_pointer_operator, void *)
{
}

/* THE WIDEST INTEGER MODE THE SELECTED BACK END ACTUALLY HAS.

   `MAX_MODE_INT' is not that.  It is an enumerator in the SINGULAR
   insn-modes.h, whose mode vocabulary is unioned over every configured back
   end, so it names the widest integer mode SOME back end has.  Shared code
   reads it as "the widest this one has" -- the `HAVE_V8HFmode' disguise in
   PRINCIPLES 3, where the UNION's answer leaks rather than the primary's.

   Measured on a four-back-end cc1 (i386, aarch64, rs6000, s390) compiling
   `int f (int a, int b) { return a + b * 3; }' for s390x:

     expr.cc:936     `oldmode = MAX_MODE_INT' for a CONST_INT of unknown mode
     MAX_MODE_INT    E_XImode -- i386's 64-byte AVX-512 integer mode
     s390            has no XImode, so it is a HOLE: class MODE_RANDOM,
		     precision 0
     rtl.h:2326      `as_a <scalar_mode> (E_XImode)' -> hard abort

   `internal compiler error: in as_a, at machmode.h:416', during RTL expand,
   for powerpc64le and s390x and for NEITHER of the two bases every
   measurement on this branch has been taken with.

   The walk down from MAX_MODE_INT is the idiom expmed.cc:226 already uses and
   documents for the same constant -- skip the holes, because the class now
   correctly says "absent" for them.  Asking `mode_class' is asking THE
   SELECTED BASE, since it is one of the per-base tables multi_target_select
   installs, so the answer is this back end's own and not another's.

   On a single-target build there are no holes, the loop exits on its first
   iteration, and this is MAX_MODE_INT by another name.  */

inline scalar_int_mode
widest_int_mode_for_target (void)
{
  for (int m = (int) MAX_MODE_INT; m >= (int) MIN_MODE_INT; m--)
    if (is_a <scalar_int_mode> ((machine_mode) m))
      return as_a <scalar_int_mode> ((machine_mode) m);
  /* Not floored: a back end with NO integer mode at all is not a thing that
     can be compiled for, and answering QImode here would be inventing one.  */
  gcc_unreachable ();
}

#endif /* not HAVE_MACHINE_MODES */
