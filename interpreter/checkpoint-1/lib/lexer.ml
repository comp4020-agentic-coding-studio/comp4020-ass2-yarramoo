(* Checkpoint 1: a hand-rolled lexer.

   Why hand-rolled rather than ocamllex: the one genuinely distinctive fact
   about SNOBOL4 lexing is that whitespace is *semantically* significant
   around "+ - * /" -- the same character can be a binary operator, a
   unary operator, or a concatenation boundary, decided purely by whether
   a blank sits immediately to its left and/or right (see
   research/snobol/02-language-reference.md, "Arithmetic and blank
   sensitivity"). That decision needs to look at the *previous* character
   already consumed and the *next* character not yet consumed at the same
   time. ocamllex's regex-driven rules can do this with lookahead patterns,
   but it is far more direct to express as an explicit character-by-
   character scan that tracks "was the previous character a blank" as
   ordinary mutable state. A hand-rolled lexer also makes the per-line,
   column-sensitive label rule (added in checkpoint 2) easy to bolt on
   later without fighting a generated automaton's line-oriented state.

   Concrete rule this lexer implements for "+ - * /" (documented here since
   it is a deliberate, citable design decision, not a guess):

     - '-' is lexed as UNARY only when a blank immediately precedes it
       AND no blank immediately follows it (the "A -B" case: the blank
       marks a concatenation boundary between A and the pattern that
       follows; '-' then binds tightly to its operand).
     - In every other case ('-' with no blank before it, or with a blank
       on both sides, or with a blank only after it) '-' is BINARY.
     - '+', '*', '/' are always binary in this subset. Real SNOBOL4 also
       treats '*' as a unary operator, but that is the *unevaluated
       expression* operator (`*E`), which this course's subset does not
       implement (see interpreter/README.md) -- so there is no unary '*'
       here, and no ambiguity to resolve for it.

   Concatenation itself has no token: the parser recognises "two operands
   with nothing between them" as concatenation directly. *)

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
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let is_ident_char c = is_alpha c || is_digit c || c = '_'
let is_blank c = c = ' ' || c = '\t'

(* TODO(checkpoint 1): implement [tokenize].
   Tokenize a single logical line (no embedded newlines) into a token
   list, terminated by EOF. Blank and comment-only lines should yield
   [[EOF]].

   You will need to handle: skipping blanks/tabs; scanning integer
   literals; scanning identifiers ([is_alpha] then zero or more
   [is_ident_char]); scanning single- or double-quoted string literals;
   and the operator/paren characters, plus '=', '(', ')'.

   The one genuinely tricky part is '-': it must come out as
   [MINUS_UNARY] when a blank immediately precedes it AND no blank
   immediately follows it, and [MINUS_BINARY] in every other case --
   see the module comment above and
   research/snobol/02-language-reference.md ("Arithmetic and blank
   sensitivity") for exactly why. Track "was the previous character a
   blank" as you scan (start it as [true], so a line-initial '-' behaves
   correctly), and peek one character ahead to decide "space_after". *)
let tokenize (_line : string) : token list =
  failwith "TODO: implement the lexer (see the comment above tokenize)"
