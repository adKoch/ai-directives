# What a reader cannot see as it is: code points that hide or reorder text. Pure; takes a code point (a number).
# Tab and the line end are the layout of a text file; every other control character is hidden.

# A control character but tab and line end (a CR, an ESC, NUL, DEL and the C1 controls), a line or paragraph
# separator, a zero-width or invisible character, a mark that turns text around (bidi), a variation selector, a tag
# character, the byte-order mark, or a byte that is no UTF-8: jq reads such a byte as U+FFFD, so the replacement
# character counts as hidden too (a raw C1 byte such as 0x9B, the 8-bit CSI, reads as it).
def is_hidden:
  . < 9 or (. > 10 and . < 32) or (. >= 127 and . <= 159)
  or . == 1564                       # U+061C Arabic letter mark
  or (. >= 8203 and . <= 8207)       # U+200B to U+200F: zero-width characters, left-to-right and right-to-left marks
  or (. >= 8232 and . <= 8238)       # U+2028 to U+202E: separators and the bidi embeddings and overrides
  or (. >= 8288 and . <= 8303)       # U+2060 to U+206F: word joiner, invisible operators, bidi isolates
  or (. >= 65024 and . <= 65039)     # U+FE00 to U+FE0F: variation selectors
  or . == 65279                      # U+FEFF byte-order mark
  or . == 65533                      # U+FFFD: a byte that is no UTF-8, as jq reads it
  or (. >= 917504 and . <= 917631)   # U+E0000 to U+E007F: tag characters, which can spell text no one sees
  or (. >= 917760 and . <= 917999);  # U+E0100 to U+E01EF: the variation selectors supplement

# A code point a file name may not hold: a hidden one, or a tab or a line end, which no file name needs.
def is_hidden_in_a_name: is_hidden or . == 9 or . == 10;

# A byte outside printable ASCII, tab and the line end (invalid UTF-8 reads as U+FFFD, so it is outside too).
def is_outside_printable_ascii:
  (. < 9 or (. > 10 and . < 32) or . > 126);

# A file name (a string) as the scan prints it: every byte but a letter, a digit, `/` `-` `_` `.` `~` written as `%`
# and two hex digits, so a name may hold what it is searched for.
def shown_name: @uri | gsub("%2F"; "/");
