#!/bin/sh
# Every object-like macro a config/<cpu>/<cpu>-opts.h leaks into the shared
# options.h, MINUS its own include guard (which is the one #define every one of
# the 32 files has and which is not a leak).  A guard is recognised by being
# #defined immediately after an `#ifndef' of the same name on the line before.
#
# usage: mtO-optsmacro2.sh <gcc-srcdir>
set -e
S=${1:?gcc srcdir}
for f in "$S"/config/*/*-opts.h; do
  cpu=$(basename "$(dirname "$f")")
  awk -v cpu="$cpu" '
    /^[ \t]*#[ \t]*ifndef[ \t]/ { line=$0; sub(/^[ \t]*#[ \t]*ifndef[ \t]+/,"",line); guard=line
      sub(/[^A-Za-z_0-9].*$/,"",guard); next }
    /^[ \t]*#[ \t]*define[ \t]/ {
      line=$0
      sub(/^[ \t]*#[ \t]*define[ \t]+/,"",line)
      name=line
      sub(/[^A-Za-z_0-9].*$/,"",name)
      # The include guard, and ONLY the include guard, is dropped: it must be
      # the first such define in the file, match the enclosing #ifndef, and
      # have an EMPTY replacement list.  `#ifndef X / #define X 8'\'' is not a
      # guard, it is a defaultable value -- m32r'\''s SDATA_DEFAULT_SIZE,
      # M32R_MODEL_DEFAULT and M32R_SDATA_DEFAULT are that shape and an
      # earlier draft of this script silently scored all three as guards.
      body=substr(line, length(name)+1)
      sub(/^[ \t]+/,"",body); sub(/[ \t]+$/,"",body)
      if (name == guard && !dropped && body == "") { dropped=1; guard=""; next }
      # function-like when the char right after the name is an open paren
      rest=substr(line, length(name)+1, 1)
      kind = (rest == "(") ? "FUNC" : "OBJ"
      print cpu "\t" kind "\t" name
    }
  ' "$f"
done
