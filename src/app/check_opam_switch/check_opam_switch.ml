(**
   Checks that the current switch contains all the packages specified
   in the opam.export passed as an argument.
 *)

let () =
  if Array.length Sys.argv <> 2 then
    let () = Format.printf "USAGE: check_opam_switch opam.export\n" in
    exit 1
  else
    let opam_export_path = Sys.argv.(1) in
    Compare_switch.compare_with_current_switch opam_export_path
