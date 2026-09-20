(* Week 1: a hand-rolled lexer that recognises integer literals only.

   Why hand-rolled rather than ocamllex, right from week 1: SNOBOL4's
   arithmetic operators ("+ - * /") are blank-sensitive -- the same
   character can be binary or unary depending on whether a blank sits
   immediately to its left and/or right (see
   research/snobol/02-language-reference.md, "Arithmetic and blank
   sensitivity"). Resolving that needs a scan that tracks the previous
   character while peeking at the next one, which a hand-rolled
   character-by-character loop expresses directly. Rather than build this
   week's lexer in ocamllex and then swap technology out from under it in
   week 2 the moment blanks matter, every week starting here uses the same
   hand-rolled shape checkpoint 1 already settled on -- there is exactly one
   lexer design across the whole course, growing one rule at a time. *)

type token =
  | INT of int
  | EOF

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_blank c = c = ' ' || c = '\t'

(* Tokenize a single logical line into a token list, terminated by EOF.
   This week's whole vocabulary is "a run of digits" -- no identifiers, no
   operators, no strings yet. Blanks between digit runs are skipped, not
   treated as concatenation (that rule doesn't exist until week 4). *)
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
      else raise (Lex_error (Printf.sprintf "unexpected character %c" c))
  in
  go 0 []

let show_token = function
  | INT n -> Printf.sprintf "INT %d" n
  | EOF -> "EOF"
