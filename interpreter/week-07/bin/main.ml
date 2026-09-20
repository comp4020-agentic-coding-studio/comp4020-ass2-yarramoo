let () =
  match Sys.argv with
  | [| _; path |] ->
    let ic = open_in path in
    let n = in_channel_length ic in
    let source = really_input_string ic n in
    close_in ic;
    let prog = Snobol.Parser.parse_program source in
    Snobol.Eval.run prog
  | [| _; path; "--trace" |] ->
    let ic = open_in path in
    let n = in_channel_length ic in
    let source = really_input_string ic n in
    close_in ic;
    let prog = Snobol.Parser.parse_program source in
    Snobol.Eval.trace_enabled := true;
    Snobol.Eval.run prog
  | _ ->
    prerr_endline "usage: main <file.sno> [--trace]";
    exit 1
