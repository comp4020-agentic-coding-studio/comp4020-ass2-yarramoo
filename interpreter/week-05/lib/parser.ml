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

(* Goto field: ":" then either "(label)" (unconditional) or one or two of
   "S(label)"/"F(label)" in either order (":S(label)", ":F(label)",
   ":S(l1)F(l2)", ":F(l1)S(l2)", ":(label)"). *)
let parse_label_name (st : state) : string =
  match advance st with
  | IDENT name -> name
  | _ -> raise (Parse_error "expected a label name in goto field")

let parse_goto (st : state) : goto option =
  match peek st with
  | COLON ->
    ignore (advance st);
    (match peek st with
     | LPAREN ->
       ignore (advance st);
       let lbl = parse_label_name st in
       expect st RPAREN;
       Some { on_success = None; on_failure = None; unconditional = Some lbl }
     | IDENT _ ->
       let s_lbl = ref None and f_lbl = ref None in
       let parse_one () =
         match advance st with
         | IDENT "S" ->
           expect st LPAREN;
           let l = parse_label_name st in
           expect st RPAREN;
           s_lbl := Some l
         | IDENT "F" ->
           expect st LPAREN;
           let l = parse_label_name st in
           expect st RPAREN;
           f_lbl := Some l
         | _ -> raise (Parse_error "expected S or F in goto field")
       in
       parse_one ();
       (match peek st with
        | IDENT ("S" | "F") -> parse_one ()
        | _ -> ());
       Some { on_success = !s_lbl; on_failure = !f_lbl; unconditional = None }
     | _ -> raise (Parse_error "malformed goto field"))
  | _ -> None

(* A statement body is [subject] or [subject = object]. The subject is
   parsed once as a full expression; if it turns out to be a bare
   variable and an EQUALS follows, this is an assignment. Anything else
   (a bare expression, typically a predicate call made for its
   success/failure, e.g. `GT(N,10)`) is [Expr]. *)
let parse_body (st : state) : stmt_body =
  let subject = parse_expr st in
  match peek st, subject with
  | EQUALS, Var name ->
    ignore (advance st);
    let obj = parse_expr st in
    Assign (name, obj)
  | EQUALS, _ ->
    raise (Parse_error "left-hand side of '=' must be a plain identifier")
  | _ -> Expr subject

let parse_stmt (label : string option) (toks : token list) : stmt =
  let st = { toks } in
  let body = parse_body st in
  let goto = parse_goto st in
  (match peek st with
   | EOF -> ()
   | _ -> raise (Parse_error "unexpected trailing tokens on statement"));
  { label; body; goto }

(* A label starts in column 1; a label-less statement line must start
   with a blank (research/snobol/02-language-reference.md, "Program
   Format"). Splits the raw line into an optional label and the rest of
   the line *before* tokenizing -- the label itself is never a token.
   Comment lines ('*' in column 1) and blank lines are filtered out by
   [parse_program] before this ever runs. *)
let split_label (line : string) : string option * string =
  if line = "" then (None, line)
  else if Lexer.is_blank line.[0] then (None, line)
  else begin
    let n = String.length line in
    let i = ref 0 in
    while !i < n && Lexer.is_ident_char line.[!i] do incr i done;
    if !i = 0 then (None, line)
    else (Some (String.sub line 0 !i), String.sub line !i (n - !i))
  end

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
