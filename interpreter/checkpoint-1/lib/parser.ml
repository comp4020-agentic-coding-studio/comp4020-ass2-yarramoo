(* Checkpoint 1: recursive-descent parser for arithmetic expressions,
   string literals, and [IDENT = expr] assignment statements.

   Precedence, highest to lowest (per
   research/snobol/02-language-reference.md, "Arithmetic and blank
   sensitivity"): unary minus, then * /, then + -, then concatenation
   (lowest of all -- concatenation glues together whole additive
   expressions, e.g. "A + 1 B - 1" is (A + 1) concatenated with (B - 1)). *)

open Ast
open Lexer

exception Parse_error of string

type state = { mutable toks : token list }

let peek st = match st.toks with t :: _ -> t | [] -> EOF

let advance st =
  match st.toks with
  | t :: rest -> st.toks <- rest; t
  | [] -> EOF

let expect st t =
  let got = advance st in
  if got <> t then
    raise (Parse_error "unexpected token")

(* Tokens that can legally start a new operand -- used to decide whether
   we've hit a concatenation boundary (two operands, nothing between
   them). *)
let starts_operand = function
  | INT _ | STR _ | IDENT _ | LPAREN | MINUS_UNARY -> true
  | _ -> false

let rec parse_primary st =
  match advance st with
  | INT n -> Int n
  | STR s -> Str s
  | IDENT name -> Var name
  | LPAREN ->
    let e = parse_concat st in
    expect st RPAREN;
    e
  | _ -> raise (Parse_error "expected an expression")

and parse_unary st =
  match peek st with
  | MINUS_UNARY -> ignore (advance st); Neg (parse_unary st)
  | _ -> parse_primary st

and parse_muldiv st =
  let lhs = ref (parse_unary st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | STAR -> ignore (advance st); lhs := Bin (Mul, !lhs, parse_unary st)
    | SLASH -> ignore (advance st); lhs := Bin (Div, !lhs, parse_unary st)
    | _ -> continue_ := false
  done;
  !lhs

and parse_addsub st =
  let lhs = ref (parse_muldiv st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | PLUS -> ignore (advance st); lhs := Bin (Add, !lhs, parse_muldiv st)
    | MINUS_BINARY -> ignore (advance st); lhs := Bin (Sub, !lhs, parse_muldiv st)
    | _ -> continue_ := false
  done;
  !lhs

(* Lowest precedence: repeatedly glue on another additive expression as
   long as the next token could start one, with no operator consumed in
   between -- that "nothing between them" is exactly what concatenation
   is in SNOBOL4. *)
and parse_concat st =
  let lhs = ref (parse_addsub st) in
  while starts_operand (peek st) do
    lhs := Concat (!lhs, parse_addsub st)
  done;
  !lhs

let parse_expr st = parse_concat st

(* A checkpoint-1 statement is exactly [IDENT = expr]. *)
let parse_stmt (toks : token list) : stmt =
  let st = { toks } in
  match advance st with
  | IDENT name ->
    expect st EQUALS;
    let e = parse_expr st in
    (match peek st with
     | EOF -> Assign (name, e)
     | _ -> raise (Parse_error "trailing tokens after assignment"))
  | _ -> raise (Parse_error "expected an assignment statement (IDENT = expr)")

(* Split source text into logical lines, dropping blank lines and
   comment lines (a '*' in column 1, the real SNOBOL4 convention -- see
   research/snobol/02-language-reference.md, "Program Format"), and parse
   each remaining line as one statement. *)
let parse_program (source : string) : program =
  let lines = String.split_on_char '\n' source in
  List.filter_map
    (fun line ->
       let trimmed = String.trim line in
       if trimmed = "" then None
       else if String.length line > 0 && line.[0] = '*' then None
       else Some (parse_stmt (Lexer.tokenize line)))
    lines
