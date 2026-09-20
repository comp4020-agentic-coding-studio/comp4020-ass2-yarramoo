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
   or `GT(N,5)`).

   Week 10 adds one more postfix form directly onto [parse_primary],
   the same tier `IDENT(args)` calls already occupy: `IDENT<expr>`,
   array/table indexing (ast.ml's [Index]).

   Week 11 adds source positions and located diagnostics, without
   touching the grammar above at all:

   - Every [expr] this parser builds is tagged with the position of the
     first token it consumed (see [cur_pos]/the `start_pos` convention
     used throughout below), and every [stmt] is tagged with the
     position of its first body token -- see ast.ml's module comment for
     why [expr] needs this per-node but [stmt] only needs it once.
   - [Parse_error] messages are always formatted as
     "line L, column C: <message>", using [err_at], and name the actual
     offending token via [Lexer.string_of_token] rather than saying just
     "unexpected token".
   - [expect_matching] is used at the two places in this grammar with an
     opening/closing delimiter pair -- a parenthesized expression and a
     call's argument list -- and reports *both* the position the opening
     delimiter was found at and the position where the closing one was
     expected but missing, per week-11.md's "at least one error case
     names a second, earlier location" requirement (an unmatched `(` is
     the textbook example of this: the useful location is where it was
     *opened*, not just where the parser eventually gave up).
   - [parse_program]'s recovery strategy (see its own comment below) is
     line-level panic-mode recovery: on a lex or parse error within one
     source line, record the located message and skip straight to the
     next line, rather than aborting the whole file at the first error.
     This fits the parsing strategy every checkpoint before this one
     already committed to -- one statement per source line, no
     continuation lines (see interpreter/README.md's "Deliberate scope
     decisions") -- so a newline is already a safe, unambiguous
     resynchronization point that needs no new heuristic (a token-level
     scheme, like "skip to the next `)` or newline", would be needed for
     a grammar with multi-line statements, but this one doesn't have
     any). [main.ml] runs the program only if zero errors were
     recovered; if any were, it prints all of them and exits without
     executing a partially-parsed program. *)

open Ast
open Lexer

exception Parse_error of string

type state = { mutable toks : Lexer.postok list }

let peek (st : state) : token = match st.toks with pt :: _ -> pt.tok | [] -> EOF

let cur_pos (st : state) : pos =
  match st.toks with pt :: _ -> pt.ppos | [] -> { line = 0; col = 0 }

let advance (st : state) : token =
  match st.toks with
  | pt :: rest -> st.toks <- rest; pt.tok
  | [] -> EOF

(* Always raise with a location and the actual token name -- see the
   module comment. *)
let err_at (p : pos) (msg : string) : 'a =
  raise (Parse_error (Printf.sprintf "line %d, column %d: %s" p.line p.col msg))

let expect (st : state) (t : token) : unit =
  let p = cur_pos st in
  let got = advance st in
  if got <> t then
    err_at p
      (Printf.sprintf "expected %s but found %s" (string_of_token t) (string_of_token got))

(* The two-location form of [expect]: used only where this grammar has a
   real opening/closing delimiter pair. [open_pos] is where the opening
   delimiter itself was found (captured by the caller before parsing
   whatever sits between the delimiters); if the closing delimiter is
   missing, the error names both where parsing actually stopped *and*
   where the unmatched opener was, so a reader isn't left guessing which
   of possibly several parens on the line is the culprit. *)
let expect_matching (st : state) (open_tok : token) (open_pos : pos) (close_tok : token) : unit =
  let close_pos = cur_pos st in
  let got = advance st in
  if got <> close_tok then
    err_at close_pos
      (Printf.sprintf "expected %s to close the %s opened at line %d, column %d, but found %s"
         (string_of_token close_tok) (string_of_token open_tok) open_pos.line open_pos.col
         (string_of_token got))

let starts_operand = function
  | INT _ | STR _ | IDENT _ | LPAREN | MINUS_UNARY -> true
  | _ -> false

(* Precedence chain, highest to lowest: primary (incl. function calls),
   unary minus, * /, + -, concatenation. Mutually recursive because a
   parenthesized expression and a call's argument list both bottom back
   out through the whole chain.

   Every node built below starts with `let start_pos = cur_pos st in`
   *before* consuming any of its own tokens, so [epos] always names the
   position of the node's own leftmost token, not the position parsing
   happened to be at when the node was finished. *)
let rec parse_primary (st : state) : expr =
  let start_pos = cur_pos st in
  match advance st with
  | INT n -> { ek = Int n; epos = start_pos }
  | STR s -> { ek = Str s; epos = start_pos }
  | IDENT name ->
    if peek st = LPAREN then begin
      let open_pos = cur_pos st in
      ignore (advance st);
      let args = parse_arglist st in
      expect_matching st LPAREN open_pos RPAREN;
      { ek = Call (name, args); epos = start_pos }
    end else if peek st = LANGLE then begin
      ignore (advance st);
      let idx = parse_alt st in
      expect st RANGLE;
      { ek = Index (name, idx); epos = start_pos }
    end else { ek = Var name; epos = start_pos }
  | LPAREN ->
    let open_pos = start_pos in
    let e = parse_alt st in
    expect_matching st LPAREN open_pos RPAREN;
    e
  | got -> err_at start_pos (Printf.sprintf "expected an expression but found %s" (string_of_token got))

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
  let start_pos = cur_pos st in
  match peek st with
  | MINUS_UNARY -> ignore (advance st); { ek = Neg (parse_primary st); epos = start_pos }
  | _ -> parse_primary st

(* Postfix "." -- conditional pattern binding. Binds only to the single
   pattern element immediately to its left (see the module comment's
   `ARB . DOTVAR` example), so it sits directly on top of [parse_unary],
   tighter than `* /` or concatenation: "X Y . V Z" binds V to Y alone,
   not to "X Y" or to "V Z". *)
and parse_bind (st : state) : expr =
  let start_pos = cur_pos st in
  let e = parse_unary st in
  match peek st with
  | DOT ->
    ignore (advance st);
    let name_pos = cur_pos st in
    (match advance st with
     | IDENT name -> { ek = Bind (e, name); epos = start_pos }
     | got -> err_at name_pos (Printf.sprintf "expected a variable name after '.' but found %s" (string_of_token got)))
  | _ -> e

and parse_muldiv (st : state) : expr =
  let start_pos = cur_pos st in
  let lhs = ref (parse_bind st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | STAR -> ignore (advance st); lhs := { ek = Bin (Mul, !lhs, parse_bind st); epos = start_pos }
    | SLASH -> ignore (advance st); lhs := { ek = Bin (Div, !lhs, parse_bind st); epos = start_pos }
    | _ -> continue_ := false
  done;
  !lhs

and parse_addsub (st : state) : expr =
  let start_pos = cur_pos st in
  let lhs = ref (parse_muldiv st) in
  let continue_ = ref true in
  while !continue_ do
    match peek st with
    | PLUS -> ignore (advance st); lhs := { ek = Bin (Add, !lhs, parse_muldiv st); epos = start_pos }
    | MINUS_BINARY -> ignore (advance st); lhs := { ek = Bin (Sub, !lhs, parse_muldiv st); epos = start_pos }
    | _ -> continue_ := false
  done;
  !lhs

and parse_concat (st : state) : expr =
  let start_pos = cur_pos st in
  let lhs = ref (parse_addsub st) in
  while starts_operand (peek st) do
    lhs := { ek = Concat (!lhs, parse_addsub st); epos = start_pos }
  done;
  !lhs

(* Alternation, "|" -- the lowest precedence level of all, sitting below
   concatenation: concatenation distributes over alternation from the
   right [Gimpel1973], e.g. `'A' ('B' | 'C')` and `'A' 'B' | 'A' 'C'`
   denote the same pattern, so alternation must bind more loosely than
   juxtaposition for `'A' 'B' | 'C'` to parse as `('A' 'B') | 'C'`
   rather than `'A' ('B' | 'C')`. *)
and parse_alt (st : state) : expr =
  let start_pos = cur_pos st in
  let lhs = ref (parse_concat st) in
  while peek st = PIPE do
    ignore (advance st);
    lhs := { ek = Alt (!lhs, parse_concat st); epos = start_pos }
  done;
  !lhs

let parse_expr st = parse_alt st

(* Goto field: ":" then either "(label)" (unconditional) or one or two of
   "S(label)"/"F(label)" in either order (research/snobol/
   02-language-reference.md, "Goto field": ":S(label)", ":F(label)",
   ":S(l1)F(l2)", ":F(l1)S(l2)", ":(label)"). *)
let parse_label_name (st : state) : string =
  let p = cur_pos st in
  match advance st with
  | IDENT name -> name
  | got -> err_at p (Printf.sprintf "expected a label name in goto field but found %s" (string_of_token got))

let parse_goto (st : state) : goto option =
  match peek st with
  | COLON ->
    ignore (advance st);
    (match peek st with
     | LPAREN ->
       let open_pos = cur_pos st in
       ignore (advance st);
       let lbl = parse_label_name st in
       expect_matching st LPAREN open_pos RPAREN;
       Some { on_success = None; on_failure = None; unconditional = Some lbl }
     | IDENT _ ->
       let s_lbl = ref None and f_lbl = ref None in
       let parse_one () =
         let p = cur_pos st in
         match advance st with
         | IDENT "S" ->
           let open_pos = cur_pos st in
           expect st LPAREN;
           let l = parse_label_name st in
           expect_matching st LPAREN open_pos RPAREN;
           s_lbl := Some l
         | IDENT "F" ->
           let open_pos = cur_pos st in
           expect st LPAREN;
           let l = parse_label_name st in
           expect_matching st LPAREN open_pos RPAREN;
           f_lbl := Some l
         | got -> err_at p (Printf.sprintf "expected S or F in goto field but found %s" (string_of_token got))
       in
       parse_one ();
       (match peek st with
        | IDENT ("S" | "F") -> parse_one ()
        | _ -> ());
       Some { on_success = !s_lbl; on_failure = !f_lbl; unconditional = None }
     | got -> err_at (cur_pos st) (Printf.sprintf "malformed goto field at %s" (string_of_token got)))
  | _ -> None

(* A statement body is [subject], [subject = object], [subject pattern],
   or [subject pattern = object]. The subject is parsed once, as a
   single [parse_primary] (see the module comment for why it is
   deliberately not the full expression chain), and what follows it
   decides which of the four shapes this is:

   - an immediate EQUALS with no pattern in between: assignment
     (checkpoint 2's shape, unchanged) -- the subject must be a plain
     variable, or (week 10) an indexed variable;
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
    match subject.ek with
    | Var name ->
      ignore (advance st);
      let obj = parse_expr st in
      Assign (name, obj)
    | Index (name, idx) ->
      ignore (advance st);
      let obj = parse_expr st in
      IndexAssign (name, idx, obj)
    | _ ->
      err_at subject.epos "left-hand side of '=' must be a plain identifier or an indexed variable")
  | t when starts_operand t ->
    let pattern = parse_alt st in
    (match peek st with
     | EQUALS ->
       ignore (advance st);
       let obj = parse_expr st in
       Match (subject, pattern, Some obj)
     | _ -> Match (subject, pattern, None))
  | _ -> Expr subject

let parse_stmt (label : string option) (toks : Lexer.postok list) : stmt =
  let st = { toks } in
  let start_pos = cur_pos st in
  let body = parse_body st in
  let goto = parse_goto st in
  (match peek st with
   | EOF -> ()
   | got -> err_at (cur_pos st) (Printf.sprintf "unexpected trailing tokens on statement, starting at %s" (string_of_token got)));
  { label; body; goto; spos = start_pos }

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

(* Week 11's recovery strategy lives entirely in this one function: parse
   a single already-tokenized line, and turn a [Parse_error]/
   [Lexer.Lex_error] raised while doing so into [(None, [msg])] instead
   of letting the exception escape -- so [parse_program] below can skip
   this line and keep going instead of aborting the whole file at the
   first mistake. See the module comment for why a source line is a
   safe, unambiguous resynchronization point in this grammar
   specifically (this subset already requires one statement per line, so
   nothing needs to guess where the next statement starts). *)
let try_parse_line (label : string option) (toks : Lexer.postok list) : stmt option * string list =
  try (Some (parse_stmt label toks), [])
  with
  | Parse_error msg -> (None, [ msg ])
  | Lexer.Lex_error msg -> (None, [ msg ])

(* Parse every non-blank, non-comment line independently via
   [try_parse_line], collecting the statements that parsed and every
   error message recovered along the way, in the order found.
   [main.ml] decides what to do if the error list is non-empty. *)
let parse_program (source : string) : program * string list =
  let lines = String.split_on_char '\n' source in
  let errors = ref [] in
  let stmts =
    lines
    |> List.mapi (fun idx line -> (idx + 1, line))
    |> List.filter_map (fun (line_no, line) ->
      let trimmed = String.trim line in
      if trimmed = "" then None
      else if String.length line > 0 && line.[0] = '*' then None
      else begin
        let label, rest = split_label line in
        let col_offset = String.length line - String.length rest in
        let stmt_opt, errs = try_parse_line label (Lexer.tokenize line_no col_offset rest) in
        errors := List.rev_append errs !errors;
        stmt_opt
      end)
    |> Array.of_list
  in
  (stmts, List.rev !errors)
