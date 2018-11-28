let lint = ref false

let () =
  Migrate_parsetree.Driver.register
    ~name:"reasonppx"
    ~args:(["-lint", Arg.Bool (fun l -> lint := l), ""])
    Migrate_parsetree.Versions.ocaml_405
    (fun _ _cookies ->
       if !lint then (
         exit 0
       ) else (
         Migrate_parsetree.Ast_405.shallow_identity
       )
    )
