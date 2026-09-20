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

(* Tokenize a single logical line (no embedded newlines) into a token
   list, terminated by EOF. Blank and comment-only lines yield [[EOF]]. *)
let tokenize (line : string) : token list =
  let n = String.length line in
  let toks = ref [] in
  let i = ref 0 in
  let prev_was_blank = ref true in
  (* true at start-of-line: treat "nothing before" like a blank so a
     leading '-' is never misread as needing a left-hand concatenation
     boundary that doesn't exist. *)
  while !i < n do
    let c = line.[!i] in
    if is_blank c then begin
      prev_was_blank := true;
      incr i
    end
    else if is_digit c then begin
      let start = !i in
      while !i < n && is_digit line.[!i] do incr i done;
      let s = String.sub line start (!i - start) in
      toks := INT (int_of_string s) :: !toks;
      prev_was_blank := false
    end
    else if is_alpha c then begin
      let start = !i in
      while !i < n && is_ident_char line.[!i] do incr i done;
      let s = String.sub line start (!i - start) in
      toks := IDENT s :: !toks;
      prev_was_blank := false
    end
    else if c = '\'' || c = '"' then begin
      let quote = c in
      incr i;
      let start = !i in
      while !i < n && line.[!i] <> quote do incr i done;
      if !i >= n then raise (Lex_error "unterminated string literal");
      let s = String.sub line start (!i - start) in
      incr i (* consume closing quote *);
      toks := STR s :: !toks;
      prev_was_blank := false
    end
    else begin
      let space_before = !prev_was_blank in
      let space_after = !i + 1 >= n || is_blank line.[!i + 1] in
      (match c with
       | '+' -> toks := PLUS :: !toks
       | '-' ->
         if space_before && not space_after then toks := MINUS_UNARY :: !toks
         else toks := MINUS_BINARY :: !toks
       | '*' -> toks := STAR :: !toks
       | '/' -> toks := SLASH :: !toks
       | '=' -> toks := EQUALS :: !toks
       | '(' -> toks := LPAREN :: !toks
       | ')' -> toks := RPAREN :: !toks
       | other ->
         raise (Lex_error (Printf.sprintf "unexpected character %c" other)));
      incr i;
      prev_was_blank := false
    end
  done;
  List.rev (EOF :: !toks)
