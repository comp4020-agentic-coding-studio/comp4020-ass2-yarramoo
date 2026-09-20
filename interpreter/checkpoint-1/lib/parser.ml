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

(* TODO(checkpoint 1): implement the parser's precedence chain.

   You need six mutually-recursive pieces, highest precedence to lowest:

   - [parse_primary]: INT / STR / IDENT / "( expr )".
   - [parse_unary]: a leading [MINUS_UNARY] negates (build [Neg]),
     otherwise just [parse_primary].
   - [parse_muldiv]: left-associative "*" and "/" over [parse_unary].
   - [parse_addsub]: left-associative "+" and [MINUS_BINARY] over
     [parse_muldiv].
   - [parse_concat]: lowest precedence -- while the next token
     [starts_operand], glue on another [parse_addsub] result with
     [Concat]. This is where "juxtaposition = concatenation" actually
     happens; see the module comment and ast.ml.
   - [parse_stmt]: expects exactly [IDENT = expr] (checkpoint 1's only
     statement shape) and builds [Assign].

   [expect], [peek], [advance], and [starts_operand] above are the
   utilities you'll build this from. *)
(* NOTE: these will need to become "let rec ... and ... and ..." once you
   fill them in for real, since they call each other. They're left as
   independent stubs for now so the file compiles as-is. *)
let parse_primary (_st : state) : expr =
  failwith "TODO: implement parse_primary (INT / STR / IDENT / parenthesized expr)"

let parse_unary (_st : state) : expr =
  failwith "TODO: implement parse_unary (leading MINUS_UNARY negates)"

let parse_muldiv (_st : state) : expr =
  failwith "TODO: implement parse_muldiv (left-associative * and /)"

let parse_addsub (_st : state) : expr =
  failwith "TODO: implement parse_addsub (left-associative + and MINUS_BINARY)"

let parse_concat (_st : state) : expr =
  failwith "TODO: implement parse_concat (juxtaposition = concatenation, lowest precedence)"

let parse_expr st = parse_concat st

(* A checkpoint-1 statement is exactly [IDENT = expr]. *)
let parse_stmt (_toks : token list) : stmt =
  failwith "TODO: implement parse_stmt (expect IDENT, EQUALS, an expr, then EOF)"

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
