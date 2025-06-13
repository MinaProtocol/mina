open Integration_test_lib
open Async
open Core_kernel

let wget ~url ~target = Util.run_cmd_exn "." "wget" [ "-c"; url; "-O"; target ]

let sed ~search ~replacement ~input =
  Util.run_cmd_exn "." "sed"
    [ "-i"; "-e"; Printf.sprintf "s/%s/%s/g" search replacement; input ]

let untar ~archive ~output =
  Util.run_cmd_exn "." "tar" [ "-xf"; archive; "-C"; output ]

let dedup_and_sort_archive_files files : string list =
  files
  |> List.dedup_and_sort ~compare:(fun left right ->
         let scan_height name = Scanf.sscanf name "%_s@-%d-%_s" Fn.id in

         let left_height = scan_height left in
         let right_height = scan_height right in

         Int.compare left_height right_height )

let force_kill process =
  Process.send_signal process Core.Signal.kill ;
  Deferred.map (Process.wait process) ~f:Or_error.return
