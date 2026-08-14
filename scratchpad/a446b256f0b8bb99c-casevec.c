/* CASE_VECTOR_MODE reproducer.  A switch big enough to build a real jump
   table (a switch whose arms are constant returns becomes a decision tree and
   never builds one at all -- the sibling task hit exactly that and recorded
   it), calling an extern function so no arm folds away.

   Compile at -O1 -fPIC.  The PIC is the point: aarch64's CASE_VECTOR_MODE is
   Pmode, and i386's is
     (!TARGET_LP64 || (flag_pic && ix86_cmodel != CM_LARGE_PIC) ? SImode
                                                                : DImode)
   so the two agree at DImode only while flag_pic is 0.  */
extern void h (int);

void
f (int x)
{
  switch (x)
    {
    case 0:  h (100); break;
    case 1:  h (101); break;
    case 2:  h (102); break;
    case 3:  h (103); break;
    case 4:  h (104); break;
    case 5:  h (105); break;
    case 6:  h (106); break;
    case 7:  h (107); break;
    case 8:  h (108); break;
    case 9:  h (109); break;
    case 10: h (110); break;
    case 11: h (111); break;
    case 12: h (112); break;
    case 13: h (113); break;
    case 14: h (114); break;
    case 15: h (115); break;
    case 16: h (116); break;
    case 17: h (117); break;
    case 18: h (118); break;
    case 19: h (119); break;
    case 20: h (120); break;
    case 21: h (121); break;
    case 22: h (122); break;
    case 23: h (123); break;
    default: h (999); break;
    }
}
