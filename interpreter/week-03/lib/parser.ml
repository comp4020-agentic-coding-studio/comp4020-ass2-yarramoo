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
  | IDENT name -> Var name
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

(* A week-3 statement is exactly [IDENT = expr]. *)
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
   comment lines (a '*' in column 1), and parse each remaining line as
   one statement. *)
let parse_program (source : string) : program =
  let lines = String.split_on_char '\n' source in
  List.filter_map
    (fun line ->
       let trimmed = String.trim line in
       if trimmed = "" then None
       else if String.length line > 0 && line.[0] = '*' then None
       else Some (parse_stmt (Lexer.tokenize line)))
    lines
