module List = ListLabels
open Printf

let write_file ~file ~contents =
  let ch = open_out file in
  output_string ch contents;
  close_out_noerr ch

let lib_stanza ~modules_without_implementation ~virtual_modules
      ~private_modules =
  sprintf "(library\n (name foo)%s%s%s)"
    (if modules_without_implementation then
       "\n (modules_without_implementation m)"
     else
       "")
    (if virtual_modules then
       "\n (virtual_modules m)"
     else
       "")
    (if private_modules then
       "\n (private_modules m)"
     else
       "")

let chdir dir ~f =
  let old_dir = Sys.getcwd () in
  begin try
    Sys.chdir dir;
    f ()
  with e ->
    Sys.chdir old_dir;
    raise e
  end;
  Sys.chdir old_dir

let gen_test ~impl ~modules_without_implementation ~virtual_modules
  ~private_modules =
  printf "impl: %b. modules_without_implementation: %b. \
          virtual_modules: %b. private_modules: %b\n%!"
    impl modules_without_implementation virtual_modules private_modules;
  let dir =
    sprintf "%b-%b-%b-%b" impl modules_without_implementation virtual_modules
      private_modules
  in
  let _ = Sys.command (sprintf "mkdir -p %s" dir) in
  chdir dir ~f:(fun () ->
    write_file ~file:"dune-project"
      ~contents:"(lang dune 1.2)\n\
                 (using in_development_do_not_use_variants 0.1)";
    write_file ~file:"m.mli" ~contents:"";
    if impl then
      write_file ~file:"m.ml" ~contents:"";
    write_file ~file:"dune" ~contents:(
      lib_stanza ~modules_without_implementation ~virtual_modules
        ~private_modules);
    ignore (Sys.command "dune build");
    print_endline "-------------------------"
  )

let bools = [true; false]

let () =
  List.iter bools ~f:(fun private_modules ->
    List.iter bools ~f:(fun impl ->
      List.iter bools ~f:(fun modules_without_implementation ->
        List.iter bools ~f:(fun virtual_modules ->
          gen_test ~impl ~modules_without_implementation ~virtual_modules
            ~private_modules
        )
      )
    )
  )
