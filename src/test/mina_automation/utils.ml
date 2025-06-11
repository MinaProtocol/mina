open Integration_test_lib
open Async
open Core_kernel

let wget ~url ~target = Util.run_cmd_exn "." "wget" [ "-c"; url; "-O"; target ]

let sed ~search ~replacement ~input =
  Util.run_cmd_exn "." "sed"
    [ "-i"; "-e"; Printf.sprintf "s/%s/%s/g" search replacement; input ]

let untar ~archive ~output =
  Util.run_cmd_exn "." "tar" [ "-xf"; archive; "-C"; output ]

let sort_archive_files files : string list =
  files
  |> List.sort ~compare:(fun left right ->
         let scan_height item =
           let item =
             Filename.basename item |> Str.global_replace (Str.regexp "-") " "
           in
           Scanf.sscanf item "%s %d %s" (fun _ height _ -> height)
         in

         let left_height = scan_height left in
         let right_height = scan_height right in

         Int.compare left_height right_height )

let force_kill process =
  Process.send_signal process Core.Signal.kill ;
  Deferred.map (Process.wait process) ~f:Or_error.return