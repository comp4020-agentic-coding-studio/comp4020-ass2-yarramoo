let () =
  match Sys.argv with
  | [| _; path |] ->
    let ic = open_in path in
    (try
       while true do
         let line = input_line ic in
         let trimmed = String.trim line in
         if trimmed <> "" then begin
           let tokens = Snobol.Lexer.tokenize line in
           let expr = Snobol.Parser.parse_line tokens in
           print_int (Snobol.Eval.eval_expr expr);
           print_newline ()
         end
       done
     with End_of_file -> close_in ic)
  | _ ->
    prerr_endline "usage: main <file.sno>";
    exit 1
