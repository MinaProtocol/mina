open Core
open Async

;;

let _ =
  let%map _ = Process.run_exn ~prog:"/bin/bash" ~args:[ "-c"; Printf.sprintf "echo \'let foo () = ()\' > %s" Sys.argv.(1)  ] () in
  exit 0
;;

let () = never_returns (Scheduler.go ())

