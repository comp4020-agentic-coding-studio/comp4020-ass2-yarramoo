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

let tokenize (line : string) : token list =
  let n = String.length line in
  let toks = ref [] in
  let i = ref 0 in
  let prev_was_blank = ref true in
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
      incr i;
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
       | ':' -> toks := COLON :: !toks
       | ',' -> toks := COMMA :: !toks
       | other ->
         raise (Lex_error (Printf.sprintf "unexpected character %c" other)));
      incr i;
      prev_was_blank := false
    end
  done;
  List.rev (EOF :: !toks)
