open Integration_test_lib
open Async
open Core_kernel

let wget ~url ~target = Util.run_cmd_exn "." "wget" [ "-c"; url; "-O"; target ]

let sed ~search ~replacement ~input =
  Util.run_cmd_exn "." "sed"
    [ "-i"; "-e"; Printf.sprintf "s/%s/%s/g" search replacement; input ]

let untar ~archive ~output =
  Util.run_cmd_exn "." "tar" [ "-xf"; archive; "-C"; output ]

let force_kill process =
  Process.send_signal process Core.Signal.kill ;
  Deferred.map (Process.wait process) ~f:Or_error.return
