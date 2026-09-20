(* Week 5: checkpoint 1's hand-rolled, blank-sensitive lexer (see
   checkpoint 1's lib/lexer.ml for the full rationale on '-'), plus two
   new tokens: COLON starts a goto field ([:S(LABEL)] etc.), and COMMA
   separates a call's arguments ([GT(N,10)]). Labels themselves are
   *not* tokenized here -- like checkpoint 2, the column-1 label at the
   front of a line is stripped by the parser's [split_label] before the
   remainder of the line ever reaches [tokenize]. *)

type token =
  | INT of int
  | STR of string
  | IDENT of string
  | PLUS
  | MINUS_BINARY
  | MINUS_UNARY
  | STAR
  | SLASH
  | EQUALS
  | LPAREN
  | RPAREN
  | COLON
  | COMMA
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let is_ident_char c = is_alpha c || is_digit c || c = '_'
let is_blank c = c = ' ' || c = '\t'

(* TODO(week 5): extend checkpoint 1's [tokenize] (digits, identifiers,
   quoted strings, the blank-sensitive '+ - * /' rule, '=', parens) with
   two new, blank-insensitive tokens: ':' -> [COLON] and ',' -> [COMMA].
   Everything else about the scan -- including the [prev_blank]
   bookkeeping for MINUS_UNARY vs MINUS_BINARY -- is unchanged from
   checkpoint 1. *)
let tokenize (_line : string) : token list =
  failwith "TODO: extend checkpoint 1's lexer with ':' and ','"
