# Object-like and function-like macros a header defines, MINUS its own include
# guard.  Shared by mtO-optsmacro2.sh and by the eyeball count in the cause-8
# report, so that the two cannot drift.
#
# The guard is dropped only when it is the FIRST define in the file, matches
# the enclosing #ifndef, and has an EMPTY replacement list.  `#ifndef X' /
# `#define X 8' is NOT a guard, it is a defaultable value -- three of m32r's
# leaked macros are that shape and an earlier draft scored all three as guards.
#
# usage: awk -v tag=<something> -f mtO-hdrmacros.awk <header>
/^[ \t]*#[ \t]*ifndef[ \t]/ {
  line=$0; sub(/^[ \t]*#[ \t]*ifndef[ \t]+/,"",line); guard=line
  sub(/[^A-Za-z_0-9].*$/,"",guard); next
}
/^[ \t]*#[ \t]*define[ \t]/ {
  line=$0
  sub(/^[ \t]*#[ \t]*define[ \t]+/,"",line)
  name=line
  sub(/[^A-Za-z_0-9].*$/,"",name)
  body=substr(line, length(name)+1)
  sub(/^[ \t]+/,"",body); sub(/[ \t]+$/,"",body)
  if (name == guard && !dropped && body == "") { dropped=1; guard=""; next }
  print (tag == "" ? "" : tag "\t") name
}
