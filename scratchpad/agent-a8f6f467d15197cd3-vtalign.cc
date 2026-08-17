/* Input for agent-a8f6f467d15197cd3-vtalignsweep.sh.

   `mt_va_key' has a virtual function whose first non-inline definition is in
   this translation unit, so the vtable is EMITTED here (the key-function
   rule) rather than left to a COMDAT in some other object.  That matters:
   `cp/class.cc:840' calls `SET_DECL_ALIGN (decl, TARGET_VTABLE_ENTRY_ALIGN)'
   on the vtable decl, and an alignment on a decl nobody emits is invisible.

   `mt_va_control' is the CONTROL: an ordinary array of the same size with no
   vtable at all.  Its alignment comes from the type, not from
   `TARGET_VTABLE_ENTRY_ALIGN', so it must be BYTE-IDENTICAL PRE and POST on
   every target.  If it moves, the comparison is measuring something other
   than this macro and the run is void rather than green.  */

struct mt_va_key
{
  virtual void f ();
  virtual void g ();
  int x;
};

void mt_va_key::f () { x = 1; }   /* key function: forces the vtable out here */
void mt_va_key::g () { x = 2; }

/* A second, unrelated vtable, so a per-object accident cannot pass as a rule. */
struct mt_va_key2
{
  virtual int h ();
};

int mt_va_key2::h () { return 3; }

/* THE CONTROL.  No virtual anything. */
struct mt_va_plain { int a; int b; };
mt_va_plain mt_va_control = { 4, 5 };
