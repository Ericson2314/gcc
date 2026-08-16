/* TARGET_PTRMEMFUNC_VBIT_LOCATION, observable in a static initialiser.

   A pointer to a VIRTUAL member function is a { ptrdiff_t pfn; ptrdiff_t delta }
   pair, and the bit saying "this is virtual" lives in one field or the other:

     ptrmemfunc_vbit_in_pfn     i386 (i386.h:832)         pfn = index*size + 1, delta = 0
     ptrmemfunc_vbit_in_delta   aarch64 arm mips          pfn = index*size,     delta = 1
                                loongarch arc

   `cp/typeck.cc' reads the macro and `cp/*.o' are SHARED translation units, so
   whichever answer the shared `tm.h' carries is the answer all 47 back ends
   get.  The two layouts are not compatible: a compiler emitting the i386 form
   for aarch64 produces objects no correct aarch64 C++ compiler can link
   against, silently.

   -O2, no headers, no libstdc++.  */

struct C { virtual void f (); virtual void g (); };

void (C::*mt_pmf_first) () = &C::f;
void (C::*mt_pmf_second) () = &C::g;

/* A non-virtual one, as the control: its vbit is clear either way, so this
   symbol must be IDENTICAL between the two targets and any difference here
   means the comparison is measuring something else.  */
struct D { void h (); };
void (D::*mt_pmf_nonvirtual) () = &D::h;
