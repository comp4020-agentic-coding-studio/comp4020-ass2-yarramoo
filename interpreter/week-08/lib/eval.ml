(* Week 8 keeps week 7's explicit-stack matcher and its cursor contract
   completely unchanged, and adds the vocabulary the lecture calls the
   Green Book's foundational primitives (research/snobol/
   03-pattern-matching.md, "The primitive patterns"): `LEN`, `ANY`,
   `NOTANY`, `SPAN`, `BREAK` (single-answer, no retry), and `ARB`/
   `ARBNO`/`BAL` (the three that genuinely need backtracking). No `.`/
   `$`/`@` capture or replacement yet -- that is still checkpoint 3's
   job -- so [exec_stmt]'s [Match] case is untouched from week 7.

   The session's own instruction is "this should not need you to touch
   the matching loop's control flow at all," and it doesn't: [step]'s
   [PLit]/[PConcat]/[PAlt] cases, and [backtrack], are byte-for-byte
   what week 7 already had. Everything new is either a new, single-
   answer case in [step] (`PLen`/`PAny`/`PNotAny`/`PSpan`/`PBreak`), or
   -- for `ARB`/`ARBNO`/`BAL` -- reuses [PAlt]/[PConcat] themselves
   rather than adding new backtracking machinery:

   - `ARB` is rewritten, the moment [step] sees it, into the Green
     Book's own recursive definition `ARB = NULL | LEN(1) *ARB`
     (`PAlt (PLit "", PConcat (PLen 1, PArb))`): try the null match
     first, and if the stack's recorded alternative is ever resumed,
     retry with one more character than last time, via the very same
     [PAlt] case above. `ARBNO(p)` is the same trick generalized to a
     subpattern, `ARBNO(p) = NULL | p *ARBNO(p)`.
   - `BAL` is the lecture's `BALEXP = NOTANY('()') | '(' ARBNO( *BALEXP)
     ')'`, `BAL = BALEXP ARBNO(BALEXP)`, built once as a genuinely
     self-referential OCaml value (a "tied knot": [balexp] is defined
     in terms of a [pattern] that itself contains [balexp], which
     OCaml allows here because every recursive occurrence sits
     strictly inside a data constructor, never inside a function
     application -- the same trick the lecture's own `*BALEXP`
     unevaluated-expression notation is standing in for). Matching
     never needs to know [balexp] is cyclic: [step] only ever unfolds
     one [PArbno]/[PAlt] layer at a time, exactly as far as a given
     backtrack attempt asks for.

   Neither `ARB`, `ARBNO`, nor `BAL` therefore needs its own entry in
   the [choice] stack type at all -- they retry by pushing an ordinary
   [PAlt] choice, the same as `|` does. This is deliberate, not an
   accident of code golf: it is the concrete demonstration that the
   "record an alternative, retry it on failure" machinery week 7 built
   for `|` is already general enough for the Green Book's two growth-
   by-one-unit primitives, exactly as this week's own spec claims. *)

open Ast

type value = VInt of int | VStr of string | VPattern of pattern

and pattern =
  | PLit of string
  | PLen of int
  | PAny of string
  | PNotAny of string
  | PSpan of string
  | PBreak of string
  | PArb
  | PArbno of pattern
  | PConcat of pattern * pattern
  | PAlt of pattern * pattern

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s
  | VPattern _ -> failwith "cannot convert a pattern to a string"

exception Fail_signal
exception Stmt_return
exception Stmt_freturn

let to_int = function
  | VInt n -> n
  | VStr s ->
    (match int_of_string_opt (String.trim s) with
     | Some n -> n
     | None -> raise Fail_signal)
  | VPattern _ -> failwith "cannot convert a pattern to a number"

(* A plain string or number used where a pattern is expected matches
   itself literally (research/snobol/03-pattern-matching.md: "a string
   used as a pattern matches itself"). *)
let to_pattern = function
  | VPattern p -> p
  | VStr s -> PLit s
  | VInt n -> PLit (string_of_int n)

let env : (string, value) Hashtbl.t = Hashtbl.create 64

let lookup name =
  match Hashtbl.find_opt env name with
  | Some v -> v
  | None -> VStr ""

let assign name v =
  Hashtbl.replace env name v;
  if name = "OUTPUT" then print_endline (string_of_value v)

let eval_compare (name : string) (args : value list) (to_int : value -> int) : value =
  match args with
  | [ a; b ] ->
    let x = to_int a and y = to_int b in
    let ok =
      match name with
      | "LT" -> x < y
      | "LE" -> x <= y
      | "EQ" -> x = y
      | "NE" -> x <> y
      | "GE" -> x >= y
      | "GT" -> x > y
      | _ -> false
    in
    if ok then VStr "" else raise Fail_signal
  | _ -> failwith (Printf.sprintf "%s requires exactly two arguments" name)

let is_comparison name =
  match name with
  | "LT" | "LE" | "EQ" | "NE" | "GE" | "GT" -> true
  | _ -> false

(* This week's four non-retrying primitives plus `ARBNO`, told apart
   from a real DEFINE'd call purely by name -- exactly like
   [is_comparison]/[eval_compare] above. `ARB` and `BAL` are bare
   constants, not functions (research/snobol/03-pattern-matching.md
   line 106 lists both alongside `FAIL`/`FENCE`/`ABORT`/`SUCCEED`/`REM`),
   so they are handled in [eval_expr]'s [Var] case instead of here. *)
let is_pattern_primitive name =
  match name with
  | "LEN" | "ANY" | "NOTANY" | "SPAN" | "BREAK" | "ARBNO" -> true
  | _ -> false

let eval_pattern_primitive (name : string) (args : value list) : value =
  match name, args with
  | "LEN", [ n ] -> VPattern (PLen (to_int n))
  | "ANY", [ s ] -> VPattern (PAny (string_of_value s))
  | "NOTANY", [ s ] -> VPattern (PNotAny (string_of_value s))
  | "SPAN", [ s ] -> VPattern (PSpan (string_of_value s))
  | "BREAK", [ s ] -> VPattern (PBreak (string_of_value s))
  | "ARBNO", [ p ] -> VPattern (PArbno (to_pattern p))
  | _ -> failwith (Printf.sprintf "%s requires exactly one argument" name)

(* `BAL`, built exactly as the lecture derives it -- see the module
   comment for why OCaml accepts a directly self-referential [pattern]
   value here. Built once, at module load, and reused as the single
   [VPattern] every `BAL` reference evaluates to. *)
let rec balexp : pattern =
  PAlt (PNotAny "()", PConcat (PLit "(", PConcat (PArbno balexp, PLit ")")))

let bal : pattern = PConcat (balexp, PArbno balexp)

type def = { formals : string list; locals : string list; entry : string }

let defs : (string, def) Hashtbl.t = Hashtbl.create 16

type outcome = Success | Failure

let program : stmt array ref = ref [||]
let labels : (string, int) Hashtbl.t = Hashtbl.create 64

let build_labels (prog : stmt array) : unit =
  Hashtbl.clear labels;
  Array.iteri
    (fun i s -> match s.label with Some l -> Hashtbl.replace labels l i | None -> ())
    prog

(* Trace instrumentation, unchanged from week 7 -- see that week's
   module comment. *)
let trace_enabled = ref false
let trace (msg : string) : unit = if !trace_enabled then print_endline msg

let str_contains (set : string) (c : char) : bool = String.contains set c

(* The explicit-stack matcher, extended with this week's vocabulary.
   [choice] is unchanged from week 7: one recorded, not-yet-tried
   [PAlt] alternative. `ARB`/`ARBNO`/`BAL` never construct a [choice]
   of their own -- see the module comment -- so this type needs no new
   case at all. *)
type choice = { alt : pattern; rest : pattern list; at : int }

let match_from (pat : pattern) (subj : string) (start : int) : int option =
  let len = String.length subj in
  let stack : choice list ref = ref [] in
  let rec step (todo : pattern list) (pos : int) : int option =
    match todo with
    | [] ->
      trace (Printf.sprintf "    matched, cursor now at %d" pos);
      Some pos
    | PLit s :: rest ->
      let l = String.length s in
      if pos + l <= len && String.sub subj pos l = s then begin
        trace (Printf.sprintf "    %S matches at %d" s pos);
        step rest (pos + l)
      end else begin
        trace (Printf.sprintf "    %S fails at %d" s pos);
        backtrack ()
      end
    | PLen n :: rest ->
      if n >= 0 && pos + n <= len then begin
        trace (Printf.sprintf "    LEN(%d) matches at %d" n pos);
        step rest (pos + n)
      end else begin
        trace (Printf.sprintf "    LEN(%d) fails at %d" n pos);
        backtrack ()
      end
    | PAny set :: rest ->
      if pos < len && str_contains set subj.[pos] then begin
        trace (Printf.sprintf "    ANY(%S) matches %C at %d" set subj.[pos] pos);
        step rest (pos + 1)
      end else begin
        trace (Printf.sprintf "    ANY(%S) fails at %d" set pos);
        backtrack ()
      end
    | PNotAny set :: rest ->
      if pos < len && not (str_contains set subj.[pos]) then begin
        trace (Printf.sprintf "    NOTANY(%S) matches %C at %d" set subj.[pos] pos);
        step rest (pos + 1)
      end else begin
        trace (Printf.sprintf "    NOTANY(%S) fails at %d" set pos);
        backtrack ()
      end
    | PSpan set :: rest ->
      (* Longest run (>=1 char) from [set]. One attempt, at the
         maximal length -- SPAN does not retry shorter on backtrack
         "in the usual case" (research file), so neither does this. *)
      let j = ref pos in
      while !j < len && str_contains set subj.[!j] do incr j done;
      if !j > pos then begin
        trace (Printf.sprintf "    SPAN(%S) matches [%d,%d)" set pos !j);
        step rest !j
      end else begin
        trace (Printf.sprintf "    SPAN(%S) fails at %d (no characters from the set)" set pos);
        backtrack ()
      end
    | PBreak set :: rest ->
      (* Longest run NOT in [set]; may be null if the very next
         character is already in [set]. Deterministic length, so also
         a single attempt -- but unlike SPAN, this one always
         succeeds. *)
      let j = ref pos in
      while !j < len && not (str_contains set subj.[!j]) do incr j done;
      trace (Printf.sprintf "    BREAK(%S) matches [%d,%d)" set pos !j);
      step rest !j
    | PArb :: rest ->
      (* Green Book: `ARB = NULL | LEN(1) *ARB` -- rewrite into the
         [PAlt] case below, which does the actual recording/resuming. *)
      step (PAlt (PLit "", PConcat (PLen 1, PArb)) :: rest) pos
    | PArbno p :: rest ->
      (* Same trick, generalized: `ARBNO(p) = NULL | p *ARBNO(p)`. *)
      step (PAlt (PLit "", PConcat (p, PArbno p)) :: rest) pos
    | PConcat (p1, p2) :: rest -> step (p1 :: p2 :: rest) pos
    | PAlt (p1, p2) :: rest ->
      stack := { alt = p2; rest; at = pos } :: !stack;
      trace (Printf.sprintf "    at %d: trying first alternative, recording second on the history list" pos);
      step (p1 :: rest) pos
  and backtrack () : int option =
    match !stack with
    | [] -> None
    | { alt; rest; at } :: tl ->
      stack := tl;
      trace (Printf.sprintf "    backtrack: resuming recorded alternative at %d" at);
      step (alt :: rest) at
  in
  step [ pat ] start

(* Unanchored search, unchanged from week 7. *)
let find_match (pat : pattern) (subj : string) : int option =
  let len = String.length subj in
  let rec try_from start =
    if start > len then None
    else begin
      trace (Printf.sprintf "  trying match at position %d" start);
      match match_from pat subj start with
      | Some endp -> Some endp
      | None -> try_from (start + 1)
    end
  in
  try_from 0

let rec eval_expr (e : expr) : value =
  match e with
  | Int n -> VInt n
  | Str s -> VStr s
  | Var "ARB" -> VPattern PArb (* built-in pattern constant, not a variable *)
  | Var "BAL" -> VPattern bal (* built-in pattern constant, not a variable *)
  | Var name -> lookup name
  | Neg e -> VInt (- (to_int (eval_expr e)))
  | Bin (op, l, r) ->
    let a = to_int (eval_expr l) and b = to_int (eval_expr r) in
    (match op with
     | Add -> VInt (a + b)
     | Sub -> VInt (a - b)
     | Mul -> VInt (a * b)
     | Div ->
       if b = 0 then raise Fail_signal
       else VInt (a / b))
  | Concat (l, r) ->
    let lv = eval_expr l and rv = eval_expr r in
    (match lv, rv with
     | VPattern _, _ | _, VPattern _ ->
       VPattern (PConcat (to_pattern lv, to_pattern rv))
     | _ -> VStr (string_of_value lv ^ string_of_value rv))
  | Alt (l, r) ->
    let lv = eval_expr l and rv = eval_expr r in
    VPattern (PAlt (to_pattern lv, to_pattern rv))
  | Call (name, args) ->
    let arg_vals = List.map eval_expr args in
    if name = "DEFINE" then eval_define arg_vals
    else if is_comparison name then eval_compare name arg_vals to_int
    else if is_pattern_primitive name then eval_pattern_primitive name arg_vals
    else
      match Hashtbl.find_opt defs name with
      | Some d -> call_function name d arg_vals
      | None -> failwith (Printf.sprintf "call to undefined function: %s" name)

and eval_define (args : value list) : value =
  let proto =
    match args with
    | v :: _ -> string_of_value v
    | [] -> failwith "DEFINE requires at least one argument"
  in
  let entry_arg =
    match args with
    | [ _; e ] -> Some (string_of_value e)
    | _ -> None
  in
  let split_csv s =
    String.split_on_char ',' s
    |> List.map String.trim
    |> List.filter (fun s -> s <> "")
  in
  let open_paren =
    match String.index_opt proto '(' with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: malformed prototype %S (missing '(')" proto)
  in
  let close_paren =
    match String.index_opt proto ')' with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: malformed prototype %S (missing ')')" proto)
  in
  let name = String.sub proto 0 open_paren in
  let formals_str = String.sub proto (open_paren + 1) (close_paren - open_paren - 1) in
  let locals_str =
    String.sub proto (close_paren + 1) (String.length proto - close_paren - 1)
  in
  let formals = split_csv formals_str in
  let locals = split_csv locals_str in
  let entry = match entry_arg with Some e -> e | None -> name in
  Hashtbl.replace defs name { formals; locals; entry };
  VStr ""

and call_function (fn_name : string) (d : def) (args : value list) : value =
  let tracked = fn_name :: (d.formals @ d.locals) in
  let saved = List.map (fun v -> (v, lookup v)) tracked in
  let restore () = List.iter (fun (v, old) -> Hashtbl.replace env v old) saved in
  let rec bind formals actuals =
    match formals, actuals with
    | [], _ -> ()
    | f :: fs, a :: rest -> Hashtbl.replace env f a; bind fs rest
    | f :: fs, [] -> Hashtbl.replace env f (VStr ""); bind fs []
  in
  bind d.formals args;
  List.iter (fun l -> Hashtbl.replace env l (VStr "")) d.locals;
  let entry_pc =
    match Hashtbl.find_opt labels d.entry with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: unknown entry label %s" d.entry)
  in
  (try
     run_from entry_pc;
     restore ();
     raise Fail_signal
   with
   | Stmt_return ->
     let result = lookup fn_name in
     restore ();
     result
   | Stmt_freturn ->
     restore ();
     raise Fail_signal)

and exec_stmt (s : stmt) : outcome =
  match s.body with
  | Assign (name, e) ->
    (try
       let v = eval_expr e in
       assign name v;
       Success
     with Fail_signal -> Failure)
  | Match (subj_e, pat_e) ->
    (try
       let subj = string_of_value (eval_expr subj_e) in
       let pat = to_pattern (eval_expr pat_e) in
       trace (Printf.sprintf "matching against %S" subj);
       (match find_match pat subj with
        | Some _ -> Success
        | None -> Failure)
     with Fail_signal -> Failure)
  | Expr e ->
    (try
       ignore (eval_expr e);
       Success
     with Fail_signal -> Failure)

and goto_target (lbl : string) : int =
  if lbl = "RETURN" then raise Stmt_return
  else if lbl = "FRETURN" then raise Stmt_freturn
  else
    match Hashtbl.find_opt labels lbl with
    | Some i -> i
    | None -> failwith (Printf.sprintf "undefined label: %s" lbl)

and run_from (pc : int) : unit =
  if pc < 0 || pc >= Array.length !program then ()
  else begin
    let s = (!program).(pc) in
    if s.label = Some "END" then ()
    else begin
      let outcome = exec_stmt s in
      let next_pc =
        match s.goto with
        | None -> pc + 1
        | Some g ->
          (match g.unconditional with
           | Some lbl -> goto_target lbl
           | None ->
             (match outcome, g.on_success, g.on_failure with
              | Success, Some lbl, _ -> goto_target lbl
              | Failure, _, Some lbl -> goto_target lbl
              | _ -> pc + 1))
      in
      run_from next_pc
    end
  end

let run (prog : program) : unit =
  program := prog;
  build_labels prog;
  try run_from 0
  with Stmt_return | Stmt_freturn ->
    failwith "RETURN/FRETURN used outside of any DEFINE'd function"
