(* Week 11: [Parser.parse_program] now returns [program * string list] --
   the parsed statements (skipping any line that failed to parse) plus
   every located, recovered error message, in source order (see
   parser.ml's module comment). Run the program only if that error list
   is empty; otherwise print every recovered error and exit nonzero
   without executing a program we know is incomplete. This is the
   payoff of line-level recovery: a malformed program now reports *all*
   of its syntax errors in one pass, instead of stopping at the first. *)
let () =
  match Sys.argv with
  | [| _; path |] ->
    let ic = open_in path in
    let n = in_channel_length ic in
    let source = really_input_string ic n in
    close_in ic;
    let prog, errors = Snobol.Parser.parse_program source in
    if errors <> [] then begin
      List.iter (fun msg -> Printf.eprintf "%s\n" msg) errors;
      exit 1
    end else Snobol.Eval.run prog
  | _ ->
    prerr_endline "usage: main <file.sno>";
    exit 1
