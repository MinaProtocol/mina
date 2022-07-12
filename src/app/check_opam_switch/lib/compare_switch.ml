(**
   Utilities to check that the packages from an opam.export file are installed in the current switch.
 *)

(** Fails if some package was not found *)
let switch_export_of_path path =
  path |> OpamFilename.of_string |> OpamFile.make |> OpamFile.SwitchExport.read

(** Fails if some package was not found *)
let fail ?(from_overlay = false) opam_export_filepath
    (print_error_message : unit -> unit) =
  Format.printf
    "\n[ERROR]: The current opam switch is not a superset of the %s file:\n"
    opam_export_filepath ;
  print_error_message () ;
  Format.printf
    "Current switch should probably be updated using 'opam switch import \
     src/opam.export'.\n" ;
  if from_overlay then
    (* See https://github.com/ocaml/opam/issues/5173 *)
    Format.printf "Potentially twice in a row due to an opam bug.\n" ;
  Format.printf "\n" ;
  exit 1

(** Checks that [pkgs] is a subset of [pkgs_current] *)
let check_pkgs_subset opam_export_filepath pkgs pkgs_current =
  OpamPackage.Set.iter
    (fun p ->
      if not @@ OpamPackage.Set.mem p pkgs_current then
        fail opam_export_filepath (fun () ->
            Format.printf "Could not find package %s in current switch\n"
              (OpamPackage.to_string p) ) )
    pkgs

let check_overlay_eq opam_export_filepath name (overlay_file : OpamFile.OPAM.t)
    (overlay_current : OpamFile.OPAM.t) =
  if not @@ OpamFile.OPAM.effectively_equal overlay_file overlay_current then
    fail ~from_overlay:true opam_export_filepath (fun () ->
        Format.printf "Different overlays for package : %s\n" name ;
        Format.printf "\nopam.export FILE:\n" ;
        Format.printf "-------------- BEGIN ----------------------\n" ;
        Format.printf "%s\n" (OpamFile.OPAM.write_to_string overlay_file) ;
        Format.printf "-------------- END ------------------------\n" ;
        Format.printf "\nCURRENT SWITCH:\n" ;
        Format.printf "-------------- BEGIN ----------------------\n" ;
        Format.printf "%s\n" (OpamFile.OPAM.write_to_string overlay_current) ;
        Format.printf "-------------- END ------------------------\n" )

(** check that the [overlays] are a subset of the ones from [overlays_current] *)
let check_overlays_subset opam_export_filepath overlays overlays_current =
  OpamPackage.Name.Map.iter
    (fun name overlay_file ->
      match OpamPackage.Name.Map.find_opt name overlays_current with
      | None ->
          fail opam_export_filepath (fun () ->
              Format.printf "Could not find overlay %s in current switch\n"
                (OpamPackage.Name.to_string name) )
      | Some overlay_current ->
          check_overlay_eq opam_export_filepath
            (OpamPackage.Name.to_string name)
            overlay_file overlay_current )
    overlays

(** [compare_switch_states] checks that packages from the [installed] section, and the overlays (which look like inlined .opam files) are present in the current switch. *)
let compare_switch_states opam_export_filepath
    (opam_export : OpamFile.SwitchExport.t) (current : OpamFile.SwitchExport.t)
    =
  let () =
    check_pkgs_subset opam_export_filepath opam_export.selections.sel_installed
      current.selections.sel_installed
  in
  let () =
    check_pkgs_subset opam_export_filepath opam_export.selections.sel_compiler
      current.selections.sel_compiler
  in
  check_overlays_subset opam_export_filepath opam_export.overlays
    current.overlays

(** Compare the [opam_export_path] file with the current switch. *)
let compare_with_current_switch opam_export_path : unit =
  let output =
    Commands.run_string "opam" [| "opam"; "switch"; "export"; "-" |]
  in
  let switch_current = OpamFile.SwitchExport.read_from_string output in
  let switch_file = switch_export_of_path opam_export_path in
  compare_switch_states opam_export_path switch_file switch_current
