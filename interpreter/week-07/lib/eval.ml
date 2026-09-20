(* Week 7 keeps checkpoint 2's complete statement executor (success/
   failure control flow, DEFINE/call frames, RETURN/FRETURN) unchanged,
   and adds the first slice of Movement III: a pattern type for literal
   matching, concatenation, and alternation only (research/snobol/
   03-pattern-matching.md, "Pattern construction operators") -- no
   ANY/NOTANY/SPAN/BREAK/ARB (week 8) and no "."/capture/replacement
   (checkpoint 3), so [exec_stmt]'s new [Match] case only reports
   success or failure; nothing is bound and nothing is replaced.

   The backtracking strategy is deliberately NOT checkpoint 3's. This
   week's own session material asks for the explicit-stack version at
   least once, to make concrete what the lecture calls SNOBOL4's real
   runtime strategy: a "Pattern-Matching History List" of recorded,
   not-yet-tried alternatives that a failure pops and resumes, rather
   than relying on the host language's own call stack for backtracking
   (checkpoint 3's [match_pat] is CPS-based, and uses OCaml's call stack
   for exactly that job -- see interpreter/checkpoint-3/lib/eval.ml for
   the contrast). Here, [stack] in [match_from] below *is* that history
   list: a [PAlt] node pushes its untried right-hand alternative before
   trying its left, and [backtrack] pops and resumes the most recently
   pushed one -- the same last-in-first-out discipline as the "record
   and resume" requirement in this week's own spec. The cursor contract
   is Griswold's: a pattern element only ever moves the cursor forward
   or leaves it where it found it; it is never moved backward or
   mutated in place. *)

open Ast

type value = VInt of int | VStr of string | VPattern of pattern

and pattern = PLit of string | PConcat of pattern * pattern | PAlt of pattern * pattern

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

(* TODO(week 7): a plain string or number used where a pattern is
   expected matches itself literally (research/snobol/
   03-pattern-matching.md: "a string used as a pattern matches itself").
   [VPattern p] is already a pattern -- return it unchanged. [VStr s] /
   [VInt n] become a literal [PLit] of their printed form. *)
let to_pattern (_v : value) : pattern =
  failwith "TODO: to_pattern (VPattern -> itself; VStr/VInt -> PLit of their printed form)"

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

(* Trace instrumentation for the matcher below: every cursor position
   the outer search tries, and every alternative recorded on or resumed
   from the explicit stack, so a run can be inspected rather than taken
   on faith -- this week's own spec asks for exactly this log. *)
let trace_enabled = ref false
let trace (msg : string) : unit = if !trace_enabled then print_endline msg

(* [choice] is one recorded, not-yet-tried alternative: the pattern to
   try if everything after this choice point fails, what still has to
   match after it succeeds, and the cursor position to resume at (the
   position [PAlt] was reached at, since neither alternative has moved
   the cursor yet). This is the "history list" the module comment
   describes -- keep it as explicit, inspectable data on [stack], not
   hidden inside a closure or continuation. *)
type choice = { alt : pattern; rest : pattern list; at : int }

(* TODO(week 7): implement the explicit-stack backtracking matcher.
   [match_from pat subj start] tries to match [pat] against [subj]
   starting exactly at [start] (anchored -- it never itself advances
   the cursor to a later starting position; that is [find_match]'s job
   below, not this function's). Returns [Some end_pos] on success,
   [None] if every recorded alternative has been exhausted.

   A reasonable shape is two mutually recursive local functions closed
   over a [stack : choice list ref]:

   - [step todo pos]: [todo] is the list of pattern pieces still to be
     matched, left to right; [pos] is the current cursor.
       - [[]]: nothing left to match -- succeed with [Some pos].
       - [PLit s :: rest]: does [s] occur in [subj] starting at [pos]?
         If so, continue with [step rest (pos + String.length s)]. If
         not, this path has failed -- call [backtrack ()] instead of
         returning [None] directly, so a still-untried alternative
         elsewhere on the stack gets a chance.
       - [PConcat (p1, p2) :: rest]: concatenation is just sequencing --
         [step (p1 :: p2 :: rest) pos].
       - [PAlt (p1, p2) :: rest]: push [{ alt = p2; rest; at = pos }]
         onto [stack] (recording the untried right-hand alternative,
         resumable at the *same* position, since nothing has matched
         yet), then try the left: [step (p1 :: rest) pos].
   - [backtrack ()]: pop the most recently pushed [choice] off [stack]
     and resume it with [step (alt :: rest) at]; if [stack] is empty,
     every alternative has failed -- return [None].

   Call [trace] (a plain [string -> unit], already defined above) at
   the points that matter for the "log every position/alternative"
   requirement: when a literal matches or fails, when an alternative is
   recorded, and when one is resumed. *)
let match_from (_pat : pattern) (_subj : string) (_start : int) : int option =
  failwith "TODO: match_from (explicit-stack backtracking -- see the comment above)"

(* TODO(week 7): implement [find_match], the unanchored outer search
   (research/snobol/03-pattern-matching.md, "matching is inherently
   unanchored"): try [match_from pat subj 0] first; if that returns
   [None] (every alternative recorded at position 0 has been
   exhausted), try position 1, then 2, and so on up to and including
   [String.length subj], returning the first [Some _] found, or [None]
   if no starting position works at all. A [trace] call before each
   attempt is what lets a run show "both alternatives are tried before
   the cursor moves on". *)
let find_match (_pat : pattern) (_subj : string) : int option =
  failwith "TODO: find_match (try match_from at every starting position 0..length subj)"

let rec eval_expr (e : expr) : value =
  match e with
  | Int n -> VInt n
  | Str s -> VStr s
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
  | Match (_subj_e, _pat_e) ->
    (* TODO(week 7): evaluate the subject ([eval_expr subj_e], then
       [string_of_value]) and the pattern ([eval_expr pat_e], then
       [to_pattern]); either can raise [Fail_signal], which should fail
       the whole statement just like [Assign]/[Expr] above. Then call
       [find_match] on them: [Some _] is [Success], [None] is
       [Failure]. Nothing is bound and nothing is replaced this week --
       the pattern's success or failure is all this statement reports. *)
    failwith "TODO: exec_stmt's Match case (evaluate subject/pattern, call find_match)"
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
