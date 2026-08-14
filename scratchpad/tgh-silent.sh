#!/bin/sh
# tgh-silent.sh -- close the SILENT half of the targhook matrix.
#
# THE SHAPE, AND WHY IT IS THE DANGEROUS HALF.  Two `targhooks.cc' defaults
# have an `#ifdef' with NO `#else':
#
#     default_external_libcall:  #ifdef ASM_OUTPUT_EXTERNAL_LIBCALL
#                                  ASM_OUTPUT_EXTERNAL_LIBCALL (asm_out_file, fun);
#                                #endif
#     default_debug_unwind_info: #ifdef DWARF2_DEBUGGING_INFO
#                                  if (dwarf_debuginfo_p ()) return UI_DWARF2;
#                                #endif
#
# Both primaries define both macros (via `gcc/config/elfos.h'), so in a
# multi-target binary the `#ifdef' is TRUE for a reason that has nothing to do
# with the back end being compiled for.  The four back ends that do NOT define
# them therefore get the primary's behaviour: an external-libcall directive
# emitted where upstream emits none, and UI_DWARF2 returned where upstream
# returns UI_NONE.  No ICE.  No diagnostic.  This is the branch's signature
# failure and it is invisible with two back ends, because both of them define
# the macros.
#
# WHOSE ANSWER THIS GIVES -- stated explicitly, per PRINCIPLES section 2a.
# This is a floor on the SUPPLY side, not the consumer side.  The value handed
# to each back end is the one UPSTREAM computes for that back end standing
# alone: with the macro undefined, `default_external_libcall' does nothing and
# `default_debug_unwind_info' falls through to UI_NONE.  It is that back end's
# own answer, not the primary's, and a second configured back end cannot change
# it.  Contrast the banned form, which would be giving these four back ends
# i386's `ASM_OUTPUT_EXTERNAL_LIBCALL' body because i386 happened to be built
# first -- which is exactly the behaviour being removed here.
#
# `tgh-hdrmatrix.sh' measured this population through the real tm.h chain, not
# by directory grep: 6 pairs over 4 back ends.  The directory grep said 90 over
# 45, because it cannot see `elfos.h'.
set -u
S=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$S/.." && pwd)
cd "$SRC" || exit 9

WANT=${WANT_ANCHOR:-47}
n=$(grep -c MULTI_TARGET gcc/Makefile.in)
[ "$n" = "$WANT" ] || { echo "FATAL: anchor=$n, expected exactly $WANT"; exit 9; }

# back end : which hooks it needs, as measured.
#   L = TARGET_ASM_EXTERNAL_LIBCALL   D = TARGET_DEBUG_UNWIND_INFO
WORK='microblaze:L mmix:L nvptx:LD pdp11:LD'

for w in $WORK; do
  b=${w%%:*}; k=${w##*:}
  f="gcc/config/$b/$b.cc"
  [ -f "$f" ] || { echo "FATAL: $f missing"; exit 9; }

  # REFUSE if the back end actually defines the macro -- that would mean the
  # measurement moved under us and this edit would be suppressing a real answer.
  case $k in *L*)
    grep -rqE '^[[:space:]]*#[[:space:]]*define[[:space:]]+ASM_OUTPUT_EXTERNAL_LIBCALL\>' \
      "gcc/config/$b/" && { echo "FATAL: $b DOES define ASM_OUTPUT_EXTERNAL_LIBCALL"; exit 9; } ;;
  esac
  case $k in *D*)
    grep -rqE '^[[:space:]]*#[[:space:]]*define[[:space:]]+DWARF2_DEBUGGING_INFO\>' \
      "gcc/config/$b/" && { echo "FATAL: $b DOES define DWARF2_DEBUGGING_INFO"; exit 9; } ;;
  esac

  BLK=$(mktemp)
  {
    echo "/* MULTI-TARGET, SILENT HALF.  This back end defines neither"
    echo "   \`ASM_OUTPUT_EXTERNAL_LIBCALL' nor (where noted) \`DWARF2_DEBUGGING_INFO',"
    echo "   but \`targhooks.cc' is compiled once against the PRIMARY's tm.h, where"
    echo "   \`elfos.h' defines both.  The \`#ifdef's have no \`#else', so instead of"
    echo "   an ICE this back end silently inherits the primary's behaviour."
    echo
    echo "   The values supplied here are UPSTREAM's own answers for this back end"
    echo "   standing alone -- with the macros undefined, default_external_libcall"
    echo "   emits nothing and default_debug_unwind_info returns UI_NONE.  A"
    echo "   supply-side floor giving a base its own documented value, not a"
    echo "   consumer-side fallback giving it somebody else's.  */"
    case $k in *L*)
      echo "#undef TARGET_ASM_EXTERNAL_LIBCALL"
      echo "#define TARGET_ASM_EXTERNAL_LIBCALL ${b}_mt_external_libcall" ;;
    esac
    case $k in *D*)
      echo "#undef TARGET_DEBUG_UNWIND_INFO"
      echo "#define TARGET_DEBUG_UNWIND_INFO ${b}_mt_debug_unwind_info" ;;
    esac
    echo
  } > "$BLK"

  FN=$(mktemp)
  : > "$FN"
  case $k in *L*)
    {
      echo "/* Upstream's default_external_libcall for a back end that does not"
      echo "   define ASM_OUTPUT_EXTERNAL_LIBCALL: the \`#ifdef' body is skipped, so"
      echo "   nothing is emitted.  (There is no hooks.h no-op with this signature;"
      echo "   \`hook_void_rtx' does not exist -- measured, it fails to compile.)  */"
      echo "static void"
      echo "${b}_mt_external_libcall (rtx)"
      echo "{"
      echo "}"
      echo
    } >> "$FN" ;;
  esac
  case $k in *D*)
    {
      echo "static enum unwind_info_type"
      echo "${b}_mt_debug_unwind_info (void)"
      echo "{"
      echo "  /* Neither DWARF2_FRAME_INFO nor DWARF2_DEBUGGING_INFO is defined for"
      echo "     this back end, so upstream's default_debug_unwind_info falls all the"
      echo "     way through.  */"
      echo "  return UI_NONE;"
      echo "}"
      echo
    } >> "$FN" ;;
  esac

  awk -v fn="$FN" -v blk="$BLK" '
    /^struct gcc_target targetm = TARGET_INITIALIZER;/ && !done {
      while ((getline l < fn) > 0) print l
      close (fn)
      while ((getline l < blk) > 0) print l
      close (blk); done = 1
    }
    { print }
  ' "$f" > "$f.new" || { echo "FATAL: awk failed on $f"; exit 9; }

  case $k in *L*)
    grep -q "^#define TARGET_ASM_EXTERNAL_LIBCALL ${b}_mt_external_libcall\$" "$f.new" \
      || { echo "FATAL: $b: libcall define absent after edit"; exit 9; }
    grep -q "^${b}_mt_external_libcall (rtx)\$" "$f.new" \
      || { echo "FATAL: $b: libcall body absent after edit"; exit 9; } ;;
  esac
  case $k in *D*)
    grep -q "^#define TARGET_DEBUG_UNWIND_INFO ${b}_mt_debug_unwind_info\$" "$f.new" \
      || { echo "FATAL: $b: unwind define absent after edit"; exit 9; }
    grep -q "^${b}_mt_debug_unwind_info (void)\$" "$f.new" \
      || { echo "FATAL: $b: unwind body absent after edit"; exit 9; } ;;
  esac
  cmp -s "$f" "$f.new" && { echo "FATAL: $b: byte-identical after edit"; exit 9; }
  mv "$f.new" "$f"; rm -f "$BLK" "$FN"
  echo "APPLIED $b ($k)"
done
