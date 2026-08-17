#!/bin/sh
# agent-ad6a5c1d2539f5e18-vbitsweep.sh -- BOTH-SIDED, over every target that
# has a specs-config in BOTH build dirs: did `TARGET_PTRMEMFUNC_VBIT_LOCATION'
# stop being the primary's?
#
# THE SHAPE THIS PROJECT TRUSTS: "N changed, M byte-identical, 0 differ".
# A one-sided run cannot separate "fixed" from "everyone now gets the same new
# answer", so PRE and POST are compiled from two build dirs and every target
# is scored, not only the ones expected to move.
#
# THREE ARMS, and the second and third are what make the first mean anything:
#
#  1. PRE vs POST on the whole `.s'.  A target whose own header agrees with
#     i386 must be BYTE-IDENTICAL; a target whose header disagrees must CHANGE.
#  2. THE NON-VIRTUAL CONTROL.  `mt_pmf_nonvirtual' has its vbit clear under
#     either convention, so its two words must be identical PRE and POST on
#     EVERY target.  If that moves, the comparison is measuring something other
#     than the vbit and the verdict is void.
#  3. THE CENSUS CROSS-CHECK.  The convention actually EMITTED at POST is read
#     back out of the assembly and compared against what that base's own header
#     chain says (agent-ad6a5c1d2539f5e18-vbitcensus.sh).  Arm 1 alone would
#     accept a change to the WRONG convention.
#
# The emitted convention is read from `mt_pmf_first', whose two words are
# `pfn=1, delta=0' under `vbit_in_pfn' and `pfn=0, delta=1' under
# `vbit_in_delta'.  Both are 2-word initialisers of whatever the target's
# pointer directive is (.quad/.xword/.long/.word/.4byte/.short/.byte), so the
# directive is not hardcoded -- 45 targets do not share one.
#
# NULL-RESULT ARM, FIRST AND FATAL.  A missing `cc1plus`, a target with no
# specs-config, an empty `.s' and a compiler that emitted nothing interesting
# all produce the same empty grep.  Every one of them fails BY NAME here, and
# the script refuses to print a verdict if it scored zero targets.
#
# usage: PRE=<dir> POST=<dir> agent-ad6a5c1d2539f5e18-vbitsweep.sh
set -u
S=$(cd "$(dirname "$0")" && pwd)
PRE=${PRE:?PRE build dir}
POST=${POST:?POST build dir}
IN=$S/agent-a260445cf27ba480a-ptrmem.cc
[ -s "$IN" ] || { echo "FATAL: no $IN"; exit 9; }

for D in "$PRE" "$POST"; do
  [ -x "$D/gcc/cc1plus" ] || { echo "FATAL: no $D/gcc/cc1plus -- a language that
  was never enabled and a language that passes everything give the same empty
  failure list, so this refuses rather than scoring zero"; exit 9; }
done
# `BASE-VER' is in the SRCDIR, not the build dir, and reading it from the build
# dir gives an empty version -- which makes every `lib/gcc//<target>' path miss
# and scores ZERO targets.  That looked exactly like "nothing to report" until
# the zero-targets refusal below said otherwise, which is why that refusal is
# in here.  Take the version from the artefact instead: `lib/gcc/<ver>/' is
# written by the specs run and there is exactly one.
verof () {                             # verof <builddir>
  set -- "$1"/lib/gcc/*/
  [ -d "$1" ] || return 1
  basename "$1"
}
VPRE=$(verof "$PRE")   || { echo "FATAL: no $PRE/lib/gcc/<ver>/ -- target-specs
  has not been run for this build dir, so there is nothing to compile against";
  exit 9; }
VPOST=$(verof "$POST") || { echo "FATAL: no $POST/lib/gcc/<ver>/"; exit 9; }
echo "PRE  $PRE  (gcc $VPRE)"
echo "POST $POST  (gcc $VPOST)"

W=$(mktemp -d); trap 'rm -rf "$W"' 0

# Targets present in BOTH.  A target only one side can compile is reported,
# never silently dropped: "not attempted" and "identical" are the same silence.
ls "$PRE/lib/gcc/$VPRE"  > "$W/pre.t"  2>/dev/null || : > "$W/pre.t"
ls "$POST/lib/gcc/$VPOST" > "$W/post.t" 2>/dev/null || : > "$W/post.t"
BOTH=$(comm -12 "$W/pre.t" "$W/post.t")
ONLY=$(comm -3 "$W/pre.t" "$W/post.t" | tr -d '\t')
[ -z "$ONLY" ] || echo "WARNING: targets in only one build dir: $ONLY"

emit () {                              # emit <builddir> <ver> <target> <out>
  ( cd "$1/gcc" && ./cc1plus -quiet -nostdinc -O2 \
      -ftarget-config="$1/lib/gcc/$2/$3/specs-config" "$IN" -o "$4" ) \
    > "$4.msg" 2>&1
}

# EVERY data operand of a named object, in emission order.
#
# THE FIRST VERSION OF THIS TOOK "the next two data-directive lines" AND IT WAS
# WRONG IN TWO INDEPENDENT WAYS, both of which showed up as an alarm rather
# than as a wrong green -- which is the only reason they were investigated
# instead of banked.  Recorded rather than quietly replaced, because both are
# shapes the next reader will reproduce:
#
#   * THE DIRECTIVE NAME IS NOT A CLOSED SET AND DOES NOT ALWAYS START WITH A
#     DOT.  bpf and cris emit `.dword'; ia64 emits `data8', with no leading
#     dot at all.  Missing a name made the extractor read NOTHING, which the
#     control arm then reported as CONTROL-MOVED -- "the reader failed" and
#     "the value moved" arriving as the same verdict.
#   * ONE FIELD IS NOT ONE LINE.  sparc64 emits each 8-byte field as EIGHT
#     `.byte' lines, so "the first two data lines" read the top two BYTES of
#     the pfn field -- `0, 0' on a big-endian target, which classified as
#     neither convention.
#   * THE TWO FIELDS ARE NOT ALWAYS THE SAME SIZE, so the obvious repair --
#     "split the operands in half" -- is ALSO wrong, and wrong exactly where
#     it is load-bearing.  avr's `mt_pmf_first' is `.word 0' plus four
#     `.byte's, `.size' 6: a 2-byte `pfn' and a 4-byte `delta'.  xstormy16 is
#     three `.hword's, likewise 2 + 4.  Halving puts the boundary at 3 bytes
#     and misclassifies both -- and avr is one of the eight back ends whose
#     answer this whole task is about.
#
# So the reader works in BYTE OFFSETS, and takes the field boundary from the
# NON-VIRTUAL CONTROL, the one object whose layout is known independently: its
# `pfn' is the function SYMBOL and its `delta' is zero, so the width of the
# directive carrying that symbol IS the width of `pfn'.
#
# DIRECTIVE WIDTHS ARE NOT TABULATED, because they are not portable: `.dword'
# is 8 on bpf and 4 on cris, `.word' is 2 on avr and 4 elsewhere.  `.byte' is 1
# by definition and the ONE remaining width is solved from the object's own
# `.size'.  Two unknown widths in one object is a REFUSAL, not a guess.
#
# `.zero'/`.space'/`.skip N' expands to N `.byte' zeros rather than being
# skipped: a padding directive dropped silently would shift the boundary and
# misclassify with no diagnostic.

# One line per operand: "<directive> <value>".
op_lines () {                          # op_lines <asm> <symbol>
  awk -v sym="$2:" '
    $0 == sym { p = 1; next }
    !p { next }
    $1 ~ /^(\.globl?|\.global|\.type|\.size|\.align|\.even|\.p2align|\.ident|\.section|\.data|\.text|\.local|\.comm|\.weak)$/ { exit }
    /:[ \t]*$/ { exit }
    {
      d = $1
      if (d ~ /^\.(zero|space|skip)$/) {
        for (i = 0; i < $2 + 0; i++) print ".byte 0"
        next
      }
      if (d ~ /^(\.|)(byte|short|hword|half|word|long|quad|xword|dword|octa|2byte|4byte|8byte|uahalf|uaword|uaxword)$/ \
          || d ~ /^data[1248]$/ || d ~ /^\.dc\.[abwl]$/) {
        rest = $0; sub (/^[ \t]*[^ \t]+[ \t]*/, "", rest)
        n = split (rest, a, /[ \t]*,[ \t]*/)
        for (i = 1; i <= n; i++) { gsub (/[ \t]/, "", a[i]); print d " " a[i] }
        next
      }
      # An unrecognised directive ENDS the object rather than being walked
      # past: reading on would silently drop bytes and move the boundary.
      exit
    }' "$1"
}

# `.size <sym>, <n>' -- emitted before the label.
sizeof_obj () {                        # sizeof_obj <asm> <symbol>
  awk -v s="$2," '$1 == ".size" && $2 == s { print $3 + 0; exit }' "$1"
}

# Solve the single non-`.byte' width in an operand list of known total size.
# Prints the width, or nothing if it cannot be solved.
solve_width () {                       # solve_width <total>   (op_lines on stdin)
  awk -v total="$1" '
    # NO APOSTROPHE ANYWHERE IN THIS awk PROGRAM.  It is inside a single-quoted
    # shell string, so one apostrophe in a comment CLOSES the quote, and the
    # rest of the program is re-parsed as shell.  That is what happened here:
    # the file still passed "sh -n", every function after this point silently
    # stopped existing, and the run reported 43 of 45 targets UNREADABLE with
    # "pfn_width: command not found".  Same family as the truncated generated
    # makefile PRINCIPLES records -- a quote in a comment, exit 0, wrong output.
    function known (d) {
      # NAMES WHOSE WIDTH IS THE SAME ON EVERY GNU TARGET.  Tabulated so that
      # an object mixing two of them can still be read: rl78 emits .short plus
      # .long (2 + 4, .size 6), which the solve-one-unknown rule below refuses
      # -- correctly, since it has two unknowns -- and which is perfectly
      # determined once these are known.
      if (d == ".byte" || d == "data1") return 1
      if (d == ".short" || d == ".hword" || d == ".half" || d == ".2byte" \
          || d == "data2") return 2
      if (d == ".long" || d == ".4byte" || d == "data4") return 4
      if (d == ".quad" || d == ".xword" || d == ".8byte" || d == "data8") return 8
      if (d == ".octa") return 16
      # .word is 2 on avr and pdp11 and 4 elsewhere; .dword is 4 on cris and 8
      # on bpf.  Not portable, so not tabulated -- solved instead.
      return 0
    }
    { dir[NR] = $1; val[NR] = $2 }
    END {
      fixed = 0; unk = ""; cnt = 0
      for (i = 1; i <= NR; i++) {
        w = known(dir[i])
        if (w) { fixed += w; continue }
        if (unk == "") unk = dir[i]
        else if (dir[i] != unk) exit          # two unknown widths: refuse
        cnt++
      }
      if (cnt == 0) { print "FIXED"; exit }   # every width already known
      w = (total - fixed) / cnt
      if (w == int (w) && w >= 1) print w
    }'
}

# The width of ONE operand, given the solved unknown width.
opw () {                               # opw <directive> <solved>
  case $1 in
    .byte|data1) echo 1 ;;
    .short|.hword|.half|.2byte|data2) echo 2 ;;
    .long|.4byte|data4) echo 4 ;;
    .quad|.xword|.8byte|data8) echo 8 ;;
    .octa) echo 16 ;;
    *) echo "$2" ;;
  esac
}

# The width of the `pfn' field, from the non-virtual control.
pfn_width () {                         # pfn_width <asm>
  _sz=$(sizeof_obj "$1" mt_pmf_nonvirtual)
  [ -n "$_sz" ] && [ "$_sz" -gt 0 ] || return 1
  _w=$(op_lines "$1" mt_pmf_nonvirtual | solve_width "$_sz")
  [ -n "$_w" ] || return 1
  # The directive carrying the SYMBOL is the `pfn' field, so its width is the
  # width of `pfn'.
  _d=$(op_lines "$1" mt_pmf_nonvirtual | awk '$2 ~ /[A-Za-z_]/ { print $1; exit }')
  [ -n "$_d" ] || return 1
  opw "$_d" "$_w"
}

# pfn / delta / unreadable, by the BYTE OFFSET of the nonzero operand.
shape () {                             # shape <asm> <symbol>
  _bw=$(pfn_width "$1") || { echo "unreadable(no-pfn-width)"; return; }
  _tot=$(sizeof_obj "$1" "$2")
  [ -n "$_tot" ] || { echo "unreadable(no-size)"; return; }
  _w=$(op_lines "$1" "$2" | solve_width "$_tot")
  [ -n "$_w" ] || { echo "unreadable(width-unsolved)"; return; }
  op_lines "$1" "$2" | awk -v bw="$_bw" -v w="$_w" -v total="$_tot" '
    function opw (d) {
      if (d == ".byte" || d == "data1") return 1
      if (d == ".short" || d == ".hword" || d == ".half" || d == ".2byte" \
          || d == "data2") return 2
      if (d == ".long" || d == ".4byte" || d == "data4") return 4
      if (d == ".quad" || d == ".xword" || d == ".8byte" || d == "data8") return 8
      if (d == ".octa") return 16
      return w + 0
    }
    { dir[NR] = $1; val[NR] = $2 }
    END {
      if (NR < 2) { print "unreadable(" NR " operands)"; exit }
      off = 0; lo = 0; hi = 0
      for (i = 1; i <= NR; i++) {
        if (val[i] !~ /^[0-9]+$/) { print "unreadable(non-numeric)"; exit }
        if (val[i] + 0 != 0) { if (off < bw) lo = 1; else hi = 1 }
        off += opw(dir[i])
      }
      # The bytes accounted for must equal the objects own `.size`.  This is
      # the arm that catches a directive walked past or a width solved wrong,
      # both of which otherwise produce a confident misclassification.
      if (off != total + 0) { print "unreadable(size-mismatch " off "!=" total ")"; exit }
      if (lo && !hi) print "pfn"
      else if (hi && !lo) print "delta"
      else if (!lo && !hi) print "unreadable(all-zero)"
      else print "unreadable(both-fields)"
    }'
}

nsame=0; nchg=0; nfail=0; nctl=0; nbad=0; ntot=0; nunread=0
printf '%-30s %-9s %-9s %-8s %s\n' TARGET PRE POST VERDICT CENSUS
for T in $BOTH; do
  [ -s "$PRE/lib/gcc/$VPRE/$T/specs-config" ] || continue
  [ -s "$POST/lib/gcc/$VPOST/$T/specs-config" ] || continue
  ntot=$((ntot + 1))
  A=$W/$T.pre.s; B=$W/$T.post.s
  emit "$PRE"  "$VPRE"  "$T" "$A"; ra=$?
  emit "$POST" "$VPOST" "$T" "$B"; rb=$?
  if [ "$ra" != 0 ] || [ "$rb" != 0 ] || [ ! -s "$A" ] || [ ! -s "$B" ]; then
    printf '%-30s %-9s %-9s %-8s %s\n' "$T" "rc=$ra" "rc=$rb" CC1PLUS-FAIL -
    sed -n 1,2p "$B.msg" | sed 's/^/    /'
    nfail=$((nfail + 1)); continue
  fi

  sa=$(shape "$A" mt_pmf_first); sb=$(shape "$B" mt_pmf_first)

  # THE READER'S OWN FAILURE IS A SEPARATE VERDICT FROM THE CONTROL MOVING.
  # Folding them cost an investigation: five targets whose assembler syntax
  # this script simply could not read were reported as CONTROL-MOVED, i.e. as
  # "the measurement is void", which is the same words as a real finding.
  case "$sa$sb" in
    *unreadable*)
      printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" UNREADABLE -
      nunread=$((nunread + 1)); continue ;;
  esac

  # ARM 2, the control, before any verdict is printed for this target.
  ca=$(op_lines "$A" mt_pmf_nonvirtual); cb=$(op_lines "$B" mt_pmf_nonvirtual)
  if [ -z "$ca" ]; then
    printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" CONTROL-UNREADABLE -
    nunread=$((nunread + 1)); continue
  fi
  if [ "$ca" != "$cb" ]; then
    printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" CONTROL-MOVED -
    nctl=$((nctl + 1)); continue
  fi

  if cmp -s "$A" "$B"; then v=identical; nsame=$((nsame + 1))
  else v=changed; nchg=$((nchg + 1)); fi

  # ARM 3.  What does this target's OWN header chain want?  Taken from the
  # census run beside this script, if the caller supplied one.
  want=-
  if [ -n "${CENSUS:-}" ] && [ -s "$CENSUS" ]; then
    b=$(awk -F: -v t="$T" '$2 == t { print $1 }' \
          "$S/agent-acda89931a903ec27-backends.txt")
    [ -n "$b" ] && want=$(awk -v b="$b" '$1 == b { if ($0 ~ /delta/) print "delta";
                                                   else if ($0 ~ /pfn/) print "pfn" }' \
                          "$CENSUS")
    [ -n "$want" ] || want='?'
    if [ "$want" != '-' ] && [ "$want" != '?' ] && [ "$want" != "$sb" ]; then
      want="$want!=EMITTED"; nbad=$((nbad + 1))
    fi
  fi
  printf '%-30s %-9s %-9s %-8s %s\n' "$T" "$sa" "$sb" "$v" "$want"
done

echo
echo "targets scored: $ntot   changed=$nchg  byte-identical=$nsame  differ(cc1plus failed)=$nfail"
echo "unreadable by this script: $nunread   control moved: $nctl   census disagrees with emitted: $nbad"
[ "$ntot" -gt 0 ] || { echo "FATAL: scored ZERO targets -- refusing to print a
  verdict.  A sweep that measured nothing and a sweep that found nothing wrong
  produce the same empty table."; exit 9; }
[ "$nctl" = 0 ] || { echo "FATAL: the non-virtual control moved on $nctl targets;
  the comparison is not measuring the vbit and the verdict is VOID"; exit 9; }
[ "$nbad" = 0 ] || { echo "FATAL: $nbad targets emit a convention their own
  header does not ask for"; exit 9; }
[ "$nchg" -gt 0 ] && [ "$nsame" -gt 0 ] \
  || echo "NOTE: one of the two columns is empty -- check that is expected."
