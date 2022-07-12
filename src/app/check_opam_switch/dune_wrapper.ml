(**
   Wrapper around [dune] that first checks that the current switch
   contains all the packages specified in the opam.export
   file located at [$DUNE_WRAPPER_OPAM_FILE].
 *)

let () =
  let () =
    match Sys.getenv_opt "DUNE_WRAPPER_OPAM_FILE" with
    | Some opam_export_path ->
        Compare_switch.compare_with_current_switch opam_export_path
    | None ->
        ()
  in
  Unix.execvp "dune" Sys.argv
