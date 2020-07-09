(* dump_dhall_types.ml -- dump Dhall types for runtime config and related types *)

open Core

(* Dhall types (as OCaml values) and their names to be used in Dhall *)
let types_and_files = [(Runtime_config.dhall_type, "runtime_config")]

let print_dhall_type (ty, nm) =
  let s = Ppx_dhall_type.Dhall_type.to_string ty in
  let dhall_file = nm ^ ".dhall" in
  let oc = Caml.open_out dhall_file in
  Printf.fprintf oc "-- GENERATED FILE\n\n%!" ;
  Printf.fprintf oc "let %s : Type = %s in %s" nm s nm ;
  Caml.close_out oc ;
  ignore
    (Unix.create_process ~prog:"dhall" ~args:["format"; "--inplace"; dhall_file])

let main ~output_dir () =
  let output_dir =
    Option.value_map ~default:(Sys.getcwd ()) ~f:Fn.id output_dir
  in
  Sys.chdir output_dir ;
  List.iter types_and_files ~f:print_dhall_type

let () =
  Command.(
    run
      (let open Let_syntax in
      basic ~summary:"Dump Dhall types to files"
        (let%map output_dir =
           Param.flag "--output-dir"
             ~doc:
               "Directory where the Dhall files will be created (default: \
                current directory)"
             Param.(optional string)
         in
         main ~output_dir)))
