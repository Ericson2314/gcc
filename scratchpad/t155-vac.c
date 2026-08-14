/* #155 -- the non-vacuity input for t155-compile.sh.
   It must provoke a COMPILE diagnostic containing "undeclared", so that a
   driver which cannot compile anything at all is distinguishable from one that
   compiles cleanly.  Both look like "no ICE" otherwise.  */
int f (void) { return not_a_declared_thing; }
