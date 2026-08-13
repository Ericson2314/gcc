/* Minimal stand-in for the driver: it names one back end's spec-function
   table, exactly as spec-functions-select.cc does, and nothing else.  The only
   question it can answer is whether that table's own references are satisfied
   by the objects on the link line -- which is the question EXTRA_GCC_OBJS
   exists to answer, isolated from every other reason xgcc might not link.

   Used both ways: WITHOUT the back end's driver object the link must FAIL by
   name, and WITH it must succeed.  A one-sided run proves nothing.

   Linked against libiberty.a (for `concat') with a local `fancy_abort', which
   are the two NON-target references driver-arc.o makes and which the real xgcc
   line supplies from libiberty.a and libcommon.a.  Supplying them here keeps
   the only variable in the experiment the presence of the back end's own
   driver object; libcommon.a itself is not used because it drags in libcpp and
   buries the one symbol under 200 unrelated ones.  */
struct spec_function;
extern const struct spec_function extra_spec_functions_arc[];
const void *p = (const void *) extra_spec_functions_arc;

void fancy_abort (const char *, int, const char *) __attribute__ ((noreturn));
void fancy_abort (const char *, int, const char *) { __builtin_trap (); }

int main (void) { return p != 0; }
