(* test_common.ml -- code common to tests *)

open Core_kernel
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  (* [logs] is a string containing the entire replayer output *)
  let check_replayer_logs ~logger logs =
    let log_level_substring level = sprintf {|"level":"%s"|} level in
    let error_log_substring = log_level_substring "Error" in
    let fatal_log_substring = log_level_substring "Fatal" in
    let info_log_substring = log_level_substring "Info" in
    let split_logs = String.split logs ~on:'\n' in
    let error_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:error_log_substring
             || String.is_substring log ~substring:fatal_log_substring )
    in
    let info_logs =
      split_logs
      |> List.filter ~f:(fun log ->
             String.is_substring log ~substring:info_log_substring )
    in
    let num_info_logs = List.length info_logs in
    if num_info_logs < 25 then
      Malleable_error.hard_error_string
        (sprintf "Replayer output contains suspiciously few (%d) Info logs"
           num_info_logs )
    else if List.is_empty error_logs then (
      [%log info] "The replayer encountered no errors" ;
      Malleable_error.return () )
    else
      let error = String.concat error_logs ~sep:"\n  " in
      Malleable_error.hard_error_string ("Replayer errors:\n  " ^ error)
end
