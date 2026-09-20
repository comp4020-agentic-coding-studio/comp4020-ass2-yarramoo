(* Week 5 extends checkpoint 1's expression parser with function calls
   ([IDENT(args)], needed for the comparison predicates below), and adds
   the real statement shape: an optional label, an optional goto field,
   and a statement body that is either an assignment or a bare
   expression evaluated for its success/failure (research/snobol/
   02-language-reference.md, "Statement structure" and "Goto field").
   This is exactly checkpoint 2's own parser -- checkpoint 2 keeps this
   machinery unchanged when it later adds DEFINE on top of it. *)

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
   out through the whole chain.

   TODO(week 5): checkpoint 1's [parse_primary] handles [INT]/[STR]/
   [LPAREN] already (kept below) and a bare [IDENT] as [Var] -- add the
   new case: an [IDENT] immediately followed by '(' is a call, e.g.
   [GT(N,10)]. Consume the '(', parse a comma-separated [parse_arglist],
   then [expect st RPAREN]. *)
let rec parse_primary (st : state) : expr =
  match advance st with
  | INT n -> Int n
  | STR s -> Str s
  | IDENT _name -> failwith "TODO: parse_primary (add the IDENT '(' ... ')' call case)"
  | LPAREN ->
    let e = parse_concat st in
    expect st RPAREN;
    e
  | _ -> raise (Parse_error "expected an expression")

(* TODO(week 5): zero or more comma-separated expressions, closed by
   ')' (the ')' itself is left for the caller to [expect]). *)
and parse_arglist (_st : state) : expr list =
  failwith "TODO: parse_arglist"

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

(* Goto field: ":" then either "(label)" (unconditional) or one or two of
   "S(label)"/"F(label)" in either order (":S(label)", ":F(label)",
   ":S(l1)F(l2)", ":F(l1)S(l2)", ":(label)"). *)
let parse_label_name (st : state) : string =
  match advance st with
  | IDENT name -> name
  | _ -> raise (Parse_error "expected a label name in goto field")

(* TODO(week 5): if [peek st] isn't [COLON], there's no goto field --
   return [None]. Otherwise consume the ':' and dispatch on what follows:
   ['('] means unconditional (parse one [parse_label_name] between parens
   and wrap it in [unconditional]); ['S'/'F' as an IDENT] means one or
   both of [on_success]/[on_failure] -- each is its own "S(label)" or
   "F(label)", and either can come first, so parse one, then check
   whether the other follows immediately. *)
let parse_goto (_st : state) : goto option =
  failwith "TODO: parse_goto"

(* TODO(week 5): a statement body is [subject] or [subject = object].
   Parse the subject as one full expression ([parse_expr]); if it turns
   out to be a bare [Var name] and an [EQUALS] follows, consume it and
   parse an object expression for [Assign]. Otherwise the subject itself
   is the whole statement ([Expr]) -- this is how a predicate call like
   [GT(N,10)] is used on its own line, for its success/failure alone. *)
let parse_body (_st : state) : stmt_body =
  failwith "TODO: parse_body"

let parse_stmt (label : string option) (toks : token list) : stmt =
  let st = { toks } in
  let body = parse_body st in
  let goto = parse_goto st in
  (match peek st with
   | EOF -> ()
   | _ -> raise (Parse_error "unexpected trailing tokens on statement"));
  { label; body; goto }

(* TODO(week 5): a label starts in column 1; a label-less statement line
   must start with a blank (research/snobol/02-language-reference.md,
   "Program Format"). Split the raw line into an optional label and the
   rest of the line *before* tokenizing -- the label itself is never a
   token. If [line] is empty or starts with a blank there's no label:
   return [(None, line)]. Otherwise scan [Lexer.is_ident_char]s from
   column 0 to find where the label ends, and split there. Comment
   lines ('*' in column 1) and blank lines are filtered out by
   [parse_program] before this ever runs. *)
let split_label (_line : string) : string option * string =
  failwith "TODO: split_label"

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
