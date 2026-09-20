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

(* TODO(checkpoint 3): implement [to_pattern] -- coerce an evaluated
   value into a [pattern]: a [VPattern] already is one; a plain string
   or integer should become a literal match against its printed form
   ([PLit]) -- this is what lets an ordinary variable or string literal
   be used directly as (part of) a pattern, e.g. `SUBJ 'HELLO'` or
   `SUBJ SOMEVAR`. This is used everywhere a pattern value is needed
   (below in [eval_expr]'s [Concat]/[Alt]/[Bind] cases, and in
   [exec_stmt]'s [Match] case), so nothing pattern-related will work
   until it does. *)
let to_pattern (_v : value) : pattern =
  failwith "TODO: implement to_pattern (VPattern -> itself; VStr/VInt -> PLit of their printed form)"

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

(* TODO(checkpoint 3): implement [eval_pattern_primitive] -- build the
   [pattern] value each primitive denotes, from its evaluated argument(s):
     - "LEN", [n]     -> PLen (to_int n)
     - "ANY", [s]     -> PAny (string_of_value s)
     - "NOTANY", [s]  -> PNotAny (string_of_value s)
     - "SPAN", [s]    -> PSpan (string_of_value s)
     - "BREAK", [s]   -> PBreak (string_of_value s)
   each wrapped in [VPattern]. See research/snobol/03-pattern-matching.md,
   "The primitive patterns", for what each one actually means -- LEN is
   an exact character count, ANY/NOTANY match exactly one character,
   SPAN/BREAK are greedy runs (see [match_pat] below for their precise,
   non-backtracking semantics). *)
let eval_pattern_primitive (_name : string) (_args : value list) : value =
  failwith "TODO: implement eval_pattern_primitive (LEN/ANY/NOTANY/SPAN/BREAK -> VPattern ...)"

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
(* TODO(checkpoint 3): implement [match_pat], the CPS backtracking
   matcher. Signature (keep it exactly, [find_match] below depends on
   it): given a [pattern], the [subj]ect string, a starting cursor
   [pos], the [binds] accumulated so far, and a success continuation
   [k] that takes the cursor position just after this pattern matched
   plus the (possibly extended) bindings list and decides whether
   *everything after this point* ultimately succeeds -- return [true]
   exactly when some way of matching [pat] here leads [k] to eventually
   return [true]. Backtracking is nothing more than trying another way
   when [k] returns [false].

   Per Griswold's cursor-model contract, every case must either call
   [k] with a cursor that has moved forward-or-stayed-equal, or return
   [false] having touched nothing else [Griswold1981]. What each case
   needs to do (research/snobol/03-pattern-matching.md, "The primitive
   patterns"):
     - PLit s      : the next [String.length s] characters of [subj]
                     must equal [s] exactly.
     - PLen n      : just advance the cursor by [n], if that many
                     characters remain.
     - PAny set    : exactly one character, and it must be in [set].
     - PNotAny set : exactly one character, and it must NOT be in [set].
     - PSpan set   : the longest run (>=1 char) drawn from [set] --
                     ONE attempt at the maximal length; per the research
                     file this does not retry shorter on backtrack "in
                     the usual case".
     - PBreak set  : the longest run NOT in [set] (may be null,
                     deterministic length) -- also one attempt, nothing
                     to backtrack over.
     - PArb        : shortest first (the null match), extending by one
                     character on each retry -- Green Book's
                     `ARB = NULL | LEN(1) *ARB`. The one primitive here
                     that genuinely retries multiple lengths.
     - PConcat (p1,p2) : match [p1], and in ITS continuation, match [p2]
                     from wherever [p1] left the cursor, continuing with
                     the outer [k] -- i.e. nest the continuations.
     - PAlt (p1,p2)    : try [p1] first; if that can't be made to lead
                     [k] to [true], try [p2] from the same [pos].
     - PBind (p,name)  : match [p], and in its continuation, record the
                     substring it actually matched (from [pos] to the
                     new cursor) under [name] by consing onto [binds]
                     before calling [k]. *)
let match_pat (_pat : pattern) (_subj : string) (_pos : int)
    (_binds : binding list) (_k : int -> binding list -> bool) : bool =
  failwith "TODO: implement match_pat (see the comment above for the case-by-case contract)"

(* TODO(checkpoint 3): implement [find_match], the unanchored search
   driver. Try the whole pattern starting at cursor 0, using a
   continuation that records the match and returns [true] immediately
   on any full success; if [match_pat] can't find any way to make that
   continuation succeed anywhere within it, advance the start cursor by
   one character and try completely afresh -- do NOT treat a single
   failed attempt at position 0 as "no match anywhere in the string"
   (research file's `'--1B-A-' (ANY('AB') | '1' ABORT)` example turns
   on exactly this distinction: a later alternative can still succeed
   at the SAME start position after an earlier one fails, and only
   after every alternative at a position is exhausted should the start
   position itself advance). Try every start position from 0 up to and
   including [String.length subj] (a null match is allowed at the very
   end). Return [Some (start, endp, binds)] for the first successful
   attempt found, or [None] if no start position works at all. *)
let find_match (_pat : pattern) (_subj : string) : (int * int * binding list) option =
  failwith "TODO: implement find_match (see the comment above; calls match_pat)"

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
  | Match (_subject_e, _pattern_e, _object_e) ->
    (* TODO(checkpoint 3): implement the pattern-match statement,
       following the Green Book Ch.10's fixed execution order
       (research/snobol/03-pattern-matching.md, "How a pattern-matching
       statement actually executes"):
         1. evaluate the subject ([eval_expr subject_e]) and turn it
            into a string ([string_of_value]) -- a [Fail_signal] here
            fails the whole statement;
         2. evaluate the pattern ([eval_expr pattern_e]) and coerce it
            with [to_pattern] -- likewise can fail the statement;
         3. attempt the match with [find_match]; [None] means the
            statement fails outright (return [Failure]) with the
            subject left completely untouched;
         4. on [Some (start, endp, binds)]: commit every conditional
            (".") binding into [env] via [assign] NOW, unconditionally
            -- this must happen before step 5, so a bound variable is
            already available for use inside the replacement object
            expression itself (see bind_replace.sno);
         5. if there is no replacement object ([object_e = None]), the
            statement is done: [Success];
         6. otherwise evaluate the replacement object; a [Fail_signal]
            here fails the statement (but does NOT undo the bindings
            already committed in step 4 -- that's deliberate, per the
            Green Book);
         7. splice the replacement string in place of [start, endp) in
            the original subject string, and assign the result back --
            this subset requires the subject to be a plain [Var] (not,
            e.g., a function-call lvalue) to have somewhere to assign
            the result to. *)
    failwith
      "TODO: implement Match (subject, pattern, replacement) statement execution -- see the comment above"

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
