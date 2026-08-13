/* #133 -- the input on which STACK_DYNAMIC_OFFSET is observable at all.

   aarch64.h:1688 reserves STACK_CLASH_MIN_BYTES_OUTGOING_ARGS bytes of
   outgoing-argument space when

       flag_stack_clash_protection && cfun->calls_alloca
       && known_lt (crtl->outgoing_args_size,
		    STACK_CLASH_MIN_BYTES_OUTGOING_ARGS)

   so all three have to hold, or the macro's two arms agree and nothing moves.

     * `-fstack-clash-protection' on the command line;
     * `alloca' in the function, so `cfun->calls_alloca';
     * a call with FEW arguments, so `crtl->outgoing_args_size' is small --
       a call with none at all gives 0, which is still `known_lt' the
       minimum, but a one-argument call keeps the call sequence honest.

   Compile with -O2 -fstack-clash-protection.  */

extern int sink (char *);
extern void *alloca (__SIZE_TYPE__);

int
f (int n)
{
  char *p = (char *) alloca ((__SIZE_TYPE__) n);
  p[0] = (char) n;
  return sink (p);
}
