(* Week 3: extends week 2's arithmetic lexer with identifiers and '='. *)

type token =
  | INT of int
  | IDENT of string
  | EQUALS
  | PLUS
  | MINUS
  | STAR
  | SLASH
  | LPAREN
  | RPAREN
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let is_ident_char c = is_alpha c || is_digit c || c = '_'
let is_blank c = c = ' ' || c = '\t'

(* TODO(week 3): extend week 2's arithmetic-only [tokenize] with
   identifiers ([is_alpha] then zero or more [is_ident_char]) and '='.
   Keep the digit-run and operator scanning from week 2 unchanged. *)
let tokenize (_line : string) : token list =
  failwith "TODO: extend the lexer with identifiers and '='"
