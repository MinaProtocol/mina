open Core
open Async

let print_peerss nanobits =
  printf "peers:\n";
  Deferred.List.iter ~how:`Parallel nanobits ~f:(fun nanobit -> 
    let%map peers = Nanobit_testbridge.get_peers nanobit in
    printf "\t%d %s\n" nanobit.bridge_port
      (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list option] peers));
  )

let lists_same xs ys = 
  (List.for_all 
    xs
    ~f:(fun x -> List.exists ys ~f:(fun y -> Host_and_port.(y = x))))
    &&
  (List.for_all 
    ys
    ~f:(fun y -> List.exists xs ~f:(fun x -> Host_and_port.(x = y))))
;;

let check_alive_nanobits alive_nanobits =
  printf "peers:\n";
  let%map peers = 
    Deferred.List.map ~how:`Parallel alive_nanobits ~f:(fun nanobit -> 
      let%map peers = Nanobit_testbridge.get_peers nanobit in
      printf "\t%s %s\n" 
        (Sexp.to_string_hum ([%sexp_of: Host_and_port.t] nanobit.Nanobit_testbridge.Nanobit.swim_addr))
        (Sexp.to_string_hum ([%sexp_of: Host_and_port.t list option] peers));
      peers
    )
  in
  let peers = 
    List.map2_exn alive_nanobits peers 
      ~f:(fun alive_peer peers -> alive_peer.Nanobit_testbridge.Nanobit.swim_addr::(Option.value_exn peers))
  in
  List.for_all
    peers
    ~f:(fun peers -> 
      lists_same 
        (List.map alive_nanobits ~f:(fun nanobit -> nanobit.Nanobit_testbridge.Nanobit.swim_addr))
        peers
    )
;;

let check alive_nanobits = 
  let%bind () = after (sec 10.0) in
  let%map pass = check_alive_nanobits alive_nanobits in
  assert pass;
  printf "pass %b\n" pass
;;

let pattern n = 
  assert (n%4 = 0);
  [ `Kill 2
  ; `Start 1
  ; `Start 1
  ; `Kill (n/2)
  ; `Start (n/4)
  ; `Start (n/4)
  ; `Kill (n-1)
  ]
;;

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";
  let nanobits_state = Nanobit_testbridge.init_alive_dead_nanobits nanobits args in

  let%bind () = check (List.map (fst nanobits_state) ~f:(fun na -> na.nanobit)) in

  let%bind _ = 
    Deferred.List.fold
      ~init:nanobits_state
      (pattern (List.length nanobits)) ~f:(fun nanobits_state cmd ->
        match cmd with
        | `Kill n -> 
          printf "kill %d\n" n;
          let%bind nanobits_state = Nanobit_testbridge.kill_nanobits n nanobits_state in
          let%map () = check (List.map (fst nanobits_state) ~f:(fun na -> na.nanobit)) in
          nanobits_state
        | `Start n -> 
          printf "start %d\n" n;
          let%bind nanobits_state = Nanobit_testbridge.start_nanobits n nanobits_state in
          let%map () = check (List.map (fst nanobits_state) ~f:(fun na -> na.nanobit)) in
          nanobits_state
      )
  in

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
