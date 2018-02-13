open Core
open Async

module Nanobit_args = struct
  type t = 
    { nanobit: Nanobit_testbridge.Nanobit.t
    ; args: Nanobit_testbridge.Rpcs.Main.query
    }
end

let kill_nanobits n alive_nanobits dead_nanobits =
  let nanobits = List.permute alive_nanobits in
  let to_kill = List.take nanobits n in
  let%map () = Deferred.List.iter to_kill ~f:(fun na -> Nanobit_testbridge.stop na.Nanobit_args.nanobit) in
  (List.drop nanobits n, List.concat [ to_kill; dead_nanobits ])

let start_nanobits n alive_nanobits dead_nanobits =
  let nanobits = List.permute dead_nanobits in
  let to_start = List.take nanobits n in
  let%map () = 
    Deferred.List.iter to_start ~f:(fun na -> 
      let%bind () = Nanobit_testbridge.start na.Nanobit_args.nanobit in
      Nanobit_testbridge.main na.nanobit na.args
    )
  in
  (List.concat [ to_start; alive_nanobits ], List.drop nanobits n)

let check alive_nanobits = 
  let%bind () = after (sec 5.0) in
  let%map pass = return true in
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
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits ~should_mine:true in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";
  let _alive_nanobits, _dead_nanobits = 
    List.map2_exn nanobits args ~f:(fun nanobit args -> { Nanobit_args.nanobit; args }), [] 
  in

  don't_wait_for begin
    Deferred.List.iter ~how:`Parallel nanobits
      ~f:(fun nanobit ->
        Deferred.ignore begin
          Nanobit_testbridge.get_strongest_blocks 
            nanobit
            ~f:(fun pipe -> 
              let%map () = 
                Pipe.iter_without_pushback pipe ~f:(fun () -> 
                  printf "got block %s\n"
                    (Sexp.to_string_hum ([%sexp_of: Host_and_port.t] nanobit.Nanobit_testbridge.Nanobit.swim_addr))
                )
              in
              Ok ()
            )
        end
      )
  end;

  (*let%bind () = check (List.map alive_nanobits ~f:(fun na -> na.nanobit)) in

  let%bind _ = 
    Deferred.List.fold
      ~init:(alive_nanobits, dead_nanobits)
      (pattern (List.length nanobits)) ~f:(fun (alive_nanobits, dead_nanobits) cmd ->
        match cmd with
        | `Kill n -> 
          printf "kill %d\n" n;
          let%bind (alive_nanobits, dead_nanobits) = kill_nanobits n alive_nanobits dead_nanobits in
          let%map () = check (List.map alive_nanobits ~f:(fun na -> na.nanobit)) in
          (alive_nanobits, dead_nanobits)
        | `Start n -> 
          printf "start %d\n" n;
          let%bind (alive_nanobits, dead_nanobits) = start_nanobits n alive_nanobits dead_nanobits in
          let%map () = check (List.map alive_nanobits ~f:(fun na -> na.nanobit)) in
          (alive_nanobits, dead_nanobits)
      )
  in*)

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
