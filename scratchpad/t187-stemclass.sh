#!/bin/sh
# #187 -- for each build-root header stem, WHICH bases' copies is it identical
# to?  Three outcomes and they are not the same claim:
#
#   equal to ALL bases   the stem is unioned; reading the root copy is not a
#                        leak of presence.
#   equal to EXACTLY ONE the root copy IS that base's file under a neutral
#                        name.  This is the primary leak, unambiguously, and
#                        it is what the acceptance arm fails on.
#   equal to NONE        undecided from md5 alone -- a union generated
#                        separately (options.h, insn-modes.h) looks exactly
#                        like a per-base file nobody matched.  Resolved by the
#                        NAME-SET arm below, never by assumption.
#
# usage: t187-stemclass.sh <builddir>
set -u
G=${1:?build dir}/gcc
BASES=$(ls -d "$G"/*-inc 2>/dev/null | sed -e "s|^$G/||" -e 's|-inc$||' | sort)
[ -n "$BASES" ] || { echo "FATAL: no <base>-inc dirs in $G"; exit 9; }
STEMS=$(ls "$G"/*-inc/*.h 2>/dev/null | sed 's|.*/||' | sort -u | grep -v '^mt-inc-tag-')

resolve () {   # <base> <stem> -> path of the REAL header behind the forwarder
  f=$G/$1-inc/$2
  [ -f "$f" ] || return 1
  real=$(sed -n '1s/^#include "\(.*\)"$/\1/p' "$f")
  if [ -n "$real" ] && [ -f "$G/$real" ]; then echo "$G/$real"; else echo "$f"; fi
}

# The name set of a header: every identifier it #defines.  Cheap, and it is
# the property that decides `union or one base's': a union defines the names
# of every base, a per-base file defines one base's.
names () { grep -hoE '^[[:space:]]*#[[:space:]]*define[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$1" \
             | awk '{print $NF}' | sort -u; }

printf '%-22s %-12s %-6s %s\n' stem root neq class
for s in $STEMS; do
  [ -f "$G/$s" ] || { printf '%-22s %-12s %-6s %s\n' "$s" - - "no-build-root-copy"; continue; }
  r=$(md5sum "$G/$s" | cut -c1-12)
  eq=""; n=0
  for b in $BASES; do
    f=$(resolve "$b" "$s") || continue
    n=$((n + 1))
    [ "$(md5sum "$f" | cut -c1-12)" = "$r" ] && eq="$eq $b"
  done
  cnt=$(echo $eq | wc -w)
  # ARM (#193): COMMENT-ONLY DIVERGENCE.  md5 equality to exactly one base is
  # the primary-leak verdict, and for two stems it is produced by a COMMENT.
  # Every generated header genmodes writes opens with
  #     /* Generated automatically from machmode.def and
  #        config/<be>/<be>-modes.def  by genmodes.  */
  # and stamps each enumerator with `/* config/<be>/<be>-modes.def:NN */'.
  # Those name the back end, so every base's file differs from every other's
  # while the C does not: measured, `insn-modes-inline.h' has ONE distinct
  # body across all 47 bases and still classifies `PER-BASE-it-is i386' here.
  #
  # REPORTED, NOT SUBTRACTED.  The verdict is deliberately left alone -- a
  # stem staying on the leak list costs nothing, and moving one off it on a
  # comment-stripping heuristic is the shape of §2a's "deleting a check that
  # fails".  The annotation tells the reader which of the two a stem is.
  # `insn-modes.h' keeps a real divergence (NUM_INT_N_ENTS, and the
  # PSImode/CPSImode aliases avr and msp430 collide on) and is NOT annotated.
  ann=""
  if [ "$cnt" -ge 1 ] && [ "$cnt" -lt "$n" ]; then
    nosee () { sed -e 's,/\*[^*]*\*/,,g' -e '1,2d' -e 's/[[:space:]]*$//' "$1"; }
    nosee "$G/$s" > /tmp/t187-cm-root.$$
    same=0; tot=0
    for b in $BASES; do
      f=$(resolve "$b" "$s") || continue
      tot=$((tot + 1))
      nosee "$f" > /tmp/t187-cm-b.$$
      cmp -s /tmp/t187-cm-root.$$ /tmp/t187-cm-b.$$ && same=$((same + 1))
    done
    rm -f /tmp/t187-cm-root.$$ /tmp/t187-cm-b.$$
    [ "$same" = "$tot" ] && ann="  [COMMENT-ONLY: identical to all $tot bases once comments and the 2-line provenance header are removed]"
  fi
  if [ "$cnt" = "$n" ]; then cls="UNIONED-identical-to-all-$n"
  elif [ "$cnt" = 1 ]; then cls="PER-BASE-it-is$eq$ann"
  elif [ "$cnt" = 0 ]; then
    # ARM: THE CONFIG-DIR SET.  `tm.h' and `tm_p.h' are include CHAINS, not
    # definition files, so a #define name set says almost nothing about them
    # -- which is why they land here.  What identifies them exactly is the set
    # of `config/<dir>/...' headers they pull in.  If the root copy's set is
    # the same as exactly one base's, the root copy IS that back end's chain
    # wearing a target-neutral filename, and that is the whole bug.
    cfg () { grep -hoE '"config/[A-Za-z0-9_./-]+"' "$1" | sort -u; }
    cfg "$G/$s" > /tmp/t187-cf-root.$$
    if [ -s /tmp/t187-cf-root.$$ ]; then
      hit=""; nh=0
      for b in $BASES; do
        f=$(resolve "$b" "$s") || continue
        cfg "$f" > /tmp/t187-cf-b.$$
        if cmp -s /tmp/t187-cf-root.$$ /tmp/t187-cf-b.$$; then hit="$hit $b"; nh=$((nh + 1)); fi
      done
      rm -f /tmp/t187-cf-b.$$
      if [ "$nh" = 1 ]; then
        rm -f /tmp/t187-cf-root.$$
        printf '%-22s %-12s %-6s %s\n' "$s" "$r" "$cnt/$n" "PER-BASE-by-config-chain-it-is$hit"
        continue
      fi
    fi
    rm -f /tmp/t187-cf-root.$$
    # ARM: NAME-SET EQUALITY.  Two files can differ byte for byte (a comment,
    # a guard, an ordering) and still define exactly one back end's set of
    # names.  If the root's set equals exactly one base's, that is the same
    # finding as byte equality and must not be lost to it.
    names "$G/$s" > /tmp/t187-ns-root.$$
    eqn=""; nen=0
    for b in $BASES; do
      f=$(resolve "$b" "$s") || continue
      names "$f" > /tmp/t187-ns-b.$$
      if cmp -s /tmp/t187-ns-root.$$ /tmp/t187-ns-b.$$; then eqn="$eqn $b"; nen=$((nen + 1)); fi
    done
    rm -f /tmp/t187-ns-b.$$ /tmp/t187-ns-root.$$
    if [ "$nen" -ge 1 ] && [ "$nen" -lt "$n" ]; then
      printf '%-22s %-12s %-6s %s\n' "$s" "$r" "$cnt/$n" "PER-BASE-by-name-set-it-is$eqn"
      continue
    fi
    # Undecided by md5.  Ask whether the root's #define set is a SUPERSET of
    # every base's (a union) or looks like one base's alone.
    names "$G/$s" > /tmp/t187-nm-root.$$
    sup=1; best=""; bestn=-1
    for b in $BASES; do
      f=$(resolve "$b" "$s") || continue
      names "$f" > /tmp/t187-nm-b.$$
      miss=$(comm -23 /tmp/t187-nm-b.$$ /tmp/t187-nm-root.$$ | wc -l)
      [ "$miss" = 0 ] || sup=0
      common=$(comm -12 /tmp/t187-nm-b.$$ /tmp/t187-nm-root.$$ | wc -l)
      [ "$common" -gt "$bestn" ] && { bestn=$common; best=$b; }
    done
    rm -f /tmp/t187-nm-b.$$ /tmp/t187-nm-root.$$
    if [ "$sup" = 1 ]; then cls="UNIONED-by-name-set-superset-of-all-$n"
    else
      # ARM (#193): THE EXCLUSIVE-NAME ARM, WHICH SETTLES `options.h'.
      #
      # A header can be neither a copy of any base nor the union of all of
      # them and STILL be one back end's, and `options.h' is exactly that: the
      # `struct gcc_options' member set is unioned, so it carries names no
      # single base has, while `s-options-h' generates it with
      # `-v union_base=$(multi_target_base)' so the MACROS are one base's.
      # Set equality and superset-ness both decline, correctly, and #187 left
      # it UNDECIDED rather than guessing.
      #
      # What decides it is the EXCLUSIVE set: for each base, the names no
      # OTHER base defines.  A neutral header shares none of anybody's; a
      # header generated for base B carries B's.  Measured on `options.h' in a
      # 47-base build: i386 828 of its 829 exclusive names are in the shared
      # header, and every other back end contributes 0.  That is not a close
      # call and it is not a heuristic -- it names the back end and says how
      # much of it is visible.
      excl_all=/tmp/t187-ex-all.$$
      names "$G/$s" > /tmp/t187-ex-root.$$
      win=""; winn=0; winof=0; nz=0
      for b in $BASES; do
        f=$(resolve "$b" "$s") || continue
        names "$f" > /tmp/t187-ex-b.$$
        : > "$excl_all"
        for o in $BASES; do
          [ "$o" = "$b" ] && continue
          g=$(resolve "$o" "$s") || continue
          names "$g" >> "$excl_all"
        done
        sort -u "$excl_all" -o "$excl_all"
        comm -23 /tmp/t187-ex-b.$$ "$excl_all" > /tmp/t187-ex-x.$$
        nx=$(wc -l < /tmp/t187-ex-x.$$)
        nin=$(comm -12 /tmp/t187-ex-x.$$ /tmp/t187-ex-root.$$ | wc -l)
        [ "$nin" -gt 0 ] && nz=$((nz + 1))
        [ "$nin" -gt "$winn" ] && { winn=$nin; win=$b; winof=$nx; }
      done
      rm -f /tmp/t187-ex-root.$$ /tmp/t187-ex-b.$$ /tmp/t187-ex-x.$$ "$excl_all"
      if [ "$nz" = 1 ]; then
        cls="PER-BASE-by-exclusive-names-it-is $win ($winn of its $winof back-end-private names are in the shared copy; every other base contributes 0)"
      elif [ "$nz" = 0 ]; then
        cls="NEUTRAL-by-exclusive-names-no-base-private-name-is-in-the-shared-copy"
      else
        cls="UNDECIDED-not-a-superset-closest=$best ($nz bases contribute private names; top $win with $winn)"
      fi
    fi
  else cls="PER-BASE-shared-by$eq"
  fi
  printf '%-22s %-12s %-6s %s\n' "$s" "$r" "$cnt/$n" "$cls"
done
