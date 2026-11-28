# Text a tool of the collector's said on its stderr, one line at a time, as text that is safe to print on a terminal:
# it names the project's paths, which a person chose. Every character but printable ASCII is written as `\u{<hex>}`,
# and a backslash as `\\`, so an escape the path really holds never reads as one made here (as ctxm's `escaped`).
# Pure; needs nothing.

def hex_digits: if . < 16 then "0123456789abcdef"[.:. + 1] else (. / 16 | floor | hex_digits) + (. % 16 | hex_digits) end;

def escaped_character:
  if . == 92 then "\\\\" elif . >= 32 and . <= 126 then [.] | implode else "\\u{\(hex_digits)}" end;

def escaped_text: explode | map(escaped_character) | join("");
