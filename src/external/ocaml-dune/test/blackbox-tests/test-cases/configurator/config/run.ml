module Configurator = Configurator.V1

let () =
  begin match Sys.getenv "DUNE_CONFIGURATOR" with
  | exception Not_found -> failwith "DUNE_CONFIGURATOR is not passed"
  | _ -> print_endline "DUNE_CONFIGURATOR is present"
  end;
  Configurator.main ~name:"config" (fun t ->
    match Configurator.ocaml_config_var t "version" with
    | None -> failwith "version is absent"
    | Some _ -> print_endline "version is present"
  )
