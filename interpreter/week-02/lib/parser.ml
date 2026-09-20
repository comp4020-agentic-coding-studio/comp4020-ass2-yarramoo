(* Week 2: a precedence-climbing ("Pratt") parser for a two-level
   arithmetic grammar -- * / bind tighter than + -, both left-associative.
   One function per precedence level, each level looping to fold in
   same-precedence operators before returning to the level above it, is
   the standard shape for a small, fixed number of precedence levels (see
   week-02.md's own framing: "one small table ... and one loop"). *)

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
  if got <> t then raise (Parse_error "unexpected token")

let rec parse_primary st =
  match advance st with
  | INT n -> Int n
  | LPAREN ->
    let e = parse_expr st in
    expect st RPAREN;
    e
  | _ -> raise (Parse_error "expected an expression")

and parse_muldiv st =
  let lhs = ref (parse_primary st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | STAR -> ignore (advance st); lhs := Bin (Mul, !lhs, parse_primary st)
    | SLASH -> ignore (advance st); lhs := Bin (Div, !lhs, parse_primary st)
    | _ -> continue_ := false
  done;
  !lhs

and parse_addsub st =
  let lhs = ref (parse_muldiv st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | PLUS -> ignore (advance st); lhs := Bin (Add, !lhs, parse_muldiv st)
    | MINUS -> ignore (advance st); lhs := Bin (Sub, !lhs, parse_muldiv st)
    | _ -> continue_ := false
  done;
  !lhs

and parse_expr st = parse_addsub st

let parse_line (toks : token list) : expr =
  let st = { toks } in
  let e = parse_expr st in
  match peek st with
  | EOF -> e
  | _ -> raise (Parse_error "trailing tokens after expression")
