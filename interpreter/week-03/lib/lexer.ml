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
      else if is_alpha c then begin
        let j = ref i in
        while !j < n && is_ident_char line.[!j] do
          incr j
        done;
        let text = String.sub line i (!j - i) in
        go !j (IDENT text :: acc)
      end
      else
        match c with
        | '=' -> go (i + 1) (EQUALS :: acc)
        | '+' -> go (i + 1) (PLUS :: acc)
        | '-' -> go (i + 1) (MINUS :: acc)
        | '*' -> go (i + 1) (STAR :: acc)
        | '/' -> go (i + 1) (SLASH :: acc)
        | '(' -> go (i + 1) (LPAREN :: acc)
        | ')' -> go (i + 1) (RPAREN :: acc)
        | _ -> raise (Lex_error (Printf.sprintf "unexpected character %c" c))
  in
  go 0 []
