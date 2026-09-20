(* Week 7 reuses checkpoint 2's lexer unchanged, plus one new,
   blank-insensitive token: PIPE for the alternation operator '|'
   (research/snobol/03-pattern-matching.md, "Pattern construction
   operators"). *)

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
  | PIPE
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let is_ident_char c = is_alpha c || is_digit c || c = '_'
let is_blank c = c = ' ' || c = '\t'

let tokenize (line : string) : token list =
  let n = String.length line in
  let toks = ref [] in
  let push t = toks := t :: !toks in
  let i = ref 0 in
  let prev_blank = ref true in
  while !i < n do
    let c = line.[!i] in
    if is_blank c then begin
      prev_blank := true;
      incr i
    end else if is_digit c then begin
      let start = !i in
      while !i < n && is_digit line.[!i] do incr i done;
      push (INT (int_of_string (String.sub line start (!i - start))));
      prev_blank := false
    end else if is_alpha c then begin
      let start = !i in
      while !i < n && is_ident_char line.[!i] do incr i done;
      push (IDENT (String.sub line start (!i - start)));
      prev_blank := false
    end else if c = '\'' || c = '"' then begin
      let quote = c in
      incr i;
      let start = !i in
      while !i < n && line.[!i] <> quote do incr i done;
      if !i >= n then raise (Lex_error "unterminated string literal");
      push (STR (String.sub line start (!i - start)));
      incr i;
      prev_blank := false
    end else begin
      let space_before = !prev_blank in
      (match c with
       | '+' -> push PLUS
       | '-' ->
         let space_after = !i + 1 >= n || is_blank line.[!i + 1] in
         if space_before && not space_after then push MINUS_UNARY
         else push MINUS_BINARY
       | '*' -> push STAR
       | '/' -> push SLASH
       | '=' -> push EQUALS
       | '(' -> push LPAREN
       | ')' -> push RPAREN
       | ':' -> push COLON
       | ',' -> push COMMA
       | '|' -> push PIPE
       | _ -> raise (Lex_error (Printf.sprintf "unexpected character: %c" c)));
      incr i;
      prev_blank := false
    end
  done;
  push EOF;
  List.rev !toks
