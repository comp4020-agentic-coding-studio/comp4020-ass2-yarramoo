(* Week 7 keeps checkpoint 2's expression grammar and statement shape,
   and adds one new precedence level for the one new pattern operator in
   scope this week: [parse_alt] (infix "|", alternation -- research/
   snobol/03-pattern-matching.md, "Pattern construction operators").
   There is no postfix "." binding yet (checkpoint 3's [parse_bind]) --
   this week's [Match] only asks whether a pattern matches, so nothing
   needs a name to be bound to.

   The statement shape changes the same way checkpoint 3's does, minus
   replacement: a statement's subject is parsed as a single
   [parse_primary] (not the full expression chain), deliberately, so
   "where does the subject end and the pattern field begin" is
   unambiguous. What follows the subject then decides the shape: an
   immediate EQUALS is an assignment (checkpoint 2's shape, unchanged);
   something that could start an operand means a pattern follows,
   parsed with [parse_alt] and paired with the subject as [Match] --
   with no trailing "= object" this week, since replacement is out of
   scope; anything else is a bare [Expr], unchanged from checkpoint 2. *)

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
    let e = parse_alt st in
    expect st RPAREN;
    e
  | _ -> raise (Parse_error "expected an expression")

and parse_arglist (st : state) : expr list =
  if peek st = RPAREN then []
  else
    let rec loop acc =
      let e = parse_alt st in
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

(* Alternation, "|" -- the lowest precedence level of all, below
   concatenation, since concatenation distributes over alternation from
   the right [Gimpel1973]: `'A' 'B' | 'C'` must parse as
   `('A' 'B') | 'C'`, not `'A' ('B' | 'C')`. *)
and parse_alt (st : state) : expr =
  let lhs = ref (parse_concat st) in
  while peek st = PIPE do
    ignore (advance st);
    lhs := Alt (!lhs, parse_concat st)
  done;
  !lhs

let parse_expr st = parse_alt st

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

(* A statement body is [subject], [subject = object], or
   [subject pattern] -- no replacement this week (see the module
   comment). The subject is parsed once, as a single [parse_primary],
   and what follows it decides which of the three shapes this is. *)
let parse_body (st : state) : stmt_body =
  let subject = parse_primary st in
  match peek st with
  | EQUALS -> (
    match subject with
    | Var name ->
      ignore (advance st);
      let obj = parse_expr st in
      Assign (name, obj)
    | _ -> raise (Parse_error "left-hand side of '=' must be a plain identifier"))
  | t when starts_operand t ->
    let pattern = parse_alt st in
    Match (subject, pattern)
  | _ -> Expr subject

let parse_stmt (label : string option) (toks : token list) : stmt =
  let st = { toks } in
  let body = parse_body st in
  let goto = parse_goto st in
  (match peek st with
   | EOF -> ()
   | _ -> raise (Parse_error "unexpected trailing tokens on statement"));
  { label; body; goto }

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
