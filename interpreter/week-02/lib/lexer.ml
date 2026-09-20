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

let tokenize (line : string) : token list =
  let n = String.length line in
  let rec go i acc =
    if i >= n then List.rev (EOF :: acc)
    else
      let c = line.[i] in
      if is_blank c then go (i + 1) acc
      else if is_digit c then begin
        let j = ref i in
        while !j < n && is_digit line.[!j] do
          incr j
        done;
        let text = String.sub line i (!j - i) in
        go !j (INT (int_of_string text) :: acc)
      end
      else
        match c with
        | '+' -> go (i + 1) (PLUS :: acc)
        | '-' -> go (i + 1) (MINUS :: acc)
        | '*' -> go (i + 1) (STAR :: acc)
        | '/' -> go (i + 1) (SLASH :: acc)
        | '(' -> go (i + 1) (LPAREN :: acc)
        | ')' -> go (i + 1) (RPAREN :: acc)
        | _ -> raise (Lex_error (Printf.sprintf "unexpected character %c" c))
  in
  go 0 []
