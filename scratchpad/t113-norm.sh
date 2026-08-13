#!/bin/sh
# Normalise a recipe to the text the SHELL actually receives.
#
# WHY THIS IS LEGITIMATE AND NOT "EDITING A PROBE UNTIL IT PASSES":
# make hands a recipe line to /bin/sh with its backslash-newline continuations
# intact, and sh joins them before executing.  So two recipes that differ ONLY
# in where the continuations fall are the same command.  $(call)/$(eval)
# collapses the continuations while the literal form keeps them; that is a
# difference in physical layout, not in what runs.
#
# The normalisation is applied IDENTICALLY to both sides, and arm 4 (the
# under-quoting injection) is what proves it has not been flattened into
# insensitivity: a real quoting error still shows through it.
sed -e 's/\\$//' "$1" | tr '\n' ' ' | tr -s ' \t' ' ' | sed -e 's/^ //' -e 's/ $//'
