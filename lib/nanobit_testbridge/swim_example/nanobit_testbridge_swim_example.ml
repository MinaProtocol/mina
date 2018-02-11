open Core
open Async

let print_peerss nanobits =
  printf "peers:\n";
  Deferred.List.iter ~how:`Parallel nanobits ~f:(fun  nanobit -> 
    let%map peers = Nanobit_testbridge.get_peers nanobit in
    printf "\t%d %s\n" nanobit.bridge_port
      (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list option] peers));
  )

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.init_all_connected nanobits in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Init.query list] args));
  printf "starting test\n";
  let%bind () = after (sec 5.0) in
  let%bind () = print_peerss nanobits in
  let%bind () = Nanobit_testbridge.stop (List.nth_exn nanobits 1) in
  let%bind () = after (sec 5.0) in
  let%bind () = print_peerss (Nanobit_testbridge.remove_nth nanobits 1) in
  let%bind () = Nanobit_testbridge.start (List.nth_exn nanobits 1) in
  let%bind () = Nanobit_testbridge.init (List.nth_exn nanobits 1) (List.nth_exn args 1) in
  let%bind () = after (sec 5.0) in
  let%bind () = print_peerss (Nanobit_testbridge.remove_nth nanobits 1) in
  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
