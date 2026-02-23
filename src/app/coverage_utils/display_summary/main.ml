(**

   Format the output of the test coverage summary.  We are interested in
   code added by the develop branch, so we sort the files by the
   number of lines added in this branch.

*)
open Parsing

open Utils

let () =
  if Array.length Sys.argv <> 2 then
    let () = Printf.printf "Usage: %s coverage_summary\n" Sys.argv.(0) in
    exit 1
  else
    let coverage_map = Coverage.read_from_file Sys.argv.(1) in
    let files_modified_in_develop =
      (* files and their number of lines added in develop *)
      Modified_in_develop.get ()
    in
    let files_modified_in_develop =
      (* Filter out some files we are not interested in *)
      List.filter
        (fun (_, file) ->
          (not @@ String.starts_with ~prefix:"src/app" file)
          && (not @@ String.ends_with ~suffix:"intf.ml" file)
          && (not @@ String.ends_with ~suffix:"debug.ml" file)
          && (not @@ contains_substring "integration_test_cloud_engine" file)
          && (not @@ contains_substring "integration_test_lib" file) )
        files_modified_in_develop
    in
    let report =
      (* Join the coverage and lines added in develop information *)
      Report.make coverage_map files_modified_in_develop
    in
    Format.printf "%a" Report.pp report
