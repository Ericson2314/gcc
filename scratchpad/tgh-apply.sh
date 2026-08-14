#!/bin/sh
# tgh-apply.sh -- supply, per back end, the `targhooks.cc' defaults the PRIMARY
# was answering.
#
# WHOSE ANSWER EACH WRAPPER GIVES.  Every wrapper below expands the back end's
# OWN `tm.h' macro in the back end's OWN translation unit.  That is not a
# fallback and not a floor: it is precisely what a single-target build of that
# back end computes today.  No back end ever reads another's value, and nothing
# is invented -- if a back end did not define the macro it gets no wrapper and
# stays on the shared default, loudly or otherwise.  This is the `d65b829e7a8'
# (rs6000) shape applied to the other thirty-six back ends the matrix names.
#
# The insertion point is immediately before `struct gcc_target targetm =
# TARGET_INITIALIZER;'.  That is the one place in every back end where both
# requirements hold at once: the wrapper is DEFINED before the initializer
# reads its address, and the `#define TARGET_*' is in effect when
# TARGET_INITIALIZER expands.  Appending at end of file gives a definition the
# initializer never sees; putting the #defines at the top gives a name with no
# definition.  Both were considered and both are wrong.
#
# Reads its work list from a file of `<backend> <MACRO> <HOOK>' lines --
# mta7-targhook-matrix2.sh's actionable ICE section -- rather than carrying
# one, so it cannot drift from the instrument.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
LIST=${1:?work list: '<backend> <MACRO> <HOOK>' per line}
[ -s "$LIST" ] || { echo "FATAL: work list $LIST empty/missing"; exit 9; }

WANT=${WANT_ANCHOR:-47}
n=$(grep -c MULTI_TARGET "$SRC/gcc/Makefile.in")
[ "$n" = "$WANT" ] || { echo "FATAL: $SRC anchor=$n, expected exactly $WANT"; exit 9; }

emit () {  # $1 = back end, $2 = macro
  b=$1; m=$2
  case $m in
  PRINT_OPERAND)
    cat <<EOF
static void
${b}_mt_print_operand (FILE *stream, rtx x, int code)
{
  PRINT_OPERAND (stream, x, code);
}
EOF
    ;;
  PRINT_OPERAND_ADDRESS)
    cat <<EOF
static void
${b}_mt_print_operand_address (FILE *stream, machine_mode, rtx x)
{
  PRINT_OPERAND_ADDRESS (stream, x);
}
EOF
    ;;
  PRINT_OPERAND_PUNCT_VALID_P)
    cat <<EOF
static bool
${b}_mt_print_operand_punct_valid_p (unsigned char code)
{
  return PRINT_OPERAND_PUNCT_VALID_P (code);
}
EOF
    ;;
  FUNCTION_VALUE)
    cat <<EOF
static rtx
${b}_mt_function_value (const_tree ret_type, const_tree fn_decl_or_type, bool)
{
  /* The old interface does not handle receiving the function type; this is
     default_function_value's own preamble, kept so the wrapper is behaviourally
     identical to the default it replaces.  */
  if (fn_decl_or_type && !DECL_P (fn_decl_or_type))
    fn_decl_or_type = NULL;
  return FUNCTION_VALUE (ret_type, fn_decl_or_type);
}
EOF
    ;;
  LIBCALL_VALUE)
    cat <<EOF
static rtx
${b}_mt_libcall_value (machine_mode mode, const_rtx)
{
  return LIBCALL_VALUE (MACRO_MODE (mode));
}
EOF
    ;;
  FUNCTION_VALUE_REGNO_P)
    cat <<EOF
static bool
${b}_mt_function_value_regno_p (const unsigned int regno)
{
  return FUNCTION_VALUE_REGNO_P (regno);
}
EOF
    ;;
  CLASS_MAX_NREGS)
    cat <<EOF
static unsigned char
${b}_mt_class_max_nregs (reg_class_t rclass, machine_mode mode)
{
  return (unsigned char) CLASS_MAX_NREGS ((enum reg_class) rclass,
					  MACRO_MODE (mode));
}
EOF
    ;;
  PREFERRED_RELOAD_CLASS)
    cat <<EOF
static reg_class_t
${b}_mt_preferred_reload_class (rtx x, reg_class_t rclass)
{
  return (reg_class_t) PREFERRED_RELOAD_CLASS (x, (enum reg_class) rclass);
}
EOF
    ;;
  PROFILE_BEFORE_PROLOGUE)
    cat <<EOF
static bool
${b}_mt_profile_before_prologue (void)
{
  /* default_profile_before_prologue returns true exactly when the macro is
     defined; this back end defines it.  */
  return true;
}
EOF
    ;;
  *) echo "FATAL: no template for $m" 1>&2; exit 9 ;;
  esac
}

fname () {  # $1 = back end, $2 = macro -> wrapper function name
  case $2 in
  PRINT_OPERAND)               echo "$1_mt_print_operand" ;;
  PRINT_OPERAND_ADDRESS)       echo "$1_mt_print_operand_address" ;;
  PRINT_OPERAND_PUNCT_VALID_P) echo "$1_mt_print_operand_punct_valid_p" ;;
  FUNCTION_VALUE)              echo "$1_mt_function_value" ;;
  LIBCALL_VALUE)               echo "$1_mt_libcall_value" ;;
  FUNCTION_VALUE_REGNO_P)      echo "$1_mt_function_value_regno_p" ;;
  CLASS_MAX_NREGS)             echo "$1_mt_class_max_nregs" ;;
  PREFERRED_RELOAD_CLASS)      echo "$1_mt_preferred_reload_class" ;;
  PROFILE_BEFORE_PROLOGUE)     echo "$1_mt_profile_before_prologue" ;;
  *) echo "FATAL"; exit 9 ;;
  esac
}

TEMPLATABLE='PRINT_OPERAND PRINT_OPERAND_ADDRESS PRINT_OPERAND_PUNCT_VALID_P
FUNCTION_VALUE LIBCALL_VALUE FUNCTION_VALUE_REGNO_P CLASS_MAX_NREGS
PREFERRED_RELOAD_CLASS PROFILE_BEFORE_PROLOGUE'

BES=$(awk '{print $1}' "$LIST" | sort -u)
NAPP=0; NSKIP=0
for b in $BES; do
  f="$SRC/gcc/config/$b/$b.cc"
  [ -f "$f" ] || { echo "SKIP $b: no $b.cc"; continue; }
  grep -q 'TARGET_INITIALIZER;' "$f" \
    || { echo "SKIP $b: no TARGET_INITIALIZER; in $b.cc"; continue; }

  ms=""
  for m in $(awk -v b="$b" '$1==b{print $2}' "$LIST"); do
    ok=0
    for t in $TEMPLATABLE; do [ "$t" = "$m" ] && ok=1; done
    if [ "$ok" = 0 ]; then
      echo "DEFER $b $m (no safe template -- reported, not fixed)"
      NSKIP=$((NSKIP + 1))
      continue
    fi
    ms="$ms $m"
  done
  [ -n "$ms" ] || continue

  BLK=$(mktemp)
  {
    echo "/* MULTI-TARGET: hooks this back end never needed to supply, because"
    echo "   \`targhooks.cc' answered from its own \`#ifdef <tm.h macro>'.  That"
    echo "   file is compiled ONCE, against the PRIMARY's tm.h, so in a"
    echo "   multi-target binary the \`#ifdef' is resolved for somebody else and"
    echo "   this back end gets the \`#else' arm -- \`gcc_unreachable ()' for some"
    echo "   of these, and a silently wrong generic answer for the rest."
    echo
    echo "   Each wrapper expands THIS back end's own macro in THIS back end's"
    echo "   own translation unit against its own tm.h.  That is the per-base"
    echo "   answer, identical to what a single-target build computes -- not a"
    echo "   fallback and not a floor.  See scratchpad/mta7-targhook-matrix2.sh"
    echo "   and commit d65b829e7a8, which did this for rs6000 first.  */"
    echo
    for m in $ms; do
      emit "$b" "$m"
      echo
    done
    for m in $ms; do
      h=$(awk -v b="$b" -v m="$m" '$1==b && $2==m{print $3}' "$LIST")
      echo "#undef $h"
      echo "#define $h $(fname "$b" "$m")"
    done
    echo
  } > "$BLK"

  awk -v blk="$BLK" '
    /^struct gcc_target targetm = TARGET_INITIALIZER;/ && !done {
      while ((getline l < blk) > 0) print l
      close (blk); done = 1
    }
    { print }
  ' "$f" > "$f.new" || { echo "FATAL: awk failed on $f"; exit 9; }

  # ASSERT THE EDIT PRODUCED THE STATE INTENDED, not merely that awk exited 0.
  # A generator that runs and changes nothing is this project's third-recorded
  # false green.
  for m in $ms; do
    fn=$(fname "$b" "$m")
    grep -q "^$fn (" "$f.new" \
      || { echo "FATAL: $b: wrapper $fn absent after edit"; exit 9; }
    h=$(awk -v b="$b" -v m="$m" '$1==b && $2==m{print $3}' "$LIST")
    grep -q "^#define $h $fn\$" "$f.new" \
      || { echo "FATAL: $b: '#define $h $fn' absent after edit"; exit 9; }
  done
  cmp -s "$f" "$f.new" && { echo "FATAL: $b: file byte-identical after edit"; exit 9; }
  mv "$f.new" "$f"
  rm -f "$BLK"
  echo "APPLIED $b:$(echo $ms | tr ' ' ',')"
  NAPP=$((NAPP + $(echo $ms | wc -w)))
done
echo
echo "applied=$NAPP deferred=$NSKIP over $(echo $BES | wc -w) back ends"
