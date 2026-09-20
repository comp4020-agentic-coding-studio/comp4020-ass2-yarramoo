(* Checkpoint 2 extends checkpoint 1's expression parser with function
   calls ([IDENT(args)], needed for DEFINE and for calling user-defined
   functions), and adds the real statement shape: an optional label, an
   optional goto field, and a statement body that is either an assignment
   or a bare expression evaluated for its side effect/success-failure
   (research/snobol/02-language-reference.md, "Statement structure" and
   "Goto field"). *)

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

let starts_operand = function
  | INT _ | STR _ | IDENT _ | LPAREN | MINUS_UNARY -> true
  | _ -> false

(* Precedence chain, highest to lowest: primary (incl. function calls),
   unary minus, * /, + -, concatenation. Mutually recursive because a
   parenthesized expression and a call's argument list both bottom back
   out through the whole chain. *)
let rec parse_primary (st : state) : expr =
  match advance st with
  | INT n -> Int n
  | STR s -> Str s
  | IDENT name ->
    if peek st = LPAREN then begin
      ignore (advance st);
      let args = parse_arglist st in
      expect st RPAREN;
      Call (name, args)
    end else Var name
  | LPAREN ->
    let e = parse_concat st in
    expect st RPAREN;
    e
  | _ -> raise (Parse_error "expected an expression")

and parse_arglist (st : state) : expr list =
  if peek st = RPAREN then []
  else
    let rec loop acc =
      let e = parse_concat st in
      match peek st with
      | COMMA -> ignore (advance st); loop (e :: acc)
      | _ -> List.rev (e :: acc)
    in
    loop []

and parse_unary (st : state) : expr =
  match peek st with
  | MINUS_UNARY -> ignore (advance st); Neg (parse_primary st)
  | _ -> parse_primary st

and parse_muldiv (st : state) : expr =
  let lhs = ref (parse_unary st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | STAR -> ignore (advance st); lhs := Bin (Mul, !lhs, parse_unary st)
    | SLASH -> ignore (advance st); lhs := Bin (Div, !lhs, parse_unary st)
    | _ -> continue_ := false
  done;
  !lhs

and parse_addsub (st : state) : expr =
  let lhs = ref (parse_muldiv st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | PLUS -> ignore (advance st); lhs := Bin (Add, !lhs, parse_muldiv st)
    | MINUS_BINARY -> ignore (advance st); lhs := Bin (Sub, !lhs, parse_muldiv st)
    | _ -> continue_ := false
  done;
  !lhs

and parse_concat (st : state) : expr =
  let lhs = ref (parse_addsub st) in
  while starts_operand (peek st) do
    lhs := Concat (!lhs, parse_addsub st)
  done;
  !lhs

let parse_expr st = parse_concat st

let parse_label_name (st : state) : string =
  match advance st with
  | IDENT name -> name
  | _ -> raise (Parse_error "expected a label name in goto field")

(* TODO(checkpoint 2): implement the new statement-shape and label rules.

   [parse_goto]: a goto field is ":" then either "(label)"
   (unconditional -- [unconditional]) or one or two of "S(label)"/
   "F(label)" in either order ([on_success]/[on_failure]). See
   research/snobol/02-language-reference.md, "Goto field", for the exact
   forms (":S(label)", ":F(label)", ":S(l1)F(l2)", ":F(l1)S(l2)",
   ":(label)"). No leading ":" at all means no goto field -- return
   [None]. [parse_label_name] above reads one label name once you're
   positioned at it.

   [parse_body]: a statement body is [subject] or [subject = object].
   Parse [subject] once with [parse_expr]; if it's a bare [Var name] and
   an [EQUALS] follows, consume it and parse [object] to build [Assign].
   Otherwise (a bare expression -- typically a function call made for
   effect, e.g. a top-level `DEFINE(...)`) build [Expr].

   [parse_stmt]: parse a body, then an optional goto field, then require
   nothing but [EOF] left.

   [split_label]: a label starts in column 1 -- the line's very first
   character is not a blank, and (in this subset) starts an identifier.
   A label-less statement line must start with a blank
   (research/snobol/02-language-reference.md, "Program Format"). Return
   [(label option, rest-of-line-with-the-label-removed)]. Comment lines
   ('*' in column 1) and blank lines never reach this function --
   [parse_program] filters them out first. *)
let parse_goto (_st : state) : goto option =
  failwith "TODO: implement parse_goto (':' then '(label)' or S(...)/F(...))"

let parse_body (_st : state) : stmt_body =
  failwith "TODO: implement parse_body (subject, or subject = object)"

let parse_stmt (_label : string option) (_toks : token list) : stmt =
  failwith "TODO: implement parse_stmt (parse_body, then parse_goto, then expect EOF)"

let split_label (_line : string) : string option * string =
  failwith "TODO: implement split_label (column-1 label rule -- see the comment above)"

let parse_program (source : string) : program =
  let lines = String.split_on_char '\n' source in
  lines
  |> List.filter_map (fun line ->
    let trimmed = String.trim line in
    if trimmed = "" then None
    else if String.length line > 0 && line.[0] = '*' then None
    else begin
      let label, rest = split_label line in
      Some (parse_stmt label (Lexer.tokenize rest))
    end)
  |> Array.of_list
