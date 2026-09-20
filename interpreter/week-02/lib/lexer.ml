(* Week 2: extends week 1's lexer with the four arithmetic operators and
   parentheses. Per week-02.md's own scope note, the full blank-sensitivity
   rule for '+ - * /' (see interpreter/week-01/lib/lexer.ml's module
   comment) is deliberately deferred -- this week's grammar has no unary
   minus and no concatenation to disambiguate against, so every operator
   is lexed as an ordinary token regardless of surrounding blanks. *)

type token =
  | INT of int
  | PLUS
  | MINUS
  | STAR
  | SLASH
  | LPAREN
  | RPAREN
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_blank c = c = ' ' || c = '\t'

(* TODO(week 2): extend week 1's digit-only [tokenize] with '+', '-', '*',
   '/', '(', and ')' as ordinary single-character tokens (no
   blank-sensitivity yet -- see the module comment above). Keep the
   digit-run scanning from week 1 unchanged. *)
let tokenize (_line : string) : token list =
  failwith "TODO: extend the lexer with arithmetic operators and parens"
