(* Checkpoint 2 extends checkpoint 1's expression parser with function
   calls ([IDENT(args)], needed for DEFINE and for calling user-defined
   functions), and adds the real statement shape: an optional label, an
   optional goto field, and a statement body that is either an assignment
   or a bare expression evaluated for its side effect/success-failure
   (research/snobol/02-language-reference.md, "Statement structure" and
   "Goto field").

   Checkpoint 3 adds the pattern sublanguage, reusing this same
   expression grammar rather than inventing a separate one: pattern
   primitives (LEN/ANY/NOTANY/SPAN/BREAK) are just [IDENT(args)] calls,
   [ARB] is just a bare [IDENT], and pattern concatenation is just
   juxtaposition -- all already handled by [parse_primary]/[parse_concat]
   below. Two genuinely new precedence levels are added for the two
   genuinely new pattern operators: [parse_bind] (postfix ".", tightest
   after a primary/unary -- see the `"A" ARB . DOTVAR "E"` example in
   research/snobol/03-pattern-matching.md, where "." binds only to the
   immediately preceding [ARB], not to the whole surrounding
   concatenation) and [parse_alt] (infix "|", the *lowest* precedence,
   below concatenation -- concatenation distributes over alternation
   from the right [Gimpel1973]).

   The statement shape itself also changes: a statement's subject is now
   parsed as a single [parse_primary] (not the full expression chain),
   deliberately, so that "where does the subject end and the pattern
   field begin" is unambiguous without needing real SNOBOL4's full
   disambiguation rules -- see interpreter/README.md's "Deliberate scope
   decisions" for the citation against research/snobol/
   02-language-reference.md's `(TENS UNITS) 30` example. A statement body
   is then one of: [subject = object] (assignment, unchanged from
   checkpoint 2), [subject pattern] (a bare pattern-match, no
   replacement), [subject pattern = object] (a replacement), or a bare
   [subject] with neither a following operand nor an EQUALS (an
   [Expr], unchanged from checkpoint 2, e.g. a top-level `DEFINE(...)`
   or `GT(N,5)`). *)

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

(* Postfix "." -- conditional pattern binding. Binds only to the single
   pattern element immediately to its left (see the module comment's
   `ARB . DOTVAR` example), so it sits directly on top of [parse_unary],
   tighter than `* /` or concatenation: "X Y . V Z" binds V to Y alone,
   not to "X Y" or to "V Z". *)
and parse_bind (st : state) : expr =
  let e = parse_unary st in
  match peek st with
  | DOT ->
    ignore (advance st);
    (match advance st with
     | IDENT name -> Bind (e, name)
     | _ -> raise (Parse_error "expected a variable name after '.'"))
  | _ -> e

and parse_muldiv (st : state) : expr =
  let lhs = ref (parse_bind st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | STAR -> ignore (advance st); lhs := Bin (Mul, !lhs, parse_bind st)
    | SLASH -> ignore (advance st); lhs := Bin (Div, !lhs, parse_bind st)
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

(* Alternation, "|" -- the lowest precedence level of all, sitting below
   concatenation: concatenation distributes over alternation from the
   right [Gimpel1973], e.g. `'A' ('B' | 'C')` and `'A' 'B' | 'A' 'C'`
   denote the same pattern, so alternation must bind more loosely than
   juxtaposition for `'A' 'B' | 'C'` to parse as `('A' 'B') | 'C'`
   rather than `'A' ('B' | 'C')`. *)
and parse_alt (st : state) : expr =
  let lhs = ref (parse_concat st) in
  while peek st = PIPE do
    ignore (advance st);
    lhs := Alt (!lhs, parse_concat st)
  done;
  !lhs

let parse_expr st = parse_alt st

(* Goto field: ":" then either "(label)" (unconditional) or one or two of
   "S(label)"/"F(label)" in either order (research/snobol/
   02-language-reference.md, "Goto field": ":S(label)", ":F(label)",
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

(* A statement body is [subject], [subject = object], [subject pattern],
   or [subject pattern = object]. The subject is parsed once, as a
   single [parse_primary] (see the module comment for why it is
   deliberately not the full expression chain), and what follows it
   decides which of the four shapes this is:

   - an immediate EQUALS with no pattern in between: assignment
     (checkpoint 2's shape, unchanged) -- the subject must be a plain
     variable;
   - something that could start an operand (an [IDENT], string, number,
     parenthesized group, or unary minus): a pattern follows. Parse the
     *whole* pattern expression (concatenation and alternation, "."
     bindings and all) with [parse_alt], then check for a trailing
     "= object" to tell a bare match apart from a replacement;
   - anything else (including plain EOF or a goto field's leading
     COLON): a bare expression evaluated for effect, e.g. `DEFINE(...)`
     or `GT(N,5)` -- unchanged from checkpoint 2. *)
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
    (match peek st with
     | EQUALS ->
       ignore (advance st);
       let obj = parse_expr st in
       Match (subject, pattern, Some obj)
     | _ -> Match (subject, pattern, None))
  | _ -> Expr subject

let parse_stmt (label : string option) (toks : token list) : stmt =
  let st = { toks } in
  let body = parse_body st in
  let goto = parse_goto st in
  (match peek st with
   | EOF -> ()
   | _ -> raise (Parse_error "unexpected trailing tokens on statement"));
  { label; body; goto }

(* A label starts in column 1: the very first character of the line is
   not a blank, and (per this subset) is the start of an identifier. A
   label-less statement line must start with a blank
   (research/snobol/02-language-reference.md, "Program Format": labels
   occupy column 1, everything else is indented). Comment lines ('*' in
   column 1) and blank lines are filtered out by [parse_program] before
   this ever runs. *)
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
