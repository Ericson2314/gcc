#!/bin/sh
# #172 arm 2 -- THE UNCONFIGURED-DEFAULT CLASS, swept.
#
# The class (PRINCIPLES section 4, "the silent-default variant"): an option
# variable carries an `Init (...)' that is NOT the target's real value; the
# real value is installed later by that back end's *_option_override (or, worse,
# only by TARGET_HANDLE_OPTION when a `-m' option is actually passed).  Shared
# code reading a tm.h macro whose body is that variable therefore gets the
# PRIMARY's UNCONFIGURED default -- correct for no back end at all.
#
#   ix86_pmode   Init (PMODE_SI)   promoted by ix86_option_override   -> #124
#   riscv MASK_64BIT in riscv_isa_flags, Init 0, set ONLY by
#                riscv_parse_arch_string from OPT_march_             -> #172
#
# FOUR ARMS, scored separately because they fail for different reasons:
#
#   1 INIT      the .opt record: back end, Var, Init text
#   2 OVERRIDE  is that Var assigned anywhere in the back end's own sources
#               outside the .opt file (i.e. does something promote it)?
#   3 MACRO     does one of the back end's HEADERS define a macro whose body
#               names that Var?  Only then can the value escape the back end.
#   4 SHARED    is such a macro spelled by a translation unit the generated
#               makefile compiles ONCE (shared), rather than per base?
#
# Arm 4's authority is the GENERATED makefile, never a path pattern:
# PRINCIPLES records an agent reporting a fix as a defect by assuming
# "outside gcc/config/" means "shared".  221 sources at gcc/ are per-base.
#
# usage: t172-initsweep.sh <srcdir> <builddir>
set -u
SRC=${1:?srcdir}
D=${2:-}
G=$SRC/gcc
[ -d "$G/config" ] || { echo "FATAL: $G/config missing"; exit 9; }

TMP=${TMPDIR:-/tmp}/t172-sweep.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# ---- ARM 1: every .opt record carrying BOTH Var() and Init().
# Mask(X) Var(V) records are collected too: their "Init" is the implicit 0,
# which is the riscv shape and the one an Init-only scan cannot see.
awk '
  FILENAME != prev { prev = FILENAME
                     n = split(FILENAME, a, "/"); be = a[n-1] }
  /Var *\(/ {
    v = $0; sub(/.*Var *\(/, "", v); sub(/[),].*/, "", v)
    if ($0 ~ /Init *\(/) {
      i = $0; sub(/.*Init *\(/, "", i); sub(/\).*/, "", i)
      print be "\t" v "\t" i "\tINIT"
    } else if ($0 ~ /(^|[^A-Za-z_])(Mask|InverseMask) *\(/) {
      m = $0; sub(/.*Mask *\(/, "", m); sub(/\).*/, "", m)
      print be "\t" v "\t" "0/MASK:" m "\tIMPLICIT0"
    }
  }
' "$G"/config/*/*.opt | sort -u > "$TMP/records"

nrec=$(wc -l < "$TMP/records")
[ "$nrec" -gt 100 ] || { echo "FATAL: only $nrec .opt records; the scan read nothing"; exit 9; }

# ---- ARMS 2-4, per (backend, var).
: > "$TMP/rows"
# The alias set for a Mask(M) Var(V) record is {V, TARGET_M}: optc-gen writes
# `#define TARGET_M ((V & MASK_M) != 0)' into the GENERATED options-<be>.h, and
# it is TARGET_M -- never V -- that the back end's own headers then spell.  A
# scan for V alone therefore misses the whole Mask population, which is
# #172's own subject:
#
#   riscv.opt  Mask(64BIT) Var(riscv_isa_flags)   ->  TARGET_64BIT
#   riscv.h    #define UNITS_PER_WORD (TARGET_64BIT ? 8 : 4)
#
# Measured: without this the sweep reports 55 pairs and NOT the one the task
# was opened for.  An instrument blind to the defect it was written for is
# worth nothing, so this arm runs before any population is quoted.
awk -F'\t' '{ split($3, m, ":"); if (m[2] != "") print $1 "\t" $2 "\tTARGET_" m[2]
              else print $1 "\t" $2 "\t" $2 }' "$TMP/records" \
  | sort -u > "$TMP/aliases"

# THE ROW KEY IS THE BIT, NOT THE VARIABLE, and getting that wrong gives the
# wrong answer for #172 itself.  riscv.opt puts MASK_64BIT, MASK_VECTOR and
# MASK_FULL_V in ONE Var(riscv_isa_flags); riscv.cc assigns MASK_VECTOR, so a
# per-variable row scores the whole word as promoted and riscv's word size
# comes out clean.  Per bit, MASK_64BIT is OPT-PARSE and MASK_VECTOR is
# OVERRIDE, which is what they are.
while IFS='	' read -r be v alias_re; do
  # ARM 2 -- WHO SUPPLIES THE REAL VALUE, and the three answers are three
  # different bugs, so they are scored apart rather than as one "is it set".
  #
  #   OVERRIDE   assigned in gcc/config/<be>/, i.e. by <be>_option_override,
  #              which RUNS whenever that back end is selected.  The leak
  #              window is "shared code reading it before the override" --
  #              the ix86_pmode / #124 shape.
  #   OPT-PARSE  assigned ONLY under common/config/<be>/, i.e. by
  #              TARGET_HANDLE_OPTION, which runs only if a `-m' option is
  #              actually PASSED.  Strictly worse: selecting the back end is
  #              not enough, and with nothing on the command line the Init
  #              stands for the whole compilation.  riscv's MASK_64BIT.
  #   INIT-ONLY  nothing assigns it; the Init IS the value.  No promotion to
  #              miss -- but if the macro escapes, it escapes as whichever
  #              back end's Init the shared object was linked with.
  # A Mask() record is asked about ITS BIT, not about the flags word.  This
  # correction is the difference between a right and a wrong answer for the
  # case that opened the task: riscv.cc assigns riscv_isa_flags in several
  # places (clearing vector bits, the target attribute), so asking about the
  # WORD scores riscv_isa_flags as OVERRIDE -- promoted, no bug.  Asking about
  # MASK_64BIT scores it OPT-PARSE, which is what it is: no override anywhere
  # touches that bit, and riscv_parse_arch_string off OPT_march_ is the only
  # thing that sets it.  Left in the script rather than swapped out silently,
  # so the next reader can see why the obvious per-variable check is wrong.
  case $alias_re in
    TARGET_*)
      # a Mask bit: ask whether anything names MASK_<bit>
      re="(^|[^A-Za-z0-9_])MASK_${alias_re#TARGET_}([^A-Za-z0-9_]|\$)" ;;
    *)
      re="(^|[^A-Za-z0-9_])(x_)?${v} *(\||&|\^|\+|-)?=[^=]" ;;
  esac
  in_be=no; in_common=no
  grep -rlqE "$re" "$G/config/$be" 2>/dev/null && in_be=yes
  grep -rlqE "$re" "$G/common/config/$be" 2>/dev/null && in_common=yes
  if [ "$in_be" = yes ]; then ovr=OVERRIDE
  elif [ "$in_common" = yes ]; then ovr=OPT-PARSE
  else ovr=INIT-ONLY
  fi

  # arm 3: a macro in this back end's headers whose BODY names the var.
  macs=$(grep -rhE "^ *# *define +[A-Za-z_][A-Za-z0-9_]*" \
           "$G/config/$be"/*.h 2>/dev/null \
         | awk -v v="$alias_re" '
             { line = $0
               sub(/^ *# *define +/, "", line)
               name = line; sub(/[ (].*/, "", name)
               body = line; sub(/^[^ ]*/, "", body)
               if (body ~ ("(^|[^A-Za-z0-9_])(" v ")([^A-Za-z0-9_]|$)")) print name }' \
         | sort -u | tr '\n' ' ')
  [ -n "$macs" ] || macs="-"
  if [ "$alias_re" = "$v" ]; then key=$v; else key="$v:${alias_re#TARGET_}"; fi
  printf '%s\t%s\t%s\t%s\n' "$be" "$key" "$ovr" "$macs" >> "$TMP/rows"
done < "$TMP/aliases"

# ---- ARM 4: which of those macros does a SHARED translation unit spell?
# Shared set from the generated makefile when one is available; the fallback is
# stated as a fallback rather than silently used, because "outside config/" is
# not "shared".
if [ -n "$D" ] && [ -f "$D/gcc/Makefile" ]; then
  # Objects with no mt-<base>/ prefix are the once-compiled ones.
  awk '/^[a-zA-Z0-9_\/-]+\.o *:/ && $0 !~ /mt-[a-z0-9_]*\// { print $1 }' \
    "$D/gcc/Makefile" | sed 's/\.o:*$//' | sort -u > "$TMP/shared-stems"
  SHAREDSRC=$(awk '{print $1}' "$TMP/shared-stems")
  SHAREDMODE="generated-makefile ($(wc -l < "$TMP/shared-stems") once-compiled stems)"
else
  SHAREDSRC=
  SHAREDMODE="NO BUILD DIR -- arm 4 NOT RUN (a path pattern is not an authority)"
fi

echo "== #172 unconfigured-default sweep"
echo "   srcdir     $SRC"
echo "   records    $nrec  (.opt lines with Var(), Init() or Mask())"
echo "   shared set $SHAREDMODE"
echo
printf '%-10s %-40s %-10s %s\n' BACKEND VAR:BIT PROMOTED MACROS-IN-HEADERS
sort "$TMP/rows" | while IFS='	' read -r be v ovr macs; do
  [ "$macs" = "-" ] && continue
  printf '%-10s %-40s %-10s %s\n' "$be" "$v" "$ovr" "$macs"
done

echo
echo "== population BY CAUSE (pairs that reach a header macro)"
awk -F'\t' '
  { tot++ ; if ($4 == "-") next ; mac++ ; c[$3]++ ; be[$1] = 1 ; bec[$3 "\t" $1] = 1 }
  END {
    printf "   %d (backend,var) pairs scanned\n", tot
    printf "   %d reach a header macro -- an escape route out of the back end\n\n", mac
    printf "   %-10s %6s %8s   %s\n", "CAUSE", "PAIRS", "BACKENDS", "leak window"
    printf "   %-10s %6d %8d   %s\n", "OVERRIDE",  c["OVERRIDE"],  n("OVERRIDE", bec),
           "before <be>_option_override runs"
    printf "   %-10s %6d %8d   %s\n", "OPT-PARSE", c["OPT-PARSE"], n("OPT-PARSE", bec),
           "ALWAYS, unless a -m option is passed"
    printf "   %-10s %6d %8d   %s\n", "INIT-ONLY", c["INIT-ONLY"], n("INIT-ONLY", bec),
           "the Init is the value; whose Init is linked?"
    k = 0; for (b in be) k++
    printf "\n   %d back ends affected in total\n", k
  }
  function n(cause, m,   k, key) { k = 0
    for (key in m) if (index(key, cause "\t") == 1) k++
    return k }' "$TMP/rows"

echo
echo "== BLIND SPOTS of this instrument, stated because a 0 from it is a claim"
echo "   about the instrument (PRINCIPLES section 4):"
echo "   * bare Mask(X) records with NO Var() -- they land in the SHARED"
echo "     global_options.x_target_flags and their bit numbering is per base."
printf '     Not scanned here: %s such records across the tree.\n' \
  "$(grep -hE '(^|[^A-Za-z_])(Mask|InverseMask) *\(' "$G"/config/*/*.opt \
     | grep -vc 'Var *(')"
echo "   * arm 3 reads gcc/config/<be>/*.h ONLY.  A macro defined in a"
echo "     generated header, or in gcc/config/*.h one level up (elfos.h et al,"
echo "     which PRINCIPLES records as 66 of 87 missed pairs in an earlier"
echo "     sweep), is invisible to it.  Upper bound, not lower."
echo "   * arm 2 is a grep for an assignment, not a reachability proof: a var"
echo "     assigned in dead code scores OVERRIDE."
