let flag = ref false
let arg = ref ""

let () =
  Migrate_parsetree.Driver.register
    ~name:"linter"
    ~args:([ "-flag", Arg.Set flag, ""
           ; "-arg", Arg.Set_string arg, ""
           ])
    Migrate_parsetree.Versions.ocaml_405
    (fun _ _cookies ->
       if not !flag then (
         Format.eprintf "pass -flag to fooppx@.%!";
         exit 1
       );
       if !arg = "" then (
         Format.eprintf "pass -arg to fooppx@.%!"
       );
       Format.eprintf "-arg: %s%@." !arg;
       Migrate_parsetree.Ast_405.shallow_identity
    )
