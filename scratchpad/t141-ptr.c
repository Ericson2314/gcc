/* #141 -- the option-state family's behavioural probe.
   Every construct here is chosen so its EMITTED FORM depends on POINTER_SIZE
   (and, through defaults.h's derivation ladder, on DWARF2_ADDR_SIZE):
     - `sizeof (struct S)' is emitted as a .word/.xword INITIALISER, so the
       struct layout appears in the assembly as a number rather than only in
       the compiler's internal state;
     - the address arithmetic in `g' selects w-register or x-register forms;
     - `.eh_frame' addresses are emitted at DWARF2_ADDR_SIZE width.
   Deliberately small: `big.c' cannot be used for the aarch64 arms because
   under `-mabi=ilp32' it ICEs in `add_clobbers, at config/i386/sync.md:2483'
   -- i386's recog matching an aarch64 compilation, the per-base recog
   blocker recorded in STATE.md #138, which is a different conversion from
   this one and would mask this arm rather than inform it.  */
struct S { char c; void *p; int a[3]; };
unsigned long sz = sizeof (struct S);
void *g (struct S *s, int i) { return &s->a[i]; }
long diff (char *a, char *b) { return a - b; }
