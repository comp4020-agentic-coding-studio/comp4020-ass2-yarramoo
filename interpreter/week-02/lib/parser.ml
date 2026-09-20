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

(* TODO(week 2): implement the precedence-climbing chain, highest
   precedence to lowest:

   - [parse_primary]: INT, or "( expr )" via [parse_expr].
   - [parse_muldiv]: [parse_primary], then loop consuming STAR/SLASH,
     each time folding in another [parse_primary] on the right.
   - [parse_addsub]: [parse_muldiv], then loop consuming PLUS/MINUS,
     each time folding in another [parse_muldiv] on the right.
   - [parse_expr]: just [parse_addsub] -- this grammar has no level below
     it yet (concatenation arrives in week 4). *)
let rec parse_primary (_st : state) : expr =
  failwith "TODO: parse_primary"

and parse_muldiv (_st : state) : expr =
  failwith "TODO: parse_muldiv"

and parse_addsub (_st : state) : expr =
  failwith "TODO: parse_addsub"

and parse_expr st = parse_addsub st

let parse_line (toks : token list) : expr =
  let st = { toks } in
  let e = parse_expr st in
  match peek st with
  | EOF -> e
  | _ -> raise (Parse_error "trailing tokens after expression")
