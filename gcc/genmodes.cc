/* Generate the machine mode enumeration and associated tables.
   Copyright (C) 2003-2026 Free Software Foundation, Inc.

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

#include "bconfig.h"
#include "system.h"
#include "errors.h"

/* enum mode_class is normally defined by machmode.h but we can't
   include that header here.  */
#include "mode-classes.def"

#define DEF_MODE_CLASS(M) M
enum mode_class { MODE_CLASSES, MAX_MODE_CLASS };
#undef DEF_MODE_CLASS

/* Text names of mode classes, for output.  */
#define DEF_MODE_CLASS(M) #M
static const char *const mode_class_names[MAX_MODE_CLASS] =
{
  MODE_CLASSES
};
#undef DEF_MODE_CLASS
#undef MODE_CLASSES

/* Multi-target: one build tree serves many back ends, so which extra modes
   file to compile in cannot be settled at configure time.  bconfig.h names
   the configured target's; -DTARGET_EXTRA_MODES_FILE on the command line
   overrides it, which is how the per-back-end copies of this program are
   built.  TARGET_NO_EXTRA_MODES says the back end has no such file at all,
   which is not the same as leaving both undefined -- that would silently
   fall back to the configured target's modes.  */
#ifdef TARGET_NO_EXTRA_MODES
# undef EXTRA_MODES_FILE
#elif defined (TARGET_EXTRA_MODES_FILE)
# undef EXTRA_MODES_FILE
# define EXTRA_MODES_FILE TARGET_EXTRA_MODES_FILE
#endif

#ifdef EXTRA_MODES_FILE
# define HAVE_EXTRA_MODES 1
#else
# define HAVE_EXTRA_MODES 0
# define EXTRA_MODES_FILE ""
#endif

/* Data structure for building up what we know about a mode.
   They're clustered by mode class.  */
struct mode_data
{
  struct mode_data *next;	/* next this class - arbitrary order */

  const char *name;		/* printable mode name -- SI, not SImode */
  enum mode_class cl;		/* this mode class */
  unsigned int order;		/* top-level sorting order */
  unsigned int precision;	/* size in bits, equiv to TYPE_PRECISION */
  unsigned int bytesize;	/* storage size in addressable units */
  unsigned int ncomponents;	/* number of subunits */
  unsigned int alignment;	/* mode alignment */
  const char *format;		/* floating point format - float modes only */

  struct mode_data *component;	/* mode of components */
  struct mode_data *wider;	/* next wider mode */

  struct mode_data *contained;  /* Pointer to list of modes that have
				   this mode as a component.  */
  struct mode_data *next_cont;  /* Next mode in that list.  */

  struct mode_data *complex;	/* complex type with mode as component.  */
  const char *file;		/* file and line of definition, */
  unsigned int line;		/* for error reporting */
  unsigned int counter;		/* Rank ordering of modes */
  unsigned int ibit;		/* the number of integral bits */
  unsigned int fbit;		/* the number of fractional bits */
  bool need_nunits_adj;		/* true if this mode needs dynamic nunits
				   adjustment */
  bool need_bytesize_adj;	/* true if this mode needs dynamic size
				   adjustment */
  unsigned int int_n;		/* If nonzero, then __int<INT_N> will be defined */
  bool boolean;
  bool numbered;		/* Shared numbering: this mode was given an
				   ordinal by the shared numbering.  */
  bool is_hole;			/* Union numbering: no back end reachable from
				   this run defines this mode.  The record
				   exists only to occupy the ordinal that the
				   shared enum gave it.  */
  const char *bare;		/* Namespaced modes: the UNQUALIFIED spelling.
				   `name' is the numbering key and the enum
				   name and has to be unique; `bare' is what
				   `GET_MODE_NAME' answers and what the back
				   end's own sources write.  Equal for every
				   mode that does not collide.  */
  const char *arch;		/* Union run: the back end whose modes file
				   defined this mode, or null for a mode
				   `machmode.def' defines for everybody.  */
};

static struct mode_data *modes[MAX_MODE_CLASS];
static unsigned int n_modes[MAX_MODE_CLASS];
static struct mode_data *void_mode;

static const struct mode_data blank_mode = {
  0, "<unknown>", MAX_MODE_CLASS,
  0, -1U, -1U, -1U, -1U,
  0, 0, 0, 0, 0, 0,
  "<unknown>", 0, 0, 0, 0, false, false, 0,
  false, false, false, 0, 0
};

static htab_t modes_by_name;

/* Union run: the back end whose modes file is being read right now.  The
   generated union input announces it before each `#include'; see
   `union_note_arch'.  Null while `machmode.def' itself is being read, which
   is exactly the distinction that decides whether a mode may be qualified:
   `SImode' is shared vocabulary and must mean one thing everywhere, `PSI'
   is one back end's and need not.  */
static const char *union_cur_arch ATTRIBUTE_UNUSED;

/* Data structure for recording target-specified runtime adjustments
   to a particular mode.  We support varying the byte size, the
   alignment, and the floating point format.  */
struct mode_adjust
{
  struct mode_adjust *next;
  struct mode_data *mode;
  const char *adjustment;

  const char *file;
  unsigned int line;
};

static struct mode_adjust *adj_nunits;
static struct mode_adjust *adj_bytesize;
static struct mode_adjust *adj_alignment;
static struct mode_adjust *adj_format;
static struct mode_adjust *adj_ibit;
static struct mode_adjust *adj_fbit;
static struct mode_adjust *adj_precision;

/* Mode class operations.  */
static enum mode_class
complex_class (enum mode_class c)
{
  switch (c)
    {
    case MODE_INT: return MODE_COMPLEX_INT;
    case MODE_PARTIAL_INT: return MODE_COMPLEX_INT;
    case MODE_FLOAT: return MODE_COMPLEX_FLOAT;
    default:
      error ("no complex class for class %s", mode_class_names[c]);
      return MODE_RANDOM;
    }
}

static enum mode_class
vector_class (enum mode_class cl)
{
  switch (cl)
    {
    case MODE_INT: return MODE_VECTOR_INT;
    case MODE_FLOAT: return MODE_VECTOR_FLOAT;
    case MODE_FRACT: return MODE_VECTOR_FRACT;
    case MODE_UFRACT: return MODE_VECTOR_UFRACT;
    case MODE_ACCUM: return MODE_VECTOR_ACCUM;
    case MODE_UACCUM: return MODE_VECTOR_UACCUM;
    default:
      error ("no vector class for class %s", mode_class_names[cl]);
      return MODE_RANDOM;
    }
}

/* Utility routines.  */
static inline struct mode_data *
find_mode_key (const char *key_name)
{
  struct mode_data key;

  key.name = key_name;
  return (struct mode_data *) htab_find (modes_by_name, &key);
}

static inline struct mode_data *
find_mode (const char *name)
{
#ifdef GENMODES_UNION
  /* Inside a back end's own modes file, a bare name means THAT back end's
     mode.  `INT_N (PSI, 24)' in `avr-modes.def' must reach avr's PSI even
     though the name is now qualified, or the qualification would silently
     redirect the back end's own references to another back end's mode --
     which is the bug this exists to prevent, arriving through the fix.  */
  if (union_cur_arch)
    {
      char *q = concat (union_cur_arch, "_", name, NULL);
      struct mode_data *m = find_mode_key (q);
      free (q);
      if (m)
	return m;
    }
#endif
  return find_mode_key (name);
}

static struct mode_data *
new_mode (enum mode_class cl, const char *name,
	  const char *file, unsigned int line)
{
  struct mode_data *m;
  static unsigned int count = 0;

  m = find_mode (name);
  if (m)
    {
#ifdef GENMODES_UNION
      /* Union run: one enum for every back end at once, so the same mode
	 name arriving from several `*-modes.def' files is the normal case
	 -- `TFmode' and `V2SImode' are each defined by a dozen of them.
	 They agree on the only thing the enum records, which is the name
	 and the class, and they are one entry in the vocabulary.

	 Size, precision and format do NOT have to agree, and often do not
	 (`XFmode' is 12 bytes on i386 and 16 on ia64, `SFmode' is VAX F
	 format on vax and IEEE elsewhere).  Those live in the per-back-end
	 tables, so the first definition's numbers are simply discarded
	 along with the rest of the duplicate record.

	 The class is different: it decides which contiguous run of the
	 enum the mode lands in, and `MIN_MODE_<CLASS>'/`MAX_MODE_<CLASS>'
	 are that run's endpoints.  A name that is two classes cannot be
	 one entry, so that is the one disagreement worth a diagnostic.  */
      if (m->cl != cl)
	{
	  /* Two back ends, one name, two classes.  `PSI' is MODE_INT in avr
	     (24-bit) and MODE_PARTIAL_INT in msp430 (20-bit).  The class
	     decides which contiguous run of the enum a mode lands in and
	     `MIN_MODE_<CLASS>'/`MAX_MODE_<CLASS>' are that run's endpoints,
	     so one entry cannot serve both.

	     Neither is wrong and neither gets renamed: the name is
	     arch-specific, and only the flat numbering forced them together.
	     Give each its own ordinal under a qualified KEY and leave
	     `bare' -- what `GET_MODE_NAME' answers -- alone.  That is what
	     keeps `optabs-libfuncs.cc' building `__mulpsi3' from `psi' and
	     keeps every libgcc symbol where it is.

	     Only a mode a back end's own file defines may be qualified.  A
	     name from `machmode.def' is shared vocabulary; `SImode' meaning
	     one thing everywhere is the entire point of the union, so a
	     class disagreement there is still an error.  */
	  if (!union_cur_arch || !m->arch)
	    {
	      error ("%s:%d: mode \"%s\" is %s here but %s at %s:%d",
		     trim_filename (file), line, name, mode_class_names[cl],
		     mode_class_names[m->cl], m->file, m->line);
	      return m;
	    }

	  /* The FIRST claimant was registered under the bare name before
	     anyone knew it collided.  Retro-qualify it too, so that neither
	     back end silently keeps the unqualified ordinal -- a first-wins
	     asymmetry here would be invisible and would decide which back end
	     `__attribute__((mode(PSI)))' resolves to.  */
	  if (!strcmp (m->name, m->bare))
	    {
	      htab_remove_elt (modes_by_name, m);
	      m->name = concat (m->arch, "_", m->bare, NULL);
	      *htab_find_slot (modes_by_name, m, INSERT) = m;
	    }

	  {
	    char *q = concat (union_cur_arch, "_", name, NULL);
	    struct mode_data *n = new_mode (cl, q, file, line);
	    n->bare = name;
	    return n;
	  }
	}

      /* Hand back a throwaway copy.  The caller is about to fill in the
	 duplicate's precision, component and so on; letting it write
	 through to the retained record would make the last back end read
	 win, silently.  */
      {
	struct mode_data *scratch = XNEW (struct mode_data);
	memcpy (scratch, m, sizeof (struct mode_data));
	return scratch;
      }
#else
      error ("%s:%d: duplicate definition of mode \"%s\"",
	     trim_filename (file), line, name);
      error ("%s:%d: previous definition here", m->file, m->line);
      return m;
#endif
    }

  m = XNEW (struct mode_data);
  memcpy (m, &blank_mode, sizeof (struct mode_data));
  m->cl = cl;
  m->name = name;
  m->bare = name;
#ifdef GENMODES_UNION
  m->arch = union_cur_arch;
#endif
  if (file)
    m->file = trim_filename (file);
  m->line = line;
  m->counter = count++;

  m->next = modes[cl];
  modes[cl] = m;
  n_modes[cl]++;

  *htab_find_slot (modes_by_name, m, INSERT) = m;

  return m;
}

/* Make a mode DERIVED from M -- its complex, its vectors.  If M is
   qualified its derivatives must be too: avr's and msp430's PSI both derive
   a complex named `CPSI', and letting those merge would hand one back end
   the other's precision under a name they agree on.  This is also the hook
   that covers the four SIZE-only collisions (`XF', `XC', `V4BI', `V8BI')
   when the tables unify at M3, without a redesign.  */
static struct mode_data *
new_derived_mode (enum mode_class cl, struct mode_data *m ATTRIBUTE_UNUSED,
		  const char *name, const char *file, unsigned int line)
{
  struct mode_data *c;
#ifdef GENMODES_UNION
  if (m->arch && strcmp (m->name, m->bare))
    {
      c = new_mode (cl, concat (m->arch, "_", name, NULL), file, line);
      c->bare = xstrdup (name);
      /* `union_cur_arch' is already back to null by the time `machmode.def'
	 derives complex and vector modes, so a derivative has to inherit the
	 attribution from its component rather than read the cursor.  */
      c->arch = m->arch;
      return c;
    }
#endif
  c = new_mode (cl, xstrdup (name), file, line);
  return c;
}

static hashval_t
hash_mode (const void *p)
{
  const struct mode_data *m = (const struct mode_data *)p;
  return htab_hash_string (m->name);
}

static int
eq_mode (const void *p, const void *q)
{
  const struct mode_data *a = (const struct mode_data *)p;
  const struct mode_data *b = (const struct mode_data *)q;

  return !strcmp (a->name, b->name);
}

#define for_all_modes(C, M)			\
  for (C = 0; C < MAX_MODE_CLASS; C++)		\
    for (M = modes[C]; M; M = M->next)

static void ATTRIBUTE_UNUSED
new_adjust (const char *name,
	    struct mode_adjust **category, const char *catname,
	    const char *adjustment,
	    enum mode_class required_class_from,
	    enum mode_class required_class_to,
	    const char *file, unsigned int line)
{
  struct mode_data *mode = find_mode (name);
  struct mode_adjust *a;

  file = trim_filename (file);

  if (!mode)
    {
      error ("%s:%d: no mode \"%s\"", file, line, name);
      return;
    }

  if (required_class_from != MODE_RANDOM
      && (mode->cl < required_class_from || mode->cl > required_class_to))
    {
      error ("%s:%d: mode \"%s\" is not among class {%s, %s}",
	     file, line, name, mode_class_names[required_class_from] + 5,
	     mode_class_names[required_class_to] + 5);
      return;
    }

  for (a = *category; a; a = a->next)
    if (a->mode == mode)
      {
#ifdef GENMODES_UNION
	/* Two back ends adjusting the same mode differently is expected --
	   the adjustment is per-back-end data and the union run emits no
	   data, only the enum.  Keep the first and say nothing.  */
	return;
#endif
	error ("%s:%d: mode \"%s\" already has a %s adjustment",
	       file, line, name, catname);
	error ("%s:%d: previous adjustment here", a->file, a->line);
	return;
      }

  a = XNEW (struct mode_adjust);
  a->mode = mode;
  a->adjustment = adjustment;
  a->file = file;
  a->line = line;

  a->next = *category;
  *category = a;
}

/* Diagnose failure to meet expectations in a partially filled out
   mode structure.  */
enum requirement { SET, UNSET, OPTIONAL };

#define validate_field_(mname, fname, req, val, unset, file, line) do {	\
  switch (req)								\
    {									\
    case SET:								\
      if (val == unset)							\
	error ("%s:%d: (%s) field %s must be set",			\
	       file, line, mname, fname);				\
      break;								\
    case UNSET:								\
      if (val != unset)							\
	error ("%s:%d: (%s) field %s must not be set",			\
	       file, line, mname, fname);				\
    case OPTIONAL:							\
      break;								\
    }									\
} while (0)

#define validate_field(M, F) \
  validate_field_(M->name, #F, r_##F, M->F, blank_mode.F, M->file, M->line)

static void
validate_mode (struct mode_data *m,
	       enum requirement r_precision,
	       enum requirement r_bytesize,
	       enum requirement r_component,
	       enum requirement r_ncomponents,
	       enum requirement r_format)
{
  validate_field (m, precision);
  validate_field (m, bytesize);
  validate_field (m, component);
  validate_field (m, ncomponents);
  validate_field (m, format);
}
#undef validate_field
#undef validate_field_

/* Given a partially-filled-out mode structure, figure out what we can
   and fill the rest of it in; die if it isn't enough.  */
static void
complete_mode (struct mode_data *m)
{
  unsigned int alignment;

  if (!m->name)
    {
      error ("%s:%d: mode with no name", m->file, m->line);
      return;
    }
  if (m->cl == MAX_MODE_CLASS)
    {
      error ("%s:%d: %smode has no mode class", m->file, m->line, m->name);
      return;
    }

  switch (m->cl)
    {
    case MODE_RANDOM:
      /* Nothing more need be said.  */
      if (!strcmp (m->name, "VOID"))
	void_mode = m;

      validate_mode (m, UNSET, UNSET, UNSET, UNSET, UNSET);

      m->precision = 0;
      m->bytesize = 0;
      m->ncomponents = 0;
      m->component = 0;
      break;

    case MODE_CC:
      /* Again, nothing more need be said.  For historical reasons,
	 the size of a CC mode is four units.  */
      validate_mode (m, UNSET, UNSET, UNSET, UNSET, UNSET);

      m->bytesize = 4;
      m->ncomponents = 1;
      m->component = 0;
      break;

    case MODE_INT:
    case MODE_FLOAT:
    case MODE_DECIMAL_FLOAT:
    case MODE_FRACT:
    case MODE_UFRACT:
    case MODE_ACCUM:
    case MODE_UACCUM:
      /* A scalar mode must have a byte size, may have a bit size,
	 and must not have components.   A float mode must have a
         format.  */
      validate_mode (m, OPTIONAL, SET, UNSET, UNSET,
		     (m->cl == MODE_FLOAT || m->cl == MODE_DECIMAL_FLOAT)
		     ? SET : UNSET);

      m->ncomponents = 1;
      m->component = 0;
      break;

    case MODE_OPAQUE:
      /* Opaque modes have size and precision.  */
      validate_mode (m, OPTIONAL, SET, UNSET, UNSET, UNSET);

      m->ncomponents = 1;
      m->component = 0;
      break;

    case MODE_PARTIAL_INT:
      /* A partial integer mode uses ->component to say what the
	 corresponding full-size integer mode is, and may also
	 specify a bit size.  */
      validate_mode (m, OPTIONAL, UNSET, SET, UNSET, UNSET);

      m->bytesize = m->component->bytesize;

      m->ncomponents = 1;
      break;

    case MODE_COMPLEX_INT:
    case MODE_COMPLEX_FLOAT:
      /* Complex modes should have a component indicated, but no more.  */
      validate_mode (m, UNSET, UNSET, SET, UNSET, UNSET);
      m->ncomponents = 2;
      if (m->component->precision != (unsigned int)-1)
	m->precision = 2 * m->component->precision;
      m->bytesize = 2 * m->component->bytesize;
      break;

    case MODE_VECTOR_BOOL:
      validate_mode (m, UNSET, SET, SET, SET, UNSET);
      break;

    case MODE_VECTOR_INT:
    case MODE_VECTOR_FLOAT:
    case MODE_VECTOR_FRACT:
    case MODE_VECTOR_UFRACT:
    case MODE_VECTOR_ACCUM:
    case MODE_VECTOR_UACCUM:
      /* Vector modes should have a component and a number of components.  */
      validate_mode (m, UNSET, UNSET, SET, SET, UNSET);
      if (m->component->precision != (unsigned int)-1)
	m->precision = m->ncomponents * m->component->precision;
      m->bytesize = m->ncomponents * m->component->bytesize;
      break;

    default:
      gcc_unreachable ();
    }

  /* If not already specified, the mode alignment defaults to the largest
     power of two that divides the size of the object.  Complex types are
     not more aligned than their contents.  */
  if (m->cl == MODE_COMPLEX_INT || m->cl == MODE_COMPLEX_FLOAT)
    alignment = m->component->bytesize;
  else
    alignment = m->bytesize;

  m->alignment = alignment & (~alignment + 1);

  /* If this mode has components, make the component mode point back
     to this mode, for the sake of adjustments.  */
  if (m->component)
    {
      m->next_cont = m->component->contained;
      m->component->contained = m;
    }
}

static void
complete_all_modes (void)
{
  struct mode_data *m;
  int cl;

  for_all_modes (cl, m)
    complete_mode (m);
}

/* For each mode in class CLASS, construct a corresponding complex mode.  */
#define COMPLEX_MODES(C) make_complex_modes (MODE_##C, __FILE__, __LINE__)
static void
make_complex_modes (enum mode_class cl,
		    const char *file, unsigned int line)
{
  struct mode_data *m;
  struct mode_data *c;
  enum mode_class cclass = complex_class (cl);

  if (cclass == MODE_RANDOM)
    return;

  for (m = modes[cl]; m; m = m->next)
    {
      char *p, *buf;
      size_t m_len;

      /* Skip BImode.  FIXME: BImode probably shouldn't be MODE_INT.  */
      if (m->boolean)
	continue;

      m_len = strlen (m->bare);
      /* The leading "1 +" is in case we prepend a "C" below.  */
      buf = (char *) xmalloc (1 + m_len + 1);

      /* Float complex modes are named SCmode, etc.
	 Int complex modes are named CSImode, etc.
         This inconsistency should be eliminated.  */
      p = 0;
      if (cl == MODE_FLOAT)
	{
	  memcpy (buf, m->bare, m_len + 1);
	  p = strchr (buf, 'F');
	  if (p == 0 && strchr (buf, 'D') == 0)
	    {
	      error ("%s:%d: float mode \"%s\" has no 'F' or 'D'",
		     m->file, m->line, m->name);
	      free (buf);
	      continue;
	    }
	}
      if (p != 0)
	*p = 'C';
      else
	{
	  buf[0] = 'C';
	  memcpy (buf + 1, m->bare, m_len + 1);
	}

      c = new_derived_mode (cclass, m, buf, file, line);
      c->component = m;
      m->complex = c;
    }
}

/* For all modes in class CL, construct vector modes of width WIDTH,
   having as many components as necessary.  ORDER is the sorting order
   of the mode, with smaller numbers indicating a higher priority.  */
#define VECTOR_MODES_WITH_PREFIX(PREFIX, C, W, ORDER) \
  make_vector_modes (MODE_##C, #PREFIX, W, ORDER, __FILE__, __LINE__)
#define VECTOR_MODES(C, W) VECTOR_MODES_WITH_PREFIX (V, C, W, 0)
static void ATTRIBUTE_UNUSED
make_vector_modes (enum mode_class cl, const char *prefix, unsigned int width,
		   unsigned int order, const char *file, unsigned int line)
{
  struct mode_data *m;
  struct mode_data *v;
  /* Big enough for a 32-bit UINT_MAX plus the text.  */
  char buf[12];
  unsigned int ncomponents;
  enum mode_class vclass = vector_class (cl);

  if (vclass == MODE_RANDOM)
    return;

  for (m = modes[cl]; m; m = m->next)
    {
      /* Do not construct vector modes with only one element, or
	 vector modes where the element size doesn't divide the full
	 size evenly.  */
      ncomponents = width / m->bytesize;
      if (ncomponents < 2)
	continue;
      if (width % m->bytesize)
	continue;

      /* Skip QFmode and BImode.  FIXME: this special case should
	 not be necessary.  */
      if (cl == MODE_FLOAT && m->bytesize == 1)
	continue;
      if (m->boolean)
	continue;

      if ((size_t) snprintf (buf, sizeof buf, "%s%u%s", prefix,
			     ncomponents, m->bare) >= sizeof buf)
	{
	  error ("%s:%d: mode name \"%s\" is too long",
		 m->file, m->line, m->name);
	  continue;
	}

      v = new_derived_mode (vclass, m, buf, file, line);
      v->order = order;
      v->component = m;
      v->ncomponents = ncomponents;
    }
}

/* Create a vector of booleans called NAME with COUNT elements and
   BYTESIZE bytes in total.  */
#define VECTOR_BOOL_MODE(NAME, COUNT, COMPONENT, BYTESIZE)		\
  make_vector_bool_mode (#NAME, COUNT, #COMPONENT, BYTESIZE,		\
			 __FILE__, __LINE__)
static void ATTRIBUTE_UNUSED
make_vector_bool_mode (const char *name, unsigned int count,
		       const char *component, unsigned int bytesize,
		       const char *file, unsigned int line)
{
  struct mode_data *m = find_mode (component);
  if (!m)
    {
      error ("%s:%d: no mode \"%s\"", file, line, component);
      return;
    }

  struct mode_data *v = new_mode (MODE_VECTOR_BOOL, name, file, line);
  v->component = m;
  v->ncomponents = count;
  v->bytesize = bytesize;
}

/* Input.  */

#define _SPECIAL_MODE(C, N) \
  make_special_mode (MODE_##C, #N, __FILE__, __LINE__)
#define RANDOM_MODE(N) _SPECIAL_MODE (RANDOM, N)
#define CC_MODE(N) _SPECIAL_MODE (CC, N)

static void
make_special_mode (enum mode_class cl, const char *name,
		   const char *file, unsigned int line)
{
  new_mode (cl, name, file, line);
}

#define INT_MODE(N, Y) FRACTIONAL_INT_MODE (N, -1U, Y)
#define FRACTIONAL_INT_MODE(N, B, Y) \
  make_int_mode (#N, B, Y, __FILE__, __LINE__)

static void
make_int_mode (const char *name,
	       unsigned int precision, unsigned int bytesize,
	       const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (MODE_INT, name, file, line);
  m->bytesize = bytesize;
  m->precision = precision;
}

#define BOOL_MODE(N, B, Y) \
  make_bool_mode (#N, B, Y, __FILE__, __LINE__)

static void
make_bool_mode (const char *name,
		unsigned int precision, unsigned int bytesize,
		const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (MODE_INT, name, file, line);
  m->bytesize = bytesize;
  m->precision = precision;
  m->boolean = true;
}

#define OPAQUE_MODE(N, B)			\
  make_opaque_mode (#N, -1U, B, __FILE__, __LINE__)

static void ATTRIBUTE_UNUSED
make_opaque_mode (const char *name,
		  unsigned int precision,
		  unsigned int bytesize,
		  const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (MODE_OPAQUE, name, file, line);
  m->bytesize = bytesize;
  m->precision = precision;
}

#define FRACT_MODE(N, Y, F) \
	make_fixed_point_mode (MODE_FRACT, #N, Y, 0, F, __FILE__, __LINE__)

#define UFRACT_MODE(N, Y, F) \
	make_fixed_point_mode (MODE_UFRACT, #N, Y, 0, F, __FILE__, __LINE__)

#define ACCUM_MODE(N, Y, I, F) \
	make_fixed_point_mode (MODE_ACCUM, #N, Y, I, F, __FILE__, __LINE__)

#define UACCUM_MODE(N, Y, I, F) \
	make_fixed_point_mode (MODE_UACCUM, #N, Y, I, F, __FILE__, __LINE__)

/* Create a fixed-point mode by setting CL, NAME, BYTESIZE, IBIT, FBIT,
   FILE, and LINE.  */

static void
make_fixed_point_mode (enum mode_class cl,
		       const char *name,
		       unsigned int bytesize,
		       unsigned int ibit,
		       unsigned int fbit,
		       const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (cl, name, file, line);
  m->bytesize = bytesize;
  m->ibit = ibit;
  m->fbit = fbit;
}

#define FLOAT_MODE(N, Y, F)             FRACTIONAL_FLOAT_MODE (N, -1U, Y, F)
#define FRACTIONAL_FLOAT_MODE(N, B, Y, F) \
  make_float_mode (#N, B, Y, #F, __FILE__, __LINE__)

static void
make_float_mode (const char *name,
		 unsigned int precision, unsigned int bytesize,
		 const char *format,
		 const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (MODE_FLOAT, name, file, line);
  m->bytesize = bytesize;
  m->precision = precision;
  m->format = format;
}

#define DECIMAL_FLOAT_MODE(N, Y, F)	\
	FRACTIONAL_DECIMAL_FLOAT_MODE (N, -1U, Y, F)
#define FRACTIONAL_DECIMAL_FLOAT_MODE(N, B, Y, F)	\
  make_decimal_float_mode (#N, B, Y, #F, __FILE__, __LINE__)

static void
make_decimal_float_mode (const char *name,
			 unsigned int precision, unsigned int bytesize,
			 const char *format,
			 const char *file, unsigned int line)
{
  struct mode_data *m = new_mode (MODE_DECIMAL_FLOAT, name, file, line);
  m->bytesize = bytesize;
  m->precision = precision;
  m->format = format;
}

#define RESET_FLOAT_FORMAT(N, F) \
  reset_float_format (#N, #F, __FILE__, __LINE__)
static void ATTRIBUTE_UNUSED
reset_float_format (const char *name, const char *format,
		    const char *file, unsigned int line)
{
  struct mode_data *m = find_mode (name);
  if (!m)
    {
      error ("%s:%d: no mode \"%s\"", file, line, name);
      return;
    }
  if (m->cl != MODE_FLOAT && m->cl != MODE_DECIMAL_FLOAT)
    {
      error ("%s:%d: mode \"%s\" is not a FLOAT class", file, line, name);
      return;
    }
  m->format = format;
}

/* __intN support.  */
#define INT_N(M,PREC)				\
  make_int_n (#M, PREC, __FILE__, __LINE__)
static void ATTRIBUTE_UNUSED
make_int_n (const char *m, int bitsize,
            const char *file, unsigned int line)
{
  struct mode_data *component = find_mode (m);
  if (!component)
    {
      error ("%s:%d: no mode \"%s\"", file, line, m);
      return;
    }
  if (component->cl != MODE_INT
      && component->cl != MODE_PARTIAL_INT)
    {
      error ("%s:%d: mode \"%s\" is not class INT or PARTIAL_INT", file, line, m);
      return;
    }
  if (component->int_n != 0)
    {
      error ("%s:%d: mode \"%s\" already has an intN", file, line, m);
      return;
    }

  component->int_n = bitsize;
}

/* Partial integer modes are specified by relation to a full integer
   mode.  */
#define PARTIAL_INT_MODE(M,PREC,NAME)				\
  make_partial_integer_mode (#M, #NAME, PREC, __FILE__, __LINE__)
static void ATTRIBUTE_UNUSED
make_partial_integer_mode (const char *base, const char *name,
			   unsigned int precision,
			   const char *file, unsigned int line)
{
  struct mode_data *m;
  struct mode_data *component = find_mode (base);
  if (!component)
    {
      error ("%s:%d: no mode \"%s\"", file, line, name);
      return;
    }
  if (component->cl != MODE_INT)
    {
      error ("%s:%d: mode \"%s\" is not class INT", file, line, name);
      return;
    }

  m = new_mode (MODE_PARTIAL_INT, name, file, line);
  m->precision = precision;
  m->component = component;
}

/* A single vector mode can be specified by naming its component
   mode and the number of components.  */
#define VECTOR_MODE_WITH_PREFIX(PREFIX, C, M, N, ORDER) \
  make_vector_mode (MODE_##C, #PREFIX, #M, N, ORDER, __FILE__, __LINE__);
#define VECTOR_MODE(C, M, N) VECTOR_MODE_WITH_PREFIX(V, C, M, N, 0);
static void ATTRIBUTE_UNUSED
make_vector_mode (enum mode_class bclass,
		  const char *prefix,
		  const char *base,
		  unsigned int ncomponents,
		  unsigned int order,
		  const char *file, unsigned int line)
{
  struct mode_data *v;
  enum mode_class vclass = vector_class (bclass);
  struct mode_data *component = find_mode (base);
  char namebuf[16];

  if (vclass == MODE_RANDOM)
    return;
  if (component == 0)
    {
      error ("%s:%d: no mode \"%s\"", file, line, base);
      return;
    }
  if (component->cl != bclass
      && (component->cl != MODE_PARTIAL_INT
	  || bclass != MODE_INT))
    {
      error ("%s:%d: mode \"%s\" is not class %s",
	     file, line, base, mode_class_names[bclass] + 5);
      return;
    }

  if ((size_t)snprintf (namebuf, sizeof namebuf, "%s%u%s", prefix,
			ncomponents, base) >= sizeof namebuf)
    {
      error ("%s:%d: mode name \"%s\" is too long",
	     file, line, base);
      return;
    }

  v = new_mode (vclass, xstrdup (namebuf), file, line);
  v->order = order;
  v->ncomponents = ncomponents;
  v->component = component;
}

/* Adjustability.  */
#define _ADD_ADJUST(A, M, X, C1, C2) \
  new_adjust (#M, &adj_##A, #A, #X, MODE_##C1, MODE_##C2, __FILE__, __LINE__)

#define ADJUST_NUNITS(M, X)    _ADD_ADJUST (nunits, M, X, RANDOM, RANDOM)
#define ADJUST_BYTESIZE(M, X)  _ADD_ADJUST (bytesize, M, X, RANDOM, RANDOM)
#define ADJUST_ALIGNMENT(M, X) _ADD_ADJUST (alignment, M, X, RANDOM, RANDOM)
#define ADJUST_PRECISION(M, X) _ADD_ADJUST (precision, M, X, RANDOM, RANDOM)
#define ADJUST_FLOAT_FORMAT(M, X)    _ADD_ADJUST (format, M, X, FLOAT, FLOAT)
#define ADJUST_IBIT(M, X)  _ADD_ADJUST (ibit, M, X, ACCUM, UACCUM)
#define ADJUST_FBIT(M, X)  _ADD_ADJUST (fbit, M, X, FRACT, UACCUM)

static int bits_per_unit;
static int max_bitsize_mode_any_int;
static int max_bitsize_mode_any_mode;

#ifdef GENMODES_UNION
/* `MAX_BITSIZE_MODE_ANY_INT' and `MAX_BITSIZE_MODE_ANY_MODE' are plain
   `#define's in the back ends that raise them, so reading them once after
   including 45 modes files gives whichever file came last, not the largest.
   That happens to be right today only because riscv's 32768 follows
   aarch64's 8192 in alphabetical order, with a `-Wmacro-redefined' warning
   as the sole evidence.  Nothing may depend on that.

   The union input file must therefore, after each `#include', pass the
   current values here and `#undef' them, so that each file is read on its
   own and the largest wins:

	#include "config/aarch64/aarch64-modes.def"
	#ifdef MAX_BITSIZE_MODE_ANY_INT
	  union_note_max_bitsize (MAX_BITSIZE_MODE_ANY_INT, 0);
	  #undef MAX_BITSIZE_MODE_ANY_INT
	#endif
	...

   A file that fails to report leaves the maximum to be computed from the
   modes themselves, which is a lower bound -- the back ends that set these
   explicitly do so precisely because their widest mode is not a bound (a
   riscv RVV vector has no compile-time size).  */
static int union_max_any_int;
static int union_max_any_mode;

/* The generated union input announces each back end before including its
   modes file, so that a name defined there can be attributed to it.  The
   attribution is what makes qualification TARGETED: only a name two back
   ends define, and disagree about, is qualified.  The 123 names they define
   and AGREE about -- `V4SI' across twelve back ends, `TF' across twelve --
   stay one ordinal, which is the compression the union exists for.  */
static void ATTRIBUTE_UNUSED
union_note_arch (const char *arch)
{
  union_cur_arch = arch;
}

static void ATTRIBUTE_UNUSED
union_note_max_bitsize (int any_int, int any_mode)
{
  if (any_int > union_max_any_int)
    union_max_any_int = any_int;
  if (any_mode > union_max_any_mode)
    union_max_any_mode = any_mode;
}
#endif

static void
create_modes (void)
{
#include "machmode.def"

  /* So put the default value unless the target needs a non standard
     value. */
#ifdef BITS_PER_UNIT
  bits_per_unit = BITS_PER_UNIT;
#else
  bits_per_unit = 8;
#endif

#ifdef GENMODES_UNION
  /* Whatever survived to here is one arbitrary file's value; the running
     maxima above are the answer.  Zero means nobody reported, and
     `emit_max_int' then computes a bound from the modes.  */
  max_bitsize_mode_any_int = union_max_any_int;
  max_bitsize_mode_any_mode = union_max_any_mode;
#else

#ifdef MAX_BITSIZE_MODE_ANY_INT
  max_bitsize_mode_any_int = MAX_BITSIZE_MODE_ANY_INT;
#else
  max_bitsize_mode_any_int = 0;
#endif

#ifdef MAX_BITSIZE_MODE_ANY_MODE
  max_bitsize_mode_any_mode = MAX_BITSIZE_MODE_ANY_MODE;
#else
  max_bitsize_mode_any_mode = 0;
#endif

#endif
}

/* MAX_BITSIZE_MODE_ANY_INT / _ANY_MODE, IN BITS, AS THIS RUN'S MODES SAY.

   Either the back end stated the number outright (`max_bitsize_mode_any_*'
   is then non-zero and already in bits), or it is computed as the widest
   mode this run knows about.  Split out of `emit_max_int' because the union
   run has to write the same numbers into the shared numbering, and computing
   them twice is how one name acquires two authorities.  */
static int
resolve_max_any_int (void)
{
  unsigned int max, mmax;
  struct mode_data *i;

  if (max_bitsize_mode_any_int)
    return max_bitsize_mode_any_int;

  for (max = 1, i = modes[MODE_INT]; i; i = i->next)
    if (max < i->bytesize)
      max = i->bytesize;
  mmax = max;
  for (max = 1, i = modes[MODE_PARTIAL_INT]; i; i = i->next)
    if (max < i->bytesize)
      max = i->bytesize;
  if (max > mmax)
    mmax = max;
  return (int) mmax * bits_per_unit;
}

static int
resolve_max_any_mode (void)
{
  unsigned int mmax = 0;
  struct mode_data *i;
  int j;

  if (max_bitsize_mode_any_mode)
    return max_bitsize_mode_any_mode;

  for (j = 0; j < MAX_MODE_CLASS; j++)
    for (i = modes[j]; i; i = i->next)
      if (mmax < i->bytesize)
	mmax = i->bytesize;
  return (int) mmax * bits_per_unit;
}

#ifndef NUM_POLY_INT_COEFFS
#define NUM_POLY_INT_COEFFS 1
#endif

/* Processing.  */

/* Sort a list of modes into the order needed for the WIDER field:
   major sort by precision, minor sort by component precision.

   For instance:
     QI < HI < SI < DI < TI
     V4QI < V2HI < V8QI < V4HI < V2SI.

   If the precision is not set, sort by the bytesize.  A mode with
   precision set gets sorted before a mode without precision set, if
   they have the same bytesize; this is the right thing because
   the precision must always be smaller than the bytesize * BITS_PER_UNIT.
   We don't have to do anything special to get this done -- an unset
   precision shows up as (unsigned int)-1, i.e. UINT_MAX.  */
static int
cmp_modes (const void *a, const void *b)
{
  const struct mode_data *const m = *(const struct mode_data *const*)a;
  const struct mode_data *const n = *(const struct mode_data *const*)b;

  if (m->order > n->order)
    return 1;
  else if (m->order < n->order)
    return -1;

  if (m->bytesize > n->bytesize)
    return 1;
  else if (m->bytesize < n->bytesize)
    return -1;

  if (m->precision > n->precision)
    return 1;
  else if (m->precision < n->precision)
    return -1;

  if (!m->component && !n->component)
    {
      if (m->counter < n->counter)
	return -1;
      else
	return 1;
    }

  if (m->component->bytesize > n->component->bytesize)
    return 1;
  else if (m->component->bytesize < n->component->bytesize)
    return -1;

  if (m->component->precision > n->component->precision)
    return 1;
  else if (m->component->precision < n->component->precision)
    return -1;

  if (m->counter < n->counter)
    return -1;
  else
    return 1;
}

static void
calc_wider_mode (void)
{
  int c;
  struct mode_data *m;
  struct mode_data **sortbuf;
  unsigned int max_n_modes = 0;
  unsigned int i, j;

  for (c = 0; c < MAX_MODE_CLASS; c++)
    max_n_modes = MAX (max_n_modes, n_modes[c]);

  /* Allocate max_n_modes + 1 entries to leave room for the extra null
     pointer assigned after the qsort call below.  */
  sortbuf = XALLOCAVEC (struct mode_data *, max_n_modes + 1);

  for (c = 0; c < MAX_MODE_CLASS; c++)
    {
      /* "wider" is not meaningful for MODE_RANDOM and MODE_CC.
	 However, we want these in textual order, and we have
	 precisely the reverse.  */
      if (c == MODE_RANDOM || c == MODE_CC)
	{
	  struct mode_data *prev, *next;

	  for (prev = 0, m = modes[c]; m; m = next)
	    {
	      m->wider = void_mode;

	      /* this is nreverse */
	      next = m->next;
	      m->next = prev;
	      prev = m;
	    }
	  modes[c] = prev;
	}
      else
	{
	  if (!modes[c])
	    continue;

	  for (i = 0, m = modes[c]; m; i++, m = m->next)
	    sortbuf[i] = m;

	  (qsort) (sortbuf, i, sizeof (struct mode_data *), cmp_modes);

	  sortbuf[i] = 0;
	  for (j = 0; j < i; j++)
	    {
	      sortbuf[j]->next = sortbuf[j + 1];
	      if (c == MODE_PARTIAL_INT)
		sortbuf[j]->wider = sortbuf[j]->component;
	      else
		sortbuf[j]->wider = sortbuf[j]->next;
	    }

	  modes[c] = sortbuf[0];
	}
    }
}

/* Text to add to the constant part of a poly_int initializer in
   order to fill out te whole structure.  */
#if NUM_POLY_INT_COEFFS == 1
#define ZERO_COEFFS ""
#elif NUM_POLY_INT_COEFFS == 2
#define ZERO_COEFFS ", 0"
#else
#error "Unknown value of NUM_POLY_INT_COEFFS"
#endif

/* The shared mode numbering.

   `E_SImode' has to be the same number in every translation unit of a
   compiler that holds more than one back end, and today it is not: it is
   ordinal 122 for i386, 115 for aarch64, 51 for riscv, because each back
   end's enum is dense over the modes that back end happens to define.  A
   back-end object compiled against its own numbering, linked with shared
   code compiled against another's, passes `SImode' and the other side
   reads a different mode -- with no link error and no diagnostic.

   The fix is the project's standing rule: union the vocabulary, keep the
   data per configuration.  A `-DGENMODES_UNION' run reads every back end's
   modes file at once and emits the enum -- that is the vocabulary, and it
   is the same for everybody.  The tables (`mode_size', `mode_next',
   `real_format_for_mode', ...) stay per back end, because a mode's size,
   precision and format legitimately differ between back ends and are not
   vocabulary.

   Those tables are emitted as positional initialisers in enum order, so a
   per-back-end run has to place its values at the SHARED ordinals and put
   something inert at the ordinals belonging to back ends it knows nothing
   about.  `-U' passes it the shared numbering to place them against: the
   union run writes the list with `-l', and each per-back-end run reads it.

   The per-back-end run still reads only its own modes file and computes
   every value exactly as it does today; `-U' changes WHERE a value is
   written, never what it is.  That is deliberate.  Deriving which modes
   belong to a back end from the union run instead -- by tracking which
   file defined what -- gets the modes that `machmode.def' DERIVES from a
   back end's own (`COMPLEX_MODES', `VECTOR_MODES') wrong in ways that are
   hard to see, and the ground truth for "does this back end have this
   mode" is simply what its own run produces.

   A mode no back end defines is a HOLE: class from the shared numbering so
   that it lands in the right run of the enum, and everything else zero.
   Its size and precision are 0 and its format is a null pointer, so shared
   code asking a foreign mode about itself gets an answer that is wrong in
   a way that shows, rather than another back end's answer.  Nothing should
   ask: `mode_next'/`mode_wider' and `class_narrowest_mode' stay dense over
   the back end's own modes, so `FOR_EACH_MODE*' never walks into a hole.  */

static const char *union_list_file;
static const char *union_arch;
static bool gen_union_list;

/* True when this run belongs to one back end of a multi-target compiler,
   i.e. `-A<arch>' was given.  Every run in such a build has it -- the
   singular one announces itself as the primary -- so it is also the test for
   "more than one back end may be linked into the compiler that will read
   this output", which is what the callers below actually care about.  */

static inline bool
multi_target_p (void)
{
  return union_arch != NULL;
}

/* The per-back-end namespace, or NULL.  Same shape as gensupport.cc's
   gen_target_ns, deliberately not shared with it: genmodes is in genprogerr
   and does not link build/gensupport.o, and adding it there to reach one
   three-line function would drag the whole md reader into a program that
   does not use it.  The two must agree on the SPELLING, which is why the
   prefix is written here rather than derived.  */

static const char *
mode_target_ns (void)
{
  static char *ns;
  static bool computed;

  if (!computed)
    {
      computed = true;
      if (union_arch && union_arch[0])
	{
	  ns = concat ("insn_", union_arch, NULL);
	  for (char *p = ns; *p; p++)
	    if (!ISALNUM ((unsigned char) *p) && *p != '_')
	      *p = '_';
	}
    }
  return ns;
}

static void
print_mode_ns_open (void)
{
  const char *ns = mode_target_ns ();
  if (ns)
    printf ("\nnamespace %s {\n", ns);
}

static void
print_mode_ns_close (void)
{
  const char *ns = mode_target_ns ();
  if (ns)
    printf ("\n} /* namespace %s */\n", ns);
}

struct union_slot
{
  const char *name;		/* the numbering key, unique */
  enum mode_class cl;
  const char *arch;		/* owning back end, or null if shared */
  const char *bare;		/* unqualified spelling; == name if shared */
};

static struct union_slot *union_slots;
static unsigned int n_union_slots;

/* NUM_POLY_INT_COEFFS AS THE SHARED NUMBERING SAYS IT IS, or 0 before the
   list has been read.

   This is not a mode, but it belongs in the same file and for the same
   reason.  A back end sets it in its own <cpu>-modes.def (aarch64 and riscv
   say 2; everyone else takes genmodes' default of 1), genmodes emits it into
   insn-modes.h, and poly-int-types.h builds poly_int64, poly_uint64 and the
   rest on top of it.  So on a multi-target build the middle end is compiled
   with poly_int<1,...> -- the primary's answer -- while aarch64's objects use
   poly_int<2,...>, and every function passing one across that line has a
   DIFFERENT MANGLED NAME on the two sides.  It shows up as 37 undefined
   references with names like

     undefined reference to `gen_int_mode(poly_int<2u, long>, machine_mode)'

   which read as missing middle-end objects and are nothing of the kind.

   The union answer is the maximum, and taking it is safe rather than merely
   convenient: a back end that needs only one coefficient works correctly with
   two, carrying a second that is always zero -- which is exactly what aarch64
   itself does for every non-SVE computation.  The maximum is what the union
   run already computes, because it includes every configured back end's modes
   file and the last `#define NUM_POLY_INT_COEFFS 2' wins over the default.  */
static int union_poly_int_coeffs;

/* MAX_BITSIZE_MODE_ANY_INT / MAX_BITSIZE_MODE_ANY_MODE AS THE SHARED
   NUMBERING SAYS THEY ARE, in bits, or 0 before the list has been read.

   These are not modes either, and they are here for the same reason and with
   a sharper failure.  MAX_BITSIZE_MODE_ANY_MODE sizes STACK BUFFERS in
   target-independent code:

     fold-const.cc:13090   unsigned char b[MAX_BITSIZE_MODE_ANY_MODE / BITS_PER_UNIT];
     gimple-fold.cc:10106  unsigned char buf[...];
     expr.cc:13458         unsigned char charbuf[...];
     simplify-rtx.cc:8146  long el32[MAX_BITSIZE_MODE_ANY_MODE / 32];

   and the bounds check that is supposed to protect each of them -- e.g.
   fold-const.cc:13088 `bitsize <= MAX_BITSIZE_MODE_ANY_MODE' -- is written in
   terms of THE SAME CONSTANT.  So when the middle end holds the primary's
   answer (i386: 1024) and the mode being encoded is the selected back end's
   (aarch64 SVE: 8192), the guard admits the value and the buffer is 128 bytes
   where 1024 are written.  That is a stack smash, not a wrong number, and no
   diagnostic precedes it.

   Widths of this kind must therefore be compile-time AND IDENTICAL IN EVERY
   TRANSLATION UNIT.  There is no runtime selection available and none is
   wanted: the union answer is the maximum over every configured back end, a
   back end that needs less is merely given a buffer larger than it can fill,
   and the guards stay correct because they are the same constant again.

   The union run computes the maximum correctly already -- it reads every
   configured back end's modes file and `union_note_max_bitsize' keeps the
   largest -- but until now that answer stayed inside the union run, whose
   only output is this list.  Each per-back-end run, insn-modes.h included,
   recomputed the number from its own modes and got its own answer.  */
static int union_max_bitsize_any_int;
static int union_max_bitsize_any_mode;

/* Write the shared numbering: one line per ordinal, in enum order.  This
   is the union run's output; `read_union_list' is its reader.  */
static void
emit_union_list (void)
{
  int c;
  struct mode_data *m;

  /* Settings first, one per `#'-introduced line.  A per-back-end run reads
     these back instead of computing its own answer; see
     union_poly_int_coeffs.  */
  printf ("#poly_int_coeffs %d\n", NUM_POLY_INT_COEFFS);
  printf ("#max_bitsize_any_int %d\n", resolve_max_any_int ());
  printf ("#max_bitsize_any_mode %d\n", resolve_max_any_mode ());

  for_all_modes (c, m)
    if (strcmp (m->name, m->bare))
      printf ("%s %s %s %s\n", m->name, mode_class_names[m->cl],
	      m->arch, m->bare);
    else
      printf ("%s %s\n", m->name, mode_class_names[m->cl]);
}

static void
read_union_list (void)
{
  FILE *f = fopen (union_list_file, "r");
  char name[256], cl[64], arch[64], bare[256], line[640];
  unsigned int alloc = 64;

  if (!f)
    {
      error ("cannot read shared mode numbering %s", union_list_file);
      return;
    }

  union_slots = XNEWVEC (struct union_slot, alloc);
  while (fgets (line, sizeof line, f))
    {
      int c, nf;

      if (line[0] == '#')
	{
	  int v;
	  if (sscanf (line, "#poly_int_coeffs %d", &v) == 1)
	    union_poly_int_coeffs = v;
	  else if (sscanf (line, "#max_bitsize_any_int %d", &v) == 1)
	    union_max_bitsize_any_int = v;
	  else if (sscanf (line, "#max_bitsize_any_mode %d", &v) == 1)
	    union_max_bitsize_any_mode = v;
	  else
	    error ("%s: unknown setting \"%s\"", union_list_file, line);
	  continue;
	}

      nf = sscanf (line, "%255s %63s %63s %255s", name, cl, arch, bare);
      if (nf != 2 && nf != 4)
	{
	  if (nf > 0)
	    error ("%s: malformed line \"%s\"", union_list_file, name);
	  break;
	}

      if (n_union_slots == alloc)
	{
	  alloc *= 2;
	  union_slots = XRESIZEVEC (struct union_slot, union_slots, alloc);
	}
      for (c = 0; c < MAX_MODE_CLASS; c++)
	if (!strcmp (cl, mode_class_names[c]))
	  break;
      if (c == MAX_MODE_CLASS)
	{
	  error ("%s: unknown mode class \"%s\" for mode \"%s\"",
		 union_list_file, cl, name);
	  break;
	}
      union_slots[n_union_slots].name = xstrdup (name);
      union_slots[n_union_slots].cl = (enum mode_class) c;
      union_slots[n_union_slots].arch = nf == 4 ? xstrdup (arch) : 0;
      union_slots[n_union_slots].bare
	= xstrdup (nf == 4 ? bare : name);
      n_union_slots++;
    }
  fclose (f);

  /* A numbering that could not be read must not be silently treated as an
     empty one: every mode would then look like a mode this back end does
     not have, every table would come out empty, and the build would go on.  */
  if (n_union_slots == 0)
    error ("%s: no modes in the shared numbering", union_list_file);

  /* Zero would silently mean poly_int<0>, which does not compile, but only in
     whatever translation unit happens to instantiate it first -- far from
     here.  Refuse instead: an old list that predates the setting is exactly
     the case that has to be caught, and it cannot be told from a corrupt one.
     No fallback to this run's own NUM_POLY_INT_COEFFS: that is precisely the
     per-back-end answer the shared one exists to replace, so silently using
     it would restore the bug and report success.  */
  if (union_poly_int_coeffs <= 0)
    error ("%s: no #poly_int_coeffs line; regenerate the shared numbering",
	   union_list_file);

  /* Same rule, and here the silent-default trap is a buffer overflow rather
     than a link error: falling back to this run's own maximum is exactly the
     per-back-end answer the shared one replaces, and it would be the SMALLER
     one on the primary.  Refuse by name instead.  */
  if (union_max_bitsize_any_int <= 0)
    error ("%s: no #max_bitsize_any_int line; regenerate the shared numbering",
	   union_list_file);
  if (union_max_bitsize_any_mode <= 0)
    error ("%s: no #max_bitsize_any_mode line; regenerate the shared numbering",
	   union_list_file);
}

/* Rebuild the per-class lists so that walking them in class order walks
   the shared numbering, with a hole wherever this back end has no mode.  */
static void
apply_union_order (void)
{
  struct mode_data *tail[MAX_MODE_CLASS];
  struct mode_data **all;
  unsigned int n_all = 0, i;
  int c;
  struct mode_data *m;

  for_all_modes (c, m)
    n_all++;
  all = XNEWVEC (struct mode_data *, n_all);
  n_all = 0;
  for_all_modes (c, m)
    all[n_all++] = m;

  for (c = 0; c < MAX_MODE_CLASS; c++)
    {
      modes[c] = 0;
      n_modes[c] = 0;
      tail[c] = 0;
    }

  for (i = 0; i < n_union_slots; i++)
    {
      c = union_slots[i].cl;
      /* A qualified ordinal belongs to ONE back end.  For anybody else it
	 is a hole and there is nothing to look up -- looking up the bare
	 name would find this back end's own mode of that name and then trip
	 the class check below, turning another back end's ordinal into a
	 spurious error about this one.  */
      if (union_slots[i].arch
	  && (!union_arch || strcmp (union_slots[i].arch, union_arch)))
	m = 0;
      else
	m = find_mode (union_slots[i].bare);

      /* This back end's mode takes the qualified key as its enum name, and
	 keeps `bare' for `GET_MODE_NAME'.  */
      if (m && union_slots[i].arch)
	m->name = union_slots[i].name;

      /* The class is the one thing the shared numbering fixes, because it
	 decides which run of the enum a mode lands in and
	 `MIN_MODE_<CLASS>'/`MAX_MODE_<CLASS>' are that run's endpoints.  */
      if (m && m->cl != (enum mode_class) c)
	{
	  error ("mode \"%s\" is %s here but %s in the shared numbering",
		 m->name, mode_class_names[m->cl], mode_class_names[c]);
	  m = 0;
	}

      if (m)
	m->numbered = true;
      else
	{
	  m = XNEW (struct mode_data);
	  *m = blank_mode;
	  m->name = union_slots[i].name;
	  /* A hole keeps the QUALIFIED spelling as its `mode_name'.  A hole is
	     a mode this back end does not have, so no name a user can write
	     may match it: `__attribute__((mode(PSI)))' scans `mode_name' by
	     string and takes the FIRST match (c-attribs.cc:2460), so a hole
	     answering "PSI" would capture avr's own attribute for msp430's
	     ordinal, with no diagnostic anywhere.  */
	  m->bare = union_slots[i].name;
	  m->cl = (enum mode_class) c;
	  m->precision = 0;
	  m->bytesize = 0;
	  m->ncomponents = 0;
	  m->alignment = 0;
	  m->format = "0";
	  m->is_hole = true;
	}

      m->next = 0;
      if (tail[c])
	tail[c]->next = m;
      else
	modes[c] = m;
      tail[c] = m;
      n_modes[c]++;
    }

  /* A mode of this back end's that the shared numbering does not contain
     has no ordinal to be written at, and would simply vanish from every
     table -- which is the silent-wrong-answer this step exists to remove.
     It means the numbering is stale, so say which mode and stop.  */
  for (i = 0; i < n_all; i++)
    if (!all[i]->numbered)
      error ("%s:%d: mode \"%s\" is missing from the shared numbering %s",
	     all[i]->file, all[i]->line, all[i]->name, union_list_file);

  free (all);
}

/* Output routines.  */

#define tagged_printf(FMT, ARG, TAG) do {		\
  int count_ = printf ("  " FMT ",", ARG);		\
  printf ("%*s/* %s */\n", 27 - count_, "", TAG);	\
} while (0)

/* Open a mode table.  TYPE is the complete element type including any
   qualifier, NAME the table's name, ASIZE the array bound (possibly empty).

   ON A MULTI-TARGET BUILD THE TABLE GETS TWO NAMES.  The array itself becomes
   <NAME>_tab and <NAME> becomes a POINTER to it, because machmode.h declares
   every one of these as a pointer so that multi-target-select.cc can aim it
   at whichever back end is in force.  Emitting the pointer alongside the
   array, rather than only in the selector, is what lets the SAME output serve
   three consumers that need three different things:

     * insn-modes-<base>.cc -- inside namespace insn_<base>, so the pair is
       insn_<base>::mode_size_tab and insn_<base>::mode_size.  The selector
       copies the pointer; init_adjust_machine_modes, which is in the same
       namespace, writes through it into its own array.
     * min-insn-modes-<base>.cc -- global, linked into the build/gen*
       programs, which include the same machmode.h and therefore need the
       pointer and not the array.
     * a single-target build -- multi_target_p() is false, nothing changes,
       and the output is byte-identical to what it always was.

   print_table_closer () must follow each opener; it needs the name and type,
   which is why they are remembered rather than passed twice.  */

static const char *cur_table_name;
static const char *cur_table_type;

static void
print_table_decl (const char *type, const char *name, const char *asize)
{
  cur_table_name = name;
  cur_table_type = type;
  printf ("\n%s %s%s[%s] =\n{\n", type, name,
	  multi_target_p () ? "_tab" : "", asize);
}

static void
print_table_closer (void)
{
  puts ("};");
  if (multi_target_p ())
    {
      /* The ARRAY keeps this back end's own constness -- it is writable
	 exactly when this modes file adjusts it -- but the POINTER the rest
	 of the compiler shares is const-qualified whatever the back end, to
	 match the CONST_MODE_* that the multi-target headers now emit
	 unconditionally.  See emit_insn_modes_h.  A table whose type is
	 already const stays as it is; `const const' is not a spelling.  */
      const char *add_const =
	strncmp (cur_table_type, "const", 5) == 0 ? "" : "const ";
      printf ("%s%s *%s = %s_tab;\n",
	      add_const, cur_table_type, cur_table_name, cur_table_name);
    }
}

#define print_decl(TYPE, NAME, ASIZE) \
  print_table_decl ("const " TYPE, NAME, ASIZE)

#define print_maybe_const_decl(TYPE, NAME, ASIZE, NEEDS_ADJ)		\
  do {									\
    char *type_ = xasprintf (TYPE, NEEDS_ADJ ? "" : "const ");		\
    print_table_decl (type_, NAME, ASIZE);				\
  } while (0)

#define print_closer() print_table_closer ()

/* Compute the max bitsize of some of the classes of integers.  It may
   be that there are needs for the other integer classes, and this
   code is easy to extend.  */
static void
emit_max_int (void)
{
  puts ("");

  printf ("#define BITS_PER_UNIT (%d)\n", bits_per_unit);

  /* On a multi-target build these two are the SHARED answer, not this back
     end's; see `resolve_max_any_mode'.  */
  printf ("#define MAX_BITSIZE_MODE_ANY_INT %d\n",
	  union_list_file ? union_max_bitsize_any_int : resolve_max_any_int ());
  printf ("#define MAX_BITSIZE_MODE_ANY_MODE %d\n",
	  union_list_file ? union_max_bitsize_any_mode
			  : resolve_max_any_mode ());
}

/* Emit, inside a mode_*_inline body, the declaration of the table that body
   falls back on.  QUALS is any leading qualifier ("const " or ""), TYPE the
   element type, NAME the table.

   ON A MULTI-TARGET BUILD THE TABLE IS A POINTER, AND THE CALLERS BELOW EMIT
   NO `switch' CASES AT ALL.  That switch is a constant-folding fast path: it
   answers every mode whose value cannot be adjusted at runtime with a literal
   taken from THIS run's back end.  With one back end that is the same answer
   the table would give.  With several it is not.  The singular
   insn-modes-inline.h is the PRIMARY's, so `GET_MODE_SIZE (VNx16QImode)'
   folded to the i386 run's value for that ordinal -- 0, because a mode no
   i386 pattern names is a hole -- for every caller whose argument was a
   compile-time constant, while the identical call with a variable argument
   went through the table and got aarch64's real answer.  It bypassed the
   selector silently and only sometimes, which is the hardest possible thing
   to see.  So the fast path goes when there is more than one back end; it
   stays, byte for byte, when there is one.  */

static void
print_inline_table_decl (const char *quals, const char *type,
			 const char *name)
{
  if (multi_target_p ())
    /* QUALS is ignored: it is this back end's own answer to "may this table
       be written", and in a multi-target build these names are the shared
       const pointers -- see emit_insn_modes_h.  Redeclaring one here with
       the back end's qualifier is the same divergence one scope down, and
       it is a hard error rather than a silent one only because this
       declaration sits in the same translation unit as machmode.h's.  */
    printf ("  extern const %s *%s;\n", type, name);
  else
    printf ("  extern %s%s %s[NUM_MACHINE_MODES];\n", quals, type, name);
}

/* Emit mode_size_inline routine into insn-modes.h header.  */
static void
emit_mode_size_inline (void)
{
  int c;
  struct mode_adjust *a;
  struct mode_data *m;

  /* Size adjustments must be propagated to all containing modes.  */
  for (a = adj_bytesize; a; a = a->next)
    {
      a->mode->need_bytesize_adj = true;
      for (m = a->mode->contained; m; m = m->next_cont)
	m->need_bytesize_adj = true;
    }

  /* Changing the number of units by a factor of X also changes the size
     by a factor of X.  */
  for (mode_adjust *a = adj_nunits; a; a = a->next)
    a->mode->need_bytesize_adj = true;

  printf ("\
#ifdef __cplusplus\n\
inline __attribute__((__always_inline__))\n\
#else\n\
extern __inline__ __attribute__((__always_inline__, __gnu_inline__))\n\
#endif\n\
poly_uint16\n\
mode_size_inline (machine_mode mode)\n\
{\n");
  print_inline_table_decl (adj_nunits || adj_bytesize ? "" : "const ",
			   "poly_uint16", "mode_size");
  printf ("\
  gcc_assert (mode >= 0 && mode < NUM_MACHINE_MODES);\n\
  switch (mode)\n\
    {\n");

  if (!multi_target_p ())
    for_all_modes (c, m)
      if (!m->need_bytesize_adj)
	printf ("    case E_%smode: return %u;\n", m->name, m->bytesize);

  puts ("\
    default: return mode_size[mode];\n\
    }\n\
}\n");
}

/* Emit mode_nunits_inline routine into insn-modes.h header.  */
static void
emit_mode_nunits_inline (void)
{
  int c;
  struct mode_data *m;

  for (mode_adjust *a = adj_nunits; a; a = a->next)
    a->mode->need_nunits_adj = true;

  printf ("\
#ifdef __cplusplus\n\
inline __attribute__((__always_inline__))\n\
#else\n\
extern __inline__ __attribute__((__always_inline__, __gnu_inline__))\n\
#endif\n\
poly_uint16\n\
mode_nunits_inline (machine_mode mode)\n\
{\n");
  print_inline_table_decl (adj_nunits ? "" : "const ",
			   "poly_uint16", "mode_nunits");
  printf ("\
  switch (mode)\n\
    {\n");

  if (!multi_target_p ())
    for_all_modes (c, m)
      if (!m->need_nunits_adj)
	printf ("    case E_%smode: return %u;\n", m->name, m->ncomponents);

  puts ("\
    default: return mode_nunits[mode];\n\
    }\n\
}\n");
}

/* Emit mode_inner_inline routine into insn-modes.h header.  */
static void
emit_mode_inner_inline (void)
{
  int c;
  struct mode_data *m;

  puts ("\
#ifdef __cplusplus\n\
inline __attribute__((__always_inline__))\n\
#else\n\
extern __inline__ __attribute__((__always_inline__, __gnu_inline__))\n\
#endif\n\
unsigned short\n\
mode_inner_inline (machine_mode mode)\n\
{");
  print_inline_table_decl ("const ", "unsigned short", "mode_inner");
  puts ("\
  gcc_assert (mode >= 0 && mode < NUM_MACHINE_MODES);\n\
  switch (mode)\n\
    {");

  if (!multi_target_p ())
    for_all_modes (c, m)
      printf ("    case E_%smode: return E_%smode;\n", m->name,
	      c != MODE_PARTIAL_INT && m->component
	      ? m->component->name : m->name);

  puts ("\
    default: return mode_inner[mode];\n\
    }\n\
}\n");
}

/* Emit mode_unit_size_inline routine into insn-modes.h header.  */
static void
emit_mode_unit_size_inline (void)
{
  int c;
  struct mode_data *m;

  puts ("\
#ifdef __cplusplus\n\
inline __attribute__((__always_inline__))\n\
#else\n\
extern __inline__ __attribute__((__always_inline__, __gnu_inline__))\n\
#endif\n\
unsigned char\n\
mode_unit_size_inline (machine_mode mode)\n\
{");
  print_inline_table_decl ("CONST_MODE_UNIT_SIZE ", "unsigned char",
			   "mode_unit_size");
  puts ("\
  gcc_assert (mode >= 0 && mode < NUM_MACHINE_MODES);\n\
  switch (mode)\n\
    {");

  if (!multi_target_p ())
    for_all_modes (c, m)
      {
	const char *name = m->name;
	struct mode_data *m2 = m;
	if (c != MODE_PARTIAL_INT && m2->component)
	  m2 = m2->component;
	if (!m2->need_bytesize_adj)
	  printf ("    case E_%smode: return %u;\n", name, m2->bytesize);
      }

  puts ("\
    default: return mode_unit_size[mode];\n\
    }\n\
}\n");
}

/* Emit mode_unit_precision_inline routine into insn-modes.h header.  */
static void
emit_mode_unit_precision_inline (void)
{
  int c;
  struct mode_data *m;

  puts ("\
#ifdef __cplusplus\n\
inline __attribute__((__always_inline__))\n\
#else\n\
extern __inline__ __attribute__((__always_inline__, __gnu_inline__))\n\
#endif\n\
unsigned short\n\
mode_unit_precision_inline (machine_mode mode)\n\
{");
  print_inline_table_decl ("const ", "unsigned short",
			   "mode_unit_precision");
  puts ("\
  gcc_assert (mode >= 0 && mode < NUM_MACHINE_MODES);\n\
  switch (mode)\n\
    {");

  if (!multi_target_p ())
    for_all_modes (c, m)
      {
	struct mode_data *m2
	  = (c != MODE_PARTIAL_INT && m->component) ? m->component : m;
	if (m2->precision != (unsigned int)-1)
	  printf ("    case E_%smode: return %u;\n", m->name, m2->precision);
	else
	  printf ("    case E_%smode: return %u*BITS_PER_UNIT;\n",
		  m->name, m2->bytesize);
      }

  puts ("\
    default: return mode_unit_precision[mode];\n\
    }\n\
}\n");
}

/* Return the best machine mode class for MODE, or null if machine_mode
   should be used.  */

static const char *
get_mode_class (struct mode_data *mode)
{
  switch (mode->cl)
    {
    case MODE_INT:
    case MODE_PARTIAL_INT:
      return "scalar_int_mode";

    case MODE_FRACT:
    case MODE_UFRACT:
    case MODE_ACCUM:
    case MODE_UACCUM:
      return "scalar_mode";

    case MODE_FLOAT:
    case MODE_DECIMAL_FLOAT:
      return "scalar_float_mode";

    case MODE_COMPLEX_INT:
    case MODE_COMPLEX_FLOAT:
      return "complex_mode";

    default:
      return NULL;
    }
}

static void
emit_insn_modes_h (void)
{
  int c;
  struct mode_data *m, *first, *last;
  int n_int_n_ents = 0;

  printf ("/* Generated automatically from machmode.def%s%s\n",
	   HAVE_EXTRA_MODES ? " and " : "",
	   EXTRA_MODES_FILE);

  puts ("\
   by genmodes.  */\n\
\n\
#ifndef GCC_INSN_MODES_H\n\
#define GCC_INSN_MODES_H\n");

  /* How machmode.h declares the mode tables.  It cannot decide this for
     itself: whether a table is an array or a pointer to the selected back
     end's array is a property of how this compiler was CONFIGURED, and
     genmodes is the only thing that knows.  Putting the choice in a macro
     rather than an #if in machmode.h keeps the fifteen declarations there
     readable and, more usefully, makes it impossible for one of them to be
     converted and another forgotten -- which would compile in every
     translation unit and differ only in what the linker resolved.  */
  if (multi_target_p ())
    puts ("\
\n/* Multi-target: each back end has its own tables, in its own namespace,\n\
   and these bare names are pointers that multi-target-select.cc aims at\n\
   the back end in force.  Reading one before a target is selected is a\n\
   null dereference, deliberately: there is no default back end.  */\n\
#define GCC_TARGET_TABLE(TYPE, NAME, SIZE) TYPE *NAME\n");
  else
    puts ("\
\n#define GCC_TARGET_TABLE(TYPE, NAME, SIZE) TYPE NAME[SIZE]\n");

  puts ("\
enum machine_mode\n{");

  for (c = 0; c < MAX_MODE_CLASS; c++)
    for (m = modes[c]; m; m = m->next)
      {
	int count_ = printf ("  E_%smode,", m->name);
	printf ("%*s/* %s:%d */\n", 27 - count_, "",
		 trim_filename (m->file), m->line);
	printf ("#define HAVE_%smode\n", m->name);
	printf ("#ifdef USE_ENUM_MODES\n");
	printf ("#define %smode E_%smode\n", m->name, m->name);
	printf ("#else\n");
	if (const char *mode_class = get_mode_class (m))
	  printf ("#define %smode (%s ((%s::from_int) E_%smode))\n",
		  m->name, mode_class, mode_class, m->name);
	else
	  printf ("#define %smode ((void) 0, E_%smode)\n",
		  m->name, m->name);
	printf ("#endif\n");
	/* The back end's own sources say `PSImode', not `avr_PSImode', and
	   are not going to be edited.  Alias the unqualified spelling to
	   this back end's ordinal.  Holes get no alias: nothing may reach
	   another back end's mode by its plain name.  */
	if (!m->is_hole && strcmp (m->name, m->bare))
	  {
	    printf ("#define HAVE_%smode\n", m->bare);
	    /* And the `E_'-prefixed spelling, which is a THIRD name for the
	       same ordinal and is the one that appears where a `case' label
	       or an `==' needs an integral constant rather than a
	       `scalar_int_mode'.  Both the back end's own sources
	       (`config/avr/avr.cc' has seven `case E_PSImode:', msp430 four)
	       and the generated `insn-recog'/`insn-emit'/`insn-output' for
	       this back end spell it: read-rtl.cc:218 and genrecog.cc:4569
	       build it as "E_" GET_MODE_NAME (mode) "mode", and
	       GET_MODE_NAME answers `bare'.  Without this line those are 606
	       diagnostics from the two back ends that collide, and the
	       unqualified `PSImode' alias below cannot serve them because it
	       expands to a class object, not to an enumerator.  */
	    printf ("#define E_%smode E_%smode\n", m->bare, m->name);
	    printf ("#ifdef USE_ENUM_MODES\n");
	    printf ("#define %smode E_%smode\n", m->bare, m->name);
	    printf ("#else\n");
	    if (const char *mc = get_mode_class (m))
	      printf ("#define %smode (%s ((%s::from_int) E_%smode))\n",
		      m->bare, mc, mc, m->name);
	    else
	      printf ("#define %smode ((void) 0, E_%smode)\n",
		      m->bare, m->name);
	    printf ("#endif\n");
	  }
      }

  puts ("  MAX_MACHINE_MODE,\n");

  for (c = 0; c < MAX_MODE_CLASS; c++)
    {
      first = modes[c];
      last = 0;
      for (m = first; m; last = m, m = m->next)
	;

      /* Don't use BImode for MIN_MODE_INT, since otherwise the middle
	 end will try to use it for bitfields in structures and the
	 like, which we do not want.  Only the target md file should
	 generate BImode widgets.  Since some targets such as ARM/MVE
	 define boolean modes with multiple bits, handle those too.  */
      if (first && first->boolean)
	{
	  struct mode_data *last_bool = first;
	  printf ("  MIN_MODE_BOOL = E_%smode,\n", first->name);

	  while (first && first->boolean)
	    {
	      last_bool = first;
	      first = first->next;
	    }

	  printf ("  MAX_MODE_BOOL = E_%smode,\n\n", last_bool->name);
	}

      if (first && last)
	printf ("  MIN_%s = E_%smode,\n  MAX_%s = E_%smode,\n\n",
		 mode_class_names[c], first->name,
		 mode_class_names[c], last->name);
      else
	printf ("  MIN_%s = E_%smode,\n  MAX_%s = E_%smode,\n\n",
		 mode_class_names[c], void_mode->name,
		 mode_class_names[c], void_mode->name);
    }

  puts ("\
  NUM_MACHINE_MODES = MAX_MACHINE_MODE\n\
};\n");

  /* Define a NUM_* macro for each mode class, giving the number of modes
     in the class.  */
  for (c = 0; c < MAX_MODE_CLASS; c++)
    {
      printf ("#define NUM_%s ", mode_class_names[c]);
      if (modes[c])
	printf ("(MAX_%s - MIN_%s + 1)\n", mode_class_names[c],
		mode_class_names[c]);
      else
	printf ("0\n");
    }
  printf ("\n");

  /* WHO MAY WRITE A MODE TABLE, AND WHEN.

     Single target: unchanged.  A table is `const' exactly when this modes
     file has no ADJUST_* for it, because the one thing that writes it --
     init_adjust_machine_modes, below -- is in the same program.

     Multi target: ALWAYS `const', in every one of these headers, shared and
     per back end alike.  These macros qualify a name that crosses between
     back ends, and it used to be answered per back end: i386 says `const
     poly_uint16 mode_precision[]' (it adjusts nothing) while aarch64 says
     `poly_uint16 mode_precision[]' (SVE adjusts mode sizes at startup).
     The middle end reads the shared header, so it held a declaration that
     every aarch64 object contradicted -- one object, two types, and no
     diagnostic anywhere.

     `const' is the answer rather than "not const" because it is the true
     one for everybody who reads through these names.  The middle end never
     writes a mode table -- there is not one assignment to one of them
     outside this generator -- and neither does any hand-written back-end
     source.  The sole writer is the generated adjustment code, it runs in
     its own back end's translation unit, and it now writes the ARRAY
     (`mode_size_tab') rather than the pointer the rest of the compiler
     shares.  See emit_mode_adjustments.

     Dropping `const' from the shared declaration instead would also have
     made the types agree, and would have agreed on the weaker claim: it
     would have left the middle end able to write a table belonging to a
     back end that may not even be selected, with nothing left to say so.  */
  if (multi_target_p ())
    {
      puts ("#define CONST_MODE_NUNITS const");
      puts ("#define CONST_MODE_PRECISION const");
      puts ("#define CONST_MODE_SIZE const");
      puts ("#define CONST_MODE_UNIT_SIZE const");
      puts ("#define CONST_MODE_BASE_ALIGN const");
      puts ("#define CONST_MODE_IBIT const");
      puts ("#define CONST_MODE_FBIT const");
      puts ("#define CONST_MODE_MASK const");
    }
  else
    {
      /* I can't think of a better idea, can you?  */
      printf ("#define CONST_MODE_NUNITS%s\n", adj_nunits ? "" : " const");
      printf ("#define CONST_MODE_PRECISION%s\n", adj_nunits ? "" : " const");
      printf ("#define CONST_MODE_SIZE%s\n",
	      adj_bytesize || adj_nunits ? "" : " const");
      printf ("#define CONST_MODE_UNIT_SIZE%s\n", adj_bytesize ? "" : " const");
      printf ("#define CONST_MODE_BASE_ALIGN%s\n",
	      adj_alignment ? "" : " const");
#if 0 /* disabled for backward compatibility, temporary */
      printf ("#define CONST_REAL_FORMAT_FOR_MODE%s\n",
	      adj_format ? "" :" const");
#endif
      printf ("#define CONST_MODE_IBIT%s\n", adj_ibit ? "" : " const");
      printf ("#define CONST_MODE_FBIT%s\n", adj_fbit ? "" : " const");
      printf ("#define CONST_MODE_MASK%s\n", adj_nunits ? "" : " const");
    }
  emit_max_int ();

  for_all_modes (c, m)
    if (m->int_n)
      n_int_n_ents ++;

  printf ("#define NUM_INT_N_ENTS %d\n", n_int_n_ents);

  /* The shared answer when there is one; see union_poly_int_coeffs.  This is
     the ONE value in insn-modes-<base>.h that is deliberately not this back
     end's own -- it decides a TYPE that crosses between back ends, so it is
     vocabulary and not data.  A run given no shared numbering at all (no -U)
     has no back end but its own to agree with, and answers as it always
     did.  */
  printf ("#define NUM_POLY_INT_COEFFS %d\n",
	  union_list_file ? union_poly_int_coeffs : NUM_POLY_INT_COEFFS);

  puts ("\
\n\
#endif /* insn-modes.h */");
}

static void
emit_insn_modes_inline_h (void)
{
  printf ("/* Generated automatically from machmode.def%s%s\n",
	   HAVE_EXTRA_MODES ? " and " : "",
	   EXTRA_MODES_FILE);

  puts ("\
   by genmodes.  */\n\
\n\
#ifndef GCC_INSN_MODES_INLINE_H\n\
#define GCC_INSN_MODES_INLINE_H");

  puts ("\n#if !defined (USED_FOR_TARGET) && GCC_VERSION >= 4001\n");
  emit_mode_size_inline ();
  emit_mode_nunits_inline ();
  emit_mode_inner_inline ();
  emit_mode_unit_size_inline ();
  emit_mode_unit_precision_inline ();
  puts ("#endif /* GCC_VERSION >= 4001 */");

  puts ("\
\n\
#endif /* insn-modes-inline.h */");
}

/* Multi-target: the `tm.h' this emits is NOT yet suffixed.  genmodes is built
   per back end, but only its -h/-i/-m outputs are (insn-modes-<base>.h,
   insn-modes-inline-<base>.h, min-insn-modes-<base>.cc); insn-modes.cc itself
   is still produced once.  genmodes also does not link gensupport.o, so it has
   no print_gen_include.  Whoever makes insn-modes.cc per back end must fix
   this line at the same time.  */

static void
emit_insn_modes_c_header (void)
{
  printf ("/* Generated automatically from machmode.def%s%s\n",
	   HAVE_EXTRA_MODES ? " and " : "",
	   EXTRA_MODES_FILE);

  puts ("\
   by genmodes.  */\n\
\n\
#include \"config.h\"\n\
#include \"system.h\"\n\
#include \"coretypes.h\"\n\
#include \"tm.h\"\n\
#include \"real.h\"");
}

static void
emit_min_insn_modes_c_header (void)
{
  printf ("/* Generated automatically from machmode.def%s%s\n",
	   HAVE_EXTRA_MODES ? " and " : "",
	   EXTRA_MODES_FILE);

  puts ("\
   by genmodes.  */\n\
\n\
#include \"bconfig.h\"\n\
#include \"system.h\"\n\
#include \"coretypes.h\"");
}

static void
emit_mode_name (void)
{
  int c;
  struct mode_data *m;

  print_decl ("char *const", "mode_name", "NUM_MACHINE_MODES");

  /* `GET_MODE_NAME' answers the UNQUALIFIED name.  It is what
     `optabs-libfuncs.cc:159' lowercases to build `__mulpsi3', so a
     qualified name here would rename libgcc symbols -- which is the one
     thing this whole approach exists to avoid.  Holes are the exception,
     above.  */
  for_all_modes (c, m)
    printf ("  \"%s\",\n", m->bare);

  print_closer ();
}

static void
emit_mode_class (void)
{
  int c;
  struct mode_data *m;

  print_decl ("unsigned char", "mode_class", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    tagged_printf ("%s", mode_class_names[m->cl], m->name);

  print_closer ();
}

static void
emit_mode_precision (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%spoly_uint16", "mode_precision",
			  "NUM_MACHINE_MODES", adj_nunits);

  for_all_modes (c, m)
    if (m->precision != (unsigned int)-1)
      tagged_printf ("{ %u" ZERO_COEFFS " }", m->precision, m->name);
    else
      tagged_printf ("{ %u * BITS_PER_UNIT" ZERO_COEFFS " }",
		     m->bytesize, m->name);

  print_closer ();
}

static void
emit_mode_size (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%spoly_uint16", "mode_size",
			  "NUM_MACHINE_MODES", adj_nunits || adj_bytesize);

  for_all_modes (c, m)
    tagged_printf ("{ %u" ZERO_COEFFS " }", m->bytesize, m->name);

  print_closer ();
}

static void
emit_mode_nunits (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%spoly_uint16", "mode_nunits",
			  "NUM_MACHINE_MODES", adj_nunits);

  for_all_modes (c, m)
    tagged_printf ("{ %u" ZERO_COEFFS " }", m->ncomponents, m->name);

  print_closer ();
}

static void
emit_mode_wider (void)
{
  int c;
  struct mode_data *m;

  print_decl ("unsigned short", "mode_next", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    tagged_printf ("E_%smode",
		   m->wider ? m->wider->name : void_mode->name,
		   m->name);

  print_closer ();
  print_decl ("unsigned short", "mode_wider", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    {
      struct mode_data *m2 = 0;

      if (m->cl == MODE_INT
	  || m->cl == MODE_PARTIAL_INT
	  || m->cl == MODE_FLOAT
	  || m->cl == MODE_DECIMAL_FLOAT
	  || m->cl == MODE_COMPLEX_FLOAT
	  || m->cl == MODE_FRACT
	  || m->cl == MODE_UFRACT
	  || m->cl == MODE_ACCUM
	  || m->cl == MODE_UACCUM)
	for (m2 = m->wider; m2 && m2 != void_mode; m2 = m2->wider)
	  {
	    if (m2->bytesize == m->bytesize
		&& m2->precision == m->precision)
	      continue;
	    break;
	  }

      if (m2 == void_mode)
	m2 = 0;
      tagged_printf ("E_%smode",
		     m2 ? m2->name : void_mode->name,
		     m->name);
    }

  print_closer ();
  print_decl ("unsigned short", "mode_2xwider", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    {
      struct mode_data * m2;

      /* A hole has size and precision 0, so the search below would match
	 the hole itself (0 == 2 * 0) and hand out a mode that is its own
	 2x-wider.  Nothing should ask a foreign mode for its 2x-wider;
	 answer VOIDmode, which every caller already treats as "none".  */
      if (m->is_hole)
	{
	  tagged_printf ("E_%smode", void_mode->name, m->name);
	  continue;
	}

      for (m2 = m;
	   m2 && m2 != void_mode;
	   m2 = m2->wider)
	{
	  if (m2->bytesize < 2 * m->bytesize)
	    continue;
	  if (m->precision != (unsigned int) -1)
	    {
	      if (m2->precision != 2 * m->precision)
		continue;
	    }
	  else
	    {
	      if (m2->precision != (unsigned int) -1)
		continue;
	    }

	  /* For vectors we want twice the number of components,
	     with the same element type.  */
	  if (m->cl == MODE_VECTOR_BOOL
	      || m->cl == MODE_VECTOR_INT
	      || m->cl == MODE_VECTOR_FLOAT
	      || m->cl == MODE_VECTOR_FRACT
	      || m->cl == MODE_VECTOR_UFRACT
	      || m->cl == MODE_VECTOR_ACCUM
	      || m->cl == MODE_VECTOR_UACCUM)
	    {
	      if (m2->ncomponents != 2 * m->ncomponents)
		continue;
	      if (m->component != m2->component)
		continue;
	    }

	  break;
	}
      if (m2 == void_mode)
	m2 = 0;
      tagged_printf ("E_%smode",
		     m2 ? m2->name : void_mode->name,
		     m->name);
    }

  print_closer ();
}

static void
emit_mode_complex (void)
{
  int c;
  struct mode_data *m;

  print_decl ("unsigned short", "mode_complex", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    tagged_printf ("E_%smode",
		   m->complex ? m->complex->name : void_mode->name,
		   m->name);

  print_closer ();
}

static void
emit_mode_mask (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%sunsigned HOST_WIDE_INT", "mode_mask_array",
			  "NUM_MACHINE_MODES", adj_nunits);
  puts ("\
#define MODE_MASK(m)                          \\\n\
  ((m) >= HOST_BITS_PER_WIDE_INT)             \\\n\
   ? HOST_WIDE_INT_M1U                        \\\n\
   : (HOST_WIDE_INT_1U << (m)) - 1\n");

  for_all_modes (c, m)
    if (m->precision != (unsigned int)-1)
      tagged_printf ("MODE_MASK (%u)", m->precision, m->name);
    else
      tagged_printf ("MODE_MASK (%u*BITS_PER_UNIT)", m->bytesize, m->name);

  puts ("#undef MODE_MASK");
  print_closer ();
}

/* ASSESSED AND DELIBERATELY NOT "FIXED": `mode_inner[hole] = hole'.

   A hole has no `component', so the expression below falls to `m->name' and a
   hole is emitted as its own inner mode.  For a scalar mode that is upstream's
   normal encoding -- `mode_inner[E_SImode]' really is `E_SImode' -- but a hole
   exists in EVERY class of the shared numbering, including the vector classes,
   so `GET_MODE_INNER' of a vector-class hole answers a vector-class mode.
   That is a type-invariant violation, and a silent one:

     machmode.h:626  mode_to_inner  returns  scalar_mode::from_int (mode_inner[mode])

   and `from_int' is the unchecked constructor -- `scalar_mode::includes_p' is
   never consulted on this path -- so nothing asserts, in a checking build
   either.

   THE OBVIOUS FIX IS UNAVAILABLE, AND THAT IS THE RESULT.  `emit_mode_2xwider'
   twenty lines up meets the identical problem (a hole has size 0, so `0 == 2*0'
   makes it its own 2x-wider) and answers `VOIDmode', "which every caller
   already treats as none".  That substitution CANNOT be copied here, because
   the two tables have different return types: `mode_2xwider' is read as a
   `machine_mode', where VOIDmode is a legal value, and `mode_inner' is read as
   a `scalar_mode', where it is not -- VOIDmode is `MODE_RANDOM' and fails
   `scalar_mode::includes_p'.  So `scalar_mode' HAS NO REPRESENTABLE "NONE",
   and every candidate value here is a lie of some kind; picking one would
   move the wrongness rather than remove it, and would look like the 2xwider
   guard while not being it.

   WHAT WOULD ACTUALLY CLOSE IT, for whoever takes this next.  The property
   that makes a hole safe everywhere else is that `FOR_EACH_MODE*' never walks
   into one, so the question is never asked; the residue is code that reaches a
   mode by ORDINAL rather than by walking.  Closing it therefore needs either
   (a) a checked accessor -- make `mode_to_inner' assert `!mode_is_hole (mode)',
   which needs a hole predicate exported into `insn-modes.h', currently absent,
   and turns a silent wrong type into a diagnostic naming the mode; or
   (b) `scalar_mode' gaining a none-value, which is a middle-end change far
   outside genmodes.  (a) is the tractable one and is a task of its own: it is
   an ARM, not a table edit, and it wants the both-sided evidence that no
   configured back end reaches it in a normal compilation before it is turned
   on.  Note that `mode_unit_size' and `mode_unit_precision' below take the
   same `m->component ? ... : m->name' shape and so give a hole its own 0 --
   there the answer happens to be harmless, which is why only this one is
   worth a note.  */

static void
emit_mode_inner (void)
{
  int c;
  struct mode_data *m;

  print_decl ("unsigned short", "mode_inner", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    tagged_printf ("E_%smode",
		   c != MODE_PARTIAL_INT && m->component
		   ? m->component->name : m->name,
		   m->name);

  print_closer ();
}

/* Emit mode_unit_size array into insn-modes.cc file.  */
static void
emit_mode_unit_size (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%sunsigned char", "mode_unit_size",
			  "NUM_MACHINE_MODES", adj_bytesize);

  for_all_modes (c, m)
    tagged_printf ("%u",
		   c != MODE_PARTIAL_INT && m->component
		   ? m->component->bytesize : m->bytesize, m->name);

  print_closer ();
}

/* Emit mode_unit_precision array into insn-modes.cc file.  */
static void
emit_mode_unit_precision (void)
{
  int c;
  struct mode_data *m;

  print_decl ("unsigned short", "mode_unit_precision", "NUM_MACHINE_MODES");

  for_all_modes (c, m)
    {
      struct mode_data *m2 = (c != MODE_PARTIAL_INT && m->component) ?
			     m->component : m;
      if (m2->precision != (unsigned int)-1)
	tagged_printf ("%u", m2->precision, m->name);
      else
	tagged_printf ("%u*BITS_PER_UNIT", m2->bytesize, m->name);
    }

  print_closer ();
}


static void
emit_mode_base_align (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%sunsigned short",
			  "mode_base_align", "NUM_MACHINE_MODES",
			  adj_alignment);

  for_all_modes (c, m)
    tagged_printf ("%u", m->alignment, m->name);

  print_closer ();
}

static void
emit_class_narrowest_mode (void)
{
  int c;

  print_decl ("unsigned short", "class_narrowest_mode", "MAX_MODE_CLASS");

  for (c = 0; c < MAX_MODE_CLASS; c++)
    {
      /* Bleah, all this to get the comment right for MIN_MODE_INT.  */
      struct mode_data *m = modes[c];
      while (m && (m->boolean || m->is_hole))
	m = m->next;
      const char *comment_name = (m ? m : void_mode)->name;

      /* This is where `FOR_EACH_MODE_IN_CLASS' starts walking, so under a
	 shared numbering it must be this back end's own narrowest mode of
	 the class and not the numbering's, which may well belong to a back
	 end that is not this one.  `MIN_MODE_<CLASS>' is the numbering's,
	 so name the mode instead -- and say VOIDmode when this back end has
	 no mode of the class at all, which ends the walk immediately.  */
      if (union_list_file)
	tagged_printf ("E_%smode", (m ? m : void_mode)->name, comment_name);
      else
	tagged_printf ("MIN_%s", mode_class_names[c], comment_name);
    }

  print_closer ();
}

static void
emit_real_format_for_mode (void)
{
  struct mode_data *m;

  /* The entities pointed to by this table are constant, whether
     or not the table itself is constant.

     For backward compatibility this table is always writable
     (several targets modify it in TARGET_OPTION_OVERRIDE).   FIXME:
     convert all said targets to use ADJUST_FORMAT instead.  */
#if 0
  print_maybe_const_decl ("const struct real_format *%s",
			  "real_format_for_mode",
			  "MAX_MODE_FLOAT - MIN_MODE_FLOAT + 1",
			  format);
#else
  print_decl ("struct real_format *\n", "real_format_for_mode",
	      "MAX_MODE_FLOAT - MIN_MODE_FLOAT + 1 "
	      "+ MAX_MODE_DECIMAL_FLOAT - MIN_MODE_DECIMAL_FLOAT + 1");
#endif

  /* The beginning of the table is entries for float modes.  */
  for (m = modes[MODE_FLOAT]; m; m = m->next)
    if (!strcmp (m->format, "0"))
      tagged_printf ("%s", m->format, m->name);
    else
      tagged_printf ("&%s", m->format, m->name);

  /* The end of the table is entries for decimal float modes.  */
  for (m = modes[MODE_DECIMAL_FLOAT]; m; m = m->next)
    if (!strcmp (m->format, "0"))
      tagged_printf ("%s", m->format, m->name);
    else
      tagged_printf ("&%s", m->format, m->name);

  print_closer ();
}

static void
emit_mode_adjustments (void)
{
  int c;
  struct mode_adjust *a;
  struct mode_data *m;

  /* THE ONLY WRITER OF A MODE TABLE IN THE WHOLE COMPILER.

     In a multi-target build the bare names are const pointers shared with
     every other back end (see emit_insn_modes_h), so this code writes the
     underlying array instead.  Same storage, and it is this back end's own:
     the array is defined a few lines above in this same file, and it is
     non-const precisely when this modes file adjusts it.

     Spelled as macros rather than by rewriting each printf below because
     there are forty-odd of them and a rewrite that missed one would fail in
     the one place the diagnostic is least useful -- a const violation deep
     in generated code -- while this cannot miss one.  Undefined again at the
     end of the function, so nothing else in the file sees them.  */
  if (multi_target_p ())
    puts ("\n\
/* The adjustment code below writes the tables; see emit_mode_adjustments.  */\n\
#define mode_mask_array mode_mask_array_tab\n\
#define mode_precision mode_precision_tab\n\
#define mode_size mode_size_tab\n\
#define mode_nunits mode_nunits_tab\n\
#define mode_unit_size mode_unit_size_tab\n\
#define mode_base_align mode_base_align_tab\n\
#define mode_ibit mode_ibit_tab\n\
#define mode_fbit mode_fbit_tab");

  if (adj_nunits)
    printf ("\n"
	    "void\n"
	    "adjust_mode_mask (machine_mode mode)\n"
	    "{\n"
	    "  unsigned int precision;\n"
	    "  if (GET_MODE_PRECISION (mode).is_constant (&precision)\n"
	    "      && precision < HOST_BITS_PER_WIDE_INT)\n"
	    "    mode_mask_array[mode] = (HOST_WIDE_INT_1U << precision) - 1;"
	    "\n"
	    "  else\n"
	    "    mode_mask_array[mode] = HOST_WIDE_INT_M1U;\n"
	    "}\n");

  puts ("\
\nvoid\
\ninit_adjust_machine_modes (void)\
\n{\
\n  poly_uint16 ps ATTRIBUTE_UNUSED;\n\
  size_t s ATTRIBUTE_UNUSED;");

  for (a = adj_nunits; a; a = a->next)
    {
      m = a->mode;
      printf ("\n"
	      "  {\n"
	      "    /* %s:%d */\n  ps = %s;\n",
	      a->file, a->line, a->adjustment);
      printf ("    int old_factor = vector_element_size"
	      " (mode_precision[E_%smode], mode_nunits[E_%smode]);\n",
	      m->name, m->name);
      printf ("    mode_precision[E_%smode] = ps * old_factor;\n", m->name);
      printf ("    if (!multiple_p (mode_precision[E_%smode],"
	      " BITS_PER_UNIT, &mode_size[E_%smode]))\n", m->name, m->name);
      printf ("      mode_size[E_%smode] = -1;\n", m->name);
      printf ("    mode_nunits[E_%smode] = ps;\n", m->name);
      printf ("    adjust_mode_mask (E_%smode);\n", m->name);
      printf ("  }\n");
    }

  /* Size adjustments must be propagated to all containing modes.
     A size adjustment forces us to recalculate the alignment too.  */
  for (a = adj_bytesize; a; a = a->next)
    {
      printf ("\n  /* %s:%d */\n", a->file, a->line);
      switch (a->mode->cl)
	{
	case MODE_VECTOR_BOOL:
	case MODE_VECTOR_INT:
	case MODE_VECTOR_FLOAT:
	case MODE_VECTOR_FRACT:
	case MODE_VECTOR_UFRACT:
	case MODE_VECTOR_ACCUM:
	case MODE_VECTOR_UACCUM:
	  printf ("  ps = %s;\n", a->adjustment);
	  printf ("  s = mode_unit_size[E_%smode];\n", a->mode->name);
	  break;

	default:
	  printf ("  ps = s = %s;\n", a->adjustment);
	  printf ("  mode_unit_size[E_%smode] = s;\n", a->mode->name);
	  break;
	}
      printf ("  mode_size[E_%smode] = ps;\n", a->mode->name);
      printf ("  mode_base_align[E_%smode] = known_alignment (ps);\n",
	      a->mode->name);

      for (m = a->mode->contained; m; m = m->next_cont)
	{
	  switch (m->cl)
	    {
	    case MODE_COMPLEX_INT:
	    case MODE_COMPLEX_FLOAT:
	      printf ("  mode_size[E_%smode] = 2*s;\n", m->name);
	      printf ("  mode_unit_size[E_%smode] = s;\n", m->name);
	      printf ("  mode_base_align[E_%smode] = s & (~s + 1);\n",
		      m->name);
	      break;

	    case MODE_VECTOR_BOOL:
	      /* Changes to BImode should not affect vector booleans.  */
	      break;

	    case MODE_VECTOR_INT:
	    case MODE_VECTOR_FLOAT:
	    case MODE_VECTOR_FRACT:
	    case MODE_VECTOR_UFRACT:
	    case MODE_VECTOR_ACCUM:
	    case MODE_VECTOR_UACCUM:
	      printf ("  mode_size[E_%smode] = %d * ps;\n",
		      m->name, m->ncomponents);
	      printf ("  mode_unit_size[E_%smode] = s;\n", m->name);
	      printf ("  mode_base_align[E_%smode]"
		      " = known_alignment (%d * ps);\n",
		      m->name, m->ncomponents);
	      break;

	    default:
	      internal_error (
	      "mode %s is neither vector nor complex but contains %s",
	      m->name, a->mode->name);
	      /* NOTREACHED */
	    }
	}
    }

  /* Alignment adjustments propagate too.
     ??? This may not be the right thing for vector modes.  */
  for (a = adj_alignment; a; a = a->next)
    {
      printf ("\n  /* %s:%d */\n  s = %s;\n",
	      a->file, a->line, a->adjustment);
      printf ("  mode_base_align[E_%smode] = s;\n", a->mode->name);

      for (m = a->mode->contained; m; m = m->next_cont)
	{
	  switch (m->cl)
	    {
	    case MODE_COMPLEX_INT:
	    case MODE_COMPLEX_FLOAT:
	      printf ("  mode_base_align[E_%smode] = s;\n", m->name);
	      break;

	    case MODE_VECTOR_BOOL:
	      /* Changes to BImode should not affect vector booleans.  */
	      break;

	    case MODE_VECTOR_INT:
	    case MODE_VECTOR_FLOAT:
	    case MODE_VECTOR_FRACT:
	    case MODE_VECTOR_UFRACT:
	    case MODE_VECTOR_ACCUM:
	    case MODE_VECTOR_UACCUM:
	      printf ("  mode_base_align[E_%smode] = %d*s;\n",
		      m->name, m->ncomponents);
	      break;

	    default:
	      internal_error (
	      "mode %s is neither vector nor complex but contains %s",
	      m->name, a->mode->name);
	      /* NOTREACHED */
	    }
	}
    }

  /* Ibit adjustments don't have to propagate.  */
  for (a = adj_ibit; a; a = a->next)
    {
      printf ("\n  /* %s:%d */\n  s = %s;\n",
	      a->file, a->line, a->adjustment);
      printf ("  mode_ibit[E_%smode] = s;\n", a->mode->name);
    }

  /* Fbit adjustments don't have to propagate.  */
  for (a = adj_fbit; a; a = a->next)
    {
      printf ("\n  /* %s:%d */\n  s = %s;\n",
	      a->file, a->line, a->adjustment);
      printf ("  mode_fbit[E_%smode] = s;\n", a->mode->name);
    }

  /* Real mode formats don't have to propagate anywhere.  */
  for (a = adj_format; a; a = a->next)
    printf ("\n  /* %s:%d */\n  REAL_MODE_FORMAT (E_%smode) = %s;\n",
	    a->file, a->line, a->mode->name, a->adjustment);

  /* Adjust precision to the actual bits size.  */
  for (a = adj_precision; a; a = a->next)
    switch (a->mode->cl)
      {
	case MODE_VECTOR_BOOL:
	  printf ("\n  /* %s:%d.  */\n  ps = %s;\n", a->file, a->line,
		  a->adjustment);
	  printf ("  mode_precision[E_%smode] = ps;\n", a->mode->name);
	  break;
	default:
	  internal_error ("invalid use of ADJUST_PRECISION for mode %s",
			  a->mode->name);
	  /* NOTREACHED.  */
      }

  /* Ensure there is no mode size equals -1.  */
  for_all_modes (c, m)
    printf ("\n  gcc_assert (maybe_ne (mode_size[E_%smode], -1));\n",
	    m->name);

  puts ("}");

  if (multi_target_p ())
    puts ("\n\
#undef mode_mask_array\n\
#undef mode_precision\n\
#undef mode_size\n\
#undef mode_nunits\n\
#undef mode_unit_size\n\
#undef mode_base_align\n\
#undef mode_ibit\n\
#undef mode_fbit");
}

/* Emit ibit for all modes.  */

static void
emit_mode_ibit (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%sunsigned char",
			  "mode_ibit", "NUM_MACHINE_MODES",
			  adj_ibit);

  for_all_modes (c, m)
    tagged_printf ("%u", m->ibit, m->name);

  print_closer ();
}

/* Emit fbit for all modes.  */

static void
emit_mode_fbit (void)
{
  int c;
  struct mode_data *m;

  print_maybe_const_decl ("%sunsigned char",
			  "mode_fbit", "NUM_MACHINE_MODES",
			  adj_fbit);

  for_all_modes (c, m)
    tagged_printf ("%u", m->fbit, m->name);

  print_closer ();
}

/* Emit __intN for all modes.  */

static void
emit_mode_int_n (void)
{
  int c;
  struct mode_data *m;
  struct mode_data **mode_sort;
  int n_modes = 0;
  int i, j;

  print_decl ("int_n_data_t", "int_n_data", "");

  n_modes = 0;
  for_all_modes (c, m)
    if (m->int_n)
      n_modes ++;
  mode_sort = XALLOCAVEC (struct mode_data *, n_modes);

  n_modes = 0;
  for_all_modes (c, m)
    if (m->int_n)
      mode_sort[n_modes++] = m;

  /* Yes, this is a bubblesort, but there are at most four (and
     usually only 1-2) entries to sort.  */
  for (i = 0; i<n_modes - 1; i++)
    for (j = i + 1; j < n_modes; j++)
      if (mode_sort[i]->int_n > mode_sort[j]->int_n)
	std::swap (mode_sort[i], mode_sort[j]);

  for (i = 0; i < n_modes; i ++)
    {
      m = mode_sort[i];
      printf(" {\n");
      tagged_printf ("%u", m->int_n, m->name);
      printf ("{ E_%smode },", m->name);
      printf(" },\n");
    }

  print_closer ();
}


static void
emit_insn_modes_c (void)
{
  emit_insn_modes_c_header ();
  /* Every table below, and init_adjust_machine_modes with them, is declared
     bare in machmode.h and read by the whole middle end.  Two back ends
     defining `mode_size' bare is the silent-collision case in its purest
     form -- an archive keeps one and every foreign mode then answers with
     another machine's size.  Namespaced; machmode.h's bare names are
     POINTERS supplied by multi-target-select.cc.  */
  print_mode_ns_open ();
  emit_mode_name ();
  emit_mode_class ();
  emit_mode_precision ();
  emit_mode_size ();
  emit_mode_nunits ();
  emit_mode_wider ();
  emit_mode_complex ();
  emit_mode_mask ();
  emit_mode_inner ();
  emit_mode_unit_size ();
  emit_mode_unit_precision ();
  emit_mode_base_align ();
  emit_class_narrowest_mode ();
  emit_real_format_for_mode ();
  emit_mode_adjustments ();
  emit_mode_ibit ();
  emit_mode_fbit ();
  emit_mode_int_n ();
  print_mode_ns_close ();
}

static void
emit_min_insn_modes_c (void)
{
  emit_min_insn_modes_c_header ();
  emit_mode_name ();
  emit_mode_class ();
  emit_mode_nunits ();
  emit_mode_wider ();
  emit_mode_inner ();
  emit_class_narrowest_mode ();
}

/* Master control.  */
int
main (int argc, char **argv)
{
  bool gen_header = false, gen_inlines = false, gen_min = false;
  int i;
  progname = argv[0];

  for (i = 1; i < argc; i++)
    {
      if (!strcmp (argv[i], "-h"))
	gen_header = true;
      else if (!strcmp (argv[i], "-i"))
	gen_inlines = true;
      else if (!strcmp (argv[i], "-m"))
	gen_min = true;
      else if (!strcmp (argv[i], "-l"))
	gen_union_list = true;
      else if (!strcmp (argv[i], "-U") && i + 1 < argc)
	union_list_file = argv[++i];
      else if (!strcmp (argv[i], "-A") && i + 1 < argc)
	union_arch = argv[++i];
      else
	{
	  error ("usage: %s [-h|-i|-m|-l] [-U numbering [-A arch]] > file",
		 progname);
	  return FATAL_EXIT_CODE;
	}
    }

  if (gen_header + gen_inlines + gen_min + gen_union_list > 1)
    {
      error ("%s: -h, -i, -m and -l are mutually exclusive", progname);
      return FATAL_EXIT_CODE;
    }

  modes_by_name = htab_create_alloc (64, hash_mode, eq_mode, 0, xcalloc, free);

  create_modes ();
  complete_all_modes ();

  if (have_error)
    return FATAL_EXIT_CODE;

  calc_wider_mode ();

  /* After `calc_wider_mode', which is what puts each class's list in width
     order, and before anything is emitted: the shared numbering only moves
     values to other ordinals, it does not compute them.  */
  if (union_list_file)
    {
      read_union_list ();
      if (have_error)
	return FATAL_EXIT_CODE;
      apply_union_order ();
      if (have_error)
	return FATAL_EXIT_CODE;
    }

  if (gen_union_list)
    emit_union_list ();
  else if (gen_header)
    emit_insn_modes_h ();
  else if (gen_inlines)
    emit_insn_modes_inline_h ();
  else if (gen_min)
    emit_min_insn_modes_c ();
  else
    emit_insn_modes_c ();

  if (fflush (stdout) || fclose (stdout))
    return FATAL_EXIT_CODE;
  return SUCCESS_EXIT_CODE;
}
