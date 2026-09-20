(* Checkpoint 2: success/failure control flow, DEFINE/RETURN/FRETURN.

   The global, non-lexically-scoped symbol table from checkpoint 1 is
   unchanged. What's new:

   - Every statement produces an [outcome] (Success or Failure), and the
     goto field decides where execution goes next based on that outcome
     (research/snobol/02-language-reference.md, "Statement structure":
     success/failure goto is SNOBOL4's only control-flow primitive).
   - Arithmetic on a non-numeric string, and division by zero, are now
     genuine, catchable statement failures ([Fail_signal]) instead of a
     hard [failwith] -- this is the "at least one genuinely failing
     built-in" requirement.
   - [DEFINE] registers a user function's name, formal parameters, and
     local variables from its prototype string. Calling it saves the
     current values of the function name, its formals, and its locals;
     binds the formals to the call's argument values and the locals to
     the null string; runs the function body starting at its entry
     label; and restores the saved values afterward -- this is SNOBOL4's
     real save/restore call-frame discipline, not a simplified "closure"
     model (research/snobol/02-language-reference.md, "DEFINE and call
     frames").
   - [RETURN] and [FRETURN] are goto targets recognised by name (not
     ordinary labels) and implemented as OCaml exceptions: a function
     call in this interpreter really is just running statements starting
     at the entry label using an ordinary (recursive) OCaml function
     call, so "return to whichever call is currently active" falls out
     for free from OCaml's own exception handling always reaching the
     *nearest* enclosing handler -- which is exactly the most-recently
     entered, still-active call, i.e. the correct frame, including for
     recursive calls.

   Checkpoint 3 adds the pattern sublanguage as a first-class value
   (research/snobol/03-pattern-matching.md):

   - [pattern] is the matcher's own little AST, built by [to_pattern]
     coercing an evaluated [value] (a [VPattern] already is one; a
     [VStr]/[VInt] becomes a literal [PLit]) and by [eval_expr]'s
     [Concat]/[Alt]/[Bind] cases and the LEN/ANY/NOTANY/SPAN/BREAK
     primitive dispatch.
   - [match_pat] is a CPS backtracking matcher: it matches [pattern]
     against [subj] starting at [pos] and calls its success
     continuation [k] with the new cursor position and the (functional,
     not mutated) list of conditional bindings accumulated so far; it
     returns [true] only if [k] itself eventually returns [true],
     letting OCaml's own call stack and the [k] chain do all the
     backtracking (concatenation nests continuations, alternation tries
     the left branch and falls back to `||`-ing in the right one, [ARB]
     retries with an ever-larger length). This is exactly Griswold's
     cursor-model contract: never move the subject, never move the
     cursor backward on success, leave it untouched on failure
     [Griswold1981].
   - [find_match] is the unanchored driver: try the whole pattern at
     cursor 0; if every alternative anywhere in it fails, advance the
     cursor by one and start over from scratch (not a single
     left-to-right character scan misreading -- see the research file's
     `'--1B-A-' (ANY('AB') | '1' ABORT)` example).
   - [exec_stmt]'s new [Match] case follows the Green Book's fixed
     7-step execution order (research file, "How a pattern-matching
     statement actually executes"): conditional (".") bindings commit
     the instant the match itself succeeds (step 4), strictly *before*
     the replacement object is evaluated (step 5) -- so a failing
     replacement object still fails the statement, but does not undo
     bindings already committed by a successful match. *)

open Ast

(* A pattern is deliberately its own little AST, separate from [expr]:
   [Concat]/[Alt]/[Bind] on the [expr] side describe *how a pattern
   value is built* (by evaluating an expression), while [pattern]
   describes what the matcher actually walks over once that value
   exists. [PLit] covers both an explicit string literal used as a
   pattern (`'AB'`) and any plain string/int value coerced into one by
   [to_pattern] (e.g. a variable holding a string, used directly as a
   pattern). [PArb] is SNOBOL4's built-in constant `ARB`, not a
   function call -- see [eval_expr]'s [Var] case. *)
type pattern =
  | PLit of string
  | PLen of int
  | PAny of string
  | PNotAny of string
  | PSpan of string
  | PBreak of string
  | PArb
  | PConcat of pattern * pattern
  | PAlt of pattern * pattern
  | PBind of pattern * string

type value = VInt of int | VStr of string | VPattern of pattern

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s
  | VPattern _ ->
    failwith
      "cannot use a pattern value as a plain string (a pattern is only \
       meaningful as the pattern field of a match statement)"

(* A statement-level failure, distinct from OCaml-level bugs in this
   interpreter itself (which still raise [Failure] via [failwith] and are
   allowed to crash the interpreter -- e.g. calling an undefined
   function, or DEFINE-ing a malformed prototype). [Fail_signal] is the
   only failure a goto field reacts to. *)
exception Fail_signal

(* RETURN / FRETURN, as control-flow exceptions -- see the module
   comment above for why exceptions are the right tool here. *)
exception Stmt_return
exception Stmt_freturn

let to_int = function
  | VInt n -> n
  | VStr s ->
    (match int_of_string_opt (String.trim s) with
     | Some n -> n
     | None -> raise Fail_signal)
  | VPattern _ ->
    failwith "cannot use a pattern value where a number was expected"

(* Coerce an evaluated value into a [pattern]: a pattern value is
   already one; a plain string or integer becomes a literal match
   against its printed form -- this is what lets an ordinary variable
   or string literal be used directly as (part of) a pattern, e.g.
   `SUBJ 'HELLO'` or `SUBJ SOMEVAR`. *)
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

(* Comparison predicates (research/snobol/02-language-reference.md,
   "Success and failure as the only branch primitive"): there is no
   boolean type and no `if` in SNOBOL4. `LT(N1,N2)` "returns true" only in
   the sense that it succeeds (yielding the null string, never inspected)
   or fails; a goto field is what actually branches on it. This is the
   idiom that makes loops possible without any dedicated looping
   construct, e.g. `GT(N,10) :S(DONE)`. Scoped to numeric comparison only
   (`LT`/`LE`/`EQ`/`NE`/`GE`/`GT`) -- real SNOBOL4 also has string-identity
   `IDENT`/`DIFFER` and lexical-order `LGT`, which are out of scope here. *)
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

(* Pattern primitives (research/snobol/03-pattern-matching.md, "The
   primitive patterns"). They parse as ordinary [Call] nodes (reusing
   checkpoint 2's function-call syntax -- see ast.ml's module comment)
   and are told apart from a real DEFINE'd call purely by name, exactly
   like [is_comparison]/[eval_compare] above. [ARB] is a bare constant,
   not a function, so it is handled separately in [eval_expr]'s [Var]
   case instead of here. *)
let is_pattern_primitive name =
  match name with
  | "LEN" | "ANY" | "NOTANY" | "SPAN" | "BREAK" -> true
  | _ -> false

let eval_pattern_primitive (name : string) (args : value list) : value =
  match name, args with
  | "LEN", [ n ] -> VPattern (PLen (to_int n))
  | "ANY", [ s ] -> VPattern (PAny (string_of_value s))
  | "NOTANY", [ s ] -> VPattern (PNotAny (string_of_value s))
  | "SPAN", [ s ] -> VPattern (PSpan (string_of_value s))
  | "BREAK", [ s ] -> VPattern (PBreak (string_of_value s))
  | _ -> failwith (Printf.sprintf "%s requires exactly one argument" name)

(* A DEFINE'd function: its formal parameters, its local variables (reset
   to the null string on each call), and the label its body starts at
   (usually the function's own name, but DEFINE's optional second
   argument can point it elsewhere). *)
type def = { formals : string list; locals : string list; entry : string }

let defs : (string, def) Hashtbl.t = Hashtbl.create 16

type outcome = Success | Failure

(* The running program and its label table. Mutable and global because
   [call_function] needs to jump into the middle of the very same
   statement array the top-level driver is (or, for a nested call, isn't
   currently) executing -- there is exactly one program per run. *)
let program : stmt array ref = ref [||]
let labels : (string, int) Hashtbl.t = Hashtbl.create 64

let build_labels (prog : stmt array) : unit =
  Hashtbl.clear labels;
  Array.iteri
    (fun i s -> match s.label with Some l -> Hashtbl.replace labels l i | None -> ())
    prog

(* A conditional (".") binding captured during one matching attempt --
   [name], and the substring it matched. Kept as a plain functional
   list threaded through the continuation chain (never mutated in
   place) so that an abandoned backtracking attempt simply drops its
   list on the floor instead of needing to be undone -- only the list
   belonging to the attempt that [find_match] ultimately accepts is
   ever looked at again (by [exec_stmt], which commits it into [env]). *)
type binding = string * string

let str_contains (set : string) (c : char) : bool = String.contains set c

(* The backtracking matcher itself. [k] is the success continuation: it
   receives the cursor position just after this pattern matched and the
   bindings accumulated so far, and decides whether the *rest* of the
   overall match (everything concatenated after this point) ultimately
   succeeds. [match_pat] returns [true] exactly when some way of
   matching [pat] here leads to [k] eventually returning [true] --
   backtracking is simply OCaml trying another way when [k] says no.
   Per Griswold's cursor-model contract, every case below either calls
   [k] with a cursor that has moved forward-or-stayed-equal, or returns
   [false] having touched nothing [Griswold1981]. *)
let rec match_pat (pat : pattern) (subj : string) (pos : int)
    (binds : binding list) (k : int -> binding list -> bool) : bool =
  let len = String.length subj in
  match pat with
  | PLit s ->
    let l = String.length s in
    pos + l <= len && String.sub subj pos l = s && k (pos + l) binds
  | PLen n -> n >= 0 && pos + n <= len && k (pos + n) binds
  | PAny set -> pos < len && str_contains set subj.[pos] && k (pos + 1) binds
  | PNotAny set ->
    pos < len && (not (str_contains set subj.[pos])) && k (pos + 1) binds
  | PSpan set ->
    (* Longest run (>=1 char) from [set]. Per the research file this
       does *not* retry shorter matches on backtrack "in the usual
       case" -- so, deliberately, neither does this implementation: one
       attempt, at the maximal length, or outright failure. *)
    let j = ref pos in
    while !j < len && str_contains set subj.[!j] do incr j done;
    !j > pos && k !j binds
  | PBreak set ->
    (* Longest run *not* in [set], stopping just before a character
       that is in it (or at the end of the subject); may be null. This
       length is uniquely determined by the subject and [set] -- there
       is nothing to backtrack over, so (like [PSpan] above) this is a
       single attempt, not a retry loop. *)
    let j = ref pos in
    while !j < len && not (str_contains set subj.[!j]) do incr j done;
    k !j binds
  | PArb ->
    (* Shortest first (the null match), extending by one character on
       each retry -- Green Book's `ARB = NULL | LEN(1) *ARB`. This is
       the one primitive here that genuinely retries multiple lengths. *)
    let rec try_len l = pos + l <= len && (k (pos + l) binds || try_len (l + 1)) in
    try_len 0
  | PConcat (p1, p2) ->
    match_pat p1 subj pos binds (fun pos2 binds2 -> match_pat p2 subj pos2 binds2 k)
  | PAlt (p1, p2) -> match_pat p1 subj pos binds k || match_pat p2 subj pos binds k
  | PBind (p, name) ->
    match_pat p subj pos binds (fun pos2 binds2 ->
      let matched = String.sub subj pos (pos2 - pos) in
      k pos2 ((name, matched) :: binds2))

(* Unanchored search: try the whole pattern starting at cursor 0; if
   every alternative anywhere inside it fails, advance the cursor by
   one character and start completely over, rather than treating a
   single failed attempt as "no match anywhere" (research file's
   `'--1B-A-' (ANY('AB') | '1' ABORT)` example turns on exactly this
   distinction). Returns the matched span `[start, endp)` and the
   bindings belonging to the first successful attempt found, in the
   same left-to-right, first-alternative-first order the backtracking
   search itself explores. *)
let find_match (pat : pattern) (subj : string) : (int * int * binding list) option =
  let len = String.length subj in
  let rec try_from start =
    if start > len then None
    else
      let result = ref None in
      let found =
        match_pat pat subj start [] (fun endp binds ->
          result := Some (start, endp, binds);
          true)
      in
      if found then !result else try_from (start + 1)
  in
  try_from 0

let rec eval_expr (e : expr) : value =
  match e with
  | Int n -> VInt n
  | Str s -> VStr s
  | Var "ARB" -> VPattern PArb (* built-in pattern constant, not a variable *)
  | Var name -> lookup name
  | Neg e -> VInt (- (to_int (eval_expr e)))
  | Bin (op, l, r) ->
    let a = to_int (eval_expr l) and b = to_int (eval_expr r) in
    (match op with
     | Add -> VInt (a + b)
     | Sub -> VInt (a - b)
     | Mul -> VInt (a * b)
     | Div ->
       if b = 0 then raise Fail_signal (* division by zero fails, doesn't crash *)
       else VInt (a / b))
  | Concat (l, r) ->
    let lv = eval_expr l and rv = eval_expr r in
    (* Checkpoint 1's plain string concatenation and a pattern
       concatenation are the same [Concat] node -- which one this is
       is a runtime question, decided by whether either operand turned
       out to be a pattern value (see ast.ml's module comment). *)
    (match lv, rv with
     | VPattern _, _ | _, VPattern _ -> VPattern (PConcat (to_pattern lv, to_pattern rv))
     | _ -> VStr (string_of_value lv ^ string_of_value rv))
  | Alt (l, r) ->
    (* Alternation is only ever meaningful as a pattern operator, so
       (unlike [Concat]) it always coerces both sides to patterns, even
       if a bare string literal is one of them (e.g. `ANY('AB') | '1'`). *)
    VPattern (PAlt (to_pattern (eval_expr l), to_pattern (eval_expr r)))
  | Bind (e, name) -> VPattern (PBind (to_pattern (eval_expr e), name))
  | Call (name, args) ->
    let arg_vals = List.map eval_expr args in
    if name = "DEFINE" then eval_define arg_vals
    else if is_comparison name then eval_compare name arg_vals to_int
    else if is_pattern_primitive name then eval_pattern_primitive name arg_vals
    else
      match Hashtbl.find_opt defs name with
      | Some d -> call_function name d arg_vals
      | None -> failwith (Printf.sprintf "call to undefined function: %s" name)

(* DEFINE('NAME(ARG1,ARG2)LOCAL1,LOCAL2' [, 'ENTRYLABEL']). The prototype
   string's own grammar (a name, then a parenthesized comma-separated
   formal list, then a comma-separated local list with no parens) is
   parsed here with plain string splitting -- it is a tiny, fixed shape,
   not worth a sub-lexer. *)
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
     (* Fell off the end of the program without RETURN/FRETURN: SNOBOL4
        treats this as a failure to return properly. Restoring the saved
        state and signalling failure is the conservative choice. *)
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
  | Expr e ->
    (try
       ignore (eval_expr e);
       Success
     with Fail_signal -> Failure)
  | Match (subject_e, pattern_e, object_e) ->
    (* Green Book Ch.10's fixed execution order for a pattern-matching
       statement (research/snobol/03-pattern-matching.md, "How a
       pattern-matching statement actually executes"): subject, then
       pattern, then the match itself, then (on success) commit
       conditional bindings, then evaluate the replacement object, then
       perform the replacement. Steps 1/2/5 can each fail on their own
       (caught here as [Fail_signal]); step 3 failing is reported by
       [find_match] returning [None], not by raising. *)
    (try
       let subject_v = eval_expr subject_e in
       let subject_s = string_of_value subject_v in
       let pat = to_pattern (eval_expr pattern_e) in
       match find_match pat subject_s with
       | None -> Failure
       | Some (start, endp, binds) ->
         (* Step 4: conditional (".") bindings commit now, unconditionally,
            because the match itself already succeeded -- independent of
            whatever the replacement object does next. *)
         List.iter (fun (name, matched) -> assign name (VStr matched)) (List.rev binds);
         (match object_e with
          | None -> Success (* plain pattern-match statement, no replacement *)
          | Some obj_e ->
            (try
               let replacement = string_of_value (eval_expr obj_e) in
               let new_s =
                 String.sub subject_s 0 start ^ replacement
                 ^ String.sub subject_s endp (String.length subject_s - endp)
               in
               match subject_e with
               | Var name ->
                 assign name (VStr new_s);
                 Success
               | _ ->
                 failwith
                   "a replacement statement's subject must be a plain \
                    variable (this subset does not support replacing into, \
                    e.g., a function-call lvalue)"
             with Fail_signal -> Failure))
     with Fail_signal -> Failure)

(* Resolve a goto-field label to a statement index, treating RETURN and
   FRETURN as control exceptions rather than ordinary labels -- see the
   module comment. Using either as a label at the top level, outside any
   call, is a program bug reported by [run]. *)
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
