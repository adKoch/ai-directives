# What a reader cannot see as it is: code points that hide or reorder text. Pure; takes a code point (a number).
# Tab and the line end are the layout of a text file; every other control character is hidden.

# A control character but tab and line end (a CR, an ESC, NUL, DEL and the C1 controls), a line or paragraph
# separator, a zero-width or invisible character, a mark that turns text around (bidi), or the byte-order mark.
def is_hidden:
  . < 9 or (. > 10 and . < 32) or (. >= 127 and . <= 159)
  or . == 1564                   # U+061C Arabic letter mark
  or (. >= 8203 and . <= 8207)   # U+200B to U+200F: zero-width characters, left-to-right and right-to-left marks
  or (. >= 8232 and . <= 8238)   # U+2028 to U+202E: separators and the bidi embeddings and overrides
  or (. >= 8288 and . <= 8303)   # U+2060 to U+206F: word joiner, invisible operators, bidi isolates
  or . == 65279;                 # U+FEFF byte-order mark

# A byte outside printable ASCII, tab and the line end (invalid UTF-8 reads as U+FFFD, so it is outside too).
def is_outside_printable_ascii:
  (. < 9 or (. > 10 and . < 32) or . > 126);
